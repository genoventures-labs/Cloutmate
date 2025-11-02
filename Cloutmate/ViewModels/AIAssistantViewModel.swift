//
//  AIAssistantViewModel.swift
//  Cloutmate
//
//  AI Assistant View Model
//

import Foundation
import SwiftUI
import SwiftData
import GoogleGenerativeAI
import CloutmateShared

enum DateFilter: String, CaseIterable {
    case all = "All"
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case older = "Older"
}

@MainActor
@Observable
final class AIAssistantViewModel {
    private let aiService = AICreativeService.shared
    private let geminiService = GeminiService.shared
    private let aiSettings = AISettings.shared
    private let actionRouter = AIActionRouter.shared
    private let feedbackLogger = AIFeedbackLogger.shared
    
    var messages: [AIMessage] = []
    var currentConversation: AIConversation?
    var selectedConversation: AIConversation?
    var inputText = ""
    var searchText = ""
    var selectedDateFilter: DateFilter = .all
    var selectedTags: Set<String> = []
    var selectedPlatform: Platform = .facebook
    var isLoading = false
    var errorMessage: String?
    
    // Status tracking for inline updates
    var currentStatus: String?
    
    var isAIEnabled: Bool {
        aiSettings.isAIEnabled
    }
    
    // MARK: - Status Methods
    
    func updateStatus(_ message: String) {
        currentStatus = message
    }
    
    func clearStatus() {
        currentStatus = nil
    }
    
    // MARK: - Methods
    
    func initializeConversation(modelContext: ModelContext) {
        if currentConversation == nil {
            let conversation = AIConversation(title: "Chat \(Date().formatted(date: .abbreviated, time: .omitted))")
            modelContext.insert(conversation)
            currentConversation = conversation
            selectedConversation = conversation
            
            // Save the conversation immediately so it appears in the list
            do {
                try modelContext.save()
            } catch {
                print("Failed to save conversation: \(error)")
            }
            
            // Load messages for this conversation
            if let messages = conversation.messages {
                self.messages = messages
            }
        }
    }
    
    func sendMessage(_ text: String, modelContext: ModelContext) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Initialize conversation if needed
        if currentConversation == nil {
            initializeConversation(modelContext: modelContext)
        }
        
        // Track if this is the first message in the conversation
        let isFirstMessage = (currentConversation?.messages?.count ?? 0) == 0
        
        // Check if AI is enabled
        guard aiSettings.isAIEnabled else {
            let errorMessage = AIMessage(
                role: "assistant",
                content: "AI features are currently disabled. Please enable them in Settings."
            )
            modelContext.insert(errorMessage)
            messages.append(errorMessage)
            currentConversation?.messages?.append(errorMessage)
            try? modelContext.save()
            return
        }
        
        // Analyze emotional tone of user message
        let emotionalSnapshot = EmotionAnalyzer.analyzeTone(text: text)
        
        let userMessage = AIMessage(
            role: "user",
            content: text,
            emotion: emotionalSnapshot.primaryEmotion.rawValue,
            emotionScore: emotionalSnapshot.valence,
            emotionIntensity: emotionalSnapshot.intensity
        )
        modelContext.insert(userMessage)
        messages.append(userMessage)
        currentConversation?.messages?.append(userMessage)
        
        inputText = ""
        isLoading = true
        errorMessage = nil
        
        _Concurrency.Task {
            // DISABLED: Creation intent detection is too aggressive and constantly asks about creating tasks
            // Only create items when explicitly requested through conversational flow
            
            // Try preference update intent
            if let prefUpdate = try? await geminiService.inferPreferenceUpdate(input: text) {
                await MainActor.run {
                    // Fetch or create preferences
                    let prefs: UserPreferences
                    if let existing = try? modelContext.fetch(FetchDescriptor<UserPreferences>()).first {
                        prefs = existing
                    } else {
                        prefs = UserPreferences()
                        modelContext.insert(prefs)
                    }
                    if let hours = prefUpdate.preferredPostingHours, !hours.isEmpty {
                        prefs.preferredPostingHours = hours
                    }
                    if let platforms = prefUpdate.defaultPlatforms, !platforms.isEmpty {
                        prefs.defaultPlatforms = platforms
                    }
                    if let tone = prefUpdate.defaultTone, !tone.isEmpty {
                        prefs.defaultTone = tone
                    }
                    try? modelContext.save()
                    let confirm = AIMessage(role: "assistant", content: "Preferences updated.")
                    modelContext.insert(confirm)
                    messages.append(confirm)
                    currentConversation?.messages?.append(confirm)
                }
                await processMessage(text, modelContext: modelContext, isFirstMessage: isFirstMessage)
                return
            }
            
            // REMOVED: Scheduling intent picker - will auto-schedule in processMessage if needed
            
            await processMessage(text, modelContext: modelContext, isFirstMessage: isFirstMessage)
        }
    }
    
    private func processMessage(_ text: String, modelContext: ModelContext, isFirstMessage: Bool = false) async {
        do {
            // Build app context for AI
            let appContext = try await AppContextService.shared.buildContextForAI(modelContext: modelContext)
            
            // Check for REFLECTION intent first (introspective queries about patterns/state)
            if let reflectionIntent = try? await geminiService.detectReflectionIntent(input: text) {
                await processReflection(reflectionIntent, originalQuery: text, modelContext: modelContext, isFirstMessage: isFirstMessage)
                return
            }
            
            // Then check for execution intent (action-oriented commands)
            if let executionIntent = try? await geminiService.detectExecutionIntent(input: text) {
                await executeIntent(executionIntent, modelContext: modelContext, isFirstMessage: isFirstMessage)
                return
            }
            
            // Convert conversation messages to ModelContent for context
            let conversationModelContent: [ModelContent]? = await geminiService.convertMessagesToModelContent(messages)
            
            // Build adaptive payload context (recall + feedback loop)
            let recallSnippets = AIRecallService.shared.fetchRelevantSnippets(
                for: text,
                modelContext: modelContext
            )
            var feedbackSummaries = feedbackLogger.recentSummaries(
                limit: 3,
                modelContext: modelContext
            )
            if let weeklySummary = feedbackLogger.weeklyActivitySummary(modelContext: modelContext),
               !feedbackSummaries.contains(where: { $0.title == weeklySummary.title }) {
                feedbackSummaries.insert(weeklySummary, at: 0)
            }
            
            // Build emotional narrative from recent conversation messages
            let narrativeSummary = buildEmotionalNarrative(from: messages)
            
            // Fetch top priority items from CPS
            let priorityItems = PriorityEngine.shared.getTopObjects(limit: 10, modelContext: modelContext)
            
            // Build focus session context if enabled
            var focusContext: FocusSessionContext? = nil
            if AIConfigService.shared.config.featureFlags.focusModeEnabled {
                let activeSession = FocusSessionService.shared.getActiveSession(modelContext: modelContext)
                let now = Date()
                let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
                let stats = FocusSessionService.shared.getSessionStats(
                    for: DateInterval(start: weekAgo, end: now),
                    modelContext: modelContext
                )
                
                focusContext = FocusSessionContext(
                    isActive: activeSession != nil,
                    objective: activeSession?.objective,
                    elapsedMinutes: activeSession != nil ? Int(activeSession!.elapsedTime / 60) : nil,
                    remainingMinutes: activeSession != nil ? Int(max(0, activeSession!.remainingTime) / 60) : nil,
                    recentSessionCount: stats.totalSessions,
                    completionRate: stats.completionRate,
                    totalFocusHoursThisWeek: Int(stats.totalFocusTime / 3600)
                )
            }
            
            // Build live themes context if enabled
            var liveThemes: [ConceptSummary]? = nil
            if AIConfigService.shared.config.featureFlags.narrativeEnabled {
                liveThemes = ConceptTracker.shared.getConceptSummaries(limit: 5, modelContext: modelContext)
            }
            
            // Fetch past conversation summaries (excluding current)
            let pastConversationSummaries = ConversationArchive.shared.getConversationSummariesForContext(
                excludingId: currentConversation?.id,
                limit: 3,
                modelContext: modelContext
            )
            
            // Fetch memory graph themes if enabled
            var memoryThemes: [ThemeSummary]? = nil
            if AIConfigService.shared.config.featureFlags.memoryGraphEnabled {
                let themes = MemoryGraphService.shared.getActiveThemes(modelContext: modelContext)
                memoryThemes = themes.prefix(5).map { theme in
                    ThemeSummary(
                        id: theme.id,
                        label: theme.label,
                        description: theme.themeDescription,
                        salience: theme.salience,
                        memberCount: theme.memberNodeIds.count,
                        keywords: theme.keywords,
                        isActive: theme.isActive
                    )
                }
            }
            
            let payloadContext = AIPayloadContext(
                recall: recallSnippets,
                priorities: priorityItems,
                feedback: feedbackSummaries,
                focusSession: focusContext,
                liveThemes: liveThemes,
                pastConversations: pastConversationSummaries.isEmpty ? nil : pastConversationSummaries,
                memoryThemes: memoryThemes,
                narrativeSummary: narrativeSummary,
                metadata: ["phase": "6", "emotionalContinuity": "enabled", "cpsEnabled": "true", "focusModeEnabled": String(AIConfigService.shared.config.featureFlags.focusModeEnabled), "narrativeEnabled": String(AIConfigService.shared.config.featureFlags.narrativeEnabled), "crossConversationEnabled": "true", "memoryGraphEnabled": String(AIConfigService.shared.config.featureFlags.memoryGraphEnabled)]
            )
            
            // Use Gemini with app context for app-smart responses
            let response = try await geminiService.generateResponseWithAppContext(
                for: text,
                appContext: appContext,
                payloadContext: payloadContext,
                conversationMessages: conversationModelContent
            )
            
            // Convert markdown to attributed string for rich text
            let attributedResponse = convertMarkdownToAttributedString(response)
            
            let assistantMessage = AIMessage(role: "assistant", content: attributedResponse)
            
            await MainActor.run {
                modelContext.insert(assistantMessage)
                messages.append(assistantMessage)
                currentConversation?.messages?.append(assistantMessage)
                isLoading = false
                
                // Save after adding messages
                try? modelContext.save()
            }
            
            // Generate title if this is the first message
            if isFirstMessage, let conversation = currentConversation {
                await generateAndSetTitle(from: text, conversation: conversation, modelContext: modelContext)
            }
        } catch {
            // Handle errors
            let errorMessage = AIMessage(
                role: "assistant",
                content: "I'm having trouble connecting to the AI service. Please check your API key and internet connection."
            )
            
            await MainActor.run {
                modelContext.insert(errorMessage)
                messages.append(errorMessage)
                currentConversation?.messages?.append(errorMessage)
                self.errorMessage = error.localizedDescription
                isLoading = false
                
                // Save after adding error message
                try? modelContext.save()
            }
        }
    }
    
    private func executeIntent(_ intent: GeminiService.ExecutionIntent, modelContext: ModelContext, isFirstMessage: Bool) async {
        do {
            if let action = AIIntentAction(from: intent) {
                let actionResult = try await actionRouter.route(action, modelContext: modelContext)
                
                let attributedResult = convertMarkdownToAttributedString(actionResult.markdown)
                let assistantMessage = AIMessage(role: "assistant", content: attributedResult)
                
                await MainActor.run {
                    modelContext.insert(assistantMessage)
                    messages.append(assistantMessage)
                    currentConversation?.messages?.append(assistantMessage)
                    isLoading = false
                    try? modelContext.save()
                }
                
                feedbackLogger.record(action: action, result: actionResult, modelContext: modelContext)
                
                if isFirstMessage, let conversation = currentConversation {
                    await generateAndSetTitle(from: action.displayName, conversation: conversation, modelContext: modelContext)
                }
            } else {
                // Fallback to legacy execution for unknown intents (should rarely trigger).
                let executionService = AIExecutionService.shared
                let legacyResult: AIExecutionService.ExecutionResult
                
                switch intent.operation {
                case .archiveTasks:
                    let criteria = AIExecutionService.ArchiveCriteria(rawValue: intent.criteria ?? "completed") ?? .completed
                    legacyResult = try await executionService.archiveTasks(
                        criteria: criteria,
                        daysAgo: intent.daysAgo,
                        projectId: nil,
                        context: modelContext
                    )
                case .summarizePosts:
                    let filter = AIExecutionService.PostFilter(rawValue: intent.postFilter ?? "all") ?? .all
                    legacyResult = try await executionService.summarizePosts(
                        filter: filter,
                        filterValue: intent.filterValue,
                        context: modelContext
                    )
                case .generateReport:
                    let type = AIExecutionService.ReportType(rawValue: intent.reportType ?? "weekly") ?? .weekly
                    legacyResult = try await executionService.generateProgressReport(
                        type: type,
                        context: modelContext
                    )
                case .predictScheduling:
                    legacyResult = try await executionService.predictSchedulingNeeds(
                        daysAhead: intent.daysAhead ?? 7,
                        context: modelContext
                    )
                default:
                    // All other operations (createPost, publishPost, tasks, notes, inbox, projects) 
                    // are handled by AIActionRouter above and should never reach this fallback
                    throw ExecutionError.executionFailed("Operation \(intent.operation.rawValue) not supported in legacy execution path")
                }
                
                let attributed = convertMarkdownToAttributedString(legacyResult.asMarkdown())
                let assistantMessage = AIMessage(role: "assistant", content: attributed)
                
                await MainActor.run {
                    modelContext.insert(assistantMessage)
                    messages.append(assistantMessage)
                    currentConversation?.messages?.append(assistantMessage)
                    isLoading = false
                    try? modelContext.save()
                }
            }
        } catch {
            let errorMessage = AIMessage(
                role: "assistant",
                content: "❌ Failed to execute: \(error.localizedDescription)"
            )
            
            await MainActor.run {
                modelContext.insert(errorMessage)
                messages.append(errorMessage)
                currentConversation?.messages?.append(errorMessage)
                self.errorMessage = error.localizedDescription
                isLoading = false
                
                // Save after adding error message
                try? modelContext.save()
            }
        }
    }
    
    private func processReflection(_ intent: GeminiService.ReflectionIntent, originalQuery: String, modelContext: ModelContext, isFirstMessage: Bool) async {
        // Map the user's query to the appropriate time range for analytics
        // For now, default to "thisWeek" unless the query explicitly mentions other timeframes
        let timeRange: AnalyticsTimeRange = .thisWeek
        
        // Use AIReflectionService to analyze Intelligence Dashboard data
        let reflectionService = AIReflectionService.shared
        let reflectiveInsight = await reflectionService.reflect(
            on: intent,
            timeRange: timeRange,
            modelContext: modelContext
        )
        
        // Generate chart data if this is a visualization-oriented query
        var chartData: ChartData? = nil
        let queryLower = originalQuery.lowercased()
        let hasVisualizationRequest = queryLower.contains("visualiz") || queryLower.contains("render") ||
                                       queryLower.contains("display") || queryLower.contains("curve") ||
                                       queryLower.contains("graph") || queryLower.contains("chart") ||
                                       queryLower.contains("projection")
        
        if hasVisualizationRequest {
            // Generate appropriate chart based on intent
            switch intent {
            case .productivityPatterns:
                chartData = await ChartGenerator.generateProductivityChart(timeRange: timeRange, modelContext: modelContext)
            case .focusEffectiveness:
                chartData = await ChartGenerator.generateFocusChart(timeRange: timeRange, modelContext: modelContext)
            case .emotionalTrends:
                chartData = await ChartGenerator.generateEmotionalChart(timeRange: timeRange, modelContext: modelContext)
            case .weekOverview, .monthOverview:
                // For projection-specific queries, use projection chart
                if queryLower.contains("projection") || queryLower.contains("predict") {
                    chartData = await ChartGenerator.generateProjectionChart(timeRange: timeRange, modelContext: modelContext)
                }
            default:
                break
            }
        }
        
        // Format as Aurora's thoughtful response
        let fullResponse = """
        💭 **Reflection on your patterns and progress**
        
        \(reflectiveInsight)
        
        ---
        
        _This analysis is based on data from your Intelligence Dashboard. Visit **Insights** to explore these patterns visually._
        """
        
        let attributedResponse = convertMarkdownToAttributedString(fullResponse)
        let assistantMessage = AIMessage(role: "assistant", content: attributedResponse, chartData: chartData)
        
        await MainActor.run {
            modelContext.insert(assistantMessage)
            messages.append(assistantMessage)
            currentConversation?.messages?.append(assistantMessage)
            isLoading = false
            try? modelContext.save()
        }
        
        // Log this as a feedback event for learning
        let feedbackEvent = AIFeedbackEvent(
            actionName: "reflection_query",
            resultMessage: "Provided reflective insights for \(intent.rawValue)",
            itemsAffected: 1
        )
        modelContext.insert(feedbackEvent)
        try? modelContext.save()
        
        if isFirstMessage, let conversation = currentConversation {
            await generateAndSetTitle(from: "Reflection: \(intent.rawValue)", conversation: conversation, modelContext: modelContext)
        }
    }
    
    func executeQuickTool(_ tool: AITool, topic: String, modelContext: ModelContext) async {
        // Initialize conversation if needed
        if currentConversation == nil {
            initializeConversation(modelContext: modelContext)
        }
        
        // Check if AI is enabled
        guard aiSettings.isAIEnabled else {
            let errorMessage = AIMessage(
                role: "assistant",
                content: "AI features are currently disabled. Please enable them in Settings."
            )
            modelContext.insert(errorMessage)
            messages.append(errorMessage)
            currentConversation?.messages?.append(errorMessage)
            try? modelContext.save()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let userMessage = AIMessage(role: "user", content: "Use \(tool.rawValue) for: \(topic)", toolUsed: tool.rawValue)
        modelContext.insert(userMessage)
        messages.append(userMessage)
        currentConversation?.messages?.append(userMessage)
        
        let result = await aiService.executeTool(tool, input: topic, context: selectedPlatform.rawValue)
        
        // Extract clean content for the tool result
        let cleanResult = extractCleanContent(from: result.result, tool: tool)
        
        // Convert markdown to attributed string
        let attributedResult = convertMarkdownToAttributedString(cleanResult)
        
        let assistantMessage = AIMessage(role: "assistant", content: attributedResult)
        
        await MainActor.run {
            modelContext.insert(assistantMessage)
            messages.append(assistantMessage)
            currentConversation?.messages?.append(assistantMessage)
            isLoading = false
            
            // Save after adding quick tool message
            try? modelContext.save()
        }
    }
    
    func clearMessages() {
        messages.removeAll()
        currentConversation = nil
        selectedConversation = nil
    }
    
    // MARK: - Message Editing
    
    func editAndRegenerateMessage(_ messageToEdit: AIMessage, newContent: String, modelContext: ModelContext) {
        guard let messageIndex = messages.firstIndex(where: { $0.id == messageToEdit.id }) else {
            return
        }
        
        // Update the message content
        messageToEdit.content = newContent
        messageToEdit.timestamp = Date()
        
        // Remove all messages after the edited one (to regenerate from this point)
        let messagesToRemove = messages.suffix(from: messageIndex + 1)
        
        // Remove from conversation
        if let conversation = currentConversation {
            for message in messagesToRemove {
                if let conversationMessages = conversation.messages,
                   let idx = conversationMessages.firstIndex(where: { $0.id == message.id }) {
                    conversation.messages?.remove(at: idx)
                }
                modelContext.delete(message)
            }
        }
        
        // Remove from local messages array
        messages.removeSubrange((messageIndex + 1)..<messages.count)
        
        // Save changes
        try? modelContext.save()
        
        // Track if this is the first message in the conversation
        let isFirstMessage = messageIndex == 0
        
        // Regenerate AI response
        isLoading = true
        errorMessage = nil
        
        _Concurrency.Task {
            await processMessage(newContent, modelContext: modelContext, isFirstMessage: isFirstMessage)
        }
    }
    
    // MARK: - Conversation Management
    
    func loadConversation(_ conversation: AIConversation, modelContext: ModelContext) -> Bool {
        // Check if there are unsaved messages in the current conversation
        if let current = currentConversation, !messages.isEmpty {
            // Check if messages have been saved
            let savedMessageIDs = Set(current.messages?.compactMap { $0.id } ?? [])
            let currentMessageIDs = Set(messages.map { $0.id })
            
            // If there are messages not in saved messages, they're unsaved
            if !currentMessageIDs.isSubset(of: savedMessageIDs) {
                return false // Need to handle unsaved changes
            }
        }
        
        // Load the conversation
        currentConversation = conversation
        selectedConversation = conversation
        
        // Load messages
        if let conversationMessages = conversation.messages {
            messages = conversationMessages
        } else {
            messages = []
        }
        
        // Auto-generate summary if conditions are met
        if let messages = conversation.messages,
           messages.count >= 5,
           conversation.summary == nil || conversation.lastSummaryGeneratedAt == nil {
            _Concurrency.Task {
                await generateSummary(for: conversation, modelContext: modelContext)
            }
        }
        
        return true // Successfully loaded
    }
    
    func generateAndSetTitle(from firstMessage: String, conversation: AIConversation, modelContext: ModelContext) async {
        do {
            let title = try await geminiService.generateConversationTitle(from: firstMessage)
            
            await MainActor.run {
                conversation.title = title
                try? modelContext.save()
            }
            
            // Auto-generate tags after title is set
            await autoTag(conversation, modelContext: modelContext)
        } catch {
            print("Failed to generate title: \(error)")
        }
    }
    
    func renameConversation(_ conversation: AIConversation, newTitle: String, modelContext: ModelContext) {
        guard !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        conversation.title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to rename conversation: \(error)")
        }
    }
    
    func deleteConversation(_ conversation: AIConversation, modelContext: ModelContext) {
        // Clear if this was the current conversation
        if currentConversation?.id == conversation.id {
            clearMessages()
        }
        
        // Delete from context
        modelContext.delete(conversation)
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete conversation: \(error)")
        }
    }
    
    func togglePin(_ conversation: AIConversation, modelContext: ModelContext) {
        conversation.isPinned.toggle()
        conversation.pinnedAt = conversation.isPinned ? Date() : nil
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to toggle pin: \(error)")
        }
    }
    
    func generateSummary(for conversation: AIConversation, modelContext: ModelContext) async {
        guard let messages = conversation.messages, !messages.isEmpty else { return }
        
        do {
            let summary = try await geminiService.generateConversationSummary(messages: messages)
            
            await MainActor.run {
                conversation.summary = summary
                conversation.lastSummaryGeneratedAt = Date()
                
                do {
                    try modelContext.save()
                } catch {
                    print("Failed to save summary: \(error)")
                }
            }
        } catch {
            print("Failed to generate summary: \(error)")
        }
    }
    
    func refreshSummary(_ conversation: AIConversation, modelContext: ModelContext) async {
        await generateSummary(for: conversation, modelContext: modelContext)
    }
    
    func autoTag(_ conversation: AIConversation, modelContext: ModelContext) async {
        guard let title = conversation.title else { return }
        
        do {
            let tags = try await geminiService.categorizeConversation(
                title: title,
                summary: conversation.summary
            )
            
            await MainActor.run {
                conversation.tags = tags
                
                do {
                    try modelContext.save()
                } catch {
                    print("Failed to save tags: \(error)")
                }
            }
        } catch {
            print("Failed to generate tags: \(error)")
        }
    }
    
    func exportToDraft(messages: [AIMessage], conversation: AIConversation, modelContext: ModelContext) -> Draft {
        // Extract all assistant messages
        let assistantMessages = messages.filter { $0.role == "assistant" }
        let content = assistantMessages.compactMap { $0.content }.joined(separator: "\n\n")
        
        // Create draft with conversation title as notes
        let draft = Draft(
            caption: content,
            tags: conversation.tags,
            notes: "From AI Conversation: \(conversation.title ?? "Untitled")"
        )
        
        modelContext.insert(draft)
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save draft: \(error)")
        }
        
        return draft
    }
    
    func filteredConversations(_ conversations: [AIConversation]) -> [AIConversation] {
        var filtered = conversations
        
        // Filter by date
        filtered = filterByDate(filtered)
        
        // Filter by tags
        if !selectedTags.isEmpty {
            filtered = filtered.filter { conversation in
                let conversationTags = Set(conversation.tags)
                return !conversationTags.isDisjoint(with: selectedTags)
            }
        }
        
        // Filter by search text
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let searchLower = searchText.lowercased()
            filtered = filtered.filter { conversation in
                // Search in title
                if let title = conversation.title, title.lowercased().contains(searchLower) {
                    return true
                }
                
                // Search in summary
                if let summary = conversation.summary, summary.lowercased().contains(searchLower) {
                    return true
                }
                
                // Search in message content
                if let messages = conversation.messages {
                    return messages.contains { message in
                        guard let content = message.content else { return false }
                        return content.lowercased().contains(searchLower)
                    }
                }
                
                return false
            }
        }
        
        // Sort: Pinned first, then by date
        filtered.sort { conversation1, conversation2 in
            if conversation1.isPinned != conversation2.isPinned {
                return conversation1.isPinned
            }
            guard let date1 = conversation1.createdAt, let date2 = conversation2.createdAt else {
                return false
            }
            return date1 > date2
        }
        
        return filtered
    }
    
    private func filterByDate(_ conversations: [AIConversation]) -> [AIConversation] {
        let calendar = Calendar.current
        let now = Date()
        
        return conversations.filter { conversation in
            guard let createdAt = conversation.createdAt else { return false }
            
            switch selectedDateFilter {
            case .all:
                return true
                
            case .today:
                return calendar.isDateInToday(createdAt)
                
            case .thisWeek:
                if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) {
                    return createdAt >= weekAgo
                }
                return false
                
            case .thisMonth:
                return calendar.isDate(createdAt, equalTo: now, toGranularity: .month)
                
            case .older:
                if let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) {
                    return createdAt < monthAgo
                }
                return false
            }
        }
    }
    
    func generateChatSummary() async {
        guard let conversation = currentConversation,
              let conversationMessages = conversation.messages,
              conversationMessages.count >= 10 else { return }
        
        do {
            let summary = try await geminiService.summarizeRecentMessages(conversationMessages, count: 15)
            
            // Insert as system message
            let systemMessage = AIMessage(
                role: "assistant",
                content: "📋 **Chat Summary**\n\n\(summary)",
                isSystemMessage: true
            )
            
            await MainActor.run {
                self.messages.append(systemMessage)
                conversation.messages?.append(systemMessage)
            }
        } catch {
            print("Failed to generate chat summary: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func buildEmotionalNarrative(from messages: [AIMessage]) -> String? {
        // Analyze recent messages (last 5-10) for emotional flow
        let recentMessages = Array(messages.suffix(min(10, messages.count)))
        
        guard !recentMessages.isEmpty else { return nil }
        
        // Filter messages with emotional data
        let emotionalMessages = recentMessages.filter { message in
            guard let emotion = message.emotion, !emotion.isEmpty else { return false }
            return message.emotionIntensity > 0.1
        }
        
        guard emotionalMessages.count >= 2 else { return nil }
        
        // Detect emotional trajectory
        let emotionScores = emotionalMessages.map { $0.emotionScore }
        let avgScore = emotionScores.reduce(0.0, +) / Double(emotionScores.count)
        
        // Get dominant emotions
        var emotionCounts: [String: Int] = [:]
        for message in emotionalMessages {
            if let emotion = message.emotion {
                emotionCounts[emotion, default: 0] += 1
            }
        }
        
        let dominantEmotions = emotionCounts.sorted { $0.value > $1.value }.prefix(2).map { $0.key }
        
        // Build narrative
        var narrative = "Conversation Emotional Context: "
        
        if avgScore > 0.3 {
            narrative += "The discussion has been flowing with positive energy"
        } else if avgScore < -0.3 {
            narrative += "The conversation has touched on challenging topics"
        } else {
            narrative += "The exchange has maintained a balanced, thoughtful tone"
        }
        
        if !dominantEmotions.isEmpty {
            narrative += ", with recurring \(dominantEmotions.joined(separator: " and ")) themes"
        }
        
        // Detect emotional shift
        if emotionalMessages.count >= 3 {
            let recentThree = Array(emotionalMessages.suffix(3))
            let firstScore = recentThree.first?.emotionScore ?? 0
            let lastScore = recentThree.last?.emotionScore ?? 0
            let shift = lastScore - firstScore
            
            if abs(shift) > 0.5 {
                if shift > 0 {
                    narrative += ". Recent messages show a shift toward more positive energy"
                } else {
                    narrative += ". The tone has become more serious or concerned recently"
                }
            }
        }
        
        narrative += "."
        return narrative
    }
    
    private func convertMarkdownToAttributedString(_ markdown: String) -> String {
        let normalizedNewlines = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalizedNewlines.components(separatedBy: .newlines)
        var output: [String] = []
        var previousBlank = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if !previousBlank && !output.isEmpty {
                    output.append("")
                }
                previousBlank = true
                continue
            }
            previousBlank = false
            if trimmed.hasPrefix("•") {
                let content = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                output.append("- " + content)
            } else if trimmed.hasPrefix("▪") || trimmed.hasPrefix("◦") {
                let content = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                output.append("- " + content)
            } else {
                output.append(line)
            }
        }
        return output.joined(separator: "\n")
    }
    
    private func extractCleanContent(from text: String, tool: AITool) -> String {
        // Extract only the valid content based on the tool used
        var content = text
        
        switch tool {
        case .generateCaptions:
            // For hooks, extract just the numbered list items
            let lines = content.components(separatedBy: .newlines)
            let hookLines = lines.filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return trimmed.hasPrefix("1.") || trimmed.hasPrefix("2.") || trimmed.hasPrefix("3.") || 
                       trimmed.hasPrefix("4.") || trimmed.hasPrefix("5.") || trimmed.hasPrefix("•") ||
                       trimmed.hasPrefix("-") || trimmed.hasPrefix("*")
            }
            if !hookLines.isEmpty {
                content = hookLines.joined(separator: "\n")
            } else {
                // Remove any explanations or additional text after the actual caption
                if let firstDoubleNewline = content.range(of: "\n\n") {
                    content = String(content[..<firstDoubleNewline.lowerBound])
                }
                
                // Remove any prefix text like "Caption:" or "Improved text:"
                if let colonIndex = content.firstIndex(of: ":") {
                    let afterColon = content.index(after: colonIndex)
                    if !content[afterColon...].trimmingCharacters(in: .whitespaces).isEmpty {
                        content = String(content[afterColon...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
            
        case .improveText:
            // Remove any explanations or additional text after the actual caption
            if let firstDoubleNewline = content.range(of: "\n\n") {
                content = String(content[..<firstDoubleNewline.lowerBound])
            }
            
            // Remove any prefix text like "Improved text:"
            if let colonIndex = content.firstIndex(of: ":") {
                let afterColon = content.index(after: colonIndex)
                if !content[afterColon...].trimmingCharacters(in: .whitespaces).isEmpty {
                    content = String(content[afterColon...]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
        case .suggestHashtags:
            // For hashtags, extract just the hashtags themselves
            let regex = try? NSRegularExpression(pattern: #"#[\w]+"#, options: [])
            let nsString = content as NSString
            let matches = regex?.matches(in: content, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
            
            if !matches.isEmpty {
                let hashtags = matches.compactMap { result -> String? in
                    let range = result.range(at: 0)
                    guard range.location != NSNotFound else { return nil }
                    return nsString.substring(with: range)
                }
                content = hashtags.joined(separator: " ")
            }
            
        default:
            // For other tools, just clean up the content
            break
        }
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
