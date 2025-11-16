//
//  AIAssistantView.swift
//  Cloutmate
//
//  AI Creative Assistant Main View
//

import SwiftUI
import SwiftData
import CloutmateShared
import AppKit

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

struct AIAssistantView: View {
    @Query(sort: \AIConversation.createdAt, order: .reverse) private var conversations: [AIConversation]
    @Environment(\.modelContext) private var modelContext
    
    @State private var viewModel = AIAssistantViewModel()
    @State private var showUnsavedAlert = false
    @State private var conversationToLoad: AIConversation?
    @State private var showRenameAlert = false
    @State private var conversationToRename: AIConversation?
    @State private var newTitle = ""
    @State private var showDeleteAlert = false
    @State private var conversationToDelete: AIConversation?
    
    // Toast notifications
    @State private var toastMessage: String?
    @State private var showAIInfo = false
    @State private var isRecording = false
    @State private var voiceInputText = ""
    @FocusState private var isInputFocused: Bool
    @State private var showMicroFeedback: ToolbarAction? = nil
    @State private var showContextualCreateSheet = false
    @State private var contextualCreateTab: TabIdentifier = .home
    @State private var scrollOffset: CGFloat = 0
    @State private var headerOpacity: Double = 1.0
    @State private var showAuroraPreferences = false
    @State private var showAuroraCreateSheet = false
    @State private var createSheetAction: ToolbarAction?
    @State private var chatScrollProxy: ScrollViewProxy?
    @State private var showDocumentSourceDrawer = false
    @State private var showDocumentURLDrawer = false
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    private let voiceService = VoiceTranscriptionService.shared
    private let tintManager = ArteTintManager.shared
    private let usageTracker = ToolbarUsageTracker.shared
    private let chatBottomAnchor = "legacy-ai-chat-bottom-anchor"
    
    var body: some View {
        ZStack {
        HSplitView {
            conversationsSidebar
                .frame(minWidth: 250, idealWidth: 280)
            
            mainChatArea
                .frame(minWidth: 500)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
            .opacity(drawerVisible ? 0 : 1)
            
            overlayDrawers
        }
        .onAppear {
            setupVoiceService()
            setupKeyboardHandlers()
            setupNotifications()
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
    
    private var drawerVisible: Bool {
        // showAuroraCreateSheet removed - now handled in AuroraChatContainer
        showContextualCreateSheet || showAuroraPreferences || showDocumentSourceDrawer || showDocumentURLDrawer
    }
    
    @ViewBuilder
    private var overlayDrawers: some View {
        if showContextualCreateSheet {
            ContextualCreateDrawer(isPresented: $showContextualCreateSheet, currentTab: contextualCreateTab)
                .transition(.move(edge: .trailing).combined(with: .opacity))
        }
        
        
        if showAuroraPreferences {
            AIAssistantPreferencesSheet(isPresented: $showAuroraPreferences)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        
        if showDocumentSourceDrawer {
            DocumentSourceDrawer(
                isPresented: $showDocumentSourceDrawer,
                onSelectFromComputer: {
                    attachDocumentFromPicker()
                },
                onSelectFromURL: {
                    showDocumentURLDrawer = true
                }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        
        if showDocumentURLDrawer {
            DocumentURLDrawer(
                isPresented: $showDocumentURLDrawer,
                onImport: { url in
                    attachDocumentFromURL(url)
                }
            )
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    private func setupNotifications() {
            // Listen for keyboard shortcuts
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("AuroraToolbarAction"),
                object: nil,
                queue: .main
            ) { notification in
                if let action = notification.object as? ToolbarAction {
                    handleToolbarAction(action)
                }
            }
            // Listen for current tab updates
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("CurrentTabUpdated"),
                object: nil,
                queue: .main
            ) { notification in
                if let tab = notification.object as? TabIdentifier {
                    contextualCreateTab = tab
                }
            }
            // Listen for image paste from MentionInputField
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("MentionInputImagePaste"),
                object: nil,
                queue: .main
            ) { notification in
                if let image = notification.object as? NSImage {
                    handleImagePaste(image)
                }
            }
            // Listen for conversation selection from Spotlight
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("SelectAIConversation"),
                object: nil,
                queue: .main
            ) { notification in
                if let conversation = notification.object as? AIConversation {
                    let loaded = viewModel.loadConversation(conversation, modelContext: modelContext)
                    if !loaded {
                        conversationToLoad = conversation
                        showUnsavedAlert = true
                    }
                }
            }
    }
    
    // MARK: - Conversations Sidebar
    
    private var conversationsSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Conversations")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                Spacer()
            }
            
            Divider()
            
            // Reflection Panel
            if conversations.count >= 5 {
                ReflectionPanel(conversations: conversations)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            
            Divider()
            
                                // Search and Filter Bar
                    ConversationSearchBar(
                        searchText: $viewModel.searchText,
                        selectedFilter: $viewModel.selectedDateFilter,
                        selectedTags: $viewModel.selectedTags,
                        allTags: conversations.flatMap { $0.tags }.removingDuplicates().sorted()
                    )
            
            Divider()
            
            ScrollView {
                VStack(spacing: 8) {
                    let filteredConversations = viewModel.filteredConversations(conversations)
                    
                    if filteredConversations.isEmpty {
                        ContentUnavailableView(
                            "No conversations found",
                            systemImage: "bubble.left.and.bubble.right",
                            description: Text("No conversations match your search or filter criteria")
                        )
                        .frame(maxHeight: .infinity)
                    } else {
                        ForEach(filteredConversations) { conversation in
                                ConversationRow(
                                conversation: conversation,
                                isSelected: viewModel.currentConversation?.id == conversation.id,
                                onTap: {
                                    handleConversationTap(conversation)
                                },
                                onRename: {
                                    conversationToRename = conversation
                                    newTitle = conversation.title ?? ""
                                    showRenameAlert = true
                                },
                                onDelete: {
                                    conversationToDelete = conversation
                                    showDeleteAlert = true
                                },
                                onTogglePin: {
                                    viewModel.togglePin(conversation, modelContext: modelContext)
                                    toastMessage = conversation.isPinned ? "Conversation unpinned" : "Conversation pinned"
                                },
                                onRefreshSummary: {
 		_Concurrency.Task {
                                        await viewModel.refreshSummary(conversation, modelContext: modelContext)
                                    }
                                },
                                onExportToDraft: {
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
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func handleConversationTap(_ conversation: AIConversation) {
        viewModel.isScrolledToBottom = true
        let loaded = viewModel.loadConversation(conversation, modelContext: modelContext)
        
        if !loaded {
            conversationToLoad = conversation
            showUnsavedAlert = true
        }
    }
    
    private var mainChatArea: some View {
        VStack(spacing: 0) {
            // Header with scroll fade
            AIAssistantHeaderView(
                onSearch: {
                    AuroraSpotlightWindowController.shared.show()
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
            .opacity(headerOpacity)
            .transition(.move(edge: .top).combined(with: .opacity))
            
            Divider()
            
            // Chat Messages with scroll tracking
            ZStack(alignment: .bottomTrailing) {
                ScrollViewReader { proxy in
                    GeometryReader { geometry in
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
                                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                    }
                                }
                                
                                if viewModel.isLoading {
                                    // When research mode is active, ONLY show research progress indicator
                                    // Never show "Crafting response" ThinkingIndicator in research mode
                                    if viewModel.researchModeActive {
                                        // Show progress indicator if we have an action, otherwise show "Starting research..."
                                        let action = viewModel.currentResearchAction ?? "Starting research..."
                                        ResearchProgressIndicator(
                                            action: action,
                                            sourceCount: viewModel.currentResearchSourceCount
                                        )
                                        .padding()
                                    } else {
                                        // Only show ThinkingIndicator when NOT in research mode
                                    ThinkingIndicator(
                                        activity: viewModel.displayedActivity,
                                        sourceModel: viewModel.currentSourceModel,
                                        statusMessage: viewModel.currentStatus
                                    )
                                    .padding()
                                    }
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
                            .background(
                                GeometryReader { scrollGeometry in
                                    Color.clear.preference(
                                        key: ScrollOffsetPreferenceKey.self,
                                        value: scrollGeometry.frame(in: .named("chatScroll")).minY
                                    )
                                }
                            )
                        }
                        .coordinateSpace(name: "chatScroll")
                        .onAppear {
                            chatScrollProxy = proxy
                            if viewModel.isScrolledToBottom {
                                scrollToBottom(animated: false)
                            }
                        }
                        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                            let offset = -value
                            scrollOffset = offset
                            withAnimation(reduceMotion ? nil : GlassMotion.Easing.spring) {
                                headerOpacity = max(0.0, min(1.0, 1.0 - offset / 100.0))
                            }
                        }
                        .onPreferenceChange(ChatScrollOffsetPreferenceKey.self) { bottomOffset in
                            let containerHeight = geometry.size.height
                            let isAtBottom = bottomOffset <= containerHeight + 32
                            if viewModel.isScrolledToBottom != isAtBottom {
                                viewModel.isScrolledToBottom = isAtBottom
                            }
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
                }
                
                VStack(alignment: .trailing, spacing: 16) {
                    if viewModel.messages.count >= 10 {
                        Button(action: {
                            _Concurrency.Task {
                                await viewModel.generateChatSummary()
                            }
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
                    }
                    
                    ScrollToBottomButton(isVisible: !viewModel.isScrolledToBottom) {
                        scrollToBottom(animated: true)
                    }
                }
                .padding(.trailing, 16)
                .padding(.bottom, 80)
            }
            
            Divider()
            
            // Toolbar
            AIAssistantToolbar(
                viewModel: viewModel,
                isRecording: $isRecording,
                onSmartRecap: {
                    _Concurrency.Task {
                        await viewModel.generateSmartRecap(modelContext: modelContext)
                    }
                },
                onExportToDraft: {
                    saveCurrentToDraft()
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
            
            Divider()
            
            // Message Composer
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
                isResearchMode: viewModel.researchModeActive,
                onResendLastAssistant: viewModel.canResendLastAssistant ? {
                    viewModel.resendLastAssistant(modelContext: modelContext)
                } : nil,
                onSend: {
                    sendCurrentMessage(modelContext: modelContext)
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
            
            // Contextual Hint Bar
            if viewModel.inputText.isEmpty && !viewModel.isLoading {
                HStack {
                    Text("You can @mention a project or attach a doc")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .opacity(0.6)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .transition(.opacity)
            }
        }
    }
    
    // MARK: - Scroll Offset Preference Key
    
    struct ScrollOffsetPreferenceKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }
    
    private struct ChatScrollOffsetPreferenceKey: PreferenceKey {
        static var defaultValue: CGFloat = .zero
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
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
                Text("AI Creative Assistant")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("I can help you create tasks, projects, notes, reminders, analyze documents, and more!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)
            }
            
            Text("Use the toolbar above or ask me anything below")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Voice Input & Actions

    private func sendCurrentMessage(modelContext: ModelContext) {
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
    
    private func handleToolbarAction(_ action: ToolbarAction) {
        guard !viewModel.isLoading else { return }
        
        // Track usage
        usageTracker.trackUsage(action)
        
        // Show micro-feedback
        showMicroFeedback = action
        _Concurrency.Task {
            try? await _Concurrency.Task.sleep(nanoseconds: 500_000_000) // 0.5s
            await MainActor.run {
                showMicroFeedback = nil
            }
        }
        
        // Handle action
        switch action {
        case .createTask, .createProject, .createNote, .createReminder:
            // AuroraCreateSheet removed - now handled in AuroraChatContainer as bottom drawer
            // These actions are handled in UnifiedAIAssistantView
            break
            
        case .analyzeDocument:
            presentDocumentSourceChooser()
            
        case .analyzeImage:
            attachImageFromPicker()
        }
    }

    private func presentDocumentSourceChooser() {
        showDocumentSourceDrawer = true
    }

    private func attachImageFromPicker() {
        _Concurrency.Task {
            do {
                let attachment = try await ImageAttachmentService.shared.loadFromFilePicker()
                await MainActor.run {
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
    }

    private func attachImageFromPhotos() {
        _Concurrency.Task {
            do {
                let attachment = try await ImageAttachmentService.shared.loadFromPhotosLibrary()
                await MainActor.run {
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
    }

    private func attachDocumentFromPicker() {
        _Concurrency.Task {
            do {
                let attachment = try await DocumentAttachmentService.shared.loadFromFilePicker()
                await MainActor.run {
                    if !viewModel.attachDocument(attachment) {
                        if viewModel.isLoading {
                            toastMessage = "Aurora is already processing a document. Please wait for her to finish."
                        } else if viewModel.pendingDocumentAttachment != nil {
                            toastMessage = "Due to Aurora's sanity, we only allow her to process a single file at a time."
                        }
                    }
                }
            } catch DocumentAttachmentService.DocumentError.noDocumentSelected {
                // Ignore cancellations
            } catch let error as DocumentAttachmentService.DocumentError {
                await MainActor.run {
                    toastMessage = error.localizedDescription
                }
            } catch {
                await MainActor.run {
                    toastMessage = error.localizedDescription
                }
            }
        }
    }

    private func attachDocumentFromURL(_ url: URL) {
        _Concurrency.Task {
            do {
                let attachment = try await DocumentAttachmentService.shared.loadFromURL(url)
                await MainActor.run {
                    if !viewModel.attachDocument(attachment) {
                        if viewModel.isLoading {
                            toastMessage = "Aurora is already processing a document. Please wait for her to finish."
                        } else if viewModel.pendingDocumentAttachment != nil {
                            toastMessage = "Due to Aurora's sanity, we only allow her to process a single file at a time."
                        }
                    }
                }
            } catch let error as DocumentAttachmentService.DocumentError {
                await MainActor.run {
                    toastMessage = error.localizedDescription
                }
            } catch {
                await MainActor.run {
                    toastMessage = error.localizedDescription
                }
            }
        }
    }

    private func scrollToBottom(animated: Bool = true) {
        guard let proxy = chatScrollProxy else { return }
        let action = {
            proxy.scrollTo(chatBottomAnchor, anchor: .bottom)
        }
        if animated {
            withAnimation(reduceMotion ? nil : GlassMotion.Easing.spring) {
                action()
            }
        } else {
            action()
        }
        viewModel.isScrolledToBottom = true
    }

    @MainActor
    private func promptDocumentURL() {
        showDocumentURLDrawer = true
    }

    private func handleImagePaste(_ image: NSImage) {
        _Concurrency.Task {
            do {
                let attachment = try await ImageAttachmentService.shared.validateAndPrepare(image, preferredFileName: nil)
                await MainActor.run {
                    viewModel.attachImage(attachment)
                }
            } catch {
                await MainActor.run {
                    toastMessage = error.localizedDescription
                }
            }
        }
    }

    private func documentDetailText(for attachment: DocumentAttachmentService.DocumentAttachment) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        let sizeLabel = formatter.string(fromByteCount: Int64(attachment.sizeInBytes))
        var parts: [String] = [attachment.mimeType, sizeLabel]
        if let pages = attachment.pageCount, pages > 0 {
            parts.append("\(pages) page\(pages == 1 ? "" : "s")")
        }
        if let url = attachment.sourceURL {
            let host = url.host ?? url.absoluteString
            parts.append(host)
        }
        return parts.joined(separator: " • ")
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
        // Set up keyboard monitoring for "+" key combo
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Don't intercept if a text field or text editor is focused (unless it's our own input)
            if let firstResponder = NSApp.keyWindow?.firstResponder,
               (firstResponder is NSTextView || firstResponder is NSTextField),
               !isInputFocused {
                return event
            }
            
            // Check for Cmd+N or "+" key when input is focused
            if isInputFocused {
                // Cmd+N
                if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "n" {
                    showContextualCreateSheet = true
                    return nil
                }
                // "+" key (equality key on most keyboards)
                if event.charactersIgnoringModifiers == "+" || event.charactersIgnoringModifiers == "=" {
                    showContextualCreateSheet = true
                    return nil
                }
            }
            return event
        }
    }
    
    private func toggleVoiceInput() {
        if isRecording {
            // Stop recording and use whatever text we have
            completeVoiceInput()
        } else {
            // Start recording
            voiceInputText = ""
            _Concurrency.Task {
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
        }
    }
    
    private func completeVoiceInput() {
        // Use the current partial text if we have it
        let finalText = voiceInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Stop the recording
        voiceService.stopTranscribing()
        
        // Update the input field with whatever we captured
        if !finalText.isEmpty {
            viewModel.inputText = finalText
        }
        
        // Reset state
        isRecording = false
        voiceInputText = ""
    }
    
    private func saveCurrentToDraft() {
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
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: AIConversation
    let isSelected: Bool
    let onTap: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    let onRefreshSummary: () -> Void
    let onExportToDraft: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Pin indicator
                if conversation.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundColor(.kosmicBlue)
                }
                
                // Tags
                if !conversation.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(conversation.tags.prefix(2), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.kosmicBlue.opacity(0.15))
                                .foregroundColor(.kosmicBlue)
                                .cornerRadius(4)
                        }
                        if conversation.tags.count > 2 {
                            Text("+\(conversation.tags.count - 2)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Title
            Text(conversation.title ?? "")
                .font(.body)
                .fontWeight(isSelected ? .medium : .regular)
                .lineLimit(1)
            
            // Summary
            if let summary = conversation.summary, !summary.isEmpty {
                Text(summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Date
            Text((conversation.createdAt ?? Date()).formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            Group {
                if isSelected {
                    Color.kosmicBlue.opacity(0.1)
                } else if conversation.isPinned {
                    Color.kosmicBlue.opacity(0.05)
                } else {
                    Color.clear.background(.ultraThinMaterial)
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    conversation.isPinned ? Color.kosmicBlue.opacity(0.3) : (isSelected ? Color.kosmicBlue.opacity(0.3) : Color.clear),
                    lineWidth: conversation.isPinned ? 1.5 : 2
                )
        )
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .overlay(alignment: .trailing) {
            if isHovered {
                HStack(spacing: 8) {
                    // Continue button
                    Button(action: onTap) {
                        Image(systemName: "arrow.forward")
                            .font(.caption)
                            .padding(6)
                            .background(Color.kosmicBlue.opacity(0.1))
                            .foregroundColor(.kosmicBlue)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Continue conversation")
                    
                    // Summarize/Export button
                    if conversation.summary != nil {
                        Button(action: onRefreshSummary) {
                            Image(systemName: "doc.text")
                                .font(.caption)
                                .padding(6)
                            .background(Color.kosmicGreen.opacity(0.1))
                            .foregroundColor(.kosmicGreen)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .help("Refresh summary")
                    }
                    
                    // Export button
                    Button(action: onExportToDraft) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.caption)
                            .padding(6)
                            .background(Color.orange.opacity(0.1))
                            .foregroundColor(.orange)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Export to Drafts")
                }
                .padding(.trailing, 8)
                .transition(.opacity)
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button(conversation.isPinned ? "Unpin" : "Pin to Top", systemImage: conversation.isPinned ? "pin.slash" : "pin") {
                onTogglePin()
            }
            
            Divider()
            
            Button("Rename", systemImage: "pencil") {
                onRename()
            }
            
            if conversation.summary != nil {
                Button("Refresh Summary", systemImage: "arrow.clockwise") {
                    onRefreshSummary()
                }
            }
            
            Divider()
            
            Button("Export to Drafts", systemImage: "square.and.arrow.down") {
                onExportToDraft()
            }
            
            Divider()
            
            Button("Delete", systemImage: "trash", role: .destructive) {
                onDelete()
            }
        }
    }
}

#Preview {
    AIAssistantView()
        .modelContainer(for: [AIMessage.self, AIConversation.self])
}

#if os(macOS)
import AppKit

private struct ChatTextEditor: NSViewRepresentable {
    @Binding var text: String
    var isEditable: Bool = true
    var onSubmit: () -> Void
    var onImagePaste: ((NSImage) -> Void)? = nil
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let textView = ChatNSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        textView.drawsBackground = false
        textView.font = NSFont.preferredFont(forTextStyle: .body)
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: 200)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.backgroundColor = .clear
        textView.string = text
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.onSubmit = { onSubmit() }
        textView.onImagePaste = onImagePaste

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = context.coordinator.textView else { return }
        if textView.string != text {
            textView.string = text
            textView.selectedRange = NSRange(location: textView.string.count, length: 0)
        }
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.onSubmit = { onSubmit() }
        textView.onImagePaste = onImagePaste
    }
    
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ChatTextEditor
        weak var textView: ChatNSTextView?
        
        init(parent: ChatTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

private final class ChatNSTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onImagePaste: ((NSImage) -> Void)?
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 { // Return key
            if event.modifierFlags.contains(.shift) {
                super.insertNewline(nil)
            } else {
                onSubmit?()
            }
        } else {
            super.keyDown(with: event)
        }
    }

    override func paste(_ sender: Any?) {
        if let image = NSImage(pasteboard: .general) {
            onImagePaste?(image)
            return
        }
        super.paste(sender)
    }
}
#endif
