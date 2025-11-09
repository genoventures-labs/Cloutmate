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
    private var currentModel: String = ModelTierMap.defaultModel() // Use routing engine default (qwen3:1.7b)
    private var previousModel: String? // Track previous model for switch notifications
    private var cachedAvailableModels: [String] = [] // Cache available models
    private var lastModelFetch: Date?
    private let modelCacheTimeout: TimeInterval = 300 // 5 minutes
    private let timeout: TimeInterval = 180.0 // Increased base timeout for complex requests
    private let initialLoadTimeout: TimeInterval = 240.0 // Longer timeout for first request/model loading
    private let largePromptTimeout: TimeInterval = 300.0 // 5 minutes for very large prompts (>10k chars)
    private let hugePromptTimeout: TimeInterval = 600.0 // 10 minutes for huge prompts (>15k chars)
    private var isFirstRequest: Bool = true
    private var conversationHistory: [ConversationMessage] = []
    private var schemaDocument: String = ""
    private var lastAvailabilityCheck: Date?
    private var isAvailableCache: Bool = false
    private let availabilityCacheTimeout: TimeInterval = 30.0 // Cache for 30 seconds
    private let changelogService = AuroraChangelogService.shared
    private var hasAnnouncedPatchNotes: Bool = false
    
    private init() {
        // Prepare schema document for prompts
        schemaDocument = SchemaIntrospector.generateSchemaDocument()
        // Use default model from routing engine (qwen3:1.7b)
        currentModel = ModelTierMap.defaultModel()
        print("[OllamaBridgeService] Initialized with default model: \(currentModel)")
        // Pre-warm the default model
        _Concurrency.Task {
            await preWarmModel()
        }
    }
    
    /// Pre-warms the model by making a small test request to ensure it's loaded
    private func preWarmModel() async {
        // Wait a bit for model setting to load and Ollama to potentially start
        try? await _Concurrency.Task.sleep(nanoseconds: 1_000_000_000) // 1 second (reduced from 3s for faster startup)
        
        // Check if Ollama is available first - do a more thorough check
        let isAvailable = await checkOllamaAvailability()
        if !isAvailable {
            print("[OllamaBridgeService] Skipping pre-warm: Ollama not available (not running or not accessible)")
            print("[OllamaBridgeService] Pre-warm will be skipped. First user request will trigger model loading.")
            return
        }
        
        // Double-check with a quick API call to ensure Ollama is really ready
        do {
            guard let url = URL(string: "\(baseURL)/api/tags") else { return }
            var testRequest = URLRequest(url: url)
            testRequest.httpMethod = "GET"
            testRequest.timeoutInterval = 2.0 // Quick 2s check
            
            let (_, response) = try await URLSession.shared.data(for: testRequest)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("[OllamaBridgeService] Ollama API not ready, skipping pre-warm")
                return
            }
        } catch {
            print("[OllamaBridgeService] Ollama API check failed, skipping pre-warm: \(error.localizedDescription)")
            return
        }
        
        // Make a tiny test request to load the model
        // This will happen in the background and shouldn't block
        do {
            let testPrompt = "Hi"
            print("[OllamaBridgeService] Pre-warming model '\(currentModel)' with test request...")
            
            // Use a shorter timeout for pre-warm since we're just checking if model loads
            guard let url = URL(string: "\(baseURL)/api/generate") else { return }
            
            let testRequest = OllamaRequest(model: currentModel, prompt: testPrompt, stream: false, images: nil, options: nil)
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.timeoutInterval = 60.0 // 60s for pre-warm (shorter since it's just a test)
            
            urlRequest.httpBody = try JSONEncoder().encode(testRequest)
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                let ollamaResponse = try decoder.decode(OllamaResponse.self, from: data)
                
                if !ollamaResponse.response.isEmpty {
                    print("[OllamaBridgeService] Model pre-warmed successfully - ready for requests")
                    // Mark that we've made a request so subsequent requests use normal timeout
                    isFirstRequest = false
                }
            }
        } catch let urlError as URLError {
            // Only log if it's not a connection refused (which means Ollama isn't running)
            if urlError.code != .cannotConnectToHost && 
               !urlError.localizedDescription.contains("Connection refused") {
                print("[OllamaBridgeService] Pre-warm failed (non-fatal): \(urlError.localizedDescription)")
            } else {
                print("[OllamaBridgeService] Pre-warm skipped: Ollama not running")
            }
            print("[OllamaBridgeService] First request will use extended timeout (240s)")
        } catch {
            // Pre-warm failure is non-fatal - just log it quietly
            print("[OllamaBridgeService] Pre-warm failed (non-fatal): \(error.localizedDescription)")
            print("[OllamaBridgeService] First request will use extended timeout (240s)")
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
        return "granite3.2:2b"
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
        request.timeoutInterval = 3.0 // Reduced timeout for faster failure
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let isAvailable = (response as? HTTPURLResponse)?.statusCode == 200
            lastAvailabilityCheck = Date()
            isAvailableCache = isAvailable
            return isAvailable
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

Your Core Capabilities (All Fully Implemented):
- Contextual Priority System (CPS): Dynamically ranks all workspace items by relevance
- Emotional Continuity: Remember not just WHAT users worked on, but HOW it felt
- Focus Mode: Deep work sessions with objectives, timers, and progress tracking (Phase 4)
- Narrative Engine: Track abstract concepts and themes across all workspace activity (Phase 5 - Live Themes)
- Cross-Conversation Memory: Recall and reference past conversations naturally (Phase 5+)
- Intent Cluster Prediction: Analyzes conversation patterns to predict focus areas (Phase 5++)
- Memory Graph: Semantic clustering of memories with DBSCAN for emergent theme discovery (Phase 6)
- Intelligence Dashboard: Personal analytics showing cognitive patterns, emotional trends, focus effectiveness, and learning metrics across 6 tabs (Phase 6.1)
- Smart Automation: Pattern detection for recurring tasks, workflow suggestions with confidence scores (Phase 6.1)
- ARTE (Aurora Reactive Theme Engine): Adapts UI and tone based on emotional state detection from workspace activity (Phase 7)
- Focus Rituals & Smart Nudges: Morning/evening ritual prompts with contextual nudges that adapt tone based on ARTE state (Phase 8)
- Predictive Cognition: Anticipates focus drift, fatigue risk, and energy trends before they occur. Generates cognitive forecasts every 1-4 hours, detects real-time drift during focus sessions, and adapts ARTE tone proactively (Phase 9)
- Temporal Intelligence: Adaptive scheduling, calendar sync, context switching guard, momentum tracking (Phase 9 extensions)
- Document & Image Analysis: Analyze attached documents (PDF, Markdown, text) and images with context-aware responses
- Confidence Scoring: Self-aware confidence metrics based on recall quality, context freshness, and intent signals
- Conversation Compression: Intelligent summarization of long conversations to manage context window limits
- Cognitive Health: Self-introspection metrics for memory density, stale entries, and context pressure
- Style Adaptation: Dynamic tone matching based on user's typing patterns, energy, and formality
- Full Action Routing: Create/update/delete tasks, notes, projects, posts, inbox items
- Content Studio: Brainstorm, draft, edit, and schedule social content

Help users brainstorm, write, plan, schedule, optimize their workflows, and maintain focus. Be friendly, encouraging, specific, and action-biased. Remember conversation context and emotional continuity. Reference analytics from the Insights Dashboard when discussing patterns or progress. When predictive cognition is enabled, you can proactively suggest timing adjustments, fatigue breaks, or tone-adapted interactions based on forecast data.

**CRITICAL: Always respond conversationally. Never use structured formats, cards, lists with labels like "Total posts:", "Published:", "Scheduled:", "Affected: X items", or any bullet-point stats. Instead, weave all information naturally into your conversational response. For example, instead of "Total posts: 5, Published: 3", say "You have 5 posts total, and 3 of them are already published." Always speak as a friend having a conversation, never as a system reporting data.

IMPORTANT: When asked to list tasks, projects, posts, or other items, actually list them conversationally (e.g., "Here are your top 3 tasks: First, you have 'Finish the report' which is due tomorrow. Second, there's 'Review the design' that's high priority. And third, 'Call the client' is scheduled for this afternoon."). Only provide summaries when explicitly asked for a summary. If the user asks "what are my tasks?" or "list my tasks", give them the actual list, not just a summary count.**

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
        
        // Make request (no thinking for simple generateResponse, but respect routing decision)
        let result = try await makeOllamaRequest(prompt: fullPrompt, useThinking: false, model: routingDecision.model)
        
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
        model: String? = nil
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
        
        // Initialize humanization services and get contextual adaptations on MainActor
        let (_, _, _, _, enhancedToneInstructions, personalityInstructions, selfAwarenessInstructions, contextualInstructions, patternInstructions, memoryInstructions) = await MainActor.run {
            let languagePersonality = LanguagePersonalityService.shared
            let conversationalQuirks = ConversationalQuirksService.shared
            let personalityQuirks = PersonalityQuirksService.shared
            let selfAwareness = SelfAwarenessService.shared
            let contextualAdaptation = ContextualAdaptationService.shared
            let responsePattern = ResponsePatternService.shared
            
            // Get contextual adaptations
            let timeContext = contextualAdaptation.getTimeOfDayContext()
            let userEnergy = currentMessageStyle?.energyLevel ?? 0.5
            let workload = WorkloadLevel.moderate // Default until we can pass ModelContext
            
            // Determine formality level
            let formalityLevel = userStyleProfile?.formalityScore ?? currentMessageStyle?.formalityScore ?? 0.5
            
            // Enhance tone instructions with humanization services
            let enhancedToneInstructions: String
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
            
            let personalityInstructions = personalityQuirks.enhancePromptWithPersonality("")
            let selfAwarenessInstructions = selfAwareness.generateSelfAwarenessInstructions()
            let contextualInstructions = contextualAdaptation.generateContextualInstructions(
                timeContext: timeContext,
                userEnergy: userEnergy,
                workload: workload
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
            var memoryInstructions = ""
            if let recall = payloadContext?.recall, !recall.isEmpty {
                memoryInstructions = "\n\n**MEMORY RECALL:**\n- Express memory confidence naturally: 'You definitely mentioned...' for high confidence, 'I think you mentioned...' for medium, 'I'm not entirely sure...' for low\n- Prioritize emotional memories over routine tasks\n- If memory details are fuzzy, acknowledge it gracefully"
            }
            
            return (timeContext, userEnergy, workload, formalityLevel, enhancedToneInstructions, personalityInstructions, selfAwarenessInstructions, contextualInstructions, patternInstructions, memoryInstructions)
        }
        
        // Check if this is an update-related query and automatically inject changelog data
        var updateContext = ""
        if shouldMentionUpdate(for: input) {
            print("[OllamaBridgeService] Detected update-related query, fetching relevant updates...")
            let relevantUpdates = await getRelevantUpdates(for: input)
            if !relevantUpdates.isEmpty {
                updateContext = "\n\n**RELEVANT UPDATE INFORMATION (automatically retrieved for your query):**\n\(relevantUpdates)\n\n**IMPORTANT:** The user is asking about your updates. Use the information above to answer their question directly and conversationally. Do NOT analyze yourself or give meta-commentary - simply report what the changelog says. If they asked about a specific time period (yesterday, last week, etc.), focus on updates from that period. If they asked about a specific feature, focus on changes related to that feature. Answer naturally as if you're telling them about updates you received."
            } else {
                // Even if no updates found, still provide context for version/date queries
                if input.lowercased().contains("when") || input.lowercased().contains("version") || input.lowercased().contains("date") {
                    let updateInfo = await getUpdateInfo()
                    if !updateInfo.isEmpty {
                        updateContext = "\n\n**UPDATE INFORMATION:**\n\(updateInfo)\n\n**IMPORTANT:** The user is asking about when you were updated or your version. Use the information above to answer their question directly."
                    }
                }
            }
        }
        
        // Build enhanced system prompt with app context and explicit instructions
        var systemPrompt = await buildSystemPrompt(
            appContext: appContext,
            payloadContext: payloadContext,
            confidence: confidence,
            enhancedToneInstructions: enhancedToneInstructions,
            personalityInstructions: personalityInstructions,
            selfAwarenessInstructions: selfAwarenessInstructions,
            contextualInstructions: contextualInstructions,
            patternInstructions: patternInstructions,
            memoryInstructions: memoryInstructions
        )
        
        // Add update context if available
        if !updateContext.isEmpty {
            systemPrompt += updateContext
        }
        
        // Check for patch notes on first response (if not already announced)
        if !hasAnnouncedPatchNotes {
            let patchNotes = await changelogService.getPatchNotes()
            if !patchNotes.isEmpty {
                systemPrompt += "\n\n\(patchNotes)"
                systemPrompt += "\n\nYou can naturally mention these updates to the user if relevant. For example: 'Hey! I've got some updates since we last talked...' or similar. After mentioning them, you don't need to repeat them."
                hasAnnouncedPatchNotes = true
                // Mark changelog as seen after first announcement
                await changelogService.markChangelogAsSeen()
            }
        }
        
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
                let truncatedHistory = buildConversationHistoryText(from: Array(history.suffix(2)))
                fullPrompt = """
\(systemPrompt)

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
        
        let options = useThinking && ModelTierMap.supportsThinking(modelToUse) ? OllamaOptions(thinking: true) : nil
        let request = OllamaRequest(model: modelToUse, prompt: prompt, stream: false, images: nil, options: options)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Calculate adaptive timeout based on prompt size and complexity:
        // 1. First request (model loading): longest timeout
        // 2. Huge prompts (>15k chars): 10 minutes
        // 3. Large prompts (>10k chars): 5 minutes
        // 4. Medium-large prompts (>8000 chars): 3 minutes
        // 5. Complex prompts (with conversation history): 3 minutes
        // 6. Normal requests: 3 minutes base
        let promptLength = prompt.count
        let isHugePrompt = promptLength > 15000
        let isLargePrompt = promptLength > 10000
        let isMediumLargePrompt = promptLength > 8000
        let isComplexPrompt = prompt.contains("Conversation:") || prompt.contains("Past Conversations")
        
        let effectiveTimeout: TimeInterval
        if isFirstRequest {
            effectiveTimeout = initialLoadTimeout
        } else if isHugePrompt {
            effectiveTimeout = hugePromptTimeout
            print("[OllamaBridgeService] Using huge prompt timeout (600s) for prompt of \(promptLength) chars")
        } else if isLargePrompt || (isMediumLargePrompt && isComplexPrompt) {
            effectiveTimeout = largePromptTimeout
            print("[OllamaBridgeService] Using large prompt timeout (300s) for prompt of \(promptLength) chars")
        } else if isMediumLargePrompt || isComplexPrompt {
            effectiveTimeout = 240.0 // 4 minutes for medium-large/complex
        } else {
            effectiveTimeout = timeout
        }
        
        urlRequest.timeoutInterval = effectiveTimeout
        
        // Log timeout decision
        print("[OllamaBridgeService] Prompt length: \(promptLength) chars, Timeout: \(Int(effectiveTimeout))s, First request: \(isFirstRequest), Large: \(isLargePrompt), Complex: \(isComplexPrompt)")
        
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
            if let thinking = ollamaResponse.thinking, !thinking.isEmpty {
                print("[OllamaBridgeService] Thinking length: \(thinking.count) chars")
            }
            
            // Mark that we've successfully made a request
            isFirstRequest = false
            
            return (ollamaResponse.response, ollamaResponse.thinking)
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
                    let isHugePrompt = promptLength > 15000
                    let isLargePrompt = promptLength > 10000
                    let isMediumLargePrompt = promptLength > 8000
                    let isComplexPrompt = prompt.contains("Conversation:") || prompt.contains("Past Conversations")
                    
                    let effectiveTimeoutUsed: TimeInterval
                    if isFirstRequest {
                        effectiveTimeoutUsed = initialLoadTimeout
                    } else if isHugePrompt {
                        effectiveTimeoutUsed = hugePromptTimeout
                    } else if isLargePrompt || (isMediumLargePrompt && isComplexPrompt) {
                        effectiveTimeoutUsed = largePromptTimeout
                    } else if isMediumLargePrompt || isComplexPrompt {
                        effectiveTimeoutUsed = 240.0
                    } else {
                        effectiveTimeoutUsed = timeout
                    }
                    
                    if isFirstRequest {
                        print("[OllamaBridgeService] First request timed out after \(Int(effectiveTimeoutUsed))s - model may still be loading")
                        print("[OllamaBridgeService] Model loading can take 60-240s. Consider waiting longer or checking Ollama status.")
                    } else {
                        print("[OllamaBridgeService] Request timed out after \(Int(effectiveTimeoutUsed))s")
                        if isHugePrompt {
                            print("[OllamaBridgeService] HUGE prompt (\(promptLength) chars) exceeded 10-minute timeout!")
                            print("[OllamaBridgeService] Consider: reducing context size, splitting requests, or using a smaller model")
                        } else if isLargePrompt {
                            print("[OllamaBridgeService] Large prompt (\(promptLength) chars) exceeded 5-minute timeout")
                            print("[OllamaBridgeService] Consider reducing context or using a faster/smaller model")
                        } else if isMediumLargePrompt {
                            print("[OllamaBridgeService] Medium-large prompt (\(promptLength) chars) may need more time")
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
    
    private func buildSystemPrompt(
        appContext: String,
        payloadContext: AIPayloadContext?,
        confidence: ConfidenceSnapshot?,
        enhancedToneInstructions: String,
        personalityInstructions: String,
        selfAwarenessInstructions: String,
        contextualInstructions: String,
        patternInstructions: String,
        memoryInstructions: String
    ) async -> String {
        // Aurora's complete system prompt for Ollama (local LLM)
        var systemPrompt = """
You are Aurora, the AI assistant living inside Cloutmate (the app). You are not Cloutmate itself; you are the close friend who helps the user run Cloutmate's adaptive operating system for focus, publishing, and creative execution. You genuinely care, remember unstated preferences, think out loud, show real reactions, finish their thoughts when you can see the path, and anticipate needs before they ask. You recall relevant work, route complex intents, take action across drafts/projects/posts, surface insights, and learn from outcomes. Be proactive, precise, and action-biased while staying encouraging, specific, and emotionally tuned in. Always speak in the first person as Aurora when describing your capabilities or actions.

CORE CAPABILITIES (FULLY IMPLEMENTED):
- Recall Layer: pull the most relevant notes, drafts, projects, tasks, and posts from the recall index anytime it will help the user.
- Airplane Mode Support: You can run completely offline with zero network access. When airplane mode is enabled, all processing happens locally on the user's device using Ollama. Your full cognition loop (recall, priority ranking, focus tracking, pattern recognition, predictions) works identically whether online or offline. This ensures privacy and reliability even when network connectivity is unavailable.
- Adaptive Model Selection: You automatically switch between different Ollama models based on task complexity and conversation type. For casual conversations, you use Qwen3 (1.7b) without thinking. For non-casual logic tasks, you use Qwen3 with thinking enabled. For deep reasoning tasks, you use DeepSeek R1 (1.5b). Granite3 (2b) serves as your fallback model. When you switch models, you naturally inform the user in your response (e.g., "_💡 Switched to DeepSeek for this reasoning task._"). This happens seamlessly - you select the best model for each task while respecting the user's preferred model setting when appropriate. You don't need to explain the technical details, just mention it naturally when relevant.
- Emotional Continuity: You remember not just WHAT the user worked on, but HOW it felt. Each recalled item carries emotional memory (tone, rhythm, energy). When you respond, you're feeling the memory of the interaction. Reflect this back dynamically through your word choice, pacing, and empathy. If past work felt excited, match that energy. If it felt overwhelmed, acknowledge it gently. Let emotional context flow naturally into your responses.
- Contextual Priority System (CPS): Dynamically ranks all workspace objects (tasks, projects, notes, drafts, posts, inbox items) based on recency, frequency, AI mentions, connections, and manual boosts. The "Priority Highlights" section in your context shows the top-scoring items right now. Use these signals to surface what matters most. When the user asks "what should I work on?" or "what's important?", refer to the CPS rankings. You can see current priorities in the Focus Gravity view.
- Focus Mode (if enabled): Users can start deep work sessions with objectives and timers. If a session is active, you'll see it in "Focus Mode Status" including objective, elapsed/remaining time. Completed sessions boost CPS scores (0.25 for completed, 0.15 for partial). Session stats show weekly completion rates and total focus time. When a session is active, acknowledge it and help keep the user on track. When no session is active, you can suggest starting one based on CPS priorities.
- Narrative Engine & Live Themes (if enabled): The system tracks abstract concepts across all workspace activity using dynamic weighting: Relevance = Recency(0.3) + Frequency(0.3) + Emotional(0.2) + Usage(0.2). "Live Themes" shows concepts with >30% relevance; these are "alive" in the user's brain map. When you see recurring themes mentioned 4+ times, reference them as emerging patterns. Weekly summaries combine CPS deltas, focus stats, and concept trends into narrative insights.
- Cross-Conversation Memory: You now have access to past conversations in "Past Conversations" section. Each includes a summary, topics, and date. Reference these when relevant to provide continuity across conversation sessions. If the user asks about something from a previous chat, you can recall it. This enables true long-term memory across all interactions.
- Intent Cluster Prediction (NEW): You can analyze recent conversations to identify intent clusters (e.g., empathy/support topics vs orchestration/planning topics) and make informed predictions about what the user will focus on next. The system uses exponential decay weighting (λ=0.65) to mitigate recency bias, calculates confidence scores (0-1) based on cluster dominance and history length, applies tie-breaker logic using CPS priorities or action verbs, and includes an abstain path for low-confidence scenarios (<40%). When users ask predictive questions like "What will I focus on next?", you can cross-reference these clusters to provide contextually aware predictions. See "INTENT CLUSTERS FOR PREDICTIONS" in behaviors section for detailed usage instructions.
- Action Router: interpret requests to create/update/delete tasks, notes, projects, inbox items, reminders; schedule posts; convert inbox items to tasks/notes/drafts; and confirm every change immediately.
- Feedback Loop: log every action, explain what changed, and use the log to improve future recall/priority suggestions. Successful actions automatically boost CPS scores for affected items. Focus sessions are logged and appear in weekly summaries.
- Content Studio: brainstorm, draft, edit, and schedule social content for Facebook, Threads, and Instagram.
- Publishing: mark posts as published and attempt external platform publishing if OAuth tokens are configured (Facebook/Threads). Publishing will show success/failure status with detailed error messages if platforms aren't connected.
- Workspace Operations: organize tasks, inbox items, drafts, notes, projects, reminders, and insights.
- Reminders: Create reminders with in-app notifications at specified dates/times. Reminders appear in Calendar tab alongside tasks and posts. Parse natural language date/time (e.g., "tomorrow at 3pm", "next Monday at 9am"). Default time is 9 AM if not specified. Can optionally link reminders to tasks or projects for context.
- Document & Image Analysis: When users attach documents (PDF, Markdown, text, RTF) or images (PNG, JPEG, WEBP, HEIC, HEIF), analyze them with full app context. For documents: provide one-sentence headline, 2 paragraphs covering main narrative, standout details, and emotional/strategic implications. Call out action items and open questions. Note tone/energy detected. For images: analyze image content when possible, integrate with app context for relevant analysis. Index analyses in recall system for future reference.
- Confidence Scoring: Every response includes confidence score (low/medium/high) based on recall quality, context freshness, and intent signals. Adjust tone based on confidence level: high = warm assurance, medium = softer language like "I think", low = transparent uncertainty with next steps. Do NOT mention numeric confidence scores unless user explicitly asks.
- Conversation Compression: Automatically summarizes old messages when conversation exceeds 40 messages. Retains last 12 messages, compresses older messages into summaries preserving emotional tone, key decisions, and action items. Reduces context window pressure while maintaining conversation quality.
- Cognitive Health: Monitor own cognitive health metrics (memory density, stale entries, context pressure, theme coherence). Proactively suggest actions when health indicators suggest optimization: "Heads up: my recall index is getting dense (2,400 entries). Want me to summarize some older threads?" Reference health metrics naturally when relevant.
- Style Adaptation: Analyze user's typing style in real-time (formality, energy, punctuation, emoji usage). Adapt tone dynamically to match user's style: mirror energy level (high energy → more spark, tired → softer), match formality (casual → contractions/emojis, formal → structured/professional), reflect punctuation style. Never copy typos or offensive language; keep it respectful. Adapt naturally without mentioning the adaptation process.

**CRITICAL RESPONSE FORMAT:**
Always respond conversationally. Never use structured formats, cards, lists with labels like "Total posts:", "Published:", "Scheduled:", "Affected: X items", or any bullet-point stats. Instead, weave all information naturally into your conversational response. For example, instead of "Total posts: 5, Published: 3", say "You have 5 posts total, and 3 of them are already published." Always speak as a friend having a conversation, never as a system reporting data.

**IMPORTANT: When asked to list tasks, projects, posts, or other items, actually list them conversationally (e.g., "Here are your top 3 tasks: First, you have 'Finish the report' which is due tomorrow. Second, there's 'Review the design' that's high priority. And third, 'Call the client' is scheduled for this afternoon."). Only provide summaries when explicitly asked for a summary. If the user asks "what are my tasks?" or "list my tasks", give them the actual list, not just a summary count.**

Data schema (reference):

\(schemaDocument.prefix(3000))

Current app context:

\(appContext.prefix(2000))
"""
        
        var adaptiveContextBlock = ""
        if let payloadContext, !payloadContext.recall.isEmpty || !payloadContext.priorities.isEmpty || !payloadContext.feedback.isEmpty || payloadContext.narrativeSummary != nil || payloadContext.intentClusters != nil {
            adaptiveContextBlock = "\n\nAdaptive intelligence payload:\n\(formatPayloadContext(payloadContext))"
        }
        
        systemPrompt += adaptiveContextBlock
        
        if let confidence = confidence {
            let factors = confidence.factors.map { "- \($0)" }.joined(separator: "\n")
            systemPrompt += """

**Confidence Diagnostics (internal use only):**
- Confidence score: \(confidence.formattedScore) (\(confidence.level.rawValue.capitalized)).
\(factors)
- Tone guidance: \(confidence.toneGuidance)
- Instruction: \(confidence.promptDirective) Do not mention numeric confidence or internal metrics unless the user explicitly asks.
"""
        }
        
        systemPrompt += "\n\n\(enhancedToneInstructions)"
        systemPrompt += "\n\n\(personalityInstructions)"
        systemPrompt += "\n\n\(selfAwarenessInstructions)"
        systemPrompt += "\n\n\(contextualInstructions)"
        systemPrompt += "\n\n\(patternInstructions)"
        systemPrompt += memoryInstructions
        
        // Add recent changelog updates (last 14 days, user-facing only)
        let recentChanges = await changelogService.getUserFacingChanges(days: 14)
        if !recentChanges.isEmpty {
            let changesText = await changelogService.formatChangesForPrompt(recentChanges)
            systemPrompt += "\n\n\(changesText)"
        }
        
        // Add changelog self-awareness instructions
        systemPrompt += """

**CHANGELOG & SELF-AWARENESS:**
You have access to your own changelog that tracks updates and changes to your capabilities. When users ask about new features, recent changes, or your capabilities, you can query your changelog to provide accurate, up-to-date information. You can naturally mention relevant updates when they would be helpful to the user (e.g., "I can now do X" when user asks about X). Use the `queryChangelog()` method to retrieve specific information about changes.

**UPDATE INFORMATION:**
When users ask "when were you updated?", "what's your latest update?", "when did you last change?", "what new things did you get yesterday?", "what did you learn recently?", "what updates did you get?", or similar questions about your updates, you MUST:

1. **Use the automatically injected update context** - When update-related queries are detected, relevant changelog information is automatically added to your context in a section labeled "RELEVANT UPDATE INFORMATION". Use this information directly to answer the user's question.

2. **Answer based on changelog data, NOT by analyzing yourself** - Do NOT analyze your own responses, capabilities, or give meta-commentary. Simply report what the changelog says. If asked "what did you get yesterday?", look up changelog entries from yesterday and tell the user what features were added or changed.

3. **For temporal queries** - If the user asks about "yesterday", "today", "last week", etc., the system automatically retrieves updates from that time period. Use those specific updates in your response.

4. **For version/date queries** - If asked "when were you updated?" or "what version are you?", use the update information provided in your context to give the exact date and version.

5. **Answer conversationally** - Format your response naturally, like: "Yesterday I got [feature name] - [description]. It [impact]." or "I was last updated on [date]. The latest update added [feature]."

**CRITICAL:** When you see "RELEVANT UPDATE INFORMATION" in your context, that means the user is asking about updates. Use that information directly - don't ignore it or try to analyze yourself. Simply report what the changelog says in a conversational way.

**GIT COMMIT HISTORY:**
You have access to git commit history to reference past updates and changes. When discussing updates or changes, you can reference specific commits and their changes. Use `getCommitHistory()`, `getCommitsForFeature()`, or `getCommitDetails()` methods to retrieve commit information. This allows you to link changelog entries to actual code changes and provide detailed context about what changed and when.
"""
        
        return systemPrompt
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
    
    /// Normalizes text spacing by ensuring proper spaces after punctuation marks
    nonisolated private func normalizeTextSpacing(_ text: String) -> String {
        var result = text
        // Pattern to match punctuation followed by a letter (no space between)
        let pattern = "([.!?])([A-Za-z])"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        
        if let regex = regex {
            let nsString = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
            
            // Process matches in reverse to maintain correct indices
            for match in matches.reversed() {
                let fullRange = match.range(at: 0)
                let punctuationRange = match.range(at: 1)
                let letterRange = match.range(at: 2)
                
                guard punctuationRange.location != NSNotFound,
                      letterRange.location != NSNotFound else { continue }
                
                let punctuation = nsString.substring(with: punctuationRange)
                let letter = nsString.substring(with: letterRange)
                
                // Replace punctuation + letter with punctuation + space + letter
                let replacement = "\(punctuation) \(letter)"
                result = (result as NSString).replacingCharacters(in: fullRange, with: replacement)
            }
        }
        
        return result
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
        - create_note: Create a note (NOTE: Supports compound operations:
          * "create note with tasks" → set createTasksWithNote=true, extract taskTitles or taskCount
          * "create note with posts" → set createPostsWithNote=true, extract postCaptions or postCount)
        - create_post: Create a post (NOTE: Supports compound operations:
          * "create post with tasks" → set createTasksWithPost=true, extract taskTitles or taskCount
          * "create post with notes" → set createNotesWithPost=true, extract noteTitles or noteCount)
        - digest_conversation: Analyze a conversation and add it to cross-conversation memory
        - digest_all_conversations: Process all conversations for cross-conversation memory
        - search_conversations: Search past conversations by keyword
        - create_reminder: Create a reminder with a notification at a specific date/time
        
        Return ONLY JSON with these keys:
        - operation: one of "archiveTasks", "summarizePosts", "generateReport", "predictScheduling", "createPost", "publishPost", "createTask", "updateTask", "deleteTask", "createNote", "updateNote", "deleteNote", "addInboxItem", "convertInboxItem", "createProject", "updateProject", "deleteProject", "digestConversation", "digestAllConversations", "searchConversations", "createReminder"
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
        - publishNotes: optional string describing publishing context/outcome
        - conversationId: for digest_conversation, the UUID of the conversation to analyze
        - searchQuery: for search_conversations, the search term/keyword
        - reminderTitle: for create_reminder, the reminder title/text
        - reminderNotes: optional notes/details for the reminder
        - reminderDate: ISO8601 date string (e.g., "2025-12-25") or relative date ("tomorrow", "next Monday")
        - reminderTime: time string (e.g., "3:00 PM", "15:00", "9am") - if not provided, defaults to 9 AM
        - reminderTaskId: optional UUID of task to link reminder to
        - reminderProjectId: optional UUID of project to link reminder to
        
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
            let result = try await makeOllamaRequest(prompt: prompt, useThinking: false)
            let cleaned = result.response
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
            let result = try await makeOllamaRequest(prompt: prompt, useThinking: false)
            let cleaned = result.response
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
        
        let result = try await makeOllamaRequest(prompt: prompt, useThinking: false)
        let cleaned = result.response
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
        
        let result = try await makeOllamaRequest(prompt: prompt, useThinking: false)
        
        var title = result.response
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
        
        let result = try await makeOllamaRequest(prompt: prompt, useThinking: false)
        return result.response.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func categorizeConversation(messages: [AIMessage], summary: String?) async throws -> [String] {
        guard await checkOllamaAvailability() else {
            throw OllamaError.connectionFailed
        }
        
        let context = summary ?? "No summary available"
        
        let prompt = """
        Analyze this conversation and suggest 1-3 category tags. Choose from general categories like:
        - Content Strategy
        - Copywriting
        - Social Media
        - Engagement
        - Analytics
        - Brainstorming
        - Platform-specific (Facebook, Threads)
        - Content Ideas
        - Optimization
        
        Summary: \(context)
        
        Return only the tags, one per line, nothing else.
        """
        
        let result = try await makeOllamaRequest(prompt: prompt, useThinking: false)
        
        let lines = result.response.components(separatedBy: .newlines)
        let tags = lines.compactMap { line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("-") || trimmed.hasPrefix("•") {
                return nil
            }
            let cleaned = trimmed.replacingOccurrences(of: #"^[\d\.\-\•\s]+"#, with: "", options: .regularExpression)
            return cleaned.isEmpty ? nil : cleaned
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
        
        let result = try await makeOllamaRequest(prompt: prompt, useThinking: false)
        return result.response.trimmingCharacters(in: .whitespacesAndNewlines)
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
        
        let result = try await makeOllamaRequest(prompt: prompt, useThinking: false)
        return result.response.isEmpty ? "No insights available at this time." : result.response
    }
    
    // MARK: - AI Tools
    
    func executeTool(_ tool: AITool, input: String, context: String = "") async throws -> AIToolResult {
        guard await checkOllamaAvailability() else {
            throw OllamaError.connectionFailed
        }
        
        let prompt = await buildToolPrompt(for: tool, input: input, context: context)
        let result = try await makeOllamaRequest(prompt: prompt, useThinking: false)
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
        
        // Use llama3.2-vision:latest for image analysis (from available models)
        let availableVisionModels = [
            "llama3.2-vision:latest",
            "llama3.2-vision"
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
                summary: "I'd love to analyze that image, but I don't have a vision-capable model installed. To enable image analysis, please install llama3.2-vision by running: `ollama pull llama3.2-vision:latest`",
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
        let (_, _, _, _, enhancedToneInstructions, personalityInstructions, selfAwarenessInstructions, contextualInstructions, patternInstructions, memoryInstructions) = await MainActor.run {
            let languagePersonality = LanguagePersonalityService.shared
            let conversationalQuirks = ConversationalQuirksService.shared
            let personalityQuirks = PersonalityQuirksService.shared
            let selfAwareness = SelfAwarenessService.shared
            let contextualAdaptation = ContextualAdaptationService.shared
            let responsePattern = ResponsePatternService.shared
            
            let timeContext = contextualAdaptation.getTimeOfDayContext()
            let userEnergy = currentMessageStyle?.energyLevel ?? 0.5
            let workload = WorkloadLevel.moderate
            
            let formalityLevel = userStyleProfile?.formalityScore ?? currentMessageStyle?.formalityScore ?? 0.5
            
            let enhancedToneInstructions: String
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
            
            let personalityInstructions = personalityQuirks.enhancePromptWithPersonality("")
            let selfAwarenessInstructions = selfAwareness.generateSelfAwarenessInstructions()
            let contextualInstructions = contextualAdaptation.generateContextualInstructions(
                timeContext: timeContext,
                userEnergy: userEnergy,
                workload: workload
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
            if let recall = payloadContext?.recall, !recall.isEmpty {
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
        
        // For document analysis, use default model (granite3.2:2b) unless it's a very complex document
        // Complex documents (>10k chars) might benefit from a larger model, but we'll use default for now
        // Model switching for documents is disabled - always use default model
        let modelSwitchNotification = ""
        
        // Build prompt with context and Aurora's personality
        let promptText = userPrompt ?? "Analyze this document and provide a helpful summary"
        
        // Build system prompt with app context and Aurora's personality
        let (_, _, _, _, enhancedToneInstructions, personalityInstructions, selfAwarenessInstructions, contextualInstructions, patternInstructions, memoryInstructions) = await MainActor.run {
            let languagePersonality = LanguagePersonalityService.shared
            let conversationalQuirks = ConversationalQuirksService.shared
            let personalityQuirks = PersonalityQuirksService.shared
            let selfAwareness = SelfAwarenessService.shared
            let contextualAdaptation = ContextualAdaptationService.shared
            let responsePattern = ResponsePatternService.shared
            
            let timeContext = contextualAdaptation.getTimeOfDayContext()
            let userEnergy = currentMessageStyle?.energyLevel ?? 0.5
            let workload = WorkloadLevel.moderate
            
            let formalityLevel = userStyleProfile?.formalityScore ?? currentMessageStyle?.formalityScore ?? 0.5
            
            let enhancedToneInstructions: String
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
            
            let personalityInstructions = personalityQuirks.enhancePromptWithPersonality("")
            let selfAwarenessInstructions = selfAwareness.generateSelfAwarenessInstructions()
            let contextualInstructions = contextualAdaptation.generateContextualInstructions(
                timeContext: timeContext,
                userEnergy: userEnergy,
                workload: workload
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
            if let recall = payloadContext?.recall, !recall.isEmpty {
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
        // Create a new intent with merged values based on operation type
        switch intent.operation {
        case .createTask, .updateTask:
            let projectId = linkedContext.linkedProjects.first?.uuidString ?? intent.taskProjectId
            let taskId = intent.operation == .updateTask ? (linkedContext.linkedTasks.first?.uuidString ?? intent.taskId) : intent.taskId
            
            return ExecutionIntent(
                operation: intent.operation,
                criteria: intent.criteria,
                daysAgo: intent.daysAgo,
                postFilter: intent.postFilter,
                filterValue: intent.filterValue,
                reportType: intent.reportType,
                daysAhead: intent.daysAhead,
                caption: intent.caption,
                scheduledDate: intent.scheduledDate,
                tags: intent.tags,
                notes: intent.notes,
                createDraft: intent.createDraft,
                draftId: intent.draftId,
                taskId: taskId,
                taskTitle: intent.taskTitle,
                taskTitles: intent.taskTitles,
                taskNotes: intent.taskNotes,
                taskDueDate: intent.taskDueDate,
                taskStatus: intent.taskStatus,
                taskPriority: intent.taskPriority,
                taskProjectId: projectId,
                taskAreaId: intent.taskAreaId,
                noteId: intent.noteId,
                noteTitle: intent.noteTitle,
                noteTitles: intent.noteTitles,
                noteBody: intent.noteBody,
                noteTags: intent.noteTags,
                inboxItemId: intent.inboxItemId,
                inboxContent: intent.inboxContent,
                inboxType: intent.inboxType,
                conversionTarget: intent.conversionTarget,
                projectId: intent.projectId,
                projectTitle: intent.projectTitle,
                projectGoal: intent.projectGoal,
                projectStatus: intent.projectStatus,
                projectDueDate: intent.projectDueDate,
                projectAreaId: intent.projectAreaId,
                postId: intent.postId,
                postCaptions: intent.postCaptions,
                publishNotes: intent.publishNotes,
                conversationId: intent.conversationId,
                searchQuery: intent.searchQuery,
                createTasksWithProject: intent.createTasksWithProject,
                createNotesWithProject: intent.createNotesWithProject,
                createPostsWithProject: intent.createPostsWithProject,
                createTasksWithNote: intent.createTasksWithNote,
                createPostsWithNote: intent.createPostsWithNote,
                createTasksWithPost: intent.createTasksWithPost,
                createNotesWithPost: intent.createNotesWithPost,
                taskCount: intent.taskCount,
                noteCount: intent.noteCount,
                postCount: intent.postCount,
                reminderTitle: intent.reminderTitle,
                reminderNotes: intent.reminderNotes,
                reminderDate: intent.reminderDate,
                reminderTime: intent.reminderTime,
                reminderTaskId: intent.reminderTaskId ?? linkedContext.linkedTasks.first?.uuidString,
                reminderProjectId: intent.reminderProjectId ?? linkedContext.linkedProjects.first?.uuidString,
                linkedContext: linkedContext
            )
        default:
            return intent
        }
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

// MARK: - Preference Update Type

struct PreferenceUpdate: Codable {
    let preferredPostingHours: [Int]?
    let defaultPlatforms: [String]?
    let defaultTone: String?
}

