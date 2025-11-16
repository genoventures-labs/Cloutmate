//
//  CoreResponseService.swift
//  Cloutmate
//
//  Abstraction layer for AI response generation
//  Currently routes to OllamaBridgeService (local Ollama)
//  Integrated with AuroraToneKit for tone-aware responses
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
        modelContext: ModelContext? = nil,
        toneContext: AuroraTone? = nil
    ) async throws -> String {
        // Apply tone context to prompt if provided
        var enhancedInput = input
        var enhancedContext = context
        
        if let tone = toneContext {
            let promptPrefix = AuroraToneKit.promptPrefix(for: tone)
            let toneDescription = AuroraToneKit.summaryTone(for: tone)
            
            // Prepend tone prefix to input
            enhancedInput = "\(promptPrefix). \(input)"
            
            // Add tone description to context
            if !enhancedContext.isEmpty {
                enhancedContext += "\n\nTone guidance: \(toneDescription)"
            } else {
                enhancedContext = "Tone guidance: \(toneDescription)"
            }
        }
        
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
                for: enhancedInput,
                context: enhancedContext,
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
            return try await ollamaBridge.generateResponse(for: enhancedInput, context: enhancedContext)
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
        modelContext: ModelContext? = nil,
        preselectedDecision: ModelRoutingDecision? = nil,
        toneContext: AuroraTone? = nil,
        predictedNextTone: AuroraTone? = nil
    ) async throws -> (response: String, thinking: String?, modelUsed: String) {
        // Apply tone context to prompt and app context if provided
        var enhancedInput = input
        var enhancedAppContext = appContext
        
        // Apply tone context with optional prediction bias
        if let tone = toneContext {
            let promptPrefix = AuroraToneKit.promptPrefix(for: tone)
            let toneDescription = AuroraToneKit.summaryTone(for: tone)
            
            // Prepend tone prefix to input
            enhancedInput = "\(promptPrefix). \(input)"
            
            // Add tone description to app context
            var toneGuidance = "Your response should be \(toneDescription)."
            
            // If prediction exists and differs from current tone, add predictive bias
            if let predicted = predictedNextTone, predicted != tone {
                let predictedDescription = AuroraToneKit.summaryTone(for: predicted)
                let predictedCategory = AuroraToneKit.category(for: predicted)
                let currentCategory = AuroraToneKit.category(for: tone)
                
                if predictedCategory == currentCategory {
                    // Same category - subtle shift
                    toneGuidance += " You may begin to shift toward \(predictedDescription) as the conversation evolves."
                } else {
                    // Different category - prepare for transition
                    toneGuidance += " The conversation may transition toward \(predictedDescription) - be prepared to adapt smoothly."
                }
            }
            
            if !enhancedAppContext.isEmpty {
                enhancedAppContext += "\n\nTone guidance: \(toneGuidance)"
            } else {
                enhancedAppContext = "Tone guidance: \(toneGuidance)"
            }
        } else if let predicted = predictedNextTone {
            // No current tone, but we have a prediction - use it as initial guidance
            let predictedDescription = AuroraToneKit.summaryTone(for: predicted)
            let promptPrefix = AuroraToneKit.promptPrefix(for: predicted)
            enhancedInput = "\(promptPrefix). \(input)"
            
            if !enhancedAppContext.isEmpty {
                enhancedAppContext += "\n\nPredicted tone guidance: Your response should be \(predictedDescription)."
            } else {
                enhancedAppContext = "Predicted tone guidance: Your response should be \(predictedDescription)."
            }
        }
        
        // Use local Ollama routing with ModelRoutingEngine
        if let modelContext = modelContext {
            // Check for research mode (from payload context metadata or input detection)
            let isResearchMode = payloadContext?.metadata["isResearchMode"] as? Bool ?? false ||
                                input.lowercased().hasPrefix("/research") ||
                                input.lowercased().contains("research mode")
            
            // Get routing decision from ModelRoutingEngine
            let routingDecision: ModelRoutingDecision
            if let preselectedDecision {
                routingDecision = preselectedDecision
            } else {
                let intentCluster = payloadContext?.intentClusters?.primaryCluster
                let confidenceScore = payloadContext?.intentClusters?.confidence ?? confidence?.score ?? 0.7
                let messageLength = input.count
                
                routingDecision = await ModelRoutingEngine.shared.selectModel(
                    input: input,
                    intentCluster: intentCluster,
                    confidence: confidenceScore,
                    messageLength: messageLength,
                    userStyle: currentMessageStyle,
                    conversationId: nil,
                    isResearchMode: isResearchMode
                )
            }
            
            // Use OllamaBridgeService with the selected model and thinking setting
            let result = try await ollamaBridge.generateResponseWithAppContext(
                for: enhancedInput,
                appContext: enhancedAppContext,
                payloadContext: payloadContext,
                conversationMessages: conversationMessages,
                currentMessageStyle: currentMessageStyle,
                userStyleProfile: userStyleProfile,
                confidence: confidence,
                useThinking: routingDecision.useThinking,
                model: routingDecision.model,
                initialCasualConversation: routingDecision.isCasual,
                toneContext: toneContext,
                modelContext: modelContext
            )
            
            // Record model usage for cooldown/stickiness
            await ModelRoutingEngine.shared.recordModelUsage(routingDecision.model)
            
            return result
        } else {
            // Fallback to local Ollama if no modelContext (legacy compatibility)
            let response = try await ollamaBridge.generateResponseWithAppContext(
                for: enhancedInput,
                appContext: enhancedAppContext,
                payloadContext: payloadContext,
                conversationMessages: conversationMessages,
                currentMessageStyle: currentMessageStyle,
                userStyleProfile: userStyleProfile,
                confidence: confidence,
                useThinking: false,
                model: nil,
                toneContext: toneContext,
                modelContext: modelContext
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
        // Safety guard: Force isResearchMode = false for images regardless of conversation mode
        var safePayloadContext = payloadContext
        if safePayloadContext == nil {
            safePayloadContext = AIPayloadContext(intent: .general)
        }
        safePayloadContext?.metadata["isResearchMode"] = false
        
        // Use image routing from ModelRoutingEngine
        let imageRoutingDecision = await ModelRoutingEngine.shared.selectImageModel()
        print("[CoreResponseService] Routing image analysis to \(imageRoutingDecision.model) via Ollama")
        
        return try await hybridBridge.analyzeImage(
            imageData: imageData,
            mimeType: mimeType,
            userPrompt: userPrompt,
            appContext: appContext,
            payloadContext: safePayloadContext,
            conversationMessages: conversationMessages,
            currentMessageStyle: currentMessageStyle,
            userStyleProfile: userStyleProfile,
            confidence: confidence
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
        // Safety guard: Force isResearchMode = false for documents regardless of conversation mode
        var safePayloadContext = payloadContext
        if safePayloadContext == nil {
            safePayloadContext = AIPayloadContext(intent: .general)
        }
        safePayloadContext?.metadata["isResearchMode"] = false
        
        // Use document routing from ModelRoutingEngine
        let documentRoutingDecision = await ModelRoutingEngine.shared.selectDocumentModel()
        
        return try await ollamaBridge.analyzeDocument(
            descriptor: descriptor,
            userPrompt: userPrompt,
            appContext: appContext,
            payloadContext: safePayloadContext,
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
    
    func generateInsights(
        conversations: [ConversationSummaryContext],
        toneContext: AuroraTone? = nil
    ) async throws -> String {
        // Convert ConversationSummaryContext to tuple format expected by OllamaBridgeService
        let conversationTuples = conversations.map { ($0.title, $0.keyTopics) }
        
        // Apply tone context if provided
        if let tone = toneContext {
            let promptPrefix = AuroraToneKit.promptPrefix(for: tone)
            let toneDescription = AuroraToneKit.summaryTone(for: tone)
            
            // Generate insights with tone-aware prompt
            let baseInsights = try await ollamaBridge.generateInsights(conversations: conversationTuples)
            return "\(promptPrefix). \(baseInsights)\n\n[Generated with \(toneDescription) tone]"
        } else {
            // Use default insightful tone for insights
            let defaultTone = AuroraTone.insightful
            let promptPrefix = AuroraToneKit.promptPrefix(for: defaultTone)
            let toneDescription = AuroraToneKit.summaryTone(for: defaultTone)
            
            let baseInsights = try await ollamaBridge.generateInsights(conversations: conversationTuples)
            return "\(promptPrefix). \(baseInsights)"
        }
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
    case publishPost
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
    case duplicateProject
    case createArtifact
    case updateArtifact
    case deleteArtifact
    case convertTaskToNote
    case digestConversation
    case digestAllConversations
    case searchConversations
    case createReminder
}

struct ExecutionIntent: Codable {
    var operation: ExecutionOperation
    var criteria: String?
    var daysAgo: Int?
    var postFilter: String?
    var filterValue: String?
    var reportType: String?
    var daysAhead: Int?
    var caption: String?
    var scheduledDate: String?
    var tags: [String]?
    var notes: String?
    var createDraft: Bool?
    var draftId: String?
    var taskId: String?
    var taskTitle: String?
    var taskTitles: [String]?
    var taskNotes: String?
    var taskDueDate: String?
    var taskStatus: String?
    var taskPriority: String?
    var taskProjectId: String?
    var taskAreaId: String?
    var noteId: String?
    var noteTitle: String?
    var noteTitles: [String]?
    var noteBody: String?
    var noteTags: [String]?
    var inboxItemId: String?
    var inboxContent: String?
    var inboxType: String?
    var conversionTarget: String?
    var projectId: String?
    var projectTitle: String?
    var projectGoal: String?
    var projectStatus: String?
    var projectDueDate: String?
    var projectAreaId: String?
    var postId: String?
    var postCaptions: [String]?
    var publishNotes: String?
    var conversationId: String?
    var searchQuery: String?
    var createTasksWithProject: Bool?
    var createNotesWithProject: Bool?
    var createPostsWithProject: Bool?
    var createTasksWithNote: Bool?
    var createPostsWithNote: Bool?
    var createTasksWithPost: Bool?
    var createNotesWithPost: Bool?
    var taskCount: Int?
    var noteCount: Int?
    var postCount: Int?
    var reminderTitle: String?
    var reminderNotes: String?
    var reminderDate: String?
    var reminderTime: String?
    var reminderTaskId: String?
    var reminderProjectId: String?
    var artifactId: String?
    var artifactTitle: String?
    var artifactContent: String?
    var artifactFormat: String?
    var artifactState: String?
    var artifactTags: [String]?
    var artifactProjectId: String?
    var artifactAreaId: String?
    var artifactNotes: String?
    var createTasksWithArtifact: Bool?
    var createNotesWithArtifact: Bool?
    var duplicateProjectTitle: String?
    var duplicateIncludeTasks: Bool?
    var convertDeleteOriginal: Bool?
    var linkedContext: LinkedContext?
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

