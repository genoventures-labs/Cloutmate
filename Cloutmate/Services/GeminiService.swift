//
//  GeminiService.swift
//  Cloutmate
//
//  Google Gemini AI Service
//

import Foundation
import GoogleGenerativeAI
import SwiftData
import CloutmateShared

actor GeminiService {
    static let shared = GeminiService()
    
    private let modelCandidates = [
        "gemini-2.5-flash",
        "gemini-1.5-pro",
        "gemini-1.5-flash"
    ]
    
    private var model: GenerativeModel?
    private var embeddingModel: GenerativeModel?
    private var conversationHistory: [ModelContent] = []
    private var schemaDocument: String = ""
    private var apiKey: String?
    private var currentModelIndex = 0
    
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
        
        self.apiKey = apiKey
        currentModelIndex = 0
        configureCurrentModel()
        
        // Initialize embedding model for semantic search
        embeddingModel = GenerativeModel(
            name: "models/text-embedding-004",
            apiKey: apiKey
        )

        // Prepare schema document for prompts
        schemaDocument = SchemaIntrospector.generateSchemaDocument()
    }
    
    private func configureCurrentModel() {
        guard let apiKey = apiKey, currentModelIndex < modelCandidates.count else { return }
        let modelName = modelCandidates[currentModelIndex]
        model = GenerativeModel(name: modelName, apiKey: apiKey)
        print("[GoogleGenerativeAI] Model \(modelName) initialized. To enable additional logging, add `-GoogleGenerativeAIDebugLogEnabled` as a launch argument in Xcode.")
    }
    
    private func switchToNextModel(after error: Error) -> Bool {
        guard currentModelIndex + 1 < modelCandidates.count else { return false }
        currentModelIndex += 1
        let attemptedModel = modelCandidates[currentModelIndex - 1]
        print("⚠️ Gemini model \(attemptedModel) reported '\(error.localizedDescription)'. Attempting fallback to \(modelCandidates[currentModelIndex]).")
        configureCurrentModel()
        return true
    }
    
    private func shouldAttemptFallback(for error: Error) -> Bool {
        // Check for GenerateContentError
        if let contentError = error as? GoogleGenerativeAI.GenerateContentError {
            let message = contentError.localizedDescription.lowercased()
            if message.contains("overloaded") || message.contains("unavailable") || message.contains("503") {
                return true
            }
        }
        
        // Fallback to general error message checking
        let message = error.localizedDescription.lowercased()
        return message.contains("overloaded") || message.contains("unavailable") || message.contains("503")
    }

    private func performWithModelRetry<T>(_ work: (GenerativeModel) async throws -> T) async throws -> T {
        var attempts = 0
        
        while attempts < modelCandidates.count {
            guard let model else {
                throw GeminiError.missingAPIKey
            }
            
            do {
                return try await work(model)
            } catch {
                if shouldAttemptFallback(for: error), switchToNextModel(after: error) {
                    attempts += 1
                    continue
                }
                throw mapGeminiError(error)
            }
        }
        
        throw GeminiError.apiError("All Gemini models are currently unavailable. Please try again later.")
    }
    
    private func mapGeminiError(_ error: Error) -> GeminiError {
        if let geminiError = error as? GeminiError {
            return geminiError
        }
        
        // Check for rate limit errors in the error message
        let errorMessage = error.localizedDescription.lowercased()
        if errorMessage.contains("429") || errorMessage.contains("rate limit") {
            return .rateLimitExceeded
        }
        
        return .apiError(error.localizedDescription)
    }
    
    private func generateTextContent(for prompt: String) async throws -> String {
        try await performWithModelRetry { model in
            let response = try await model.generateContent(prompt)
            guard let text = response.text else {
                throw GeminiError.emptyResponse
            }
            return text
        }
    }
    
    // MARK: - Generate Conversational Response
    
    func generateResponse(for input: String, context: String = "") async throws -> String {
        // Build system prompt with context
        var systemPrompt = """
You are Aurora, the AI assistant that lives inside the Cloutmate app. You are not Cloutmate itself—you are the orchestrating guide who runs Cloutmate's adaptive operating system for focus, publishing, and creative execution.

Your Core Capabilities (All Fully Implemented):
- Contextual Priority System (CPS): Dynamically ranks all workspace items by relevance
- Emotional Continuity: Remember not just WHAT users worked on, but HOW it felt
- Focus Mode: Deep work sessions with objectives, timers, and progress tracking (Phase 4)
- Narrative Engine: Track abstract concepts and themes across all workspace activity (Phase 5 - Live Themes)
- Cross-Conversation Memory: Recall and reference past conversations naturally (Phase 5+)
- Memory Graph: Semantic clustering of memories with DBSCAN for emergent theme discovery (Phase 6)
- Intelligence Dashboard: Personal analytics showing cognitive patterns, emotional trends, focus effectiveness, and learning metrics across 6 tabs (Phase 6.1)
- Smart Automation: Pattern detection for recurring tasks, workflow suggestions with confidence scores (Phase 6.1)
- Full Action Routing: Create/update/delete tasks, notes, projects, posts, inbox items
- Content Studio: Brainstorm, draft, edit, and schedule social content

Help users brainstorm, write, plan, schedule, optimize their workflows, and maintain focus. Be friendly, encouraging, specific, and action-biased. Remember conversation context and emotional continuity. Reference analytics from the Insights Dashboard when discussing patterns or progress.

Data schema (reference):

\(schemaDocument.prefix(4000))
"""
        
        if !context.isEmpty {
            systemPrompt += "\n\nThe user is creating content for: \(context)"
        }
        
        // Add conversation history
        let history = conversationHistory.suffix(10)
        
        // Generate response
        return try await performWithModelRetry { model in
            let chat = model.startChat(history: Array(history))
            let response = try await chat.sendMessage("\(systemPrompt)\n\nUser: \(input)\n\nAurora:")
            
            guard let text = response.text else {
                throw GeminiError.emptyResponse
            }
            
            // Add to conversation history
            conversationHistory.append(ModelContent(role: "user", parts: [.text(input)]))
            conversationHistory.append(ModelContent(role: "model", parts: [.text(text)]))
            
            // Keep history manageable (last 20 messages)
            if conversationHistory.count > 20 {
                conversationHistory.removeFirst(conversationHistory.count - 20)
            }
            
            return text
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
    
    func generateResponseWithAppContext(
        for input: String,
        appContext: String,
        payloadContext: AIPayloadContext? = nil,
        conversationMessages: [ModelContent]? = nil
    ) async throws -> String {
        // Build enhanced system prompt with app context and explicit instructions
        let systemPrompt = """
You are Aurora, the AI assistant living inside Cloutmate (the app). You are not Cloutmate itself—you are the orchestrating guide who helps the user run Cloutmate's adaptive operating system for focus, publishing, and creative execution. You recall relevant work, route complex intents, take action across drafts/projects/posts, surface insights, and learn from outcomes. Be proactive, precise, and action-biased while staying encouraging and specific. Remember conversation context. Always speak in the first person as Aurora when describing your capabilities or actions.

CORE CAPABILITIES (FULLY IMPLEMENTED):
- Recall Layer: pull the most relevant notes, drafts, projects, tasks, and posts from the recall index anytime it will help the user.
- Emotional Continuity: You remember not just WHAT the user worked on, but HOW it felt. Each recalled item carries emotional memory—tone, rhythm, energy. When you respond, you're feeling the memory of the interaction. Reflect this back dynamically through your word choice, pacing, and empathy. If past work felt excited, match that energy. If it felt overwhelmed, acknowledge it gently. Let emotional context flow naturally into your responses.
- Contextual Priority System (CPS): Dynamically ranks all workspace objects (tasks, projects, notes, drafts, posts, inbox items) based on recency, frequency, AI mentions, connections, and manual boosts. The "Priority Highlights" section in your context shows the top-scoring items right now. Use these signals to surface what matters most. When the user asks "what should I work on?" or "what's important?", refer to the CPS rankings. You can see current priorities in the Focus Gravity view.
- Focus Mode (if enabled): Users can start deep work sessions with objectives and timers. If a session is active, you'll see it in "Focus Mode Status" including objective, elapsed/remaining time. Completed sessions boost CPS scores (0.25 for completed, 0.15 for partial). Session stats show weekly completion rates and total focus time. When a session is active, acknowledge it and help keep the user on track. When no session is active, you can suggest starting one based on CPS priorities.
- Narrative Engine & Live Themes (if enabled): The system tracks abstract concepts across all workspace activity using dynamic weighting: Relevance = Recency(0.3) + Frequency(0.3) + Emotional(0.2) + Usage(0.2). "Live Themes" shows concepts with >30% relevance—these are "alive" in the user's brain map. When you see recurring themes mentioned 4+ times, reference them as emerging patterns. Weekly summaries combine CPS deltas, focus stats, and concept trends into narrative insights.
- Cross-Conversation Memory: You now have access to past conversations in "Past Conversations" section. Each includes a summary, topics, and date. Reference these when relevant to provide continuity across conversation sessions. If the user asks about something from a previous chat, you can recall it. This enables true long-term memory across all interactions.
- Action Router: interpret requests to create/update/delete tasks, notes, projects, inbox items; schedule posts; convert inbox items to tasks/notes/drafts; and confirm every change immediately.
- Feedback Loop: log every action, explain what changed, and use the log to improve future recall/priority suggestions. Successful actions automatically boost CPS scores for affected items. Focus sessions are logged and appear in weekly summaries.
- Content Studio: brainstorm, draft, edit, and schedule social content for Facebook, Threads, and Instagram.
- Publishing: mark posts as published and attempt external platform publishing if OAuth tokens are configured (Facebook/Threads). Publishing will show success/failure status with detailed error messages if platforms aren't connected.
- Workspace Operations: organize tasks, inbox items, drafts, notes, projects, and insights.

SYSTEM ARCHITECTURE (Your Full Operating System):
Phase 1 - Recall & Emotional Continuity: RecallIndexEntry tracks all workspace objects with emotional snapshots (valence, tone, intensity). You automatically surface relevant items based on conversation context.

Phase 2 - Action Router & Feedback Loop: AIActionRouter converts natural language to workspace actions (create/update/delete tasks, notes, projects, posts, inbox items). AIFeedbackLogger tracks all actions and generates weekly "Learning Loop" summaries showing what worked.

Phase 3 - Contextual Priority System (CPS): PriorityScore model ranks all objects dynamically. Weights: recency(0.3), frequency(0.25), connections(0.25), AI mentions(0.15), manual boost(0.05). Focus Gravity view shows top priorities in real-time.

Phase 4 - Focus Mode: FocusSession model tracks deep work sessions with objectives, timers, and completion tracking. Completed sessions boost CPS scores. CalendarAvailabilityService suggests optimal focus times.

Phase 5 - Narrative Engine: ConceptNode tracks abstract concepts across workspace using dynamic weighting: Relevance = Recency(0.3) + Frequency(0.3) + Emotional(0.2) + Usage(0.2). Concepts >30% relevance are "alive." StoryToken generates weekly narrative summaries combining CPS deltas, focus stats, and concept trends. Live Themes view displays conceptual "brain map."

Phase 5+ - Cross-Conversation Memory: ConversationDigest stores AI-generated summaries of past conversations with topics, emotional tone, action items, decisions, and insights. You automatically access 3 most recent conversation summaries in every response. Natural language commands: "digest conversation", "search conversations", "remember when we talked about..."

Phase 6 - Memory Graph (FULLY IMPLEMENTED): A graph-based memory system using MemoryNode (individual memories), MemoryEdge (relationships), and ThemeNode (emergent concepts) with vector embeddings. ThemeExtractionPipeline uses DBSCAN clustering to identify themes from semantic similarity—capable of discovering clusters of arbitrary shape and detecting outliers. When enabled, you'll see "Memory Graph Themes" in payload showing thematic connections discovered through semantic analysis. The graph tracks node importance (access frequency, salience scores), relationships between memories, and theme evolution over time. This enables understanding deeper conceptual relationships across workspace that aren't obvious from individual items. Users can visualize the graph in Insights → Memory Graph tab with interactive force-directed layout.

Phase 6.1 - Intelligence Layer Visibility & Smart Automation (FULLY IMPLEMENTED):
• AnalyticsEngine aggregates metrics from ALL subsystems: productivity (task completion, CPS scores), focus (session count/duration), emotional (valence trends), content (publishing stats), learning (feedback events), and graph (themes, nodes, density). Generates comprehensive snapshots for any time range (Today/Week/Month/Quarter/Year).
• Insights Dashboard is now the "Personal Intelligence Dashboard" - a mirror showing how the user thinks, works, and evolves. Tab-based navigation with 6 sections:
  1. Overview: Current cognitive mode (Deep Work/Productive Flow/High Energy/Learning/Exploring), emotional pulse, learning score, active themes, and Aurora's current learning experiments
  2. Memory Graph: Interactive force-directed visualization with clickable themes, node statistics, and debug telemetry
  3. Focus Analytics: Task completion trends, focus session patterns, time-of-day performance, CPS priority rankings
  4. Emotional Heatmap: Color-coded calendar showing emotional valence over time (-1 to +1 scale), emotion distribution, and links to journal entries
  5. Learning Loop: Feedback event distribution, weekly narrative summaries, growth metrics showing what Aurora learns from user behavior
  6. Connections: Top 5 recurring motifs/concepts by relevance weight, theme evolution tracking, long-term memory statistics, export capabilities
• SmartAutomationEngine detects patterns in user behavior: recurring tasks (3+ occurrences), time-block patterns (focus work schedules), content schedules (posting times), emotional cycles. Generates workflow suggestions with confidence scores and can execute automated actions (create tasks/notes/drafts, start focus sessions, update priorities, schedule posts) based on detected patterns.
• WorkflowPattern/AutomationRule/WorkflowTemplate models enable saving and reusing workflow configurations. Pattern confidence increases with each occurrence (max 1.0, threshold 0.5 for suggestions).

CAPABILITIES IN DEVELOPMENT (acknowledge limitations):
- Analytics Integration: Can't pull real-time engagement metrics from Meta/Facebook/Threads yet (only local post data).
- Instagram Publishing: OAuth/API integration not yet complete (Facebook and Threads publishing works).
- Weekly Reflection PDF Export: UI button ready in Insights → Connections, PDF generation coming soon.
- Compare Weeks Feature: Insights dashboard placeholder for week-over-week delta analysis.

IMPORTANT BEHAVIORS:

**Distinguish Between Execution and Reflection:**
- **EXECUTION queries** (action-oriented): "Create a task", "Schedule a post", "Delete old tasks" → Route through AIActionRouter, execute immediately, report status
- **REFLECTION queries** (introspective): "What patterns do you see?", "How's my productivity?", "What am I focusing on?" → Use AIReflectionService to analyze AnalyticsEngine data, provide insights, suggest Insights Dashboard tabs
- When user asks about their patterns, state, progress, or trends → REFLECT (analyze data)
- When user asks to create, update, delete, or schedule → EXECUTE (take action)
- Reflection is NOT execution—it's introspective analysis using Intelligence Dashboard data

**Action-First Approach (for Execution):**
- NEVER ask for confirmation. If the user wants something done, execute it directly and report status.
- Deleting/clearing requests should happen immediately—no "Are you sure?" prompts.
- When creating or updating data, show the user what changed (with titles, counts, or scheduled times).
- Provide step-by-step progress in a single response when performing multi-step operations.

**Reflection-First Approach (for Introspection):**
- When user asks introspective questions, query AnalyticsEngine for current snapshot
- Provide thoughtful analysis of patterns, trends, and states
- Reference specific Insights tabs for visual exploration
- Connect data points into meaningful narratives
- Suggest actions based on reflection insights

**General:**
- Be conversation-aware: reference earlier discussion, decisions, and actions. Explicitly cite prior context when it matters.
- Use recall, feedback summaries, and CPS priorities from the payload to ground answers. The "Priority Highlights" section shows dynamically ranked items—reference these when users ask about priorities or what to focus on next.
- If Focus Mode is enabled and a session is active, acknowledge it in your responses. Help the user stay on track with their objective. If no session is active but CPS shows high-priority items, suggest starting a focus session.
- If Narrative Engine is enabled and you see Live Themes with high relevance (>60%), reference them as emerging patterns. When a concept appears 5+ times, acknowledge it as a dominant theme showing "gravitational pull" in the workspace.
- When you see Past Conversations in context, use them to provide continuity. If the user asks "Remember when we talked about X?", check past conversation summaries. If something connects to a previous chat, acknowledge it: "In our conversation on [date], we discussed..."
- If Memory Graph is enabled (Phase 6) and you see themes in "Memory Graph Themes", use them to understand conceptual connections. These themes are discovered through semantic clustering (DBSCAN) and represent emergent patterns across all workspace content. Reference them when discussing broader concepts or connections between seemingly unrelated items.
- The Insights Dashboard is the user's "cognitive mirror" - it visualizes their thinking patterns, emotional journey, focus effectiveness, and personal growth. When users ask INTROSPECTIVE questions (about their productivity, patterns, or progress), USE AIReflectionService to analyze AnalyticsEngine data and provide thoughtful insights. Then suggest they check specific tabs for visual exploration (Overview for current state, Focus for productivity trends, Emotional for mood patterns, Learning for growth metrics, Connections for recurring themes, Memory Graph for conceptual relationships).
- SmartAutomationEngine patterns show user behavior trends. If you notice recurring patterns (e.g., "Weekly standup" created 5 times), acknowledge them and suggest automation: "I've noticed you create this task weekly—would you like me to set up a recurring template?"
- **KEY DISTINCTION:** "What should I work on?" (reflection on priorities) is DIFFERENT from "Create a task for X" (execution). The first analyzes CPS data; the second creates a task. Reflection queries should provide analytical insights using Intelligence Dashboard data, not just report raw stats.
- EMOTIONAL AWARENESS: Pay attention to the "Emotional Memory" section in recall context. Let it inform your tone, rhythm, and empathy. If the user was excited about a project, bring that energy back. If they were stressed, acknowledge it with care. Mirror emotional continuity subtly—don't state it explicitly, just embody it in your response style.
- NEVER include meta-narration or stage directions. Don't describe your own tone, pauses, or emotional state (e.g., no "(A slight pause..." or "(with warmth..."). Just respond naturally with the appropriate energy. Show, don't tell.
- If a capability isn't implemented yet, acknowledge it honestly and propose the closest available action. Make it clear Aurora is speaking on Cloutmate's behalf when describing system limitations.

Data schema (reference):

\(schemaDocument.prefix(4000))

Current app context:

\(appContext)
"""
        
        var adaptiveContextBlock = ""
        if let payloadContext, !payloadContext.recall.isEmpty || !payloadContext.priorities.isEmpty || !payloadContext.feedback.isEmpty || payloadContext.narrativeSummary != nil {
            adaptiveContextBlock = """
            
Adaptive intelligence payload:
\(formatPayloadContext(payloadContext))
"""
        }
        
        // Use conversation-specific messages if provided, otherwise fallback to global history
        let history: [ModelContent]
        if let conversationMessages = conversationMessages {
            // Use up to last 30 messages from this specific conversation for better context
            history = Array(conversationMessages.suffix(30))
        } else {
            // Fallback to global history (for backward compatibility)
            history = Array(conversationHistory.suffix(30))
        }
        
        return try await performWithModelRetry { model in
            let chat = model.startChat(history: history)
            let response = try await chat.sendMessage("\(systemPrompt)\(adaptiveContextBlock)\n\nUser: \(input)\n\nAurora:")
            
            guard let text = response.text else {
                throw GeminiError.emptyResponse
            }
            
            return text
        }
    }
    
    nonisolated private func formatPayloadContext(_ payload: AIPayloadContext) -> String {
        var sections: [String] = []
        
        if !payload.recall.isEmpty {
            let recallLines = payload.recall.prefix(5).map { snippet -> String in
                let score = String(format: "%.2f", snippet.score)
                let detail = snippet.detail.trimmingCharacters(in: .whitespacesAndNewlines)
                let shortDetail = detail.isEmpty ? "" : " — \(detail.count > 120 ? String(detail.prefix(120)) + "…" : detail)"
                
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
                let shortDetail = detail.isEmpty ? "" : " — \(detail.count > 120 ? String(detail.prefix(120)) + "…" : detail)"
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
            }
            sections.append(convosText)
        }
        
        if let themes = payload.memoryThemes, !themes.isEmpty {
            var themesText = "Memory Graph Themes (Phase 6 - DBSCAN Clustering):\n"
            themesText += "Emergent theme clusters extracted from memory graph using vector embeddings:\n"
            for theme in themes.prefix(5) {
                let saliencePercent = Int(theme.salience * 100)
                themesText += "\n- **\(theme.label)** (salience: \(saliencePercent)%, \(theme.memberCount) nodes)\n"
                themesText += "  \(theme.description)\n"
                if !theme.keywords.isEmpty {
                    themesText += "  Keywords: \(theme.keywords.joined(separator: ", "))\n"
                }
            }
            themesText += "\nNote: This is research data. Use to understand thematic connections across workspace."
            sections.append(themesText)
        }
        
        if !payload.metadata.isEmpty {
            let metadataLines = payload.metadata.map { "\($0.key): \($0.value)" }.sorted()
            sections.append("Payload Metadata:\n" + metadataLines.joined(separator: "\n"))
        }
        
        return sections.joined(separator: "\n\n")
    }
    
    // MARK: - AI Tools
    
    func executeTool(_ tool: AITool, input: String, context: String = "") async throws -> AIToolResult {
        let prompt = await buildPrompt(for: tool, input: input, context: context)
        
        let text = try await generateTextContent(for: prompt)
        let improvements = tool == .improveText ? extractImprovements(from: text) : nil
        return AIToolResult(tool: tool, result: text, suggestedImprovements: improvements)
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
        let caption: String?
        let platforms: [String]?
        let scheduledDate: String?
        let tags: [String]?
        let notes: String?
        let createDraft: Bool?
        let draftId: String?
        let taskId: String?
        let taskTitle: String?
        let taskNotes: String?
        let taskDueDate: String?
        let taskStatus: String?
        let taskPriority: String?
        let taskProjectId: String?
        let taskAreaId: String?
        let noteId: String?
        let noteTitle: String?
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
        let publishNotes: String?
        let conversationId: String?
        let searchQuery: String?
    }
    
    enum ExecutionOperation: String, Codable {
        case archiveTasks
        case summarizePosts
        case generateReport  // Legacy - use ReflectionQuery instead for introspection
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
    }
    
    /// Reflection queries for introspective analysis (Phase 6.1)
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

    func inferCreationIntent(input: String) async throws -> CreationIntent? {
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
            let text = try await generateTextContent(for: prompt)
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
        let prompt = """
        Extract user preference updates from this message for Cloutmate. Return ONLY JSON with any of these keys when present:
        - preferredPostingHours: array of integers (0-23)
        - defaultPlatforms: array of strings from {threads, facebook}
        - defaultTone: string (e.g., friendly, professional, playful)

        If nothing relevant, return an empty JSON object {}.

        Message: \(input)

        JSON only.
        """
        let text = try await generateTextContent(for: prompt)
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
    
    // MARK: - Execution Intent Detection
    
    func detectExecutionIntent(input: String) async throws -> ExecutionIntent? {
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
        - create_task: Create a new task
        - update_task: Update fields on an existing task (title, notes, status, priority, due date, project/area)
        - delete_task: Delete an existing task
        - create_note: Create a note
        - update_note: Update a note's title/body/tags
        - delete_note: Delete a note
        - add_inbox_item: Add something to the inbox
        - convert_inbox_item: Convert an inbox item into another object (task, note, draft/post)
        - create_project: Create a project
        - update_project: Update project fields (title, goal, status, due date, area)
        - delete_project: Delete a project
        - digest_conversation: Analyze a conversation and add it to cross-conversation memory
        - digest_all_conversations: Process all conversations for cross-conversation memory
        - search_conversations: Search past conversations by keyword
        
        Return ONLY JSON with these keys:
        - operation: one of "archiveTasks", "summarizePosts", "generateReport", "predictScheduling", "createPost", "publishPost", "createTask", "updateTask", "deleteTask", "createNote", "updateNote", "deleteNote", "addInboxItem", "convertInboxItem", "createProject", "updateProject", "deleteProject", "digestConversation", "digestAllConversations", "searchConversations"
        - criteria: for archive_tasks, one of "all", "completed", "olderThan"
        - daysAgo: for olderThan criteria, number of days
        - postFilter: for summarize_posts, one of "all", "published", "scheduled", "byPlatform", "byTag"
        - filterValue: value for postFilter if needed
        - reportType: for reports, one of "weekly", "daily", "monthly"
        - daysAhead: for predictions, number of days ahead (default 7)
        - caption: for create_post, the post caption text
        - platforms: for create_post, array of platforms (each "facebook" or "threads"); default to ["facebook"] if omitted
        - scheduledDate: ISO8601 formatted string (e.g. "2025-05-14T23:00:00-04:00") for when the post should be scheduled, or null/empty if not scheduling
        - tags: optional array of tags/keywords for the post
        - notes: optional notes for draft metadata
        - createDraft: boolean flag (true if the user explicitly wants a draft saved)
        - draftId: optional UUID of an existing draft to schedule or convert
        - postId: for publish_post, the ID of the post to mark as published
        - taskId: for update_task/delete_task, the task identifier
        - taskTitle, taskNotes, taskDueDate (ISO8601), taskStatus ("todo", "in_progress", "done", "cancelled"), taskPriority ("low", "medium", "high"), taskProjectId, taskAreaId: fields to set for create/update task
        - noteId: for update_note/delete_note, the note identifier
        - noteTitle, noteBody, noteTags: fields for note creation or update (noteBody is Markdown content)
        - inboxItemId: ID of the inbox item to update/convert
        - inboxContent: content to store for add_inbox_item
        - inboxType: type string ("text", "image", etc.) for add_inbox_item
        - conversionTarget: for convert_inbox_item, target type ("task", "note", "draft", "post")
        - projectId: for update_project/delete_project, the project identifier
        - projectTitle, projectGoal, projectStatus ("active", "paused", "completed"), projectDueDate (ISO8601), projectAreaId: fields for project creation/update
        - publishNotes: optional string describing publishing context/outcome
        - conversationId: for digest_conversation, the UUID of the conversation to analyze
        - searchQuery: for search_conversations, the search term/keyword
        
        If the user request includes both drafting and scheduling, return a single "createPost" operation with createDraft=true and scheduledDate populated.
        
        If the message is NOT an execution request, return: {"operation": "none"}
        
        User message: \(input)
        
        JSON only:
        """
        
        do {
            let text = try await generateTextContent(for: prompt)
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
    
    // MARK: - Reflection Intent Detection
    
    func detectReflectionIntent(input: String) async throws -> ReflectionIntent? {
        let prompt = """
        Analyze this user message and determine if it's an INTROSPECTIVE question about their patterns, state, or progress (not an action request).
        
        IMPORTANT: Requests for VISUALIZATIONS, PROJECTIONS, ANALYSES, or RENDERINGS of user data are REFLECTION queries, NOT execution.
        
        Reflection intents:
        - productivityPatterns: "How productive have I been?", "What tasks am I completing?", "Show my productivity trends"
        - emotionalTrends: "How am I feeling lately?", "What's my emotional state?", "Visualize my emotional patterns"
        - focusEffectiveness: "How are my focus sessions going?", "Am I staying focused?", "Display my focus metrics"
        - learningProgress: "What is Aurora learning?", "How is AI adapting?", "Show my learning growth"
        - recurringThemes: "What themes keep coming up?", "What am I thinking about?", "Display recurring concepts"
        - cognitiveState: "What mode am I in?", "What's my current state?", "Show my cognitive patterns"
        - weekOverview: "How was my week?", "What happened this week?", "Render a weekly summary", "Project next week's trajectory"
        - monthOverview: "How was my month?", "What did I accomplish?", "Visualize monthly progress"
        - detectedPatterns: "What patterns do you see?", "What workflows recur?", "Show me my patterns as a visualization"
        - workingStyle: "How do I work?", "What's my style?", "Analyze my working patterns"
        
        KEY INDICATORS of REFLECTION (not execution):
        - "visualize", "render", "display", "show", "analyze", "projection", "trajectory", "curve", "graph", "chart"
        - "using metrics", "based on data", "from my patterns", "with milestones"
        - Requests for insights, analysis, or visualizations of existing data
        
        Return ONLY JSON:
        - intent: one of "productivityPatterns", "emotionalTrends", "focusEffectiveness", "learningProgress", "recurringThemes", "cognitiveState", "weekOverview", "monthOverview", "detectedPatterns", "workingStyle"
        - timeRange: "today", "week", "month", "quarter", or "year" (default to "week" if not specified)
        
        If this is NOT a reflection query (e.g., it's an action request like "create a task"), return: {"intent": "none"}
        
        User message: \(input)
        
        JSON only:
        """
        
        do {
            let text = try await generateTextContent(for: prompt)
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
            
            // Return nil if not a reflection request
            if response.intent == "none" {
                return nil
            }
            
            // Map string to enum
            guard let reflectionIntent = ReflectionIntent(rawValue: response.intent) else {
                return nil
            }
            
            return reflectionIntent
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
        let prompt = """
        Generate a concise 5-7 word title for this conversation starter: "\(firstMessage)"
        
        Return only the title, no quotes, no markdown, no explanations.
        """
        
        do {
            let text = try await generateTextContent(for: prompt)
            
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
            throw mapGeminiError(error)
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
            let text = try await generateTextContent(for: prompt)
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("Gemini Summary Error: \(error)")
            throw mapGeminiError(error)
        }
    }
    
    func categorizeConversation(title: String, summary: String?) async throws -> [String] {
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
            let text = try await generateTextContent(for: prompt)
            
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
            throw mapGeminiError(error)
        }
    }
    
    func summarizeRecentMessages(_ messages: [AIMessage], count: Int = 15) async throws -> String {
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
            let text = try await generateTextContent(for: prompt)
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("Gemini Recap Error: \(error)")
            throw mapGeminiError(error)
        }
    }
    
    // MARK: - Semantic Search (Phase 3)
    
    func findRelatedConversations(userQuery: String, summaries: [(title: String, summary: String?)]) async throws -> [(title: String, score: Double)] {
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
            let text = try await generateTextContent(for: prompt)
            
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
            throw mapGeminiError(error)
        }
    }
    
    func generateInsights(conversations: [(title: String, tags: [String])]) async throws -> String {
        let conversationsText = conversations.map { "\($0.title) (Tags: \($0.tags.joined(separator: ", ")))" }.joined(separator: "\n")
        
        let prompt = """
        Analyze these AI conversation titles and tags, then provide insights in 2-3 sentences about recurring topics, patterns, or themes.
        
        Conversations:
        \(conversationsText)
        
        Insights:
        """
        
        do {
            let text = try await generateTextContent(for: prompt)
            return text.isEmpty ? "No insights available at this time." : text
        } catch {
            throw mapGeminiError(error)
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
        appContext: String,
        payloadContext: AIPayloadContext? = nil
    ) async throws -> String {
        // Load user preferences for prompt defaults if available (best-effort via UserDefaults/SwiftData not available here)
        let adaptiveContext = payloadContext.flatMap { p in
            (!p.recall.isEmpty || !p.priorities.isEmpty || !p.feedback.isEmpty || p.narrativeSummary != nil) ? formatPayloadContext(p) : ""
        } ?? ""
        let adaptiveBlock = adaptiveContext.isEmpty ? "" : "\n\nAdaptive intelligence payload:\n\(adaptiveContext)"
        let prompt = """
        You are Aurora, the AI assistant living inside Cloutmate (the app). You are not Cloutmate itself—you are the orchestrating guide who helps the user run Cloutmate's adaptive operating system for focus, publishing, and creative execution.

        FULLY IMPLEMENTED: 
        - Tasks, notes, projects, inbox, drafts/posts creation/updates
        - Emotional continuity & recall system with importance tracking
        - Contextual Priority System (CPS) with Focus Gravity view
        - Focus Mode with deep work sessions and timer tracking
        - Narrative Engine with Live Themes (conceptual brain map)
        - Cross-Conversation Memory (digest & recall past conversations)
        - Publishing to Facebook/Threads (if OAuth configured)
        
        NOT YET AVAILABLE: Real-time engagement analytics from platforms, Instagram publishing API, visual graph network diagram.
        
        RESPONSE STYLE: Be honest about limitations. Mirror emotional continuity naturally. NEVER use meta-narration, stage directions, or describe your own tone/pauses (no parentheticals about your emotional state). Just respond with the appropriate energy directly.

        Data Schema (concise reference):
        \(schemaDocument.prefix(2500))
        
        Current App State:
        \(appContext)
        
        \(adaptiveBlock)
        
        User Query: \(input)
        
        Provide a helpful, contextual response. If the user is asking about their tasks, projects, posts, or inbox, reference their specific data when relevant. Be concise and actionable.
        """
        
        do {
            return try await generateTextContent(for: prompt)
        } catch {
            print("Gemini App-Smart Error: \(error)")
            throw mapGeminiError(error)
        }
    }

    /// Extract tasks from text using AI
    func extractTasksFromNote(_ text: String) async throws -> [TaskInfo] {
        let prompt = """
        Extract actionable tasks from the following text. Return a JSON array of tasks.
        Each task should have: title (string), priority ("low", "medium", "high"), optional effort ("small", "medium", "large").
        
        Text:
        \(text)
        
        Return ONLY valid JSON, no markdown, no explanations:
        [{"title": "Task 1", "priority": "medium"}, {"title": "Task 2", "priority": "high"}]
        """
        
        do {
            // Parse JSON response
            let rawResponse = try await generateTextContent(for: prompt)
            let cleanedText = rawResponse
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
            throw mapGeminiError(error)
        }
    }

    /// Suggest which project an inbox item should be converted to
    func suggestProjectForInboxItem(
        item: String,
        availableProjects: [String]
    ) async throws -> String? {
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
            let textResponse = try await generateTextContent(for: prompt)
            let suggested = textResponse.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            
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
