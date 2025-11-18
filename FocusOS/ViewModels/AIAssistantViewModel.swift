//
//  AIAssistantViewModel.swift
//  FocusOS
//
//  AI Assistant View Model
//

import Foundation
import SwiftUI
import SwiftData
import FocusOSShared

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
    private let coreResponseService = CoreResponseService.shared
    private let aiSettings = AISettings.shared
    private let actionRouter = AIActionRouter.shared
    private let feedbackLogger = AIFeedbackLogger.shared
    private let creationService = WorkspaceObjectCreationService.shared
    private let actionReportService = ActionReportService.shared
    
    var messages: [AIMessage] = []
    var currentConversation: AIConversation?
    var selectedConversation: AIConversation?
    var inputText = ""
    var searchText = ""
    var selectedDateFilter: DateFilter = .all
    var selectedTags: Set<String> = []
    var conversationMode: ConversationMode = .operational
    var isLoading = false
    var errorMessage: String?
    var pendingImageAttachment: ImageAttachmentService.ImageAttachment?
    var pendingDocumentAttachment: DocumentAttachmentService.DocumentAttachment?
    var isScrolledToBottom: Bool = true
    
    // Research mode properties
    var researchModeActive: Bool = false
    var currentResearchAction: String?
    var currentResearchSourceCount: Int = 0
    
    // Vision pipeline processing states
    var processingVision: Bool = false
    var processingOCR: Bool = false
    var interpreting: Bool = false
    var visionContextTag: String? = nil // "Using on-device vision" or "Using fallback OCR"
    
    // Developer mode properties
    @ObservationIgnored private let devModeKey = "com.kosmicapps.focusos.auroraDevMode"
    var devModeActive: Bool {
        get {
            UserDefaults.standard.bool(forKey: devModeKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: devModeKey)
        }
    }
    
    private struct ResendPayload {
        let text: String
        let image: ImageAttachmentService.ImageAttachment?
        let document: DocumentAttachmentService.DocumentAttachment?
    }
    
    // Task cancellation support
    @ObservationIgnored private var currentResponseTask: _Concurrency.Task<Void, Never>?
    
    // Last message for retry functionality
    @ObservationIgnored private var lastUserMessage: (id: UUID, text: String, image: ImageAttachmentService.ImageAttachment?, document: DocumentAttachmentService.DocumentAttachment?)?
    @ObservationIgnored private var messagePayloadCache: [UUID: ResendPayload] = [:]
    @ObservationIgnored private var lastParsedIntent: ParsedIntent?
    @ObservationIgnored private var lastIntentMessageId: UUID?
    @ObservationIgnored private var lastRoutingDecision: ModelRoutingDecision?
    @ObservationIgnored private var retryModeActive = false
    
    var canRetry: Bool {
        lastUserMessage != nil
    }
    
    // Linked context from @ mentions
    var linkedContext: LinkedContext = LinkedContext()
    
    // Activity tracking for dynamic thinking indicator
    enum ActivityType {
        case warmingUp
        case thinking
        case analyzingDocument
        case analyzingImage
        case generatingResponse
        case creatingTasks
        case creatingProject
        case creatingNote
        case creatingPost
        case reflecting
        case searching
    }
    
    var currentActivity: ActivityType = .thinking
    
    // Track current source model for adaptive phrasing
    var currentSourceModel: SummarySource?
    
    // Micro-delay smoothing: debounced activity to prevent jitter
    private var debouncedActivity: ActivityType = .thinking
    @ObservationIgnored private var activityDebounceTask: _Concurrency.Task<Void, Never>?
    private var isFirstActivityUpdate = true
    
    private func updateActivity(_ newActivity: ActivityType) {
        currentActivity = newActivity
        
        // Cancel existing debounce task
        activityDebounceTask?.cancel()
        
        // For first update, set immediately to avoid delay
        if isFirstActivityUpdate {
            debouncedActivity = newActivity
            isFirstActivityUpdate = false
            return
        }
        
        // Debounce activity changes with 0.15s delay
        activityDebounceTask = _Concurrency.Task {
            try? await _Concurrency.Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds
            if !_Concurrency.Task.isCancelled {
                await MainActor.run {
                    debouncedActivity = newActivity
                }
            }
        }
    }
    
    var displayedActivity: ActivityType {
        debouncedActivity
    }
    
    // Status tracking for inline updates
    var currentStatus: String?
    private var pendingOperation: PendingOperation?
    private var lastLinkingSuggestionAt: Date?
    private var lastSocialIntentAt: Date?
    private let socialIntentCooldown: TimeInterval = 12.0
    private let workKeywordSet: Set<String> = [
        "task",
        "tasks",
        "todo",
        "to-do",
        "project",
        "projects",
        "due",
        "deadline",
        "plan",
        "plans",
        "planning",
        "remind",
        "reminder",
        "schedule",
        "focus",
        "prep",
        "draft"
    ]
    
    var isAIEnabled: Bool {
        aiSettings.isAIEnabled
    }
    
    // MARK: - Pending Operation Support
    private struct PendingOperation {
        let operation: ExecutionOperation
        let intent: ExecutionIntent
        var collectedFields: [ExecutionFieldKey: String]
        var remainingPrompts: [PendingField]
    }
    
    private struct PendingField {
        let key: ExecutionFieldKey
        let prompt: String
    }
    
    private enum ExecutionFieldKey: Hashable {
        case taskTitle
        case projectTitle
        case noteTitle
        case artifactTitle
        case postCaption
        case inboxContent
        case reminderTitle
        case reminderDate
    }
    
    // MARK: - Status Methods
    
    func updateStatus(_ message: String) {
        currentStatus = message
    }
    
    func clearStatus() {
        currentStatus = nil
    }
    
    func attachImage(_ attachment: ImageAttachmentService.ImageAttachment) {
        pendingDocumentAttachment = nil
        pendingImageAttachment = attachment
    }
    
    func clearPendingImage() {
        pendingImageAttachment = nil
    }

    func attachDocument(_ attachment: DocumentAttachmentService.DocumentAttachment) -> Bool {
        guard !isLoading else {
            return false
        }
        guard pendingDocumentAttachment == nil else {
            return false
        }
        pendingImageAttachment = nil
        pendingDocumentAttachment = attachment
        return true
    }

    func clearPendingDocument() {
        pendingDocumentAttachment = nil
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
        
        // Check for pending automation suggestions
        _Concurrency.Task {
            await checkAndShowPendingSuggestions(modelContext: modelContext)
        }
    }
    
    func sendMessage(
        _ text: String,
        modelContext: ModelContext,
        image: ImageAttachmentService.ImageAttachment? = nil,
        document: DocumentAttachmentService.DocumentAttachment? = nil
    ) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedImage = image ?? pendingImageAttachment
        let resolvedDocument = document ?? pendingDocumentAttachment
        let isRetryFlow = retryModeActive
        if !isRetryFlow {
            lastParsedIntent = nil
            lastIntentMessageId = nil
            lastRoutingDecision = nil
        }

        guard !trimmedText.isEmpty || resolvedImage != nil || resolvedDocument != nil else { return }

        // Clear input immediately when sending (not waiting for async completion)
        inputText = ""

        if resolvedImage != nil && resolvedDocument != nil {
            let warning = AIMessage(
                role: "assistant",
                content: "I can handle one attachment at a time. Mind sending either the document or the image separately?"
            )
            modelContext.insert(warning)
            messages.append(warning)
            currentConversation?.messages?.append(warning)
            try? modelContext.save()
            return
        }
        
        // Initialize conversation if needed
        if currentConversation == nil {
            initializeConversation(modelContext: modelContext)
            // Ensure conversation is saved before proceeding
            do {
                try modelContext.save()
            } catch {
                print("Failed to save conversation after initialization: \(error)")
            }
        }
        
        // Track if this is the first message in the conversation
        let isFirstMessage = (currentConversation?.messages?.count ?? 0) == 0
        isScrolledToBottom = true
        
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
        let emotionalSourceText = !text.isEmpty ? text : (resolvedDocument?.textPreview ?? "")
        let emotionalSnapshot = EmotionAnalyzer.analyzeTone(text: emotionalSourceText)
        
        let userMessage = AIMessage(
            role: "user",
            content: text,
            emotion: emotionalSnapshot.primaryEmotion.rawValue,
            emotionScore: emotionalSnapshot.valence,
            emotionIntensity: emotionalSnapshot.intensity
        )
        if let attachment = resolvedImage {
            userMessage.imageData = attachment.data
            userMessage.imageMimeType = attachment.mimeType
            userMessage.imageFileName = attachment.fileName
        }
        if let documentAttachment = resolvedDocument {
            userMessage.documentMimeType = documentAttachment.mimeType
            userMessage.documentFileName = documentAttachment.fileName
            userMessage.documentTextPreview = documentAttachment.textPreview
            userMessage.documentSourceURL = documentAttachment.sourceURL?.absoluteString
            if documentAttachment.persistOriginalData {
                userMessage.documentData = documentAttachment.originalData
            }
        }
        modelContext.insert(userMessage)
        messages.append(userMessage)
        currentConversation?.messages?.append(userMessage)
        messagePayloadCache[userMessage.id] = ResendPayload(
            text: text,
            image: resolvedImage,
            document: resolvedDocument
        )
        
        // Ensure conversation and user message are saved immediately so it appears in the list
        do {
            try modelContext.save()
        } catch {
            print("Failed to save conversation with user message: \(error)")
        }
        
        let typingStyle: TypingStyle
        if !trimmedText.isEmpty {
            typingStyle = StyleAnalyzer.analyzeStyle(text: text)
        } else {
            typingStyle = TypingStyle.neutral
        }
        let stylePreferences = fetchOrCreatePreferences(modelContext: modelContext)
        applyStyleSample(typingStyle, to: stylePreferences)
        stylePreferences.lastUserEmotion = emotionalSnapshot.primaryEmotion.rawValue
        let topicSource = !text.isEmpty ? text : (resolvedDocument?.textPreview ?? "")
        if let topic = StyleAnalyzer.primaryTopic(from: topicSource) {
            stylePreferences.lastConversationTopic = topic
        }
        stylePreferences.lastEmotionalUpdate = Date()
        try? modelContext.save()
        
        pendingImageAttachment = nil
        pendingDocumentAttachment = nil
        isLoading = true
        errorMessage = nil
        
        // Store last message for retry functionality
        lastUserMessage = (id: userMessage.id, text: trimmedText, image: resolvedImage, document: resolvedDocument)
        
        // Cancel any existing task
        currentResponseTask?.cancel()
        
        // Create new task and store it
        let task: _Concurrency.Task<Void, Never> = _Concurrency.Task {
            if let attachment = resolvedDocument {
                    updateActivity(.analyzingDocument)
                await handleDocumentMessage(
                    text: trimmedText,
                    documentAttachment: attachment,
                    userMessage: userMessage,
                    modelContext: modelContext,
                    isFirstMessage: isFirstMessage,
                    typingStyle: typingStyle,
                    stylePreferences: stylePreferences
                )
                return
            }
            if let attachment = resolvedImage {
                    updateActivity(.analyzingImage)
                await handleImageMessage(
                    text: trimmedText,
                    imageAttachment: attachment,
                    userMessage: userMessage,
                    modelContext: modelContext,
                    isFirstMessage: isFirstMessage,
                    typingStyle: typingStyle,
                    stylePreferences: stylePreferences
                )
                return
            }
            if await handlePendingOperationIfNeeded(with: text, modelContext: modelContext, isFirstMessage: isFirstMessage) {
                return
            }
            // DISABLED: Creation intent detection is too aggressive and constantly asks about creating tasks
            // Only create items when explicitly requested through conversational flow
            
            // Try preference update intent
            if let prefUpdate = try? await coreResponseService.inferPreferenceUpdate(input: text) {
                await MainActor.run {
                    // Fetch or create preferences
                    let prefs: UserPreferences
                    prefs = fetchOrCreatePreferences(modelContext: modelContext)
                    if let hours = prefUpdate.preferredPostingHours, !hours.isEmpty {
                        prefs.preferredPostingHours = hours
                    }
                    if let platforms = prefUpdate.defaultPlatforms, !platforms.isEmpty {
                        // Platforms removed - no longer used
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
                    currentActivity = .generatingResponse
                await processMessage(
                    text,
                    modelContext: modelContext,
                    isFirstMessage: isFirstMessage,
                    currentStyle: typingStyle,
                    styleProfile: stylePreferences
                )
                return
            }
            
            // REMOVED: Scheduling intent picker - will auto-schedule in processMessage if needed
            
                updateActivity(.generatingResponse)
            await processMessage(
                text,
                modelContext: modelContext,
                isFirstMessage: isFirstMessage,
                currentStyle: typingStyle,
                styleProfile: stylePreferences
            )
        }
        currentResponseTask = task
    }
    
    private func processMessage(
        _ text: String,
        modelContext: ModelContext,
        isFirstMessage: Bool = false,
        currentStyle: TypingStyle? = nil,
        styleProfile: UserPreferences? = nil
    ) async {
        do {
            // Check for Developer Mode toggle commands first
            let textLower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if textLower == "/aurora devmode on" {
                await MainActor.run {
                    devModeActive = true
                    let message = AIMessage(
                        role: "assistant",
                        content: "Developer Mode enabled. I can explain reasoning more deeply and discuss technical concepts when helpful."
                    )
                    modelContext.insert(message)
                    messages.append(message)
                    currentConversation?.messages?.append(message)
                    try? modelContext.save()
                }
                return
            } else if textLower == "/aurora devmode off" {
                await MainActor.run {
                    devModeActive = false
                    let message = AIMessage(
                        role: "assistant",
                        content: "Developer Mode disabled. Back to calm and concise responses."
                    )
                    modelContext.insert(message)
                    messages.append(message)
                    currentConversation?.messages?.append(message)
                    try? modelContext.save()
                }
                return
            }
            
            // Check for REFLECTION intent first (introspective queries about patterns/state)
            if let reflectionIntent = try? await coreResponseService.detectReflectionIntent(input: text) {
                updateActivity(.reflecting)
                await processReflection(
                    reflectionIntent,
                    originalQuery: text,
                    modelContext: modelContext,
                    isFirstMessage: isFirstMessage,
                    currentStyle: currentStyle,
                    styleProfile: styleProfile
                )
                return
            }
            
            // Then check for execution intent (action-oriented commands)
            // Parse @ mentions and resolve them to linked context
            let mentions = MentionParser.parseMentions(from: text)
            var resolvedLinkedContext = LinkedContext()
            
            // Check for @web mentions and perform web search
            var webSearchQuery: String? = nil
            for mention in mentions {
                if MentionParser.isWebSearchMention(mention) {
                    if let query = MentionParser.extractWebSearchQuery(from: text, mention: mention) {
                        webSearchQuery = query
                    } else {
                        // If no query provided, use the rest of the message as query
                        let remainingText = text.replacingOccurrences(of: mention.fullText, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        webSearchQuery = remainingText.isEmpty ? nil : remainingText
                    }
                    break // Only handle first @web mention
                }
            }
            
            // If web search is requested, perform it and include results in context
            var webSearchResults: String? = nil
            var webSearchFailed = false
            var webSearchResult: WebSearchResult? = nil
            if let query = webSearchQuery {
                updateActivity(.searching)
                do {
                    let searchResult = try await WebSearchService.shared.searchWeb(query: query)
                    webSearchResult = searchResult
                    
                    // Format search results naturally for Aurora to incorporate
                    var resultsText = ""
                    
                    if let summary = searchResult.summary, !summary.isEmpty {
                        resultsText += summary
                        if !searchResult.results.isEmpty {
                            resultsText += "\n\n"
                        }
                    }
                    
                    if !searchResult.results.isEmpty {
                        for (index, result) in searchResult.results.prefix(3).enumerated() {
                            if index > 0 { resultsText += "\n" }
                            resultsText += "• \(result.title)"
                            if let snippet = result.snippet, !snippet.isEmpty {
                                resultsText += " — \(snippet)"
                            }
                            resultsText += " (\(result.url))"
                        }
                    }
                    
                    webSearchResults = resultsText.isEmpty ? nil : resultsText
                } catch {
                    // If web search fails, mark it as failed so we can handle it appropriately
                    webSearchFailed = true
                    print("Web search error: \(error.localizedDescription)")
                    
                    // Ensure conversation is saved even if web search fails
                    await MainActor.run {
                        do {
                            try modelContext.save()
                        } catch {
                            print("Failed to save conversation after web search error: \(error)")
                        }
                    }
                }
            }
            
            // Resolve other mentions to actual objects (skip @web)
            // Use MentionService for better resolution (handles both structured and plain mentions)
            let resolvedMentions = MentionService.shared.resolveAllMentions(
                from: text,
                modelContext: modelContext
            )
            
            // Add resolved mentions to linked context
            for resolved in resolvedMentions {
                resolvedLinkedContext.addLinkedObject(
                    type: resolved.type,
                    id: resolved.id,
                    mentionText: "@\(resolved.displayName)",
                    displayName: resolved.displayName
                )
            }
            
            // Also handle plain mentions for backward compatibility
            for mention in mentions {
                if MentionParser.isWebSearchMention(mention) {
                    continue // Skip @web mentions
                }
                
                // Skip if already resolved by MentionService
                if resolvedMentions.contains(where: { $0.displayName.lowercased() == mention.mentionText.lowercased() }) {
                    continue
                }
                
                let results = WorkspaceObjectSearchService.shared.search(
                    query: mention.mentionText,
                    modelContext: modelContext,
                    limit: 1
                )
                
                if let firstResult = results.first {
                    resolvedLinkedContext.addLinkedObject(
                        type: firstResult.type,
                        id: firstResult.id,
                        mentionText: mention.fullText,
                        displayName: firstResult.title
                    )
                }
            }
            
            // Use resolved linked context for deterministic parsing
            if let parsedIntent = try? await coreResponseService.parsedIntent(
                for: text,
                linkedContext: resolvedLinkedContext.isEmpty ? nil : resolvedLinkedContext,
                modelContext: modelContext
            ) {
                lastParsedIntent = parsedIntent
                // Find the last user message from the messages array
                if let lastUserMsg = await MainActor.run(body: { messages.last(where: { $0.role == "user" }) }) {
                    lastIntentMessageId = lastUserMsg.id
                    ConversationFlowService.shared.cacheIntent(parsedIntent, for: lastUserMsg.id)
                }
                #if DEBUG
                print("[AIAssistantViewModel] Parsed intent \(parsedIntent.action.rawValue) → \(parsedIntent.object.rawValue)")
                #endif
                switch parsedIntent.object {
                case .task:
                    updateActivity(.creatingTasks)
                case .project:
                    updateActivity(.creatingProject)
                case .note:
                    updateActivity(.creatingNote)
                case .post:
                    updateActivity(.creatingPost)
                default:
                    updateActivity(.thinking)
                }
                if await executeIntent(
                    parsedIntent,
                    modelContext: modelContext,
                    isFirstMessage: isFirstMessage,
                    messageText: text,
                    payloadContext: nil
                ) {
                    return
                }
            }
            
            updateActivity(.generatingResponse)
            
            // Build AI context - transition state will be added after tone detection
            var (appContext, payloadContext, conversationModelContent) = try await buildAIContext(
                for: text,
                modelContext: modelContext,
                currentStyle: currentStyle,
                styleProfile: styleProfile
            )
            recordIntent(from: payloadContext)
            let contextFreshness = AppContextService.shared.contextFreshness()
            let confidenceSnapshot = ConfidenceScorer.evaluate(
                recallSnippets: payloadContext.recall,
                intentSummary: payloadContext.intentClusters,
                contextAge: contextFreshness
            )
            
            // Convert conversation messages to ConversationMessage format for CoreResponseService
            // conversationModelContent is already [ConversationMessage]? from buildAIContext
            let conversationMessages: [ConversationMessage]? = conversationModelContent
            
            // Use CoreResponseService with app context for app-smart responses
            // Include web search results in the user input if available, so Aurora can naturally incorporate them
            // CRITICAL: Completely remove all @web mentions so Aurora never sees or references them in her response
            let userInputWithWebSearch: String
            if let webResults = webSearchResults, !webResults.isEmpty, let query = webSearchQuery {
                // Remove @web mention and query completely - use regex to catch all variations
                // Pattern: @web followed by optional space and then the query text (handles "@web query" and "@webquery")
                var cleanText = text
                // First, try to match @web followed by the query (with or without space)
                let escapedQuery = NSRegularExpression.escapedPattern(for: query)
                if let regex = try? NSRegularExpression(pattern: "@web\\s*\(escapedQuery)", options: .caseInsensitive) {
                    let range = NSRange(cleanText.startIndex..<cleanText.endIndex, in: cleanText)
                    cleanText = regex.stringByReplacingMatches(in: cleanText, options: [], range: range, withTemplate: "")
                }
                // Also remove any remaining @web mentions (standalone or with other text)
                // Pattern: @web followed by any non-whitespace characters
                if let regex = try? NSRegularExpression(pattern: "@web\\S*", options: .caseInsensitive) {
                    let range = NSRange(cleanText.startIndex..<cleanText.endIndex, in: cleanText)
                    cleanText = regex.stringByReplacingMatches(in: cleanText, options: [], range: range, withTemplate: "")
                }
                cleanText = cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Format as a natural question with search results as context
                // Don't mention "web search" or "@web" - just provide the information naturally
                let queryText = cleanText.isEmpty ? query : cleanText
                userInputWithWebSearch = "\(queryText)\n\n\(webResults)"
            } else if webSearchFailed, let query = webSearchQuery {
                // Web search failed - remove @web mention completely
                var cleanText = text
                // Remove @web followed by query (with or without space)
                let escapedQuery = NSRegularExpression.escapedPattern(for: query)
                if let regex = try? NSRegularExpression(pattern: "@web\\s*\(escapedQuery)", options: .caseInsensitive) {
                    let range = NSRange(cleanText.startIndex..<cleanText.endIndex, in: cleanText)
                    cleanText = regex.stringByReplacingMatches(in: cleanText, options: [], range: range, withTemplate: "")
                }
                // Remove any remaining @web mentions
                if let regex = try? NSRegularExpression(pattern: "@web\\S*", options: .caseInsensitive) {
                    let range = NSRange(cleanText.startIndex..<cleanText.endIndex, in: cleanText)
                    cleanText = regex.stringByReplacingMatches(in: cleanText, options: [], range: range, withTemplate: "")
                }
                cleanText = cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Format as a normal question
                let queryText = cleanText.isEmpty ? query : cleanText
                userInputWithWebSearch = queryText
            } else {
                // No web search requested or no results - remove @web if present
                var cleanText = text
                // Remove @web and everything after it until whitespace/newline
                if let regex = try? NSRegularExpression(pattern: "@web\\S*", options: .caseInsensitive) {
                    let range = NSRange(cleanText.startIndex..<cleanText.endIndex, in: cleanText)
                    cleanText = regex.stringByReplacingMatches(in: cleanText, options: [], range: range, withTemplate: "")
                }
                cleanText = cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
                userInputWithWebSearch = cleanText.isEmpty ? text : cleanText
            }
            
            // Detect research mode from input or existing flag
            let isResearchMode = text.lowercased().hasPrefix("/research") ||
                               text.lowercased().contains("research mode") ||
                               (payloadContext.metadata["isResearchMode"] as? Bool ?? false)
            
            // Set research mode in payload context metadata for CoreResponseService
            if isResearchMode {
                payloadContext.metadata["isResearchMode"] = true
            }
            
            let intentCluster = payloadContext.intentClusters?.primaryCluster
            let routingConfidence = payloadContext.intentClusters?.confidence ?? confidenceSnapshot.score
            let messageLength = userInputWithWebSearch.count
            
            var routingDecision = await ModelRoutingEngine.shared.selectModel(
                input: userInputWithWebSearch,
                intentCluster: intentCluster,
                confidence: routingConfidence,
                messageLength: messageLength,
                userStyle: currentStyle,
                conversationId: nil,
                isResearchMode: isResearchMode,
                retryModeActive: retryModeActive,
                previousDecision: lastRoutingDecision,
                isCreationAction: false
            )
            
            if !(await OllamaBridgeService.shared.isModelReady(routingDecision.model)) {
                await MainActor.run {
                    updateActivity(.warmingUp)
                    updateStatus("\(ModelTierMap.displayName(for: routingDecision.model)) is spinning up.")
                }
                do {
                    try await OllamaBridgeService.shared.ensureModelReady(
                        model: routingDecision.model,
                        progressHandler: { message in
                            await MainActor.run {
                                self.updateStatus(message)
                            }
                        }
                    )
                    await MainActor.run {
                        self.clearStatus()
                    }
                } catch {
                    let fallbackModel = ModelTierMap.fallbackModel()
                    routingDecision = ModelRoutingDecision(
                        model: fallbackModel,
                        useThinking: false,
                        isCasual: true
                    )
                    await MainActor.run {
                        self.updateStatus("Gemma needs a little more time. Switching to \(ModelTierMap.displayName(for: fallbackModel)).")
                    }
                }
            }
            
            await MainActor.run {
                updateActivity(.generatingResponse)
            }
            lastRoutingDecision = routingDecision
            
            // Determine tone context based on conversation context
            let toneContext: AuroraTone? = await MainActor.run {
                // Check for emotional state from ARTE
                if let glassSystem = GlassColorSystem.active {
                    return AuroraToneKit.tone(for: glassSystem.emotionalState)
                }
                // Check time of day
                let hour = Calendar.current.component(.hour, from: Date())
                let timeOfDay: TimeOfDayContext = {
                    switch hour {
                    case 5..<9: return .morning
                    case 9..<12: return .lateMorning
                    case 12..<14: return .midday
                    case 14..<17: return .afternoon
                    case 17..<21: return .evening
                    default: return .night
                    }
                }()
                return AuroraToneKit.tone(for: timeOfDay)
            }
            
            // Extract user's last 3 messages and Aurora's last 2 tones for prediction
            let (userMessages, auroraTones): ([String], [AuroraTone]) = await MainActor.run {
                // Get user's last 3 messages
                let userMessages = messages
                    .filter { ($0.role ?? "") == "user" }
                    .suffix(3)
                    .compactMap { $0.content }
                
                // Get Aurora's last 2 tones
                let assistantMessages = messages.filter { ($0.role ?? "") == "assistant" }
                let auroraTones = assistantMessages
                    .suffix(2)
                    .compactMap { message -> AuroraTone? in
                        guard let toneString = message.tone else { return nil }
                        return AuroraTone(rawValue: toneString)
                    }
                
                return (userMessages, auroraTones)
            }
            
            // Get historical accuracy data, reliability profiles, and temporal emotional memory for adaptive weighting
            // Extract async calls outside MainActor.run
            let accuracyScores = ToneForecastService.shared.allToneAccuracyScores(modelContext: modelContext)
            
            // Build adaptive bias factors for potential transitions
            var biasFactors: [String: Double] = [:]
            if let lastTone = auroraTones.last {
                for tone in AuroraTone.allCases {
                    if tone != lastTone {
                        let biasFactor = ToneForecastService.shared.adaptiveBiasFactor(
                            predicted: lastTone,
                            actual: tone,
                            modelContext: modelContext
                        )
                        let pairKey = "\(lastTone.rawValue)_\(tone.rawValue)"
                        biasFactors[pairKey] = biasFactor
                    }
                }
            }
            
            // Get reliability profiles for all tones
            let allProfiles = await ToneFeedbackReinforcementEngine.shared.getAllProfiles(modelContext: modelContext)
            var profilesDict: [AuroraTone: ToneReliabilityProfile] = [:]
            for profile in allProfiles {
                if let tone = profile.toneValue {
                    profilesDict[tone] = profile
                }
            }
            
            // Get temporal emotional memory context
            let momentumForecast = await TemporalEmotionalMemory.shared.forecastEmotionalMomentum(modelContext: modelContext)
            let rollingBaseline = await TemporalEmotionalMemory.shared.rollingAverageBaseline(days: 7, modelContext: modelContext)
            
            // Convert TemporalEmotionalTrend to EmotionalTrend
            let emotionalMomentum: (momentum: Double, trend: EmotionalTrend, confidence: Double) = {
                let trend: EmotionalTrend = {
                    switch momentumForecast.trend {
                    case .positive: return .improving
                    case .negative: return .declining
                    case .neutral: return .stable
                    }
                }()
                return (momentumForecast.momentum, trend, momentumForecast.confidence)
            }()
            
            let toneAccuracyScores: [AuroraTone: Double]? = accuracyScores.isEmpty ? nil : accuracyScores
            let adaptiveBiasFactors: [String: Double]? = biasFactors.isEmpty ? nil : biasFactors
            let reliabilityProfiles: [AuroraTone: ToneReliabilityProfile]? = profilesDict.isEmpty ? nil : profilesDict
            
            // Get ERI for tone weighting adjustment
            let eriIndex = await AuroraEcosphericLayer.shared.getCurrentERI(modelContext: modelContext)
            
            // Predict next tone based on conversation patterns with historical accuracy, reliability, temporal emotional memory, and ERI weighting
            let tonePrediction = AuroraToneKit.predictNextTone(
                userMessages: userMessages,
                auroraTones: auroraTones,
                toneAccuracyScores: toneAccuracyScores,
                adaptiveBiasFactors: adaptiveBiasFactors,
                reliabilityProfiles: reliabilityProfiles,
                emotionalMomentum: emotionalMomentum,
                rollingBaseline: rollingBaseline,
                eriIndex: eriIndex
            )
            
            // Extract previous tone from conversation history for blending
            let previousTone: AuroraTone? = await MainActor.run {
                // Get the last assistant message's tone
                let assistantMessages = messages.filter { ($0.role ?? "") == "assistant" }
                guard let lastMessage = assistantMessages.last,
                      let toneString = lastMessage.tone,
                      let previous = AuroraTone(rawValue: toneString) else {
                    return nil
                }
                return previous
            }
            
            // Get AECI for default tone bias
            let aecIndex = await EmotionalContinuityEngine.shared.getCurrentAECI(modelContext: modelContext)
            let defaultToneBias = EmotionalContinuityEngine.shared.getDefaultToneBias(aecIndex: aecIndex)
            
            // Use prediction to bias tone selection if confidence is high enough
            // Also consider AECI default tone bias if no strong prediction
            let biasedToneContext: AuroraTone? = {
            // First, check if we have a strong prediction
            if let predicted = tonePrediction.predictedTone,
               tonePrediction.confidence >= 0.6 {
                // If prediction differs from current tone context, use it as bias
                // Blend prediction with current context based on confidence
                if let current = toneContext, predicted != current {
                    // High confidence (>0.8) = use prediction directly
                    // Medium confidence (0.6-0.8) = blend with current
                    if tonePrediction.confidence >= 0.8 {
                        return predicted
                    } else {
                        // Blend: favor prediction but keep some current context
                        return predicted // For now, use prediction if confidence is reasonable
                    }
                } else if toneContext == nil {
                    // No current tone - use prediction
                    return predicted
                }
            }
            
            // If no strong prediction, use AECI default tone bias if available
            if let defaultBias = defaultToneBias, toneContext == nil {
                return defaultBias
            }
            
            return toneContext
        }()
            
            // Detect tone transition and blend if needed
            // Also track transition state for gradual memory weighting
            // Use biased tone context if prediction was applied
            let (blendedTone, transitionState): (AuroraTone?, ToneTransitionState?) = await MainActor.run {
                let effectiveToneContext = biasedToneContext ?? toneContext
                guard let currentTone = effectiveToneContext else { return (effectiveToneContext, nil) }
                guard let previous = previousTone, previous != currentTone else {
                    // Check if we're in an active transition
                    if let lastState = currentConversation?.toneTransitionState, lastState.isActive {
                        // Continue the transition
                        let nextTurn = lastState.transitionTurn + 1
                        if nextTurn < 3 {
                            // Still transitioning - use transition tone
                            let fromTone = lastState.fromToneValue ?? previousTone ?? currentTone
                            let toTone = lastState.toToneValue ?? currentTone
                            let transition = AuroraToneKit.transitionTone(from: fromTone, to: toTone)
                            let intensity = lastState.transitionIntensity
                            let updatedState = ToneTransitionState(
                                fromTone: lastState.fromToneValue ?? currentTone,
                                toTone: lastState.toToneValue ?? currentTone,
                                transitionTone: transition,
                                transitionTurn: nextTurn,
                                transitionIntensity: intensity
                            )
                            return (transition, updatedState)
                        } else {
                            // Transition complete - use target tone
                            currentConversation?.toneTransitionState = nil
                            return (currentTone, nil)
                        }
                    }
                    return (currentTone, nil)
                }
                
                // New transition detected
                let transition = AuroraToneKit.transitionTone(from: previous, to: currentTone)
                let intensity = AuroraToneKit.calculateTransitionIntensity(from: previous, to: currentTone)
                let newState = ToneTransitionState(
                    fromTone: previous,
                    toTone: currentTone,
                    transitionTone: transition,
                    transitionTurn: 0, // Start of transition
                    transitionIntensity: intensity
                )
                return (transition, newState)
            }
            
            // Store transition state in conversation and add to payload context metadata
            await MainActor.run {
                currentConversation?.toneTransitionState = transitionState
                
                // Add transition state to payload context metadata for memory weighting
                if let transition = transitionState,
                   let transitionData = try? JSONEncoder().encode(transition),
                   let transitionString = String(data: transitionData, encoding: .utf8) {
                    payloadContext.metadata["toneTransitionState"] = transitionString
                }
            }
            
            // Use blended tone for response generation
            let effectiveTone = blendedTone ?? toneContext
            
            // Use prediction to bias response generation
            let predictedNextTone: AuroraTone? = tonePrediction.confidence >= 0.6 ? tonePrediction.predictedTone : nil
            
            var result = try await coreResponseService.generateResponseWithAppContext(
                for: userInputWithWebSearch,
                appContext: appContext,
                payloadContext: payloadContext,
                conversationMessages: conversationMessages,
                currentMessageStyle: currentStyle,
                userStyleProfile: styleProfile,
                confidence: confidenceSnapshot,
                modelContext: modelContext,
                preselectedDecision: routingDecision,
                toneContext: effectiveTone,
                predictedNextTone: predictedNextTone
            )
            
            var response = result.response
            
            // Don't prepend web search results - they're already in the context
            // Aurora will naturally incorporate them into the response
            
            // Apply typography emotion based on ARTE state
            if let glassSystem = GlassColorSystem.active {
                let typographyService = TypographyEmotionService.shared
                response = typographyService.applyEmotionalTypography(
                    response,
                    emotionalState: glassSystem.emotionalState,
                    intensity: glassSystem.emotionalIntensity
                )
            }
            
            // Check if this was an ambiguous query - if so, append data offer
            let isAmbiguous = await coreResponseService.isAmbiguousQuery(input: text)
            if isAmbiguous {
                response += "\n\nWant me to show your data? Just say \"show my data\" or \"visualize my patterns\" and I'll pull up the analytics."
            }
            
            // Create assistant message with streaming support
            // Include web search results if available
            let webSearchResultsForMessage: WebSearchResults? = webSearchResult.map { WebSearchResults(from: $0) }
            let webSearchConfidenceScore: Double? = webSearchResult?.confidence
            
            // Limit thinking content to 600-800 chars max for storage efficiency
            let limitedThinkingContent: String? = {
                guard let thinking = result.thinking, !thinking.isEmpty else { return nil }
                let maxLength = 700 // Target ~700 chars (middle of 600-800 range)
                if thinking.count > maxLength {
                    // Truncate at word boundary near the limit
                    let truncated = String(thinking.prefix(maxLength))
                    if let lastSpace = truncated.lastIndex(of: " ") {
                        return String(truncated[..<lastSpace]) + "..."
                    }
                    return truncated + "..."
                }
                return thinking
            }()
            
            // Store the effective (blended) tone in message metadata for visual styling
            let assistantMessage = AIMessage(
                role: "assistant",
                content: response,
                confidenceScore: confidenceSnapshot.score,
                webSearchResults: webSearchResultsForMessage,
                webSearchConfidence: webSearchConfidenceScore,
                thinkingContent: limitedThinkingContent,
                modelUsed: result.modelUsed,
                wasThinking: result.thinking != nil && !result.thinking!.isEmpty,
                tone: effectiveTone?.rawValue
            )
            
            await MainActor.run {
                modelContext.insert(assistantMessage)
                messages.append(assistantMessage)
                currentConversation?.messages?.append(assistantMessage)
                inputText = ""
                isLoading = false
                currentActivity = .thinking // Reset activity when done
                clearStatus()
                currentSourceModel = nil // Clear source model
                currentResponseTask = nil // Clear task reference
                
                // Record tone prediction outcome for feedback reinforcement
                if let predicted = predictedNextTone,
                   let actual = effectiveTone {
                    let outcomeSentiment = ToneForecastService.shared.inferOutcomeSentiment(
                        predictedTone: predicted,
                        actualTone: actual,
                        userMessage: text
                    )
                    
                    ToneForecastService.shared.recordPrediction(
                        predictedTone: predicted,
                        actualTone: actual,
                        outcomeSentiment: outcomeSentiment,
                        predictionConfidence: tonePrediction.confidence,
                        conversationId: currentConversation?.id,
                        messageId: assistantMessage.id,
                        modelContext: modelContext
                    )
                    
                    // Track conversation batch and process if complete
                    if let conversationId = currentConversation?.id {
                        let batchComplete = ToneFeedbackReinforcementEngine.shared.trackTurn(conversationId: conversationId)
                        if batchComplete {
                            // Process batch asynchronously
                            _Concurrency.Task {
                                await ToneFeedbackReinforcementEngine.shared.processBatch(
                                    conversationId: conversationId,
                                    modelContext: modelContext
                                )
                            }
                        }
                    }
                    
                    // Update temporal emotional memory epochs
                    _Concurrency.Task {
                        let today = Date()
                        let dailyEpoch = await TemporalEmotionalMemory.shared.createOrUpdateDailyEpoch(
                            for: today,
                            modelContext: modelContext
                        )
                        await TemporalEmotionalMemory.shared.aggregateMetricsIntoEpoch(
                            epoch: dailyEpoch,
                            modelContext: modelContext
                        )
                        
                        let weeklyEpoch = await TemporalEmotionalMemory.shared.createOrUpdateWeeklyEpoch(
                            for: today,
                            modelContext: modelContext
                        )
                        await TemporalEmotionalMemory.shared.aggregateMetricsIntoEpoch(
                            epoch: weeklyEpoch,
                            modelContext: modelContext
                        )
                        
                        // Calculate and update AECI weekly
                        if let aecHistory = await EmotionalContinuityEngine.shared.calculateWeeklyAECI(modelContext: modelContext) {
                            // Update GlassColorSystem with AECI
                            await MainActor.run {
                                if let glassSystem = GlassColorSystem.active {
                                    glassSystem.updateAECI(aecHistory.aecIndex, category: aecHistory.category)
                                }
                            }
                        }
                        
                        // Calculate and update ERI
                        if let eriHistory = await AuroraEcosphericLayer.shared.calculateERI(modelContext: modelContext) {
                            // Update GlassColorSystem with ERI
                            await MainActor.run {
                                if let glassSystem = GlassColorSystem.active {
                                    glassSystem.updateERI(eriHistory.eriIndex, category: eriHistory.category)
                                }
                            }
                        }
                        
                        // Calculate and update ERS
                        if let ersHistory = await AuroraMetaSymphony.shared.calculateERS(modelContext: modelContext) {
                            // Update GlassColorSystem with ERS
                            await MainActor.run {
                                if let glassSystem = GlassColorSystem.active {
                                    glassSystem.updateERS(ersHistory.ersIndex, category: ersHistory.category)
                                }
                            }
                        }
                        
                        // Calculate and update Luminance Field
                        if let lfHistory = await AuroraLuminara.shared.calculateLuminanceField(modelContext: modelContext) {
                            // LF automatically updates visual parameters
                            // No need to update GlassColorSystem as it's handled by LuminanceFieldVisualizer
                        }
                    }
                }
                
                // Save after adding messages
                try? modelContext.save()
            }
            
            // Generate title if this is the first message
            if isFirstMessage, let conversation = currentConversation {
                await generateAndSetTitle(from: text, conversation: conversation, modelContext: modelContext)
            }
            
            let suggestionPreferences: UserPreferences
            if let styleProfile {
                suggestionPreferences = styleProfile
            } else {
                suggestionPreferences = fetchOrCreatePreferences(modelContext: modelContext)
            }
            await offerLinkingSuggestionIfNeeded(modelContext: modelContext, stylePreferences: suggestionPreferences)
        } catch {
            // Check if this is an Ollama connection error
            let errorDesc = error.localizedDescription.lowercased()
            let isOllamaError = errorDesc.contains("ollama") || 
                                errorDesc.contains("connection failed") ||
                                errorDesc.contains("service unavailable") ||
                                errorDesc.contains("model not found")
            
            let errorContent: String
            if isOllamaError {
                errorContent = error.localizedDescription
            } else {
                errorContent = "I'm having trouble connecting to the AI service. Please check that Ollama is running and the `gemma3:4b` model is available."
            }
            
            // Handle errors
            let errorMessage = AIMessage(
                role: "assistant",
                content: errorContent
            )
            
            await MainActor.run {
                modelContext.insert(errorMessage)
                messages.append(errorMessage)
                currentConversation?.messages?.append(errorMessage)
                self.errorMessage = error.localizedDescription
                isLoading = false
                currentActivity = .thinking // Reset activity on error
                clearStatus()
                currentSourceModel = nil // Clear source model
                currentResponseTask = nil // Clear task reference
                
                // Save after adding error message
                try? modelContext.save()
            }
        }
    }

    private func buildAIContext(
        for text: String,
        modelContext: ModelContext,
        currentStyle: TypingStyle?,
        styleProfile: UserPreferences?
    ) async throws -> (String, AIPayloadContext, [ConversationMessage]?) {
        let appContext = try await AppContextService.shared.buildContextForAI(modelContext: modelContext)
        let compressionResult = await ConversationCompressionService.shared.compress(
            conversationId: currentConversation?.id,
            messages: messages
        )
        let contextMessages = compressionResult.retainedMessages.isEmpty ? messages : compressionResult.retainedMessages
        var conversationModelContent: [ConversationMessage]? = await coreResponseService.convertMessagesToConversationMessages(contextMessages)
        if let summary = compressionResult.summary {
            let summaryContent = ConversationMessage(
                role: "user",
                content: "Conversation so far (summary): \(summary)"
            )
            if var existing = conversationModelContent {
                existing.insert(summaryContent, at: 0)
                conversationModelContent = existing
            } else {
                conversationModelContent = [summaryContent]
            }
        }
        let recallSnippets = AIRecallService.shared.fetchRelevantSnippets(
            for: text,
            modelContext: modelContext,
            mode: conversationMode
        )
        let conversationReferencedIDs = recallSnippets.filter { $0.score >= 0.65 }.map { $0.objectId }
        if !conversationReferencedIDs.isEmpty {
            AIRecallService.shared.boostImportance(
                for: conversationReferencedIDs,
                amount: 0.0,
                engagementIncrement: 0.1,
                modelContext: modelContext
            )
        }
        var feedbackSummaries = feedbackLogger.recentSummaries(
            limit: 3,
            modelContext: modelContext
        )
        if let weeklySummary = feedbackLogger.weeklyActivitySummary(modelContext: modelContext),
           !feedbackSummaries.contains(where: { $0.title == weeklySummary.title }) {
            feedbackSummaries.insert(weeklySummary, at: 0)
        }
        let narrativeSummary = buildEmotionalNarrative(from: messages)
        let priorityItems = PriorityEngine.shared.getTopObjects(limit: 10, modelContext: modelContext)
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
        var liveThemes: [ConceptSummary]? = nil
        if AIConfigService.shared.config.featureFlags.narrativeEnabled {
            liveThemes = ConceptTracker.shared.getConceptSummaries(limit: 5, modelContext: modelContext)
        }
        let pastConversationSummaries = ConversationArchive.shared.getConversationSummariesForContext(
            excludingId: currentConversation?.id,
            limit: 5,
            modelContext: modelContext
        )
        let intentClusters = await ConversationArchive.shared.extractIntentClusters(
            excludingId: currentConversation?.id,
            limit: 10,
            modelContext: modelContext
        )
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
        let breadcrumbs: ConversationBreadcrumbs? = {
            guard let prefs = styleProfile else { return nil }
            if (prefs.lastUserEmotion ?? "").isEmpty && (prefs.lastConversationTopic ?? "").isEmpty {
                return nil
            }
            return ConversationBreadcrumbs(
                lastEmotion: prefs.lastUserEmotion,
                lastTopic: prefs.lastConversationTopic,
                lastUpdated: prefs.lastEmotionalUpdate
            )
        }()
        let cognitiveHealth = CognitiveHealthService.shared.snapshot(messages: messages, modelContext: modelContext)
        let payloadContext = AIPayloadContext(
            recall: recallSnippets,
            priorities: priorityItems,
            feedback: feedbackSummaries,
            focusSession: focusContext,
            liveThemes: liveThemes,
            pastConversations: pastConversationSummaries.isEmpty ? nil : pastConversationSummaries,
            memoryThemes: memoryThemes,
            narrativeSummary: narrativeSummary,
            intentClusters: intentClusters,
            conversationBreadcrumbs: breadcrumbs,
            cognitiveHealth: cognitiveHealth,
            metadata: [
                "phase": "6",
                "emotionalContinuity": "enabled",
                "cpsEnabled": "true",
                "focusModeEnabled": String(AIConfigService.shared.config.featureFlags.focusModeEnabled),
                "narrativeEnabled": String(AIConfigService.shared.config.featureFlags.narrativeEnabled),
                "crossConversationEnabled": "true",
                "memoryGraphEnabled": String(AIConfigService.shared.config.featureFlags.memoryGraphEnabled),
                "devModeActive": String(devModeActive)
            ]
        )
        return (appContext, payloadContext, conversationModelContent)
    }

    private func handleImageMessage(
        text: String,
        imageAttachment: ImageAttachmentService.ImageAttachment,
        userMessage: AIMessage,
        modelContext: ModelContext,
        isFirstMessage: Bool,
        typingStyle: TypingStyle,
        stylePreferences: UserPreferences
    ) async {
        let fallbackText = text.isEmpty ? "image attachment" : text
        do {
            let (appContext, payloadContext, conversationModelContent) = try await buildAIContext(
                for: fallbackText,
                modelContext: modelContext,
                currentStyle: typingStyle,
                styleProfile: stylePreferences
            )
            
            // Safety guard: Force isResearchMode = false for images regardless of conversation mode
            payloadContext.metadata["isResearchMode"] = false
            
            // Set initial processing state
            await MainActor.run {
                isLoading = true
                processingVision = true
                processingOCR = false
                interpreting = false
                visionContextTag = "Using on-device vision"
                currentActivity = .analyzingImage
            }
            
            recordIntent(from: payloadContext)
            let contextFreshness = AppContextService.shared.contextFreshness()
            let confidenceSnapshot = ConfidenceScorer.evaluate(
                recallSnippets: payloadContext.recall,
                intentSummary: payloadContext.intentClusters,
                contextAge: contextFreshness
            )
            
            // Update state to interpreting (Gemma layer)
            await MainActor.run {
                processingVision = false
                interpreting = true
                visionContextTag = nil // Will be set based on PipelineContext in result
            }
            
            let analysis = try await coreResponseService.analyzeImage(
                imageData: imageAttachment.data,
                mimeType: imageAttachment.mimeType,
                userPrompt: text.isEmpty ? nil : text,
                appContext: appContext,
                payloadContext: payloadContext,
                conversationMessages: conversationModelContent,
                currentMessageStyle: typingStyle,
                userStyleProfile: stylePreferences,
                confidence: confidenceSnapshot
            )
            await MainActor.run {
                let analysisText = analysis.summary
                userMessage.imageAnalysis = analysisText
                let assistantMessage = AIMessage(
                    role: "assistant",
                    content: analysisText,
                    confidenceScore: confidenceSnapshot.score
                )
                modelContext.insert(assistantMessage)
                messages.append(assistantMessage)
                currentConversation?.messages?.append(assistantMessage)
                AIRecallService.shared.indexImageAnalysis(
                    userMessage: userMessage,
                    analysis: analysisText,
                    modelContext: modelContext
                )
                inputText = ""
                isLoading = false
                processingVision = false
                processingOCR = false
                interpreting = false
                visionContextTag = nil
                currentActivity = .thinking // Reset activity when done
                currentSourceModel = nil // Clear source model
                currentResponseTask = nil // Clear task reference
                try? modelContext.save()
            }
            if isFirstMessage, let conversation = currentConversation {
                await generateAndSetTitle(
                    from: text.isEmpty ? analysis.summary : text,
                    conversation: conversation,
                    modelContext: modelContext
                )
            }

            await offerLinkingSuggestionIfNeeded(modelContext: modelContext, stylePreferences: stylePreferences)
        } catch {
            await MainActor.run {
                // Provide helpful error messages based on error type
                let errorContent: String
                let errorDescription = error.localizedDescription
                
                // Check error type by description or type name
                if errorDescription.contains("authentication") || errorDescription.contains("API key") || errorDescription.contains("Google API key") {
                    errorContent = "I need your Google API key to analyze images. Please add it to Config.plist (GoogleAPIKey)."
                } else if errorDescription.contains("airplane mode") || errorDescription.contains("cloud access") {
                    errorContent = "Image analysis requires cloud access. \(errorDescription)"
                } else if errorDescription.contains("timeout") || errorDescription.contains("timed out") {
                    errorContent = "Image analysis timed out. The image might be too large or the service is slow. Please try again."
                } else if errorDescription.contains("HTTP 401") || errorDescription.contains("401") {
                    errorContent = "Authentication failed. Please check your Google API key in Config.plist (GoogleAPIKey)."
                } else if errorDescription.contains("HTTP") {
                    errorContent = "Gemini API error: \(errorDescription). Please check your API key and try again."
                } else if errorDescription.contains("Image analysis requires") {
                    errorContent = errorDescription
                } else {
                    errorContent = "I'm having trouble processing that image: \(errorDescription). Please check your Google API key configuration in Config.plist (GoogleAPIKey)."
                }
                
                let errorMessage = AIMessage(
                    role: "assistant",
                    content: errorContent
                )
                modelContext.insert(errorMessage)
                messages.append(errorMessage)
                currentConversation?.messages?.append(errorMessage)
                self.errorMessage = errorDescription
                isLoading = false
                currentActivity = .thinking // Reset activity on error
                currentSourceModel = nil // Clear source model
                currentResponseTask = nil // Clear task reference
                try? modelContext.save()
            }
        }
    }

    private func handleDocumentMessage(
        text: String,
        documentAttachment: DocumentAttachmentService.DocumentAttachment,
        userMessage: AIMessage,
        modelContext: ModelContext,
        isFirstMessage: Bool,
        typingStyle: TypingStyle,
        stylePreferences: UserPreferences
    ) async {
        let fallbackText = text.isEmpty ? (documentAttachment.fileName) : text
        do {
            let (appContext, payloadContext, conversationModelContent) = try await buildAIContext(
                for: fallbackText,
                modelContext: modelContext,
                currentStyle: typingStyle,
                styleProfile: stylePreferences
            )
            
            // Safety guard: Force isResearchMode = false for documents regardless of conversation mode
            payloadContext.metadata["isResearchMode"] = false
            
            recordIntent(from: payloadContext)
            let contextFreshness = AppContextService.shared.contextFreshness()
            let confidenceSnapshot = ConfidenceScorer.evaluate(
                recallSnippets: payloadContext.recall,
                intentSummary: payloadContext.intentClusters,
                contextAge: contextFreshness
            )

            let descriptor = DocumentDescriptor(
                text: documentAttachment.extractedText,
                preview: documentAttachment.textPreview,
                fileName: documentAttachment.fileName,
                mimeType: documentAttachment.mimeType,
                sizeInBytes: documentAttachment.sizeInBytes,
                pageCount: documentAttachment.pageCount,
                sourceURL: documentAttachment.sourceURL?.absoluteString
            )

            let analysis = try await coreResponseService.analyzeDocument(
                descriptor: descriptor,
                userPrompt: text.isEmpty ? nil : text,
                appContext: appContext,
                payloadContext: payloadContext,
                conversationMessages: conversationModelContent,
                currentMessageStyle: typingStyle,
                userStyleProfile: stylePreferences,
                confidence: confidenceSnapshot
            )
            
            // Track source model for adaptive phrasing
            currentSourceModel = analysis.sourceModel

            let finalSummary: String
            if analysis.truncatedContext {
                finalSummary = analysis.summary + "\n\nHeads up: I only had room to review part of that document this time. Want me to pull more later?"
            } else {
                finalSummary = analysis.summary
            }
            
            // UX Transparency: Add source model information
            let sourceMessage: String
            switch analysis.sourceModel {
            case .appleLLM:
                sourceMessage = "\n\n💡 _Summary generated locally using Apple Intelligence for faster processing._"
            case .offline:
                sourceMessage = "\n\n💡 _Summary generated offline using template-based extraction._"
            default:
                sourceMessage = "" // Ollama is primary, no message needed
            }
            
            let finalSummaryWithSource = finalSummary + sourceMessage
            
            // Log diagnostic information
            print("📊 Document analysis source: \(analysis.sourceModel.rawValue) for \(documentAttachment.fileName)")

            await MainActor.run {
                userMessage.documentSummary = finalSummaryWithSource
                if userMessage.documentTextPreview == nil {
                    userMessage.documentTextPreview = documentAttachment.textPreview
                }
                let assistantMessage = AIMessage(
                    role: "assistant",
                    content: finalSummaryWithSource,
                    confidenceScore: confidenceSnapshot.score,
                    documentSourceModel: analysis.sourceModel.rawValue
                )
                modelContext.insert(assistantMessage)
                messages.append(assistantMessage)
                currentConversation?.messages?.append(assistantMessage)
                AIRecallService.shared.indexDocumentSummary(
                    userMessage: userMessage,
                    summary: finalSummaryWithSource,
                    modelContext: modelContext
                )
                inputText = ""
                isLoading = false
                currentActivity = .thinking // Reset activity when done
                try? modelContext.save()
            }
            if analysis.sourceModel != SummarySource.appleLLM {
                // Store metadata for reconciliation if needed
                await DocumentReconciliationService.shared.recordFallbackSummary(
                    documentId: userMessage.id,
                    fileName: documentAttachment.fileName,
                    sourceModel: analysis.sourceModel,
                    summary: finalSummaryWithSource,
                    descriptor: descriptor,
                    modelContext: modelContext
                )
            }

            // Check if user requested execution actions after document analysis
            if !text.isEmpty {
                if let parsedIntent = try? await coreResponseService.parsedIntent(
                    for: text,
                    modelContext: modelContext
                ) {
                    lastParsedIntent = parsedIntent
                    lastIntentMessageId = userMessage.id
                    ConversationFlowService.shared.cacheIntent(parsedIntent, for: userMessage.id)
                    if await executeIntent(
                        parsedIntent,
                        modelContext: modelContext,
                        isFirstMessage: isFirstMessage,
                        messageText: text,
                        payloadContext: payloadContext
                    ) {
                        return
                    }
                }
            }

            if isFirstMessage, let conversation = currentConversation {
                await generateAndSetTitle(
                    from: text.isEmpty ? finalSummary : text,
                    conversation: conversation,
                    modelContext: modelContext
                )
            }
            
            // Process any task creation or other execution requests from the user's message
            // This handles cases where user asks to "break down into tasks" or similar
            if !text.isEmpty {
                do {
                    // Parse @ mentions and resolve them
                    let mentions = MentionParser.parseMentions(from: text)
                    var resolvedLinkedContext = LinkedContext()
                    
                    for mention in mentions {
                        let results = WorkspaceObjectSearchService.shared.search(
                            query: mention.mentionText,
                            modelContext: modelContext,
                            limit: 1
                        )
                        
                        if let firstResult = results.first {
                            resolvedLinkedContext.addLinkedObject(
                                type: firstResult.type,
                                id: firstResult.id,
                                mentionText: mention.fullText,
                                displayName: firstResult.title
                            )
                        }
                    }
                    
                    // Check for execution intent (like creating tasks from the document)
                    if let parsedIntent = try? await coreResponseService.parsedIntent(
                        for: text,
                        linkedContext: resolvedLinkedContext.isEmpty ? nil : resolvedLinkedContext,
                        modelContext: modelContext
                    ) {
                        lastParsedIntent = parsedIntent
                        lastIntentMessageId = userMessage.id
                        ConversationFlowService.shared.cacheIntent(parsedIntent, for: userMessage.id)
                        if await executeIntent(
                            parsedIntent,
                            modelContext: modelContext,
                            isFirstMessage: isFirstMessage,
                            messageText: text,
                            payloadContext: payloadContext
                        ) {
                            return
                        } else {
                            await processMessage(
                                text,
                                modelContext: modelContext,
                                isFirstMessage: false,
                                currentStyle: typingStyle,
                                styleProfile: stylePreferences
                            )
                        }
                    } else {
                        // If no explicit execution intent, process as a regular message to handle conversational requests
                        await processMessage(
                            text,
                            modelContext: modelContext,
                            isFirstMessage: false,
                            currentStyle: typingStyle,
                            styleProfile: stylePreferences
                        )
                    }
                } catch {
                    // If processing the follow-up request fails, log but don't fail the whole document analysis
                    await MainActor.run {
                        let errorMsg = AIMessage(
                            role: "assistant",
                            content: "I was able to analyze the document, but I'm having trouble processing your follow-up request right now. The model might be overloaded - could you try again in a moment?"
                        )
                        modelContext.insert(errorMsg)
                        messages.append(errorMsg)
                        currentConversation?.messages?.append(errorMsg)
                        self.errorMessage = error.localizedDescription
                        try? modelContext.save()
                    }
                }
            }
            
            await offerLinkingSuggestionIfNeeded(modelContext: modelContext, stylePreferences: stylePreferences)
        } catch {
            // Check if this is a model overload error
            let errorDesc = error.localizedDescription.lowercased()
            let isOverloadError = errorDesc.contains("overloaded") || 
                                  errorDesc.contains("unavailable") || 
                                  errorDesc.contains("503") ||
                                  errorDesc.contains("try again later")
            
            let errorContent: String
            if isOverloadError {
                errorContent = "I tried switching to a different model, but all models are currently overloaded. The document hasn't been processed yet - could you try again in a moment?"
            } else {
                errorContent = "I'm having trouble processing that document right now. Mind trying again in a minute?"
            }
            
            await MainActor.run {
                let errorMessage = AIMessage(
                    role: "assistant",
                    content: errorContent
                )
                modelContext.insert(errorMessage)
                messages.append(errorMessage)
                currentConversation?.messages?.append(errorMessage)
                self.errorMessage = error.localizedDescription
                isLoading = false
                currentActivity = .thinking // Reset activity on error
                currentSourceModel = nil // Clear source model
                try? modelContext.save()
            }
        }
    }
    
    private func executeIntent(
        _ parsedIntent: ParsedIntent,
        modelContext: ModelContext,
        isFirstMessage: Bool,
        allowPromptForMissingFields: Bool = true,
        messageText: String? = nil,
        payloadContext: AIPayloadContext? = nil
    ) async -> Bool {
        var intent = parsedIntent
        var executionIntent = intent.executionIntent
        
        if intent.action == .create,
           intent.object == .task,
           shouldBlockTaskCreation(for: messageText, payloadContext: payloadContext) {
            return false
        }

        if intent.action == .create || executionIntent.operation == .createReminder {
            if await ensureReferencedParentsExist(for: &intent, modelContext: modelContext) {
                return await handleWorkspaceCreation(intent: intent, modelContext: modelContext, isFirstMessage: isFirstMessage)
            }
            return true
        }
        
        if executionIntent.operation == .updateTask && executionIntent.taskId == nil {
            if let lastTask = findLastCreatedTask(from: messages, modelContext: modelContext) {
                executionIntent.taskId = lastTask.id.uuidString
                if executionIntent.taskProjectId == nil {
                    executionIntent.taskProjectId = lastTask.projectId?.uuidString
                }
            }
        }
        
        if let action = AIIntentAction(from: executionIntent) {
            await perform(action: action, intent: executionIntent, modelContext: modelContext, isFirstMessage: isFirstMessage)
            if let conversation = currentConversation {
                await ConversationFlowService.shared.evaluateAndRenameChat(intent: intent, conversation: conversation, modelContext: modelContext)
            }
            return true
        }
        if allowPromptForMissingFields,
           await handleIncompleteExecutionIntent(executionIntent, modelContext: modelContext) {
            return true
        }
        do {
            let executionService = AIExecutionService.shared
            let legacyResult: AIExecutionService.ExecutionResult
            
            switch executionIntent.operation {
            case .archiveTasks:
                let criteria = AIExecutionService.ArchiveCriteria(rawValue: executionIntent.criteria ?? "completed") ?? .completed
                legacyResult = try await executionService.archiveTasks(
                    criteria: criteria,
                    daysAgo: executionIntent.daysAgo,
                    projectId: nil,
                    context: modelContext
                )
            case .summarizePosts:
                let filter = AIExecutionService.PostFilter(rawValue: executionIntent.postFilter ?? "all") ?? .all
                legacyResult = try await executionService.summarizePosts(
                    filter: filter,
                    filterValue: executionIntent.filterValue,
                    context: modelContext
                )
            case .generateReport:
                let type = AIExecutionService.ReportType(rawValue: executionIntent.reportType ?? "weekly") ?? .weekly
                legacyResult = try await executionService.generateProgressReport(
                    type: type,
                    context: modelContext
                )
            case .predictScheduling:
                legacyResult = try await executionService.predictSchedulingNeeds(
                    daysAhead: executionIntent.daysAhead ?? 7,
                    context: modelContext
                )
            default:
                throw ExecutionError.executionFailed("Operation \(executionIntent.operation.rawValue) not supported in legacy execution path")
            }
            
            let attributed = convertMarkdownToAttributedString(legacyResult.asMarkdown())
            let assistantMessage = AIMessage(role: "assistant", content: attributed)
            
            await MainActor.run {
                modelContext.insert(assistantMessage)
                messages.append(assistantMessage)
                currentConversation?.messages?.append(assistantMessage)
            inputText = ""
                isLoading = false
                try? modelContext.save()
            }
            return true
        } catch {
            let errorDesc = error.localizedDescription.lowercased()
            let isOverloadError = errorDesc.contains("overloaded") ||
                errorDesc.contains("unavailable") ||
                errorDesc.contains("503") ||
                errorDesc.contains("try again later")
            
            let errorContent: String
            if isOverloadError {
                errorContent = "I tried switching to a different model, but all models are currently overloaded. Could you try again in a moment? The tasks haven't been created yet."
            } else {
                errorContent = "❌ Failed to execute: \(error.localizedDescription)"
            }
            
            let errorMessage = AIMessage(
                role: "assistant",
                content: errorContent
            )
            
            await MainActor.run {
                modelContext.insert(errorMessage)
                messages.append(errorMessage)
                currentConversation?.messages?.append(errorMessage)
                self.errorMessage = error.localizedDescription
                isLoading = false
            }
            return true
        }
    }
    
    // MARK: - Compound Operations
    
    private func handleWorkspaceCreation(
        intent: ParsedIntent,
        modelContext: ModelContext,
        isFirstMessage: Bool
    ) async -> Bool {
        do {
            let currentTone = messages.last(where: { ($0.role ?? "") == "assistant" })?.tone.flatMap { AuroraTone(rawValue: $0) }
            let result = try await creationService.executeCreation(intent: intent, modelContext: modelContext)
            let report = await actionReportService.generateActionReport(
                intent: intent,
                createdObjects: result.createdObjectIDs,
                modelContext: modelContext,
                tone: currentTone
            )
            await sendAssistantPrompt(report, modelContext: modelContext)
            if let conversation = currentConversation {
                await ConversationFlowService.shared.evaluateAndRenameChat(intent: intent, conversation: conversation, modelContext: modelContext)
            }
            return true
        } catch let creationError as WorkspaceObjectCreationService.CreationError {
            await sendAssistantPrompt(creationError.localizedDescription, modelContext: modelContext)
            return true
        } catch {
            await sendAssistantPrompt("I couldn't finish that. \(error.localizedDescription)", modelContext: modelContext)
            return true
        }
    }
    
    private func ensureReferencedParentsExist(
        for intent: inout ParsedIntent,
        modelContext: ModelContext
    ) async -> Bool {
        if let projectName = intent.executionIntent.projectTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !projectName.isEmpty,
           intent.metadata.projectId == nil,
           intent.object != .project {
            if let existing = await WorkspaceLookupService.shared.lookupProject(name: projectName, modelContext: modelContext) {
                var executionIntent = intent.executionIntent
                executionIntent.projectId = existing.id.uuidString
                executionIntent.taskProjectId = existing.id.uuidString
                intent.metadata.projectId = existing.id
                intent.executionIntent = executionIntent
            } else {
                await sendAssistantPrompt("I didn't find a project named \"\(projectName)\". Want me to create it?", modelContext: modelContext)
                return false
            }
        }
        return true
    }
    
    
    
    
    // MARK: - Reminder Creation
    
    
    private func processReflection(
        _ intent: ReflectionIntent,
        originalQuery: String,
        modelContext: ModelContext,
        isFirstMessage: Bool,
        currentStyle: TypingStyle?,
        styleProfile: UserPreferences?
    ) async {
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
        
        // Determine tone for reflection (use pattern recognition or insightful)
        let reflectionTone = AuroraTone.patternRecognition
        
        // Format as Aurora's thoughtful response
        let fullResponse = """
        💭 **Reflection on your patterns and progress**
        
        \(reflectiveInsight)
        
        ---
        
        _This analysis is based on data from your Intelligence Dashboard. Visit **Insights** to explore these patterns visually._
        """
        
        let attributedResponse = convertMarkdownToAttributedString(fullResponse)
        let assistantMessage = AIMessage(
            role: "assistant",
            content: attributedResponse,
            chartData: chartData,
            tone: reflectionTone.rawValue
        )
        
        await MainActor.run {
            modelContext.insert(assistantMessage)
            messages.append(assistantMessage)
            currentConversation?.messages?.append(assistantMessage)
            inputText = ""
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
        messagePayloadCache[userMessage.id] = ResendPayload(
            text: userMessage.content ?? "",
            image: nil,
            document: nil
        )
        
        let result = await aiService.executeTool(tool, input: topic, context: "")
        
        // Extract clean content for the tool result
        let cleanResult = extractCleanContent(from: result.result, tool: tool)
        
        // Convert markdown to attributed string
        let attributedResult = convertMarkdownToAttributedString(cleanResult)
        
        let assistantMessage = AIMessage(role: "assistant", content: attributedResult)
        
        await MainActor.run {
            modelContext.insert(assistantMessage)
            messages.append(assistantMessage)
            currentConversation?.messages?.append(assistantMessage)
            inputText = ""
            isLoading = false
            
            // Save after adding quick tool message
            try? modelContext.save()
        }
    }
    
    private func handlePendingOperationIfNeeded(
        with text: String,
        modelContext: ModelContext,
        isFirstMessage: Bool
    ) async -> Bool {
        guard var pending = pendingOperation else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        if ["cancel", "never mind", "nevermind", "stop", "abort"].contains(lowercased) {
            pendingOperation = nil
            await sendAssistantPrompt("No problem, I'll cancel that request.", modelContext: modelContext)
            return true
        }
        guard !trimmed.isEmpty else {
            await sendAssistantPrompt("I didn't catch that. Could you share that detail again?", modelContext: modelContext)
            return true
        }
        guard !pending.remainingPrompts.isEmpty else {
            pendingOperation = nil
            return false
        }
        var prompts = pending.remainingPrompts
        let currentPrompt = prompts.removeFirst()
        pending.collectedFields[currentPrompt.key] = trimmed
        pending.remainingPrompts = prompts
        pendingOperation = pending
        if prompts.isEmpty {
            pendingOperation = nil
            if let action = buildAction(for: pending) {
                await perform(action: action, intent: pending.intent, modelContext: modelContext, isFirstMessage: isFirstMessage)
            } else {
                await sendAssistantPrompt("I couldn't use that information to finish the request. Let's try again or give me more detail.", modelContext: modelContext)
            }
        } else {
            let nextPrompt = prompts.first!.prompt
            await sendAssistantPrompt(nextPrompt, modelContext: modelContext)
        }
        return true
    }
    
    private func handleIncompleteExecutionIntent(
        _ intent: ExecutionIntent,
        modelContext: ModelContext
    ) async -> Bool {
        let prompts = promptsForMissingFields(intent)
        guard !prompts.isEmpty else { return false }
        let collected = initialCollectedFields(from: intent)
        pendingOperation = PendingOperation(
            operation: intent.operation,
            intent: intent,
            collectedFields: collected,
            remainingPrompts: prompts
        )
        await sendAssistantPrompt(prompts.first!.prompt, modelContext: modelContext)
        return true
    }
    
    private func promptsForMissingFields(_ intent: ExecutionIntent) -> [PendingField] {
        switch intent.operation {
        case .createTask:
            var prompts: [PendingField] = []
            if isEmpty(intent.taskTitle) {
                prompts.append(PendingField(key: .taskTitle, prompt: "Sure, what should I call the task?"))
            }
            return prompts
        case .createProject:
            var prompts: [PendingField] = []
            if isEmpty(intent.projectTitle) {
                prompts.append(PendingField(key: .projectTitle, prompt: "Got it, what's the project title?"))
            }
            return prompts
        case .createNote:
            var prompts: [PendingField] = []
            if isEmpty(intent.noteTitle) {
                prompts.append(PendingField(key: .noteTitle, prompt: "Happy to draft that, what should the note be titled?"))
            }
            return prompts
        case .createPost:
            var prompts: [PendingField] = []
            if isEmpty(intent.caption) {
                prompts.append(PendingField(key: .postCaption, prompt: "What's the caption you'd like me to use?"))
            }
            return prompts
        case .addInboxItem:
            var prompts: [PendingField] = []
            if isEmpty(intent.inboxContent) {
                prompts.append(PendingField(key: .inboxContent, prompt: "Sure, what should I capture in your inbox?"))
            }
            return prompts
        case .createReminder:
            var prompts: [PendingField] = []
            if isEmpty(intent.reminderTitle) {
                prompts.append(PendingField(key: .reminderTitle, prompt: "What should I remind you about?"))
            }
            if isEmpty(intent.reminderDate) && isEmpty(intent.reminderTime) {
                prompts.append(PendingField(key: .reminderDate, prompt: "When should I remind you? (e.g., 'tomorrow at 3pm', 'Monday at 9am')"))
            }
            return prompts
        case .createArtifact:
            var prompts: [PendingField] = []
            if isEmpty(intent.artifactTitle) {
                prompts.append(PendingField(key: .artifactTitle, prompt: "What should I call the artifact?"))
            }
            return prompts
        default:
            return []
        }
    }
    
    private func initialCollectedFields(from intent: ExecutionIntent) -> [ExecutionFieldKey: String] {
        var collected: [ExecutionFieldKey: String] = [:]
        if let title = trimmed(intent.taskTitle), !title.isEmpty {
            collected[.taskTitle] = title
        }
        if let title = trimmed(intent.projectTitle), !title.isEmpty {
            collected[.projectTitle] = title
        }
        if let title = trimmed(intent.noteTitle), !title.isEmpty {
            collected[.noteTitle] = title
        }
        if let caption = trimmed(intent.caption), !caption.isEmpty {
            collected[.postCaption] = caption
        }
        if let content = trimmed(intent.inboxContent), !content.isEmpty {
            collected[.inboxContent] = content
        }
        if let title = trimmed(intent.reminderTitle), !title.isEmpty {
            collected[.reminderTitle] = title
        }
        if let date = trimmed(intent.reminderDate), !date.isEmpty {
            collected[.reminderDate] = date
        } else if let time = trimmed(intent.reminderTime), !time.isEmpty {
            collected[.reminderDate] = time
        }
        return collected
    }
    
    private func buildAction(for pending: PendingOperation) -> AIIntentAction? {
        switch pending.operation {
        case .createTask:
            guard let title = pending.collectedFields[.taskTitle] ?? trimmed(pending.intent.taskTitle), !title.isEmpty else {
                return nil
            }
            let status = mapTaskStatus(pending.intent.taskStatus) ?? .todo
            let priority = mapTaskPriority(pending.intent.taskPriority) ?? .medium
            let dueDate = parseISODate(pending.intent.taskDueDate)
            let projectId = pending.intent.taskProjectId.flatMap(UUID.init(uuidString:))
            let areaId = pending.intent.taskAreaId.flatMap(UUID.init(uuidString:))
            let request = TaskCreationRequest(
                title: title,
                notes: pending.intent.taskNotes,
                dueDate: dueDate,
                status: status,
                priority: priority,
                projectId: projectId,
                areaId: areaId
            )
            return .createTask(request)
        case .createProject:
            guard let title = pending.collectedFields[.projectTitle] ?? trimmed(pending.intent.projectTitle), !title.isEmpty else {
                return nil
            }
            let status = mapProjectStatus(pending.intent.projectStatus) ?? .active
            let dueDate = parseISODate(pending.intent.projectDueDate)
            let areaId = pending.intent.projectAreaId.flatMap(UUID.init(uuidString:))
            let tags = pending.intent.tags ?? []
            let request = ProjectCreationRequest(
                title: title,
                goal: pending.intent.projectGoal,
                status: status,
                dueDate: dueDate,
                areaId: areaId,
                tags: tags
            )
            return .createProject(request)
        case .createNote:
            guard let title = pending.collectedFields[.noteTitle] ?? trimmed(pending.intent.noteTitle), !title.isEmpty else {
                return nil
            }
            let body = pending.intent.noteBody ?? ""
            let tags = pending.intent.noteTags ?? []
            let request = NoteMutationRequest(noteId: nil, title: title, body: body, tags: tags)
            return .createNote(request)
        case .createPost:
            guard let caption = pending.collectedFields[.postCaption] ?? trimmed(pending.intent.caption), !caption.isEmpty else {
                return nil
            }
            let scheduledDate = parseISODate(pending.intent.scheduledDate)
            let tags = pending.intent.tags ?? []
            let notes = pending.intent.notes
            let createDraft = pending.intent.createDraft ?? (pending.intent.draftId == nil)
            let draftId = pending.intent.draftId.flatMap(UUID.init(uuidString:))
            let request = PostCreationRequest(
                caption: caption,
                scheduledDate: scheduledDate,
                tags: tags,
                notes: notes,
                createDraft: createDraft,
                draftId: draftId
            )
            return .createPost(request)
        case .addInboxItem:
            guard let content = pending.collectedFields[.inboxContent] ?? trimmed(pending.intent.inboxContent), !content.isEmpty else {
                return nil
            }
            let itemType = pending.intent.inboxType ?? "text"
            let request = InboxAdditionRequest(content: content, itemType: itemType)
            return .addInboxItem(request)
        case .createReminder:
            guard let title = pending.collectedFields[.reminderTitle] ?? trimmed(pending.intent.reminderTitle), !title.isEmpty else {
                return nil
            }
            let dateString = pending.collectedFields[.reminderDate] ?? pending.intent.reminderDate ?? pending.intent.reminderTime ?? ""
            guard !dateString.isEmpty else {
                return nil
            }
            // Parse date/time - simplified for now, assume ISO8601 or relative date
            let reminderDate: Date
            if let parsedDate = parseISODate(dateString) {
                reminderDate = parsedDate
            } else {
                // Fallback to current date + 1 hour if parsing fails
                reminderDate = Date().addingTimeInterval(3600)
            }
            let taskId = pending.intent.reminderTaskId.flatMap(UUID.init(uuidString:))
            let projectId = pending.intent.reminderProjectId.flatMap(UUID.init(uuidString:))
            let request = ReminderCreationRequest(
                title: title,
                notes: pending.intent.reminderNotes,
                reminderDate: reminderDate,
                taskId: taskId,
                projectId: projectId
            )
            return .createReminder(request)
        case .createArtifact:
            guard let title = pending.collectedFields[.artifactTitle] ?? trimmed(pending.intent.artifactTitle), !title.isEmpty else {
                return nil
            }
            let format = mapOutputFormat(pending.intent.artifactFormat)
            let state = mapArtifactState(pending.intent.artifactState)
            let projectId = pending.intent.artifactProjectId.flatMap(UUID.init(uuidString:))
            let areaId = pending.intent.artifactAreaId.flatMap(UUID.init(uuidString:))
            let notes = pending.intent.artifactNotes ?? pending.intent.notes
            let request = ArtifactCreationRequest(
                title: title,
                content: pending.intent.artifactContent ?? pending.intent.notes,
                format: format,
                state: state,
                tags: pending.intent.artifactTags ?? [],
                projectId: projectId,
                areaId: areaId,
                auroraNotes: notes
            )
            return .createArtifact(request)
        default:
            return nil
        }
    }
    
    private func perform(
        action: AIIntentAction,
        intent: ExecutionIntent,
        modelContext: ModelContext,
        isFirstMessage: Bool
    ) async {
        do {
            let actionResult = try await actionRouter.route(action, modelContext: modelContext)
            
            // Convert structured markdown to conversational format
            let conversationalResponse = await convertExecutionResultToConversational(actionResult, modelContext: modelContext)
            let attributedResult = convertMarkdownToAttributedString(conversationalResponse)
            let assistantMessage = AIMessage(role: "assistant", content: attributedResult)
            
            await MainActor.run {
                modelContext.insert(assistantMessage)
                messages.append(assistantMessage)
                currentConversation?.messages?.append(assistantMessage)
            inputText = ""
                isLoading = false
                try? modelContext.save()
            }
            feedbackLogger.record(action: action, result: actionResult, modelContext: modelContext)
            if isFirstMessage, let conversation = currentConversation {
                await generateAndSetTitle(from: action.displayName, conversation: conversation, modelContext: modelContext)
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
                try? modelContext.save()
            }
        }
    }
    
    /// Converts structured execution results to conversational format
    private func convertExecutionResultToConversational(_ result: AIActionResult, modelContext: ModelContext) async -> String {
        // Extract key information from the structured result
        var conversational = result.message
        
        // Convert details to natural language
        if !result.details.isEmpty {
            let detailsText = result.details.joined(separator: ", ")
            conversational += " \(detailsText)."
        }
        
        // Add items affected naturally if relevant
        if result.itemsAffected > 0 {
            conversational = conversational.replacingOccurrences(of: "Affected: \(result.itemsAffected) items", with: "")
            conversational = conversational.replacingOccurrences(of: "✅ **", with: "")
            conversational = conversational.replacingOccurrences(of: "**", with: "")
            
            // Make it conversational
            if result.itemsAffected == 1 {
                conversational += " That's 1 item updated."
            } else {
                conversational += " That's \(result.itemsAffected) items updated."
            }
        }
        
        // Remove any remaining structured formatting
        conversational = conversational.replacingOccurrences(of: "Total posts:", with: "")
        conversational = conversational.replacingOccurrences(of: "Published:", with: "")
        conversational = conversational.replacingOccurrences(of: "Scheduled:", with: "")
        conversational = conversational.replacingOccurrences(of: "•", with: "")
        conversational = conversational.replacingOccurrences(of: "\n\n", with: " ")
        conversational = conversational.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If we have structured markdown, ask Aurora to convert it conversationally
        if result.markdown.contains("Total posts:") || result.markdown.contains("Published:") || result.markdown.contains("Affected:") {
            let conversionPrompt = """
            Convert this structured information into a natural, conversational response:
            
            \(result.markdown)
            
            Respond as Aurora would - naturally and conversationally, weaving the information into flowing sentences. No lists, no labels, just natural conversation.
            """
            
            do {
                let converted = try await coreResponseService.generateResponse(
                    for: conversionPrompt,
                    modelContext: modelContext
                )
                return converted
            } catch {
                // Fallback to cleaned up version if conversion fails
                return conversational
            }
        }
        
        return conversational
    }
    
    private func checkAndShowPendingSuggestions(modelContext: ModelContext) async {
        guard let conversation = currentConversation else { return }
        let now = Date()
        
        // Check if we've already shown a suggestion today
        if let patternId = conversation.pendingSuggestionPatternId {
            let descriptor = FetchDescriptor<WorkflowPattern>(
                predicate: #Predicate { $0.id == patternId }
            )
            if let pattern = try? modelContext.fetch(descriptor).first,
               !pattern.userDismissedSuggestion && !pattern.userAcceptedSuggestion {
                return
            }
        }
        
        // Limit to one suggestion per day
        if let lastSuggestion = lastLinkingSuggestionAt, now.timeIntervalSince(lastSuggestion) < 24 * 3600 {
            return
        }
        
        let suggestions = SmartAutomationEngine.shared.getPendingSuggestions(limit: 1, modelContext: modelContext)
        guard let pattern = suggestions.first, messages.isEmpty else { return }
        
        let messageText: String
        switch WorkflowPatternType(rawValue: pattern.patternType) {
        case .recurringTask:
            messageText = "btw, I've noticed you create '\(pattern.name.replacingOccurrences(of: "Recurring: ", with: ""))' tasks regularly (\(pattern.occurrenceCount) times). Want me to automate that?"
        case .timeBlockPattern:
            if let hour = pattern.timeOfDay {
                messageText = "I noticed you typically focus around \(hour):00 (\(pattern.occurrenceCount) sessions). Want me to schedule recurring focus blocks?"
            } else {
                messageText = pattern.patternDescription + " Want me to automate this?"
            }
        case .contentSchedule:
            messageText = pattern.patternDescription + " Want me to set up automatic scheduling?"
        default:
            messageText = pattern.patternDescription + " Want me to automate this?"
        }
        
        await MainActor.run {
            let assistantMessage = AIMessage(role: "assistant", content: messageText)
            modelContext.insert(assistantMessage)
            messages.append(assistantMessage)
            conversation.messages?.append(assistantMessage)
            inputText = ""
            conversation.pendingSuggestionPatternId = pattern.id
            lastLinkingSuggestionAt = now
            try? modelContext.save()
        }
    }
    
    private func offerLinkingSuggestionIfNeeded(
        modelContext: ModelContext,
        stylePreferences: UserPreferences
    ) async {
        guard AIConfigService.shared.config.featureFlags.recallEnabled,
              AIConfigService.shared.config.featureFlags.narrativeEnabled else { return }
        let now = Date()
        if let last = lastLinkingSuggestionAt, now.timeIntervalSince(last) < 6 * 3600 {
            return
        }
        let suggestions = ConceptTracker.shared.getLinkingSuggestions(limit: 1, modelContext: modelContext)
        guard let suggestion = suggestions.first else { return }
        let normalized = suggestion.normalizedConcept
        if stylePreferences.suggestedLinkingConcepts.contains(normalized) {
            return
        }
        let entries = AIRecallService.shared.allEntries(modelContext: modelContext)
        let lookup = Dictionary(uniqueKeysWithValues: entries.map { ($0.objectId, $0) })
        let detailedEntries = suggestion.objectIDs.compactMap { lookup[$0] }
        guard detailedEntries.count >= 3 else { return }
        let bulletList = detailedEntries.prefix(3).map { entry -> String in
            let type = RecallObjectType(rawValue: entry.objectType)?.displayName ?? "Item"
            return "• \(type): \(entry.title)"
        }.joined(separator: "\n")
        let messageText = "I've been noticing a thread around **\(suggestion.concept)**. It shows up in:\n\(bulletList)\nWant me to bundle these together or keep an eye on this theme for you?"
        let assistantMessage = AIMessage(role: "assistant", content: messageText)
        modelContext.insert(assistantMessage)
        messages.append(assistantMessage)
        currentConversation?.messages?.append(assistantMessage)
        inputText = ""
        stylePreferences.suggestedLinkingConcepts.append(normalized)
        stylePreferences.updatedAt = now
        lastLinkingSuggestionAt = now
        try? modelContext.save()
    }
 
    private func findLastCreatedTask(from messages: [AIMessage], modelContext: ModelContext) -> FocusOSShared.Task? {
        // Look through recent messages for task creation confirmations
        // Messages often contain "Task created Title: X" or similar patterns
        for message in messages.reversed() {
            guard let content = message.content else { continue }
            
            // Check if message mentions a task creation
            if content.lowercased().contains("task created") || content.lowercased().contains("created task") {
                // Try to extract task title from the message
                if let titleMatch = content.range(of: #"Title:\s*([^|]+)"#, options: .regularExpression) {
                    let title = String(content[titleMatch]).replacingOccurrences(of: "Title:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Find the task by title (most recent match)
                    var descriptor = FetchDescriptor<FocusOSShared.Task>(
                        predicate: #Predicate { $0.title == title },
                        sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                    )
                    descriptor.fetchLimit = 1
                    
                    if let task = try? modelContext.fetch(descriptor).first {
                        return task
                    }
                }
            }
        }
        
        // Fallback: find the most recently created task overall
        var descriptor = FetchDescriptor<FocusOSShared.Task>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        
        return try? modelContext.fetch(descriptor).first
    }
    
     private func sendAssistantPrompt(_ prompt: String, modelContext: ModelContext) async {
        await MainActor.run {
            let assistantMessage = AIMessage(role: "assistant", content: prompt)
            modelContext.insert(assistantMessage)
            messages.append(assistantMessage)
            currentConversation?.messages?.append(assistantMessage)
            inputText = ""
            isLoading = false
            try? modelContext.save()
        }
    }
    
    private func isEmpty(_ value: String?) -> Bool {
        trimmed(value)?.isEmpty ?? true
    }
    
    private func trimmed(_ value: String?) -> String? {
        value?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func parseISODate(_ raw: String?) -> Date? {
        DateParsing.parse(raw)
    }
    
    private func mapTaskStatus(_ raw: String?) -> FocusOSShared.TaskStatus? {
        guard let raw = raw?.lowercased() else { return nil }
        switch raw {
        case "todo": return .todo
        case "inprogress", "in_progress", "doing": return .inProgress
        case "done", "completed": return .done
        case "cancelled", "canceled": return .cancelled
        default: return nil
        }
    }
    
    private func mapTaskPriority(_ raw: String?) -> FocusOSShared.TaskPriority? {
        guard let raw = raw?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        let cleaned = raw
            .replacingOccurrences(of: "priority", with: "")
            .replacingOccurrences(of: "priroty", with: "")
            .replacingOccurrences(of: "set to", with: "")
            .replacingOccurrences(of: "set for", with: "")
            .replacingOccurrences(of: "set", with: "")
            .replacingOccurrences(of: "to", with: "")
            .replacingOccurrences(of: "with a", with: "")
            .replacingOccurrences(of: "with", with: "")
            .replacingOccurrences(of: "at", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        switch cleaned {
        case "low": return .low
        case "medium", "normal", "med": return .medium
        case "high", "urgent", "hi": return .high
        default: return nil
        }
    }
    
    private func mapProjectStatus(_ raw: String?) -> FocusOSShared.ProjectStatus? {
        guard let raw = raw?.lowercased() else { return nil }
        switch raw {
        case "active": return .active
        case "paused", "on_hold": return .paused
        case "completed", "done": return .completed
        default: return nil
        }
    }
    
    private func mapOutputFormat(_ raw: String?) -> OutputFormat {
        guard let raw = raw?.lowercased() else { return .brief }
        return OutputFormat(rawValue: raw) ?? .brief
    }
    
    private func mapArtifactState(_ raw: String?) -> ArtifactState {
        guard let raw = raw?.lowercased() else { return .draft }
        switch raw {
        case "idea": return .idea
        case "draft": return .draft
        case "final": return .final
        case "published": return .published
        case "archived": return .archived
        default: return .draft
        }
    }
    
    // MARK: - Style Adaptation Helpers

    private func fetchOrCreatePreferences(modelContext: ModelContext) -> UserPreferences {
        if let existing = try? modelContext.fetch(FetchDescriptor<UserPreferences>()).first {
            return existing
        }
        let prefs = UserPreferences()
        modelContext.insert(prefs)
        return prefs
    }

    private func applyStyleSample(_ style: TypingStyle, to preferences: UserPreferences) {
        let smoothing = preferences.styleUpdateCount > 0 ? 0.8 : 0.0
        preferences.formalityScore = blend(preferences.formalityScore, with: style.formalityScore, smoothing: smoothing)
        preferences.punctuationDensity = blend(preferences.punctuationDensity, with: style.punctuationDensity, smoothing: smoothing)
        preferences.emojiUsageFrequency = blend(preferences.emojiUsageFrequency, with: style.emojiUsageFrequency, smoothing: smoothing)
        preferences.contractionUsageFrequency = blend(preferences.contractionUsageFrequency, with: style.contractionUsage, smoothing: smoothing)
        preferences.exclamationFrequency = blend(preferences.exclamationFrequency, with: style.exclamationFrequency, smoothing: smoothing)
        preferences.averageSentenceLength = blend(preferences.averageSentenceLength, with: style.averageSentenceLength, smoothing: smoothing, clampRange: 1.0...60.0)
        preferences.energyLevel = blend(preferences.energyLevel, with: style.energyLevel, smoothing: smoothing)

        switch style.capitalizationPattern {
        case .proper:
            preferences.capitalizationPattern = "proper"
        case .lowercase:
            preferences.capitalizationPattern = "lowercase"
        case .mixed:
            preferences.capitalizationPattern = "mixed"
        }

        preferences.styleUpdateCount = min(preferences.styleUpdateCount + 1, Int.max)
        preferences.updatedAt = Date()
    }

    private func blend(
        _ current: Double,
        with sample: Double,
        smoothing: Double,
        clampRange: ClosedRange<Double>? = 0.0...1.0
    ) -> Double {
        let alpha = max(0.0, min(1.0, smoothing))
        let beta = 1.0 - alpha
        var blended = alpha * current + beta * sample
        if let range = clampRange {
            blended = min(max(blended, range.lowerBound), range.upperBound)
        }
        return blended
    }
    
    func clearMessages() {
        messages.removeAll()
        currentConversation = nil
        selectedConversation = nil
        pendingOperation = nil
        pendingImageAttachment = nil
        inputText = ""
        isScrolledToBottom = true
        messagePayloadCache.removeAll()
    }
    
    // MARK: - Message Editing
    
    func editAndRegenerateMessage(_ messageToEdit: AIMessage, newContent: String, modelContext: ModelContext) {
        guard let messageIndex = messages.firstIndex(where: { $0.id == messageToEdit.id }) else {
            return
        }
        
        // Update the message content
        messageToEdit.content = newContent
        messageToEdit.timestamp = Date()
        if let existingPayload = messagePayloadCache[messageToEdit.id] {
            messagePayloadCache[messageToEdit.id] = ResendPayload(
                text: newContent,
                image: existingPayload.image,
                document: existingPayload.document
            )
        } else {
            messagePayloadCache[messageToEdit.id] = ResendPayload(
                text: newContent,
                image: nil,
                document: nil
            )
        }
        
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
                if message.role == "user" {
                    messagePayloadCache.removeValue(forKey: message.id)
                }
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
        
        let typingStyle = StyleAnalyzer.analyzeStyle(text: newContent)
        let stylePreferences = fetchOrCreatePreferences(modelContext: modelContext)
        applyStyleSample(typingStyle, to: stylePreferences)
        let emotionalSnapshot = EmotionAnalyzer.analyzeTone(text: newContent)
        stylePreferences.lastUserEmotion = emotionalSnapshot.primaryEmotion.rawValue
        if let topic = StyleAnalyzer.primaryTopic(from: newContent) {
            stylePreferences.lastConversationTopic = topic
        }
        stylePreferences.lastEmotionalUpdate = Date()
        try? modelContext.save()
        
        _Concurrency.Task {
            await processMessage(
                newContent,
                modelContext: modelContext,
                isFirstMessage: isFirstMessage,
                currentStyle: typingStyle,
                styleProfile: stylePreferences
            )
        }
    }
    
    // MARK: - Conversation Management
    
    func loadConversation(_ conversation: AIConversation, modelContext: ModelContext) -> Bool {
        pendingOperation = nil
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
        messagePayloadCache.removeAll()
        for message in messages where message.role == "user" {
            messagePayloadCache[message.id] = ResendPayload(
                text: message.content ?? "",
                image: nil,
                document: nil
            )
        }
        
        // Auto-generate summary if conditions are met
        if let messages = conversation.messages,
           messages.count >= 5,
           conversation.summary == nil || conversation.lastSummaryGeneratedAt == nil {
            _Concurrency.Task {
                await generateSummary(for: conversation, modelContext: modelContext)
            }
        }
        
        isScrolledToBottom = true
        return true // Successfully loaded
    }
    
    func generateAndSetTitle(from firstMessage: String, conversation: AIConversation, modelContext: ModelContext) async {
        do {
            let title = try await coreResponseService.generateConversationTitle(from: firstMessage)
            
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
            let summary = try await coreResponseService.generateConversationSummary(messages: messages)
            
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
        guard let messages = conversation.messages, !messages.isEmpty else { return }
        
        // Use AIRecallService to generate tags using AI
        let tags = await AIRecallService.shared.extractConversationTags(messages: messages)
        
        await MainActor.run {
            // Only update tags if they're empty or if new tags are better
            if conversation.tags.isEmpty || !tags.isEmpty {
                conversation.tags = tags
                
                do {
                    try modelContext.save()
                } catch {
                    print("Failed to save tags: \(error)")
                }
            }
        }
    }
    
    func exportToDraft(messages: [AIMessage], conversation: AIConversation, modelContext: ModelContext) -> Draft {
        // Extract all assistant messages
        let assistantMessages = messages.filter { $0.role == "assistant" }
        let content = assistantMessages.compactMap { $0.content }.joined(separator: "\n\n")
        
        // Create draft with conversation title as notes
        let draft = Draft(
            title: conversation.title ?? "Aurora Conversation",
            caption: content,
            tags: conversation.tags,
            notes: "From AI Conversation: \(conversation.title ?? "Untitled")"
        )
        draft.source = "AI Assistant"
        draft.applyAutoTaggingForAIExport(conversationTitle: conversation.title)
        draft.refreshContentSignals()
        draft.refreshWordMetrics()
        draft.isPublished = false
        draft.lastEditedAt = Date()
        
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
            let summary = try await coreResponseService.summarizeRecentMessages(
                await coreResponseService.convertMessagesToConversationMessages(conversationMessages),
                count: 15
            )
            
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
    
    // MARK: - Smart Recap & Export
    
    /// Generate a smart recap (auto-summary) for the current conversation
    func generateSmartRecap(modelContext: ModelContext) async {
        guard let conversation = currentConversation else { return }
        
        // Use AIRecallService to generate context snapshot
        if let snapshot = await AIRecallService.shared.generateContextSnapshot(
            conversationId: conversation.id,
            modelContext: modelContext
        ) {
            // Update conversation with snapshot data
            conversation.summary = snapshot.summary
            if conversation.tags.isEmpty {
                conversation.tags = snapshot.tags
            }
            try? modelContext.save()
        }
    }
    
    /// Generate chat summary (legacy method name)
    func generateChatSummary(modelContext: ModelContext? = nil) async {
        guard currentConversation != nil else { return }
        // Use provided modelContext or fallback to shared container
        let context = modelContext ?? FocusOSApp.sharedModelContainer.mainContext
        await generateSmartRecap(modelContext: context)
    }
    
    /// Export conversation to Drafts (rich text with metadata)
    func exportToDraft(messages: [AIMessage], conversation: AIConversation, modelContext: ModelContext) -> Bool {
        guard !messages.isEmpty else { return false }
        
        let content = messages.map { message -> String in
            let role = message.role == "user" ? "You" : "Aurora"
            return "\(role): \(message.content ?? "")"
        }.joined(separator: "\n\n")
        
        let draft = Draft(
            caption: content,
            mediaURLs: [],
            tags: conversation.tags,
            notes: conversation.summary
        )
        
        modelContext.insert(draft)
        do {
            try modelContext.save()
            return true
        } catch {
            AIDebug.log("Failed to export to draft: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Export conversation to Notes (Markdown summary)
    func exportToNote(messages: [AIMessage], conversation: AIConversation, modelContext: ModelContext) -> Bool {
        guard !messages.isEmpty else { return false }
        
        let summary = conversation.summary ?? "Conversation summary"
        let markdown = """
        # \(conversation.title ?? "Conversation")
        
        \(summary)
        
        ## Messages
        
        \(messages.map { message -> String in
            let role = message.role == "user" ? "You" : "Aurora"
            return "### \(role)\n\n\(message.content ?? "")"
        }.joined(separator: "\n\n"))
        """
        
        let note = Note(
            title: conversation.title ?? "AI Conversation",
            markdown: markdown
        )
        
        modelContext.insert(note)
        do {
            try modelContext.save()
            return true
        } catch {
            AIDebug.log("Failed to export to note: \(error.localizedDescription)")
            return false
        }
    }
    
    func resendAssistantMessage(_ message: AIMessage, modelContext: ModelContext) {
        guard message.role == "assistant" else { return }
        guard let targetIndex = messages.firstIndex(where: { $0.id == message.id }) else { return }
        guard let userMessage = messages[..<targetIndex].last(where: { $0.role == "user" }) else { return }
        
        let payload = messagePayloadCache[userMessage.id]
        let content = payload?.text ?? userMessage.content ?? ""
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasAttachment = (payload?.image != nil) || (payload?.document != nil)
        guard !trimmed.isEmpty || hasAttachment else { return }
        
        inputText = content
        isScrolledToBottom = true
        sendMessage(
            content,
            modelContext: modelContext,
            image: payload?.image,
            document: payload?.document
        )
    }
    
    func canResendPayload(for message: AIMessage) -> Bool {
        guard message.role == "assistant" else { return false }
        guard let targetIndex = messages.firstIndex(where: { $0.id == message.id }) else { return false }
        guard let userMessage = messages[..<targetIndex].last(where: { $0.role == "user" }) else { return false }
        let payload = messagePayloadCache[userMessage.id]
        let content = payload?.text ?? userMessage.content ?? ""
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return (!trimmed.isEmpty || payload?.image != nil || payload?.document != nil) && !isLoading
    }
    
    /// Export conversation to Journal (emotional reflection only)
    func exportToJournal(messages: [AIMessage], conversation: AIConversation, modelContext: ModelContext) -> Bool {
        guard !messages.isEmpty else { return false }
        
        // Extract emotional reflection from conversation
        let emotionalTone = conversation.tags.contains("Reflection") ? "Reflective" : "Neutral"
        let reflection = """
        ## \(conversation.title ?? "Conversation Reflection")
        
        **Emotional Tone:** \(emotionalTone)
        
        **Summary:** \(conversation.summary ?? "No summary available")
        
        **Key Insights:**
        \(messages.filter { $0.role == "assistant" }.prefix(3).map { "- \($0.content ?? "")" }.joined(separator: "\n"))
        """
        
        // Create journal entry (assuming JournalEntry model exists)
        // For now, create a Note with journal-specific content
        let note = Note(
            title: "Reflection: \(conversation.title ?? "Conversation")",
            markdown: reflection
        )
        
        modelContext.insert(note)
        do {
            try modelContext.save()
            return true
        } catch {
            AIDebug.log("Failed to export to journal: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Stop & Retry
    
    func stopResponse(modelContext: ModelContext) {
        currentResponseTask?.cancel()
        currentResponseTask = nil
        isLoading = false
        currentActivity = .thinking
        currentSourceModel = nil
        
        // Don't add any message - just stop silently
    }
    
    func retryLastMessage(modelContext: ModelContext) {
        guard let lastMessage = lastUserMessage else { return }
        
        if let lastAssistantMessage = messages.last, lastAssistantMessage.role == "assistant" {
            messages.removeLast()
            currentConversation?.messages?.removeLast()
            modelContext.delete(lastAssistantMessage)
            try? modelContext.save()
        }
        
        let cachedIntent = lastIntentMessageId.flatMap {
            ConversationFlowService.shared.cachedIntent(for: $0)
        } ?? lastParsedIntent
        
        _Concurrency.Task { @MainActor in
            #if DEBUG
            print("[AIAssistantViewModel] Retry triggered (cached intent: \(cachedIntent != nil))")
            #endif
            retryModeActive = true
            defer { retryModeActive = false }
            
            var intentToRetry = cachedIntent
            if intentToRetry == nil {
                intentToRetry = await coreResponseService.cachedParsedIntent(for: lastMessage.text)
            }
            
            if let intentToRetry {
                let handled = await executeIntent(
                    intentToRetry,
                    modelContext: modelContext,
                    isFirstMessage: false,
                    messageText: lastMessage.text,
                    payloadContext: nil
                )
                if handled {
                    return
                }
            }
            
            sendMessage(
                lastMessage.text,
                modelContext: modelContext,
                image: lastMessage.image,
                document: lastMessage.document
            )
        }
    }

    var canResendLastAssistant: Bool {
        guard let lastAssistant = messages.last(where: { $0.role == "assistant" }) else { return false }
        return canResendPayload(for: lastAssistant)
    }

    func resendLastAssistant(modelContext: ModelContext) {
        guard let lastAssistant = messages.last(where: { $0.role == "assistant" }) else { return }
        resendAssistantMessage(lastAssistant, modelContext: modelContext)
    }


    private func recordIntent(from payloadContext: AIPayloadContext) {
        if payloadContext.intent == .social {
            lastSocialIntentAt = Date()
        }
    }

    private func shouldBlockTaskCreation(
        for messageText: String?,
        payloadContext: AIPayloadContext?
    ) -> Bool {
        let now = Date()
        if payloadContext?.intent == .social {
            lastSocialIntentAt = now
            return true
        }
        if let lastSocialIntentAt,
           now.timeIntervalSince(lastSocialIntentAt) < socialIntentCooldown {
            return true
        }
        guard let messageText = messageText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !messageText.isEmpty else {
            return false
        }
        if messageText.count < 20 {
            let lower = messageText.lowercased()
            if !workKeywordSet.contains(where: { lower.contains($0) }) {
                lastSocialIntentAt = now
                return true
            }
        }
        return false
    }
    
    // MARK: - Research Mode
    
    func setResearchMode(_ active: Bool) {
        researchModeActive = active
        if !active {
            currentResearchAction = nil
            currentResearchSourceCount = 0
        }
    }
    
    func clearResearchMode() {
        setResearchMode(false)
    }
}
