//
//  AuroraSpotlightView.swift
//  FocusOS
//
//  Spotlight-style overlay for Aurora quick access
//

import SwiftUI
import SwiftData
import AppKit
import FocusOSShared

struct AuroraSpotlightView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @State private var query: String = ""
    @State private var suggestions: [SpotlightSuggestion] = []
    @State private var feedbackMessage: String?
    @State private var feedbackIcon: String?
    @State private var isProcessing = false
    
    @FocusState private var isInputFocused: Bool
    
    private let commandParser = SpotlightCommandParser.shared
    private let suggestionsEngine = SpotlightSuggestionsEngine.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding(.top, 28)
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
            
            // Input field with suggestions
            VStack(spacing: 0) {
                // Result toast (if present)
                if let feedback = feedbackMessage {
                    SpotlightResultToast(
                        message: feedback,
                        systemImage: feedbackIcon
                    )
                    .padding(.horizontal, 28)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Input field
                inputField
                    .padding(.horizontal, 28)
                    .padding(.bottom, 16)
                
                // Suggestions list
                if !suggestions.isEmpty && !isProcessing {
                    SpotlightSuggestionsList(suggestions: suggestions) { suggestion in
                        // Execute asynchronously to avoid blocking UI
                        _Concurrency.Task { @MainActor in
                            query = suggestion.text
                            executeSuggestion(suggestion)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 16)
                }
            }
            
            // Footer
            footerView
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
        }
        .frame(width: 600)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(glassColorSystem.cardColor().opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(glassColorSystem.borderColor().opacity(0.2), lineWidth: 0.8)
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: 15)
        .onAppear {
            // Auto-focus input on open
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFocused = true
            }
            
            // Load initial suggestions
            updateSuggestions()
        }
        .onDisappear {
            // Clean up any pending async operations
            isInputFocused = false
            isProcessing = false
            query = ""
            suggestions = []
            feedbackMessage = nil
            feedbackIcon = nil
        }
        .onChange(of: query) { _, newValue in
            updateSuggestions()
        }
        .onKeyPress(.escape) {
            AuroraSpotlightWindowController.shared.close()
            return .handled
        }
        .onKeyPress(.return) {
            if !query.isEmpty {
                executeCommand(query)
            }
            return .handled
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Aurora Spotlight")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                Text("Ask, command, or reflect")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
            }
            
            Spacer()
        }
    }
    
    // MARK: - Input Field
    
    private var inputField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(glassColorSystem.emotionalAccent())
                .font(.system(size: 16, weight: .medium))
                .frame(width: 20)
            
            TextField("Ask, command, or reflect…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(glassColorSystem.textPrimary())
                .focused($isInputFocused)
                .onSubmit {
                    if !query.isEmpty {
                        executeCommand(query)
                    }
                }
            
            if isProcessing {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(glassColorSystem.emotionalAccent())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(glassColorSystem.cardColor().opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            isInputFocused ? glassColorSystem.emotionalAccent().opacity(0.4) : glassColorSystem.borderColor().opacity(0.2),
                            lineWidth: isInputFocused ? 1.5 : 0.8
                        )
                )
        )
        .shadow(
            color: isInputFocused ? glassColorSystem.emotionalAccent().opacity(0.2) : .clear,
            radius: isInputFocused ? 12 : 0
        )
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack {
            Text("Press ⌘⇧A to open")
                .font(.caption)
                .foregroundStyle(glassColorSystem.textTertiary())
            Spacer()
            Text("ESC to close")
                .font(.caption)
                .foregroundStyle(glassColorSystem.textTertiary())
        }
    }
    
    
    // MARK: - Suggestions Update
    
    private func updateSuggestions() {
        suggestions = suggestionsEngine.generateSuggestions(
            query: query,
            modelContext: modelContext
        )
    }
    
    // MARK: - Suggestion Execution
    
    @MainActor
    private func executeSuggestion(_ suggestion: SpotlightSuggestion) {
        query = "" // Clear input immediately
        isInputFocused = false
        
        // Handle suggestions directly based on category to avoid incorrect parsing
        switch suggestion.category {
        case .navigation:
            // Direct navigation - use tabIdentifier from suggestion
            if let tab = suggestion.tabIdentifier {
                isProcessing = false // Navigation is instant
                handleNavigation(tab)
            } else {
                // Fallback to parsing if tabIdentifier is missing
                executeCommand(suggestion.text)
            }
            
        case .task:
            // Open task - navigate to tasks tab and select the task
            if let taskId = suggestion.taskId {
                isProcessing = false // Task opening is instant
                
                // Navigate to tasks tab
                NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.tasks)
                
                // Post notification to select the task
                NotificationCenter.default.post(
                    name: NSNotification.Name("SelectTask"),
                    object: taskId
                )
                
                feedbackMessage = "Opening task"
                feedbackIcon = "checkmark.circle.fill"
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    AuroraSpotlightWindowController.shared.close()
                }
            } else {
                // Fallback to parsing
                executeCommand(suggestion.text)
            }
            
        case .command, .query:
            // Commands and queries go through normal parsing (which sets isProcessing)
            executeCommand(suggestion.text)
        }
    }
    
    // MARK: - Command Execution
    
    @MainActor
    private func executeCommand(_ input: String) {
        guard !input.isEmpty else { return }
        
        isProcessing = true
        query = "" // Clear input immediately
        isInputFocused = false
        
        // Store modelContext in local variable to capture it safely
        let context = modelContext
        
        // Create Task without inheriting MainActor context to avoid deadlock
        _Concurrency.Task { @MainActor in
            
            // Parse intent
            let intent = await commandParser.parse(input, modelContext: context)
            
            // Handle intent
            await self.handleIntent(intent, originalInput: input)
        }
    }
    
    @MainActor
    private func handleIntent(_ intent: SpotlightIntent, originalInput: String) async {
        isProcessing = false
        
        switch intent {
        case .execution(let executionIntent):
            await handleExecution(executionIntent, originalInput: originalInput)
            
        case .reflection(let reflectionIntent):
            await handleReflection(reflectionIntent, originalInput: originalInput)
            
        case .navigation(let tab):
            handleNavigation(tab)
            
        case .ritual(let ritualCommand):
            handleRitual(ritualCommand)
            
        case .dataSearch(let query):
            await handleDataSearch(query, originalInput: originalInput)
            
        case .memoryQuery(let query):
            handleMemoryQuery(query, originalInput: originalInput)
            
        case .unknown(let text):
            // Route to AI Assistant for conversational handling
            handleUnknown(text)
        }
    }
    
    @MainActor
    private func handleExecution(_ intent: ExecutionIntent, originalInput: String) async {
        // Capture modelContext safely
        let context = modelContext
        
        do {
            // Convert intent to action, handling errors gracefully
            guard let action = intent.toAIIntentAction() else {
                // If conversion fails, route to AI Assistant for handling
                handleUnknown(originalInput)
                return
            }
            
            let result = try await AIActionRouter.shared.route(
                action,
                modelContext: context
            )
            
            // Show feedback (already on MainActor)
            await MainActor.run {
                self.feedbackMessage = result.message
                self.feedbackIcon = "checkmark.circle.fill"
            }
            
            // Log to AI Assistant
            await MainActor.run {
                self.logToAIAssistant(userMessage: originalInput, assistantMessage: result.message)
            }
            
            // Auto-close after showing feedback
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                AuroraSpotlightWindowController.shared.close()
            }
        } catch {
            await MainActor.run {
                self.feedbackMessage = "Failed to execute: \(error.localizedDescription)"
                self.feedbackIcon = "exclamationmark.circle.fill"
            }
        }
    }
    
    @MainActor
    private func handleReflection(_ intent: ReflectionIntent, originalInput: String) async {
        // Capture modelContext safely
        let context = modelContext
        
        let response = await AIReflectionService.shared.reflect(
            on: intent,
            timeRange: .thisWeek,
            modelContext: context
        )
        
        // Update UI (already on MainActor)
        await MainActor.run {
            self.feedbackMessage = String(response.prefix(100)) + (response.count > 100 ? "..." : "")
            self.feedbackIcon = "brain.head.profile"
        }
        
        // Log to AI Assistant
        await MainActor.run {
            self.logToAIAssistant(userMessage: originalInput, assistantMessage: response)
        }
        
        // Auto-close after showing feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            AuroraSpotlightWindowController.shared.close()
        }
    }
    
    @MainActor
    private func handleNavigation(_ tab: TabIdentifier) {
        NotificationCenter.default.post(name: .switchTab, object: tab)
        feedbackMessage = "Navigated to \(tab.rawValue)"
        feedbackIcon = tab.icon
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            AuroraSpotlightWindowController.shared.close()
        }
    }
    
    @MainActor
    private func handleRitual(_ command: RitualCommand) {
        let ritualManager = FocusRitualManager.shared
        
        // Find the appropriate ritual
        let ritualType: FocusRitualType
        switch command {
        case .startMorning:
            ritualType = .morning
        case .startEvening:
            ritualType = .evening
        case .startFocusSession:
            // For focus sessions, navigate to Focus Mode tab
            NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.focusMode)
            feedbackMessage = "Opening Focus Mode"
            feedbackIcon = "timer"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                AuroraSpotlightWindowController.shared.close()
            }
            return
        }
        
        // Find ritual
        let descriptor = FetchDescriptor<FocusRitual>(
            predicate: #Predicate { $0.typeRaw == ritualType.rawValue }
        )
        
        if let ritual = try? modelContext.fetch(descriptor).first {
            ritualManager.triggerRitual(ritual, modelContext: modelContext)
            feedbackMessage = "\(ritualType == .morning ? "☀️ Morning" : "🌙 Evening") Ritual started"
            feedbackIcon = ritualType == .morning ? "sunrise.fill" : "moon.stars.fill"
            
            // Navigate to Rituals tab
            NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.rituals)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                AuroraSpotlightWindowController.shared.close()
            }
        } else {
            feedbackMessage = "Ritual not found"
            feedbackIcon = "exclamationmark.circle.fill"
        }
    }
    
    @MainActor
    private func handleDataSearch(_ query: String, originalInput: String) async {
        // Capture modelContext safely
        let context = modelContext
        
        let results = WorkspaceObjectSearchService.shared.search(
            query: query,
            modelContext: context,
            limit: 10
        )
        
        // Update UI (already on MainActor)
        await MainActor.run {
            if results.isEmpty {
                self.feedbackMessage = "No results found"
                self.feedbackIcon = "magnifyingglass"
            } else {
                self.feedbackMessage = "Found \(results.count) result\(results.count == 1 ? "" : "s")"
                self.feedbackIcon = "magnifyingglass"
            }
        }
        
        // Log to AI Assistant with results
        if !results.isEmpty {
            let resultsText = results.prefix(5).map { "- \($0.title)" }.joined(separator: "\n")
            await MainActor.run {
                self.logToAIAssistant(
                    userMessage: originalInput,
                    assistantMessage: "Found \(results.count) results:\n\(resultsText)"
                )
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            AuroraSpotlightWindowController.shared.close()
        }
    }
    
    @MainActor
    private func handleMemoryQuery(_ query: String, originalInput: String) {
        // For now, route to AI Assistant for memory queries
        // This can be enhanced later with MemoryGraphService integration
        handleUnknown(originalInput)
    }
    
    @MainActor
    private func handleUnknown(_ text: String) {
        // Route to AI Assistant tab and send message
        NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.aiAssistant)
        
        // Post notification to send message to AI Assistant
        NotificationCenter.default.post(
            name: NSNotification.Name("SpotlightAIMessage"),
            object: text
        )
        
        feedbackMessage = "Opening AI Assistant"
        feedbackIcon = "sparkles"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            AuroraSpotlightWindowController.shared.close()
        }
    }
    
    // MARK: - AI Assistant Logging
    
    @MainActor
    private func logToAIAssistant(userMessage: String, assistantMessage: String) {
        // Create messages in AI Assistant conversation
        let userMsg = AIMessage(role: "user", content: userMessage)
        let assistantMsg = AIMessage(role: "assistant", content: assistantMessage)
        
        modelContext.insert(userMsg)
        modelContext.insert(assistantMsg)
        
        // Try to add to current conversation
        var descriptor = FetchDescriptor<AIConversation>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        
        if let conversation = try? modelContext.fetch(descriptor).first {
            conversation.messages?.append(userMsg)
            conversation.messages?.append(assistantMsg)
        } else {
            // Create new conversation
            let conversation = AIConversation(title: "Spotlight Actions")
            conversation.messages = [userMsg, assistantMsg]
            modelContext.insert(conversation)
        }
        
        try? modelContext.save()
    }
}

// Content-only view (without backdrop) for the draggable panel
struct AuroraSpotlightContentView: View {
    var body: some View {
        AuroraSpotlightView()
    }
}

// MARK: - ExecutionIntent Extension

extension ExecutionIntent {
    func toAIIntentAction() -> AIIntentAction? {
        switch operation {
        case .createTask:
            guard let title = taskTitle, !title.isEmpty else {
                return nil
            }
            let request = TaskCreationRequest(
                title: title,
                notes: taskNotes,
                dueDate: DateParsing.parse(taskDueDate),
                status: mapTaskStatus(taskStatus) ?? .todo,
                priority: mapTaskPriority(taskPriority) ?? .medium,
                projectId: taskProjectId.flatMap(UUID.init(uuidString:)),
                areaId: taskAreaId.flatMap(UUID.init(uuidString:))
            )
            return .createTask(request)
            
        case .createNote:
            guard let title = noteTitle, !title.isEmpty else {
                return nil
            }
            let request = NoteMutationRequest(
                noteId: nil,
                title: title,
                body: noteBody ?? "",
                tags: noteTags ?? []
            )
            return .createNote(request)
            
        case .createProject:
            guard let title = projectTitle, !title.isEmpty else {
                return nil
            }
            let request = ProjectCreationRequest(
                title: title,
                goal: projectGoal,
                status: mapProjectStatus(projectStatus) ?? .active,
                dueDate: DateParsing.parse(projectDueDate),
                areaId: projectAreaId.flatMap(UUID.init(uuidString:)),
                tags: []
            )
            return .createProject(request)
            
        default:
            // For other operations, return nil to route to AI Assistant
            // Full implementation would handle all operations
            return nil
        }
    }
    
    private func mapTaskStatus(_ status: String?) -> FocusOSShared.TaskStatus? {
        guard let status = status else { return nil }
        switch status.lowercased() {
        case "todo", "pending": return .todo
        case "inprogress", "in progress": return .inProgress
        case "done", "completed": return .done
        default: return nil
        }
    }
    
    private func mapTaskPriority(_ priority: String?) -> FocusOSShared.TaskPriority? {
        guard let priority = priority?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        let cleaned = priority
            .replacingOccurrences(of: "priority", with: "")
            .replacingOccurrences(of: "priroty", with: "")
            .replacingOccurrences(of: "set to", with: "")
            .replacingOccurrences(of: "set for", with: "")
            .replacingOccurrences(of: "set", with: "")
            .replacingOccurrences(of: "to", with: "")
            .replacingOccurrences(of: "with a", with: "")
            .replacingOccurrences(of: "with", with: "")
            .replacingOccurrences(of: "at", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        switch cleaned {
        case "low": return .low
        case "medium", "normal", "med": return .medium
        case "high", "urgent", "hi": return .high
        default: return nil
        }
    }
    
    private func mapProjectStatus(_ status: String?) -> FocusOSShared.ProjectStatus? {
        guard let status = status else { return nil }
        switch status.lowercased() {
        case "active": return .active
        case "paused", "onhold", "on hold": return .paused
        case "completed": return .completed
        default: return nil
        }
    }
    
    private func parseISODate(_ dateString: String) -> Date? {
        DateParsing.parse(dateString)
    }
}

#Preview {
    AuroraSpotlightView()
        .modelContainer(for: [AIConversation.self, AIMessage.self])
        .environmentObject(GlassColorSystem())
}
