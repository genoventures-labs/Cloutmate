//
//  MenuBarPopoverView.swift
//  CloutmateMenuBar
//

import SwiftUI
import SwiftData
import CloutmateShared

enum MenuBarTab: Int, CaseIterable {
    case capture = 0
    case tasks = 1
    case artifacts = 2
    case drafts = 3
    case settings = 4
    
    var title: String {
        switch self {
        case .capture: return "Capture"
        case .tasks: return "Tasks"
        case .artifacts: return "Artifacts"
        case .drafts: return "Drafts"
        case .settings: return "Settings"
        }
    }
}

struct MenuBarPopoverView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @State private var selectedTab: MenuBarTab = .capture
    @FocusState private var isComposerFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Gradient Header
            headerSection
            
            // Tab bar with FilterChips
            tabBarSection
            
            Divider()
                .background(glassColorSystem.borderColor())
            
            // Content
            contentSection
        }
        .frame(width: 400, height: 500)
        .background(glassColorSystem.backgroundColor())
        .onAppear {
            // Set up keyboard shortcuts
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.contains(.command) {
                    switch event.keyCode {
                    case 13: // W key - open capture
                        if !event.modifierFlags.contains(.shift) {
                            selectedTab = .capture
                            return nil
                        }
                    case 9: // V key - open artifacts
                        selectedTab = .artifacts
                        return nil
                    case 1: // S key - open settings
                        selectedTab = .settings
                        return nil
                    default:
                        break
                    }
                }
                return event
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("Cloutmate Menu")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 72/255, green: 131/255, blue: 255/255), // kosmicBlue
                            Color(red: 124/255, green: 77/255, blue: 255/255)  // kosmicPurple
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("Quick access to your workspace")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(glassColorSystem.textSecondary())
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(glassColorSystem.cardElevated())
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
    }
    
    private var tabBarSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MenuBarTab.allCases, id: \.self) { tab in
                    FilterChip(
                        title: tab.title,
                        isSelected: selectedTab == tab,
                        action: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedTab = tab
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    @ViewBuilder
    private var contentSection: some View {
        Group {
            switch selectedTab {
            case .capture:
                MenuBarQuickCaptureView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            case .tasks:
                TasksView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            case .artifacts:
                UpcomingPostsView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            case .drafts:
                QuickComposerView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            case .settings:
                MenuBarSettingsView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedTab)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

#Preview {
    MenuBarPopoverView()
        .modelContainer(for: [CloutmateShared.Post.self, CloutmateShared.Artifact.self])
}

