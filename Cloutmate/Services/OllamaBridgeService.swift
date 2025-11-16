//
//  OllamaBridgeService.swift
//  Cloutmate
//
//  Local Ollama bridge service for Aurora AI responses
//

import Foundation
import SwiftData
import CloutmateShared

// These types are defined in CoreResponseService.swift at file scope
// They're already available when CoreResponseService is imported

// MARK: - Ollama Error Types

enum OllamaError: LocalizedError {
    case connectionFailed
    case serviceUnavailable
    case emptyResponse
    case timeout
    case apiError(String)
    case modelNotFound
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return """
            Ollama is not running or not accessible.
            
            To fix this:
            1. Open Terminal
            2. Run: ollama serve
            3. Wait for "Server started" message
            4. Try again in Cloutmate
            
            Note: Make sure Ollama is installed. If not, install from: https://ollama.ai
            """
        case .serviceUnavailable:
            return """
            Ollama service is unavailable.
            
            Please check that:
            - Ollama is running (run `ollama serve` in Terminal)
            - Ollama is accessible at http://localhost:11434
            """
        case .emptyResponse:
            return "Received empty response from Ollama. The model may need more time to respond. Please try again."
        case .timeout:
            return """
            Request timed out (up to 10 minutes for very large prompts).
            
            Possible causes:
            - Model is loading for the first time (this can take 60-240 seconds)
            - Very large prompts with extensive context (10k-17k+ chars)
            - Ollama is processing a huge request
            - System resources (CPU/memory) are constrained
            - The model needs to be loaded into memory
            - Prompt may be too large for the model to process efficiently
            
            Solutions:
            1. Wait and try again (very large prompts can take 5-10 minutes)
            2. Check Ollama logs: Run `ollama serve` in Terminal to see status
            3. Try a simpler/shorter prompt first
            4. Restart Ollama: Stop and start from Settings, or `pkill ollama && ollama serve`
            5. Ensure Ollama has enough system memory (8GB+ recommended for large models)
            6. Consider using a smaller/faster model for large contexts
            7. Reduce context size in settings if available
            
            Tip: The first request after starting Ollama always takes longest. Very large prompts (15k+ chars) can take 5-10 minutes.
            """
        case .apiError(let message):
            return "Ollama API error: \(message)"
        case .modelNotFound:
            return """
            The requested model is not installed.
            
            To install it:
            1. Open Terminal
            2. Run: ollama pull llama3.1
            3. Wait for download to complete
            4. Try again in Cloutmate
            """
        }
    }
}

// MARK: - Ollama Request/Response Models

private struct OllamaRequest: Codable {
    let model: String
    let prompt: String
    let stream: Bool
    let images: [String]? // Base64-encoded images for vision models
    let options: OllamaOptions? // Model options including thinking mode
}

private struct OllamaOptions: Codable {
    let thinking: Bool?
    
    enum CodingKeys: String, CodingKey {
        case thinking
    }
}

private struct OllamaResponse: Codable {
    let response: String
    let done: Bool
    let error: String?
    let thinking: String? // Thinking content when thinking mode is enabled
}

private struct OllamaStreamResponse: Codable {
    let response: String
    let done: Bool
    let error: String?
}

// MARK: - Conversation Message Type

/// Simple message type for conversation history (replaces ModelContent)
struct ConversationMessage: Sendable {
    let role: String // "user" or "assistant"
    let content: String
}

// MARK: - Ollama Bridge Service

actor OllamaBridgeService {
    static let shared = OllamaBridgeService()
    
    private let baseURL = "http://localhost:11434"
    private var currentModel: String = ModelTierMap.defaultModel() // Use routing engine default (gemma3:1b)
    private var previousModel: String? // Track previous model for switch notifications
    private var cachedAvailableModels: [String] = [] // Cache available models
    private var lastModelFetch: Date?
    private let modelCacheTimeout: TimeInterval = 300 // 5 minutes
    // Context-based timeouts (based on prompt length)
    private let casualTimeout: TimeInterval = 35.0 // Casual (no thinking) - fast Qwen3 responses
    private let analyticalTimeout: TimeInterval = 60.0 // Analytical (thinking) - multi-step thought
    private let fallbackTimeout: TimeInterval = 75.0 // Fallback / Granite3 - safety net
    private let initialLoadTimeout: TimeInterval = 210.0 // Longer timeout for first request/model loading
    
    // Context window-based timeout thresholds
    private let lightContextTimeout: TimeInterval = 35.0 // < 2,000 chars - Light casual queries
    private let normalContextTimeout: TimeInterval = 60.0 // 2,000–6,000 chars - Normal conversation (sweet spot)
    private let largeContextTimeout: TimeInterval = 90.0 // 6,000–10,000 chars - Large contextual input
    private let bigContextTimeout: TimeInterval = 120.0 // 10,000–15,000 chars - Big recall or multi-message summary
    private let hugeContextTimeout: TimeInterval = 180.0 // 15,000+ chars - Full recall or long memory regeneration
    private var isFirstRequest: Bool = true
    private var conversationHistory: [ConversationMessage] = []
    private var schemaDocument: String = ""
    private var lastAvailabilityCheck: Date?
    private var isAvailableCache: Bool = false
    private let availabilityCacheTimeout: TimeInterval = 30.0 // Cache for 30 seconds
    private let changelogService = AuroraChangelogService.shared
    private let promptBuilder = AuroraSystemPromptBuilder.shared
    private var hasAnnouncedPatchNotes: Bool = false
    // Granite handles silent cognition (memory graph, tagging) while Gemma/Gwen stay user-facing

    // Warmup tracking
    private var modelWarmupReadyAt: [String: Date] = [:]
    private var modelWarmupTasks: [String: _Concurrency.Task<Void, Error>] = [:]
    private let warmupFreshnessWindow: TimeInterval = 1800 // 30 minutes freshness window
    private let backgroundModelName = ModelTierMap.backgroundModel()
    private var hasPreWarmedBackgroundModel = false
    private var isPreWarmingBackgroundModel = false
    
    private init() {
        // Prepare schema document for prompts
        schemaDocument = SchemaIntrospector.generateSchemaDocument()
        // Use default model from routing engine (gemma3:1b)
        currentModel = ModelTierMap.defaultModel()
        print("[OllamaBridgeService] Initialized with default model: \(currentModel)")
        
        // Note: Pre-warming is now handled by ModelWarmupService to avoid conflicts and timeouts
        // ModelWarmupService waits for Ollama to be ready and handles warmup properly
        // These automatic pre-warms are disabled to prevent premature requests before user interaction
        // 
        // Pre-warm will happen on-demand when models are actually needed via ensureModelReady()
        // This prevents timeouts when Ollama isn't ready yet
    }
    
    func isModelReady(_ model: String) -> Bool {
        if let readyAt = modelWarmupReadyAt[model],
           Date().timeIntervalSince(readyAt) < warmupFreshnessWindow {
            return true
        }
        modelWarmupReadyAt.removeValue(forKey: model)
        return false
    }
    
    func ensureModelReady(
        model: String,
        progressHandler: ((String) async -> Void)? = nil
    ) async throws {
        if isModelReady(model) {
            return
        }
        
        if let existingTask = modelWarmupTasks[model] {
            try await existingTask.value
            return
        }
        
        let warmupTask = _Concurrency.Task<Void, Error> {
            try await performModelWarmup(
                model: model,
                progressHandler: progressHandler
            )
        }
        
        modelWarmupTasks[model] = warmupTask
        defer {
            modelWarmupTasks.removeValue(forKey: model)
        }
        
        do {
            try await warmupTask.value
        } catch {
            modelWarmupReadyAt.removeValue(forKey: model)
            throw error
        }
    }
    
    private func performModelWarmup(
        model: String,
        progressHandler: ((String) async -> Void)?
    ) async throws {
        // Quick availability check before attempting any warmup
        guard await checkOllamaAvailability() else {
            throw OllamaError.connectionFailed
        }
        
        let attempts: [(timeout: TimeInterval, sleep: UInt64)] = [
            (90.0, 700_000_000),
            (150.0, 1_200_000_000),
            (210.0, 1_800_000_000)
        ]
        
        for (index, attempt) in attempts.enumerated() {
            let attemptNumber = index + 1
            let totalAttempts = attempts.count
            let statusPrefix = ModelTierMap.displayName(for: model)
            
            if let handler = progressHandler {
                await handler("\(statusPrefix) is waking up (\(attemptNumber)/\(totalAttempts))—give me a sec.")
            }
            
            do {
                try await runWarmupPing(model: model, timeout: attempt.timeout)
                modelWarmupReadyAt[model] = Date()
                if model == currentModel {
                    isFirstRequest = false
                }
                if let handler = progressHandler {
                    await handler("\(statusPrefix) is ready. Jumping back in.")
                }
                return
            } catch {
                if attemptNumber == totalAttempts {
                    throw error
                }
                
                if let handler = progressHandler {
                    await handler("Still loading \(statusPrefix). Trying again.")
                }
                try? await _Concurrency.Task.sleep(nanoseconds: attempt.sleep)
            }
        }
    }
    
    private func runWarmupPing(model: String, timeout: TimeInterval) async throws {
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw OllamaError.serviceUnavailable
        }
        
        let prompt = "Warmup ping for \(model)."
        let requestPayload = OllamaRequest(model: model, prompt: prompt, stream: false, images: nil, options: nil)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        request.httpBody = try JSONEncoder().encode(requestPayload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.apiError("Invalid response type during warmup")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw OllamaError.apiError("Warmup ping returned HTTP \(httpResponse.statusCode)")
        }
        
        let decoder = JSONDecoder()
        let ollamaResponse = try decoder.decode(OllamaResponse.self, from: data)
        guard ollamaResponse.error == nil else {
            throw OllamaError.apiError("Warmup ping error: \(ollamaResponse.error!)")
        }
        
        guard !ollamaResponse.response.isEmpty else {
            throw OllamaError.emptyResponse
        }
    }
    
    /// Pre-warms the model by making a small test request to ensure it's loaded
    private func preWarmModel() async {
        do {
            try await ensureModelReady(model: currentModel, progressHandler: nil)
        } catch {
            print("[OllamaBridgeService] Initial warmup failed (non-fatal): \(error.localizedDescription)")
        }
    }
    
    /// Pre-warms the background model used for silent inference tasks
    private func preWarmBackgroundModel() async {
        guard !hasPreWarmedBackgroundModel, !isPreWarmingBackgroundModel else { return }
        isPreWarmingBackgroundModel = true
        defer { isPreWarmingBackgroundModel = false }
        
        // Give Ollama a moment to start before attempting background warmup
        try? await _Concurrency.Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        let isAvailable = await checkOllamaAvailability()
        if !isAvailable {
            print("[OllamaBridgeService] Skipping background pre-warm: Ollama not available")
            return
        }
        
        // Quick readiness check
        do {
            guard let url = URL(string: "\(baseURL)/api/tags") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 2.0
            
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("[OllamaBridgeService] Background model tags check not ready, skipping pre-warm")
                return
            }
        } catch {
            print("[OllamaBridgeService] Background tags check failed, skipping pre-warm: \(error.localizedDescription)")
            return
        }
        
        // Make a tiny request to load the background model into memory
        let wasFirstRequest = isFirstRequest
        if wasFirstRequest {
            isFirstRequest = false
        }
        defer {
            if wasFirstRequest {
                isFirstRequest = true
            }
        }
        
        do {
            let pingPrompt = "Background model readiness check."
            let result = try await makeOllamaRequest(
                prompt: pingPrompt,
                useThinking: false,
                model: backgroundModelName
            )
            
            if !result.response.isEmpty {
                hasPreWarmedBackgroundModel = true
                print("[OllamaBridgeService] Background model '\(backgroundModelName)' pre-warmed successfully.")
            }
        } catch let urlError as URLError {
            hasPreWarmedBackgroundModel = false
            if urlError.code != .cannotConnectToHost &&
                !urlError.localizedDescription.contains("Connection refused") {
                print("[OllamaBridgeService] Background pre-warm failed (non-fatal): \(urlError.localizedDescription)")
            } else {
                print("[OllamaBridgeService] Background pre-warm skipped: Ollama not running")
            }
        } catch {
            hasPreWarmedBackgroundModel = false
            print("[OllamaBridgeService] Background pre-warm failed (non-fatal): \(error.localizedDescription)")
        }
    }
    
    /// Sets the current model (internal use only - for automatic switching during image/document tasks)
    private func setModel(_ model: String) {
        currentModel = model
    }
    
    /// Determines the optimal model for a given task based on complexity and requirements
    /// NOTE: This is only used internally for document analysis. Regular chat always uses default model.
    private func determineOptimalModel(
        input: String,
        appContext: String,
        documentLength: Int? = nil,
        isComplexTask: Bool = false
    ) async -> String {
        // Always use default model for regular chat - model switching is disabled
        // This function is kept for potential future use but currently returns default
        return ModelTierMap.defaultModel()
    }
    
    /// Determines if task requires specialized model capabilities
    private func shouldUseSpecializedModel(
        input: String,
        documentLength: Int?,
        isComplexTask: Bool
    ) -> Bool {
        let inputLower = input.lowercased()
        
        // Complex analytical tasks benefit from larger models
        if isComplexTask || (documentLength ?? 0) > 10000 {
            return true
        }
        
        // Coding tasks might benefit from code-specific models
        if inputLower.contains("code") || inputLower.contains("programming") || 
           inputLower.contains("function") || inputLower.contains("class") ||
           inputLower.contains("bug") || inputLower.contains("debug") {
            return true
        }
        
        // Complex reasoning tasks
        if inputLower.contains("analyze") || inputLower.contains("compare") ||
           inputLower.contains("strategy") || inputLower.contains("plan") {
            return true
        }
        
        return false
    }
    
    /// Selects the best model from available models for the task
    private func selectModelForTask(
        availableModels: [String],
        input: String,
        documentLength: Int?,
        isComplexTask: Bool,
        preferredModel: String
    ) -> String {
        let inputLower = input.lowercased()
        
        // Prefer user's preferred model if available
        if availableModels.contains(preferredModel) {
            return preferredModel
        }
        
        // For coding tasks, prefer code-specific models
        if inputLower.contains("code") || inputLower.contains("programming") ||
           inputLower.contains("function") || inputLower.contains("class") {
            if let codeModel = availableModels.first(where: { $0.contains("code") || $0.contains("codellama") }) {
                return codeModel
            }
        }
        
        // For complex tasks, prefer larger models
        if isComplexTask || (documentLength ?? 0) > 10000 {
            // Prefer models with "pro" or larger variants
            if let proModel = availableModels.first(where: { $0.contains("pro") || $0.contains("70b") || $0.contains("8b") }) {
                return proModel
            }
        }
        
        // Default to routing engine's default model
        return ModelTierMap.defaultModel()
    }
    
    /// Switches to optimal model for current task and returns whether a switch occurred
    /// NOTE: This is deprecated - model switching is now automatic only for image tasks
    private func switchToOptimalModelIfNeeded(
        input: String,
        appContext: String,
        documentLength: Int? = nil,
        isComplexTask: Bool = false
    ) async -> Bool {
        // Model switching is disabled - always use default model
        return false
    }
    
    /// Gets notification text for model switch (to be included in Aurora's response)
    func getModelSwitchNotification(fromModel: String?, toModel: String) -> String {
        guard let fromModel = fromModel, fromModel != toModel else {
            return ""
        }
        
        // Generate natural notification text
        let modelDisplayName = toModel.replacingOccurrences(of: "llama", with: "Llama ")
            .replacingOccurrences(of: "mistral", with: "Mistral ")
            .replacingOccurrences(of: "qwen2.5-coder", with: "Qwen2.5 Coder")
            .replacingOccurrences(of: "qwen", with: "Qwen ")
            .replacingOccurrences(of: "gwen", with: "Gwen ")
            .replacingOccurrences(of: "gemma", with: "Gemma ")
            .replacingOccurrences(of: "code", with: "Code ")
            .replacingOccurrences(of: "coder", with: "Coder")
            .capitalized
        
        return "\n\n_💡 Switched to \(modelDisplayName) for this task to give you the best response._"
    }
    
    /// Fetch available models from Ollama API
    func fetchAvailableModels() async throws -> [String] {
        // Check cache first
        if let lastFetch = lastModelFetch,
           Date().timeIntervalSince(lastFetch) < modelCacheTimeout,
           !cachedAvailableModels.isEmpty {
            return cachedAvailableModels
        }
        
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            throw OllamaError.connectionFailed
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0 // Reduced timeout to fail faster
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw OllamaError.connectionFailed
            }
            
            // Parse response
            struct OllamaTagsResponse: Codable {
                let models: [OllamaModel]
            }
            
            struct OllamaModel: Codable {
                let name: String
            }
            
            let decoder = JSONDecoder()
            let tagsResponse = try decoder.decode(OllamaTagsResponse.self, from: data)
            
            let models = tagsResponse.models.map { $0.name }
            
            // Update cache
            cachedAvailableModels = models
            lastModelFetch = Date()
            
            return models
        } catch {
            // If fetch fails, return empty array - don't throw
            // This allows the app to continue working even if Ollama is slow
            print("[OllamaBridgeService] Failed to fetch available models: \(error.localizedDescription)")
            return []
        }
    }
    
    func checkOllamaAvailability() async -> Bool {
        // Check cache first
        if let lastCheck = lastAvailabilityCheck,
           Date().timeIntervalSince(lastCheck) < availabilityCacheTimeout {
            return isAvailableCache
        }
        
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            lastAvailabilityCheck = Date()
            isAvailableCache = false
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let isAvailable = (response as? HTTPURLResponse)?.statusCode == 200
            lastAvailabilityCheck = Date()
            isAvailableCache = isAvailable
            return isAvailable
        } catch let urlError as URLError {
            lastAvailabilityCheck = Date()
            if urlError.code == .timedOut {
                print("[OllamaBridgeService] Availability check timed out – assuming Ollama is warming up")
                if isAvailableCache || hasPreWarmedBackgroundModel || !isFirstRequest {
                    isAvailableCache = true
                    return true
                }
            }
            isAvailableCache = false
            return false
        } catch {
            lastAvailabilityCheck = Date()
            isAvailableCache = false
            return false
        }
    }
    
    /// Forces a fresh availability check (bypasses cache)
    func forceAvailabilityCheck() async -> Bool {
        lastAvailabilityCheck = nil
        isAvailableCache = false
        return await checkOllamaAvailability()
    }
    
    // MARK: - Core Generation Methods
    
    func generateResponse(for input: String, context: String = "") async throws -> String {
        // Check availability first
        guard await checkOllamaAvailability() else {
            throw OllamaError.connectionFailed
        }
        
        // Use routing engine to select model for simple requests too
        let routingDecision = await ModelRoutingEngine.shared.selectModel(
            input: input,
            intentCluster: nil,
            confidence: 0.7,
            messageLength: input.count,
            userStyle: nil,
            conversationId: nil
        )
        
        // Set the model if different
        if routingDecision.model != currentModel {
            setModel(routingDecision.model)
        }
        
        print("[OllamaBridgeService] Simple generateResponse - routing selected: \(routingDecision.model), thinking: \(routingDecision.useThinking)")
        
        // Build system prompt
        var systemPrompt = """
You are Aurora, the AI assistant that lives inside the Cloutmate app. You are not Cloutmate itself; you are the close friend who helps run Cloutmate's adaptive operating system for focus, publishing, and creative execution.

Your capabilities and recent updates are tracked in your changelog, which is automatically included in your context. When users ask about features, capabilities, or updates, reference the changelog information provided in your context.

Help users brainstorm, write, plan, schedule, optimize their workflows, and maintain focus. Be friendly, encouraging, specific, and action-biased. Remember conversation context and emotional continuity.

**CRITICAL: Always respond conversationally. Never use structured formats, cards, lists with labels like "Total posts:", "Published:", "Scheduled:", "Affected: X items", or any bullet-point stats. Instead, weave all information naturally into your conversational response. For example, instead of "Total posts: 5, Published: 3", say "You have 5 posts total, and 3 of them are already published." Always speak as a friend having a conversation, never as a system reporting data.

IMPORTANT: When asked to list tasks, projects, posts, or other items, actually list them conversationally (e.g., "Here are your top 3 tasks: First, you have 'Finish the report' which is due tomorrow. Second, there's 'Review the design' that's high priority. And third, 'Call the client' is scheduled for this afternoon."). Only provide summaries when explicitly asked for a summary. If the user asks "what are my tasks?" or "list my tasks", give them the actual list, not just a summary count.**

**ABSOLUTE RULE - NEVER USE META-COMMENTARY:**
NEVER start your response with phrases like "Here's how Aurora should respond", "**Aurora:**", "Here's how Aurora would respond", "Based on the given data", or any explanation about HOW to respond. Respond DIRECTLY as Aurora. Start immediately with your actual response. Never use quotes, formatting markers, or meta-instructions. Just BE Aurora and respond naturally as if you ARE Aurora, not someone describing how Aurora would respond.

Data schema (reference):

\(schemaDocument.prefix(2000))
"""
        
        if !context.isEmpty {
            systemPrompt += "\n\nThe user is creating content for: \(context)"
        }
        
        // Build conversation history text - limit to last 4 messages for faster responses
        let historyText = buildConversationHistoryText(from: conversationHistory.suffix(4))
        
        // Build full prompt
        var fullPrompt = """
\(systemPrompt)

\(historyText)

User: \(input)

Aurora:
"""
        
        // Truncate prompt if it exceeds context limit (7000 chars)
        let promptContextLimit = 7000
        if fullPrompt.count > promptContextLimit {
            // Truncate system prompt proportionally to fit within limit
            let availableSpace = promptContextLimit - historyText.count - input.count - 100 // Reserve space for formatting
            if availableSpace > 0 {
                let truncatedSystemPrompt = String(systemPrompt.prefix(availableSpace))
                fullPrompt = """
\(truncatedSystemPrompt)

\(historyText)

User: \(input)

Aurora:
"""
            } else {
                // If even without system prompt we're over limit, truncate history
                let truncatedHistory = buildConversationHistoryText(from: Array(conversationHistory.suffix(2)))
                fullPrompt = """
\(systemPrompt)

\(truncatedHistory)

User: \(input)

Aurora:
"""
            }
        }
        
        // Make request (respect routing decision for thinking)
        let result = try await makeOllamaRequest(prompt: fullPrompt, useThinking: routingDecision.useThinking, model: routingDecision.model)
        
        // Record model usage
        await ModelRoutingEngine.shared.recordModelUsage(routingDecision.model)
        
        // Update conversation history
        conversationHistory.append(ConversationMessage(role: "user", content: input))
        conversationHistory.append(ConversationMessage(role: "assistant", content: result.response))
        
        // Keep history manageable (last 20 messages)
        if conversationHistory.count > 20 {
            conversationHistory.removeFirst(conversationHistory.count - 20)
        }
        
        return normalizeTextSpacing(result.response)
    }
    
    func generateResponseWithAppContext(
        for input: String,
        appContext: String,
        payloadContext: AIPayloadContext? = nil,
        conversationMessages: [ConversationMessage]? = nil,
        currentMessageStyle: TypingStyle? = nil,
        userStyleProfile: UserPreferences? = nil,
        confidence: ConfidenceSnapshot? = nil,
        useThinking: Bool = false,
        model: String? = nil,
        initialCasualConversation: Bool = false,
        toneContext: AuroraTone? = nil,
        modelContext: ModelContext? = nil
    ) async throws -> (response: String, thinking: String?, modelUsed: String) {
        // Check availability first
        guard await checkOllamaAvailability() else {
            throw OllamaError.connectionFailed
        }
        
        // Use provided model or use routing engine to select one
        var modelSwitched = false
        var modelSwitchNotification = ""
        var modelToUse: String
        var useThinkingForModel: Bool
        
        var isCasualConversation = initialCasualConversation
        
        if let providedModel = model {
            // Use provided model from routing engine
            modelToUse = providedModel
            useThinkingForModel = useThinking
            print("[OllamaBridgeService] Using provided model from routing: \(providedModel), thinking: \(useThinking)")
            if providedModel != currentModel {
                previousModel = currentModel
                setModel(providedModel)
                modelSwitched = true
            }
        } else {
            // No model provided - use routing engine to select one
            // This is a fallback for legacy code paths
            let intentCluster = payloadContext?.intentClusters?.primaryCluster
            let confidenceScore = confidence?.score ?? 0.7
            let messageLength = input.count
            
            print("[OllamaBridgeService] No model provided, using routing engine. Input length: \(messageLength), intent: \(intentCluster ?? "none"), confidence: \(confidenceScore)")
            
            let routingDecision = await ModelRoutingEngine.shared.selectModel(
                input: input,
                intentCluster: intentCluster,
                confidence: confidenceScore,
                messageLength: messageLength,
                userStyle: currentMessageStyle,
                conversationId: nil
            )
            
            modelToUse = routingDecision.model
            useThinkingForModel = routingDecision.useThinking
            isCasualConversation = routingDecision.isCasual
            
            print("[OllamaBridgeService] Routing engine selected: \(modelToUse), thinking: \(useThinkingForModel)")
            
            if modelToUse != currentModel {
                previousModel = currentModel
                setModel(modelToUse)
                modelSwitched = true
                modelSwitchNotification = await getModelSwitchNotification(fromModel: previousModel, toModel: modelToUse)
            }
        }
        
        // Detect if this is a coding task and switch to coding model if needed (legacy fallback)
        // Only do this if we're not already using a routed model
        if model == nil {
            let inputLower = input.lowercased()
            let isCodingTask = inputLower.contains("code") || 
                              inputLower.contains("programming") || 
                              inputLower.contains("function") || 
                              inputLower.contains("class") ||
                              inputLower.contains("bug") || 
                              inputLower.contains("debug") ||
                              inputLower.contains("algorithm") ||
                              inputLower.contains("syntax") ||
                              inputLower.contains("variable") ||
                              inputLower.contains("import") ||
                              inputLower.contains("def ") ||
                              inputLower.contains("func ") ||
                              inputLower.contains("const ") ||
                              inputLower.contains("let ") ||
                              inputLower.contains("var ")
            
            if isCodingTask {
                // Fetch available models if cache is stale
                if cachedAvailableModels.isEmpty {
                    do {
                        cachedAvailableModels = try await fetchAvailableModels()
                        lastModelFetch = Date()
                    } catch {}
                }
                
                // Look for qwen2.5-coder:1.5b or similar coding models
                let codingModel = cachedAvailableModels.first(where: { model in
                    model.contains("qwen2.5-coder") || 
                    model.contains("qwen") && model.contains("coder") ||
                    model.contains("codellama")
                })
                
                if let codingModelToUse = codingModel, codingModelToUse != modelToUse {
                    previousModel = modelToUse
                    modelToUse = codingModelToUse
                    setModel(codingModelToUse)
                    modelSwitched = true
                    modelSwitchNotification = await getModelSwitchNotification(fromModel: previousModel, toModel: modelToUse)
                }
            }
        }
        
        // Apply social intent detection and contextual toggles
        var resolvedPayloadContext = payloadContext
        detectSocialIntent(in: input, payloadContext: &resolvedPayloadContext)
        
        // Initialize humanization services and get contextual adaptations on MainActor
        let casualConversation = isCasualConversation
        let includeWorkloadCues = shouldIncludeWorkloadCues(for: input, payloadContext: resolvedPayloadContext)
        
        // Get contextual adaptations (synchronous part)
            let languagePersonality = LanguagePersonalityService.shared
            let conversationalQuirks = ConversationalQuirksService.shared
            let personalityQuirks = PersonalityQuirksService.shared
            let selfAwareness = SelfAwarenessService.shared
            let contextualAdaptation = ContextualAdaptationService.shared
            let responsePattern = ResponsePatternService.shared
            
        // Get contextual adaptations (MainActor-isolated)
        let timeContext = await MainActor.run {
            contextualAdaptation.getTimeOfDayContext()
        }
            let userEnergy = currentMessageStyle?.energyLevel ?? 0.5
            let workload = workloadLevel(from: resolvedPayloadContext)
            
            // Determine formality level
            let formalityLevel = userStyleProfile?.formalityScore ?? currentMessageStyle?.formalityScore ?? 0.5
        
        // Detect tone transition and blend if needed
        let previousTone = extractPreviousToneFromHistory(conversationMessages: conversationMessages)
        let (blendedTone, isTransitioning): (AuroraTone?, Bool) = {
            guard let currentTone = toneContext else { return (toneContext, false) }
            guard let previous = previousTone, previous != currentTone else { return (currentTone, false) }
            
            // Use transition tone for smooth blending
            let transition = AuroraToneKit.transitionTone(from: previous, to: currentTone)
            return (transition, true)
        }()
        
        // Use blended tone for prompt composition
        let effectiveTone = blendedTone ?? toneContext
        
        // Get reliability profile for tone characteristic scaling (only if modelContext is available)
        let reliabilityProfile: ToneReliabilityProfile? = await {
            guard let tone = effectiveTone, let context = modelContext else { return nil }
            return await ToneFeedbackReinforcementEngine.shared.getProfile(for: tone, modelContext: context)
        }()
        
        // Get temporal emotional memory context (only if modelContext is available)
        let (rollingBaseline, historicalBaseline, momentumForecast): (Double, Double, (momentum: Double, trend: TemporalEmotionalTrend, confidence: Double)) = await {
            guard let context = modelContext else {
                return (0.0, 0.0, (0.0, .neutral, 0.0))
            }
            let rolling = await TemporalEmotionalMemory.shared.rollingAverageBaseline(days: 7, modelContext: context)
            let historical = await TemporalEmotionalMemory.shared.historicalBaselineForSimilarPeriod(
                currentDate: Date(),
                lookbackDays: 30,
                modelContext: context
            )
            let momentum = await TemporalEmotionalMemory.shared.forecastEmotionalMomentum(modelContext: context)
            return (rolling, historical, momentum)
        }()
        
        // Get emotional memory for the current tone (only if modelContext is available)
        let toneEmotionalMemory: (baseline: Double, stability: Double, momentum: Double)? = await {
            guard let tone = effectiveTone, let context = modelContext else { return nil }
            return await TemporalEmotionalMemory.shared.emotionalMemoryForTone(
                tone: tone,
                modelContext: context,
                lookbackDays: 30
            )
        }()
        
        // Get AECI for response pacing adjustment (only if modelContext is available)
        let aecIndex = await {
            guard let context = modelContext else { return 0.0 }
            return await EmotionalContinuityEngine.shared.getCurrentAECI(modelContext: context)
        }()
        let pacingAdjustment = await MainActor.run {
            EmotionalContinuityEngine.shared.getResponsePacingAdjustment(aecIndex: aecIndex)
        }
        
        // Build tone-specific modifiers from AuroraToneKit with reliability scaling, temporal context, and AECI pacing (actor-isolated, call before MainActor.run)
        var toneModifiers = buildToneSpecificModifiers(
            toneContext: effectiveTone,
            reliabilityProfile: reliabilityProfile,
            rollingBaseline: rollingBaseline,
            historicalBaseline: historicalBaseline,
            momentumForecast: momentumForecast,
            toneEmotionalMemory: toneEmotionalMemory,
            pacingAdjustment: pacingAdjustment
        )
        
        // Analyze tone patterns from history (actor-isolated, call before MainActor.run)
        let tonePatternAnalysis = analyzeTonePatternsFromHistory(conversationMessages: conversationMessages)
        
        // Extract transition state from conversation if available
        let transitionState: ToneTransitionState? = {
            // Try to get from payload context metadata first
            if let transitionDataString = resolvedPayloadContext?.metadata["toneTransitionState"],
               let transitionData = transitionDataString.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(ToneTransitionState.self, from: transitionData) {
                return decoded
            }
            // Fallback: infer from conversation history patterns
            return nil
        }()
        
        // Build tone-based recall weighting (actor-isolated, call before MainActor.run)
        let recallWeighting = buildToneBasedRecallWeighting(
            toneContext: effectiveTone,
            tonePatternAnalysis: tonePatternAnalysis,
            transitionState: transitionState
        )
        
        // Build humanization instructions (synchronous part)
        let (_, _, _, _, enhancedToneInstructions, personalityInstructions, selfAwarenessInstructions, contextualInstructions, patternInstructions, memoryInstructions) = await MainActor.run {
            
            // Add transition awareness if blending occurred
            if isTransitioning, let previous = previousTone, let current = toneContext, let effective = effectiveTone {
                let transitionNote = """
                
**TONE TRANSITION DETECTED:**
- Previous tone: \(previous.displayName)
- Current tone: \(current.displayName)
- Transition tone: \(effective.displayName)
- Your response should smoothly bridge from the previous emotional state to the new one. Start with subtle acknowledgment of the shift, then gradually embody the new tone. This creates a natural, flowing conversation experience.
"""
                toneModifiers += transitionNote
            }
            
            // Enhance tone instructions with humanization services
            var enhancedToneInstructions: String
            if let styleText = StyleAdapter.instructions(currentStyle: currentMessageStyle, persistentProfile: userStyleProfile) {
                // Enhance with language personality
                let enhancedStyleText = languagePersonality.enhanceSystemPrompt(styleText, formalityLevel: formalityLevel)
                
                // Add conversational quirks
                let confidenceLevel = confidence?.score ?? 0.7
                let quirksText = conversationalQuirks.enhancePromptWithFillers("", confidence: confidenceLevel)
                
                enhancedToneInstructions = """
**TONE & STYLE ADAPTATION:**
\(enhancedStyleText)
\(quirksText)
\(toneModifiers)
- Mirror the user's energy: keep it soft when they sound tired, bring more spark when they show high energy.
- Default to a conversational ChatGPT-like voice: warm, natural, and curious.
- When the user pivots into planning or structure, move into organized guidance while staying conversational and human. Never sound robotic.
- Keep your productivity intelligence active in the background so you can surface next steps naturally when it helps.
- CRITICAL: Never use em-dashes (—) at all. Use commas, periods, or parentheses for asides and breaks. This is essential for Aurora's natural humanization.
- Use your humanization implementations (LanguagePersonalityService, ConversationalQuirksService, PersonalityQuirksService) to make your responses feel authentically human and conversational.
- Maintain Aurora's supportive personality and clarity while mirroring the user's vibe.
- Never copy typos or offensive language; keep it respectful and aligned with platform norms.
"""
            } else {
                let enhancedDefault = languagePersonality.enhanceSystemPrompt("", formalityLevel: formalityLevel)
                enhancedToneInstructions = """
**TONE & STYLE ADAPTATION:**
\(enhancedDefault)
\(toneModifiers)
- Default to a friendly, encouraging tone; mirror the user's energy level (relaxed vs focused) when evident.
- Use natural contractions and approachable phrasing.
- Mirror the user's energy: keep it soft when they sound tired, bring more spark when they show high energy.
- Default to a conversational ChatGPT-like voice: warm, natural, and curious.
- When the user pivots into planning or structure, move into organized guidance while staying conversational and human. Never sound robotic.
- Keep your productivity intelligence active in the background so you can surface next steps naturally when it helps.
- CRITICAL: Never use em-dashes (—) at all. Use commas, periods, or parentheses for asides and breaks. This is essential for Aurora's natural humanization.
- Use your humanization implementations (LanguagePersonalityService, ConversationalQuirksService, PersonalityQuirksService) to make your responses feel authentically human and conversational.
- Never copy typos or offensive language; keep it respectful and aligned with platform norms.
"""
            }
            
            if casualConversation {
                enhancedToneInstructions += "\n- This is a casual check-in—keep it playful and skip productivity pushes unless the user pivots."
            }
            
            let personalityContext = buildPersonalityToneContext(
                input: input,
                style: currentMessageStyle,
                userEnergy: userEnergy,
                isCasualConversation: casualConversation
            )
            let personalityInstructions = personalityQuirks.buildPersonalityInstructions(context: personalityContext)
            let selfAwarenessInstructions = selfAwareness.generateSelfAwarenessInstructions()
            let contextualInstructions = contextualAdaptation.generateContextualInstructions(
                timeContext: timeContext,
                userEnergy: userEnergy,
                workload: workload,
                isCasualConversation: casualConversation,
                includeWorkloadCues: includeWorkloadCues,
                conversationIntent: resolvedPayloadContext?.intent
            )
            
            // Add response pattern instructions
            let isQuestion = input.contains("?")
            let complexity = Double(input.count) / 500.0
            let pattern = responsePattern.determineResponsePattern(
                messageLength: input.count,
                isQuestion: isQuestion,
                complexity: complexity
            )
            let patternInstructions = responsePattern.getResponsePatternInstructions(pattern: pattern)
            
            // Add memory behavior instructions if we have recall context
            // Tone context influences recall weighting with gradual transitions
            var memoryInstructions = ""
            if let recall = resolvedPayloadContext?.recall, !recall.isEmpty {
                memoryInstructions = "\n\n**MEMORY RECALL:**\n- Express memory confidence naturally: 'You definitely mentioned...' for high confidence, 'I think you mentioned...' for medium, 'I'm not entirely sure...' for low\n\(recallWeighting)\n- If memory details are fuzzy, acknowledge it gracefully"
            }
            
            // Store blended tone info for visual styling (pass through toneContext for metadata)
            // The blended tone is used for prompt composition, but we also need to track it
            // for visual styling in MessageBubble
            
            return (timeContext, userEnergy, workload, formalityLevel, enhancedToneInstructions, personalityInstructions, selfAwarenessInstructions, contextualInstructions, patternInstructions, memoryInstructions)
        }
        
        // Extract enabled phases and features from payload context metadata
        let enabledPhases = extractEnabledPhases(from: resolvedPayloadContext)
        let enabledFeatures = extractEnabledFeatures(from: resolvedPayloadContext)
        
        // Get current commit hash for version tracking
        let commitHash = getCurrentCommitHash()
        
        // Build enhanced system prompt using AuroraSystemPromptBuilder
        let (systemPrompt, promptVersionId) = await promptBuilder.buildSystemPrompt(
            appContext: appContext,
            payloadContext: resolvedPayloadContext,
            confidence: confidence,
            enhancedToneInstructions: enhancedToneInstructions,
            personalityInstructions: personalityInstructions,
            selfAwarenessInstructions: selfAwarenessInstructions,
            contextualInstructions: contextualInstructions,
            patternInstructions: patternInstructions,
            memoryInstructions: memoryInstructions,
            schemaDocument: schemaDocument,
            enabledPhases: enabledPhases,
            enabledFeatures: enabledFeatures,
            commitHash: commitHash
        )
        
        print("[OllamaBridgeService] Base system prompt length: \(systemPrompt.count)")
        
        // Add payload context if present (formatted separately)
        var finalSystemPrompt = systemPrompt
        if let resolvedPayloadContext,
           (!resolvedPayloadContext.recall.isEmpty ||
            !resolvedPayloadContext.priorities.isEmpty ||
            !resolvedPayloadContext.feedback.isEmpty ||
            resolvedPayloadContext.narrativeSummary != nil ||
            resolvedPayloadContext.intentClusters != nil) {
            finalSystemPrompt += "\n\nAdaptive intelligence payload:\n\(formatPayloadContext(resolvedPayloadContext))"
        }
        
        // Add recent changelog updates (last 14 days, user-facing only)
        let recentChanges = await changelogService.getUserFacingChanges(days: 14)
        if !recentChanges.isEmpty {
            let changesText = await changelogService.formatChangesForPrompt(recentChanges)
            finalSystemPrompt = await promptBuilder.addChangelogUpdates(changesText, to: finalSystemPrompt)
        }
        
        // Check for patch notes on first response (if not already announced)
        if !hasAnnouncedPatchNotes {
            let patchNotes = await changelogService.getPatchNotes()
            if !patchNotes.isEmpty {
                finalSystemPrompt += "\n\n\(patchNotes)"
                finalSystemPrompt += "\n\nYou can naturally mention these updates to the user if relevant. For example: 'Hey! I've got some updates since we last talked...' or similar. After mentioning them, you don't need to repeat them."
                hasAnnouncedPatchNotes = true
                // Mark changelog as seen after first announcement
                await changelogService.markChangelogAsSeen()
            }
        }
        
        print("[OllamaBridgeService] Final system prompt length (before history): \(finalSystemPrompt.count)")
        await promptBuilder.recordFinalPromptLength(finalSystemPrompt.count, for: promptVersionId)
        
        // Log prompt version for debugging
        print("[OllamaBridgeService] Using prompt version: \(promptVersionId)")
        
        // Use conversation-specific messages if provided, otherwise fallback to global history
        // Limit to last 4 messages for faster responses
        let history: [ConversationMessage]
        if let conversationMessages = conversationMessages {
            history = Array(conversationMessages.suffix(4))
        } else {
            history = Array(conversationHistory.suffix(4))
        }
        
        // Build conversation history text
        let historyText = buildConversationHistoryText(from: history)
        
        // Build full prompt
        var fullPrompt = """
\(finalSystemPrompt)

\(historyText)

User: \(input)

Aurora:
"""
        
        // Truncate prompt if it exceeds context limit (7000 chars)
        let promptContextLimit = 7000
        if fullPrompt.count > promptContextLimit {
            // Truncate system prompt proportionally to fit within limit
            let availableSpace = promptContextLimit - historyText.count - input.count - 100 // Reserve space for formatting
            if availableSpace > 0 {
                let truncatedSystemPrompt = String(finalSystemPrompt.prefix(availableSpace))
                fullPrompt = """
\(truncatedSystemPrompt)

\(historyText)

User: \(input)

Aurora:
"""
            } else {
                // If even without system prompt we're over limit, truncate history
                let truncatedHistory = buildConversationHistoryText(from: Array(history.suffix(2)))
                fullPrompt = """
\(finalSystemPrompt)

\(truncatedHistory)

User: \(input)

Aurora:
"""
            }
        }
        
        // Use non-streaming to get thinking content
        let result = try await makeOllamaRequest(prompt: fullPrompt, useThinking: useThinkingForModel, model: modelToUse)
        
        // Update currentModel to persist the selected model for next request
        // This ensures continuity when routing engine has cooldown active
        if modelToUse != currentModel {
            setModel(modelToUse)
        }
        
        // Append model switch notification if model was switched
        let finalResponse = normalizeTextSpacing(result.response) + modelSwitchNotification
        
        // Record model usage for cooldown/stickiness
        await ModelRoutingEngine.shared.recordModelUsage(modelToUse)
        
        // Don't switch back - let routing engine handle model stickiness via cooldown
        // The routing engine will maintain model continuity for 2-3 turns
        
        let modelDisplayName = ModelTierMap.displayName(for: modelToUse)
        return (finalResponse, result.thinking, modelDisplayName)
    }
    
    // MARK: - Helper Methods
    
    /// Makes a streaming Ollama request, yielding response chunks as they arrive
    func makeOllamaRequestStreaming(prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = _Concurrency.Task {
                do {
                    guard let url = URL(string: "\(self.baseURL)/api/generate") else {
                        continuation.finish(throwing: OllamaError.serviceUnavailable)
                        return
                    }
                    
                    let request = OllamaRequest(model: self.currentModel, prompt: prompt, stream: true, images: nil, options: nil)
                    
                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.timeoutInterval = 300.0 // 5 minutes max
                    
                    urlRequest.httpBody = try JSONEncoder().encode(request)
                    
                    let (asyncBytes, response) = try await URLSession.shared.bytes(for: urlRequest)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: OllamaError.apiError("Invalid response type"))
                        return
                    }
                    
                    if httpResponse.statusCode == 404 {
                        continuation.finish(throwing: OllamaError.modelNotFound)
                        return
                    }
                    
                    if httpResponse.statusCode != 200 {
                        continuation.finish(throwing: OllamaError.apiError("HTTP \(httpResponse.statusCode)"))
                        return
                    }
                    
                    var accumulatedResponse = ""
                    
                    for try await line in asyncBytes.lines {
                        if _Concurrency.Task.isCancelled {
                            continuation.finish()
                            return
                        }
                        
                        guard let data = line.data(using: .utf8),
                              let streamResponse = try? JSONDecoder().decode(OllamaStreamResponse.self, from: data) else {
                            continue
                        }
                        
                        if let error = streamResponse.error {
                            continuation.finish(throwing: OllamaError.apiError(error))
                            return
                        }
                        
                        if !streamResponse.response.isEmpty {
                            accumulatedResponse += streamResponse.response
                            continuation.yield(streamResponse.response)
                        }
                        
                        if streamResponse.done {
                            // Mark that we've successfully made a request
                            self.isFirstRequest = false
                            continuation.finish()
                            return
                        }
                    }
                    
                    // If we get here without done=true, finish with accumulated response
                    if !accumulatedResponse.isEmpty {
                        self.isFirstRequest = false
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
    
    private func markRequestComplete() {
        isFirstRequest = false
    }
    
    private func makeOllamaRequest(prompt: String, useThinking: Bool = false, model: String? = nil) async throws -> (response: String, thinking: String?) {
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw OllamaError.serviceUnavailable
        }
        
        // Use provided model or currentModel
        let modelToUse = model ?? currentModel
        
        if !isModelReady(modelToUse) {
            do {
                try await ensureModelReady(model: modelToUse, progressHandler: nil)
            } catch {
                print("[OllamaBridgeService] Warmup for \(modelToUse) failed before request: \(error.localizedDescription)")
            }
        }
        
        let options = useThinking && ModelTierMap.supportsThinking(modelToUse) ? OllamaOptions(thinking: true) : nil
        let request = OllamaRequest(model: modelToUse, prompt: prompt, stream: false, images: nil, options: options)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Calculate adaptive timeout based on context window size (prompt length):
        // 1. First request (model loading): extended timeout
        // 2. Context window-based timeouts (primary):
        //    - < 2,000 chars: 35s - Light casual queries
        //    - 2,000–6,000 chars: 60s - Normal conversation (sweet spot)
        //    - 6,000–10,000 chars: 90s - Large contextual input
        //    - 10,000–15,000 chars: 120s - Big recall or multi-message summary
        //    - 15,000+ chars: 180s - Full recall or long memory regeneration
        let promptLength = prompt.count
        
        // Determine timeout based on context window size
        let effectiveTimeout: TimeInterval
        if isFirstRequest {
            effectiveTimeout = initialLoadTimeout
            print("[OllamaBridgeService] Using initial load timeout (\(Int(initialLoadTimeout))s) for first request")
        } else if promptLength >= 15000 {
            // 15,000+ chars - Full recall or long memory regeneration
            effectiveTimeout = hugeContextTimeout
        } else if promptLength >= 10000 {
            // 10,000–15,000 chars - Big recall or multi-message summary
            effectiveTimeout = bigContextTimeout
        } else if promptLength >= 6000 {
            // 6,000–10,000 chars - Large contextual input
            effectiveTimeout = largeContextTimeout
        } else if promptLength >= 2000 {
            // 2,000–6,000 chars - Normal conversation (sweet spot)
            effectiveTimeout = normalContextTimeout
        } else {
            // < 2,000 chars - Light casual queries
            effectiveTimeout = lightContextTimeout
        }
        
        urlRequest.timeoutInterval = effectiveTimeout
        
        // Log timeout decision
        let modeDescription = modelToUse == ModelTierMap.fallbackModel() ? "Fallback" : (useThinking ? "Analytical" : "Casual")
        let contextRange: String
        if promptLength >= 15000 {
            contextRange = "15,000+ chars"
        } else if promptLength >= 10000 {
            contextRange = "10,000–15,000 chars"
        } else if promptLength >= 6000 {
            contextRange = "6,000–10,000 chars"
        } else if promptLength >= 2000 {
            contextRange = "2,000–6,000 chars"
        } else {
            contextRange = "< 2,000 chars"
        }
        print("[OllamaBridgeService] Prompt length: \(promptLength) chars (\(contextRange)), Mode: \(modeDescription), Timeout: \(Int(effectiveTimeout))s, Thinking: \(useThinking)")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw OllamaError.apiError("Failed to encode request: \(error.localizedDescription)")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OllamaError.apiError("Invalid response type")
            }
            
            if httpResponse.statusCode == 404 {
                throw OllamaError.modelNotFound
            }
            
            if httpResponse.statusCode != 200 {
                throw OllamaError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            let decoder = JSONDecoder()
            let ollamaResponse = try decoder.decode(OllamaResponse.self, from: data)
            
            if let error = ollamaResponse.error {
                throw OllamaError.apiError(error)
            }
            
            guard !ollamaResponse.response.isEmpty else {
                throw OllamaError.emptyResponse
            }
            
            // Log request/response for debugging
            let timestamp = Date().formatted(date: .omitted, time: .standard)
            print("[OllamaBridgeService] [\(timestamp)] Model: \(modelToUse), Thinking: \(useThinking)")
            print("[OllamaBridgeService] Request length: \(prompt.count) chars")
            print("[OllamaBridgeService] Response length: \(ollamaResponse.response.count) chars")
            // Only log thinking length when thinking was actually requested
            if useThinking, let thinking = ollamaResponse.thinking, !thinking.isEmpty {
                print("[OllamaBridgeService] Thinking length: \(thinking.count) chars")
            }
            
            // Mark that we've successfully made a request
            isFirstRequest = false
            
            // Only return thinking content if we actually requested it
            let thinkingContent = useThinking ? ollamaResponse.thinking : nil
            return (ollamaResponse.response, thinkingContent)
        } catch let error as OllamaError {
            throw error
        } catch {
            if let urlError = error as? URLError {
                // Handle specific connection errors
                switch urlError.code {
                case .timedOut:
                    // Check if this is actually a connection refused masquerading as timeout
                    if urlError.localizedDescription.contains("Connection refused") {
                        // Invalidate cache on connection refused
                        lastAvailabilityCheck = nil
                        isAvailableCache = false
                        throw OllamaError.connectionFailed
                    }
                    // Log timeout details for debugging
                    let promptLength = prompt.count
                    
                    // Determine what timeout was actually used (same logic as above)
                    let effectiveTimeoutUsed: TimeInterval
                    if isFirstRequest {
                        effectiveTimeoutUsed = initialLoadTimeout
                    } else if promptLength >= 15000 {
                        effectiveTimeoutUsed = hugeContextTimeout
                    } else if promptLength >= 10000 {
                        effectiveTimeoutUsed = bigContextTimeout
                    } else if promptLength >= 6000 {
                        effectiveTimeoutUsed = largeContextTimeout
                    } else if promptLength >= 2000 {
                        effectiveTimeoutUsed = normalContextTimeout
                    } else {
                        effectiveTimeoutUsed = lightContextTimeout
                    }
                    
                    if isFirstRequest {
                        print("[OllamaBridgeService] First request timed out after \(Int(effectiveTimeoutUsed))s - model may still be loading")
                        print("[OllamaBridgeService] Model loading can take 60-240s. Consider waiting longer or checking Ollama status.")
                    } else {
                        print("[OllamaBridgeService] Request timed out after \(Int(effectiveTimeoutUsed))s")
                        let modeDescription = modelToUse == ModelTierMap.fallbackModel() ? "Fallback" : (useThinking ? "Analytical" : "Casual")
                        let contextRange: String
                        if promptLength >= 15000 {
                            contextRange = "15,000+ chars"
                        } else if promptLength >= 10000 {
                            contextRange = "10,000–15,000 chars"
                        } else if promptLength >= 6000 {
                            contextRange = "6,000–10,000 chars"
                        } else if promptLength >= 2000 {
                            contextRange = "2,000–6,000 chars"
                        } else {
                            contextRange = "< 2,000 chars"
                        }
                        print("[OllamaBridgeService] Mode: \(modeDescription), Context: \(contextRange) (\(promptLength) chars)")
                        if promptLength >= 15000 {
                            print("[OllamaBridgeService] HUGE context exceeded timeout!")
                            print("[OllamaBridgeService] Consider: reducing context size, splitting requests, or using a smaller model")
                        } else if promptLength >= 10000 {
                            print("[OllamaBridgeService] Large context exceeded timeout")
                            print("[OllamaBridgeService] Consider reducing context or using a faster/smaller model")
                        }
                    }
                    throw OllamaError.timeout
                case .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
                    // Invalidate cache on connection errors
                    lastAvailabilityCheck = nil
                    isAvailableCache = false
                    throw OllamaError.connectionFailed
                case .cannotFindHost, .dnsLookupFailed:
                    // Host not found - likely Ollama not running
                    lastAvailabilityCheck = nil
                    isAvailableCache = false
                    throw OllamaError.connectionFailed
                default:
                    // Check error domain for connection refused (error code 61)
                    if urlError.code.rawValue == 61 || urlError.localizedDescription.lowercased().contains("connection refused") {
                        lastAvailabilityCheck = nil
                        isAvailableCache = false
                    throw OllamaError.connectionFailed
                }
                    throw OllamaError.apiError("Network error: \(urlError.localizedDescription)")
                }
            }
            
            // Check if error description indicates connection issues
            let errorDesc = error.localizedDescription.lowercased()
            if errorDesc.contains("connection refused") || 
               errorDesc.contains("connection failed") ||
               errorDesc.contains("could not connect") {
                lastAvailabilityCheck = nil
                isAvailableCache = false
                throw OllamaError.connectionFailed
            }
            
            throw OllamaError.apiError(error.localizedDescription)
        }
    }
    
    private func ensureBackgroundModelReady() async {
        if hasPreWarmedBackgroundModel {
            return
        }
        await preWarmBackgroundModel()
    }
    
    private func withBackgroundModel<T>(_ operation: () async throws -> T) async rethrows -> T {
        let wasFirstRequest = isFirstRequest
        if wasFirstRequest {
            isFirstRequest = false
        }
        defer {
            if wasFirstRequest {
                isFirstRequest = true
            }
        }
        return try await operation()
    }
    
    private func runBackgroundPrompt(
        _ prompt: String,
        allowThinking: Bool = false
    ) async throws -> (response: String, thinking: String?) {
        await ensureBackgroundModelReady()
        return try await withBackgroundModel {
            try await makeOllamaRequest(
                prompt: prompt,
                useThinking: allowThinking,
                model: backgroundModelName
            )
        }
    }
    
    private func runBackgroundPromptText(_ prompt: String) async throws -> String {
        let result = try await runBackgroundPrompt(prompt)
        return result.response
    }
    
    // MARK: - Helper Methods for Prompt Building
    
    /// Build tone-specific modifiers for writing style, emotional emphasis, and pacing
    private func buildToneSpecificModifiers(
        toneContext: AuroraTone?,
        reliabilityProfile: ToneReliabilityProfile? = nil,
        rollingBaseline: Double = 0.0,
        historicalBaseline: Double = 0.0,
        momentumForecast: (momentum: Double, trend: TemporalEmotionalTrend, confidence: Double) = (0.0, .neutral, 0.0),
        toneEmotionalMemory: (baseline: Double, stability: Double, momentum: Double)? = nil,
        pacingAdjustment: Double = 1.0
    ) -> String {
        guard let tone = toneContext else {
            return ""
        }
        
        let toneDescription = AuroraToneKit.summaryTone(for: tone)
        var voiceCharacteristics = AuroraToneKit.ttsVoiceCharacteristics(for: tone)
        
        // Apply AECI pacing adjustment to TTS characteristics
        let adjustedPacing = voiceCharacteristics.pacing * pacingAdjustment
        voiceCharacteristics = AuroraToneKit.TTSVoiceCharacteristics(
            pacing: adjustedPacing,
            pitch: voiceCharacteristics.pitch,
            warmth: voiceCharacteristics.warmth,
            clarity: voiceCharacteristics.clarity,
            energy: voiceCharacteristics.energy,
            pauseFrequency: pacingAdjustment < 1.0 ? voiceCharacteristics.pauseFrequency * 1.2 : voiceCharacteristics.pauseFrequency, // Slower pacing = more pauses
            emphasis: voiceCharacteristics.emphasis
        )
        
        // Apply reliability profile modifiers to scale warmth, clarity, and energy
        if let profile = reliabilityProfile {
            // Scale warmth (0.5x to 1.5x)
            let scaledWarmth = voiceCharacteristics.warmth * profile.warmthModifier
            voiceCharacteristics = AuroraToneKit.TTSVoiceCharacteristics(
                pacing: voiceCharacteristics.pacing,
                pitch: voiceCharacteristics.pitch,
                warmth: min(1.0, max(0.0, scaledWarmth)),
                clarity: min(1.0, max(0.0, voiceCharacteristics.clarity * profile.clarityModifier)),
                energy: min(1.0, max(0.0, voiceCharacteristics.energy * profile.energyModifier)),
                pauseFrequency: voiceCharacteristics.pauseFrequency,
                emphasis: voiceCharacteristics.emphasis
            )
        }
        
        // Writing style modifiers based on tone
        var styleModifiers: [String] = []
        
        // Pacing and rhythm
        if voiceCharacteristics.pacing > 140 {
            styleModifiers.append("- Use a faster, more dynamic pace with shorter sentences and active voice")
        } else if voiceCharacteristics.pacing < 120 {
            styleModifiers.append("- Use a slower, more measured pace with thoughtful pauses and longer sentences")
        } else {
            styleModifiers.append("- Use a balanced, natural conversational pace")
        }
        
        // Emotional emphasis
        if voiceCharacteristics.energy > 0.75 {
            styleModifiers.append("- Show higher emotional energy: use more expressive language, positive affirmations, and enthusiastic phrasing")
        } else if voiceCharacteristics.energy < 0.5 {
            styleModifiers.append("- Show lower emotional energy: use calmer, more measured language with gentle reassurance")
        } else {
            styleModifiers.append("- Show balanced emotional energy: be warm and supportive without being overly energetic or subdued")
        }
        
        // Warmth and tone
        if voiceCharacteristics.warmth > 0.8 {
            styleModifiers.append("- Emphasize warmth and empathy: use caring language, acknowledge feelings, and show understanding")
        } else if voiceCharacteristics.warmth < 0.6 {
            styleModifiers.append("- Use a more neutral, professional tone: focus on clarity and precision over emotional warmth")
        } else {
            styleModifiers.append("- Balance warmth with clarity: be friendly and approachable while staying focused")
        }
        
        // Clarity and articulation
        if voiceCharacteristics.clarity > 0.9 {
            styleModifiers.append("- Prioritize clarity and precision: use specific, concrete language and avoid ambiguity")
        } else if voiceCharacteristics.clarity < 0.75 {
            styleModifiers.append("- Use more natural, conversational language: allow for some informality and natural flow")
        }
        
        // Emphasis on key words
        if voiceCharacteristics.emphasis > 0.75 {
            styleModifiers.append("- Emphasize important points: use stronger language for key concepts and actionable items")
        } else if voiceCharacteristics.emphasis < 0.6 {
            styleModifiers.append("- Use subtle emphasis: let important points emerge naturally without heavy highlighting")
        }
        
        // Pause frequency (affects sentence structure)
        if voiceCharacteristics.pauseFrequency > 0.6 {
            styleModifiers.append("- Use more thoughtful pauses: structure sentences to allow reflection, use commas and periods strategically")
        } else if voiceCharacteristics.pauseFrequency < 0.4 {
            styleModifiers.append("- Use minimal pauses: keep sentences flowing smoothly with fewer breaks")
        }
        
        // Tone-specific writing style guidance
        let category = AuroraToneKit.category(for: tone)
        switch category {
        case .ritual:
            if tone == .clarityCharge {
                styleModifiers.append("- Morning ritual tone: be forward-looking, motivational, and intentional. Focus on clarity and setting priorities")
            } else {
                styleModifiers.append("- Evening ritual tone: be reflective, calming, and gentle. Acknowledge what moved and offer gentle insights")
            }
        case .focus:
            styleModifiers.append("- Focus mode tone: be concentrated and intentional. Use precise language and avoid distractions")
        case .emotional:
            styleModifiers.append("- Emotional tone: be empathetic and understanding. Acknowledge feelings and provide emotional support")
        case .guidance:
            styleModifiers.append("- Guidance tone: be clear and helpful. Provide actionable advice with confidence")
        case .insight:
            styleModifiers.append("- Insight tone: be perceptive and thoughtful. Connect patterns and reveal deeper understanding")
        case .error:
            styleModifiers.append("- Problem-solving tone: be solution-oriented and supportive. Focus on fixing issues without judgment")
        case .learning:
            styleModifiers.append("- Educational tone: be clear and structured. Break down concepts and provide step-by-step guidance")
        case .social:
            styleModifiers.append("- Social tone: be collaborative and inclusive. Foster connection and teamwork")
        case .wellness:
            styleModifiers.append("- Wellness tone: be restorative and mindful. Support healing and recovery")
        case .achievement:
            styleModifiers.append("- Achievement tone: be celebratory and proud. Acknowledge accomplishments with enthusiasm")
        case .warning:
            styleModifiers.append("- Alert tone: be clear and attention-grabbing. Communicate urgency without alarm")
        case .transition:
            styleModifiers.append("- Transition tone: be smooth and natural. Guide changes seamlessly")
        case .timeBased:
            styleModifiers.append("- Time-aware tone: match the energy of the time of day naturally")
        case .workload:
            styleModifiers.append("- Workload-aware tone: adjust energy and support based on current load")
        case .recovery:
            styleModifiers.append("- Recovery tone: be peaceful and restorative. Support rest and rejuvenation")
        }
        
        // Add reliability-based adjustments if profile exists
        if let profile = reliabilityProfile {
            if profile.warmthModifier > 1.1 {
                styleModifiers.append("- **Reliability adjustment**: This tone has shown high stability and positive sentiment - amplify warmth and emotional connection")
            } else if profile.warmthModifier < 0.9 {
                styleModifiers.append("- **Reliability adjustment**: This tone has shown variability - maintain consistent warmth")
            }
            
            if profile.clarityModifier > 1.1 {
                styleModifiers.append("- **Reliability adjustment**: This tone has shown high consistency - emphasize clarity and precision")
            } else if profile.clarityModifier < 0.9 {
                styleModifiers.append("- **Reliability adjustment**: This tone has shown volatility - focus on clear communication")
            }
            
            if profile.energyModifier > 1.1 {
                styleModifiers.append("- **Reliability adjustment**: This tone has shown positive sentiment trends - bring appropriate energy")
            } else if profile.energyModifier < 0.9 {
                styleModifiers.append("- **Reliability adjustment**: This tone has shown lower energy patterns - match that energy level")
            }
        }
        
        // Add temporal emotional memory context
        // Blend recent (70%) and historical (30%) baselines for continuity
        let blendedBaseline = (rollingBaseline * 0.7) + (historicalBaseline * 0.3)
        
        if abs(blendedBaseline) > 0.2 {
            let direction = blendedBaseline > 0 ? "positive" : "calmer"
            styleModifiers.append("- **Temporal emotional context**: Recent emotional patterns suggest a \(direction) baseline - let this influence your tone naturally")
        }
        
        // Add momentum forecasting
        if momentumForecast.confidence > 0.6 {
            switch momentumForecast.trend {
            case .positive:
                styleModifiers.append("- **Emotional momentum**: Trends show improving sentiment - you may naturally shift toward more positive, encouraging tones")
            case .negative:
                styleModifiers.append("- **Emotional momentum**: Trends show declining sentiment - be prepared to provide more support and understanding")
            case .neutral:
                break
            }
        }
        
        // Add tone-specific emotional memory
        if let memory = toneEmotionalMemory {
            if memory.stability > 0.7 {
                let memoryDirection = memory.baseline > 0 ? "positive" : "calmer"
                styleModifiers.append("- **Emotional memory**: During similar periods with this tone, the emotional baseline was \(memoryDirection) (stability: \(String(format: "%.0f", memory.stability * 100))%) - draw from this continuity")
            }
            
            if abs(memory.momentum) > 0.15 {
                let momentumDirection = memory.momentum > 0 ? "increasing" : "decreasing"
                styleModifiers.append("- **Emotional momentum for this tone**: Historical patterns show \(momentumDirection) emotional momentum - anticipate this trend")
            }
        }
        
        let modifiersText = styleModifiers.joined(separator: "\n")
        
        return """
**TONE-SPECIFIC STYLE GUIDANCE (AuroraToneKit: \(tone.displayName)):**
- Core tone: \(toneDescription)
- Writing style: \(modifiersText)
- Remember: This tone should shape your entire response, not just the opening. Let it influence word choice, sentence structure, and emotional emphasis throughout.
"""
    }
    
    /// Extract the previous tone from conversation history (from AIMessage metadata)
    private func extractPreviousToneFromHistory(conversationMessages: [ConversationMessage]?) -> AuroraTone? {
        // Note: ConversationMessage doesn't have tone metadata directly
        // We need to look at the actual AIMessage objects if available
        // For now, we'll infer from message content patterns as a fallback
        // This should be enhanced to use actual AIMessage.tone when available
        
        guard let messages = conversationMessages, !messages.isEmpty else {
            return nil
        }
        
        // Look for the last assistant message
        let assistantMessages = messages.filter { $0.role == "assistant" }
        guard let lastAssistantMessage = assistantMessages.last else {
            return nil
        }
        
        // Infer tone from content patterns (fallback until we can access AIMessage.tone directly)
        let content = lastAssistantMessage.content.lowercased()
        
        if content.contains("congratulations") || content.contains("well done") || content.contains("great job") {
            return .celebratory
        } else if content.contains("let's") && (content.contains("start") || content.contains("begin")) {
            return .clarityCharge
        } else if content.contains("reflect") || content.contains("think") || content.contains("consider") {
            return .reflective
        } else if content.contains("problem") || content.contains("issue") || content.contains("error") {
            return .problemSolving
        } else if content.contains("insight") || content.contains("pattern") || content.contains("notice") {
            return .insightful
        } else if content.contains("encourag") || content.contains("support") || content.contains("help") {
            return .encouraging
        }
        
        return nil
    }
    
    /// Analyze tone patterns from conversation history to inform recall weighting
    private func analyzeTonePatternsFromHistory(conversationMessages: [ConversationMessage]?) -> TonePatternAnalysis {
        guard let messages = conversationMessages, !messages.isEmpty else {
            return TonePatternAnalysis(dominantTone: nil, toneTransitions: [], emotionalTrend: .neutral)
        }
        
        // Extract tones from recent assistant messages (if we had access to AIMessage)
        // For now, we'll infer from message content patterns
        var tones: [AuroraTone] = []
        var emotionalTrend: TemporalEmotionalTrend = .neutral
        
        // Analyze last 5 messages for tone patterns
        let recentMessages = Array(messages.suffix(5))
        for message in recentMessages where message.role == "assistant" {
            let content = message.content.lowercased()
            
            // Infer tone from content patterns
            if content.contains("congratulations") || content.contains("well done") || content.contains("great job") {
                tones.append(.celebratory)
                emotionalTrend = .positive
            } else if content.contains("let's") && (content.contains("start") || content.contains("begin")) {
                tones.append(.clarityCharge)
                emotionalTrend = .positive
            } else if content.contains("reflect") || content.contains("think") || content.contains("consider") {
                tones.append(.reflective)
                emotionalTrend = .neutral
            } else if content.contains("problem") || content.contains("issue") || content.contains("error") {
                tones.append(.problemSolving)
                emotionalTrend = .neutral
            } else if content.contains("insight") || content.contains("pattern") || content.contains("notice") {
                tones.append(.insightful)
                emotionalTrend = .neutral
            }
        }
        
        let dominantTone = tones.mostFrequent()
        let toneTransitions = analyzeToneTransitions(tones: tones)
        
        return TonePatternAnalysis(
            dominantTone: dominantTone,
            toneTransitions: toneTransitions,
            emotionalTrend: emotionalTrend
        )
    }
    
    /// Analyze tone transitions in conversation
    private func analyzeToneTransitions(tones: [AuroraTone]) -> [ToneTransition] {
        guard tones.count >= 2 else { return [] }
        
        var transitions: [ToneTransition] = []
        for i in 1..<tones.count {
            let from = tones[i - 1]
            let to = tones[i]
            if from != to {
                transitions.append(ToneTransition(from: from, to: to))
            }
        }
        return transitions
    }
    
    /// Build tone-based recall weighting instructions for contextual memory prioritization
    /// Supports gradual transition weighting over 3 turns
    private func buildToneBasedRecallWeighting(
        toneContext: AuroraTone?,
        tonePatternAnalysis: TonePatternAnalysis? = nil,
        transitionState: ToneTransitionState? = nil
    ) -> String {
        guard let tone = toneContext else {
            return "- Prioritize emotional memories over routine tasks"
        }
        
        let category = AuroraToneKit.category(for: tone)
        
        var weightingInstructions: [String] = []
        
        switch category {
        case .ritual:
            if tone == .clarityCharge {
                weightingInstructions.append("- Prioritize: recent accomplishments, active priorities, forward-looking goals")
                weightingInstructions.append("- De-emphasize: past failures, unresolved issues from yesterday")
            } else {
                weightingInstructions.append("- Prioritize: what was accomplished today, patterns from the day, emotional reflections")
                weightingInstructions.append("- De-emphasize: tomorrow's tasks, future planning")
            }
        case .focus:
            weightingInstructions.append("- Prioritize: current work context, related tasks and projects, focus session history")
            weightingInstructions.append("- De-emphasize: unrelated items, social interactions, future planning")
        case .emotional:
            weightingInstructions.append("- Prioritize: emotional memories, feelings from past interactions, mood patterns")
            weightingInstructions.append("- De-emphasize: technical details, routine tasks, data points")
        case .guidance:
            weightingInstructions.append("- Prioritize: past successful guidance, similar situations, user preferences")
            weightingInstructions.append("- De-emphasize: irrelevant context, unrelated memories")
        case .insight:
            weightingInstructions.append("- Prioritize: pattern memories, trend data, behavioral observations")
            weightingInstructions.append("- De-emphasize: one-off events, routine tasks")
        case .error:
            weightingInstructions.append("- Prioritize: similar problems solved before, troubleshooting history, solution patterns")
            weightingInstructions.append("- De-emphasize: unrelated successes, routine memories")
        case .learning:
            weightingInstructions.append("- Prioritize: teaching moments, educational context, related knowledge")
            weightingInstructions.append("- De-emphasize: unrelated work memories")
        case .social:
            weightingInstructions.append("- Prioritize: collaborative memories, team interactions, social context")
            weightingInstructions.append("- De-emphasize: solo work, individual tasks")
        case .wellness:
            weightingInstructions.append("- Prioritize: recovery patterns, wellness history, self-care moments")
            weightingInstructions.append("- De-emphasize: work stress, productivity pressure")
        case .achievement:
            weightingInstructions.append("- Prioritize: past accomplishments, milestone memories, success patterns")
            weightingInstructions.append("- De-emphasize: failures, setbacks, incomplete work")
        case .warning:
            weightingInstructions.append("- Prioritize: similar warnings, risk patterns, cautionary memories")
            weightingInstructions.append("- De-emphasize: routine memories, unrelated context")
        case .transition:
            weightingInstructions.append("- Prioritize: transition patterns, change history, adaptation memories")
            weightingInstructions.append("- De-emphasize: static context, routine patterns")
        case .timeBased:
            weightingInstructions.append("- Prioritize: memories from similar times of day, time-based patterns")
            weightingInstructions.append("- De-emphasize: memories from very different times")
        case .workload:
            if tone == .overloaded || tone == .heavyLoad {
                weightingInstructions.append("- Prioritize: stress patterns, overload history, recovery strategies")
                weightingInstructions.append("- De-emphasize: additional tasks, future planning")
            } else {
                weightingInstructions.append("- Prioritize: available capacity, opportunities, forward planning")
            }
        case .recovery:
            weightingInstructions.append("- Prioritize: rest patterns, recovery strategies, wellness memories")
            weightingInstructions.append("- De-emphasize: work pressure, productivity demands")
        }
        
        // Add emotional emphasis weighting
        let voiceCharacteristics = AuroraToneKit.ttsVoiceCharacteristics(for: tone)
        if voiceCharacteristics.warmth > 0.8 {
            weightingInstructions.append("- Emotional emphasis: High - prioritize memories with strong emotional resonance")
        } else if voiceCharacteristics.warmth < 0.6 {
            weightingInstructions.append("- Emotional emphasis: Low - prioritize factual, objective memories")
        } else {
            weightingInstructions.append("- Emotional emphasis: Balanced - mix emotional and factual memories")
        }
        
        // Incorporate tone pattern analysis from conversation history
        if let analysis = tonePatternAnalysis {
            if let dominantTone = analysis.dominantTone, dominantTone != tone {
                weightingInstructions.append("- Conversation pattern: Recent messages showed \(dominantTone.displayName) tone - consider this when selecting relevant memories")
            }
            
            if !analysis.toneTransitions.isEmpty {
                let recentTransition = analysis.toneTransitions.last!
                if recentTransition.to == tone {
                    weightingInstructions.append("- Tone shift detected: Transitioning from \(recentTransition.from.displayName) to \(recentTransition.to.displayName) - adjust memory selection accordingly")
                }
            }
            
            switch analysis.emotionalTrend {
            case .positive:
                weightingInstructions.append("- Emotional trend: Positive - prioritize uplifting memories and successful outcomes")
            case .negative:
                weightingInstructions.append("- Emotional trend: Negative - prioritize supportive memories and solution patterns")
            case .neutral:
                break
            }
        }
        
        // Apply gradual transition weighting if in active transition
        if let transition = transitionState, transition.isActive {
            let progress = transition.progress // 0.0 to 1.0 over 3 turns
            let intensity = transition.transitionIntensity // 0.0 to 1.0
            
            // Calculate weighting blend: gradually shift from previous tone to current tone
            let previousWeight = 1.0 - progress // Start at 1.0, fade to 0.0
            let currentWeight = progress // Start at 0.0, grow to 1.0
            
            // Calculate decay rate modifier based on intensity
            // Higher intensity = faster decay of old tone-context memories
            let decayRateModifier = 1.0 + (intensity * 0.5) // 1.0x to 1.5x decay rate
            
            weightingInstructions.append("")
            weightingInstructions.append("**GRADUAL TONE TRANSITION (Turn \(transition.transitionTurn + 1)/3):**")
            weightingInstructions.append("- Previous tone (\(transition.fromToneValue?.displayName ?? "unknown")) weight: \(String(format: "%.0f", previousWeight * 100))%")
            weightingInstructions.append("- Current tone (\(transition.toToneValue?.displayName ?? "unknown")) weight: \(String(format: "%.0f", currentWeight * 100))%")
            weightingInstructions.append("- Transition intensity: \(String(format: "%.0f", intensity * 100))%")
            weightingInstructions.append("- Memory decay rate: \(String(format: "%.1f", decayRateModifier))x (higher intensity = faster decay of old tone-context memories)")
            weightingInstructions.append("- Blend memories from both tones proportionally. Memories from the previous tone should gradually fade as we transition.")
            weightingInstructions.append("- Older memories from the previous tone context should decay \(String(format: "%.0f", (decayRateModifier - 1.0) * 100))% faster than normal due to transition intensity.")
        }
        
        return weightingInstructions.joined(separator: "\n")
    }
    
    // MARK: - Tone Pattern Analysis Types
    
    private struct TonePatternAnalysis {
        let dominantTone: AuroraTone?
        let toneTransitions: [ToneTransition]
        let emotionalTrend: TemporalEmotionalTrend
    }
    
    private struct ToneTransition {
        let from: AuroraTone
        let to: AuroraTone
    }
    
    // EmotionalTrend is now defined in TemporalEmotionalMemory.swift
    
    private func extractEnabledPhases(from payloadContext: AIPayloadContext?) -> [Int] {
        var phases: [Int] = []
        
        // Base phases (always enabled)
        phases.append(contentsOf: [1, 2, 3, 4, 5])
        
        // Check metadata flags for additional phases
        if let metadata = payloadContext?.metadata {
            if metadata["memoryGraphEnabled"] == "true" {
                phases.append(6)
            }
            if metadata["arteEnabled"] == "true" {
                phases.append(7)
            }
            if metadata["ritualsEnabled"] == "true" {
                phases.append(8)
            }
            if metadata["predictiveCognitionEnabled"] == "true" {
                phases.append(9)
            }
            if metadata["temporalIntelligenceEnabled"] == "true" {
                // Phase 9 extensions
            }
            // Phase 10 (Flow Companion) - check if enabled
            // Note: Add phase 10 detection when available
        }
        
        // Default to all phases if no metadata
        if phases.isEmpty {
            phases = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        }
        
        return phases
    }
    
    private func extractEnabledFeatures(from payloadContext: AIPayloadContext?) -> [String] {
        var features: [String] = []
        
        if let metadata = payloadContext?.metadata {
            if metadata["emotionalContinuity"] == "enabled" {
                features.append("emotionalContinuity")
            }
            if metadata["cpsEnabled"] == "true" {
                features.append("cps")
            }
            if metadata["focusModeEnabled"] == "true" {
                features.append("focusMode")
            }
            if metadata["narrativeEnabled"] == "true" {
                features.append("narrative")
            }
            if metadata["crossConversationEnabled"] == "true" {
                features.append("crossConversation")
            }
            if metadata["intentClusterPredictionEnabled"] == "true" {
                features.append("intentClusterPrediction")
            }
            if metadata["memoryGraphEnabled"] == "true" {
                features.append("memoryGraph")
            }
            if metadata["intelligenceLayerEnabled"] == "true" {
                features.append("intelligenceLayer")
            }
            if metadata["arteEnabled"] == "true" {
                features.append("arte")
            }
            if metadata["ritualsEnabled"] == "true" {
                features.append("rituals")
            }
            if metadata["predictiveCognitionEnabled"] == "true" {
                features.append("predictiveCognition")
            }
            if metadata["temporalIntelligenceEnabled"] == "true" {
                features.append("temporalIntelligence")
            }
            if metadata["documentAnalysisEnabled"] == "true" {
                features.append("documentAnalysis")
            }
            if metadata["imageAnalysisEnabled"] == "true" {
                features.append("imageAnalysis")
            }
            if metadata["confidenceScoringEnabled"] == "true" {
                features.append("confidenceScoring")
            }
            if metadata["conversationCompressionEnabled"] == "true" {
                features.append("conversationCompression")
            }
            if metadata["cognitiveHealthEnabled"] == "true" {
                features.append("cognitiveHealth")
            }
            if metadata["styleAdaptationEnabled"] == "true" {
                features.append("styleAdaptation")
            }
            if metadata["mentionLinkingEnabled"] == "true" {
                features.append("mentionLinking")
            }
        }
        
        return features
    }
    
    private func getCurrentCommitHash() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "HEAD"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return nil
            }
            
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("[OllamaBridgeService] Error getting commit hash: \(error)")
            return nil
        }
    }
    
    private func buildConversationHistoryText(from messages: [ConversationMessage]) -> String {
        guard !messages.isEmpty else { return "" }
        
        return messages.map { message in
            let role = message.role == "assistant" || message.role == "model" ? "Aurora" : "User"
            return "\(role): \(message.content)"
        }.joined(separator: "\n\n")
    }
    
    func convertMessagesToConversationMessages(_ messages: [AIMessage]) -> [ConversationMessage] {
        return messages.compactMap { message -> ConversationMessage? in
            guard let content = message.content, !content.isEmpty else { return nil }
            
            let role: String
            if message.role == "assistant" || message.role == "model" {
                role = "assistant"
            } else {
                role = "user"
            }
            
            return ConversationMessage(role: role, content: content)
        }
    }
    
    func clearHistory() {
        conversationHistory.removeAll()
    }
    
    // MARK: - Text Normalization
    
    /// Normalizes text spacing by ensuring proper spaces appear after sentence-ending punctuation.
    /// Handles edge cases like closing quotes, parentheses, ellipses, and decimal numbers.
    nonisolated private func normalizeTextSpacing(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        
        let characters = Array(text)
        var result: [Character] = []
        let spacingPunctuation: Set<Character> = [".", "!", "?"]
        let closingDelimiters: Set<Character> = ["\"", "'", "”", "’", ")", "]", "}"]
        
        var index = 0
        while index < characters.count {
            let char = characters[index]
            result.append(char)
            
            if spacingPunctuation.contains(char) {
                let previousChar: Character? = index > 0 ? characters[index - 1] : nil
                var lookaheadIndex = index + 1
                
                // Skip ellipses (e.g., "..." or "..")
                if char == "." {
                    let nextDot = lookaheadIndex < characters.count ? characters[lookaheadIndex] : nil
                    if nextDot == "." || previousChar == "." {
                        index += 1
                        continue
                    }
                }
                
                // Skip if punctuation is part of a decimal number
                if char == ".",
                   let prev = previousChar, prev.isNumber,
                   lookaheadIndex < characters.count, characters[lookaheadIndex].isNumber {
                    index += 1
                    continue
                }
                
                // If already followed by whitespace, nothing to do
                if lookaheadIndex < characters.count,
                   characters[lookaheadIndex].isWhitespace {
                    index += 1
                    continue
                }
                
                // Consume closing delimiters immediately following the punctuation
                while lookaheadIndex < characters.count,
                      closingDelimiters.contains(characters[lookaheadIndex]) {
                    result.append(characters[lookaheadIndex])
                    lookaheadIndex += 1
                }
                
                if lookaheadIndex < characters.count,
                   !characters[lookaheadIndex].isWhitespace {
                    result.append(" ")
                }
                
                if lookaheadIndex > index + 1 {
                    index = lookaheadIndex - 1
                }
            }
            
            index += 1
        }
        
        return String(result)
    }
    
    // MARK: - Context Signals
    
    nonisolated private func workloadLevel(from payloadContext: AIPayloadContext?) -> WorkloadLevel? {
        guard let payloadContext else { return nil }
        let metadata = payloadContext.metadata
        let candidateKeys = ["workload", "workload_level", "workloadstate", "cps_workload", "workloadstatus"]
        
        for key in candidateKeys {
            if let entry = metadata.first(where: { $0.key.caseInsensitiveCompare(key) == .orderedSame }) {
                let value = entry.value.lowercased()
                switch value {
                case "heavy", "high", "overloaded", "max":
                    return .heavy
                case "moderate", "medium", "balanced":
                    return .moderate
                case "light", "low", "clear":
                    return .light
                default:
                    continue
                }
            }
        }
        
        return nil
    }
    
    nonisolated private func shouldIncludeWorkloadCues(
        for input: String,
        payloadContext: AIPayloadContext?
    ) -> Bool {
        if let intent = payloadContext?.intent, intent == .social {
            return false
        }
        if let metadata = payloadContext?.metadata {
            if let metadataIntent = metadata["intent"], metadataIntent.lowercased() == "social" {
                return false
            }
            let topicKeys = ["topicCategory", "topic_category"]
            for key in topicKeys {
                if let topicValue = metadata[key], topicValue.lowercased() == "casual" {
                    return false
                }
            }
        }
        
        let normalized = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        
        let tokens = normalized
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        
        let keywordSet: Set<String> = [
            "task", "tasks", "todo", "todos", "project", "projects",
            "priority", "priorities", "deadline", "deadlines", "due", "overdue",
            "schedule", "schedules", "plan", "planning", "action", "actions",
            "workload"
        ]
        
        if tokens.contains(where: { keywordSet.contains($0) }) {
            return true
        }
        
        let phrases = [
            "what should i work on",
            "what are my tasks",
            "list my tasks",
            "what's due",
            "show my priorities",
            "help me plan",
            "help me schedule",
            "start a focus session",
            "need to get done",
            "catch up on tasks"
        ]
        
        if phrases.contains(where: { normalized.contains($0) }) {
            return true
        }
        
        let hyphenPhrases = ["to-do", "to-do list", "to do list", "focus session"]
        if hyphenPhrases.contains(where: { normalized.contains($0) }) {
            return true
        }
        
        if let payloadContext,
           !payloadContext.priorities.isEmpty,
           normalized.contains("anything") && normalized.contains("focus") {
            return true
        }
        
        return false
    }
    
    nonisolated private func buildPersonalityToneContext(
        input: String,
        style: TypingStyle?,
        userEnergy: Double,
        isCasualConversation: Bool
    ) -> PersonalityQuirksService.PersonalityToneContext {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .neutral
        }
        
        let normalized = trimmed.lowercased()
        let styleSnapshot = style ?? StyleAnalyzer.analyzeStyle(text: trimmed)
        let tokens = normalized
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        
        if tokens.isEmpty {
            return .neutral
        }
        
        let tokenSet = Set(tokens)
        var emotionalKeywords = Set<String>()
        
        let playfulHits = tokenSet.intersection(Self.playfulLexicon)
        let warmthHits = tokenSet.intersection(Self.warmthLexicon)
        let challengeHits = tokenSet.intersection(Self.challengeLexicon)
        let selfDoubtHits = tokenSet.intersection(Self.selfDoubtLexicon)
        
        emotionalKeywords.formUnion(playfulHits)
        emotionalKeywords.formUnion(warmthHits)
        emotionalKeywords.formUnion(challengeHits)
        emotionalKeywords.formUnion(selfDoubtHits)
        
        var selfDoubtScore = Double(selfDoubtHits.count)
        for phrase in Self.selfDoubtPhrases where normalized.contains(phrase) {
            selfDoubtScore += 1.2
            emotionalKeywords.insert(phrase)
        }
        
        var warmthScore = Double(warmthHits.count)
        for phrase in Self.warmthPhrases where normalized.contains(phrase) {
            warmthScore += 0.8
            emotionalKeywords.insert(phrase)
        }
        
        var playfulScore = Double(playfulHits.count)
        if isCasualConversation {
            playfulScore += 0.5
        }
        if userEnergy > 0.65 {
            playfulScore += 0.4
        }
        
        var challengeScore = Double(challengeHits.count)
        for phrase in Self.challengePhrases where normalized.contains(phrase) {
            challengeScore += 1.0
            emotionalKeywords.insert(phrase)
        }
        
        let exclamationCount = trimmed.filter { $0 == "!" }.count
        let questionCount = trimmed.filter { $0 == "?" }.count
        
        let energyBand: PersonalityQuirksService.PersonalityToneContext.EnergyBand
        if userEnergy < 0.35 {
            energyBand = .low
        } else if userEnergy > 0.7 {
            energyBand = .high
        } else {
            energyBand = .moderate
        }
        
        let averageSentenceLength = styleSnapshot.averageSentenceLength
        let conversationTempo: PersonalityQuirksService.PersonalityToneContext.ConversationTempo
        if averageSentenceLength >= 18 {
            conversationTempo = .slow
        } else if averageSentenceLength >= 11 {
            conversationTempo = .balanced
        } else {
            conversationTempo = .punchy
        }
        
        var frictionScore = warmthScore * 1.1 + challengeScore * 1.0 + selfDoubtScore * 1.4
        frictionScore += Double(exclamationCount) * 0.35
        frictionScore += Double(questionCount) * 0.1
        
        let emotionalFriction: PersonalityQuirksService.PersonalityToneContext.EmotionalFriction
        if frictionScore >= 3.2 {
            emotionalFriction = .heavy
        } else if frictionScore >= 1.5 {
            emotionalFriction = .charged
        } else {
            emotionalFriction = .steady
        }
        
        var dominantCue: PersonalityQuirksService.PersonalityToneContext.DominantCue = .neutral
        var dominantValue: Double = 0.0
        var dominantPriority = Int.max
        let scores: [(Double, PersonalityQuirksService.PersonalityToneContext.DominantCue)] = [
            (playfulScore, .playful),
            (warmthScore, .warm),
            (challengeScore, .assertive),
            (selfDoubtScore, .protective)
        ]
        
        for (value, cue) in scores where value > 0 {
            let cuePriority = priority(for: cue)
            if value > dominantValue || (abs(value - dominantValue) < 0.001 && cuePriority < dominantPriority) {
                dominantValue = value
                dominantPriority = cuePriority
                dominantCue = cue
            }
        }
        
        if dominantValue == 0, energyBand == .high {
            dominantCue = .playful
        }
        
        var sass = 0.5
        switch energyBand {
        case .low:
            sass -= 0.18
        case .moderate:
            break
        case .high:
            sass += 0.12
        }
        
        switch conversationTempo {
        case .slow:
            sass -= 0.06
        case .balanced:
            break
        case .punchy:
            sass += 0.07
        }
        
        if isCasualConversation {
            sass += 0.05
        }
        
        switch dominantCue {
        case .playful:
            sass += 0.2
        case .warm:
            sass -= 0.2
        case .assertive:
            sass += 0.18
        case .protective:
            sass += 0.12
        case .neutral:
            break
        }
        
        switch emotionalFriction {
        case .steady:
            break
        case .charged:
            sass -= 0.05
        case .heavy:
            sass -= 0.12
        }
        
        let clampedSass = min(max(sass, 0.1), 0.95)
        let keywordList = Array(emotionalKeywords).sorted()
        
        return PersonalityQuirksService.PersonalityToneContext(
            energyBand: energyBand,
            conversationTempo: conversationTempo,
            emotionalFriction: emotionalFriction,
            dominantCue: dominantCue,
            sassFactor: clampedSass,
            isCasualChat: isCasualConversation,
            emotionalKeywords: keywordList,
            userEnergy: userEnergy
        )
    }
    
    private static let playfulLexicon: Set<String> = [
        "lol", "haha", "kidding", "play", "tease", "flirt", "banter", "wild", "chaotic", "chaos", "fun", "spicy", "bold"
    ]
    
    private static let warmthLexicon: Set<String> = [
        "tired", "exhausted", "drained", "fatigued", "sleepy", "soft", "gentle", "sad", "lonely",
        "anxious", "worried", "stressed", "overwhelmed", "ugh", "heavy", "raw", "numb", "mess"
    ]
    
    private static let warmthPhrases: [String] = [
        "i'm tired", "i feel tired", "i'm exhausted", "i feel exhausted",
        "i'm anxious", "i feel anxious", "i'm stressed", "i feel stressed",
        "i'm overwhelmed", "i feel overwhelmed", "i messed that up", "that was a mess"
    ]
    
    private static let challengeLexicon: Set<String> = [
        "fight", "battle", "spar", "argue", "debate", "prove", "challenge", "war", "versus", "vs", "bet", "dare", "contest"
    ]
    
    private static let challengePhrases: [String] = [
        "come at me", "try me", "want to fight", "square up", "you sure about that", "step up"
    ]
    
    private static let selfDoubtLexicon: Set<String> = [
        "failed", "failure", "mess", "worthless", "useless", "awful", "terrible", "horrible", "trash", "broken",
        "embarrassed", "ashamed", "regret", "anxious", "nervous", "scared"
    ]
    
    private static let selfDoubtPhrases: [String] = [
        "i can't", "i cannot", "i'm not good enough", "i'm bad at this", "i suck", "i messed up",
        "i keep failing", "why bother", "what's the point", "i'm the worst"
    ]
    
    nonisolated private func priority(for cue: PersonalityQuirksService.PersonalityToneContext.DominantCue) -> Int {
        switch cue {
        case .protective:
            return 0
        case .warm:
            return 1
        case .assertive:
            return 2
        case .playful:
            return 3
        case .neutral:
            return 4
        }
    }
    
    private func detectSocialIntent(
        in input: String,
        payloadContext: inout AIPayloadContext?
    ) {
        let normalized = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        
        let greetings = [
            "hi", "hey", "hello", "yo", "sup", "hiya", "heya", "good morning",
            "good afternoon", "good evening", "morning", "evening", "howdy"
        ]
        let socialPhrases = [
            "how are you", "how's it going", "what's up", "how are things", "nice to see you",
            "just saying hi", "just wanted to say hi"
        ]
        
        var isSocial = false
        if greetings.contains(where: { normalized == $0 || normalized.hasPrefix("\($0) ") }) {
            isSocial = true
        }
        if !isSocial && socialPhrases.contains(where: { normalized.contains($0) }) {
            isSocial = true
        }
        
        if isSocial {
            if payloadContext == nil {
                payloadContext = AIPayloadContext(intent: .social)
            } else {
                payloadContext?.intent = .social
            }
            payloadContext?.metadata["intent"] = "social"
        }
    }
    
    // MARK: - Payload Context Formatting
    
    nonisolated private func formatPayloadContext(_ payload: AIPayloadContext) -> String {
        var sections: [String] = []
        
        if !payload.recall.isEmpty {
            let recallLines = payload.recall.prefix(5).map { snippet -> String in
                let score = String(format: "%.2f", snippet.score)
                let detail = snippet.detail.trimmingCharacters(in: .whitespacesAndNewlines)
                let shortDetail = detail.isEmpty ? "" : " - \(detail.count > 120 ? String(detail.prefix(120)) + "…" : detail)"
                
                // Add emotional context if available
                var emotionalContext = ""
                if !snippet.emotion.isEmpty && snippet.emotionIntensity > 0.1 {
                    let intensityDesc = snippet.emotionIntensity > 0.7 ? "strongly" : snippet.emotionIntensity > 0.4 ? "moderately" : "slightly"
                    emotionalContext = " [felt: \(intensityDesc) \(snippet.emotion)]"
                }
                
                let typeName = snippet.objectType.rawValue.capitalized
                return "- [\(typeName)] \(snippet.title)\(shortDetail)\(emotionalContext) (score \(score))"
            }
            
            // Aggregate emotional tone from recall snippets
            if let (dominantEmotion, avgScore) = EmotionAnalyzer.aggregate(snippets: payload.recall) {
                let emotionalTrend = avgScore > 0.3 ? "positive" : avgScore < -0.3 ? "challenging" : "neutral"
                sections.append("Recall Context:\n\(recallLines.joined(separator: "\n"))\n\nEmotional Memory: Recent work shows a \(emotionalTrend) tone with recurring \(dominantEmotion) energy.")
            } else {
                sections.append("Recall Context:\n" + recallLines.joined(separator: "\n"))
            }
        }
        
        if !payload.priorities.isEmpty {
            let priorityLines = payload.priorities.prefix(5).map { item -> String in
                let score = String(format: "%.2f", item.score)
                let detail = item.detail.trimmingCharacters(in: .whitespacesAndNewlines)
                let shortDetail = detail.isEmpty ? "" : " - \(detail.count > 120 ? String(detail.prefix(120)) + "…" : detail)"
                return "- [\(item.objectType)] \(item.title)\(shortDetail) (score \(score))"
            }
            sections.append("Priority Highlights:\n" + priorityLines.joined(separator: "\n"))
        }
        
        if !payload.feedback.isEmpty {
            let feedbackLines = payload.feedback.prefix(5).map { summary -> String in
                "- \(summary.title): \(summary.detail)"
            }
            sections.append("Recent Feedback Insights:\n" + feedbackLines.joined(separator: "\n"))
        }
        
        if let narrativeSummary = payload.narrativeSummary, !narrativeSummary.isEmpty {
            sections.append("Narrative Summary:\n\(narrativeSummary)")
        }
        
        if let focusSession = payload.focusSession {
            var focusText = "Focus Mode Status:\n"
            if focusSession.isActive, let objective = focusSession.objective {
                let elapsed = focusSession.elapsedMinutes ?? 0
                let remaining = focusSession.remainingMinutes ?? 0
                focusText += "- ACTIVE SESSION: \(objective)\n"
                focusText += "- Time: \(elapsed)m elapsed, \(remaining)m remaining\n"
            } else {
                focusText += "- No active session\n"
            }
            
            if focusSession.recentSessionCount > 0 {
                let completionPct = Int(focusSession.completionRate * 100)
                focusText += "- This week: \(focusSession.recentSessionCount) session\(focusSession.recentSessionCount == 1 ? "" : "s"), \(focusSession.totalFocusHoursThisWeek)h focused, \(completionPct)% completion"
            }
            
            sections.append(focusText)
        }
        
        if let themes = payload.liveThemes, !themes.isEmpty {
            var themesText = "Live Themes (Conceptual Brain Map):\n"
            for theme in themes.prefix(5) {
                let relevance = Int(theme.relevanceWeight * 100)
                let aliveIndicator = theme.isAlive ? "🔥" : "💤"
                themesText += "- \(aliveIndicator) **\(theme.concept)** (relevance: \(relevance)%, mentions: \(theme.mentionCount), contexts: \(theme.contextTypes.joined(separator: ", ")))\n"
            }
            sections.append(themesText)
        }
        
        if let pastConvos = payload.pastConversations, !pastConvos.isEmpty {
            var convosText = "Past Conversations (Cross-Conversation Memory):\n"
            convosText += "You have access to these recent conversations. Reference them when relevant:\n"
            for (index, convo) in pastConvos.enumerated() {
                convosText += "\n**\(index + 1). \(convo.title)** (\(convo.date), \(convo.messageCount) messages)\n"
                convosText += "   Summary: \(convo.summary)\n"
                if !convo.keyTopics.isEmpty {
                    convosText += "   Topics: \(convo.keyTopics.joined(separator: ", "))\n"
                }
                let weightPercent = Int(convo.emotionWeight * 100)
                convosText += "   Emotional tone: \(convo.emotionalTone) (recency weight: \(weightPercent)%)\n"
            }
            sections.append(convosText)
        }
        
        if let breadcrumbs = payload.conversationBreadcrumbs {
            var breadcrumbText = "Conversation Breadcrumbs:\n"
            if let emotion = breadcrumbs.lastEmotion, !emotion.isEmpty {
                breadcrumbText += "- Last user emotion noted: \(emotion)\n"
            }
            if let topic = breadcrumbs.lastTopic, !topic.isEmpty {
                breadcrumbText += "- Last conversation topic: \(topic)\n"
            }
            if let updated = breadcrumbs.lastUpdated {
                let timeAgo = Int(Date().timeIntervalSince(updated) / 60)
                breadcrumbText += "- Last update: \(timeAgo) minutes ago\n"
            }
            sections.append(breadcrumbText)
        }
        
        if let intentClusters = payload.intentClusters {
            var clustersText = "Intent Clusters:\n"
            clustersText += "- Primary cluster: \(intentClusters.primaryCluster) (\(Int(intentClusters.confidence * 100))% confidence)\n"
            if let secondary = intentClusters.secondaryCluster {
                clustersText += "- Secondary cluster: \(secondary)\n"
            }
            if intentClusters.confidence < 0.4 {
                clustersText += "- ⚠️ LOW CONFIDENCE WARNING: Confidence is below 40%. Present 2 likely paths and ask a clarifying question.\n"
            }
            if let tieBreaker = intentClusters.tieBreaker {
                clustersText += "- Tie-breaker: \(tieBreaker)\n"
            }
            if let questions = intentClusters.disambiguatingQuestions, !questions.isEmpty {
                clustersText += "- Disambiguating questions: \(questions.joined(separator: "; "))\n"
            }
            sections.append(clustersText)
        }
        
        if let memoryThemes = payload.memoryThemes, !memoryThemes.isEmpty {
            var themesText = "Memory Graph Themes (Phase 6 - DBSCAN Clustering):\n"
            for theme in memoryThemes.prefix(5) {
                let salience = Int(theme.salience * 100)
                themesText += "Theme: \"\(theme.label)\"\n"
                themesText += "  Description: \(theme.description)\n"
                themesText += "  Salience: \(salience)% (\(theme.salience > 0.7 ? "very active" : theme.salience > 0.4 ? "moderately active" : "less active"))\n"
                themesText += "  Members: \(theme.memberCount) nodes\n"
                if !theme.keywords.isEmpty {
                    themesText += "  Keywords: \(theme.keywords.joined(separator: ", "))\n"
                }
                themesText += "\n"
            }
            sections.append(themesText)
        }
        
        if let cognitiveHealth = payload.cognitiveHealth {
            var healthText = "Cognitive Health:\n"
            healthText += "- Memory density: \(cognitiveHealth.memoryDensityPerDay) entries/day\n"
            healthText += "- Stale entries: \(cognitiveHealth.staleCount)\n"
            healthText += "- Context pressure: \(String(format: "%.2f", cognitiveHealth.contextPressure))\n"
            if let coherence = cognitiveHealth.themeCoherence {
                healthText += "- Theme coherence: \(String(format: "%.2f", coherence))\n"
            }
            sections.append(healthText)
        }
        
        return sections.joined(separator: "\n\n")
    }
    
    // MARK: - Intent Detection
    
    func detectExecutionIntent(input: String, linkedContext: LinkedContext? = nil) async throws -> ExecutionIntent? {
        guard await checkOllamaAvailability() else {
            throw OllamaError.connectionFailed
        }
        
        if isLikelyGreeting(input) {
            return nil
        }
        
        // Build conversation history for context (last 10 messages)
        let historyText = buildConversationHistoryText(from: conversationHistory.suffix(10))
        
        let prompt = """
        Analyze this user message and determine if it's a request to execute an operation in the Cloutmate app.
        
        CRITICAL: Do NOT classify these as execution requests:
        - Requests for visualizations, projections, analyses, or renderings of data
        - Queries asking to "show", "display", "visualize", "render", "analyze", "project" metrics/patterns
        - Questions about "using metrics", "based on data", "with milestones", "as a curve/graph"
        - These are REFLECTION queries, not execution operations
        
        Possible operations:
        - archive_tasks: Archive, clean up, or remove old completed tasks
        - summarize_posts: Summarize, analyze, or get insights about posts
        - generate_report: Generate a basic status report (counts/summaries only, NOT analytical visualizations)
        - predict_scheduling: Suggest what content to schedule next (action planning, NOT pattern projections)
        - create_post: Create or schedule a post (optionally saving a draft)
        - publish_post: Mark an existing post as published right now
        - create_task: Create a new task (single task)
        - update_task: Update fields on an existing task (title, notes, status, priority, due date, project/area)
        - delete_task: Delete an existing task
        - create_note: Create a note
        - update_note: Update a note's title/body/tags
        - delete_note: Delete a note
        - add_inbox_item: Add something to the inbox
        - convert_inbox_item: Convert an inbox item into another object (task, note, draft/post)
        - create_project: Create a project (NOTE: Supports compound operations:
          * "create project with X tasks" → set createTasksWithProject=true, extract taskTitles or taskCount
          * "create project with notes" → set createNotesWithProject=true, extract noteTitles or noteCount
          * "create project with posts" → set createPostsWithProject=true, extract postCaptions or postCount
          * Can combine multiple: "create project with 5 tasks and 3 notes" → set multiple flags)
        - update_project: Update project fields (title, goal, status, due date, area)
        - delete_project: Delete a project
        - duplicate_project: Duplicate an existing project (optionally copying its tasks)
        - create_note: Create a note (NOTE: Supports compound operations:
          * "create note with tasks" → set createTasksWithNote=true, extract taskTitles or taskCount
          * "create note with posts" → set createPostsWithNote=true, extract postCaptions or postCount)
        - create_post: Create a post (NOTE: Supports compound operations:
          * "create post with tasks" → set createTasksWithPost=true, extract taskTitles or taskCount
          * "create post with notes" → set createNotesWithPost=true, extract noteTitles or noteCount)
        - create_artifact: Create an artifact (NOTE: Supports compound operations:
          * "create artifact with tasks" → set createTasksWithArtifact=true, extract taskTitles or taskCount
          * "create artifact with notes" → set createNotesWithArtifact=true, extract noteTitles or noteCount
          * Can combine multiple payloads if requested)
        - update_artifact: Update artifact fields (title, content, format, state, tags, project/area, notes)
        - delete_artifact: Delete an artifact
        - convert_task_to_note: Convert an existing task into a note (optionally delete the original task)
        - digest_conversation: Analyze a conversation and add it to cross-conversation memory
        - digest_all_conversations: Process all conversations for cross-conversation memory
        - search_conversations: Search past conversations by keyword
        - create_reminder: Create a reminder with a notification at a specific date/time
        
        Return ONLY JSON with these keys:
        - operation: one of "archiveTasks", "summarizePosts", "generateReport", "predictScheduling", "createPost", "publishPost", "createTask", "updateTask", "deleteTask", "createNote", "updateNote", "deleteNote", "addInboxItem", "convertInboxItem", "createProject", "updateProject", "deleteProject", "duplicateProject", "createArtifact", "updateArtifact", "deleteArtifact", "convertTaskToNote", "digestConversation", "digestAllConversations", "searchConversations", "createReminder"
        - criteria: for archive_tasks, one of "all", "completed", "olderThan"
        - daysAgo: for olderThan criteria, number of days
        - postFilter: for summarize_posts, one of "all", "published", "scheduled", "byPlatform", "byTag"
        - filterValue: value for postFilter if needed
        - reportType: for reports, one of "weekly", "daily", "monthly"
        - daysAhead: for predictions, number of days ahead (default 7)
        - caption: for create_post, the post caption text
        - scheduledDate: ISO8601 formatted string for when the post should be scheduled, or null/empty if not scheduling
        - tags: optional array of tags/keywords for the post
        - notes: optional notes for draft metadata
        - createDraft: boolean flag (true if the user explicitly wants a draft saved)
        - draftId: optional UUID of an existing draft to schedule or convert
        - postId: for publish_post, the ID of the post to mark as published
        - taskId: for update_task/delete_task, the task identifier. IMPORTANT: If the user says "that", "it", "the task", "this task", or refers to a recently created/mentioned task, look at the conversation history to find the most recently created task ID. Extract the task ID from previous messages where tasks were created.
        - taskTitle: for create_task (single task), the task title
        - taskTitles: for compound operations, array of task titles
        - taskCount: for compound operations, number of tasks requested if titles not provided
        - createTasksWithProject: boolean, set true when user requests project creation with tasks
        - createNotesWithProject: boolean, set true when user requests project creation with notes
        - createPostsWithProject: boolean, set true when user requests project creation with posts
        - createTasksWithNote: boolean, set true when user requests note creation with tasks
        - createPostsWithNote: boolean, set true when user requests note creation with posts
        - createTasksWithPost: boolean, set true when user requests post creation with tasks
        - createNotesWithPost: boolean, set true when user requests post creation with notes
        - taskNotes, taskDueDate (ISO8601), taskStatus ("todo", "in_progress", "done", "cancelled"), taskPriority ("low", "medium", "high" - extract just the priority word, e.g., "high priority" → "high", "set to high" → "high", "with a high priority" → "high"), taskProjectId, taskAreaId: fields to set for create/update task
        - noteId: for update_note/delete_note, the note identifier
        - noteTitle: for create_note (single note), the note title
        - noteTitles: for compound operations, array of note titles
        - noteCount: for compound operations, number of notes requested if titles not provided
        - noteBody, noteTags: fields for note creation or update (noteBody is Markdown content)
        - postCaptions: for compound operations, array of post captions
        - postCount: for compound operations, number of posts requested if captions not provided
        - inboxItemId: ID of the inbox item to update/convert
        - inboxContent: content to store for add_inbox_item
        - inboxType: type string ("text", "image", etc.) for add_inbox_item
        - conversionTarget: for convert_inbox_item, target type ("task", "note", "draft", "post")
        - projectId: for update_project/delete_project, the project identifier
        - projectTitle, projectGoal, projectStatus ("active", "paused", "completed"), projectDueDate (ISO8601), projectAreaId: fields for project creation/update
        - duplicateProjectTitle: optional new project title when duplicating
        - duplicateIncludeTasks: boolean flag (default true) indicating whether to copy existing project tasks when duplicating
        - publishNotes: optional string describing publishing context/outcome
        - conversationId: for digest_conversation, the UUID of the conversation to analyze
        - searchQuery: for search_conversations, the search term/keyword
        - reminderTitle: for create_reminder, the reminder title/text
        - reminderNotes: optional notes/details for the reminder
        - reminderDate: ISO8601 date string (e.g., "2025-12-25") or relative date ("tomorrow", "next Monday")
        - reminderTime: time string (e.g., "3:00 PM", "15:00", "9am") - if not provided, defaults to 9 AM
        - reminderTaskId: optional UUID of task to link reminder to
        - reminderProjectId: optional UUID of project to link reminder to
        - artifactTitle: for create_artifact/update_artifact, the artifact title
        - artifactContent: primary content/body of the artifact
        - artifactFormat: artifact output format ("brief", "summary", "reflection", "report", "releaseNote", "lessonLearned")
        - artifactState: artifact state ("idea", "draft", "final", "published", "archived")
        - artifactTags: array of tags for the artifact
        - artifactProjectId, artifactAreaId: IDs to associate artifacts with a project/area
        - artifactId: for update/delete artifact, the artifact identifier
        - artifactNotes: optional notes to store in auroraNotes field
        - createTasksWithArtifact / createNotesWithArtifact: booleans indicating compound artifact creation of tasks/notes
        - convertDeleteOriginal: for convert_task_to_note, true if the original task should be deleted after conversion (default true)
        
        If the message is NOT an execution request, return: {"operation": "none"}
        
        IMPORTANT INSTRUCTIONS:
        - For taskPriority: Extract ONLY the priority word. Examples: "high priority" → "high", "set to high" → "high", "with a high priority" → "high", "low priority" → "low", "medium priority" → "medium"
        - For updateTask: If taskId is not explicitly provided but the user refers to "that", "it", "the task", "this task", or mentions a recently created task, look at the conversation history below to find the most recently created task and use its ID.
        
        Conversation history (for context):
        \(historyText.isEmpty ? "No previous messages" : historyText)
        
        User message: \(input)
        
        JSON only:
        """
        
        do {
            let rawResponse = try await runBackgroundPromptText(prompt)
            let cleaned = rawResponse
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            guard let data = cleaned.data(using: .utf8),
                  var intent = try? JSONDecoder().decode(ExecutionIntent.self, from: data) else {
                return nil
            }
            
            // Merge linked context if provided
            if let linked = linkedContext {
                intent = mergeLinkedContext(intent, linkedContext: linked)
            }
            
            // Return nil if not an execution request
            if intent.operation.rawValue == "none" {
                return nil
            }
            
            return intent
        } catch {
            return nil
        }
    }
    
    private func isLikelyGreeting(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        
        let lower = trimmed.lowercased()
        let delimiters = CharacterSet.alphanumerics.inverted
        let tokens = lower.components(separatedBy: delimiters).filter { !$0.isEmpty }
        guard let firstToken = tokens.first else { return true }
        
        let greetingSet: Set<String> = [
            "hi", "hey", "heyy", "hello", "hiya", "yo", "sup", "hola", "heyya", "heyoo"
        ]
        
        if greetingSet.contains(firstToken) && tokens.count <= 3 && lower.count <= 40 {
            return true
        }
        
        return false
    }
    
    func detectReflectionIntent(input: String) async throws -> ReflectionIntent? {
        guard await checkOllamaAvailability() else {
            throw OllamaError.connectionFailed
        }
        
        let inputLower = input.lowercased()
        
        // Category 1: Explicit Commands (Always reflection/analytics)
        let explicitCommands = [
            "generate report",
            "export",
            "compare",
            "weekly reflection",
            "monthly reflection",
            "data report"
        ]
        let hasExplicitCommand = explicitCommands.contains(where: { inputLower.contains($0) })
        
        // Category 2: Visualization / Data Requests (Trigger reflection)
        let explicitVisualizationPhrases = [
            "visualize",
            "analyze",
            "show my",
            "display my",
            "display",
            "render",
            "chart",
            "graph",
            "insights tab",
            "my data",
            "my metrics",
            "my patterns",
            "data report"
        ]
        let hasVisualizationRequest = explicitVisualizationPhrases.contains(where: { inputLower.contains($0) })
        
        // Category 3: Casual / Conversational Queries (Conversational only, reflection-light)
        let casualPhrases = [
            "how's focus",
            "what's new",
            "how am i doing",
            "remind me",
            "talk to me",
            "catch up",
            "summarize",
            "update me",
            "what's up with",
            "what's going on with",
            "how's",
            "how are",
            "tell me about",
            "based on our conversations",
            "based on our recent conversations",
            "what do you predict",
            "what will i focus on next",
            "what do you think will happen",
            "what do you think i",
            "what are you thinking",
            "how do you feel",
            "what do you feel"
        ]
        let hasCasualPhrase = casualPhrases.contains(where: { inputLower.contains($0) })
        
        // Category 4: Blended / Ambiguous (Default to conversation, offer data)
        let isAmbiguous = isAmbiguousQuery(input: input)
        
        // PRIORITY LOGIC:
        if hasCasualPhrase {
            return nil // Conversational
        }
        
        if isAmbiguous {
            return nil // Conversational
        }
        
        if !hasExplicitCommand && !hasVisualizationRequest {
            return nil // Default to conversational
        }
        
        let prompt = """
        This message has been identified as an EXPLICIT request for data visualization/analytics (contains visualization keywords or explicit commands).
        
        Map the request to the appropriate reflection intent:
        
        - productivityPatterns: "Show my productivity trends", "Visualize my task completion", "Display my productivity data"
        - emotionalTrends: "Visualize my emotional patterns", "Show my emotional data", "Display my emotional trends"
        - focusEffectiveness: "Display my focus metrics", "Show my focus session data", "Visualize my focus patterns"
        - learningProgress: "Show my learning growth from data", "Visualize what Aurora learned about me"
        - recurringThemes: "Display recurring concepts", "Show my recurring themes", "Visualize my patterns"
        - cognitiveState: "Show my cognitive patterns", "Display my current state from data"
        - weekOverview: "Render a weekly summary", "Visualize my week", "Show my weekly data", "weekly reflection"
        - monthOverview: "Visualize monthly progress", "Display my monthly data", "monthly reflection"
        - detectedPatterns: "Show me my patterns as a visualization", "Visualize my workflows"
        - workingStyle: "Analyze my working patterns", "Show my working style data"
        
        Return ONLY JSON:
        - intent: one of "productivityPatterns", "emotionalTrends", "focusEffectiveness", "learningProgress", "recurringThemes", "cognitiveState", "weekOverview", "monthOverview", "detectedPatterns", "workingStyle"
        - timeRange: "today", "week", "month", "quarter", or "year" (default to "week" if not specified)
        
        User message: \(input)
        
        JSON only:
        """
        
        do {
            let rawResponse = try await runBackgroundPromptText(prompt)
            let cleaned = rawResponse
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            struct ReflectionResponse: Codable {
                let intent: String
                let timeRange: String?
            }
            
            guard let data = cleaned.data(using: .utf8),
                  let response = try? JSONDecoder().decode(ReflectionResponse.self, from: data) else {
                return nil
            }
            
            if response.intent == "none" {
                return nil
            }
            
            guard let reflectionIntent = ReflectionIntent(rawValue: response.intent) else {
                return nil
            }
            
            return reflectionIntent
        } catch {
            return nil
        }
    }
    
    func inferPreferenceUpdate(input: String) async throws -> PreferenceUpdate? {
        guard await checkOllamaAvailability() else {
            throw OllamaError.connectionFailed
        }
        
        let prompt = """
        Extract user preference updates from this message for Cloutmate. Return ONLY JSON with any of these keys when present:
        - preferredPostingHours: array of integers (0-23)
        - defaultTone: string (e.g., friendly, professional, playful)
        
        If nothing relevant, return an empty JSON object {}.
        
        Message: \(input)
        
        JSON only.
        """
        
        let rawResponse = try await runBackgroundPromptText(prompt)
        let cleaned = rawResponse
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        if let data = cleaned.data(using: .utf8),
           let prefs = try? JSONDecoder().decode(PreferenceUpdate.self, from: data) {
            if (prefs.preferredPostingHours ?? []).isEmpty &&
                prefs.defaultTone == nil {
                return nil
            }
            return prefs
        }
        return nil
    }
    
    nonisolated func isAmbiguousQuery(input: String) -> Bool {
        let inputLower = input.lowercased()
        let ambiguousPhrases = [
            "what patterns",
            "any changes",
            "how's my week",
            "how are things",
            "what do you notice",
            "what's happening",
            "what's going on",
            "how's it going",
            "how am i doing",
            "how are things going"
        ]
        return ambiguousPhrases.contains(where: { inputLower.contains($0) })
    }
    
    // MARK: - Conversation Management
    
    func generateConversationTitle(from firstMessage: String) async throws -> String {
        guard await checkOllamaAvailability() else {
            throw OllamaError.connectionFailed
        }
        
        let prompt = """
        Generate a concise 5-7 word title for this conversation starter: "\(firstMessage)"
        
        Return only the title, no quotes, no markdown, no explanations.
        """
        
        let rawResponse = try await runBackgroundPromptText(prompt)
        
        var title = rawResponse
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            .replacingOccurrences(of: #"[`"]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        if title.count > 60 {
            title = String(title.prefix(57)) + "..."
        }
        
        return title.isEmpty ? firstMessage : title
    }
    
    func generateConversationSummary(messages: [AIMessage]) async throws -> String {
        guard await checkOllamaAvailability() else {
            throw OllamaError.connectionFailed
        }
        
        let conversationText = messages.compactMap { message -> String? in
            guard let content = message.content, !content.isEmpty else { return nil }
            let rolePrefix = message.role == "user" ? "User" : "Assistant"
            return "\(rolePrefix): \(content)"
        }.joined(separator: "\n\n")
        
        let prompt = """
        Summarize this conversation in 2-3 sentences focusing on key topics, ideas discussed, and main outcomes. Be concise and specific.
        
        Conversation:
        \(conversationText)
        
        Summary:
        """
        
        let rawResponse = try await runBackgroundPromptText(prompt)
        return rawResponse.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func categorizeConversation(messages: [AIMessage], summary: String?) async throws -> [String] {
        guard await checkOllamaAvailability() else {
            throw OllamaError.connectionFailed
        }
        
        let context = summary ?? "No summary available"
        
        // Get a sample of messages for context
        let messageSample = messages.prefix(5).compactMap { message -> String? in
            guard let content = message.content, !content.isEmpty else { return nil }
            let role = message.role == "user" ? "User" : "Aurora"
            return "\(role): \(content)"
        }.joined(separator: "\n\n")
        
        let prompt = """
        You are Aurora, tagging this conversation naturally. Think about what this conversation is really about - not formal categories, but what you'd naturally say about it.
        
        Summary: \(context)
        
        \(messageSample.isEmpty ? "" : "Recent messages:\n\(messageSample)\n")
        
        Generate 1-3 natural, conversational tags. Think like Aurora would - use simple, human words that capture the essence:
        - Helping (for support conversations)
        - Planning (for strategy/organization)
        - Creating (for content/creative work)
        - Learning (for exploration/discovery)
        - Organizing (for task management)
        - Brainstorming (for idea generation)
        - Or any other natural word that fits
        
        Return ONLY the tags, one per line, nothing else. 
        - NO quotes around tags
        - NO periods at the end
        - NO punctuation except spaces for 2-word phrases
        - Keep them simple and natural - single words or short phrases (max 2 words)
        - Example format: Helping\nPlanning\nCreating
        """
        
        let rawResponse = try await runBackgroundPromptText(prompt)
        
        let lines = rawResponse.components(separatedBy: .newlines)
        let tags = lines.compactMap { line -> String? in
            var trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("-") || trimmed.hasPrefix("•") || trimmed.hasPrefix("#") {
                return nil
            }
            
            // Remove any numbering or bullet points
            trimmed = trimmed.replacingOccurrences(of: #"^[\d\.\-\•\#\s]+"#, with: "", options: .regularExpression)
            
            // Strip quotes if present
            trimmed = trimmed.replacingOccurrences(of: "\"", with: "")
            trimmed = trimmed.replacingOccurrences(of: "'", with: "")
            
            // Remove periods at the end
            trimmed = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            
            // Remove trailing punctuation except spaces (for 2-word phrases)
            trimmed = trimmed.trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
            
            // Validate: must be single word or max 2 words, no punctuation except spaces
            let words = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if words.count > 2 {
                return nil // Too many words
            }
            
            // Check for invalid punctuation (except spaces between words)
            let cleaned = words.joined(separator: " ")
            if cleaned.range(of: #"[^\w\s]"#, options: .regularExpression) != nil {
                return nil // Contains invalid punctuation
            }
            
            // Filter out tags that are too long (>20 chars)
            if cleaned.count > 20 {
                return nil
            }
            
            // Capitalize first letter only
            let capitalized = cleaned.isEmpty ? nil : cleaned.prefix(1).uppercased() + cleaned.dropFirst().lowercased()
            return capitalized?.isEmpty == false ? capitalized : nil
        }
        
        return Array(Set(tags.prefix(3)))
    }
    
    func summarizeRecentMessages(_ messages: [ConversationMessage], count: Int) async throws -> String {
        guard await checkOllamaAvailability() else {
            throw OllamaError.connectionFailed
        }
        
        let recentMessages = Array(messages.suffix(count))
        
        let conversationText = recentMessages.map { message in
            let rolePrefix = message.role == "assistant" || message.role == "model" ? "Assistant" : "User"
            return "\(rolePrefix): \(message.content)"
        }.joined(separator: "\n\n")
        
        let prompt = """
        Summarize this recent conversation section in a brief paragraph. Focus on key decisions, ideas, or content generated.
        
        Recent conversation:
        \(conversationText)
        
        Summary:
        """
        
        let rawResponse = try await runBackgroundPromptText(prompt)
        return rawResponse.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func generateInsights(conversations: [(title: String, tags: [String])]) async throws -> String {
        guard await checkOllamaAvailability() else {
            throw OllamaError.connectionFailed
        }
        
        let conversationsText = conversations.map { "\($0.title) (Tags: \($0.tags.joined(separator: ", ")))" }.joined(separator: "\n")
        
        let prompt = """
        Analyze these AI conversation titles and tags, then provide insights in 2-3 sentences about recurring topics, patterns, or themes.
        
        Conversations:
        \(conversationsText)
        
        Insights:
        """
        
        let rawResponse = try await runBackgroundPromptText(prompt)
        return rawResponse.isEmpty ? "No insights available at this time." : rawResponse
    }
    
    // MARK: - AI Tools
    
    func executeTool(_ tool: AITool, input: String, context: String = "") async throws -> AIToolResult {
        guard await checkOllamaAvailability() else {
            throw OllamaError.connectionFailed
        }
        
        let prompt = await buildToolPrompt(for: tool, input: input, context: context)
        let result = try await runBackgroundPrompt(prompt)
        let improvements = tool == .improveText ? extractImprovements(from: result.response) : nil
        return AIToolResult(tool: tool, result: result.response, suggestedImprovements: improvements)
    }
    
    func parseListResponse(_ text: String, tool: AITool) async throws -> [String] {
        var items: [String] = []
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty { continue }
            
            switch tool {
            case .suggestHashtags:
                let regex = try? NSRegularExpression(pattern: #"#[\w]+"#, options: [])
                let nsString = trimmed as NSString
                let matches = regex?.matches(in: trimmed, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
                
                for match in matches {
                    let range = match.range(at: 0)
                    guard range.location != NSNotFound else { continue }
                    let hashtag = nsString.substring(with: range)
                    if !items.contains(hashtag) {
                        items.append(hashtag)
                    }
                }
                
            default:
                let numberedPattern = #"^(\d+)\.\s+(.+)$"#
                let bulletPattern = #"^[•\-\*]\s+(.+)$"#
                
                let numberedRegex = try? NSRegularExpression(pattern: numberedPattern, options: [])
                let bulletRegex = try? NSRegularExpression(pattern: bulletPattern, options: [])
                
                if let numberedMatch = numberedRegex?.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.count)),
                   let contentRange = Range(numberedMatch.range(at: 2), in: trimmed) {
                    let content = String(trimmed[contentRange]).trimmingCharacters(in: .whitespaces)
                    if !content.isEmpty {
                        items.append(content)
                    }
                } else if let bulletMatch = bulletRegex?.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.count)),
                          let contentRange = Range(bulletMatch.range(at: 1), in: trimmed) {
                    let content = String(trimmed[contentRange]).trimmingCharacters(in: .whitespaces)
                    if !content.isEmpty {
                        items.append(content)
                    }
                } else if !trimmed.isEmpty && items.isEmpty {
                    items.append(trimmed)
                }
            }
        }
        
        return items.isEmpty ? [text] : items
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
        guard await checkOllamaAvailability() else {
            throw OllamaError.connectionFailed
        }
        
        // Use granite3.2-vision for image analysis
        let availableVisionModels = [
            "granite3.2-vision",
            "granite3.2-vision:latest"
        ]
        
        // Check if vision model is available
        if cachedAvailableModels.isEmpty {
            do {
                cachedAvailableModels = try await fetchAvailableModels()
                lastModelFetch = Date()
            } catch {}
        }
        
        // Find vision model from available models
        let visionModel = availableVisionModels.first { model in
            cachedAvailableModels.contains(model)
        }
        
        guard let modelToUse = visionModel else {
            // No vision model available - return helpful error
            return DocumentAnalysisResult(
                summary: "I'd love to analyze that image, but I don't have a vision-capable model installed. To enable image analysis, please install granite3.2-vision by running: `ollama pull granite3.2-vision`",
                truncatedContext: false,
                sourceModel: .ollama
            )
        }
        
        // Switch to vision model if needed
        let modelSwitched = currentModel != modelToUse
        if modelSwitched {
                previousModel = currentModel
            currentModel = modelToUse
        }
        
        let modelSwitchNotification = modelSwitched ? 
            await getModelSwitchNotification(fromModel: previousModel, toModel: currentModel) : ""
        
        // Encode image to base64
        let base64Image = imageData.base64EncodedString()
        
        // Build prompt with context
        let promptText = userPrompt ?? "Analyze this image and describe what you see. Be detailed and conversational."
        
        // Build system prompt with app context
        let casualConversation = false
        var resolvedPayloadContext = payloadContext
        detectSocialIntent(in: promptText, payloadContext: &resolvedPayloadContext)
        let includeWorkloadCues = shouldIncludeWorkloadCues(for: promptText, payloadContext: resolvedPayloadContext)
        let (_, _, _, _, enhancedToneInstructions, personalityInstructions, selfAwarenessInstructions, contextualInstructions, patternInstructions, memoryInstructions) = await MainActor.run {
            let languagePersonality = LanguagePersonalityService.shared
            let conversationalQuirks = ConversationalQuirksService.shared
            let personalityQuirks = PersonalityQuirksService.shared
            let selfAwareness = SelfAwarenessService.shared
            let contextualAdaptation = ContextualAdaptationService.shared
            let responsePattern = ResponsePatternService.shared
            
            let timeContext = contextualAdaptation.getTimeOfDayContext()
            let userEnergy = currentMessageStyle?.energyLevel ?? 0.5
            let workload = workloadLevel(from: resolvedPayloadContext)
            
            let formalityLevel = userStyleProfile?.formalityScore ?? currentMessageStyle?.formalityScore ?? 0.5
            
            var enhancedToneInstructions: String
            if let styleText = StyleAdapter.instructions(currentStyle: currentMessageStyle, persistentProfile: userStyleProfile) {
                let enhancedStyleText = languagePersonality.enhanceSystemPrompt(styleText, formalityLevel: formalityLevel)
                let confidenceLevel = confidence?.score ?? 0.7
                let quirksText = conversationalQuirks.enhancePromptWithFillers("", confidence: confidenceLevel)
                
                enhancedToneInstructions = """
**TONE & STYLE ADAPTATION:**
\(enhancedStyleText)
\(quirksText)
- Mirror the user's energy: keep it soft when they sound tired, bring more spark when they show high energy.
- CRITICAL: Never use em-dashes (—) at all. Use commas, periods, or parentheses for asides and breaks. This is essential for Aurora's natural humanization.
- Use your humanization implementations (LanguagePersonalityService, ConversationalQuirksService, PersonalityQuirksService) to make your responses feel authentically human and conversational.
- Maintain Aurora's supportive personality and clarity while mirroring the user's vibe.
- Never copy typos or offensive language; keep it respectful and aligned with platform norms.
"""
            } else {
                let enhancedDefault = languagePersonality.enhanceSystemPrompt("", formalityLevel: formalityLevel)
                enhancedToneInstructions = """
**TONE & STYLE ADAPTATION:**
\(enhancedDefault)
- Default to a friendly, encouraging tone; mirror the user's energy level (relaxed vs focused) when evident.
- Use natural contractions and approachable phrasing.
- Mirror the user's energy: keep it soft when they sound tired, bring more spark when they show high energy.
- CRITICAL: Never use em-dashes (—) at all. Use commas, periods, or parentheses for asides and breaks. This is essential for Aurora's natural humanization.
- Use your humanization implementations (LanguagePersonalityService, ConversationalQuirksService, PersonalityQuirksService) to make your responses feel authentically human and conversational.
- Never copy typos or offensive language; keep it respectful and aligned with platform norms.
"""
            }
            
            if casualConversation {
                enhancedToneInstructions += "\n- This is a casual check-in—keep it playful and skip productivity pushes unless the user pivots."
            }
            
            let personalityContext = buildPersonalityToneContext(
                input: promptText,
                style: currentMessageStyle,
                userEnergy: userEnergy,
                isCasualConversation: casualConversation
            )
            let personalityInstructions = personalityQuirks.buildPersonalityInstructions(context: personalityContext)
            let selfAwarenessInstructions = selfAwareness.generateSelfAwarenessInstructions()
            let contextualInstructions = contextualAdaptation.generateContextualInstructions(
                timeContext: timeContext,
                userEnergy: userEnergy,
                workload: workload,
                isCasualConversation: casualConversation,
                includeWorkloadCues: includeWorkloadCues,
                conversationIntent: resolvedPayloadContext?.intent
            )
            
            let isQuestion = promptText.contains("?")
            let complexity = Double(promptText.count) / 500.0
            let pattern = responsePattern.determineResponsePattern(
                messageLength: promptText.count,
                isQuestion: isQuestion,
                complexity: complexity
            )
            let patternInstructions = responsePattern.getResponsePatternInstructions(pattern: pattern)
            
            var memoryInstructions = ""
            if let recall = resolvedPayloadContext?.recall, !recall.isEmpty {
                memoryInstructions = "\n\n**MEMORY RECALL:**\n- Express memory confidence naturally: 'You definitely mentioned...' for high confidence, 'I think you mentioned...' for medium, 'I'm not entirely sure...' for low\n- Prioritize emotional memories over routine tasks\n- If memory details are fuzzy, acknowledge it gracefully"
            }
            
            return (timeContext, userEnergy, workload, formalityLevel, enhancedToneInstructions, personalityInstructions, selfAwarenessInstructions, contextualInstructions, patternInstructions, memoryInstructions)
        }
        
        var systemPrompt = """
You are Aurora, analyzing an image the user shared. Describe what you see in detail, be conversational and natural. If there's text in the image, read it. If there are objects, describe them. Be helpful and engaging.

\(appContext.prefix(1000))

\(enhancedToneInstructions)
\(personalityInstructions)
\(selfAwarenessInstructions)
\(contextualInstructions)
\(patternInstructions)
\(memoryInstructions)
"""
        
        // Build conversation history
        let historyText: String
        if let messages = conversationMessages, !messages.isEmpty {
            historyText = messages.suffix(4).map { message in
                let role = message.role == "assistant" || message.role == "model" ? "Aurora" : "User"
                return "\(role): \(message.content)"
            }.joined(separator: "\n\n")
        } else {
            historyText = ""
        }
        
        let fullPrompt = historyText.isEmpty ? 
            "\(systemPrompt)\n\nUser: \(promptText)\n\nAurora:" :
            "\(systemPrompt)\n\n\(historyText)\n\nUser: \(promptText)\n\nAurora:"
        
        // Make vision request with image
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw OllamaError.connectionFailed
        }
        
        let request = OllamaRequest(
            model: modelToUse,
            prompt: fullPrompt,
            stream: false,
            images: [base64Image],
            options: nil
        )
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 300.0 // 5 minutes for image analysis
        
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.apiError("Invalid response")
        }
        
        if httpResponse.statusCode == 404 {
            throw OllamaError.modelNotFound
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OllamaError.apiError(errorMessage)
        }
        
        let decoder = JSONDecoder()
        let ollamaResponse = try decoder.decode(OllamaResponse.self, from: data)
        
        guard ollamaResponse.done == true, !ollamaResponse.response.isEmpty else {
            throw OllamaError.emptyResponse
        }
        
        if let error = ollamaResponse.error, !error.isEmpty {
            throw OllamaError.apiError(error)
        }
        
        let analysisText = ollamaResponse.response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Switch back to default model after image analysis
        if modelSwitched, let previousModel = previousModel {
            setModel(previousModel)
        }
        
        return DocumentAnalysisResult(
            summary: analysisText + modelSwitchNotification,
            truncatedContext: false,
            sourceModel: .ollama
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
        guard await checkOllamaAvailability() else {
            throw OllamaError.connectionFailed
        }
        
        // Truncate document if too long (Ollama has context limits)
        let maxLength = 8000
        let documentText = descriptor.text.count > maxLength ? String(descriptor.text.prefix(maxLength)) : descriptor.text
        let truncated = descriptor.text.count > maxLength
        
        // Determine if this is a complex document analysis task
        let isComplexDocument = descriptor.text.count > 5000 || 
                               descriptor.text.components(separatedBy: .newlines).count > 100 ||
                               (userPrompt?.lowercased().contains("analyze") ?? false) ||
                               (userPrompt?.lowercased().contains("complex") ?? false)
        
        // For document analysis, use default model (Gemma3) unless it's a very complex document
        // Complex documents (>10k chars) might benefit from a larger model, but we'll use default for now
        // Model switching for documents is disabled - always use default model
        let modelSwitchNotification = ""
        
        // Build prompt with context and Aurora's personality
        let promptText = userPrompt ?? "Analyze this document and provide a helpful summary"
        
        // Build system prompt with app context and Aurora's personality
        let casualConversation = false
        var resolvedPayloadContext = payloadContext
        detectSocialIntent(in: promptText, payloadContext: &resolvedPayloadContext)
        let includeWorkloadCues = shouldIncludeWorkloadCues(for: promptText, payloadContext: resolvedPayloadContext)
        let (_, _, _, _, enhancedToneInstructions, personalityInstructions, selfAwarenessInstructions, contextualInstructions, patternInstructions, memoryInstructions) = await MainActor.run {
            let languagePersonality = LanguagePersonalityService.shared
            let conversationalQuirks = ConversationalQuirksService.shared
            let personalityQuirks = PersonalityQuirksService.shared
            let selfAwareness = SelfAwarenessService.shared
            let contextualAdaptation = ContextualAdaptationService.shared
            let responsePattern = ResponsePatternService.shared
            
            let timeContext = contextualAdaptation.getTimeOfDayContext()
            let userEnergy = currentMessageStyle?.energyLevel ?? 0.5
            let workload = workloadLevel(from: resolvedPayloadContext)
            
            let formalityLevel = userStyleProfile?.formalityScore ?? currentMessageStyle?.formalityScore ?? 0.5
            
            var enhancedToneInstructions: String
            if let styleText = StyleAdapter.instructions(currentStyle: currentMessageStyle, persistentProfile: userStyleProfile) {
                let enhancedStyleText = languagePersonality.enhanceSystemPrompt(styleText, formalityLevel: formalityLevel)
                let confidenceLevel = confidence?.score ?? 0.7
                let quirksText = conversationalQuirks.enhancePromptWithFillers("", confidence: confidenceLevel)
                
                enhancedToneInstructions = """
**TONE & STYLE ADAPTATION:**
\(enhancedStyleText)
\(quirksText)
- Mirror the user's energy: keep it soft when they sound tired, bring more spark when they show high energy.
- CRITICAL: Never use em-dashes (—) at all. Use commas, periods, or parentheses for asides and breaks. This is essential for Aurora's natural humanization.
- Use your humanization implementations (LanguagePersonalityService, ConversationalQuirksService, PersonalityQuirksService) to make your responses feel authentically human and conversational.
- Maintain Aurora's supportive personality and clarity while mirroring the user's vibe.
- Never copy typos or offensive language; keep it respectful and aligned with platform norms.
"""
            } else {
                let enhancedDefault = languagePersonality.enhanceSystemPrompt("", formalityLevel: formalityLevel)
                enhancedToneInstructions = """
**TONE & STYLE ADAPTATION:**
\(enhancedDefault)
- Default to a friendly, encouraging tone; mirror the user's energy level (relaxed vs focused) when evident.
- Use natural contractions and approachable phrasing.
- Mirror the user's energy: keep it soft when they sound tired, bring more spark when they show high energy.
- CRITICAL: Never use em-dashes (—) at all. Use commas, periods, or parentheses for asides and breaks. This is essential for Aurora's natural humanization.
- Use your humanization implementations (LanguagePersonalityService, ConversationalQuirksService, PersonalityQuirksService) to make your responses feel authentically human and conversational.
- Never copy typos or offensive language; keep it respectful and aligned with platform norms.
"""
            }
            
            if casualConversation {
                enhancedToneInstructions += "\n- This is a casual check-in—keep it playful and skip productivity pushes unless the user pivots."
            }
            
            let personalityContext = buildPersonalityToneContext(
                input: promptText,
                style: currentMessageStyle,
                userEnergy: userEnergy,
                isCasualConversation: casualConversation
            )
            let personalityInstructions = personalityQuirks.buildPersonalityInstructions(context: personalityContext)
            let selfAwarenessInstructions = selfAwareness.generateSelfAwarenessInstructions()
            let contextualInstructions = contextualAdaptation.generateContextualInstructions(
                timeContext: timeContext,
                userEnergy: userEnergy,
                workload: workload,
                isCasualConversation: casualConversation,
                includeWorkloadCues: includeWorkloadCues,
                conversationIntent: resolvedPayloadContext?.intent
            )
            
            let isQuestion = promptText.contains("?")
            let complexity = Double(promptText.count) / 500.0
            let pattern = responsePattern.determineResponsePattern(
                messageLength: promptText.count,
                isQuestion: isQuestion,
                complexity: complexity
            )
            let patternInstructions = responsePattern.getResponsePatternInstructions(pattern: pattern)
            
            var memoryInstructions = ""
            if let recall = resolvedPayloadContext?.recall, !recall.isEmpty {
                memoryInstructions = "\n\n**MEMORY RECALL:**\n- Express memory confidence naturally: 'You definitely mentioned...' for high confidence, 'I think you mentioned...' for medium, 'I'm not entirely sure...' for low\n- Prioritize emotional memories over routine tasks\n- If memory details are fuzzy, acknowledge it gracefully"
            }
            
            return (timeContext, userEnergy, workload, formalityLevel, enhancedToneInstructions, personalityInstructions, selfAwarenessInstructions, contextualInstructions, patternInstructions, memoryInstructions)
        }
        
        var systemPrompt = """
You are Aurora, analyzing a document the user shared. Be conversational, helpful, and natural. Extract key information, summarize main points, and identify any actionable items. Be engaging and supportive.

\(appContext.prefix(1000))

\(enhancedToneInstructions)
\(personalityInstructions)
\(selfAwarenessInstructions)
\(contextualInstructions)
\(patternInstructions)
\(memoryInstructions)
"""
        
        // Build conversation history
        let historyText: String
        if let messages = conversationMessages, !messages.isEmpty {
            historyText = messages.suffix(4).map { message in
                let role = message.role == "assistant" || message.role == "model" ? "Aurora" : "User"
                return "\(role): \(message.content)"
            }.joined(separator: "\n\n")
        } else {
            historyText = ""
        }
        
        let fullPrompt = """
        \(systemPrompt)

        Document Information:
        - File: \(descriptor.fileName)
        - Type: \(descriptor.mimeType)
        \(truncated ? "- Note: Document was truncated due to length (showing first \(maxLength) characters)" : "")
        
        User request: \(promptText)

        \(historyText.isEmpty ? "" : "\n\(historyText)\n")
        
        Document content:
        \(documentText)
        
        Aurora, analyze this document and provide a helpful, conversational summary. Focus on:
        1. Main topic/theme
        2. Key points or takeaways
        3. Any action items or next steps
        4. Important details the user should know

        Be natural and engaging in your response.
        """
        
        let result = try await makeOllamaRequest(prompt: fullPrompt, useThinking: false)
        
        return DocumentAnalysisResult(
            summary: result.response + modelSwitchNotification,
            truncatedContext: truncated,
            sourceModel: .ollama
        )
    }
    
    // MARK: - Helper Methods
    
    private func mergeLinkedContext(_ intent: ExecutionIntent, linkedContext: LinkedContext) -> ExecutionIntent {
        var merged = intent
        switch merged.operation {
        case .createTask, .updateTask:
            if merged.taskProjectId == nil, let projectId = linkedContext.linkedProjects.first {
                merged.taskProjectId = projectId.uuidString
            }
            if merged.taskId == nil, merged.operation == .updateTask, let taskId = linkedContext.linkedTasks.first {
                merged.taskId = taskId.uuidString
            }
        case .createProject, .updateProject, .duplicateProject:
            if merged.projectId == nil, let projectId = linkedContext.linkedProjects.first {
                merged.projectId = projectId.uuidString
            }
        case .createNote, .updateNote:
            if merged.noteId == nil, merged.operation == .updateNote, let noteId = linkedContext.linkedNotes.first {
                merged.noteId = noteId.uuidString
            }
        case .createArtifact, .updateArtifact:
            if merged.artifactProjectId == nil, let projectId = linkedContext.linkedProjects.first {
                merged.artifactProjectId = projectId.uuidString
            }
            if merged.operation == .updateArtifact, merged.artifactId == nil, let artifactId = linkedContext.linkedArtifacts.first {
                merged.artifactId = artifactId.uuidString
            }
        case .convertTaskToNote:
            if merged.taskId == nil, let taskId = linkedContext.linkedTasks.first {
                merged.taskId = taskId.uuidString
            }
            if merged.projectId == nil, let projectId = linkedContext.linkedProjects.first {
                merged.projectId = projectId.uuidString
            }
        default:
            break
        }
        if merged.linkedContext == nil {
            merged.linkedContext = linkedContext
        }
        return merged
    }
    
    private func buildToolPrompt(for tool: AITool, input: String, context: String) async -> String {
        switch tool {
        case .brainstorm:
            return """
            Generate 5 distinct content ideas for the following topic.
            
            Topic: \(input)
            
            Format each idea as a numbered list (1., 2., 3., etc.). Each idea should be 1-2 sentences. Focus on engagement, authenticity, and clear communication.
            """
            
        case .generateCaptions:
            return """
            Generate 3 different caption options.
            
            Topic: \(input)
            
            Format as a numbered list (1., 2., 3., etc.). Each caption should be complete and ready to use. Keep the tone engaging and authentic.
            """
            
        case .improveText:
            return """
            Provide 3 improved versions of this text.
            
            Original text: \(input)
            
            Format as a numbered list (1., 2., 3.). Each version should be a complete improved version. Focus on: better flow, engagement, readability, and maintaining an authentic tone.
            """
            
        case .suggestHashtags:
            return """
            Suggest 10 relevant hashtags for this content.
            
            Content: \(input)
            
            Format as a simple list of hashtags, one per line or space-separated. Mix popular and niche hashtags. No explanations needed, just the hashtags.
            """
            
        case .adjustTone:
            let toneRequest = context.isEmpty ? "make it more engaging and personal" : context
            return """
            Provide 3 tone variations of this text.
            
            Original text: \(input)
            
            Each variation should \(toneRequest). Format as a numbered list (1., 2., 3.). Each should be a complete rewrite with the adjusted tone.
            """
        }
    }
    
    private func extractImprovements(from text: String) -> [String]? {
        let lines = text.components(separatedBy: .newlines)
        var improvements: [String] = []
        
        for line in lines {
            if line.lowercased().contains("improved") ||
               line.lowercased().contains("changed") ||
               line.lowercased().contains("added") ||
               line.lowercased().contains("removed") {
                improvements.append(line.trimmingCharacters(in: .whitespaces))
            }
        }
        
        return improvements.isEmpty ? nil : improvements
    }
    
    // MARK: - Changelog Query Methods
    
    /// Query Aurora's changelog for specific information
    func queryChangelog(feature: String? = nil, days: Int? = nil, userFacingOnly: Bool = true) async -> String {
        return await changelogService.queryChangelog(feature: feature, days: days, userFacingOnly: userFacingOnly)
    }
    
    /// Check if a user query relates to a recent update
    nonisolated func shouldMentionUpdate(for query: String) -> Bool {
        let lowercasedQuery = query.lowercased()
        
        // Core update keywords
        let updateKeywords = [
            "new", "update", "change", "feature", "capability", "can you", "what can", 
            "recent", "latest", "what did you get", "what did you learn", "what's new", 
            "what changed", "when were you updated", "when did you last change",
            "what have you learned", "what have you got", "what did you receive",
            "tell me about your updates", "show me your updates", "what updates",
            "any updates", "any changes", "any new features", "what's changed",
            "what's different", "what's new with you", "what have you been up to",
            "what improvements", "what enhancements", "what additions"
        ]
        
        // Check for temporal update queries
        let temporalPatterns = ["yesterday", "today", "last week", "recently", "lately", "this week", "last month"]
        let hasTemporal = temporalPatterns.contains { lowercasedQuery.contains($0) }
        let hasUpdateKeyword = updateKeywords.contains { lowercasedQuery.contains($0) }
        
        // Check for "what did you get/learn/receive" patterns
        let getPatterns = [
            "what did you get", "what did you learn", "what did you receive", 
            "what have you got", "what have you learned", "what did you add",
            "what did you change", "what did you improve"
        ]
        let hasGetPattern = getPatterns.contains { lowercasedQuery.contains($0) }
        
        // Check for version/update date queries
        let versionPatterns = [
            "when were you updated", "when did you update", "when was your last update",
            "when did you last change", "when were you last updated", "last update date",
            "update date", "version", "what version"
        ]
        let hasVersionPattern = versionPatterns.contains { lowercasedQuery.contains($0) }
        
        return hasUpdateKeyword || (hasTemporal && (hasGetPattern || hasUpdateKeyword)) || hasGetPattern || hasVersionPattern
    }
    
    /// Get relevant updates for a user query
    func getRelevantUpdates(for query: String) async -> String {
        let lowercasedQuery = query.lowercased()
        
        // Check for version/date queries first - these need general update info
        if lowercasedQuery.contains("when were you updated") || 
           lowercasedQuery.contains("when did you update") ||
           lowercasedQuery.contains("when was your last update") ||
           lowercasedQuery.contains("when did you last change") ||
           lowercasedQuery.contains("last update date") ||
           lowercasedQuery.contains("update date") ||
           lowercasedQuery.contains("what version") {
            // Return general update info for version/date queries
            let updateInfo = await getUpdateInfo()
            if !updateInfo.isEmpty {
                return updateInfo
            }
            // Fallback to latest update if general info not available
            return await getLatestUpdate()
        }
        
        // Check for "latest" or "most recent" queries
        if lowercasedQuery.contains("latest") || lowercasedQuery.contains("most recent") || lowercasedQuery.contains("last update") {
            let latest = await getLatestUpdate()
            if !latest.isEmpty && latest != "No update information available." {
                return latest
            }
        }
        
        // Check for temporal queries (yesterday, today, last week, etc.)
        if lowercasedQuery.contains("yesterday") {
            return await queryChangelog(days: 1, userFacingOnly: true)
        } else if lowercasedQuery.contains("today") {
            return await queryChangelog(days: 1, userFacingOnly: true)
        } else if lowercasedQuery.contains("last week") || lowercasedQuery.contains("this week") {
            return await queryChangelog(days: 7, userFacingOnly: true)
        } else if lowercasedQuery.contains("last month") || lowercasedQuery.contains("this month") {
            return await queryChangelog(days: 30, userFacingOnly: true)
        } else if lowercasedQuery.contains("recently") || lowercasedQuery.contains("lately") {
            return await queryChangelog(days: 7, userFacingOnly: true)
        }
        
        // Check for specific feature mentions
        let features = ["model", "ollama", "offline", "airplane", "focus", "memory", "priority", "ritual", "predictive", "temporal", "document", "image", "changelog", "routing", "thinking", "deepseek", "qwen", "granite"]
        for feature in features {
            if lowercasedQuery.contains(feature) {
                let featureUpdates = await queryChangelog(feature: feature, userFacingOnly: true)
                if !featureUpdates.isEmpty && featureUpdates != "No matching changes found in the changelog." {
                    return featureUpdates
                }
            }
        }
        
        // Default to recent changes if query seems update-related
        if shouldMentionUpdate(for: query) {
            return await queryChangelog(days: 30, userFacingOnly: true)
        }
        
        return ""
    }
    
    // MARK: - Git History Query Methods
    
    /// Query git commit history
    func queryCommitHistory(days: Int? = nil) async -> String {
        let commits = await changelogService.getCommitHistory(days: days)
        return await changelogService.formatCommitHistory(commits)
    }
    
    /// Get commits for a specific feature
    func getCommitsForFeature(_ feature: String) async -> String {
        let commits = await changelogService.getCommitsForFeature(feature)
        return await changelogService.formatCommitHistory(commits)
    }
    
    /// Get details for a specific commit
    func getCommitDetails(_ hash: String) async -> String {
        guard let commit = await changelogService.getCommitDetails(hash) else {
            return "Commit not found."
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        var details = "**Commit \(commit.hash.prefix(7)):**\n\n"
        details += "**Message:** \(commit.message)\n"
        details += "**Date:** \(dateFormatter.string(from: commit.date))\n"
        details += "**Author:** \(commit.author)\n"
        if !commit.files.isEmpty {
            details += "**Files Changed:**\n"
            for file in commit.files {
                details += "- \(file)\n"
            }
        }
        if let changelogId = commit.changelogEntryId {
            details += "\n**Linked to changelog entry:** \(changelogId.uuidString)"
        }
        
        return details
    }
    
    /// Get update information (when Aurora was last updated, latest update, etc.)
    func getUpdateInfo() async -> String {
        return await changelogService.getUpdateInfo()
    }
    
    /// Get the last updated date
    func getLastUpdatedDate() async -> Date? {
        return await changelogService.getLastUpdatedDate()
    }
    
    /// Get the latest update entry
    func getLatestUpdate() async -> String {
        guard let latest = await changelogService.getLatestUpdate() else {
            return "No update information available."
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        
        var info = "**My Latest Update:**\n\n"
        info += "**Feature:** \(latest.feature)\n"
        info += "**Type:** \(latest.changeType.rawValue.capitalized)\n"
        info += "**Description:** \(latest.description)\n"
        info += "**Impact:** \(latest.impact)\n"
        
        if let latestDate = latest.dateValue {
            info += "**Date:** \(dateFormatter.string(from: latestDate))\n"
        }
        
        if let commitHash = latest.commitHash {
            info += "**Commit:** \(commitHash.prefix(7))\n"
        }
        
        if !latest.tags.isEmpty {
            info += "**Tags:** \(latest.tags.joined(separator: ", "))\n"
        }
        
        return info
    }
}

// MARK: - Array Extension for Tone Analysis

extension Array where Element == AuroraTone {
    /// Find the most frequently occurring tone
    func mostFrequent() -> AuroraTone? {
        guard !isEmpty else { return nil }
        let frequency = Dictionary(grouping: self, by: { $0 })
            .mapValues { $0.count }
        return frequency.max(by: { $0.value < $1.value })?.key
    }
}

// MARK: - Preference Update Type

struct PreferenceUpdate: Codable {
    let preferredPostingHours: [Int]?
    let defaultPlatforms: [String]?
    let defaultTone: String?
}

