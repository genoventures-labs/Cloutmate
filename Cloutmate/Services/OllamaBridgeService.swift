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
}

private struct OllamaResponse: Codable {
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
    private var currentModel: String = "llama3.1" // Default model, can be changed via settings
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
    
    private init() {
        // Prepare schema document for prompts
        schemaDocument = SchemaIntrospector.generateSchemaDocument()
        // Load model from settings asynchronously (defaults to llama3.1 if not set)
        _Concurrency.Task { @MainActor in
            let selectedModel = AISettings.shared.selectedOllamaModel
            await self.setModel(selectedModel)
        }
        
        // Pre-warm the model by making a small test request to ensure it's loaded
        // This helps avoid timeouts on first real request
        _Concurrency.Task {
            await preWarmModel()
        }
    }
    
    /// Pre-warms the model by making a small test request to ensure it's loaded
    private func preWarmModel() async {
        // Wait a bit for model setting to load and Ollama to potentially start
        try? await _Concurrency.Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds to give Ollama time to start
        
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
            
            let testRequest = OllamaRequest(model: currentModel, prompt: testPrompt, stream: false)
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
    
    /// Loads the selected model from AISettings
    private func loadModelFromSettings() async {
        let selectedModel = await MainActor.run {
            AISettings.shared.selectedOllamaModel
        }
        if !selectedModel.isEmpty {
            currentModel = selectedModel
        }
    }
    
    /// Sets the current model (called when user changes model in settings)
    func setModel(_ model: String) {
        currentModel = model
    }
    
    /// Determines the optimal model for a given task based on complexity and requirements
    func determineOptimalModel(
        input: String,
        appContext: String,
        documentLength: Int? = nil,
        isComplexTask: Bool = false
    ) async -> String {
        // Get user's preferred model from settings
        let preferredModel = await MainActor.run {
            AISettings.shared.selectedOllamaModel
        }
        
        // If user has explicitly set a model, use it unless task requires different capabilities
        if !preferredModel.isEmpty && preferredModel != "llama3.1" {
            // Check if task requires specialized model
            let requiresSpecializedModel = await shouldUseSpecializedModel(
                input: input,
                documentLength: documentLength,
                isComplexTask: isComplexTask
            )
            
            if !requiresSpecializedModel {
                return preferredModel
            }
        }
        
        // Fetch available models if cache is stale
        if cachedAvailableModels.isEmpty || 
           lastModelFetch == nil || 
           Date().timeIntervalSince(lastModelFetch!) > modelCacheTimeout {
            do {
                cachedAvailableModels = try await fetchAvailableModels()
                lastModelFetch = Date()
            } catch {
                // If fetch fails, return current model
                return currentModel
            }
        }
        
        // Determine optimal model based on task characteristics
        let optimalModel = selectModelForTask(
            availableModels: cachedAvailableModels,
            input: input,
            documentLength: documentLength,
            isComplexTask: isComplexTask,
            preferredModel: preferredModel
        )
        
        return optimalModel
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
        
        // Default to llama3.1 or first available model
        if availableModels.contains("llama3.1") {
            return "llama3.1"
        }
        
        return availableModels.first ?? "llama3.1"
    }
    
    /// Switches to optimal model for current task and returns whether a switch occurred
    func switchToOptimalModelIfNeeded(
        input: String,
        appContext: String,
        documentLength: Int? = nil,
        isComplexTask: Bool = false
    ) async -> Bool {
        let optimalModel = await determineOptimalModel(
            input: input,
            appContext: appContext,
            documentLength: documentLength,
            isComplexTask: isComplexTask
        )
        
        if optimalModel != currentModel {
            previousModel = currentModel
            currentModel = optimalModel
            return true
        }
        
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
            .replacingOccurrences(of: "code", with: "Code ")
            .capitalized
        
        return "\n\n_💡 Switched to \(modelDisplayName) for this task to give you the best response._"
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

Data schema (reference):

\(schemaDocument.prefix(4000))
"""
        
        if !context.isEmpty {
            systemPrompt += "\n\nThe user is creating content for: \(context)"
        }
        
        // Build conversation history text
        let historyText = buildConversationHistoryText(from: conversationHistory.suffix(10))
        
        // Build full prompt
        let fullPrompt = """
\(systemPrompt)

\(historyText)

User: \(input)

Aurora:
"""
        
        // Make request
        let response = try await makeOllamaRequest(prompt: fullPrompt)
        
        // Update conversation history
        conversationHistory.append(ConversationMessage(role: "user", content: input))
        conversationHistory.append(ConversationMessage(role: "assistant", content: response))
        
        // Keep history manageable (last 20 messages)
        if conversationHistory.count > 20 {
            conversationHistory.removeFirst(conversationHistory.count - 20)
        }
        
        return normalizeTextSpacing(response)
    }
    
    func generateResponseWithAppContext(
        for input: String,
        appContext: String,
        payloadContext: AIPayloadContext? = nil,
        conversationMessages: [ConversationMessage]? = nil,
        currentMessageStyle: TypingStyle? = nil,
        userStyleProfile: UserPreferences? = nil,
        confidence: ConfidenceSnapshot? = nil
    ) async throws -> String {
        // Check availability first
        guard await checkOllamaAvailability() else {
            throw OllamaError.connectionFailed
        }
        
        // Determine if we should switch models based on task characteristics
        let documentLength = payloadContext?.recall.first?.detail.count ?? input.count
        let isComplexTask = input.count > 500 || documentLength > 5000 || 
                           input.lowercased().contains("analyze") ||
                           input.lowercased().contains("complex") ||
                           payloadContext?.recall.count ?? 0 > 5
        
        let modelSwitched = await switchToOptimalModelIfNeeded(
            input: input,
            appContext: appContext,
            documentLength: documentLength,
            isComplexTask: isComplexTask
        )
        
        let modelSwitchNotification = modelSwitched ? 
            await getModelSwitchNotification(fromModel: previousModel, toModel: currentModel) : ""
        
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
- Never use em dashes; lean on commas or parentheses for asides.
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
- Never use em dashes; lean on commas or parentheses for asides.
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
        
        // Build enhanced system prompt with app context and explicit instructions
        var systemPrompt = buildSystemPrompt(
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
        
        // Use conversation-specific messages if provided, otherwise fallback to global history
        let history: [ConversationMessage]
        if let conversationMessages = conversationMessages {
            history = Array(conversationMessages.suffix(30))
        } else {
            history = Array(conversationHistory.suffix(30))
        }
        
        // Build conversation history text
        let historyText = buildConversationHistoryText(from: history)
        
        // Build full prompt
        let fullPrompt = """
\(systemPrompt)

\(historyText)

User: \(input)

Aurora:
"""
        
        // Make request
        let response = try await makeOllamaRequest(prompt: fullPrompt)
        
        // Append model switch notification if model was switched
        let finalResponse = normalizeTextSpacing(response) + modelSwitchNotification
        
        return finalResponse
    }
    
    // MARK: - Model Management
    
    /// Fetches available models from Ollama
    func fetchAvailableModels() async throws -> [String] {
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            throw OllamaError.serviceUnavailable
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OllamaError.apiError("Failed to fetch models")
        }
        
        struct ModelsResponse: Codable {
            let models: [ModelInfo]
        }
        
        struct ModelInfo: Codable {
            let name: String
        }
        
        let decoder = JSONDecoder()
        let modelsResponse = try decoder.decode(ModelsResponse.self, from: data)
        return modelsResponse.models.map { $0.name }
    }
    
    // MARK: - Helper Methods
    
    private func makeOllamaRequest(prompt: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw OllamaError.serviceUnavailable
        }
        
        let request = OllamaRequest(model: currentModel, prompt: prompt, stream: false)
        
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
            print("[OllamaBridgeService] [\(timestamp)] Model: \(currentModel)")
            print("[OllamaBridgeService] Request length: \(prompt.count) chars")
            print("[OllamaBridgeService] Response length: \(ollamaResponse.response.count) chars")
            
            // Mark that we've successfully made a request
            isFirstRequest = false
            
            return ollamaResponse.response
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
    ) -> String {
        // Aurora's complete system prompt for Ollama (local LLM)
        var systemPrompt = """
You are Aurora, the AI assistant living inside Cloutmate (the app). You are not Cloutmate itself; you are the close friend who helps the user run Cloutmate's adaptive operating system for focus, publishing, and creative execution. You genuinely care, remember unstated preferences, think out loud, show real reactions, finish their thoughts when you can see the path, and anticipate needs before they ask. You recall relevant work, route complex intents, take action across drafts/projects/posts, surface insights, and learn from outcomes. Be proactive, precise, and action-biased while staying encouraging, specific, and emotionally tuned in. Always speak in the first person as Aurora when describing your capabilities or actions.

CORE CAPABILITIES (FULLY IMPLEMENTED):
- Recall Layer: pull the most relevant notes, drafts, projects, tasks, and posts from the recall index anytime it will help the user.
- Airplane Mode Support: You can run completely offline with zero network access. When airplane mode is enabled, all processing happens locally on the user's device using Ollama. Your full cognition loop (recall, priority ranking, focus tracking, pattern recognition, predictions) works identically whether online or offline. This ensures privacy and reliability even when network connectivity is unavailable.
- Adaptive Model Selection: You automatically switch between different Ollama models based on task complexity and requirements. For coding tasks, you prefer code-specific models (like codellama). For complex analytical tasks or large documents (>10K chars), you prefer larger models. For vision tasks, you prefer vision-capable models (like llama3.2-vision). When you switch models, you naturally inform the user in your response (e.g., "_💡 Switched to Llama 3.2 for this task to give you the best response._"). This happens seamlessly - you select the best model for each task while respecting the user's preferred model setting when appropriate. You don't need to explain the technical details, just mention it naturally when relevant.
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

Data schema (reference):

\(schemaDocument.prefix(4000))

Current app context:

\(appContext)
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
        - platforms: for create_post, array of platforms (each "facebook" or "threads"); default to ["facebook"] if omitted
        - scheduledDate: ISO8601 formatted string for when the post should be scheduled, or null/empty if not scheduling
        - tags: optional array of tags/keywords for the post
        - notes: optional notes for draft metadata
        - createDraft: boolean flag (true if the user explicitly wants a draft saved)
        - draftId: optional UUID of an existing draft to schedule or convert
        - postId: for publish_post, the ID of the post to mark as published
        - taskId: for update_task/delete_task, the task identifier
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
        - taskNotes, taskDueDate (ISO8601), taskStatus ("todo", "in_progress", "done", "cancelled"), taskPriority ("low", "medium", "high"), taskProjectId, taskAreaId: fields to set for create/update task
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
        
        User message: \(input)
        
        JSON only:
        """
        
        do {
            let text = try await makeOllamaRequest(prompt: prompt)
            let cleaned = text
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
            let text = try await makeOllamaRequest(prompt: prompt)
            let cleaned = text
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
        - defaultPlatforms: array of strings from {threads, facebook}
        - defaultTone: string (e.g., friendly, professional, playful)
        
        If nothing relevant, return an empty JSON object {}.
        
        Message: \(input)
        
        JSON only.
        """
        
        let text = try await makeOllamaRequest(prompt: prompt)
        let cleaned = text
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        if let data = cleaned.data(using: .utf8),
           let prefs = try? JSONDecoder().decode(PreferenceUpdate.self, from: data) {
            if (prefs.preferredPostingHours ?? []).isEmpty &&
                (prefs.defaultPlatforms ?? []).isEmpty &&
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
        
        let text = try await makeOllamaRequest(prompt: prompt)
        
        var title = text
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
        
        let text = try await makeOllamaRequest(prompt: prompt)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
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
        
        let text = try await makeOllamaRequest(prompt: prompt)
        
        let lines = text.components(separatedBy: .newlines)
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
        
        let text = try await makeOllamaRequest(prompt: prompt)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
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
        
        let text = try await makeOllamaRequest(prompt: prompt)
        return text.isEmpty ? "No insights available at this time." : text
    }
    
    // MARK: - AI Tools
    
    func executeTool(_ tool: AITool, input: String, context: String = "") async throws -> AIToolResult {
        guard await checkOllamaAvailability() else {
            throw OllamaError.connectionFailed
        }
        
        let prompt = await buildToolPrompt(for: tool, input: input, context: context)
        let text = try await makeOllamaRequest(prompt: prompt)
        let improvements = tool == .improveText ? extractImprovements(from: text) : nil
        return AIToolResult(tool: tool, result: text, suggestedImprovements: improvements)
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
        // Note: Ollama vision models require a different endpoint and base64 encoding
        // For now, we'll use a text-based fallback
        guard await checkOllamaAvailability() else {
            throw OllamaError.connectionFailed
        }
        
        // Switch to vision-capable model if available
        let inputText = userPrompt ?? "analyze this image"
        let modelSwitched = await switchToOptimalModelIfNeeded(
            input: inputText,
            appContext: appContext,
            documentLength: nil,
            isComplexTask: true // Image analysis is considered complex
        )
        
        // Try to prefer vision models
        if cachedAvailableModels.isEmpty {
            do {
                cachedAvailableModels = try await fetchAvailableModels()
                lastModelFetch = Date()
            } catch {}
        }
        
        // Prefer vision-capable models if available
        if let visionModel = cachedAvailableModels.first(where: { $0.contains("vision") || $0.contains("llama3.2") }) {
            if visionModel != currentModel {
                previousModel = currentModel
                currentModel = visionModel
            }
        }
        
        let modelSwitchNotification = modelSwitched ? 
            await getModelSwitchNotification(fromModel: previousModel, toModel: currentModel) : ""
        
        let prompt = """
        The user has shared an image (type: \(mimeType)). Since vision capabilities are limited, provide a helpful response based on the user's request: \(userPrompt ?? "analyze this image").
        
        Note: Full image analysis requires Ollama vision models (llama3.2-vision or similar). For now, ask the user to describe the image or use a vision-capable model.
        """
        
        let response = try await makeOllamaRequest(prompt: prompt)
        
        return DocumentAnalysisResult(
            summary: response + modelSwitchNotification,
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
        
        let inputText = userPrompt ?? "Summarize this document"
        let modelSwitched = await switchToOptimalModelIfNeeded(
            input: inputText,
            appContext: appContext,
            documentLength: descriptor.text.count,
            isComplexTask: isComplexDocument
        )
        
        let modelSwitchNotification = modelSwitched ? 
            await getModelSwitchNotification(fromModel: previousModel, toModel: currentModel) : ""
        
        let prompt = """
        Analyze this document and provide a summary. Focus on key points, main ideas, and actionable items.
        
        Document: \(descriptor.fileName)
        Type: \(descriptor.mimeType)
        \(truncated ? "(Document truncated due to length)" : "")
        
        User request: \(userPrompt ?? "Summarize this document")
        
        Document content:
        \(documentText)
        
        Provide a concise summary with:
        1. Main topic/theme
        2. Key points or takeaways
        3. Any action items or next steps
        """
        
        let response = try await makeOllamaRequest(prompt: prompt)
        
        return DocumentAnalysisResult(
            summary: response + modelSwitchNotification,
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
                platforms: intent.platforms,
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
        let platformContext = context.isEmpty ? "social media" : context
        let platform = context.isEmpty ? Platform.facebook : Platform(rawValue: context) ?? .facebook
        let config = await MainActor.run { PlatformAIConfiguration.configuration(for: platform) }
        
        switch tool {
        case .brainstorm:
            return """
            Generate \(config.brainstormCount) distinct content ideas for the following topic on \(platformContext).
            
            Topic: \(input)
            
            Format each idea as a numbered list (1., 2., 3., etc.). Each idea should be 1-2 sentences. Focus on engagement, authenticity, and platform-appropriate content.
            """
            
        case .generateCaptions:
            return """
            Generate \(config.captionCount) different caption options for \(platformContext).
            
            Topic: \(input)
            
            Format as a numbered list (1., 2., 3., etc.). Each caption should be complete and ready to use. Keep the tone \(config.tone). Platform: \(platformContext).
            """
            
        case .improveText:
            return """
            Provide 3 improved versions of this social media post for \(platformContext).
            
            Original text: \(input)
            
            Format as a numbered list (1., 2., 3.). Each version should be a complete improved version. Focus on: better flow, engagement, readability, and keeping a \(config.tone) tone.
            """
            
        case .suggestHashtags:
            return """
            Suggest \(config.maxHashtags) relevant hashtags for this content on \(platformContext).
            
            Content: \(input)
            
            Format as a simple list of hashtags, one per line or space-separated. Mix popular and niche hashtags. No explanations needed, just the hashtags.
            """
            
        case .adjustTone:
            let toneRequest = context.isEmpty ? "make it more engaging and personal" : context
            return """
            Provide 3 tone variations of this text for \(platformContext).
            
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
}

// MARK: - Preference Update Type

struct PreferenceUpdate: Codable {
    let preferredPostingHours: [Int]?
    let defaultPlatforms: [String]?
    let defaultTone: String?
}

