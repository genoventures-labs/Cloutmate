//
//  GeminiService.swift
//  Cloutmate
//
//  Google Gemini API service for image analysis
//

import Foundation
import CloutmateShared

// MARK: - Gemini Service

actor GeminiService {
    static let shared = GeminiService()
    
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    private let model = "gemini-2.5-flash"
    
    private init() {}
    
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
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            print("[GeminiService] Image analysis failed: No API key configured")
            throw GeminiError.authenticationFailed
        }
        
        print("[GeminiService] Starting image analysis with Gemini 2.5 Flash")
        
        // Encode image to base64
        let base64Image = imageData.base64EncodedString()
        print("[GeminiService] Image encoded to base64 (\(base64Image.count) chars)")
        
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
        
        // Build user prompt
        let promptText = userPrompt ?? "Analyze this image and describe what you see. Be detailed and conversational."
        
        // Combine system prompt, history, and user prompt
        let fullPrompt = historyText.isEmpty ?
            "\(systemPrompt)\n\nUser: \(promptText)\n\nAurora:" :
            "\(systemPrompt)\n\n\(historyText)\n\nUser: \(promptText)\n\nAurora:"
        
        // Build Gemini API request
        let request = GeminiRequest(
            contents: [
                GeminiContent(
                    parts: [
                        GeminiPart(text: fullPrompt),
                        GeminiPart(
                            inlineData: GeminiInlineData(
                                mimeType: mimeType,
                                data: base64Image
                            )
                        )
                    ]
                )
            ],
            generationConfig: GeminiGenerationConfig(
                temperature: 0.7,
                topK: 40,
                topP: 0.95,
                maxOutputTokens: 8192
            )
        )
        
        // Make API request
        do {
            print("[GeminiService] Making Gemini API request")
            let response = try await makeGeminiRequest(request: request, apiKey: apiKey)
            
            print("[GeminiService] Image analysis successful")
            return DocumentAnalysisResult(
                summary: response.trimmingCharacters(in: .whitespacesAndNewlines),
                truncatedContext: false,
                sourceModel: .ollama // Using .ollama for consistency
            )
        } catch {
            print("[GeminiService] Image analysis failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func makeGeminiRequest(request: GeminiRequest, apiKey: String) async throws -> String {
        let endpoint = "\(baseURL)/models/\(model):generateContent"
        guard let url = URL(string: "\(endpoint)?key=\(apiKey)") else {
            throw GeminiError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 600.0 // 10 minutes for image analysis
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw GeminiError.encodingError(error.localizedDescription)
        }
        
        let startTime = Date()
        print("[GeminiService] Starting Gemini API request at \(startTime)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            let duration = Date().timeIntervalSince(startTime)
            print("[GeminiService] Gemini API request completed in \(String(format: "%.2f", duration)) seconds")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GeminiError.invalidResponse
            }
            
            if httpResponse.statusCode == 401 {
                throw GeminiError.authenticationFailed
            }
            
            if httpResponse.statusCode != 200 {
                let responseBody = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                print("[GeminiService] Gemini API error response (HTTP \(httpResponse.statusCode)): \(responseBody)")
                throw GeminiError.apiError("HTTP \(httpResponse.statusCode): \(responseBody)")
            }
            
            let decoder = JSONDecoder()
            let geminiResponse = try decoder.decode(GeminiResponse.self, from: data)
            
            // Extract text from response
            guard let candidate = geminiResponse.candidates.first,
                  let content = candidate.content,
                  let part = content.parts.first,
                  let text = part.text else {
                throw GeminiError.emptyResponse
            }
            
            return text
        } catch let urlError as URLError {
            if urlError.code == .timedOut {
                let duration = Date().timeIntervalSince(startTime)
                print("[GeminiService] Request timed out after \(String(format: "%.2f", duration)) seconds")
                throw GeminiError.timeout
            }
            throw GeminiError.networkError(urlError.localizedDescription)
        } catch let error as GeminiError {
            throw error
        } catch {
            throw GeminiError.unknown(error.localizedDescription)
        }
    }
    
    private func buildSystemPromptWithAppContext(
        appContext: String,
        payloadContext: AIPayloadContext?,
        confidence: ConfidenceSnapshot?,
        currentMessageStyle: TypingStyle?,
        userStyleProfile: UserPreferences?
    ) -> String {
        // Reuse the same system prompt building logic from HybridBridgeService
        // This ensures consistency with Aurora's personality
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
    
    private func buildConversationHistoryText(from messages: [ConversationMessage]) -> String {
        guard !messages.isEmpty else { return "" }
        
        return messages.map { message in
            let role = message.role == "assistant" || message.role == "model" ? "Aurora" : "User"
            return "\(role): \(message.content)"
        }.joined(separator: "\n\n")
    }
    
    private func formatPayloadContext(_ payload: AIPayloadContext) -> String {
        var sections: [String] = []
        
        if !payload.recall.isEmpty {
            let recallLines = payload.recall.prefix(5).map { snippet -> String in
                let score = String(format: "%.2f", snippet.score)
                let detail = snippet.detail.trimmingCharacters(in: .whitespacesAndNewlines)
                let shortDetail = detail.isEmpty ? "" : " - \(detail.count > 120 ? String(detail.prefix(120)) + "…" : detail)"
                return "[\(score)] \(snippet.title)\(shortDetail)"
            }
            sections.append("**Recall Context:**\n\(recallLines.joined(separator: "\n"))")
        }
        
        if let intentClusters = payload.intentClusters, !intentClusters.clusters.isEmpty {
            let intentLines = intentClusters.clusters.map { cluster -> String in
                let topics = cluster.topics.joined(separator: ", ")
                return "- \(cluster.name): \(topics)"
            }
            sections.append("**Intent Clusters:**\n\(intentLines.joined(separator: "\n"))")
        }
        
        return sections.joined(separator: "\n\n")
    }
}

// MARK: - Request/Response Models

private struct GeminiRequest: Codable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig
}

private struct GeminiContent: Codable {
    let parts: [GeminiPart]
}

private struct GeminiPart: Codable {
    let text: String?
    let inlineData: GeminiInlineData?
    
    init(text: String) {
        self.text = text
        self.inlineData = nil
    }
    
    init(inlineData: GeminiInlineData) {
        self.text = nil
        self.inlineData = inlineData
    }
}

private struct GeminiInlineData: Codable {
    let mimeType: String
    let data: String
}

private struct GeminiGenerationConfig: Codable {
    let temperature: Double
    let topK: Int
    let topP: Double
    let maxOutputTokens: Int
}

private struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]
}

private struct GeminiCandidate: Codable {
    let content: GeminiContent?
    let finishReason: String?
}

// MARK: - Errors

enum GeminiError: LocalizedError {
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
            return "Invalid URL for Gemini API"
        case .encodingError(let details):
            return "Failed to encode request: \(details)"
        case .invalidResponse:
            return "Invalid response from Gemini API"
        case .authenticationFailed:
            return "Authentication failed. Please check your Google API key."
        case .apiError(let message):
            return "Gemini API error: \(message)"
        case .emptyResponse:
            return "Received empty response from Gemini API"
        case .timeout:
            return "Request timed out"
        case .networkError(let message):
            return "Network error: \(message)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}

