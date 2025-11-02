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
    @State private var selectedTab: TabIdentifier = .home
    @State private var composerViewModel = ComposerViewModel()
    @State private var previousTab: TabIdentifier = .home
    @State private var isTransitioning = false
    @State private var showCommandPalette = false
    @State private var sidebarWidth: CGFloat = 240
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Sidebar
                Sidebar(selectedTab: $selectedTab, composerViewModel: composerViewModel)
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
        .overlay {
            if showCommandPalette {
                CommandPaletteView(isPresented: $showCommandPalette)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openComposer)) { _ in
            composerViewModel.present()
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchTab)) { notification in
            if let tab = notification.object as? TabIdentifier {
                withAnimation(GlassMotion.Easing.tabSwitch) {
                    previousTab = selectedTab
                    selectedTab = tab
                }
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            previousTab = oldValue
        }
        .task {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "k" {
                    showCommandPalette = true
                    return nil
                }
                return event
            }
        }
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

