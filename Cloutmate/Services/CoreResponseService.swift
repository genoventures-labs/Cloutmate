//
//  CoreResponseService.swift
//  Cloutmate
//
//  Abstraction layer for AI response generation
//  Currently routes to OllamaBridgeService (local Ollama)
//

import Foundation
import SwiftData
import CloutmateShared

// MARK: - Core Response Service

actor CoreResponseService {
    static let shared = CoreResponseService()
    
    private let ollamaBridge = OllamaBridgeService.shared
    private let hybridBridge = HybridBridgeService.shared
    
    private init() {}
    
    // MARK: - Core Generation Methods
    
    func generateResponse(
        for input: String,
        context: String = "",
        modelContext: ModelContext? = nil
    ) async throws -> String {
        // Hybrid bridge is the core implementation - always use it when modelContext is available
        if let modelContext = modelContext {
            let apiKey = await MainActor.run {
                AISettings.shared.ollamaCloudAPIKey
            }
            let latencyThreshold = await MainActor.run {
                AISettings.shared.latencyThreshold
            }
            
            let preferredModel = await MainActor.run {
                AISettings.shared.preferredCloudModel
            }
            
            return try await hybridBridge.generateResponse(
                for: input,
                context: context,
                intentCluster: nil,
                confidence: 0.7,
                preferredModel: preferredModel,
                apiKey: apiKey,
                useHybridBridge: true, // Always enabled as core
                latencyThreshold: latencyThreshold,
                modelContext: modelContext
            )
        } else {
            // Fallback to local Ollama if no modelContext (legacy compatibility)
            return try await ollamaBridge.generateResponse(for: input, context: context)
        }
    }
    
    func generateResponseWithAppContext(
        for input: String,
        appContext: String,
        payloadContext: AIPayloadContext? = nil,
        conversationMessages: [ConversationMessage]? = nil,
        currentMessageStyle: TypingStyle? = nil,
        userStyleProfile: UserPreferences? = nil,
        confidence: ConfidenceSnapshot? = nil,
        modelContext: ModelContext? = nil
    ) async throws -> (response: String, thinking: String?, modelUsed: String) {
        // Use local Ollama routing with ModelRoutingEngine
        if let modelContext = modelContext {
            // Get routing decision from ModelRoutingEngine
            let intentCluster = payloadContext?.intentClusters?.primaryCluster
            let confidenceScore = payloadContext?.intentClusters?.confidence ?? confidence?.score ?? 0.7
            let messageLength = input.count
            
            let routingDecision = await ModelRoutingEngine.shared.selectModel(
                input: input,
                intentCluster: intentCluster,
                confidence: confidenceScore,
                messageLength: messageLength,
                userStyle: currentMessageStyle,
                conversationId: nil
            )
            
            // Use OllamaBridgeService with the selected model and thinking setting
            let result = try await ollamaBridge.generateResponseWithAppContext(
                for: input,
                appContext: appContext,
                payloadContext: payloadContext,
                conversationMessages: conversationMessages,
                currentMessageStyle: currentMessageStyle,
                userStyleProfile: userStyleProfile,
                confidence: confidence,
                useThinking: routingDecision.useThinking,
                model: routingDecision.model
            )
            
            // Record model usage for cooldown/stickiness
            await ModelRoutingEngine.shared.recordModelUsage(routingDecision.model)
            
            return result
        } else {
            // Fallback to local Ollama if no modelContext (legacy compatibility)
            let response = try await ollamaBridge.generateResponseWithAppContext(
                for: input,
                appContext: appContext,
                payloadContext: payloadContext,
                conversationMessages: conversationMessages,
                currentMessageStyle: currentMessageStyle,
                userStyleProfile: userStyleProfile,
                confidence: confidence,
                useThinking: false,
                model: nil
            )
            return response
        }
    }
    
    // MARK: - Message Conversion Helpers
    
    /// Converts AIMessage array to ConversationMessage array
    func convertMessagesToConversationMessages(_ messages: [AIMessage]) async -> [ConversationMessage] {
        return await ollamaBridge.convertMessagesToConversationMessages(messages)
    }
    
    /// Legacy method for compatibility - converts ModelContent to ConversationMessage
    /// Note: This is a compatibility method for legacy code
    func convertMessagesToModelContent(_ messages: [AIMessage]) async -> [ConversationMessage] {
        // This is a compatibility method - just convert AIMessages to ConversationMessages
        return await convertMessagesToConversationMessages(messages)
    }
    
    // MARK: - Intent Detection
    
    func detectExecutionIntent(input: String, linkedContext: LinkedContext? = nil) async throws -> ExecutionIntent? {
        return try await ollamaBridge.detectExecutionIntent(input: input, linkedContext: linkedContext)
    }
    
    func detectReflectionIntent(input: String) async throws -> ReflectionIntent? {
        return try await ollamaBridge.detectReflectionIntent(input: input)
    }
    
    func inferPreferenceUpdate(input: String) async throws -> PreferenceUpdate? {
        return try await ollamaBridge.inferPreferenceUpdate(input: input)
    }
    
    func isAmbiguousQuery(input: String) -> Bool {
        return ollamaBridge.isAmbiguousQuery(input: input)
    }
    
    // MARK: - Document & Image Analysis
    
    func analyzeImage(
        imageData: Data,
        mimeType: String,
        userPrompt: String?,
        appContext: String,
        payloadContext: AIPayloadContext? = nil,
        conversationMessages: [ConversationMessage]? = nil,
        currentMessageStyle: TypingStyle? = nil,
        userStyleProfile: UserPreferences? = nil,
        confidence: ConfidenceSnapshot? = nil
    ) async throws -> DocumentAnalysisResult {
        // Use Gemini 2.5 Flash for image analysis - STRICTLY GEMINI, NO FALLBACK
        let apiKey = await MainActor.run {
            AISettings.shared.googleAPIKey
        }
        
        print("[CoreResponseService] Image analysis requested - Google API Key present: \(apiKey != nil && !apiKey!.isEmpty)")
        
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            let errorMsg = "Image analysis requires Google API key. Please configure it in Config.plist (GoogleAPIKey)."
            print("[CoreResponseService] Image analysis failed: \(errorMsg)")
            throw CoreResponseError.notImplemented(errorMsg)
        }
        
        // Use Gemini 2.5 Flash via GeminiService - NO FALLBACK
        print("[CoreResponseService] Routing image analysis to GeminiService (gemini-2.5-flash)")
        return try await GeminiService.shared.analyzeImage(
            imageData: imageData,
            mimeType: mimeType,
            userPrompt: userPrompt,
            appContext: appContext,
            payloadContext: payloadContext,
            conversationMessages: conversationMessages,
            currentMessageStyle: currentMessageStyle,
            userStyleProfile: userStyleProfile,
            confidence: confidence,
            apiKey: apiKey
        )
    }
    
    func analyzeDocument(
        descriptor: DocumentDescriptor,
        userPrompt: String?,
        appContext: String,
        payloadContext: AIPayloadContext? = nil,
        conversationMessages: [ConversationMessage]? = nil,
        currentMessageStyle: TypingStyle? = nil,
        userStyleProfile: UserPreferences? = nil,
        confidence: ConfidenceSnapshot? = nil
    ) async throws -> DocumentAnalysisResult {
        return try await ollamaBridge.analyzeDocument(
            descriptor: descriptor,
            userPrompt: userPrompt,
            appContext: appContext,
            payloadContext: payloadContext,
            conversationMessages: conversationMessages,
            currentMessageStyle: currentMessageStyle,
            userStyleProfile: userStyleProfile,
            confidence: confidence
        )
    }
    
    // MARK: - AI Tools
    
    func executeTool(_ tool: AITool, input: String, context: String = "") async throws -> AIToolResult {
        return try await ollamaBridge.executeTool(tool, input: input, context: context)
    }
    
    func parseListResponse(_ response: String, tool: AITool) async throws -> [String] {
        return try await ollamaBridge.parseListResponse(response, tool: tool)
    }
    
    // MARK: - Conversation Management
    
    func generateConversationTitle(from firstMessage: String) async throws -> String {
        return try await ollamaBridge.generateConversationTitle(from: firstMessage)
    }
    
    func generateConversationSummary(messages: [AIMessage]) async throws -> String {
        return try await ollamaBridge.generateConversationSummary(messages: messages)
    }
    
    func categorizeConversation(
        messages: [AIMessage],
        summary: String?
    ) async throws -> [String] {
        return try await ollamaBridge.categorizeConversation(messages: messages, summary: summary)
    }
    
    func summarizeRecentMessages(_ messages: [ConversationMessage], count: Int) async throws -> String {
        return try await ollamaBridge.summarizeRecentMessages(messages, count: count)
    }
    
    func generateInsights(conversations: [ConversationSummaryContext]) async throws -> String {
        // Convert ConversationSummaryContext to tuple format expected by OllamaBridgeService
        let conversationTuples = conversations.map { ($0.title, $0.keyTopics) }
        return try await ollamaBridge.generateInsights(conversations: conversationTuples)
    }
    
    func clearHistory() async {
        await ollamaBridge.clearHistory()
    }
}

// MARK: - Error Types

enum CoreResponseError: LocalizedError {
    case notImplemented(String)
    
    var errorDescription: String? {
        switch self {
        case .notImplemented(let message):
            return message
        }
    }
}

// MARK: - Conversation Message Extension

extension ConversationMessage {
    /// Convert from AIMessage format
    init?(from message: AIMessage) {
        guard let content = message.content, !content.isEmpty else { return nil }
        
        let role: String
        if message.role == "assistant" || message.role == "model" {
            role = "assistant"
        } else {
            role = "user"
        }
        
        self.init(role: role, content: content)
    }
}

// MARK: - Type Definitions (previously in GeminiService)

enum SummarySource: String, Sendable, Codable {
    case ollama = "Ollama"
    case appleLLM = "AppleLLM"
    case offline = "Offline"
}

struct DocumentDescriptor: Sendable {
    let text: String
    let preview: String
    let fileName: String
    let mimeType: String
    let sizeInBytes: Int
    let pageCount: Int?
    let sourceURL: String?
}

struct DocumentAnalysisResult: Sendable {
    let summary: String
    let truncatedContext: Bool
    let sourceModel: SummarySource
}

enum ExecutionOperation: String, Codable {
    case archiveTasks
    case summarizePosts
    case generateReport
    case predictScheduling
    case createPost
    case createTask
    case updateTask
    case deleteTask
    case createNote
    case updateNote
    case deleteNote
    case addInboxItem
    case convertInboxItem
    case createProject
    case updateProject
    case deleteProject
    case publishPost
    case digestConversation
    case digestAllConversations
    case searchConversations
    case createReminder
}

struct ExecutionIntent: Codable {
    let operation: ExecutionOperation
    let criteria: String?
    let daysAgo: Int?
    let postFilter: String?
    let filterValue: String?
    let reportType: String?
    let daysAhead: Int?
    let caption: String?
    let platforms: [String]?
    let scheduledDate: String?
    let tags: [String]?
    let notes: String?
    let createDraft: Bool?
    let draftId: String?
    let taskId: String?
    let taskTitle: String?
    let taskTitles: [String]?
    let taskNotes: String?
    let taskDueDate: String?
    let taskStatus: String?
    let taskPriority: String?
    let taskProjectId: String?
    let taskAreaId: String?
    let noteId: String?
    let noteTitle: String?
    let noteTitles: [String]?
    let noteBody: String?
    let noteTags: [String]?
    let inboxItemId: String?
    let inboxContent: String?
    let inboxType: String?
    let conversionTarget: String?
    let projectId: String?
    let projectTitle: String?
    let projectGoal: String?
    let projectStatus: String?
    let projectDueDate: String?
    let projectAreaId: String?
    let postId: String?
    let postCaptions: [String]?
    let publishNotes: String?
    let conversationId: String?
    let searchQuery: String?
    let createTasksWithProject: Bool?
    let createNotesWithProject: Bool?
    let createPostsWithProject: Bool?
    let createTasksWithNote: Bool?
    let createPostsWithNote: Bool?
    let createTasksWithPost: Bool?
    let createNotesWithPost: Bool?
    let taskCount: Int?
    let noteCount: Int?
    let postCount: Int?
    let reminderTitle: String?
    let reminderNotes: String?
    let reminderDate: String?
    let reminderTime: String?
    let reminderTaskId: String?
    let reminderProjectId: String?
    let linkedContext: LinkedContext?
}

enum ReflectionIntent: String, Codable {
    case productivityPatterns
    case emotionalTrends
    case focusEffectiveness
    case learningProgress
    case recurringThemes
    case cognitiveState
    case weekOverview
    case monthOverview
    case detectedPatterns
    case workingStyle
}

struct TimeSlot: Identifiable, Equatable {
    let id = UUID()
    let start: Date
    let end: Date
}

