//
//  UnifiedAIAssistantView.swift
//  Cloutmate
//
//  AI Assistant V2 - Unified glass-layered workspace
//  Merges Aurora's intelligence systems (Recall, CPS, ARTE, Predictive Cognition)
//

import SwiftUI
import SwiftData
import CloutmateShared
import AppKit

struct UnifiedAIAssistantView: View {
    @Query(sort: \AIConversation.createdAt, order: .reverse) private var conversations: [AIConversation]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @StateObject private var themeManager = ReactiveThemeManager.shared
    
    @State private var viewModel = AIAssistantViewModel()
    @State private var showUnsavedAlert = false
    @State private var conversationToLoad: AIConversation?
    @State private var showRenameAlert = false
    @State private var conversationToRename: AIConversation?
    @State private var newTitle = ""
    @State private var showDeleteAlert = false
    @State private var conversationToDelete: AIConversation?
    @State private var showAuroraPreferences = false
    @State private var showSpotlight = false
    
    @State private var showAuroraCreateSheet = false
    @State private var createSheetAction: ToolbarAction?
    
    // Toast notifications
    @State private var toastMessage: String?
    @State private var isRecording = false
    @State private var voiceInputText = ""
    @FocusState private var isInputFocused: Bool
    @State private var attachedContextLabels: [String] = []
    @State private var contextManuallyDetached = false
    @State private var attachedTab: TabIdentifier?
    @State private var attachedProjects: [UUID] = []
    @State private var attachedTasks: [UUID] = []
    @State private var messageFlags: [String: Bool] = [:]
    
    // Drawer states
    @State private var showTabDrawer = false
    @State private var showProjectDrawer = false
    @State private var showTaskDrawer = false

    private let voiceService = VoiceTranscriptionService.shared
    private let aiSettings = AISettings.shared
    @State private var imagePasteObserver: NSObjectProtocol?
    
    // ARTE gradient colors based on emotional state
    private var arteGradientColors: [Color] {
        _ = EmotionalPalette.palette(for: themeManager.currentState)
        switch themeManager.currentState {
        case .focused:
            return [Color(red: 0.0, green: 0.2, blue: 0.4), Color(red: 0.0, green: 0.3, blue: 0.5)]
        case .reflective:
            return [Color(red: 0.2, green: 0.1, blue: 0.3), Color(red: 0.3, green: 0.15, blue: 0.4)]
        case .calm:
            return [Color.kosmicBlue, Color.kosmicPurple]
        case .energized:
            return [Color(red: 0.0, green: 0.4, blue: 0.5), Color(red: 0.1, green: 0.5, blue: 0.6)]
        case .fatigued:
            return [Color(red: 0.2, green: 0.15, blue: 0.2), Color(red: 0.25, green: 0.2, blue: 0.25)]
        }
    }

    private var drawerVisible: Bool {
        false // Drawers are now shown inside AuroraChatContainer, not as overlays
    }
    
    private var contextLabelsWithTab: [String] {
        var labels = attachedContextLabels
        if let tab = attachedTab {
            labels.insert(tab.rawValue, at: 0)
        }
        
        // Add project names
        for projectId in attachedProjects {
            var descriptor = FetchDescriptor<Project>(predicate: #Predicate { $0.id == projectId })
            descriptor.fetchLimit = 1
            if let project = try? modelContext.fetch(descriptor).first {
                labels.append(project.title)
            }
        }
        
        // Add task names
        for taskId in attachedTasks {
            var descriptor = FetchDescriptor<Task>(predicate: #Predicate { $0.id == taskId })
            descriptor.fetchLimit = 1
            if let task = try? modelContext.fetch(descriptor).first {
                labels.append(task.title)
            }
        }
        
        return labels
    }

    @ViewBuilder
    private var overlayDrawers: some View {
        if showTabDrawer {
            TabAttachmentDrawer(
                isPresented: $showTabDrawer,
                onSelectTab: { tab in
                    attachTab(tab)
                    removeSlashCommandFromText("/tab")
                    showTabDrawer = false
                }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        
        if showProjectDrawer {
            ProjectAttachmentDrawer(
                isPresented: $showProjectDrawer,
                onSelectProject: { project in
                    attachProject(project)
                    removeSlashCommandFromText("/project")
                    showProjectDrawer = false
                }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        
        if showTaskDrawer {
            TaskAttachmentDrawer(
                isPresented: $showTaskDrawer,
                onSelectTask: { task in
                    attachTask(task)
                    removeSlashCommandFromText("/task")
                    showTaskDrawer = false
                }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        
        // AuroraCreateSheet will be shown in AuroraChatContainer, docked to bottom
    }
    
    @State private var isCollapsed = false
    @State private var collapseWorkItem: DispatchWorkItem?
    @State private var isHoveringPanel = false

    private var accentColor: Color {
        Color.kosmicBlue
    }

    private var glowColor: Color {
        Color.kosmicPurple
    }

    private var collapseSubtitle: String {
        if viewModel.isLoading {
            return "Aurora is thinking..."
        }
        if let title = viewModel.currentConversation?.title, !title.isEmpty {
            return title
        }
        return "Tap to resume conversation"
    }

    @ViewBuilder
    private var expandedChatView: some View {
        let warmupService = ModelWarmupService.shared
        
        ZStack {
            // Show warmup message if not ready
            if warmupService.isWarmingUp || !warmupService.isReady {
                WarmupWelcomeView(
                    message: warmupService.warmupMessage,
                    progress: warmupService.warmupProgress.isEmpty ? nil : warmupService.warmupProgress
                )
                .transition(.opacity)
            } else {
        AuroraChatContainer(
            viewModel: viewModel,
            conversations: conversations,
            arteGradientColors: arteGradientColors,
            accentColor: accentColor,
            glowColor: glowColor,
            conversationHandlers: conversationHandlers,
            toolbarHandlers: toolbarHandlers,
            manualContextLabels: contextLabelsWithTab,
            headerHandlers: headerHandlers,
            composerHandlers: composerHandlers,
            onAttachTab: { tab in
                attachTab(tab)
            },
            onDetachTab: {
                detachTab()
            },
            onSlashCommand: { command, range in
                handleSlashCommand(command, range: range)
            },
            messageFlags: messageFlags,
            showAuroraCreateSheet: showAuroraCreateSheet,
            createSheetAction: createSheetAction,
            onCreateSheetComplete: { prompt in
                viewModel.inputText = prompt
                sendCurrentMessage()
                showAuroraCreateSheet = false
                createSheetAction = nil
            },
            onCreateSheetDismiss: {
                showAuroraCreateSheet = false
                createSheetAction = nil
            },
            isRecording: $isRecording,
            voiceInputText: $voiceInputText,
            isInputFocused: $isInputFocused
        )
        .opacity(drawerVisible ? 0 : 1)
        .allowsHitTesting(!drawerVisible)
        .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: warmupService.isReady)
                    .onHover { hovering in
            if warmupService.isReady {
            isHoveringPanel = hovering
                        if hovering {
                cancelCollapseSchedule()
            } else {
                scheduleCollapseIfNeeded()
                }
            }
        }
        .onAppear {
            if warmupService.isReady {
            cancelCollapseSchedule()
            }
        }
    }
    
    private var conversationHandlers: AuroraChatContainer.ConversationHandlers {
        .init(
                            onTap: { conversation in
                                handleConversationTap(conversation)
                            },
                            onRename: { conversation in
                                conversationToRename = conversation
                                newTitle = conversation.title ?? ""
                                showRenameAlert = true
                            },
                            onDelete: { conversation in
                                conversationToDelete = conversation
                                showDeleteAlert = true
                            },
                            onTogglePin: { conversation in
                                viewModel.togglePin(conversation, modelContext: modelContext)
                                toastMessage = conversation.isPinned ? "Conversation unpinned" : "Conversation pinned"
                            },
                            onRefreshSummary: { conversation in
                                let task: _Concurrency.Task<Void, Never> = _Concurrency.Task {
                                    await viewModel.refreshSummary(conversation, modelContext: modelContext)
                                }
                                _ = task
                            },
                            onExportToDraft: { conversation in
                                if let messages = conversation.messages, !messages.isEmpty {
                                    let messagesArray: [AIMessage] = Array(messages)
                                    let conversationRef: AIConversation = conversation
                                    let result: Bool = viewModel.exportToDraft(messages: messagesArray, conversation: conversationRef, modelContext: modelContext)
                                    _ = result
                                    toastMessage = "Exported to Drafts!"
                                }
                            }
        )
    }
    
    private var toolbarHandlers: AuroraChatContainer.ToolbarHandlers {
        .init(
                            onSmartRecap: {
                                let task: _Concurrency.Task<Void, Never> = _Concurrency.Task {
                                    await viewModel.generateSmartRecap(modelContext: modelContext)
                                }
                                _ = task
                            },
                            onExportToDraft: {
                                guard let conversation = viewModel.currentConversation,
                                      let messages = conversation.messages,
                                      !messages.isEmpty else {
                                    toastMessage = "No messages to save"
                                    return
                                }
                                let messagesArray: [AIMessage] = Array(messages)
                                let conversationRef: AIConversation = conversation
                                let result: Bool = viewModel.exportToDraft(messages: messagesArray, conversation: conversationRef, modelContext: modelContext)
                                _ = result
                                toastMessage = "Saved to Drafts!"
                            },
                            onVoiceInput: {
                                toggleVoiceInput()
                            },
                            onToolbarAction: { action in
                                handleToolbarAction(action)
                            },
                            onWebSearch: {
                                if viewModel.inputText.isEmpty {
                                    viewModel.inputText = "@web "
                                } else {
                                    viewModel.inputText += " @web "
                                }
                                isInputFocused = true
                            },
                            onLinkContext: {
                // Replaced with tab attachment - no longer used
                            },
                            onToggleOffline: {
                                aiSettings.airplaneMode.toggle()
                                toastMessage = aiSettings.airplaneMode ? "Offline cognition active" : "Offline mode disabled"
                            },
                            isOffline: {
                                aiSettings.airplaneMode
                            }
        )
    }
    
    private var headerHandlers: AuroraChatContainer.HeaderHandlers {
        .init(
                            onSearch: {
                                showSpotlight = true
                            },
                            onNewChat: {
                                if !viewModel.messages.isEmpty {
                                    showUnsavedAlert = true
                                } else {
                                    // Clear research mode when starting new chat
                                    viewModel.clearResearchMode()
                                    viewModel.clearMessages()
                    contextManuallyDetached = true
                    attachedContextLabels.removeAll()
                                }
                            },
                            onSettings: {
                                showAuroraPreferences = true
                            }
        )
    }
    
    private var composerHandlers: AuroraChatContainer.ComposerHandlers {
        .init(
                            onSend: {
                                sendCurrentMessage()
                            },
                            onAttachImage: {
                                attachImageFromPicker()
                            },
                            onAttachDocument: {
                                presentDocumentSourceChooser()
                            },
                            onClearImage: {
                                viewModel.clearPendingImage()
                            },
                            onClearDocument: {
                                viewModel.clearPendingDocument()
                            },
                            onStop: {
                                viewModel.stopResponse(modelContext: modelContext)
                            },
            onRetry: {
                viewModel.retryLastMessage(modelContext: modelContext)
            },
            onResendLastAssistant: nil,
            onDetachContext: {
                detachLinkedContext()
            },
            onDetachChip: { chipLabel in
                detachChip(chipLabel)
            }
        )
    }

    private var mainContent: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(.windowBackgroundColor)
                .ignoresSafeArea()

            Group {
                if isCollapsed {
                    collapsedChatView
                        } else {
                    expandedChatView
                }
            }

            overlayDrawers
        }
    }
    
    private var collapsedChatView: some View {
        CollapsedChatView(
            title: "Aurora",
            subtitle: collapseSubtitle,
            onTap: {
                expandPanel()
            },
            onLongPress: {
                showAuroraPreferences = true
            },
            accent: accentColor,
            glow: glowColor,
            isRecording: isRecording
        )
        .padding(.trailing, 32)
        .padding(.bottom, 36)
        .transition(.scale.combined(with: .opacity))
        .onHover { hovering in
            if hovering {
                expandPanel()
                    }
                }
            }

    var body: some View {
        mainContent
        .onAppear {
            setupVoiceService()
            setupKeyboardHandlers()
            setupImagePasteHandler()
            scheduleCollapseIfNeeded()
            refreshAttachedContext()
        }
        .onDisappear {
            if let observer = imagePasteObserver {
                NotificationCenter.default.removeObserver(observer)
                imagePasteObserver = nil
            }
            cancelCollapseSchedule()
        }
        .sheet(isPresented: $showAuroraPreferences) {
                AIAssistantPreferencesSheet(isPresented: $showAuroraPreferences)
        }
        .sheet(isPresented: $showSpotlight) {
            AIAssistantSpotlightOverlay()
        }
        // AuroraCreateSheet removed from .sheet() - now shown as bottom drawer in AuroraChatContainer
        .alert("Unsaved Changes", isPresented: $showUnsavedAlert) {
                unsavedAlertContent
        } message: {
            Text("You have unsaved messages. Discard and continue?")
        }
        .alert("Rename Conversation", isPresented: $showRenameAlert) {
                renameAlertContent
        } message: {
            Text("Enter a new title for this conversation")
        }
        .alert("Delete Conversation", isPresented: $showDeleteAlert) {
                deleteAlertContent
        } message: {
            Text("Are you sure you want to delete this conversation? This action cannot be undone.")
        }
        .toast(message: $toastMessage, systemImage: "checkmark.circle.fill")
        .onChange(of: viewModel.isLoading) { _, _ in
            scheduleCollapseIfNeeded()
        }
        .onChange(of: viewModel.inputText) { _, newValue in
                handleInputTextChange(newValue)
            }
            .onChange(of: isInputFocused) { _, focused in
                handleInputFocusedChange(focused)
            }
            .onChange(of: viewModel.messages.count) { oldValue, newValue in
                handleMessagesCountChange(oldValue: oldValue, newValue: newValue)
            }
            .onChange(of: viewModel.currentConversation?.id) { _, _ in
                handleConversationIdChange()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HashtagAutocompleteSelect"))) { notification in
                if let result = notification.object as? WorkspaceObjectResult {
                    handleHashtagSelection(result)
                }
            }
    }
    
    @ViewBuilder
    private var unsavedAlertContent: some View {
        Button("Cancel", role: .cancel) {}
        Button("Discard") {
            handleUnsavedDiscard()
        }
    }
    
    @ViewBuilder
    private var renameAlertContent: some View {
        TextField("Title", text: $newTitle)
        Button("Cancel", role: .cancel) {}
        Button("Save") {
            handleRenameSave()
        }
    }
    
    @ViewBuilder
    private var deleteAlertContent: some View {
        Button("Cancel", role: .cancel) {}
        Button("Delete", role: .destructive) {
            handleDeleteConfirm()
        }
    }
    
    private func handleInputTextChange(_ newValue: String) {
            cancelCollapseSchedule()
            if isCollapsed && !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                expandPanel()
            }
        }
    
    private func handleInputFocusedChange(_ focused: Bool) {
            if focused {
                cancelCollapseSchedule()
                if isCollapsed {
                    expandPanel()
                }
            } else {
                scheduleCollapseIfNeeded()
            }
        }
    
    private func handleMessagesCountChange(oldValue: Int, newValue: Int) {
            if isCollapsed && newValue > oldValue {
                expandPanel()
            }
            scheduleCollapseIfNeeded()
        }
    
    private func handleConversationIdChange() {
            // Clear research mode when conversation changes
            viewModel.clearResearchMode()
            
            if !contextManuallyDetached {
                attachedContextLabels.removeAll()
                refreshAttachedContext()
            }
    }
    
    private func handleUnsavedDiscard() {
        // Clear research mode when discarding/clearing
        viewModel.clearResearchMode()
        
        if let conversationToLoad = conversationToLoad {
            let loaded = viewModel.loadConversation(conversationToLoad, modelContext: modelContext)
            if loaded {
                attachedContextLabels.removeAll()
                contextManuallyDetached = false
                refreshAttachedContext()
            }
            self.conversationToLoad = nil
        } else {
            viewModel.clearMessages()
            contextManuallyDetached = true
            attachedContextLabels.removeAll()
        }
    }
    
    private func handleRenameSave() {
        if let conversation = conversationToRename {
            viewModel.renameConversation(conversation, newTitle: newTitle, modelContext: modelContext)
            toastMessage = "Conversation renamed"
        }
    }
    
    private func handleDeleteConfirm() {
        if let conversation = conversationToDelete {
            viewModel.deleteConversation(conversation, modelContext: modelContext)
        }
    }
    
    // MARK: - Welcome View
    
    private var welcomeView: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.kosmicBlue, .kosmicPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 8) {
                Text("Aurora")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Your cognitive assistant")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("I can help you create tasks, projects, notes, reminders, analyze documents, and more!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Actions
    
    private func handleConversationTap(_ conversation: AIConversation) {
        // Clear research mode when switching conversations
        viewModel.clearResearchMode()
        
        viewModel.isScrolledToBottom = true
        let loaded = viewModel.loadConversation(conversation, modelContext: modelContext)
        
        if loaded {
            contextManuallyDetached = false
            attachedContextLabels.removeAll()
            refreshAttachedContext()
        } else {
            conversationToLoad = conversation
            showUnsavedAlert = true
        }
    }
    
    private func sendCurrentMessage() {
        // Block sending messages until warmup is complete
        let warmupService = ModelWarmupService.shared
        guard warmupService.isReady, !warmupService.isWarmingUp else {
            return // Silently block - warmup message will be shown
        }
        
        let currentText = viewModel.inputText
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachment = viewModel.pendingImageAttachment
        let documentAttachment = viewModel.pendingDocumentAttachment
        guard !trimmed.isEmpty || attachment != nil || documentAttachment != nil else {
            viewModel.inputText = ""
            return
        }
        viewModel.sendMessage(
            currentText,
            modelContext: modelContext,
            image: attachment,
            document: documentAttachment
        )
        
        // Clear flags after sending
        messageFlags.removeAll()
    }
    
    private func attachImageFromPicker() {
        let task: _Concurrency.Task<Void, Never> = _Concurrency.Task {
            do {
                let attachment = try await ImageAttachmentService.shared.loadFromFilePicker()
                await MainActor.run {
                    // Just attach the image, don't auto-send - user will send when ready
                    viewModel.attachImage(attachment)
                }
            } catch ImageAttachmentService.AttachmentError.noImageSelected {
                // Ignore cancellations
            } catch {
                await MainActor.run {
                    toastMessage = error.localizedDescription
                }
            }
        }
        _ = task
    }
    
    private func presentDocumentSourceChooser() {
        let task: _Concurrency.Task<Void, Never> = _Concurrency.Task { @MainActor in
            let alert = NSAlert()
            alert.messageText = "Add Document"
            alert.informativeText = "Choose how you want to bring this document into the chat."
            alert.addButton(withTitle: "From Computer")
            alert.addButton(withTitle: "From URL")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .informational
            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn:
                attachDocumentFromPicker()
            case .alertSecondButtonReturn:
                promptDocumentURL()
            default:
                break
            }
        }
        _ = task
    }
    
    private func attachDocumentFromPicker() {
        let task: _Concurrency.Task<Void, Never> = _Concurrency.Task {
            do {
                let attachment = try await DocumentAttachmentService.shared.loadFromFilePicker()
                await MainActor.run {
                    if viewModel.attachDocument(attachment) {
                        // Auto-send document for automatic analysis
                        sendCurrentMessage()
                    } else {
                        if viewModel.isLoading {
                            toastMessage = "Aurora is already processing a document. Please wait for her to finish."
                        } else if viewModel.pendingDocumentAttachment != nil {
                            toastMessage = "Due to Aurora's sanity, we only allow her to process a single file at a time."
                        }
                    }
                }
            } catch DocumentAttachmentService.DocumentError.noDocumentSelected {
                // Ignore cancellations
            } catch {
                await MainActor.run {
                    toastMessage = error.localizedDescription
                }
            }
        }
        _ = task
    }
    
    @MainActor
    private func promptDocumentURL() {
        let alert = NSAlert()
        alert.messageText = "Import Document from URL"
        alert.informativeText = "Paste a link to a PDF, Markdown, or text file."
        alert.addButton(withTitle: "Import")
        alert.addButton(withTitle: "Cancel")
        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        inputField.placeholderString = "https://example.com/report.pdf"
        alert.accessoryView = inputField
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        let value = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: value), !value.isEmpty else {
            toastMessage = "That URL doesn't look right."
            return
        }
        attachDocumentFromURL(url)
    }
    
    private func attachDocumentFromURL(_ url: URL) {
        let task: _Concurrency.Task<Void, Never> = _Concurrency.Task {
            do {
                let attachment = try await DocumentAttachmentService.shared.loadFromURL(url)
                await MainActor.run {
                    if viewModel.attachDocument(attachment) {
                        // Auto-send document for automatic analysis
                        sendCurrentMessage()
                    } else {
                        if viewModel.isLoading {
                            toastMessage = "Aurora is already processing a document. Please wait for her to finish."
                        } else if viewModel.pendingDocumentAttachment != nil {
                            toastMessage = "Due to Aurora's sanity, we only allow her to process a single file at a time."
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    toastMessage = error.localizedDescription
                }
            }
        }
        _ = task
    }
    
    private func setupImagePasteHandler() {
        // Remove existing observer if any
        if let observer = imagePasteObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        imagePasteObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MentionInputImagePaste"),
            object: nil,
            queue: .main
        ) { notification in
            guard let image = notification.object as? NSImage else { return }
            
            let task: _Concurrency.Task<Void, Never> = _Concurrency.Task {
                do {
                    let attachment = try await ImageAttachmentService.shared.validateAndPrepare(image, preferredFileName: nil)
                    await MainActor.run {
                        // Just attach the image, don't auto-send - user will send when ready
                        viewModel.attachImage(attachment)
                    }
                } catch {
                    await MainActor.run {
                        toastMessage = error.localizedDescription
                    }
                }
            }
            _ = task
        }
    }
    
    private func setupVoiceService() {
        voiceService.onPartial = { [self] partial in
            DispatchQueue.main.async {
                voiceInputText = partial
            }
        }
        
        voiceService.onFinal = { [self] final in
            DispatchQueue.main.async {
                voiceInputText = final
                viewModel.inputText = final
                isRecording = false
            }
        }
        
        voiceService.onError = { [self] error in
            DispatchQueue.main.async {
                isRecording = false
                toastMessage = "Voice input error: \(error.localizedDescription)"
            }
        }
    }
    
    private func setupKeyboardHandlers() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let characters = event.charactersIgnoringModifiers?.lowercased() else {
                return event
            }

            guard event.modifierFlags.contains(.command) else {
                return event
            }

            switch characters {
            case "k":
                togglePanelVisibility()
                return nil
            case "m":
                toggleVoiceInput()
                return nil
            case "w":
                triggerWebShortcut()
                return nil
            case "a":
                if event.modifierFlags.contains(.shift) {
                    presentDocumentSourceChooser()
                    return nil
                }
                return event
            default:
                return event
            }
        }
    }
    
    private func toggleVoiceInput() {
        if isRecording {
            completeVoiceInput()
        } else {
            voiceInputText = ""
            let task: _Concurrency.Task<Void, Never> = _Concurrency.Task {
                do {
                    try await voiceService.requestPermissions()
                    try voiceService.startTranscribing()
                    await MainActor.run {
                        isRecording = true
                    }
                } catch {
                    await MainActor.run {
                        toastMessage = "Microphone permission required"
                    }
                }
            }
            _ = task
        }
    }
    
    private func linkCurrentContext() {
        contextManuallyDetached = false

        var addedLabel: String?
        if let mentionLabel = viewModel.linkedContext.mentionMap.values
            .map({ $0.displayName })
            .first(where: { !attachedContextLabels.contains($0) }) {
            attachedContextLabels.append(mentionLabel)
            addedLabel = mentionLabel
        } else if let conversationLabel = conversationContextLabel(),
                  !attachedContextLabels.contains(conversationLabel) {
            attachedContextLabels.append(conversationLabel)
            addedLabel = conversationLabel
        } else {
            let stateLabel = "Mode: \(themeManager.currentState.displayName)"
            if !attachedContextLabels.contains(stateLabel) {
                attachedContextLabels.append(stateLabel)
                addedLabel = stateLabel
            }
        }

        if let addedLabel {
            toastMessage = "Linked to \(addedLabel)"
        } else {
            toastMessage = "Context already linked"
        }
    }

    private func detachLinkedContext() {
        viewModel.linkedContext.clear()
        attachedContextLabels.removeAll()
        attachedTab = nil
        contextManuallyDetached = true
    }
    
    private func attachTab(_ tab: TabIdentifier) {
        attachedTab = tab
    }
    
    private func detachTab() {
        attachedTab = nil
    }
    
    private func handleSlashCommand(_ command: SlashCommand, range: NSRange) {
        switch command {
        case .tab:
            showTabDrawer = true
            // Text will be removed when tab is selected
        case .project:
            showProjectDrawer = true
            // Text will be removed when project is selected
        case .task:
            showTaskDrawer = true
            // Text will be removed when task is selected
        case .think:
            messageFlags["think"] = !(messageFlags["think"] ?? false)
            removeSlashCommandFromText(range: range)
        case .web:
            messageFlags["web"] = !(messageFlags["web"] ?? false)
            removeSlashCommandFromText(range: range)
        case .research:
            viewModel.setResearchMode(true)
            removeSlashCommandFromText(range: range)
        }
    }
    
    private func attachProject(_ project: Project) {
        if !attachedProjects.contains(project.id) {
            attachedProjects.append(project.id)
        }
    }
    
    private func attachTask(_ task: Task) {
        if !attachedTasks.contains(task.id) {
            attachedTasks.append(task.id)
        }
    }
    
    private func handleToolbarAction(_ action: ToolbarAction) {
        guard !viewModel.isLoading else { return }
        
        // Handle action
        switch action {
        case .createTask, .createProject, .createNote, .createReminder:
            // Show create sheet for these actions
            createSheetAction = action
            showAuroraCreateSheet = true
            
        case .analyzeDocument:
            presentDocumentSourceChooser()
            
        case .analyzeImage:
            attachImageFromPicker()
        }
    }
    
    private func handleHashtagSelection(_ result: WorkspaceObjectResult) {
        // Link the selected content item for Aurora context based on ObjectType
        let resultId = result.id
        let resultType = result.type
        let resultTitle = result.title
        
        switch resultType {
        case .project:
            var descriptor = FetchDescriptor<Project>(predicate: #Predicate<Project> { project in
                project.id == resultId
            })
            descriptor.fetchLimit = 1
            if let project = try? modelContext.fetch(descriptor).first {
                attachProject(project)
                toastMessage = "Linked to \(resultTitle)"
            }
        case .task:
            var descriptor = FetchDescriptor<Task>(predicate: #Predicate<Task> { task in
                task.id == resultId
            })
            descriptor.fetchLimit = 1
            if let task = try? modelContext.fetch(descriptor).first {
                attachTask(task)
                toastMessage = "Linked to \(resultTitle)"
            }
        case .note, .post, .artifact:
            // Add to context labels for these types
            if !attachedContextLabels.contains(resultTitle) {
                attachedContextLabels.append(resultTitle)
                toastMessage = "Linked to \(resultTitle)"
            }
        default:
            // For other types, add to context labels
            if !attachedContextLabels.contains(resultTitle) {
                attachedContextLabels.append(resultTitle)
                toastMessage = "Linked to \(resultTitle)"
            }
        }
    }
    
    private func removeSlashCommandFromText(_ command: String) {
        // Remove the slash command from the input text
        let text = viewModel.inputText
        if let range = text.range(of: command) {
            let nsRange = NSRange(range, in: text)
            removeSlashCommandFromText(range: nsRange)
        }
    }
    
    private func removeSlashCommandFromText(range: NSRange) {
        // Remove the slash command from the input text using the provided range
        let text = viewModel.inputText
        let mutableText = NSMutableString(string: text)
        if range.location + range.length <= mutableText.length {
            mutableText.deleteCharacters(in: range)
            viewModel.inputText = String(mutableText)
        }
    }
    
    private func replaceSlashCommandWithText(_ replacement: String, range: NSRange) {
        // Replace the slash command text with the replacement text
        let text = viewModel.inputText
        let mutableText = NSMutableString(string: text)
        if range.location + range.length <= mutableText.length {
            mutableText.replaceCharacters(in: range, with: replacement)
            viewModel.inputText = String(mutableText)
        }
    }
    
    private func detachChip(_ chipLabel: String) {
        // Check if it's a tab
        if let tab = TabIdentifier.allCases.first(where: { $0.rawValue == chipLabel }) {
            if attachedTab == tab {
                attachedTab = nil
            }
            return
        }
        
        // Check if it's a project
        for projectId in attachedProjects {
            var descriptor = FetchDescriptor<Project>(predicate: #Predicate { $0.id == projectId })
            descriptor.fetchLimit = 1
            if let project = try? modelContext.fetch(descriptor).first, project.title == chipLabel {
                attachedProjects.removeAll { $0 == projectId }
                return
            }
        }
        
        // Check if it's a task
        for taskId in attachedTasks {
            var descriptor = FetchDescriptor<Task>(predicate: #Predicate { $0.id == taskId })
            descriptor.fetchLimit = 1
            if let task = try? modelContext.fetch(descriptor).first, task.title == chipLabel {
                attachedTasks.removeAll { $0 == taskId }
                return
            }
        }
        
        // If not found, detach all context
        detachLinkedContext()
    }

    private func conversationContextLabel() -> String? {
        guard let conversation = viewModel.currentConversation else { return nil }
        if let title = conversation.title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let summary = conversation.summary, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return summary.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private func refreshAttachedContext() {
        guard !contextManuallyDetached else { return }
        guard let conversationLabel = conversationContextLabel() else {
            if !attachedContextLabels.isEmpty {
                attachedContextLabels.removeAll()
            }
            return
        }
        if !attachedContextLabels.contains(conversationLabel) {
            attachedContextLabels.insert(conversationLabel, at: 0)
        }
        attachedContextLabels = attachedContextLabels.reduce(into: [String]()) { result, label in
            if !result.contains(label) {
                result.append(label)
            }
        }
    }
    
    private func completeVoiceInput() {
        let finalText = voiceInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        voiceService.stopTranscribing()
        if !finalText.isEmpty {
            viewModel.inputText = finalText
        }
        isRecording = false
        voiceInputText = ""
    }

    // MARK: - Panel Collapse Behaviour

    private func expandPanel() {
        cancelCollapseSchedule()
        guard isCollapsed else { return }
        withAnimation(.easeInOut(duration: 0.28)) {
            isCollapsed = false
        }
    }

    private func scheduleCollapseIfNeeded() {
        cancelCollapseSchedule()
        guard !isCollapsed else { return }
        guard !drawerVisible else { return }
        guard !isInputFocused else { return }
        guard !isHoveringPanel else { return }
        guard !isRecording else { return }
        guard !viewModel.isLoading else { return }
        guard viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !viewModel.messages.isEmpty else { return }

        let workItem = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.32)) {
                isCollapsed = true
            }
        }
        collapseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: workItem)
    }

    private func cancelCollapseSchedule() {
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
    }

    private func collapsePanel() {
        cancelCollapseSchedule()
        guard !isCollapsed else { return }
        withAnimation(.easeInOut(duration: 0.28)) {
            isCollapsed = true
        }
    }

    private func togglePanelVisibility() {
        if isCollapsed {
            expandPanel()
        } else {
            collapsePanel()
        }
    }

    private func triggerWebShortcut() {
        if viewModel.inputText.isEmpty {
            viewModel.inputText = "@web "
        } else {
            viewModel.inputText += " @web "
        }
        isInputFocused = true
    }
}

private struct ChatScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    UnifiedAIAssistantView()
        .modelContainer(for: [AIMessage.self, AIConversation.self])
        .environmentObject(GlassColorSystem())
}


