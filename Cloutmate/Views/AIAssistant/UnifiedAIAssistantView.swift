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
    @State private var showCreateSheet = false
    @State private var contextualCreateTab: TabIdentifier = .home
    @State private var chatScrollProxy: ScrollViewProxy?
    
    private let voiceService = VoiceTranscriptionService.shared
    @State private var imagePasteObserver: NSObjectProtocol?
    
    private let chatBottomAnchor = "ai-chat-bottom-anchor"
    
    // ARTE gradient colors based on emotional state
    private var arteGradientColors: [Color] {
        let palette = EmotionalPalette.palette(for: themeManager.currentState)
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
    
    // MARK: - View Components
    
    private var sidebarView: some View {
        AIAssistantSidebar(
            conversations: conversations,
            selectedConversation: viewModel.currentConversation,
            searchText: $viewModel.searchText,
            selectedDateFilter: $viewModel.selectedDateFilter,
            selectedTags: $viewModel.selectedTags,
            onConversationTap: { conversation in
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
        .frame(minWidth: 250, idealWidth: 280)
        .environment(\.glassTier, .contentCard)
    }
    
    private var mainChatArea: some View {
        VStack(spacing: 0) {
            chatHeader
            Divider()
            conversationPane
            Divider()
            toolbarView
            Divider()
            messageComposerView
        }
        .frame(minWidth: 500)
    }
    
    private var chatHeader: some View {
        AIAssistantHeaderView(
            onSearch: {
                showSpotlight = true
            },
            onNewChat: {
                if !viewModel.messages.isEmpty {
                    showUnsavedAlert = true
                } else {
                    viewModel.clearMessages()
                }
            },
            onSettings: {
                showAuroraPreferences = true
            },
            selectedFilter: $viewModel.selectedDateFilter
        )
        .environment(\.glassTier, .overlay)
    }
    
    private var conversationPane: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 8) {
                            if viewModel.messages.isEmpty {
                                welcomeView
                            } else {
                                ForEach(viewModel.messages) { message in
                                    MessageBubble(
                                        message: message,
                                        onEdit: { editedMessage, newContent in
                                            viewModel.editAndRegenerateMessage(editedMessage, newContent: newContent, modelContext: modelContext)
                                        },
                                        onCopy: { _ in },
                                        onResend: { assistantMessage in
                                            viewModel.resendAssistantMessage(assistantMessage, modelContext: modelContext)
                                        },
                                    canResend: viewModel.canResendPayload(for: message)
                                    )
                                    .id(message.id)
                                }
                            }
                            
                            if viewModel.isLoading {
                                ThinkingIndicator(
                                    activity: viewModel.displayedActivity,
                                    sourceModel: viewModel.currentSourceModel,
                                    statusMessage: viewModel.currentStatus
                                )
                                .padding()
                            } else if !viewModel.messages.isEmpty {
                                IdleIndicator()
                                    .padding(.top, 8)
                            }
                            
                            Color.clear
                                .frame(height: 1)
                                .id(chatBottomAnchor)
                                .background(
                                    GeometryReader { bottomGeo in
                                        Color.clear.preference(
                                            key: ChatScrollOffsetPreferenceKey.self,
                                            value: bottomGeo.frame(in: .named("chatScroll")).minY
                                        )
                                    }
                                )
                        }
                        .padding(.vertical, 16)
                        .padding(.bottom, 60)
                    }
                    .coordinateSpace(name: "chatScroll")
                    .onAppear {
                        chatScrollProxy = proxy
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if viewModel.isScrolledToBottom {
                            scrollToBottom(animated: true)
                        }
                    }
                    .onChange(of: viewModel.currentConversation?.id) { _, _ in
                        scrollToBottom(animated: false)
                    }
                }
                .onPreferenceChange(ChatScrollOffsetPreferenceKey.self) { bottomOffset in
                    let containerHeight = geometry.size.height
                    let isAtBottom = bottomOffset <= containerHeight + 32
                    if viewModel.isScrolledToBottom != isAtBottom {
                        viewModel.isScrolledToBottom = isAtBottom
                    }
                }
                
                VStack(alignment: .trailing, spacing: 16) {
                    if viewModel.messages.count >= 10 {
                        summarizeButton
                    }
                    
                    ScrollToBottomButton(isVisible: !viewModel.isScrolledToBottom) {
                        scrollToBottom(animated: true)
                    }
                }
                .padding(.trailing, 24)
                .padding(.bottom, 32)
            }
            .background(
                LinearGradient(
                    colors: arteGradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(0.1)
            )
        }
        .environment(\.glassTier, .background)
    }
    
    private var summarizeButton: some View {
        Button(action: {
            let task: _Concurrency.Task<Void, Never> = _Concurrency.Task {
                await viewModel.generateChatSummary()
            }
            _ = task
        }) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text.magnifyingglass")
                Text("Summarize Chat")
            }
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .foregroundColor(.primary)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.2), radius: 10)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 16)
        .padding(.bottom, 80)
    }
    
    private var toolbarView: some View {
        AIAssistantToolbar(
            viewModel: viewModel,
            isRecording: $isRecording,
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
                // Insert "@web " into input field and focus it
                if viewModel.inputText.isEmpty {
                    viewModel.inputText = "@web "
                } else {
                    viewModel.inputText += " @web "
                }
                isInputFocused = true
            }
        )
        .environment(\.glassTier, .overlay)
    }
    
    private var messageComposerView: some View {
        AIMessageComposer(
            text: $viewModel.inputText,
            linkedContext: $viewModel.linkedContext,
            isFocused: $isInputFocused,
            isRecording: $isRecording,
            voiceInputText: $voiceInputText,
            isLoading: viewModel.isLoading,
            pendingImageAttachment: viewModel.pendingImageAttachment,
            pendingDocumentAttachment: viewModel.pendingDocumentAttachment,
            lastConfidenceScore: viewModel.messages.last(where: { $0.role == "assistant" })?.confidenceScore,
            canRetry: viewModel.canRetry,
            onResendLastAssistant: viewModel.canResendLastAssistant ? {
                viewModel.resendLastAssistant(modelContext: modelContext)
            } : nil,
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
            }
        )
        .environment(\.glassTier, .contentCard)
    }
    
    var body: some View {
        HSplitView {
            sidebarView
            mainChatArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
        .onAppear {
            setupVoiceService()
            setupKeyboardHandlers()
            setupImagePasteHandler()
        }
        .onDisappear {
            // Clean up notification observer
            if let observer = imagePasteObserver {
                NotificationCenter.default.removeObserver(observer)
                imagePasteObserver = nil
            }
        }
        .sheet(isPresented: $showAuroraPreferences) {
            AIAssistantPreferencesSheet()
        }
        .sheet(isPresented: $showSpotlight) {
            AIAssistantSpotlightOverlay()
        }
        .sheet(isPresented: $showAuroraCreateSheet) {
            if let action = createSheetAction {
                AuroraCreateSheet(action: action) { prompt in
                    // Send formatted prompt to Aurora
                    viewModel.inputText = prompt
                    sendCurrentMessage()
                }
            }
        }
        .alert("Unsaved Changes", isPresented: $showUnsavedAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Discard") {
                if let conversationToLoad = conversationToLoad {
                    let _ = viewModel.loadConversation(conversationToLoad, modelContext: modelContext)
                    self.conversationToLoad = nil
                } else {
                    viewModel.clearMessages()
                }
            }
        } message: {
            Text("You have unsaved messages. Discard and continue?")
        }
        .alert("Rename Conversation", isPresented: $showRenameAlert) {
            TextField("Title", text: $newTitle)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if let conversation = conversationToRename {
                    viewModel.renameConversation(conversation, newTitle: newTitle, modelContext: modelContext)
                    toastMessage = "Conversation renamed"
                }
            }
        } message: {
            Text("Enter a new title for this conversation")
        }
        .alert("Delete Conversation", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let conversation = conversationToDelete {
                    viewModel.deleteConversation(conversation, modelContext: modelContext)
                }
            }
        } message: {
            Text("Are you sure you want to delete this conversation? This action cannot be undone.")
        }
        .toast(message: $toastMessage, systemImage: "checkmark.circle.fill")
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
        viewModel.isScrolledToBottom = true
        let loaded = viewModel.loadConversation(conversation, modelContext: modelContext)
        
        if !loaded {
            conversationToLoad = conversation
            showUnsavedAlert = true
        }
    }
    
    private func sendCurrentMessage() {
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
    
    private func scrollToBottom(animated: Bool = true) {
        guard let proxy = chatScrollProxy else { return }
        let scrollAction = {
            proxy.scrollTo(chatBottomAnchor, anchor: .bottom)
        }
        if animated {
            withAnimation(reduceMotion ? nil : GlassMotion.Easing.spring) {
                scrollAction()
            }
        } else {
            scrollAction()
        }
        viewModel.isScrolledToBottom = true
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
            // ⌘+K for search
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "k" {
                showSpotlight = true
                return nil
            }
            // ⌘+⇧+A for Aurora Spotlight
            if event.modifierFlags.contains([.command, .shift]) && event.charactersIgnoringModifiers?.lowercased() == "a" {
                showSpotlight = true
                return nil
            }
            return event
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
    
    private func completeVoiceInput() {
        let finalText = voiceInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        voiceService.stopTranscribing()
        if !finalText.isEmpty {
            viewModel.inputText = finalText
        }
        isRecording = false
        voiceInputText = ""
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

