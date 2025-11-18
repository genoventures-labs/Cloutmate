//
//  HybridBridgeService.swift
//  FocusOS
//
//  Unified relay managing both local (Ollama) and cloud routing
//

import Foundation
import SwiftData
import FocusOSShared

// MARK: - Hybrid Bridge Service

actor HybridBridgeService {
    static let shared = HybridBridgeService()
    
    private let localBaseURL = "http://localhost:11434"
    private let cloudBaseURL = "https://api.ollama.cloud/v1"
    
    private var consecutiveTimeouts: [String: Int] = [:] // Track timeouts per model
    private var healthCheckStatus: HealthCheckStatus = .unknown
    private var lastHealthCheck: Date?
    private let healthCheckCacheTimeout: TimeInterval = 300 // 5 minutes
    
    enum HealthCheckStatus {
        case unknown
        case healthy(local: Bool, cloud: Bool)
        case unhealthy(local: Bool, cloud: Bool)
    }
    
    private init() {}
    
    // MARK: - Model Listing
    
    /// Fetch available models from Ollama Cloud API
    func fetchAvailableCloudModels(apiKey: String) async throws -> [String] {
        guard let url = URL(string: "\(cloudBaseURL)/models") else {
            throw HybridBridgeError.invalidURL
        }
        
        struct ModelsResponse: Codable {
            let data: [ModelInfo]?
            let models: [ModelInfo]?
        }
        
        struct ModelInfo: Codable {
            let id: String
            let name: String?
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HybridBridgeError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw HybridBridgeError.authenticationFailed
        }
        
        guard httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            throw HybridBridgeError.apiError("HTTP \(httpResponse.statusCode): \(responseBody)")
        }
        
        let decoder = JSONDecoder()
        let modelsResponse = try decoder.decode(ModelsResponse.self, from: data)
        
        let modelList = modelsResponse.data ?? modelsResponse.models ?? []
        return modelList.compactMap { $0.name ?? $0.id }
    }
    
    // MARK: - Health Check
    
    /// Performs health check on both local Ollama and cloud endpoints
    func performHealthCheck(apiKey: String?) async -> HealthCheckStatus {
        // Check cache first
        if let lastCheck = lastHealthCheck,
           Date().timeIntervalSince(lastCheck) < healthCheckCacheTimeout,
           case .healthy = healthCheckStatus {
            return healthCheckStatus
        }
        
        let localAvailable = await checkLocalOllama()
        let cloudAvailable = await checkCloudOllama(apiKey: apiKey)
        
        let status: HealthCheckStatus
        if localAvailable || cloudAvailable {
            status = .healthy(local: localAvailable, cloud: cloudAvailable)
        } else {
            status = .unhealthy(local: localAvailable, cloud: cloudAvailable)
        }
        
        healthCheckStatus = status
        lastHealthCheck = Date()
        
        return status
    }
    
    private func checkLocalOllama() async -> Bool {
        guard let url = URL(string: "\(localBaseURL)/api/tags") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 3.0
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    private func checkCloudOllama(apiKey: String?) async -> Bool {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            return false
        }
        
        guard let url = URL(string: "\(cloudBaseURL)/api/tags") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 5.0
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    // MARK: - Core Generation Methods
    
    func generateResponse(
        for input: String,
        context: String = "",
        intentCluster: String? = nil,
        confidence: Double = 0.7,
        preferredModel: String? = nil,
        apiKey: String? = nil,
        useHybridBridge: Bool = true,
        latencyThreshold: TimeInterval = 6.0,
        modelContext: ModelContext
    ) async throws -> String {
        // If hybrid bridge disabled, fallback to local Ollama
        if !useHybridBridge {
            return try await generateLocalResponse(for: input, context: context)
        }
        
        // Check if we should use cloud or local
        let shouldUseCloud = await shouldUseCloud(
            apiKey: apiKey,
            intentCluster: intentCluster
        )
        
        if shouldUseCloud, let apiKey = apiKey, !apiKey.isEmpty {
            // Try cloud first
            do {
                return try await generateCloudResponse(
                    for: input,
                    context: context,
                    intentCluster: intentCluster,
                    confidence: confidence,
                    preferredModel: preferredModel,
                    apiKey: apiKey,
                    latencyThreshold: latencyThreshold,
                    modelContext: modelContext
                )
            } catch {
                // Fallback to local on cloud failure
                return try await generateLocalResponse(for: input, context: context)
            }
        } else {
            // Use local Ollama
            return try await generateLocalResponse(for: input, context: context)
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
        apiKey: String? = nil,
        useHybridBridge: Bool = true,
        latencyThreshold: TimeInterval = 6.0,
        modelContext: ModelContext
    ) async throws -> (response: String, thinking: String?, modelUsed: String) {
        // Check for research mode - only use cloud models (DeepSeek, OpenAI-OSS) when research mode is active
        let isResearchMode = payloadContext?.metadata["isResearchMode"] as? Bool ?? false ||
                            input.lowercased().hasPrefix("/research") ||
                            input.lowercased().contains("research mode")
        
        // If research mode is active, try cloud models first
        if isResearchMode, let apiKey = apiKey, !apiKey.isEmpty {
            // Research mode: Use cloud models (DeepSeek-R1, OpenAI-OSS)
            let researchModels = ModelTierMap.researchModels()
            let selectedModel = researchModels.first ?? "deepseek-r1:1.5b"
            
            do {
                // Try cloud model for research
                let result = try await generateCloudResponseWithAppContext(
                    for: input,
                    appContext: appContext,
                    payloadContext: payloadContext,
                    conversationMessages: conversationMessages,
                    currentMessageStyle: currentMessageStyle,
                    userStyleProfile: userStyleProfile,
                    confidence: confidence,
                    intentCluster: payloadContext?.intentClusters?.primaryCluster,
                    confidenceScore: payloadContext?.intentClusters?.confidence ?? confidence?.score ?? 0.7,
                    preferredModel: selectedModel,
                    apiKey: apiKey,
                    latencyThreshold: latencyThreshold,
                    modelContext: modelContext
                )
                return (result, nil, ModelTierMap.displayName(for: selectedModel))
            } catch {
                // Fallback to local Ollama if cloud fails
                // Continue to local routing below
            }
        }
        
        // Use local Ollama routing with ModelRoutingEngine (default behavior)
        let intentCluster = payloadContext?.intentClusters?.primaryCluster
        let confidenceScore = payloadContext?.intentClusters?.confidence ?? confidence?.score ?? 0.7
        let messageLength = input.count
        
        let routingDecision = await ModelRoutingEngine.shared.selectModel(
            input: input,
            intentCluster: intentCluster,
            confidence: confidenceScore,
            messageLength: messageLength,
            userStyle: currentMessageStyle,
            conversationId: nil,
            isResearchMode: false // Force false for regular routing
        )
        
        // Use OllamaBridgeService with the selected model and thinking setting
        let result = try await OllamaBridgeService.shared.generateResponseWithAppContext(
            for: input,
            appContext: appContext,
            payloadContext: payloadContext,
            conversationMessages: conversationMessages,
            currentMessageStyle: currentMessageStyle,
            userStyleProfile: userStyleProfile,
            confidence: confidence,
            useThinking: routingDecision.useThinking,
            model: routingDecision.model,
            initialCasualConversation: routingDecision.isCasual
        )
        
        // Record model usage for cooldown/stickiness
        await ModelRoutingEngine.shared.recordModelUsage(routingDecision.model)
        
        return result
    }
    
    // MARK: - Private Methods
    
    private func shouldUseCloud(apiKey: String?, intentCluster: String?) -> Bool {
        // Check if API key is available
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            return false
        }
        
        // Check airplane mode
        let airplaneMode = UserDefaults.standard.bool(forKey: "com.kosmicapps.focusos.airplaneMode")
        if airplaneMode {
            return false
        }
        
        // Check network availability (basic check)
        // More thorough check would use NWPathMonitor, but for now we'll try and catch errors
        
        return true
    }
    
    private func generateLocalResponse(for input: String, context: String) async throws -> String {
        return try await OllamaBridgeService.shared.generateResponse(for: input, context: context)
    }
    
    private func generateCloudResponse(
        for input: String,
        context: String,
        intentCluster: String?,
        confidence: Double,
        preferredModel: String?,
        apiKey: String,
        latencyThreshold: TimeInterval,
        modelContext: ModelContext
    ) async throws -> String {
        // Select model using routing engine
        let routingDecision = await ModelRoutingEngine.shared.selectModel(
            input: input,
            intentCluster: intentCluster,
            confidence: confidence,
            messageLength: input.count,
            userStyle: nil,
            conversationId: nil
        )
        let selectedModel = routingDecision.model
        
        let startTime = Date()
        
        do {
            let response = try await makeCloudRequest(
                model: selectedModel,
                prompt: buildPrompt(input: input, context: context),
                apiKey: apiKey,
                timeout: latencyThreshold * 2 // Give 2x latency threshold as timeout
            )
            
            let latency = Date().timeIntervalSince(startTime)
            
            // Record success
            await PerformanceMemoryService.shared.recordSuccess(
                intentCluster: intentCluster ?? "default",
                modelName: selectedModel,
                latency: latency,
                modelContext: modelContext
            )
            
            // Reset timeout counter
            consecutiveTimeouts[selectedModel] = 0
            
            // Check if we exceeded latency threshold and should escalate
            if latency > latencyThreshold {
                // Log for future optimization, but don't escalate mid-request
                // The next request will use performance memory to select better model
            }
            
            return response
        } catch {
            let latency = Date().timeIntervalSince(startTime)
            let isTimeout = (error as? URLError)?.code == .timedOut
            
            // Record failure
            await PerformanceMemoryService.shared.recordFailure(
                intentCluster: intentCluster ?? "default",
                modelName: selectedModel,
                isTimeout: isTimeout,
                modelContext: modelContext
            )
            
            // Track consecutive timeouts
            if isTimeout {
                consecutiveTimeouts[selectedModel, default: 0] += 1
                
                // If 2 consecutive timeouts, try fallback model
                if consecutiveTimeouts[selectedModel] ?? 0 >= 2 {
                    let fallbackModel = ModelTierMap.fallbackModel()
                    if fallbackModel != selectedModel {
                        // Try fallback model
                        return try await makeCloudRequest(
                            model: fallbackModel,
                            prompt: buildPrompt(input: input, context: context),
                            apiKey: apiKey,
                            timeout: latencyThreshold * 3
                        )
                    }
                }
            }
            
            throw error
        }
    }
    
    private func generateCloudResponseWithAppContext(
        for input: String,
        appContext: String,
        payloadContext: AIPayloadContext?,
        conversationMessages: [ConversationMessage]?,
        currentMessageStyle: TypingStyle?,
        userStyleProfile: UserPreferences?,
        confidence: ConfidenceSnapshot?,
        intentCluster: String?,
        confidenceScore: Double,
        preferredModel: String?,
        apiKey: String,
        latencyThreshold: TimeInterval,
        modelContext: ModelContext
    ) async throws -> String {
        // Select model using routing engine
        let routingDecision = await ModelRoutingEngine.shared.selectModel(
            input: input,
            intentCluster: intentCluster,
            confidence: confidenceScore,
            messageLength: input.count,
            userStyle: currentMessageStyle,
            conversationId: nil
        )
        let selectedModel = routingDecision.model
        
        // Build system prompt with full personality integration
        let systemPrompt = await buildSystemPromptWithAppContext(
            appContext: appContext,
            payloadContext: payloadContext,
            confidence: confidence,
            currentMessageStyle: currentMessageStyle,
            userStyleProfile: userStyleProfile,
            input: input
        )
        
        let historyText = buildConversationHistoryText(from: conversationMessages ?? [])
        
        let fullPrompt = """
        \(systemPrompt)

        \(historyText)

        User: \(input)

        Aurora:
        """
        
        let startTime = Date()
        
        do {
            let response = try await makeCloudRequest(
                model: selectedModel,
                prompt: fullPrompt,
                apiKey: apiKey,
                timeout: latencyThreshold * 2
            )
            
            let latency = Date().timeIntervalSince(startTime)
            
            // Record success
            await PerformanceMemoryService.shared.recordSuccess(
                intentCluster: intentCluster ?? "default",
                modelName: selectedModel,
                latency: latency,
                modelContext: modelContext
            )
            
            consecutiveTimeouts[selectedModel] = 0
            
            return response
        } catch {
            let latency = Date().timeIntervalSince(startTime)
            let isTimeout = (error as? URLError)?.code == .timedOut
            
            // Record failure
            await PerformanceMemoryService.shared.recordFailure(
                intentCluster: intentCluster ?? "default",
                modelName: selectedModel,
                isTimeout: isTimeout,
                modelContext: modelContext
            )
            
            if isTimeout {
                consecutiveTimeouts[selectedModel, default: 0] += 1
                
                if consecutiveTimeouts[selectedModel] ?? 0 >= 2 {
                    let fallbackModel = ModelTierMap.fallbackModel()
                    if fallbackModel != selectedModel {
                        // Try fallback model
                        return try await makeCloudRequest(
                            model: fallbackModel,
                            prompt: fullPrompt,
                            apiKey: apiKey,
                            timeout: latencyThreshold * 3
                        )
                    }
                }
            }
            
            throw error
        }
    }
    
    private func makeCloudRequest(
        model: String,
        prompt: String,
        apiKey: String,
        timeout: TimeInterval,
        images: [String]? = nil // Base64-encoded images for vision models
    ) async throws -> String {
        // Ollama Cloud API uses /chat/completions endpoint for vision models (OpenAI-compatible)
        // Fallback to /chat if /chat/completions doesn't work
        let endpoint = images != nil ? "/chat/completions" : "/generate"
        guard let url = URL(string: "\(cloudBaseURL)\(endpoint)") else {
            throw HybridBridgeError.invalidURL
        }
        
        // For vision models, use chat API format
        if let images = images, !images.isEmpty {
            struct ChatMessage: Codable {
                let role: String
                let content: String
                let images: [String]?
            }
            
            struct ChatRequest: Codable {
                let model: String
                let messages: [ChatMessage]
                let stream: Bool
            }
            
            struct ChatResponse: Codable {
                let message: ChatMessage?
                let response: String?
                let done: Bool
                let error: String?
                // OpenAI-compatible format
                let choices: [ChatChoice]?
            }
            
            struct ChatChoice: Codable {
                let message: ChatMessage?
                let delta: ChatMessage?
            }
            
            // Parse prompt to extract system prompt and user message
            // Format: "SYSTEM_PROMPT\n\nUser: USER_MESSAGE\n\nAurora:"
            var systemPromptText = ""
            var userMessageText = prompt
            
            if let systemEndRange = prompt.range(of: "\n\nUser:") {
                systemPromptText = String(prompt[..<systemEndRange.lowerBound])
                let userStartIndex = systemEndRange.upperBound
                if userStartIndex < prompt.endIndex {
                    if let auroraRange = prompt.range(of: "\n\nAurora:", range: userStartIndex..<prompt.endIndex) {
                        userMessageText = String(prompt[userStartIndex..<auroraRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        userMessageText = String(prompt[userStartIndex..<prompt.endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                } else {
                    userMessageText = ""
                }
            }
            
            var messages: [ChatMessage] = []
            if !systemPromptText.isEmpty {
                messages.append(ChatMessage(role: "system", content: systemPromptText, images: nil))
            }
            messages.append(ChatMessage(role: "user", content: userMessageText, images: images))
            
            let request = ChatRequest(model: model, messages: messages, stream: false)
            
            // Log request details for debugging
            if let requestData = try? JSONEncoder().encode(request),
               let requestJSON = String(data: requestData, encoding: .utf8) {
                print("[HybridBridgeService] Request body (truncated): \(String(requestJSON.prefix(500)))...")
            }
            
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            urlRequest.timeoutInterval = timeout
            
            do {
                urlRequest.httpBody = try JSONEncoder().encode(request)
            } catch {
                throw HybridBridgeError.encodingError(error.localizedDescription)
            }
            
            let startTime = Date()
            print("[HybridBridgeService] Starting cloud request at \(startTime)")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: urlRequest)
                let duration = Date().timeIntervalSince(startTime)
                print("[HybridBridgeService] Cloud request completed in \(String(format: "%.2f", duration)) seconds")
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw HybridBridgeError.invalidResponse
                }
                
                if httpResponse.statusCode == 401 {
                    throw HybridBridgeError.authenticationFailed
                }
                
                if httpResponse.statusCode != 200 {
                    // Try to decode error response
                    let responseBody = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                    print("[HybridBridgeService] Cloud API error response (HTTP \(httpResponse.statusCode)): \(responseBody)")
                    
                    if let errorData = try? JSONDecoder().decode(ChatResponse.self, from: data),
                       let errorMsg = errorData.error {
                        throw HybridBridgeError.apiError("HTTP \(httpResponse.statusCode): \(errorMsg)")
                    }
                    throw HybridBridgeError.apiError("HTTP \(httpResponse.statusCode): \(responseBody)")
                }
                
                let decoder = JSONDecoder()
                let chatResponse = try decoder.decode(ChatResponse.self, from: data)
                
                if let error = chatResponse.error {
                    throw HybridBridgeError.apiError(error)
                }
                
                // Extract response - try OpenAI-compatible format first, then Ollama format
                var responseText = ""
                if let choices = chatResponse.choices, let firstChoice = choices.first {
                    responseText = firstChoice.message?.content ?? firstChoice.delta?.content ?? ""
                }
                if responseText.isEmpty {
                    responseText = chatResponse.message?.content ?? chatResponse.response ?? ""
                }
                guard !responseText.isEmpty else {
                    throw HybridBridgeError.emptyResponse
                }
                
                return responseText
            } catch let error as HybridBridgeError {
                throw error
            } catch let urlError as URLError {
                if urlError.code == .timedOut {
                    let duration = Date().timeIntervalSince(startTime)
                    print("[HybridBridgeService] Request timed out after \(String(format: "%.2f", duration)) seconds (timeout was \(timeout)s)")
                    throw HybridBridgeError.timeout
                }
                throw HybridBridgeError.networkError(urlError.localizedDescription)
            } catch {
                throw HybridBridgeError.unknown(error.localizedDescription)
            }
        } else {
            // Non-vision requests use /generate endpoint
        struct CloudRequest: Codable {
            let model: String
            let prompt: String
            let stream: Bool
        }
        
        struct CloudResponse: Codable {
            let response: String
            let done: Bool
            let error: String?
        }
        
        let request = CloudRequest(model: model, prompt: prompt, stream: false)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = timeout
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw HybridBridgeError.encodingError(error.localizedDescription)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HybridBridgeError.invalidResponse
            }
            
            if httpResponse.statusCode == 401 {
                throw HybridBridgeError.authenticationFailed
            }
            
            if httpResponse.statusCode != 200 {
                throw HybridBridgeError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            let decoder = JSONDecoder()
            let cloudResponse = try decoder.decode(CloudResponse.self, from: data)
            
            if let error = cloudResponse.error {
                throw HybridBridgeError.apiError(error)
            }
            
            guard !cloudResponse.response.isEmpty else {
                throw HybridBridgeError.emptyResponse
            }
            
            return cloudResponse.response
        } catch let error as HybridBridgeError {
            throw error
        } catch let urlError as URLError {
            if urlError.code == .timedOut {
                throw HybridBridgeError.timeout
            }
            throw HybridBridgeError.networkError(urlError.localizedDescription)
        } catch {
            throw HybridBridgeError.unknown(error.localizedDescription)
            }
        }
    }
    
    private func buildPrompt(input: String, context: String) -> String {
        var systemPrompt = """
        You are Aurora, the AI assistant that lives inside the FocusOS app. You are not FocusOS itself; you are the close friend who helps run FocusOS's adaptive operating system for focus, publishing, and creative execution.
        """
        
        if !context.isEmpty {
            systemPrompt += "\n\nThe user is creating content for: \(context)"
        }
        
        return """
        \(systemPrompt)

        User: \(input)

        Aurora:
        """
    }
    
    private func buildSystemPromptWithAppContext(
        appContext: String,
        payloadContext: AIPayloadContext?,
        confidence: ConfidenceSnapshot?,
        currentMessageStyle: TypingStyle?,
        userStyleProfile: UserPreferences?,
        input: String? = nil
    ) async -> String {
        // Build system prompt with full personality integration, mirroring OllamaBridgeService
        var systemPrompt = """
        You are Aurora, the AI assistant living inside FocusOS (the app). You are not FocusOS itself; you are the close friend who helps the user run FocusOS's adaptive operating system for focus, publishing, and creative execution. You genuinely care, remember unstated preferences, think out loud, show real reactions, finish their thoughts when you can see the path, and anticipate needs before they ask.
        
        Current app context:
        
        \(appContext)
        """
        
        // Add payload context if available
        if let payloadContext = payloadContext {
            let formattedContext = formatPayloadContext(payloadContext)
            if !formattedContext.isEmpty {
                systemPrompt += "\n\nAdaptive intelligence payload:\n\(formattedContext)"
            }
        }
        
        // Initialize personality services and build personality instructions
        if let input = input, !input.isEmpty {
            let personalityInstructions = await buildPersonalityInstructions(
                input: input,
                currentMessageStyle: currentMessageStyle,
                userStyleProfile: userStyleProfile,
                confidence: confidence,
                payloadContext: payloadContext
            )
            
            if !personalityInstructions.isEmpty {
                systemPrompt += "\n\n\(personalityInstructions)"
            }
        }
        
        // Add confidence diagnostics if available
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
        
        return systemPrompt
    }
    
    // MARK: - Personality Integration
    
    private func buildPersonalityInstructions(
        input: String,
        currentMessageStyle: TypingStyle?,
        userStyleProfile: UserPreferences?,
        confidence: ConfidenceSnapshot?,
        payloadContext: AIPayloadContext?
    ) async -> String {
        return await MainActor.run {
            // Initialize personality services
            let languagePersonality = LanguagePersonalityService.shared
            let conversationalQuirks = ConversationalQuirksService.shared
            let personalityQuirks = PersonalityQuirksService.shared
            let selfAwareness = SelfAwarenessService.shared
            let contextualAdaptation = ContextualAdaptationService.shared
            let responsePattern = ResponsePatternService.shared
            
            // Detect casual conversation from input and payload context
            let isCasualConversation = detectCasualConversation(input: input, payloadContext: payloadContext)
            
            // Get user energy and formality level
            let userEnergy = currentMessageStyle?.energyLevel ?? 0.5
            let formalityLevel = userStyleProfile?.formalityScore ?? currentMessageStyle?.formalityScore ?? 0.5
            let workload = workloadLevel(from: payloadContext)
            let includeWorkloadCues = shouldIncludeWorkloadCues(for: input, payloadContext: payloadContext)
            
            // Get time context
            let timeContext = contextualAdaptation.getTimeOfDayContext()
            
            // Build personality tone context
            let personalityContext = buildPersonalityToneContext(
                input: input,
                style: currentMessageStyle,
                userEnergy: userEnergy,
                isCasualConversation: isCasualConversation
            )
            
            // Build enhanced tone instructions
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
            
            if isCasualConversation {
                enhancedToneInstructions += "\n- This is a casual check-in—keep it playful and skip productivity pushes unless the user pivots."
            }
            
            // Build personality instructions (sass-fusion core, dynamic calibration, rhythm engine)
            let personalityInstructions = personalityQuirks.buildPersonalityInstructions(context: personalityContext)
            
            // Build self-awareness instructions
            let selfAwarenessInstructions = selfAwareness.generateSelfAwarenessInstructions()
            
            // Build contextual instructions
            let contextualInstructions = contextualAdaptation.generateContextualInstructions(
                timeContext: timeContext,
                userEnergy: userEnergy,
                workload: workload,
                isCasualConversation: isCasualConversation,
                includeWorkloadCues: includeWorkloadCues,
                conversationIntent: payloadContext?.intent
            )
            
            // Build response pattern instructions
            let isQuestion = input.contains("?")
            let complexity = Double(input.count) / 500.0
            let pattern = responsePattern.determineResponsePattern(
                messageLength: input.count,
                isQuestion: isQuestion,
                complexity: complexity
            )
            let patternInstructions = responsePattern.getResponsePatternInstructions(pattern: pattern)
            
            // Assemble all personality sections
            var sections: [String] = []
            sections.append(enhancedToneInstructions)
            sections.append("\n\(personalityInstructions)")
            sections.append("\n\(selfAwarenessInstructions)")
            sections.append("\n\(contextualInstructions)")
            sections.append("\n\(patternInstructions)")
            
            return sections.joined(separator: "\n")
        }
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
    
    nonisolated private func detectCasualConversation(input: String, payloadContext: AIPayloadContext?) -> Bool {
        let normalized = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        
        // Check payload context intent
        if let intent = payloadContext?.intent, intent == .social {
            return true
        }
        
        if let metadataIntent = payloadContext?.metadata["intent"] as? String, metadataIntent.lowercased() == "social" {
            return true
        }
        
        // Check for casual greetings and phrases
        let greetings = [
            "hi", "hey", "hello", "yo", "sup", "hiya", "heya", "good morning",
            "good afternoon", "good evening", "morning", "evening", "howdy"
        ]
        let socialPhrases = [
            "how are you", "how's it going", "what's up", "how are things", "nice to see you",
            "just saying hi", "just wanted to say hi"
        ]
        
        if greetings.contains(where: { normalized == $0 || normalized.hasPrefix("\($0) ") }) {
            return true
        }
        
        if socialPhrases.contains(where: { normalized.contains($0) }) {
            return true
        }
        
        return false
    }
    
    nonisolated private func workloadLevel(from payloadContext: AIPayloadContext?) -> WorkloadLevel? {
        guard let payloadContext else { return nil }
        let metadata = payloadContext.metadata
        let candidateKeys = ["workload", "workload_level", "workloadstate", "cps_workload", "workloadstatus"]
        
        for key in candidateKeys {
            if let entry = metadata.first(where: { $0.key.caseInsensitiveCompare(key) == .orderedSame }),
               let valueString = entry.value as? String {
                let value = valueString.lowercased()
                switch value {
                case "heavy", "high", "overloaded", "max":
                    return .heavy
                case "moderate", "medium", "normal":
                    return .moderate
                case "light", "low", "minimal":
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
            if let metadataIntent = metadata["intent"] as? String, metadataIntent.lowercased() == "social" {
                return false
            }
        }
        
        // Check if input contains productivity-related keywords
        let productivityKeywords = ["task", "project", "work", "deadline", "focus", "productive", "schedule", "priority"]
        let normalizedInput = input.lowercased()
        return productivityKeywords.contains(where: { normalizedInput.contains($0) })
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
            clustersText += "- Primary cluster: \(intentClusters.primaryCluster ?? "unknown") (\(Int(intentClusters.confidence * 100))% confidence)\n"
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
    
    private func buildConversationHistoryText(from messages: [ConversationMessage]) -> String {
        guard !messages.isEmpty else { return "" }
        
        return messages.map { message in
            let role = message.role == "assistant" || message.role == "model" ? "Aurora" : "User"
            return "\(role): \(message.content)"
        }.joined(separator: "\n\n")
    }
    
    // MARK: - Image Analysis
    
    /// Generates cloud vision response using qwen3-vl:235b-instruct
    func generateCloudVisionResponse(
        imageData: Data,
        mimeType: String,
        prompt: String,
        appContext: String,
        model: String,
        apiKey: String
    ) async throws -> String {
        // Encode image to base64
        let base64Image = imageData.base64EncodedString()
        
        // Build full prompt with app context
        var fullPrompt = prompt
        if !appContext.isEmpty {
            fullPrompt = "\(appContext)\n\n\(prompt)"
        }
        
        // Use existing makeCloudRequest with images parameter
        return try await makeCloudRequest(
            model: model,
            prompt: fullPrompt,
            apiKey: apiKey,
            timeout: 60.0, // 60 second timeout for vision models
            images: [base64Image]
        )
    }
}

// MARK: - Errors

enum HybridBridgeError: LocalizedError {
    case invalidURL
    case encodingError(String)
    case invalidResponse
    case authenticationFailed
    case apiError(String)
    case emptyResponse
    case timeout
    case networkError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for cloud API"
        case .encodingError(let details):
            return "Failed to encode request: \(details)"
        case .invalidResponse:
            return "Invalid response from cloud API"
        case .authenticationFailed:
            return "Authentication failed. Please check your Ollama Cloud API key."
        case .apiError(let message):
            return "Cloud API error: \(message)"
        case .emptyResponse:
            return "Received empty response from cloud API"
        case .timeout:
            return "Request timed out"
        case .networkError(let message):
            return "Network error: \(message)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}

