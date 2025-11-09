//
//  MainWindowView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import AppKit
import CloutmateShared

enum TabIdentifier: String, CaseIterable, Comparable {
    // Core workflow
    case home = "Home"
    
    // CAPTURE
    case inbox = "Inbox"
    case notes = "Notes"
    case journal = "Journal"
    
    // ORGANIZE (PARA)
    case projects = "Projects"
    case tasks = "Tasks"
    case areas = "Areas"
    case resources = "Resources"
    case archives = "Archives"
    
    // EXPRESS
    case drafts = "Drafts"
    case calendar = "Calendar"
    case posts = "Artifacts"
    
    // TOOLS
    case aiAssistant = "AI Assistant"
    case focusMode = "Focus Mode"
    case focusGravity = "Focus Gravity"
    case rituals = "Rituals"
    case insights = "Insights"
    case settings = "Settings"
    
    static func < (lhs: TabIdentifier, rhs: TabIdentifier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .inbox: return "tray.fill"
        case .notes: return "note.text"
        case .journal: return "book.fill"
        case .projects: return "folder.fill"
        case .tasks: return "checkmark.circle.fill"
        case .areas: return "rectangle.stack.fill"
        case .resources: return "books.vertical.fill"
        case .archives: return "archivebox.fill"
        case .drafts: return "doc.text.fill"
        case .calendar: return "calendar"
        case .posts: return "sparkles"
        case .aiAssistant: return "sparkles"
        case .focusMode: return "timer"
        case .focusGravity: return "gauge.with.dots.needle.67percent"
        case .rituals: return "moon.stars.fill"
        case .insights: return "chart.line.uptrend.xyaxis"
        case .settings: return "gearshape.fill"
        }
    }
}

struct MainWindowView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTab: TabIdentifier = .home
    @State private var composerViewModel = ComposerViewModel()
    @State private var previousTab: TabIdentifier = .home
    @State private var isTransitioning = false
    @State private var showCommandPalette = false
    @State private var sidebarWidth: CGFloat = 260
    @AppStorage("sidebar.v2.collapsed") private var sidebarCollapsed = false
    @State private var pendingTab: TabIdentifier?
    @State private var pendingDecision: InterceptDecision?
    @State private var guardMessage: String = ""
    @State private var showingReflectionPanel: Bool = false
    @State private var showContextualCreateSheet = false
    @State private var contextualCreateTab: TabIdentifier = .home
    
    // Child sheet states
    @State private var showCreateNote = false
    @State private var showCreateTask = false
    @State private var showCreateProject = false
    @State private var showQuickCapture = false
    @State private var showInboxCapture = false
    @State private var showVoiceMemo = false
    @State private var showArtifactComposer = false
    @State private var showResourceImport = false
    @State private var createNoteSheetNote: Note?
    
    var body: some View {
        mainContent
            .modifier(SheetModifiers(
                composerViewModel: $composerViewModel,
                selectedTab: selectedTab,
                showContextualCreateSheet: $showContextualCreateSheet,
                contextualCreateTab: $contextualCreateTab,
                showCreateNote: $showCreateNote,
                createNoteSheetNote: $createNoteSheetNote,
                showCreateTask: $showCreateTask,
                showCreateProject: $showCreateProject,
                showQuickCapture: $showQuickCapture,
                showInboxCapture: $showInboxCapture,
                showVoiceMemo: $showVoiceMemo,
                showArtifactComposer: $showArtifactComposer,
                showResourceImport: $showResourceImport,
                showCommandPalette: $showCommandPalette,
                selectedTabBinding: $selectedTab,
                showingReflectionPanel: $showingReflectionPanel,
                modelContext: modelContext
            ))
            .onReceive(NotificationCenter.default.publisher(for: .switchTab)) { notification in
                if let tab = notification.object as? TabIdentifier {
                    attemptTabSwitch(to: tab)
                }
            }
            .task {
                ContextSwitchGuard.shared.start(modelContext: modelContext)
                NotificationCenter.default.post(name: NSNotification.Name("CurrentTabUpdated"), object: selectedTab)
                
                // Keyboard shortcuts
                setupKeyboardShortcuts()
            }
            .onChange(of: selectedTab) { _, _ in
                FlowTriggersService.shared.updateActivity()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserActivity"))) { _ in
                FlowTriggersService.shared.updateActivity()
            }
            .onChange(of: FlowCompanionEngine.shared.shouldShowPanel) { _, shouldShow in
                showingReflectionPanel = shouldShow
            }
            .overlay(guardOverlay, alignment: .center)
            .overlay(alignment: .bottomTrailing) {
                ReflectionBubbleView()
                    .padding(20)
            }
    }
    
    private var mainContent: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Sidebar V2
                SidebarNavigationViewV2(
                    selectedTab: Binding(
                        get: { selectedTab },
                        set: { attemptTabSwitch(to: $0) }
                    )
                )
                    .frame(width: sidebarCollapsed ? 72 : 260)
                    .onChange(of: sidebarCollapsed) { _, _ in
                        // Sync sidebar width when collapse state changes
                        sidebarWidth = sidebarCollapsed ? 72 : 260
                    }
                
                // Resizer (only show when not collapsed)
                if !sidebarCollapsed {
                    SidebarResizer(sidebarWidth: $sidebarWidth)
                        .onChange(of: sidebarWidth) { _, newWidth in
                            // Sync with collapse state
                            if newWidth < 100 {
                                sidebarCollapsed = true
                            } else {
                                sidebarCollapsed = false
                            }
                        }
                }
                
                // Detail view
                contentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        Rectangle()
                            .fill(.clear)
                            .ignoresSafeArea()
                    )
                    .id(selectedTab)
            }
        }
        .onChange(of: sidebarCollapsed) { _, collapsed in
            // Update sidebar width based on collapse state
            sidebarWidth = collapsed ? 72 : 260
        }
        .onAppear {
            // Sync initial sidebar width with collapse state
            sidebarWidth = sidebarCollapsed ? 72 : 260
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .home:
            DashboardViewV2()
        case .inbox:
            InboxView()
        case .notes:
            UnifiedNotesView()
        case .journal:
            UnifiedJournalView()
        case .projects:
            UnifiedProjectsView()
        case .tasks:
            UnifiedTasksView()
        case .areas:
            UnifiedAreasView()
        case .resources:
            UnifiedResourcesView()
        case .archives:
            ArchivesView()
        case .drafts:
            DraftsView()
        case .calendar:
            CalendarView()
        case .posts:
            ArtifactsViewV2()
        case .aiAssistant:
            if AISettings.shared.isAIEnabled {
                UnifiedAIAssistantView()
            } else {
                ContentUnavailableView(
                    "AI Features Disabled",
                    systemImage: "brain.head.profile",
                    description: Text("Enable AI features in Settings to use the AI Assistant")
                )
            }
        case .focusMode:
            UnifiedFocusModeView()
        case .focusGravity:
            FocusGravityView()
        case .rituals:
            RitualsViewV2()
        case .insights:
            InsightsView()
        case .settings:
            SettingsView()
        }
    }

    private var guardOverlay: some View {
        Group {
            if let decision = pendingDecision,
               let message = guardMessageForCurrentPrompt,
               let delay = delayForDecision(decision) {
                ZStack {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .transition(.opacity)

                    ContextSwitchPrompt(
                        message: message,
                        decision: decision,
                        delay: delay,
                        onConfirm: confirmPendingSwitch,
                        onCancel: cancelPendingSwitch
                    )
                }
                .transition(.opacity)
            }
        }
    }

    private func attemptTabSwitch(to newTab: TabIdentifier) {
        guard selectedTab != newTab else { return }

        let decision = ContextSwitchGuard.shared.shouldInterceptSwitch(
            from: selectedTab,
            to: newTab,
            modelContext: modelContext
        )

        switch decision {
        case .allow:
            completeTabSwitch(to: newTab)
        case .softPrompt(_, let message), .strongPrompt(_, let message):
            pendingTab = newTab
            pendingDecision = decision
            guardMessage = message
        }
    }

    private func completeTabSwitch(to newTab: TabIdentifier) {
        withAnimation(GlassMotion.Easing.tabSwitch) {
            previousTab = selectedTab
            selectedTab = newTab
        }
        pendingTab = nil
        pendingDecision = nil
        guardMessage = ""
        
        // Broadcast tab change for Aurora integration
        NotificationCenter.default.post(name: NSNotification.Name("CurrentTabUpdated"), object: newTab)
    }

    private func confirmPendingSwitch() {
        if let tab = pendingTab {
            completeTabSwitch(to: tab)
        } else {
            cancelPendingSwitch()
        }
    }

    private func cancelPendingSwitch() {
        pendingTab = nil
        pendingDecision = nil
        guardMessage = ""
    }

    private var guardMessageForCurrentPrompt: String? {
        guard let decision = pendingDecision else { return nil }
        switch decision {
        case .softPrompt(_, let message), .strongPrompt(_, let message):
            return message
        case .allow:
            return nil
        }
    }

    private func delayForDecision(_ decision: InterceptDecision) -> TimeInterval? {
        switch decision {
        case .softPrompt(let delay, _), .strongPrompt(let delay, _):
            return delay
        case .allow:
            return nil
        }
    }
    
    // MARK: - Keyboard Shortcuts
    
    private func setupKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            let modifiers = event.modifierFlags
            let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
            
            // ⌘K: Global search overlay
            if modifiers.contains(.command) && key == "k" {
                showCommandPalette = true
                return nil
            }
            
            // ⌘1-⌘9: Jump to tabs
            if modifiers.contains(.command) {
                if let number = Int(key), number >= 1 && number <= 9 {
                    let allTabs = TabIdentifier.allCases
                    if number <= allTabs.count {
                        let tab = allTabs[number - 1]
                        attemptTabSwitch(to: tab)
                        return nil
                    }
                }
            }
            
            // ⌘⇧←/→: Cycle through navigation groups
            if modifiers.contains(.command) && modifiers.contains(.shift) {
                if key == "←" || event.keyCode == 123 { // Left arrow
                    cycleToPreviousGroup()
                    return nil
                } else if key == "→" || event.keyCode == 124 { // Right arrow
                    cycleToNextGroup()
                    return nil
                }
            }
            
            return event
        }
    }
    
    private func cycleToPreviousGroup() {
        let allTabs = TabIdentifier.allCases
        guard let currentIndex = allTabs.firstIndex(of: selectedTab) else { return }
        let previousIndex = currentIndex > 0 ? currentIndex - 1 : allTabs.count - 1
        attemptTabSwitch(to: allTabs[previousIndex])
    }
    
    private func cycleToNextGroup() {
        let allTabs = TabIdentifier.allCases
        guard let currentIndex = allTabs.firstIndex(of: selectedTab) else { return }
        let nextIndex = (currentIndex + 1) % allTabs.count
        attemptTabSwitch(to: allTabs[nextIndex])
    }
}

// MARK: - Sheet Modifiers
struct SheetModifiers: ViewModifier {
    @Binding var composerViewModel: ComposerViewModel
    let selectedTab: TabIdentifier
    @Binding var showContextualCreateSheet: Bool
    @Binding var contextualCreateTab: TabIdentifier
    @Binding var showCreateNote: Bool
    @Binding var createNoteSheetNote: Note?
    @Binding var showCreateTask: Bool
    @Binding var showCreateProject: Bool
    @Binding var showQuickCapture: Bool
    @Binding var showInboxCapture: Bool
    @Binding var showVoiceMemo: Bool
    @Binding var showArtifactComposer: Bool
    @Binding var showResourceImport: Bool
    @Binding var showCommandPalette: Bool
    @Binding var selectedTabBinding: TabIdentifier
    @Binding var showingReflectionPanel: Bool
    let modelContext: ModelContext
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $composerViewModel.isPresented) {
                if selectedTab == .posts {
                    ArtifactComposerView()
                } else {
                    ComposerWindow()
                }
            }
            .sheet(isPresented: $showContextualCreateSheet) {
                ContextualCreateSheet(currentTab: contextualCreateTab)
            }
            .sheet(isPresented: $showCreateNote) {
                if let note = createNoteSheetNote {
                    NavigationStack {
                        NoteDetailDrawer(
                            note: note,
                            isPresented: $showCreateNote
                        )
                    }
                }
            }
            .onChange(of: showCreateNote) { _, isShowing in
                if isShowing && createNoteSheetNote == nil {
                    let newNote = Note(title: "", markdown: "")
                    newNote.author = .user
                    modelContext.insert(newNote)
                    createNoteSheetNote = newNote
                } else if !isShowing {
                    createNoteSheetNote = nil
                }
            }
            .sheet(isPresented: $showCreateTask) {
                CreateTaskSheet()
            }
            .sheet(isPresented: $showCreateProject) {
                CreateProjectSheet()
            }
            .sheet(isPresented: $showQuickCapture) {
                QuickCaptureView()
            }
            .sheet(isPresented: $showInboxCapture) {
                QuickCaptureSheet()
            }
            .sheet(isPresented: $showVoiceMemo) {
                VoiceMemoSheet()
            }
            .sheet(isPresented: $showArtifactComposer) {
                ArtifactComposerView()
            }
            .sheet(isPresented: $showResourceImport) {
                ResourceImportSheet()
            }
            .overlay {
                if showCommandPalette {
                    CommandPaletteView(isPresented: $showCommandPalette)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openComposer)) { notification in
                if selectedTab == .posts {
                    showArtifactComposer = true
                } else {
                    contextualCreateTab = selectedTab
                    showContextualCreateSheet = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openContextualCreate)) { notification in
                if let tab = notification.object as? TabIdentifier {
                    contextualCreateTab = tab
                    showContextualCreateSheet = true
                } else {
                    contextualCreateTab = selectedTab
                    showContextualCreateSheet = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .showCreateNote)) { _ in
                showCreateNote = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .showCreateTask)) { _ in
                showCreateTask = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .showCreateProject)) { _ in
                showCreateProject = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .showQuickCapture)) { _ in
                showQuickCapture = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .openInboxCapture)) { _ in
                showInboxCapture = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .showVoiceMemo)) { _ in
                showVoiceMemo = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .showArtifactComposer)) { _ in
                showArtifactComposer = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenCommandPalette"))) { _ in
                showCommandPalette = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .showResourceImport)) { _ in
                showResourceImport = true
            }
    }
}

// MARK: - Sidebar Resizer
struct SidebarResizer: View {
    @Binding var sidebarWidth: CGFloat
    @State private var isHovering = false
    @State private var startWidth: CGFloat = 0
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        Rectangle()
            .fill(isHovering ? glassColorSystem.glassTint(for: .primary).opacity(0.3) : Color.clear)
            .frame(width: 8)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if startWidth == 0 {
                            startWidth = sidebarWidth
                        }
                        let newWidth = startWidth + value.translation.width
                        sidebarWidth = min(max(newWidth, 200), 400)
                    }
                    .onEnded { _ in
                        startWidth = 0
                    }
            )
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

#Preview {
    MainWindowView()
        .modelContainer(for: [CloutmateShared.Post.self, Draft.self, CloutmateShared.Template.self, AIMessage.self, AIConversation.self])
}

