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
            return
        }
        
        let userMessage = AIMessage(role: "user", content: text)
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
            
            // Check for execution intent first
            if let executionIntent = try? await geminiService.detectExecutionIntent(input: text) {
                await executeIntent(executionIntent, modelContext: modelContext, isFirstMessage: isFirstMessage)
                return
            }
            
            // Convert conversation messages to ModelContent for context
            let conversationModelContent: [ModelContent]? = await geminiService.convertMessagesToModelContent(messages)
            
            // Use Gemini with app context for app-smart responses
            let response = try await geminiService.generateResponseWithAppContext(
                for: text,
                appContext: appContext,
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
            }
        }
    }
    
    private func executeIntent(_ intent: GeminiService.ExecutionIntent, modelContext: ModelContext, isFirstMessage: Bool) async {
        let executionService = AIExecutionService.shared
        
        do {
            var result: AIExecutionService.ExecutionResult
            
            switch intent.operation {
            case .archiveTasks:
                let criteria = AIExecutionService.ArchiveCriteria(rawValue: intent.criteria ?? "completed") ?? .completed
                result = try await executionService.archiveTasks(
                    criteria: criteria,
                    daysAgo: intent.daysAgo,
                    projectId: nil,
                    context: modelContext
                )
                
            case .summarizePosts:
                let filter = AIExecutionService.PostFilter(rawValue: intent.postFilter ?? "all") ?? .all
                result = try await executionService.summarizePosts(
                    filter: filter,
                    filterValue: intent.filterValue,
                    context: modelContext
                )
                
            case .generateReport:
                let reportType = AIExecutionService.ReportType(rawValue: intent.reportType ?? "weekly") ?? .weekly
                result = try await executionService.generateProgressReport(
                    type: reportType,
                    context: modelContext
                )
                
            case .predictScheduling:
                result = try await executionService.predictSchedulingNeeds(
                    daysAhead: intent.daysAhead ?? 7,
                    context: modelContext
                )
            }
            
            // Display execution result
            let resultMessage = result.asMarkdown()
            let attributedResult = convertMarkdownToAttributedString(resultMessage)
            
            let assistantMessage = AIMessage(role: "assistant", content: attributedResult)
            
            await MainActor.run {
                modelContext.insert(assistantMessage)
                messages.append(assistantMessage)
                currentConversation?.messages?.append(assistantMessage)
                isLoading = false
            }
            
            // Generate title if this is the first message
            if isFirstMessage, let conversation = currentConversation {
                await generateAndSetTitle(from: "Execute \(intent.operation.rawValue)", conversation: conversation, modelContext: modelContext)
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
            }
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
        }
    }
    
    func clearMessages() {
        messages.removeAll()
        currentConversation = nil
        selectedConversation = nil
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
    
    private func convertMarkdownToAttributedString(_ markdown: String) -> String {
        // Basic markdown to rich text conversion
        var result = markdown
        
        // Bold **text**
        result = result.replacingOccurrences(
            of: #"\*\*([^*]+)\*\*"#,
            with: "$1",
            options: .regularExpression
        )
        
        // Italic *text*
        result = result.replacingOccurrences(
            of: #"(?<!\*)\*([^*]+)\*(?!\*)"#,
            with: "$1",
            options: .regularExpression
        )
        
        // Code `text`
        result = result.replacingOccurrences(
            of: #"`([^`]+)`"#,
            with: "$1",
            options: .regularExpression
        )
        
        // Headers # Text (process line by line)
        let lines = result.components(separatedBy: .newlines)
        result = lines.map { line in
            var processed = line
            // H3
            processed = processed.replacingOccurrences(
                of: #"^#{3}\s+(.+)$"#,
                with: "$1",
                options: .regularExpression
            )
            // H2
            processed = processed.replacingOccurrences(
                of: #"^#{2}\s+(.+)$"#,
                with: "$1",
                options: .regularExpression
            )
            // H1
            processed = processed.replacingOccurrences(
                of: #"^#\s+(.+)$"#,
                with: "$1",
                options: .regularExpression
            )
            // Lists
            processed = processed.replacingOccurrences(
                of: #"^[-*+]\s+(.+)$"#,
                with: "• $1",
                options: .regularExpression
            )
            return processed
        }.joined(separator: "\n")
        
        // Remove markdown links but keep text
        result = result.replacingOccurrences(
            of: #"\[([^\]]+)\]\([^\)]+\)"#,
            with: "$1",
            options: .regularExpression
        )
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
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
