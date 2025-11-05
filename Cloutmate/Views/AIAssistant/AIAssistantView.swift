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
    @State private var showCreateSheet = false
    @State private var contextualCreateTab: TabIdentifier = .home
    
    private let voiceService = VoiceTranscriptionService.shared
    private let tintManager = ArteTintManager.shared
    private let usageTracker = ToolbarUsageTracker.shared
    
    var body: some View {
        HSplitView {
            // Conversations Sidebar
            conversationsSidebar
                .frame(minWidth: 250, idealWidth: 280)
            
            // Main Chat Area
            mainChatArea
                .frame(minWidth: 500)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Voice Input
                Button(action: toggleVoiceInput) {
                    Image(systemName: isRecording ? "mic.fill" : "mic.circle")
                        .foregroundColor(isRecording ? .red : .primary)
                }
                .help(isRecording ? "Stop recording" : "Voice input")
                .disabled(viewModel.isLoading)
                
                // Save to Draft
                Button(action: saveCurrentToDraft) {
                    Image(systemName: "square.and.arrow.down")
                }
                .help("Save to Draft")
                .disabled(viewModel.messages.isEmpty)
                
                // New Conversation
                Button(action: {
                    if !viewModel.messages.isEmpty {
                        showUnsavedAlert = true
                    } else {
                        viewModel.clearMessages()
                    }
                }) {
                    Image(systemName: "plus.circle")
                }
                .help("New Conversation")
            }
        }
        .onAppear {
            setupVoiceService()
            setupKeyboardHandlers()
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
        }
        .sheet(isPresented: $showCreateSheet) {
            ContextualCreateSheet(currentTab: contextualCreateTab)
        }
        .alert("AI Assistant", isPresented: $showAIInfo) {
            Button("OK") { }
        } message: {
            Text("Powered by Google Gemini, Cloutmate's AI is context-aware of your tasks, projects, posts, and notes. It can help extract tasks, suggest projects, and answer questions about your work. Your API key is stored securely in Keychain.")
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
                                isSelected: viewModel.selectedConversation?.id == conversation.id,
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
                                        _ = viewModel.exportToDraft(messages: messages, conversation: conversation, modelContext: modelContext)
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
        let loaded = viewModel.loadConversation(conversation, modelContext: modelContext)
        
        if !loaded {
            conversationToLoad = conversation
            showUnsavedAlert = true
        }
    }
    
    // MARK: - Main Chat Area
    
    private var mainChatArea: some View {
        VStack(spacing: 0) {
            // Chat Messages
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
                                        onCopy: { copiedContent in
                                            // Optional: Can show a toast or perform additional actions
                                        }
                                    )
                                    .id(message.id)
                                }
                            }
                            
                            if viewModel.isLoading {
                                ThinkingIndicator(
                                    activity: viewModel.displayedActivity,
                                    sourceModel: viewModel.currentSourceModel
                                )
                                .padding()
                            } else if !viewModel.messages.isEmpty {
                                // Idle intelligence: subtle presence when waiting for input
                                IdleIndicator()
                                    .padding(.top, 8)
                            }
                        }
                        .padding(.vertical, 16)
                        .padding(.bottom, 60) // Space for floating button
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Floating Summarize Chat Button (only show when 10+ messages)
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
                    .padding(.trailing, 16)
                    .padding(.bottom, 80)
                }
            }
            
            Divider()
                .overlay(Color.white.opacity(0.1))
            
            // Core Capabilities Toolbar
            coreCapabilitiesToolbar
            
            Divider()
                .overlay(Color.white.opacity(0.1))
            
            // Status Banner
            if let status = viewModel.currentStatus {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(status)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }
            
            // Input Area
            inputArea
            
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
    
    // MARK: - Core Capabilities Toolbar
    
    private var coreCapabilitiesToolbar: some View {
        let orderedActions = usageTracker.orderedActions()
        let tintColor = tintManager.combinedTintColor(activity: viewModel.currentActivity)
        
        return HStack(spacing: 12) {
            ForEach(orderedActions, id: \.self) { action in
                toolbarButton(for: action, tintColor: tintColor)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
    
    private func toolbarButton(for action: ToolbarAction, tintColor: Color) -> some View {
        Button(action: {
            handleToolbarAction(action)
        }) {
            Image(systemName: action.icon)
                .font(.title3)
                .symbolEffect(.pulse, isActive: showMicroFeedback == action)
        }
        .buttonStyle(ToolbarButtonStyle(tintColor: tintColor, isDisabled: viewModel.isLoading))
        .help(action.rawValue)
        .keyboardShortcut(keyboardShortcut(for: action), modifiers: [.command, .shift])
    }
    
    private func keyboardShortcut(for action: ToolbarAction) -> KeyEquivalent {
        switch action {
        case .createTask: return "1"
        case .createProject: return "2"
        case .createNote: return "3"
        case .createReminder: return "4"
        case .analyzeDocument: return "5"
        case .analyzeImage: return "6"
        }
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
        case .createTask:
            viewModel.inputText = "Create a task"
            sendCurrentMessage(modelContext: modelContext)
            
        case .createProject:
            viewModel.inputText = "Create a project"
            sendCurrentMessage(modelContext: modelContext)
            
        case .createNote:
            viewModel.inputText = "Create a note"
            sendCurrentMessage(modelContext: modelContext)
            
        case .createReminder:
            viewModel.inputText = "Create a reminder"
            sendCurrentMessage(modelContext: modelContext)
            
        case .analyzeDocument:
            presentDocumentSourceChooser()
            
        case .analyzeImage:
            attachImageFromPicker()
        }
        
        // Clear input after sending
        if action != .analyzeDocument && action != .analyzeImage {
            viewModel.inputText = ""
        }
    }
    
    // MARK: - Input Area
    
    private var inputArea: some View {
        VStack(spacing: 12) {
            // Platform selector (moved from toolbar)
            HStack(spacing: 8) {
                Text("Platform:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Platform", selection: $viewModel.selectedPlatform) {
                    ForEach(Platform.allCases, id: \.self) { platform in
                        Text(platform.displayName).tag(platform)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(maxWidth: 200)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            // Voice recording indicator
            if isRecording {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .foregroundColor(.red)
                            .symbolEffect(.variableColor.iterative, isActive: true)
                        Text("Listening...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        
                        // Done button to complete recording
                        Button(action: completeVoiceInput) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Done")
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.kosmicBlue)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        
                        // Cancel button
                        Button("Cancel") {
                            voiceService.stopTranscribing()
                            isRecording = false
                            voiceInputText = ""
                            viewModel.inputText = ""
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.red)
                    }
                    
                    // Show current transcription
                    if !voiceInputText.isEmpty {
                        Text(voiceInputText)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.5))
                            .cornerRadius(4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            
            if let document = viewModel.pendingDocumentAttachment {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.kosmicBlue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(document.fileName)
                            .font(.caption)
                            .foregroundColor(.primary)
                        Text(documentDetailText(for: document))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: viewModel.clearPendingDocument) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove document")
                }
                .padding(8)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(8)
            } else if let attachment = viewModel.pendingImageAttachment {
                HStack(spacing: 12) {
                    Image(nsImage: attachment.preview)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 72)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(attachment.fileName ?? "Attached Image")
                            .font(.caption)
                            .foregroundColor(.primary)
                        Text(attachment.mimeType)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: viewModel.clearPendingImage) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove image")
                }
                .padding(8)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(8)
            }

            // Text input area
            HStack(spacing: 12) {
                let attachmentIconName: String = {
                    if viewModel.pendingDocumentAttachment != nil {
                        return "paperclip.circle.fill"
                    }
                    if viewModel.pendingImageAttachment != nil {
                        return "photo.fill"
                    }
                    return "paperclip.circle"
                }()
                Menu {
                    Button("Document (filters only documents)", action: presentDocumentSourceChooser)
                        .disabled(viewModel.pendingDocumentAttachment != nil || viewModel.isLoading)
                    Divider()
                    Button("Image From Computer", action: attachImageFromPicker)
                    Button("Image From Photos", action: attachImageFromPhotos)
                } label: {
                    Image(systemName: attachmentIconName)
                        .font(.title3)
                        .foregroundColor(.kosmicBlue)
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .help("Attach file")
                .disabled(isRecording || viewModel.isLoading)
                ZStack(alignment: .topLeading) {
                    MentionInputField(
                        text: $viewModel.inputText,
                        isFocused: $isInputFocused,
                        placeholder: "Ask me anything...",
                        onSubmit: {
                            sendCurrentMessage(modelContext: modelContext)
                        },
                        linkedContext: $viewModel.linkedContext
                    )
                    .frame(minHeight: 38, maxHeight: 120)
                    .disabled(isRecording)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                }
                let hasAttachment = viewModel.pendingImageAttachment != nil || viewModel.pendingDocumentAttachment != nil
                let canSend = !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasAttachment
                Button(action: {
                    sendCurrentMessage(modelContext: modelContext)
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(canSend ? .kosmicBlue : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(!canSend || isRecording)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
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

    private func presentDocumentSourceChooser() {
        _Concurrency.Task { @MainActor in
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
            // Check for Cmd+N or "+" key when input is focused
            if isInputFocused {
                // Cmd+N
                if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "n" {
                    showCreateSheet = true
                    return nil
                }
                // "+" key (equality key on most keyboards)
                if event.charactersIgnoringModifiers == "+" || event.charactersIgnoringModifiers == "=" {
                    showCreateSheet = true
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
        
        _ = viewModel.exportToDraft(messages: messages, conversation: conversation, modelContext: modelContext)
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
