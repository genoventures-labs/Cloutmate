//
//  AuroraSpotlightView.swift
//  Cloutmate
//
//  Spotlight-style overlay for Aurora quick access
//

import SwiftUI
import SwiftData
import AppKit
import CloutmateShared

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
                .padding(.top, 24)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            
            // Input field with suggestions
            VStack(spacing: 0) {
                // Result toast (if present)
                if let feedback = feedbackMessage {
                    SpotlightResultToast(
                        message: feedback,
                        systemImage: feedbackIcon
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Input field
                inputField
                    .padding(.horizontal, 24)
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
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
            }
            
            // Footer
            footerView
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
        }
        .frame(width: 600)
        .background(
            // Use a solid background layer first to prevent backdrop showing through rounded corners
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .background(
                    // Solid opaque layer behind material to ensure corners are covered
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.8))
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
        .onAppear {
            // Auto-focus input on open
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFocused = true
            }
            
            // Load initial suggestions
            updateSuggestions()
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
        VStack(spacing: 8) {
            Text("Aurora Spotlight")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Gradient underline
            Rectangle()
                .fill(arteGradient)
                .frame(height: 2)
                .frame(maxWidth: 120)
        }
    }
    
    // MARK: - Input Field
    
    private var inputField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.kosmicBlue)
                .font(.title3)
            
            TextField("Ask, command, or reflect…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(.title3, design: .rounded))
                .focused($isInputFocused)
                .onSubmit {
                    if !query.isEmpty {
                        executeCommand(query)
                    }
                }
            
            if isProcessing {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
        .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            isInputFocused ? arteGradient : LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing),
                            lineWidth: isInputFocused ? 2 : 0
                        )
                )
        )
        .shadow(
            color: isInputFocused ? arteGradientColor.opacity(0.3) : Color.clear,
            radius: isInputFocused ? 8 : 0
        )
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack {
            Text("Press ⌘⇧A to open")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text("ESC to close")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - ARTE Gradient
    
    private var arteGradient: LinearGradient {
        let state = glassColorSystem.emotionalState
        
        // Map emotional state to gradient colors
        let colors: (Color, Color)
        switch state {
        case .calm:
            colors = (.kosmicBlue, .kosmicPurple)
        case .focused:
            colors = (.kosmicGreen, .kosmicBlue)
        case .reflective:
            colors = (.kosmicViolet, .kosmicPurple)
        case .energized:
            colors = (.kosmicBlue, .kosmicGreen)
        case .fatigued:
            colors = (.kosmicPurple.opacity(0.7), .kosmicBlue.opacity(0.7))
        }
        
        return LinearGradient(
            colors: [colors.0, colors.1],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var arteGradientColor: Color {
        let state = glassColorSystem.emotionalState
        switch state {
        case .calm:
            return .kosmicBlue
        case .focused:
            return .kosmicGreen
        case .reflective:
            return .kosmicViolet
        case .energized:
            return .kosmicBlue
        case .fatigued:
            return .kosmicPurple
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
        
        // Create Task without inheriting MainActor context to avoid deadlock
        _Concurrency.Task { @MainActor in
            // Parse intent
            let intent = await commandParser.parse(input, modelContext: modelContext)
            
            // Handle intent
            handleIntent(intent, originalInput: input)
        }
    }
    
    @MainActor
    private func handleIntent(_ intent: SpotlightIntent, originalInput: String) {
        isProcessing = false
        
        switch intent {
        case .execution(let executionIntent):
            handleExecution(executionIntent, originalInput: originalInput)
            
        case .reflection(let reflectionIntent):
            handleReflection(reflectionIntent, originalInput: originalInput)
            
        case .navigation(let tab):
            handleNavigation(tab)
            
        case .ritual(let ritualCommand):
            handleRitual(ritualCommand)
            
        case .dataSearch(let query):
            handleDataSearch(query, originalInput: originalInput)
            
        case .memoryQuery(let query):
            handleMemoryQuery(query, originalInput: originalInput)
            
        case .unknown(let text):
            // Route to AI Assistant for conversational handling
            handleUnknown(text)
        }
    }
    
    @MainActor
    private func handleExecution(_ intent: ExecutionIntent, originalInput: String) {
        _Concurrency.Task { @MainActor in
            do {
                // Convert intent to action, handling errors gracefully
                guard let action = intent.toAIIntentAction() else {
                    // If conversion fails, route to AI Assistant for handling
                    handleUnknown(originalInput)
                    return
                }
                
                let result = try await AIActionRouter.shared.route(
                    action,
                    modelContext: modelContext
                )
                
                // Show feedback (already on MainActor)
                feedbackMessage = result.message
                feedbackIcon = "checkmark.circle.fill"
                
                // Log to AI Assistant
                logToAIAssistant(userMessage: originalInput, assistantMessage: result.message)
                
                // Auto-close after showing feedback
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    AuroraSpotlightWindowController.shared.close()
                }
            } catch {
                feedbackMessage = "Failed to execute: \(error.localizedDescription)"
                feedbackIcon = "exclamationmark.circle.fill"
            }
        }
    }
    
    @MainActor
    private func handleReflection(_ intent: ReflectionIntent, originalInput: String) {
        _Concurrency.Task { @MainActor in
            let response = await AIReflectionService.shared.reflect(
                on: intent,
                timeRange: .thisWeek,
                modelContext: modelContext
            )
            
            // Update UI (already on MainActor)
            feedbackMessage = String(response.prefix(100)) + (response.count > 100 ? "..." : "")
            feedbackIcon = "brain.head.profile"
            
            // Log to AI Assistant
            logToAIAssistant(userMessage: originalInput, assistantMessage: response)
            
            // Auto-close after showing feedback
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                AuroraSpotlightWindowController.shared.close()
            }
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
    private func handleDataSearch(_ query: String, originalInput: String) {
        _Concurrency.Task { @MainActor in
            let results = WorkspaceObjectSearchService.shared.search(
                query: query,
                modelContext: modelContext,
                limit: 10
            )
            
            // Update UI (already on MainActor)
            if results.isEmpty {
                feedbackMessage = "No results found"
                feedbackIcon = "magnifyingglass"
            } else {
                feedbackMessage = "Found \(results.count) result\(results.count == 1 ? "" : "s")"
                feedbackIcon = "magnifyingglass"
                
                // Log to AI Assistant with results
                let resultsText = results.prefix(5).map { "- \($0.title)" }.joined(separator: "\n")
                logToAIAssistant(
                    userMessage: originalInput,
                    assistantMessage: "Found \(results.count) results:\n\(resultsText)"
                )
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                AuroraSpotlightWindowController.shared.close()
            }
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
                dueDate: taskDueDate.flatMap { parseISODate($0) },
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
                dueDate: projectDueDate.flatMap { parseISODate($0) },
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
    
    private func mapTaskStatus(_ status: String?) -> CloutmateShared.TaskStatus? {
        guard let status = status else { return nil }
        switch status.lowercased() {
        case "todo", "pending": return .todo
        case "inprogress", "in progress": return .inProgress
        case "done", "completed": return .done
        default: return nil
        }
    }
    
    private func mapTaskPriority(_ priority: String?) -> CloutmateShared.TaskPriority? {
        guard let priority = priority else { return nil }
        switch priority.lowercased() {
        case "low": return .low
        case "medium", "normal": return .medium
        case "high": return .high
        default: return nil
        }
    }
    
    private func mapProjectStatus(_ status: String?) -> CloutmateShared.ProjectStatus? {
        guard let status = status else { return nil }
        switch status.lowercased() {
        case "active": return .active
        case "paused", "onhold", "on hold": return .paused
        case "completed": return .completed
        default: return nil
        }
    }
    
    private func parseISODate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateString) ?? formatter.date(from: dateString + "Z")
    }
}

#Preview {
    AuroraSpotlightView()
        .modelContainer(for: [AIConversation.self, AIMessage.self])
        .environmentObject(GlassColorSystem())
}
