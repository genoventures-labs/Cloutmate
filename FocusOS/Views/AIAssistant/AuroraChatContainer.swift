//
//  AuroraChatContainer.swift
//  FocusOS
//
//  Floating Aurora chat surface with sidebar + thread.
//

import SwiftUI
import SwiftData
import FocusOSShared
import AppKit

struct AuroraChatContainer: View {
    struct ConversationHandlers {
        var onTap: (AIConversation) -> Void
        var onRename: (AIConversation) -> Void
        var onDelete: (AIConversation) -> Void
        var onTogglePin: (AIConversation) -> Void
        var onRefreshSummary: (AIConversation) -> Void
        var onExportToDraft: (AIConversation) -> Void
    }

    struct ToolbarHandlers {
        var onSmartRecap: () -> Void
        var onExportToDraft: () -> Void
        var onVoiceInput: () -> Void
        var onToolbarAction: (ToolbarAction) -> Void
        var onWebSearch: () -> Void
        var onLinkContext: () -> Void
        var onToggleOffline: () -> Void
        var isOffline: () -> Bool
    }

    struct HeaderHandlers {
        var onSearch: () -> Void
        var onNewChat: () -> Void
        var onSettings: () -> Void
    }

    struct ComposerHandlers {
        var onSend: () -> Void
        var onAttachImage: () -> Void
        var onAttachScreenshot: () -> Void
        var onAttachDocument: () -> Void
        var onClearImage: () -> Void
        var onClearDocument: () -> Void
        var onStop: () -> Void
        var onRetry: () -> Void
        var onResendLastAssistant: (() -> Void)?
        var onDetachContext: () -> Void
        var onDetachChip: ((String) -> Void)?
    }

    let viewModel: AIAssistantViewModel
    let conversations: [AIConversation]
    let arteGradientColors: [Color]
    let accentColor: Color
    let glowColor: Color
    let conversationHandlers: ConversationHandlers
    let toolbarHandlers: ToolbarHandlers
    let manualContextLabels: [String]
    let headerHandlers: HeaderHandlers
    let composerHandlers: ComposerHandlers
    var onAttachTab: ((TabIdentifier) -> Void)?
    var onDetachTab: (() -> Void)?
    var onSlashCommand: ((SlashCommand, NSRange) -> Void)?
    var messageFlags: [String: Bool] = [:]
    var showAuroraCreateSheet: Bool = false
    var createSheetAction: ToolbarAction? = nil
    var onCreateSheetComplete: ((String) -> Void)? = nil
    var onCreateSheetDismiss: (() -> Void)? = nil

    @Binding var isRecording: Bool
    @Binding var voiceInputText: String
    @FocusState.Binding var isInputFocused: Bool

    // Dynamic behaviour
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem

    @State private var sidebarExpanded = false
    @State private var scrollProxy: ScrollViewProxy?
    @State private var panelHeight: CGFloat = 540
    @State private var threadHeight: CGFloat = 0
    @State private var barGlowPhase: Double = 0
    @State private var highlightContext = false
    @State private var replyPulse = false
    
    // Autocomplete state - shared between input bar and drawer
    @State private var showMentionAutocomplete = false
    @State private var showHashtagAutocomplete = false
    @State private var showSlashAutocomplete = false
    @State private var showEmojiDrawer = false
    @State private var emojiFilterKeyword: String? = nil
    @State private var filteredEmojis: [String] = []
    @State private var emojiSearchQuery: String = ""
    @State private var autocompleteResults: [WorkspaceObjectResult] = []
    @State private var hashtagResults: [WorkspaceObjectResult] = []
    @State private var slashCommands: [SlashCommand] = []
    @State private var autocompleteSelectedIndex = 0
    @State private var hashtagSelectedIndex = 0
    @State private var slashSelectedIndex = 0
    @State private var autocompleteCursorPosition: CGPoint = .zero
    @State private var activeTabFilter: ObjectType? = nil
    @State private var inputContainerFrame: CGRect = .zero
    @State private var inputBarFrame: CGRect = .zero
    @State private var inputTextFieldFrame: CGRect = .zero
    @State private var chatAreaWidth: CGFloat = 0

    private let chatBottomAnchor = "aurora-chat-bottom-anchor"
    
    // Preference key for tracking input container frame
    struct InputContainerFramePreferenceKey: PreferenceKey {
        static var defaultValue: CGRect = .zero
        static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
            value = nextValue()
        }
    }
    
    // Preference key for tracking input bar frame (for drawer anchoring)
    struct InputBarFramePreferenceKey: PreferenceKey {
        static var defaultValue: CGRect = .zero
        static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
            value = nextValue()
        }
    }
    
    // Preference key for tracking chat area width
    struct ChatAreaWidthPreferenceKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }
    
    struct InputTextFieldFramePreferenceKey: PreferenceKey {
        static var defaultValue: CGRect = .zero
        static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
            value = nextValue()
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            panelBody
                .background(panelBackground)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(borderGradient, lineWidth: 1.2)
                        .shadow(color: glowColor.opacity(0.35), radius: 20, y: 14)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(
                            accentColor.opacity(highlightContext ? 0.55 : 0.0),
                            lineWidth: highlightContext ? 2.0 : 0.0
                        )
                        .animation(.easeInOut(duration: 0.25), value: highlightContext)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(glowColor.opacity(replyPulse ? 0.45 : 0.0), lineWidth: replyPulse ? 1.6 : 0.0)
                        .animation(.easeOut(duration: 0.35), value: replyPulse)
                )
                .overlay(alignment: .topTrailing) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.85), glowColor.opacity(0.65)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 90, height: 4)
                        .opacity(0.35 + 0.15 * sin(barGlowPhase))
                        .offset(x: -44, y: 16)
                }
                .frame(maxWidth: .infinity, minHeight: clampedPanelHeight, maxHeight: .infinity)
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
                .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: glowColor.opacity(0.18), radius: 60, y: 28)
                .transition(
                    AnyTransition.move(edge: .bottom)
                        .combined(with: .opacity)
                        .animation(.easeOut(duration: 0.4))
                )
                .onAppear {
                    withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                        barGlowPhase = .pi * 2
                    }
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    private var panelBody: some View {
        ZStack(alignment: .bottomLeading) {
            HStack(alignment: .top, spacing: 24) {
                sidebar
                    .frame(width: sidebarExpanded ? 280 : 260)
                    .onHover { hover in
                        withAnimation(.easeOut(duration: 0.25)) {
                            sidebarExpanded = hover
                        }
                    }

                mainThread
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .coordinateSpace(name: "panelBody")
            
            // Autocomplete drawer - now rendered in conversationScroll area, docked to bottom
        }
    }

    private var sidebar: some View {
        VStack(spacing: 16) {
            AIAssistantSidebar(
                conversations: conversations,
                selectedConversation: viewModel.currentConversation,
                searchText: Binding(
                    get: { viewModel.searchText },
                    set: { viewModel.searchText = $0 }
                ),
                selectedDateFilter: Binding(
                    get: { viewModel.selectedDateFilter },
                    set: { viewModel.selectedDateFilter = $0 }
                ),
                selectedTags: Binding(
                    get: { viewModel.selectedTags },
                    set: { viewModel.selectedTags = $0 }
                ),
                onConversationTap: conversationHandlers.onTap,
                onRename: conversationHandlers.onRename,
                onDelete: conversationHandlers.onDelete,
                onTogglePin: conversationHandlers.onTogglePin,
                onRefreshSummary: conversationHandlers.onRefreshSummary,
                onExportToDraft: conversationHandlers.onExportToDraft
            )
            .environment(\.glassTier, .contentCard)
        }
        .padding(20)
        .frame(minWidth: 248, maxWidth: 300, maxHeight: .infinity, alignment: .top)
        .background(sectionBackground(cornerRadius: 26))
    }

    private var mainThread: some View {
        VStack(spacing: 24) {
            headerSection
            conversationSection
            composerSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .coordinateSpace(name: "mainThread")
    }

    private var headerSection: some View {
        header
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(sectionBackground(cornerRadius: 26))
    }

    private var conversationSection: some View {
        conversationScroll
            .padding(24)
            .background(sectionBackground(cornerRadius: 26))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                GeometryReader { geometry in
                    // Track the INSIDE width of the container card (content area, not including padding)
                    // The geometry.size.width here is the full width including padding
                    // We want the content width inside, so we subtract padding (24 on each side = 48 total)
                    Color.clear.preference(
                        key: ChatAreaWidthPreferenceKey.self,
                        value: geometry.size.width - 48 // Subtract padding to get inside width
                    )
                }
            )
    }

    private var composerSection: some View {
        inputSection
            .padding(24)
            .background(sectionBackground(cornerRadius: 26))
            .background(
                GeometryReader { geometry in
                    // Get frame relative to panelBody coordinate space
                    let frameInPanel = geometry.frame(in: .named("panelBody"))
                    Color.clear.preference(
                        key: InputContainerFramePreferenceKey.self,
                        value: frameInPanel
                    )
                }
            )
    }

    private var header: some View {
        AIAssistantHeaderView(
            onSearch: headerHandlers.onSearch,
            onNewChat: headerHandlers.onNewChat,
            onSettings: headerHandlers.onSettings,
            selectedFilter: Binding(
                get: { viewModel.selectedDateFilter },
                set: { viewModel.selectedDateFilter = $0 }
            )
        )
        .environment(\.glassTier, .overlay)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private var conversationScroll: some View {
        GeometryReader { geometry in
            let backgroundGradient: AnyShapeStyle = AnyShapeStyle(
                LinearGradient(
                    colors: arteGradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ).opacity(highlightContext ? 0.22 : 0.12)
            )
            
            // Drawer height (responsive - max 400px, but adapts to container)
            let drawerHeight: CGFloat = min(400, geometry.size.height * 0.5) // Responsive height, max 400px

            ZStack(alignment: .bottomTrailing) {
                // Chat content - hide when AuroraCreateSheet is visible
                if !showAuroraCreateSheet {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 12) {
                                if viewModel.messages.isEmpty {
                                    welcomeView
                                        .padding(.top, 80)
                                        .opacity((showSlashAutocomplete || showMentionAutocomplete || showHashtagAutocomplete) ? 0 : 1)
                                        .transition(.opacity)
                                } else {
                                    ForEach(viewModel.messages) { message in
                                        MessageBubble(
                                            message: message,
                                            onEdit: { edited, newContent in
                                                viewModel.editAndRegenerateMessage(
                                                    edited,
                                                    newContent: newContent,
                                                    modelContext: modelContext
                                                )
                                            },
                                            onCopy: { _ in },
                                            onResend: { assistantMessage in
                                                viewModel.resendAssistantMessage(
                                                    assistantMessage,
                                                    modelContext: modelContext
                                                )
                                            },
                                            canResend: viewModel.canResendPayload(for: message)
                                        )
                                        .id(message.id)
                                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                                    }
                                }

                                if viewModel.isLoading {
                                    if viewModel.researchModeActive {
                                        // Show progress indicator if we have an action, otherwise show "Starting research..."
                                        let action = viewModel.currentResearchAction ?? "Starting research..."
                                        ResearchProgressIndicator(
                                            action: action,
                                            sourceCount: viewModel.currentResearchSourceCount
                                        )
                                        .padding()
                                    } else {
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
                                                value: bottomGeo.frame(in: .named("auroraThread")).minY
                                            )
                                        }
                                    )
                            }
                            .padding(.top, viewModel.messages.isEmpty ? 56 : 12)
                            .padding(.bottom, 56)
                            .background(
                                GeometryReader { contentGeometry in
                                    Color.clear.preference(
                                        key: ThreadHeightPreferenceKey.self,
                                        value: contentGeometry.size.height
                                    )
                                }
                            )
                        } // Close ScrollView
                        .coordinateSpace(name: "auroraThread")
                        .background(backgroundGradient)
                        .onAppear {
                            scrollProxy = proxy
                            if viewModel.isScrolledToBottom {
                                scrollToBottom(animated: false)
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
                        .transition(.opacity)
                        .opacity(showAuroraCreateSheet ? 0 : 1)
                    }
                }


                // Action buttons - hide when AuroraCreateSheet is visible
                if !showAuroraCreateSheet {
                    VStack(alignment: .trailing, spacing: 14) {
                        if viewModel.messages.count >= 10 {
                            summarizeButton
                        }

                        ScrollToBottomButton(isVisible: !viewModel.isScrolledToBottom) {
                            scrollToBottom(animated: true)
                        }
                    }
                    .padding(.trailing, 18)
                    .padding(.bottom, 48)
                    .transition(.opacity)
                }
                
                // Mention drawer - docked to bottom, edge-to-edge (highest priority)
                if showMentionAutocomplete && !autocompleteResults.isEmpty {
                    VStack {
                        Spacer()
                        MentionDrawerView(
                            results: autocompleteResults,
                            selectedIndex: autocompleteSelectedIndex,
                            onSelect: { result in
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("MentionAutocompleteSelect"),
                                    object: result
                                )
                            },
                            tabFilter: activeTabFilter,
                            arteGradientColors: arteGradientColors
                        )
                        .environmentObject(glassColorSystem)
                        .frame(width: geometry.size.width, height: drawerHeight)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                                removal: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95))
                            )
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showMentionAutocomplete)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
                
                // Hashtag drawer - docked to bottom, edge-to-edge (medium priority)
                if showHashtagAutocomplete && !hashtagResults.isEmpty {
                    VStack {
                        Spacer()
                        HashtagDrawerView(
                            results: hashtagResults,
                            selectedIndex: hashtagSelectedIndex,
                            onSelect: { result in
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("HashtagAutocompleteSelect"),
                                    object: result
                                )
                            },
                            arteGradientColors: arteGradientColors
                        )
                        .environmentObject(glassColorSystem)
                        .frame(width: geometry.size.width, height: drawerHeight)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                                removal: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95))
                            )
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showHashtagAutocomplete)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
                
                // Slash command drawer - docked to bottom, edge-to-edge (lowest priority)
                if showSlashAutocomplete && !slashCommands.isEmpty {
                    VStack {
                        Spacer()
                        SlashCommandDrawerView(
                            commands: slashCommands,
                            selectedIndex: slashSelectedIndex,
                            onSelect: { command in
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("SlashAutocompleteSelect"),
                                    object: command
                                )
                            },
                            arteGradientColors: arteGradientColors
                        )
                        .environmentObject(glassColorSystem)
                        .frame(width: geometry.size.width, height: drawerHeight)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                                removal: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95))
                            )
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showSlashAutocomplete)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
                
                // Emoji drawer - docked to bottom, edge-to-edge
                if showEmojiDrawer {
                    VStack {
                        Spacer()
                        EmojiDrawerView(
                            filteredKeyword: emojiFilterKeyword,
                            searchQuery: emojiSearchQuery,
                            onSelect: { emoji in
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("EmojiSelected"),
                                    object: emoji
                                )
                                EmojiService.shared.recordEmojiUse(emoji)
                                showEmojiDrawer = false
                            },
                            arteGradientColors: arteGradientColors
                        )
                        .environmentObject(glassColorSystem)
                        .frame(width: geometry.size.width, height: drawerHeight)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                                removal: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95))
                            )
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showEmojiDrawer)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
                
                // AuroraCreateSheet drawer - full screen overlay (only thing visible when shown)
                if showAuroraCreateSheet && !showMentionAutocomplete && !showHashtagAutocomplete && !showSlashAutocomplete, let action = createSheetAction {
                    AuroraCreateSheet(
                        action: action,
                        isPresented: Binding(
                            get: { showAuroraCreateSheet },
                            set: { if !$0 { onCreateSheetDismiss?() } }
                        ),
                        onComplete: { prompt in
                            onCreateSheetComplete?(prompt)
                        },
                        height: geometry.size.height
                    )
                    .environmentObject(glassColorSystem)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .background(glassColorSystem.backgroundColor())
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                            removal: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.95))
                        )
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showAuroraCreateSheet)
                    .zIndex(10) // Ensure it's above chat content
                }
            }
            .onPreferenceChange(ChatScrollOffsetPreferenceKey.self) { bottomOffset in
                updateBottomState(bottomOffset: bottomOffset)
            }
            .onPreferenceChange(ThreadHeightPreferenceKey.self) { height in
                DispatchQueue.main.async {
                    threadHeight = height
                    recalculatePanelHeight()
                }
            }
        }
    }

    private var summarizeButton: some View {
        Button(action: {
            _Concurrency.Task {
                await viewModel.generateChatSummary()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                Text("Summarize Chat")
            }
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .foregroundColor(.primary)
            .cornerRadius(18)
            .shadow(color: .black.opacity(0.18), radius: 12)
        }
        .buttonStyle(.plain)
        .help("Generate session summary")
    }

    private var inputSection: some View {
        let inputBinding = Binding(
            get: { viewModel.inputText },
            set: { viewModel.inputText = $0 }
        )
        let linkedContextBinding = Binding(
            get: { viewModel.linkedContext },
            set: { viewModel.linkedContext = $0 }
        )

        let warmupService = ModelWarmupService.shared
        let isWarmupInProgress = warmupService.isWarmingUp || !warmupService.isReady

        return AuroraChatInputBar(
            text: inputBinding,
            linkedContext: linkedContextBinding,
            isFocused: $isInputFocused,
            isRecording: $isRecording,
            voiceInputText: $voiceInputText,
            isLoading: viewModel.isLoading || isWarmupInProgress,
            pendingImageAttachment: viewModel.pendingImageAttachment,
            pendingDocumentAttachment: viewModel.pendingDocumentAttachment,
            lastConfidenceScore: viewModel.messages.last(where: { $0.role == "assistant" })?.confidenceScore,
            canRetry: viewModel.canRetry,
            onResendLastAssistant: composerHandlers.onResendLastAssistant,
            onSend: {
                // Block sending during warmup
                guard !isWarmupInProgress else { return }
                triggerReplyPulse()
                composerHandlers.onSend()
            },
            onAttachDocument: composerHandlers.onAttachDocument,
            onAttachImage: composerHandlers.onAttachImage,
            onAttachScreenshot: composerHandlers.onAttachScreenshot,
            onClearDocument: composerHandlers.onClearDocument,
            onClearImage: composerHandlers.onClearImage,
            onStop: composerHandlers.onStop,
            onRetry: composerHandlers.onRetry,
            onToggleVoice: toolbarHandlers.onVoiceInput,
            onWebSearch: toolbarHandlers.onWebSearch,
            onActionSelected: handleQuickAction(_:),
            onAttachTab: onAttachTab,
            onSlashCommand: onSlashCommand,
            onToggleEmoji: {
                isInputFocused = true // CRITICAL: Prevent macOS from unfocusing input field
                showEmojiDrawer.toggle()
                // Close other drawers when emoji drawer opens
                if showEmojiDrawer {
                    showMentionAutocomplete = false
                    showHashtagAutocomplete = false
                    showSlashAutocomplete = false
                }
            },
            isOfflineMode: toolbarHandlers.isOffline(),
            accentColor: accentColor,
            glowColor: glowColor,
            contextChips: contextChipTitles,
            onDetachContext: composerHandlers.onDetachContext,
            onDetachChip: { chipLabel in
                composerHandlers.onDetachChip?(chipLabel)
            },
            onHoverContext: { hovering in
                withAnimation(.easeInOut(duration: 0.25)) {
                    highlightContext = hovering
                }
            },
            hasThinkFlag: messageFlags["think"] ?? false,
            hasWebFlag: messageFlags["web"] ?? false,
            isResearchMode: viewModel.researchModeActive,
            onAutocompleteVisibilityChanged: { showMention, showHashtag, showSlash, position, mentionResults, hashtagResults, commands, mentionIndex, hashtagIndex, slashIndex, tabFilter in
                showMentionAutocomplete = showMention
                showHashtagAutocomplete = showHashtag
                showSlashAutocomplete = showSlash
                autocompleteCursorPosition = position
                autocompleteResults = mentionResults
                self.hashtagResults = hashtagResults
                slashCommands = commands
                autocompleteSelectedIndex = mentionIndex
                hashtagSelectedIndex = hashtagIndex
                slashSelectedIndex = slashIndex
                activeTabFilter = tabFilter
            },
            onEmojiAutocompleteVisibilityChanged: { visible, matchedEmojis, keyword in
                showEmojiDrawer = visible
                emojiFilterKeyword = keyword
                filteredEmojis = matchedEmojis
                emojiSearchQuery = keyword ?? ""
                // Close other drawers when emoji drawer opens
                if visible {
                    showMentionAutocomplete = false
                    showHashtagAutocomplete = false
                    showSlashAutocomplete = false
                }
            },
            onClearResearchMode: {
                viewModel.clearResearchMode()
            }
        )
        .onPreferenceChange(InputContainerFramePreferenceKey.self) { frame in
            if frame.width > 0 && frame.height > 0 {
                inputContainerFrame = frame
            }
        }
        .onPreferenceChange(InputBarFramePreferenceKey.self) { frame in
            if frame.width > 0 && frame.height > 0 {
                inputBarFrame = frame
            }
        }
        .onPreferenceChange(InputTextFieldFramePreferenceKey.self) { frame in
            if frame.width > 0 && frame.height > 0 {
                inputTextFieldFrame = frame
            }
        }
        .onPreferenceChange(ChatAreaWidthPreferenceKey.self) { width in
            if width > 0 {
                chatAreaWidth = width
            }
        }
        .onChange(of: contextChipTitles.isEmpty) { _, isEmpty in
            if isEmpty && highlightContext {
                highlightContext = false
            }
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [accentColor, glowColor],
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

                Text("Ask anything, attach documents, or explore Aurora Actions to accelerate your workflow.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var panelBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)

            LinearGradient(
                colors: [
                    accentColor.opacity(0.18),
                    glowColor.opacity(0.14),
                    Color.black.opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.plusLighter)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                accentColor.opacity(0.55),
                glowColor.opacity(0.45),
                accentColor.opacity(0.35)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    private var clampedPanelHeight: CGFloat {
        max(420, panelHeight)
    }

    // MARK: - Helpers

    private func updateBottomState(bottomOffset: CGFloat) {
        DispatchQueue.main.async {
            let containerHeight = clampedPanelHeight - 180
            let isAtBottom = bottomOffset <= containerHeight + 32
            if viewModel.isScrolledToBottom != isAtBottom {
                viewModel.isScrolledToBottom = isAtBottom
            }
        }
    }

    private func scrollToBottom(animated: Bool) {
        guard let proxy = scrollProxy else { return }
        let action = {
            proxy.scrollTo(chatBottomAnchor, anchor: .bottom)
        }
        if animated {
            withAnimation(GlassMotion.Easing.spring) {
                action()
            }
        } else {
            action()
        }
        viewModel.isScrolledToBottom = true
    }

    private func recalculatePanelHeight() {
        let basePadding: CGFloat = 320 // header + toolbar + composer + chrome
        panelHeight = basePadding + threadHeight
    }

    private func sectionBackground(cornerRadius: CGFloat = 26) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 18, y: 8)
    }

    private var contextChipTitles: [String] {
        var labels: [String] = []
        labels.append(contentsOf: manualContextLabels)
        labels.append(contentsOf: viewModel.linkedContext.mentionMap.values.map { $0.displayName })
        let unique = Set(labels.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        return unique.sorted()
    }

    private func triggerReplyPulse() {
        replyPulse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeOut(duration: 0.2)) {
                replyPulse = false
            }
        }
    }

    private func handleQuickAction(_ action: AuroraChatQuickAction) {
        switch action {
        case .createTask:
            toolbarHandlers.onToolbarAction(.createTask)
        case .createProject:
            toolbarHandlers.onToolbarAction(.createProject)
        case .createNote:
            toolbarHandlers.onToolbarAction(.createNote)
        case .createReminder:
            toolbarHandlers.onToolbarAction(.createReminder)
        case .attachTab:
            // Tab attachment is handled directly through the menu's onAttachTab callback
            break
        case .smartRecap:
            toolbarHandlers.onSmartRecap()
        case .exportDraft:
            toolbarHandlers.onExportToDraft()
        case .toggleOffline:
            toolbarHandlers.onToggleOffline()
        }
    }
}

// MARK: - Preference Keys

private struct ChatScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ThreadHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Slash Drawer Animation Modifier

struct SlashDrawerAnimationModifier: ViewModifier {
    let isVisible: Bool
    @State private var slideOffset: CGFloat = 4
    @State private var opacity: Double = 0
    
    func body(content: Content) -> some View {
        content
            .offset(y: slideOffset)
            .opacity(opacity)
            .onAppear {
                // When view first appears, if visible, animate in
                if isVisible {
                    slideOffset = 4
                    opacity = 0
                    // Appear: 100ms ease-out fade + 4px upward slide (opacity 0→1, translateY 4px→0)
                    withAnimation(.easeOut(duration: 0.1)) {
                        slideOffset = 0
                        opacity = 1
                    }
                } else {
                    slideOffset = 4
                    opacity = 0
                }
            }
            .onChange(of: isVisible) { oldValue, newValue in
                if newValue && !oldValue {
                    // Appear: 100ms ease-out fade + 4px upward slide (opacity 0→1, translateY 4px→0)
                    slideOffset = 4
                    opacity = 0
                    withAnimation(.easeOut(duration: 0.1)) {
                        slideOffset = 0
                        opacity = 1
                    }
                } else if !newValue && oldValue {
                    // Disappear: 75ms ease-in fade reverse
                    withAnimation(.easeIn(duration: 0.075)) {
                        slideOffset = 4
                        opacity = 0
                    }
                }
            }
    }
}

#Preview {
    AuroraChatContainerPreview()
}

private struct AuroraChatContainerPreview: View {
    @State private var viewModel = AIAssistantViewModel()
    @State private var isRecording = false
    @State private var voiceText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        AuroraChatContainer(
            viewModel: viewModel,
            conversations: [],
            arteGradientColors: [.kosmicBlue.opacity(0.4), .kosmicPurple.opacity(0.35)],
            accentColor: .kosmicBlue,
            glowColor: .kosmicPurple,
            conversationHandlers: .init(
                onTap: { _ in },
                onRename: { _ in },
                onDelete: { _ in },
                onTogglePin: { _ in },
                onRefreshSummary: { _ in },
                onExportToDraft: { _ in }
            ),
            toolbarHandlers: .init(
                onSmartRecap: {},
                onExportToDraft: {},
                onVoiceInput: {},
                onToolbarAction: { _ in },
                onWebSearch: {},
                onLinkContext: {},
                onToggleOffline: {},
                isOffline: { false }
            ),
            manualContextLabels: [],
            headerHandlers: .init(
                onSearch: {},
                onNewChat: {},
                onSettings: {}
            ),
            composerHandlers: .init(
                onSend: {},
                onAttachImage: {},
                onAttachScreenshot: {},
                onAttachDocument: {},
                onClearImage: {},
                onClearDocument: {},
                onStop: {},
                onRetry: {},
                onResendLastAssistant: nil,
                onDetachContext: {}
            ),
            isRecording: $isRecording,
            voiceInputText: $voiceText,
            isInputFocused: $isFocused
        )
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.9))
        .modelContainer(for: [AIMessage.self, AIConversation.self])
        .environmentObject(GlassColorSystem())
    }
}
