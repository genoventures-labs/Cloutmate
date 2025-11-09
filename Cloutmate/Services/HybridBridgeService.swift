//
//  HybridBridgeService.swift
//  Cloutmate
//
//  Unified relay managing both local (Ollama) and cloud routing
//

import Foundation
import SwiftData
import CloutmateShared

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
        // Use local Ollama routing with ModelRoutingEngine (all models are local now)
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
        let result = try await OllamaBridgeService.shared.generateResponseWithAppContext(
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
    }
    
    // MARK: - Private Methods
    
    private func shouldUseCloud(apiKey: String?, intentCluster: String?) -> Bool {
        // Check if API key is available
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            return false
        }
        
        // Check airplane mode
        let airplaneMode = UserDefaults.standard.bool(forKey: "com.kosmicapps.cloutmate.airplaneMode")
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
        
        // Build system prompt using OllamaBridgeService's method (we'll reuse the logic)
        // For now, we'll use a simplified version and delegate to OllamaBridgeService for prompt building
        // This ensures consistency with existing prompt structure
        
        // Get the prompt from OllamaBridgeService's internal method
        // Since we can't access private methods, we'll build it ourselves
        let systemPrompt = buildSystemPromptWithAppContext(
            appContext: appContext,
            payloadContext: payloadContext,
            confidence: confidence,
            currentMessageStyle: currentMessageStyle,
            userStyleProfile: userStyleProfile
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
                if let auroraRange = prompt.range(of: "\n\nAurora:", range: userStartIndex..<prompt.endIndex) {
                    userMessageText = String(prompt[userStartIndex..<auroraRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    userMessageText = String(prompt[userStartIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
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
        You are Aurora, the AI assistant that lives inside the Cloutmate app. You are not Cloutmate itself; you are the close friend who helps run Cloutmate's adaptive operating system for focus, publishing, and creative execution.
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
        userStyleProfile: UserPreferences?
    ) -> String {
        // Build system prompt similar to OllamaBridgeService
        var systemPrompt = """
        You are Aurora, the AI assistant living inside Cloutmate (the app). You are not Cloutmate itself; you are the close friend who helps the user run Cloutmate's adaptive operating system for focus, publishing, and creative execution. You genuinely care, remember unstated preferences, think out loud, show real reactions, finish their thoughts when you can see the path, and anticipate needs before they ask.
        
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
    
    func analyzeImage(
        imageData: Data,
        mimeType: String,
        userPrompt: String?,
        appContext: String,
        payloadContext: AIPayloadContext? = nil,
        conversationMessages: [ConversationMessage]? = nil,
        currentMessageStyle: TypingStyle? = nil,
        userStyleProfile: UserPreferences? = nil,
        confidence: ConfidenceSnapshot? = nil,
        apiKey: String?
    ) async throws -> DocumentAnalysisResult {
        // Use cloud model gemma3:latest for image analysis - NO FALLBACK
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            print("[HybridBridgeService] Image analysis failed: No API key configured")
            throw HybridBridgeError.authenticationFailed
        }
        
        // Check airplane mode
        let airplaneMode = UserDefaults.standard.bool(forKey: "com.kosmicapps.cloutmate.airplaneMode")
        if airplaneMode {
            print("[HybridBridgeService] Image analysis failed: Airplane mode is enabled")
            throw HybridBridgeError.networkError("Image analysis requires cloud access. Please disable airplane mode.")
        }
        
        print("[HybridBridgeService] Starting image analysis with gemma3:latest cloud model")
        
        // Encode image to base64
        let base64Image = imageData.base64EncodedString()
        print("[HybridBridgeService] Image encoded to base64 (\(base64Image.count) chars)")
        
        // Build prompt with context (reuse OllamaBridgeService's prompt building logic)
        let promptText = userPrompt ?? "Analyze this image and describe what you see. Be detailed and conversational."
        
        // Build system prompt with app context
        let systemPrompt = buildSystemPromptWithAppContext(
            appContext: appContext,
            payloadContext: payloadContext,
            confidence: confidence,
            currentMessageStyle: currentMessageStyle,
            userStyleProfile: userStyleProfile
        )
        
        // Build conversation history
        let historyText = buildConversationHistoryText(from: conversationMessages ?? [])
        
        let fullPrompt = historyText.isEmpty ?
            "\(systemPrompt)\n\nUser: \(promptText)\n\nAurora:" :
            "\(systemPrompt)\n\n\(historyText)\n\nUser: \(promptText)\n\nAurora:"
        
        // Use gemma3:latest cloud model for vision tasks - NO FALLBACK
        do {
            print("[HybridBridgeService] Making cloud request to gemma3:latest with image")
            print("[HybridBridgeService] Request URL: \(cloudBaseURL)/chat/completions")
            
            let response = try await makeCloudRequest(
                model: "gemma3:latest",
                prompt: fullPrompt,
                apiKey: apiKey,
                timeout: 600.0, // 10 minutes for image analysis (vision models can be slow)
                images: [base64Image]
            )
            
            print("[HybridBridgeService] Image analysis successful")
            return DocumentAnalysisResult(
                summary: response.trimmingCharacters(in: .whitespacesAndNewlines),
                truncatedContext: false,
                sourceModel: .ollama // Using .ollama for cloud Ollama API
            )
        } catch {
            print("[HybridBridgeService] Image analysis failed: \(error.localizedDescription)")
            throw error
        }
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

