//
//  AIAssistantView.swift
//  Cloutmate
//
//  AI Creative Assistant Main View
//

import SwiftUI
import SwiftData

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
                Button(action: { showAIInfo = true }) {
                    Image(systemName: "info.circle")
                }
                
                Menu("Platform", systemImage: "globe") {
                    ForEach(Platform.allCases, id: \.self) { platform in
                        Button(action: {
                            viewModel.selectedPlatform = platform
                        }) {
                            Label(platform.displayName, systemImage: viewModel.selectedPlatform == platform ? "checkmark" : "")
                        }
                    }
                }
                
                Button("New Chat", systemImage: "square.and.pencil") {
                    if !viewModel.messages.isEmpty {
                        showUnsavedAlert = true
                    } else {
                        viewModel.clearMessages()
                    }
                }
            }
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
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }
                            }
                            
                            if viewModel.isLoading {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("AI is thinking...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
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
                .overlay(Color.white.opacity(0.2))
            
            // Quick Action Tools
            quickActionTools
            
            Divider()
                .overlay(Color.white.opacity(0.2))
            
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
        }
    }
    
    // MARK: - Welcome View
    
    private var welcomeView: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 8) {
                Text("AI Creative Assistant")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("I can help you brainstorm, generate hooks, write captions, improve text, suggest hashtags, and more!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)
            }
            
            Text("Select a tool above or ask me anything below")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Quick Action Tools
    
    private var quickActionTools: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach([AITool.brainstorm, .generateCaptions, .improveText, .suggestHashtags, .adjustTone], id: \.self) { tool in
                    AIToolButton(tool: tool) {
 		_Concurrency.Task {
                            await viewModel.executeQuickTool(tool, topic: "Create content for \(viewModel.selectedPlatform.displayName)", modelContext: modelContext)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Input Area
    
    private var inputArea: some View {
        HStack(spacing: 12) {
            TextField("Ask me anything...", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .onSubmit {
                    if !viewModel.inputText.isEmpty {
                        viewModel.sendMessage(viewModel.inputText, modelContext: modelContext)
                    }
                }
            
            Button(action: {
                viewModel.sendMessage(viewModel.inputText, modelContext: modelContext)
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(viewModel.inputText.isEmpty ? .secondary : .blue)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.inputText.isEmpty)
        }
        .padding()
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
                        .foregroundColor(.blue)
                }
                
                // Tags
                if !conversation.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(conversation.tags.prefix(2), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .foregroundColor(.blue)
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
                    Color.blue.opacity(0.1)
                } else if conversation.isPinned {
                    Color.blue.opacity(0.05)
                } else {
                    Color.clear.background(.ultraThinMaterial)
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    conversation.isPinned ? Color.blue.opacity(0.3) : (isSelected ? Color.blue.opacity(0.3) : Color.clear),
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
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
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
                                .background(Color.green.opacity(0.1))
                                .foregroundColor(.green)
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
