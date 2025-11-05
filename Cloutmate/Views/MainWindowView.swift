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
    case posts = "Posts"
    
    // TOOLS
    case aiAssistant = "AI Assistant"
    case focusMode = "Focus Mode"
    case focusGravity = "Focus Gravity"
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
        case .posts: return "square.and.pencil"
        case .aiAssistant: return "sparkles"
        case .focusMode: return "timer"
        case .focusGravity: return "gauge.with.dots.needle.67percent"
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
    @State private var sidebarWidth: CGFloat = 240
    @State private var pendingTab: TabIdentifier?
    @State private var pendingDecision: InterceptDecision?
    @State private var guardMessage: String = ""
    @State private var showContextualCreateSheet = false
    @State private var contextualCreateTab: TabIdentifier = .home
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Sidebar
                Sidebar(
                    selectedTab: Binding(
                        get: { selectedTab },
                        set: { attemptTabSwitch(to: $0) }
                    ),
                    composerViewModel: composerViewModel
                )
                    .frame(width: sidebarWidth)
                
                // Resizer
                SidebarResizer(sidebarWidth: $sidebarWidth)
                
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
        .sheet(isPresented: $composerViewModel.isPresented) {
            ComposerWindow()
        }
        .sheet(isPresented: $showContextualCreateSheet) {
            ContextualCreateSheet(currentTab: contextualCreateTab)
        }
        .overlay {
            if showCommandPalette {
                CommandPaletteView(isPresented: $showCommandPalette)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openComposer)) { notification in
            // Check if we're in Posts view - if so, open ComposerWindow directly
            if selectedTab == .posts {
                composerViewModel.present()
            } else {
                // Otherwise open contextual create sheet
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
        .onReceive(NotificationCenter.default.publisher(for: .switchTab)) { notification in
            if let tab = notification.object as? TabIdentifier {
                attemptTabSwitch(to: tab)
            }
        }
        .task {
            ContextSwitchGuard.shared.start(modelContext: modelContext)
            // Broadcast initial tab
            NotificationCenter.default.post(name: NSNotification.Name("CurrentTabUpdated"), object: selectedTab)
            
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "k" {
                    showCommandPalette = true
                    return nil
                }
                return event
            }
        }
        .overlay(guardOverlay, alignment: .center)
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .home:
            CustomizableDashboardView()
        case .inbox:
            InboxView()
        case .notes:
            NotesView()
        case .journal:
            JournalView()
        case .projects:
            ProjectsView()
        case .tasks:
            TasksView()
        case .areas:
            AreasView()
        case .resources:
            ResourcesView()
        case .archives:
            ArchivesView()
        case .drafts:
            DraftsView()
        case .calendar:
            CalendarView()
        case .posts:
            ListTableView()
        case .aiAssistant:
            if AISettings.shared.isAIEnabled {
                AIAssistantView()
            } else {
                ContentUnavailableView(
                    "AI Features Disabled",
                    systemImage: "brain.head.profile",
                    description: Text("Enable AI features in Settings to use the AI Assistant")
                )
            }
        case .focusMode:
            FocusModeView()
        case .focusGravity:
            FocusGravityView()
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

