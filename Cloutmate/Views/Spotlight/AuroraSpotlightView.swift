//
//  AuroraSpotlightView.swift
//  Cloutmate
//
//  Spotlight-style overlay for Aurora quick access
//

import SwiftUI
import SwiftData
import AppKit

struct AuroraSpotlightView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = AuroraSpotlightViewModel()
    @FocusState private var isInputFocused: Bool
    @FocusState private var isBottomInputFocused: Bool
    @State private var bottomInputText = ""
    @State private var isMultiLine = false
    @State private var showCreateSheet = false
    @State private var contextualCreateTab: TabIdentifier = .home
    
    // Query to observe messages from the current conversation (backup)
    @Query private var allMessages: [AIMessage]
    
    // Computed property to get messages from current conversation
    // Primary: Use ViewModel messages (updated via polling)
    // Fallback: Filter @Query messages if ViewModel is empty
    private var conversationMessages: [AIMessage] {
        // Use ViewModel messages first (they're updated via polling)
        if !viewModel.messages.isEmpty {
            return viewModel.messages.sorted(by: { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) })
        }
        
        // Fallback to query if ViewModel hasn't loaded yet
        if let conversationId = viewModel.currentConversation?.id {
            return allMessages.filter { message in
                if let msgConversationId = message.conversation?.id {
                    return msgConversationId == conversationId
                }
                return false
            }
            .sorted(by: { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) })
        }
        
        return []
    }
    
    private func handleTopInputSubmit() {
        let textToSend = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !textToSend.isEmpty {
            // Clear input immediately for better UX
            viewModel.inputText = ""
            // Send message asynchronously
            Task {
                await viewModel.sendMessage(textToSend, modelContext: modelContext)
            }
        }
    }
    
    private func handleBottomInputSubmit() {
        let textToSend = bottomInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !textToSend.isEmpty {
            // Clear input immediately
            bottomInputText = ""
            isMultiLine = false
            // Send message asynchronously
            Task {
                await viewModel.sendMessage(textToSend, modelContext: modelContext)
                // Refocus bottom input after sending
                try? await Task.sleep(nanoseconds: 100_000_000)
                await MainActor.run {
                    isBottomInputFocused = true
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag handle at the top
            dragHandle
            
            topInputArea
            messageArea
            bottomInputArea
        }
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 20)
        .frame(width: 600)
        .onAppear {
            // Load existing conversation messages when Spotlight opens
            Task {
                await viewModel.loadCurrentConversation(modelContext: modelContext)
            }
            
            if viewModel.messages.isEmpty {
                isInputFocused = true
            } else {
                isBottomInputFocused = true
            }
        }
        .onDisappear {
            // Stop polling when Spotlight closes
            viewModel.stopPolling()
        }
        .onChange(of: viewModel.messages.count) { oldCount, newCount in
            // Focus bottom input when Aurora replies
            if newCount > oldCount && !viewModel.isLoading {
                // Wait a moment for the reply to appear
                Task {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    await MainActor.run {
                        isBottomInputFocused = true
                    }
                }
            }
        }
        .onChange(of: viewModel.isLoading) { _, isLoading in
            // Focus bottom input when loading finishes
            if !isLoading && !viewModel.messages.isEmpty {
                Task {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    await MainActor.run {
                        isBottomInputFocused = true
                    }
                }
            }
        }
        .onChange(of: viewModel.messages) { _, _ in
            // Force view update when messages change
            // This ensures SwiftUI detects changes to the array
        }
        .onKeyPress(.escape) {
            AuroraSpotlightWindowController.shared.close()
            return .handled
        }
        .onAppear {
            setupKeyboardHandlers()
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
    }
    
    private func setupKeyboardHandlers() {
        // Set up keyboard monitoring for "+" key combo
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Don't intercept if a text field or text editor is focused (unless it's our own input)
            if let firstResponder = NSApp.keyWindow?.firstResponder,
               (firstResponder is NSTextView || firstResponder is NSTextField),
               !(isInputFocused || isBottomInputFocused) {
                return event
            }
            
            // Check for Cmd+N or "+" key when input is focused
            if isInputFocused || isBottomInputFocused {
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
    
    private var dragHandle: some View {
        HStack {
            Spacer()
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 4)
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            // Allow dragging from the handle
        }
    }
    
    private var topInputArea: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundColor(.kosmicBlue)
                .font(.title3)
            
            MentionInputField(
                text: $viewModel.inputText,
                isFocused: $isInputFocused,
                placeholder: "Ask Aurora...",
                onSubmit: {
                    // Only submit if there's actual text (prevent auto-submit)
                    let trimmed = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        handleTopInputSubmit()
                    }
                },
                linkedContext: Binding(
                    get: { LinkedContext() },
                    set: { _ in }
                )
            )
            
            // Pop-out button (only show when there are messages)
            if !viewModel.messages.isEmpty {
                Button(action: {
                    // Switch to AI Assistant tab and select current conversation
                    NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.aiAssistant)
                    
                    // Post notification to select the conversation
                    if let conversation = viewModel.currentConversation {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("SelectAIConversation"),
                            object: conversation
                        )
                    }
                    
                    // Close spotlight
                    AuroraSpotlightWindowController.shared.close()
                }) {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.kosmicBlue)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Open in AI Assistant")
            }
            
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .overlay(
            Divider(),
            alignment: .bottom
        )
    }
    
    private var sortedMessages: [AIMessage] {
        viewModel.messages.sorted(by: { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) })
    }
    
    private var messageArea: some View {
        Group {
            if !viewModel.messages.isEmpty || viewModel.isLoading {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            // Show execution confirmation if present (instead of full chat bubbles)
                            if let confirmation = viewModel.executionConfirmation {
                                AuroraSpotlightActionConfirmation(
                                    message: confirmation,
                                    isVisible: Binding(
                                        get: { viewModel.executionConfirmation != nil },
                                        set: { if !$0 { viewModel.executionConfirmation = nil } }
                                    )
                                )
                                .padding(.horizontal, 16)
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                            
                            // Show chat bubbles for conversational responses (only if not execution)
                            if !viewModel.isExecutionRequest || viewModel.executionConfirmation == nil {
                                ForEach(sortedMessages, id: \.id) { message in
                                    AuroraSpotlightBubble(message: message)
                                        .padding(.horizontal, 16)
                                        .transition(.opacity)
                                        .id(message.id)
                                }
                            }
                            
                            // Show thinking indicator when loading
                            if viewModel.isLoading {
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.kosmicBlue)
                                        .font(.caption)
                                        .symbolEffect(.pulse)
                                    Text("Thinking...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.vertical, 16)
                    }
                    .frame(maxHeight: 400)
                    .onChange(of: viewModel.messages.count) { _, _ in
                        // Scroll to bottom when new messages arrive
                        if let lastMessage = sortedMessages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            } else {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundColor(.kosmicBlue)
                    Text("Ask Aurora anything")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Create tasks, ask questions, or get help")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
            }
        }
    }
    
    private var bottomInputArea: some View {
        Group {
            if !viewModel.messages.isEmpty && !viewModel.isLoading {
                VStack(spacing: 0) {
                    Divider()
                    
                    HStack(spacing: 12) {
                        // Single-line input that expands on Shift+Enter
                        ZStack(alignment: .topLeading) {
                            TextField("Reply to Aurora...", text: $bottomInputText, axis: isMultiLine ? .vertical : .horizontal)
                                .textFieldStyle(.plain)
                                .font(.body)
                                .focused($isBottomInputFocused)
                                .lineLimit(isMultiLine ? nil : 1)
                                .onKeyPress(.return) {
                                    // Check if Shift is currently pressed
                                    if NSEvent.modifierFlags.contains(.shift) {
                                        // Expand to multi-line
                                        isMultiLine = true
                                        return .handled
                                    } else {
                                        // Send message
                                        handleBottomInputSubmit()
                                        return .handled
                                    }
                                }
                        }
                        .frame(height: isMultiLine ? nil : 32)
                        .frame(maxHeight: isMultiLine ? 120 : 32)
                        
                        if viewModel.isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                    .padding(12)
                    .background(.regularMaterial)
                    
                    // Footer
                    HStack {
                        Text("Press ⌘⇧A to open")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("ESC to close")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            } else {
                // Footer (when no messages)
                HStack {
                    Text("Press ⌘⇧A to open")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("ESC to close")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
    }
}

#Preview {
    AuroraSpotlightView()
        .modelContainer(for: [AIConversation.self, AIMessage.self])
}

