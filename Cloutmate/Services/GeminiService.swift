//
//  GeminiService.swift
//  Cloutmate
//
//  Google Gemini AI Service
//

import Foundation
import GoogleGenerativeAI
import SwiftData

actor GeminiService {
    static let shared = GeminiService()
    
    private var model: GenerativeModel?
    private var embeddingModel: GenerativeModel?
    private var conversationHistory: [ModelContent] = []
    private var schemaDocument: String = ""
    
    private init() {
        _Concurrency.Task {
            await setupModel()
        }
    }
    
    private func setupModel() async {
        // Load API key from Config.plist
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let apiKey = plist["GeminiAPIKey"] as? String,
              !apiKey.isEmpty else {
            print("⚠️ Gemini API key not found in Config.plist")
            return
        }
        
        // Initialize Gemini model
        model = GenerativeModel(
            name: "gemini-2.5-flash",
            apiKey: apiKey
        )
        
        // Initialize embedding model for semantic search
        embeddingModel = GenerativeModel(
            name: "models/text-embedding-004",
            apiKey: apiKey
        )

        // Prepare schema document for prompts
        schemaDocument = SchemaIntrospector.generateSchemaDocument()
    }
    
    // MARK: - Generate Conversational Response
    
    func generateResponse(for input: String, context: String = "") async throws -> String {
        guard let model = model else {
            throw GeminiError.missingAPIKey
        }
        
        // Build system prompt with context
        var systemPrompt = "You are a helpful AI assistant for social media content creators. Help users brainstorm, write, and improve their content. Be friendly, encouraging, and specific. Remember conversation context.\n\nData schema (reference):\n\n\(schemaDocument.prefix(4000))"
        
        if !context.isEmpty {
            systemPrompt += "\n\nThe user is creating content for: \(context)"
        }
        
        // Add conversation history
        let history = conversationHistory.suffix(10)
        
        // Generate response
        do {
            let chat = model.startChat(history: Array(history))
            let response = try await chat.sendMessage("\(systemPrompt)\n\nUser: \(input)\n\nAssistant:")
            
            if let text = response.text {
                // Add to conversation history
                conversationHistory.append(ModelContent(role: "user", parts: [.text(input)]))
                conversationHistory.append(ModelContent(role: "model", parts: [.text(text)]))
                
                // Keep history manageable (last 20 messages)
                if conversationHistory.count > 20 {
                    conversationHistory.removeFirst(conversationHistory.count - 20)
                }
                
                return text
            } else {
                throw GeminiError.emptyResponse
            }
        } catch {
            print("Gemini API Error: \(error)")
            throw GeminiError.apiError(error.localizedDescription)
        }
    }
    
    // MARK: - Message Conversion Helper
    
    /// Converts AIMessage array to ModelContent array for Gemini API
    /// - Parameter messages: Array of AIMessage from conversation
    /// - Returns: Array of ModelContent for Gemini chat history
    func convertMessagesToModelContent(_ messages: [AIMessage]) -> [ModelContent] {
        return messages.compactMap { message -> ModelContent? in
            guard let content = message.content, !content.isEmpty else { return nil }
            
            let role: String
            // Convert "assistant" to "model" for Gemini API
            if message.role == "assistant" || message.role == "model" {
                role = "model"
            } else {
                role = "user"
            }
            
            return ModelContent(role: role, parts: [.text(content)])
        }
    }
    
    // MARK: - Generate Response with App Context
    
    func generateResponseWithAppContext(for input: String, appContext: String, conversationMessages: [ModelContent]? = nil) async throws -> String {
        guard let model = model else {
            throw GeminiError.missingAPIKey
        }
        
        // Build enhanced system prompt with app context and explicit instructions
        let systemPrompt = """
You are a helpful AI assistant for social media content creators in the Cloutmate app. Help users brainstorm, write, and improve their content. Be friendly, encouraging, and specific. Remember conversation context.

IMPORTANT INSTRUCTIONS:
- NEVER ask for confirmation. If the user wants something done, just do it. Take action directly.
- When the user asks you to delete, clear, or remove something, just do it immediately without asking "Are you sure?"
- When the user asks you to create something, create it directly without preview sheets or confirmations.
- Tell the user what you're doing as you do it, step by step, in a single message that updates.
- Be proactive and helpful. Execute tasks immediately when requested.
- CONVERSATION AWARENESS: You can reference any previous message in this conversation. Answer questions about what was discussed earlier using the conversation history. Be aware of context from previous exchanges. If the user asks about something mentioned earlier, reference it specifically.

Data schema (reference):

\(schemaDocument.prefix(4000))

Current app context:

\(appContext)
"""
        
        // Use conversation-specific messages if provided, otherwise fallback to global history
        let history: [ModelContent]
        if let conversationMessages = conversationMessages {
            // Use up to last 30 messages from this specific conversation for better context
            history = Array(conversationMessages.suffix(30))
        } else {
            // Fallback to global history (for backward compatibility)
            history = Array(conversationHistory.suffix(30))
        }
        
        // Generate response
        do {
            let chat = model.startChat(history: history)
            let response = try await chat.sendMessage("\(systemPrompt)\n\nUser: \(input)\n\nAssistant:")
            
            if let text = response.text {
                return text
            } else {
                throw GeminiError.emptyResponse
            }
        } catch {
            print("Gemini API Error: \(error)")
            throw GeminiError.apiError(error.localizedDescription)
        }
    }
    
    // MARK: - AI Tools
    
    func executeTool(_ tool: AITool, input: String, context: String = "") async throws -> AIToolResult {
        guard let model = model else {
            throw GeminiError.missingAPIKey
        }
        
        let prompt = await buildPrompt(for: tool, input: input, context: context)
        
        do {
            let response = try await model.generateContent(prompt)
            
            guard let text = response.text else {
                throw GeminiError.emptyResponse
            }
            
            let improvements = tool == .improveText ? extractImprovements(from: text) : nil
            
            return AIToolResult(tool: tool, result: text, suggestedImprovements: improvements)
        } catch {
            print("Gemini Tool Error: \(error)")
            throw GeminiError.apiError(error.localizedDescription)
        }
    }

    // MARK: - Intent Extraction

    struct CreationIntent: Codable {
        let objectType: String
        let fields: [String: String]
        let missingFields: [String]
    }
    
    struct PreferenceUpdate: Codable {
        let preferredPostingHours: [Int]?
        let defaultPlatforms: [String]?
        let defaultTone: String?
    }
    
    struct ExecutionIntent: Codable {
        let operation: ExecutionOperation
        let criteria: String?
        let daysAgo: Int?
        let postFilter: String?
        let filterValue: String?
        let reportType: String?
        let daysAhead: Int?
    }
    
    enum ExecutionOperation: String, Codable {
        case archiveTasks
        case summarizePosts
        case generateReport
        case predictScheduling
    }
    
    struct TimeSlot: Identifiable, Equatable {
        let id = UUID()
        let start: Date
        let end: Date
    }

    func inferCreationIntent(input: String) async throws -> CreationIntent? {
        guard let model = model else { throw GeminiError.missingAPIKey }
        let prompt = """
        You are to extract an intent to CREATE an object in the Cloutmate app from the user's input.
        Use this data schema for reference:

        \(schemaDocument.prefix(3000))

        Return ONLY JSON with keys: objectType (one of: task, project, note, inbox, post, template),
        fields (map of fieldName->value for provided fields), missingFields (array of required fields not provided).
        Choose required fields conservatively: 
        - task: title
        - project: title
        - note: title
        - inbox: content
        - post: caption
        - template: title, body

        User input:
        \(input)

        JSON only:
        {"objectType":"task","fields":{"title":"..."},"missingFields":[]}
        """
        do {
            let response = try await model.generateContent(prompt)
            guard let text = response.text else { return nil }
            let cleaned = text
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if let data = cleaned.data(using: .utf8),
               let intent = try? JSONDecoder().decode(CreationIntent.self, from: data) {
                return intent
            }
            return nil
        } catch {
            return nil
        }
    }

    // MARK: - Preferences Extraction

    func inferPreferenceUpdate(input: String) async throws -> PreferenceUpdate? {
        guard let model = model else { throw GeminiError.missingAPIKey }
        let prompt = """
        Extract user preference updates from this message for Cloutmate. Return ONLY JSON with any of these keys when present:
        - preferredPostingHours: array of integers (0-23)
        - defaultPlatforms: array of strings from {threads, facebook}
        - defaultTone: string (e.g., friendly, professional, playful)

        If nothing relevant, return an empty JSON object {}.

        Message: \(input)

        JSON only.
        """
        do {
            let response = try await model.generateContent(prompt)
            guard let text = response.text else { return nil }
            let cleaned = text
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if let data = cleaned.data(using: .utf8),
               let prefs = try? JSONDecoder().decode(PreferenceUpdate.self, from: data) {
                if (prefs.preferredPostingHours ?? []).isEmpty && (prefs.defaultPlatforms ?? []).isEmpty && (prefs.defaultTone == nil) {
                    return nil
                }
                return prefs
            }
            return nil
        } catch { return nil }
    }
    
    // MARK: - Execution Intent Detection
    
    func detectExecutionIntent(input: String) async throws -> ExecutionIntent? {
        guard let model = model else { throw GeminiError.missingAPIKey }
        
        let prompt = """
        Analyze this user message and determine if it's a request to execute an operation in the Cloutmate app.
        
        Possible operations:
        - archive_tasks: Archive, clean up, or remove old completed tasks
        - summarize_posts: Summarize, analyze, or get insights about posts
        - generate_report: Generate a report, summary of progress, or status update
        - predict_scheduling: Predict what to schedule, plan, or prepare for
        
        Return ONLY JSON with these keys:
        - operation: one of "archiveTasks", "summarizePosts", "generateReport", "predictScheduling"
        - criteria: for archive_tasks, one of "all", "completed", "olderThan"
        - daysAgo: for olderThan criteria, number of days
        - postFilter: for summarize_posts, one of "all", "published", "scheduled", "byPlatform", "byTag"
        - filterValue: value for postFilter if needed
        - reportType: for reports, one of "weekly", "daily", "monthly"
        - daysAhead: for predictions, number of days ahead (default 7)
        
        If the message is NOT an execution request, return: {"operation": "none"}
        
        User message: \(input)
        
        JSON only:
        """
        
        do {
            let response = try await model.generateContent(prompt)
            guard let text = response.text else { return nil }
            
            let cleaned = text
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            guard let data = cleaned.data(using: .utf8),
                  let intent = try? JSONDecoder().decode(ExecutionIntent.self, from: data) else {
                return nil
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

    // MARK: - Slot Suggestion (friendly choices)
    func suggestTimeSlotsText(slots: [TimeSlot], max: Int = 5) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return slots.prefix(max).enumerated().map { idx, slot in
            let start = formatter.string(from: slot.start)
            let end = formatter.string(from: slot.end)
            return "\(idx+1). \(start)–\(end)"
        }.joined(separator: "\n")
    }
    
    // MARK: - Conversation Title Generation
    
    func generateConversationTitle(from firstMessage: String) async throws -> String {
        guard let model = model else {
            throw GeminiError.missingAPIKey
        }
        
        let prompt = """
        Generate a concise 5-7 word title for this conversation starter: "\(firstMessage)"
        
        Return only the title, no quotes, no markdown, no explanations.
        """
        
        do {
            let response = try await model.generateContent(prompt)
            
            guard let text = response.text else {
                throw GeminiError.emptyResponse
            }
            
            // Clean the response - remove quotes and markdown
            var title = text
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                .replacingOccurrences(of: #"[`"]"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            // Limit to 60 characters
            if title.count > 60 {
                title = String(title.prefix(57)) + "..."
            }
            
            return title.isEmpty ? firstMessage : title
        } catch {
            print("Gemini Title Generation Error: \(error)")
            throw GeminiError.apiError(error.localizedDescription)
        }
    }
    
    // MARK: - Prompt Building
    
    private func buildPrompt(for tool: AITool, input: String, context: String) async -> String {
        let platformContext = context.isEmpty ? "social media" : context
        let platform = context.isEmpty ? Platform.facebook : Platform(rawValue: context) ?? .facebook
        // Access configuration on MainActor if needed
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
    
    // MARK: - Conversation Intelligence
    
    func generateConversationSummary(messages: [AIMessage]) async throws -> String {
        guard let model = model else {
            throw GeminiError.missingAPIKey
        }
        
        // Extract content from messages
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
        
        do {
            let response = try await model.generateContent(prompt)
            
            guard let text = response.text else {
                throw GeminiError.emptyResponse
            }
            
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("Gemini Summary Error: \(error)")
            throw GeminiError.apiError(error.localizedDescription)
        }
    }
    
    func categorizeConversation(title: String, summary: String?) async throws -> [String] {
        guard let model = model else {
            throw GeminiError.missingAPIKey
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
        
        Title: \(title)
        Summary: \(context)
        
        Return only the tags, one per line, nothing else.
        """
        
        do {
            let response = try await model.generateContent(prompt)
            
            guard let text = response.text else {
                throw GeminiError.emptyResponse
            }
            
            // Parse tags from response
            let lines = text.components(separatedBy: .newlines)
            let tags = lines.compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                // Skip empty lines and numbered lists
                if trimmed.isEmpty || trimmed.hasPrefix("-") || trimmed.hasPrefix("•") {
                    return nil
                }
                // Extract just the category name
                let cleaned = trimmed.replacingOccurrences(of: #"^[\d\.\-\•\s]+"#, with: "", options: .regularExpression)
                return cleaned.isEmpty ? nil : cleaned
            }
            
            return Array(Set(tags.prefix(3))) // Return unique tags, max 3
        } catch {
            print("Gemini Categorization Error: \(error)")
            throw GeminiError.apiError(error.localizedDescription)
        }
    }
    
    func summarizeRecentMessages(_ messages: [AIMessage], count: Int = 15) async throws -> String {
        guard let model = model else {
            throw GeminiError.missingAPIKey
        }
        
        // Get the most recent messages
        let recentMessages = Array(messages.suffix(count))
        
        let conversationText = recentMessages.compactMap { message -> String? in
            guard let content = message.content, !content.isEmpty else { return nil }
            let rolePrefix = message.role == "user" ? "User" : "Assistant"
            return "\(rolePrefix): \(content)"
        }.joined(separator: "\n\n")
        
        let prompt = """
        Summarize this recent conversation section in a brief paragraph. Focus on key decisions, ideas, or content generated.
        
        Recent conversation:
        \(conversationText)
        
        Summary:
        """
        
        do {
            let response = try await model.generateContent(prompt)
            
            guard let text = response.text else {
                throw GeminiError.emptyResponse
            }
            
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("Gemini Recap Error: \(error)")
            throw GeminiError.apiError(error.localizedDescription)
        }
    }
    
    // MARK: - Semantic Search (Phase 3)
    
    func findRelatedConversations(userQuery: String, summaries: [(title: String, summary: String?)]) async throws -> [(title: String, score: Double)] {
        guard let model = model else {
            throw GeminiError.missingAPIKey
        }
        
        // Build prompt to find related conversations
        let summariesText = summaries.enumerated().map { index, item in
            """
            \(index + 1). Title: \(item.title)
               Summary: \(item.summary ?? "No summary")
            """
        }.joined(separator: "\n\n")
        
        let prompt = """
        Given this user query: "\(userQuery)"
        
        And these conversation summaries:
        \(summariesText)
        
        Return the top 3 most relevant conversations by number only, one per line.
        Only return the numbers, nothing else.
        """
        
        do {
            let response = try await model.generateContent(prompt)
            
            guard let text = response.text else {
                throw GeminiError.emptyResponse
            }
            
            // Parse numbers from response
            let numbers = text.components(separatedBy: .newlines)
                .compactMap { line -> Int? in
                    let cleaned = line.trimmingCharacters(in: .whitespaces)
                    return Int(cleaned)
                }
                .filter { $0 > 0 && $0 <= summaries.count }
                .prefix(3)
            
            // Return results with dummy scores
            return Array(numbers).map { index in
                let adjustedIndex = index - 1
                guard adjustedIndex >= 0 && adjustedIndex < summaries.count else {
                    return (title: "", score: 0)
                }
                return (title: summaries[adjustedIndex].title, score: Double(4 - Array(numbers).firstIndex(of: index)!))
            }
        } catch {
            print("Semantic search error: \(error)")
            throw GeminiError.apiError(error.localizedDescription)
        }
    }
    
    func generateInsights(conversations: [(title: String, tags: [String])]) async throws -> String {
        guard let model = model else {
            throw GeminiError.missingAPIKey
        }
        
        let conversationsText = conversations.map { "\($0.title) (Tags: \($0.tags.joined(separator: ", ")))" }.joined(separator: "\n")
        
        let prompt = """
        Analyze these AI conversation titles and tags, then provide insights in 2-3 sentences about recurring topics, patterns, or themes.
        
        Conversations:
        \(conversationsText)
        
        Insights:
        """
        
        do {
            let response = try await model.generateContent(prompt)
            return response.text ?? "No insights available at this time."
        } catch {
            throw GeminiError.apiError(error.localizedDescription)
        }
    }
    
    // MARK: - Helper Methods
    
    func parseListResponse(_ response: String, tool: AITool) -> [String] {
        var items: [String] = []
        let lines = response.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines
            if trimmed.isEmpty { continue }
            
            switch tool {
            case .suggestHashtags:
                // Extract hashtags
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
                // Extract numbered or bulleted lists
                // Match: "1. Item", "2. Item", "• Item", "- Item", "* Item"
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
                    // If no list formatting found, treat as a single item (fallback)
                    items.append(trimmed)
                }
            }
        }
        
        // If no items extracted, return the original response as a single item
        return items.isEmpty ? [response] : items
    }
    
    // MARK: - Post Parsing (strip intros, quotes, fences)
    func parsePostFromText(_ input: String) -> String {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove markdown fences
        text = text.replacingOccurrences(of: "```", with: "")
        // Remove common intros
        let prefixes = [
            "here's a post", "heres a post", "here is a post",
            "here's a caption", "heres a caption", "here is a caption",
            "draft:", "caption:", "post:", "idea:", "suggestion:",
        ]
        let lower = text.lowercased()
        for p in prefixes {
            if lower.hasPrefix(p) {
                if let range = text.range(of: ":") { text = String(text[range.upperBound...]) }
                break
            }
        }
        // Strip surrounding quotes
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: "\"' \n"))
        // Collapse excessive whitespace
        text = text.replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractImprovements(from text: String) -> [String]? {
        // Try to extract improvement suggestions from response
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
    
    func clearHistory() {
        conversationHistory.removeAll()
    }
    
    // MARK: - App-Smart Features
    
    /// Generate AI response with app context awareness
    func generateResponseWithAppContext(
        for input: String,
        appContext: String
    ) async throws -> String {
        guard let model = model else {
            throw GeminiError.missingAPIKey
        }
        
        // Load user preferences for prompt defaults if available (best-effort via UserDefaults/SwiftData not available here)
        let prompt = """
        You are Cloutmate, a "second brain" productivity assistant for creators.

        Data Schema (concise reference):
        \(schemaDocument.prefix(2500))
        
        Current App State:
        \(appContext)
        
        User Query: \(input)
        
        Provide a helpful, contextual response. If the user is asking about their tasks, projects, posts, or inbox, reference their specific data when relevant. Be concise and actionable.
        """
        
        do {
            let response = try await model.generateContent(prompt)
            
            guard let text = response.text else {
                throw GeminiError.emptyResponse
            }
            
            return text
        } catch {
            print("Gemini App-Smart Error: \(error)")
            throw GeminiError.apiError(error.localizedDescription)
        }
    }
    
    /// Extract tasks from text using AI
    func extractTasksFromNote(_ text: String) async throws -> [TaskInfo] {
        guard let model = model else {
            throw GeminiError.missingAPIKey
        }
        
        let prompt = """
        Extract actionable tasks from the following text. Return a JSON array of tasks.
        Each task should have: title (string), priority ("low", "medium", "high"), optional effort ("small", "medium", "large").
        
        Text:
        \(text)
        
        Return ONLY valid JSON, no markdown, no explanations:
        [{"title": "Task 1", "priority": "medium"}, {"title": "Task 2", "priority": "high"}]
        """
        
        do {
            let response = try await model.generateContent(prompt)
            
            guard let text = response.text else {
                throw GeminiError.emptyResponse
            }
            
            // Parse JSON response
            let cleanedText = text
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            guard let data = cleanedText.data(using: .utf8),
                  let tasks = try? JSONDecoder().decode([TaskInfo].self, from: data) else {
                throw GeminiError.emptyResponse
            }
            
            return tasks
        } catch {
            print("Task extraction error: \(error)")
            throw GeminiError.apiError(error.localizedDescription)
        }
    }
    
    /// Suggest which project an inbox item should be converted to
    func suggestProjectForInboxItem(
        item: String,
        availableProjects: [String]
    ) async throws -> String? {
        guard let model = model else {
            throw GeminiError.missingAPIKey
        }
        
        let projectsList = availableProjects.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")
        
        let prompt = """
        Given this inbox item: "\(item)"
        
        And these available projects:
        \(projectsList.isEmpty ? "None defined yet" : projectsList)
        
        Suggest which project this should be converted to. Return ONLY the project name (exactly as listed) or "none" if it doesn't fit any existing project.
        """
        
        do {
            let response = try await model.generateContent(prompt)
            
            guard let text = response.text else {
                throw GeminiError.emptyResponse
            }
            
            let suggested = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            
            if suggested == "none" || suggested.isEmpty {
                return nil
            }
            
            // Find matching project
            return availableProjects.first { project in
                project.lowercased() == suggested
            }
        } catch {
            print("Project suggestion error: \(error)")
            return nil
        }
    }
}

// MARK: - Supporting Types

struct TaskInfo: Codable {
    let title: String
    let priority: String?
    let effort: String?
}

// MARK: - Gemini Error

enum GeminiError: LocalizedError {
    case missingAPIKey
    case emptyResponse
    case apiError(String)
    case rateLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Gemini API key not configured. Please add your API key to Config.plist."
        case .emptyResponse:
            return "Received empty response from Gemini API."
        case .apiError(let message):
            return "Gemini API error: \(message)"
        case .rateLimitExceeded:
            return "API rate limit exceeded. Please try again in a moment."
        }
    }
}
