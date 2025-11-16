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
                    conversationId: nil
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
        print("[CoreResponseService] Routing image analysis to Gemma3 via Ollama")
        return try await hybridBridge.analyzeImage(
            imageData: imageData,
            mimeType: mimeType,
            userPrompt: userPrompt,
            appContext: appContext,
            payloadContext: payloadContext,
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
    
    // MARK: - Research Mode
    
    func generateResearchResponse(
        for input: String,
        appContext: String,
        payloadContext: AIPayloadContext? = nil,
        conversationMessages: [ConversationMessage]? = nil,
        currentMessageStyle: TypingStyle? = nil,
        userStyleProfile: UserPreferences? = nil,
        confidence: ConfidenceSnapshot? = nil,
        toneContext: AuroraTone? = nil,
        modelContext: ModelContext? = nil,
        onProgressUpdate: ((String, Int) -> Void)? = nil
    ) async throws -> (response: String, thinking: String?, modelUsed: String, sources: [ResearchSource]) {
        guard let modelContext = modelContext else {
            throw CoreResponseError.notImplemented("Research mode requires modelContext")
        }
        
        // Note: Model warmup is handled by AIAssistantViewModel before calling this function
        // This ensures models are ready and shows "Getting things ready" messages
        
        // Add research-specific instructions to app context
        // This tells Aurora to format responses like ChatGPT Deep Research: synthesized, comprehensive reports
        let researchInstructions = """

**RESEARCH MODE - RESPONSE FORMAT (like ChatGPT Deep Research):**
- Synthesize all research findings into ONE cohesive, comprehensive narrative report
- Don't just list facts - weave insights together into a flowing narrative
- Integrate information from multiple sources naturally (sources are shown as pills below your response)
- Be authoritative but conversational - like a well-researched article or expert analysis
- Start with an overview or introduction, then dive into key findings
- Connect related ideas and synthesize different perspectives
- End with a summary or conclusion that ties everything together
- Focus on synthesis and analysis, not just enumeration
- Write as if you're creating a research report that tells a complete story
"""
        let enhancedAppContext = appContext + researchInstructions
        
        // Step 1: Local model (deepseek-r1:1.5b) with thinking
        let localModel = "deepseek-r1:1.5b"
        print("[CoreResponseService] Research mode: Running local model \(localModel) with thinking")
        
        // Emit progress: preparing local model
        await MainActor.run {
            onProgressUpdate?("Preparing local model...", 0)
        }
        
        var localResponse: String = ""
        var localThinking: String? = nil
        
        // Try local model with error handling
        do {
            // Emit progress: analyzing locally
            await MainActor.run {
                onProgressUpdate?("Analyzing locally...", 0)
            }
            
            // Ensure model is ready (this will load it if needed)
            do {
                try await ollamaBridge.ensureModelReady(
                    model: localModel,
                    progressHandler: { message in
                        await MainActor.run {
                            onProgressUpdate?(message, 0)
                        }
                    }
                )
            } catch {
                // If model can't be loaded, skip local analysis and proceed with cloud only
                print("[CoreResponseService] Research mode: Failed to load local model \(localModel): \(error.localizedDescription)")
                await MainActor.run {
                    onProgressUpdate?("Local model unavailable, proceeding with cloud analysis...", 0)
                }
                // Add helpful note about installing the model
                localResponse = "Note: Local analysis was skipped because the `deepseek-r1:1.5b` model isn't available. To install it, run `ollama pull deepseek-r1:1.5b` in Terminal. Research will continue with cloud analysis.\n\n"
                localThinking = nil
            }
            
            if localResponse.isEmpty { // Only attempt if not already set by error
                let localResult = try await ollamaBridge.generateResponseWithAppContext(
                    for: input,
                    appContext: enhancedAppContext, // Use enhanced app context with research instructions
                    payloadContext: payloadContext,
                    conversationMessages: conversationMessages,
                    currentMessageStyle: currentMessageStyle,
                    userStyleProfile: userStyleProfile,
                    confidence: confidence,
                    useThinking: true, // Enable thinking for local model
                    model: localModel,
                    initialCasualConversation: false,
                    toneContext: toneContext,
                    modelContext: modelContext
                )
                
                localResponse = localResult.response
                localThinking = localResult.thinking
            }
        } catch {
            // If local model fails, continue with cloud-only analysis
            print("[CoreResponseService] Research mode: Local model error: \(error.localizedDescription)")
            if localResponse.isEmpty {
                localResponse = "Note: Local analysis encountered an issue.\n\n"
            }
        }
        
        // Step 2: Cloud model (gpt-oss:20b) with thinking and web search
        let cloudModel = "gpt-oss:20b"
        let apiKey = await MainActor.run {
            AISettings.shared.ollamaCloudAPIKey
        }
        
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            // Fallback: return only local response
            let localSources = SourceExtractor.extractFromText(localResponse)
            // Synthesize the local response into a report format
            let synthesizedResponse = synthesizeResearchResponse(
                localResponse: localResponse,
                cloudResponse: nil,
                sources: localSources
            )
            return (synthesizedResponse, localThinking, "DeepSeek R1", localSources)
        }
        
        print("[CoreResponseService] Research mode: Running cloud model \(cloudModel) with thinking and web search")
        
        var cloudResponse: String = ""
        var cloudThinking: String? = nil
        var webSearchResults: WebSearchResults? = nil
        
        // Use HybridBridgeService with web search enabled
        // Progress updates for web search and cloud analysis will be handled in HybridBridgeService
        do {
            let cloudResult = try await hybridBridge.generateCloudResponseWithAppContextAndWebSearch(
                for: input,
                appContext: enhancedAppContext, // Use enhanced app context with research instructions
                payloadContext: payloadContext,
                conversationMessages: conversationMessages,
                currentMessageStyle: currentMessageStyle,
                userStyleProfile: userStyleProfile,
                confidence: confidence,
                model: cloudModel,
                apiKey: apiKey,
                useThinking: true, // Enable thinking for cloud model
                enableWebSearch: true, // Enable web search
                modelContext: modelContext,
                onProgressUpdate: onProgressUpdate
            )
            
            cloudResponse = cloudResult.response
            cloudThinking = cloudResult.thinking
            webSearchResults = cloudResult.webSearchResults
        } catch {
            // If cloud model fails, continue with local-only analysis
            // BUT preserve web search results if they were already fetched
            let errorDescription = error.localizedDescription
            print("[CoreResponseService] Research mode: Cloud model error: \(errorDescription)")
            
            // Provide helpful error message based on error type
            let errorMessage: String
            if errorDescription.contains("HTTP 404") {
                errorMessage = "Cloud model 'gpt-oss:20b' not found. Research will continue with local analysis and web search results."
            } else if errorDescription.contains("HTTP 401") || errorDescription.contains("401") {
                errorMessage = "Cloud authentication failed. Research will continue with local analysis and web search results."
            } else {
                errorMessage = "Cloud analysis unavailable. Research will continue with local analysis and web search results."
            }
            
            await MainActor.run {
                onProgressUpdate?(errorMessage, webSearchResults?.results.count ?? 0)
            }
            cloudResponse = ""
            cloudThinking = nil
            // DON'T clear webSearchResults here - they may have been fetched before the cloud request failed
            // webSearchResults is preserved from the try block above if web search succeeded
        }
        
        // Only emit "analyzing with cloud model" progress if cloud request succeeded
        if !cloudResponse.isEmpty {
            await MainActor.run {
                onProgressUpdate?("Analyzing with cloud model...", webSearchResults?.results.count ?? 0)
            }
        }
        
        // Step 3: Extract sources from both responses and web search (before synthesis)
        var sources: [ResearchSource] = []
        
        // Extract from web search results
        if let webResults = webSearchResults {
            let webSources = SourceExtractor.extractFromWebSearch(webResults)
            sources.append(contentsOf: webSources)
        }
        
        // Extract from local response
        let localSources = SourceExtractor.extractFromText(localResponse)
        sources.append(contentsOf: localSources)
        
        // Extract from cloud response
        let cloudSources = SourceExtractor.extractFromText(cloudResponse)
        sources.append(contentsOf: cloudSources)
        
        // Combine and deduplicate
        let allSources = SourceExtractor.combineSources([sources])
        
        // Emit progress: compiling results
        await MainActor.run {
            onProgressUpdate?("Compiling research results...", allSources.count)
        }
        
        // Step 4: Synthesize responses into a cohesive research report (like ChatGPT Deep Research)
        // Don't just combine with divider - synthesize into one cohesive narrative
        let combinedResponse: String
        if localResponse.isEmpty || (localResponse.contains("Note:") && !localResponse.contains("Local analysis was skipped")) {
            // Only cloud response or local failed - synthesize what we have
            combinedResponse = synthesizeResearchResponse(
                localResponse: nil,
                cloudResponse: cloudResponse,
                sources: allSources
            )
        } else if cloudResponse.isEmpty {
            // Only local response - synthesize what we have
            combinedResponse = synthesizeResearchResponse(
                localResponse: localResponse,
                cloudResponse: nil,
                sources: allSources
            )
        } else {
            // Both responses - synthesize into one cohesive report
            combinedResponse = synthesizeResearchResponse(
                localResponse: localResponse,
                cloudResponse: cloudResponse,
                sources: allSources
            )
        }
        
        // Combine thinking content
        var combinedThinking: String?
        var thinkingParts: [String] = []
        if let local = localThinking, !local.isEmpty {
            thinkingParts.append("Local analysis: \(local)")
        }
        if let cloud = cloudThinking, !cloud.isEmpty {
            thinkingParts.append("Cloud analysis: \(cloud)")
        }
        if !thinkingParts.isEmpty {
            combinedThinking = thinkingParts.joined(separator: "\n\n")
        }
        
        return (combinedResponse, combinedThinking, "Research Mode", allSources)
    }
    
    /// Synthesizes research responses into a cohesive report format like ChatGPT Deep Research
    /// Takes local and cloud responses and weaves them into a comprehensive narrative
    private func synthesizeResearchResponse(
        localResponse: String?,
        cloudResponse: String?,
        sources: [ResearchSource]
    ) -> String {
        var parts: [String] = []
        
        // Extract key insights from both responses (removing meta-commentary)
        let localInsights = localResponse?.replacingOccurrences(of: "Note: ", with: "")
            .replacingOccurrences(of: "Local analysis was skipped", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false ? localResponse : nil
        
        let cloudInsights = cloudResponse?.trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false ? cloudResponse : nil
        
        // If we have both, synthesize them into one narrative
        if let local = localInsights, let cloud = cloudInsights {
            // Combine insights, avoiding duplication and creating flow
            // Remove any divider markers or meta-commentary
            let cleanLocal = local.replacingOccurrences(of: "---", with: "")
                .replacingOccurrences(of: "Note:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            let cleanCloud = cloud.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // If responses are very different, synthesize them
            // Otherwise, prefer the more comprehensive one
            if cleanLocal.count > cleanCloud.count {
                parts.append(cleanLocal)
                // Add complementary insights from cloud if they're different enough
                if !cleanCloud.isEmpty && !cleanLocal.contains(cleanCloud.prefix(100)) {
                    parts.append("\n" + cleanCloud)
                }
            } else {
                parts.append(cleanCloud)
                // Add complementary insights from local if they're different enough
                if !cleanLocal.isEmpty && !cleanCloud.contains(cleanLocal.prefix(100)) {
                    parts.append("\n" + cleanLocal)
                }
            }
        } else if let local = localInsights {
            // If local response is very short and we have sources, the response might be incomplete
            // Still use it, but ensure it's cleaned properly
            let cleaned = local
                .replacingOccurrences(of: "Note: ", with: "")
                .replacingOccurrences(of: "Local analysis was skipped", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !cleaned.isEmpty {
                parts.append(cleaned)
            }
        } else if let cloud = cloudInsights {
            parts.append(cloud)
        }
        
        let synthesized = parts.joined(separator: "\n\n")
            .replacingOccurrences(of: "Here's how Aurora should respond", with: "")
            .replacingOccurrences(of: "**Aurora:**", with: "")
            .replacingOccurrences(of: "Based on the given data", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If synthesized response is empty or too short, provide helpful message
        if synthesized.isEmpty || (synthesized.count < 50 && !sources.isEmpty) {
            return "I've gathered research on this topic, but the response was incomplete. Please try again or check that the required models are installed and your API key is configured correctly."
        }
        
        return synthesized
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

