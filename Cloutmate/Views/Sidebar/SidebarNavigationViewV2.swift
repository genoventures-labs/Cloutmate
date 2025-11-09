//
//  SidebarNavigationViewV2.swift
//  Cloutmate
//
//  Sidebar V2: ARTE-adaptive navigation sidebar with tone-aware gradients
//

import SwiftUI
import SwiftData

struct SidebarNavigationViewV2: View {
    @Binding var selectedTab: TabIdentifier
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    
    @AppStorage("sidebar.v2.collapsed") private var isCollapsed = false
    @AppStorage("selectedRoute") private var persistedRoute: String = "Home"
    
    @State private var hoveredTab: TabIdentifier?
    @State private var isFocusModeActive = false
    
    // Navigation groups
    private let primaryNav: [TabIdentifier] = [.home, .tasks, .projects, .calendar, .insights]
    private let personalNav: [TabIdentifier] = [.journal, .rituals, .posts, .areas]
    private let systemNav: [TabIdentifier] = [.focusMode, .archives, .aiAssistant, .settings]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Zone
            headerZone
            
            // Navigation Content
            ScrollView {
                VStack(spacing: 0) {
                    // Primary Navigation
                    sectionHeader(title: "Primary", isCollapsed: isCollapsed)
                        .padding(.top, 16)
                    
                    navigationGroup(
                        items: primaryNav,
                        spacing: 4
                    )
                    .padding(.top, 8)
                    
                    // Divider
                    divider
                        .padding(.vertical, 16)
                    
                    // Personal Navigation
                    sectionHeader(title: "Personal", isCollapsed: isCollapsed)
                    
                    navigationGroup(
                        items: personalNav,
                        spacing: 4,
                        indent: 8
                    )
                    .padding(.top, 8)
                    
                    // Divider
                    divider
                        .padding(.vertical, 16)
                    
                    // System Navigation (bottom-anchored)
                    Spacer()
                        .frame(minHeight: 20)
                    
                    sectionHeader(title: "System", isCollapsed: isCollapsed)
                    
                    navigationGroup(
                        items: systemNav,
                        spacing: 4
                    )
                    .padding(.top, 8)
                }
                .padding(.horizontal, isCollapsed ? 8 : 12)
                .padding(.bottom, 20)
            }
            
            // Collapse Control
            collapseControl
                .padding(.bottom, 12)
        }
        .frame(width: isCollapsed ? 72 : 260)
        .glassPanel(tier: .sidebar, cornerRadius: 16, showInnerStroke: false)
        .overlay(
            // ARTE tone gradient overlay
            SidebarToneSyncService.shared.currentGradient
                .opacity(SidebarToneSyncService.shared.gradientOpacity * 0.15)
                .ignoresSafeArea()
        )
        .clipShape(
            .rect(
                topLeadingRadius: 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 16,
                topTrailingRadius: 16
            )
        )
        .overlay(sideEdgeHighlight, alignment: .trailing)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.25),
            value: isCollapsed
        )
        .task {
            // Restore persisted route
            restorePersistedRoute()
            
            // Check focus mode status
            checkFocusModeStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusSessionStatusChanged)) { _ in
            checkFocusModeStatus()
        }
        .onChange(of: selectedTab) { _, newTab in
            // Persist route
            persistedRoute = newTab.rawValue
        }
        .onAppear {
            // Check focus mode status on appear
            checkFocusModeStatus()
        }
    }
    
    // MARK: - Header Zone
    
    private var headerZone: some View {
        HStack(spacing: isCollapsed ? 0 : 12) {
            if !isCollapsed {
                // App Orb
                appOrb
                
                // Cloutmate Label
                Text("Cloutmate")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
            } else {
                // Compact: Just orb centered
                appOrb
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .padding(.horizontal, isCollapsed ? 0 : 20)
    }
    
    private var appOrb: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.kosmicBlue,
                        Color.kosmicPurple
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: isCollapsed ? 32 : 40, height: isCollapsed ? 32 : 40)
            .shadow(color: Color.kosmicBlue.opacity(0.3), radius: 8)
            .overlay(
                Circle()
                    .strokeBorder(
                        Color.white.opacity(0.2),
                        lineWidth: 1
                    )
            )
    }
    
    // MARK: - Navigation Groups
    
    @ViewBuilder
    private func navigationGroup(
        items: [TabIdentifier],
        spacing: CGFloat,
        indent: CGFloat = 0
    ) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(items, id: \.self) { tab in
                SidebarNavItem(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    isHovered: hoveredTab == tab,
                    isFocusModeActive: tab == .focusMode && isFocusModeActive,
                    hasNotification: hasNotification(for: tab),
                    onSelect: {
                        selectedTab = tab
                    },
                    onHover: { hovering in
                        hoveredTab = hovering ? tab : nil
                    }
                )
                .padding(.leading, indent)
                .opacity(isCollapsed && tab != selectedTab ? 0 : 1)
            }
        }
    }
    
    // MARK: - Dividers
    
    @ViewBuilder
    private func sectionHeader(title: String, isCollapsed: Bool) -> some View {
        if !isCollapsed {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(glassColorSystem.textSecondary().opacity(0.7))
                .tracking(0.5)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
        }
    }
    
    private var divider: some View {
        Rectangle()
            .fill(Color.kosmicPurple.opacity(0.12))
            .frame(height: 1)
            .padding(.horizontal, isCollapsed ? 8 : 12)
    }
    
    // MARK: - Collapse Control
    
    private var collapseControl: some View {
        HStack {
            if !isCollapsed {
                Spacer()
            }
            SidebarCollapseButton(isCollapsed: $isCollapsed) {
                // Additional actions on toggle if needed
            }
            if !isCollapsed {
                Spacer()
            }
        }
        .padding(.horizontal, isCollapsed ? 0 : 12)
    }
    
    // MARK: - Background
    
    private var sideEdgeHighlight: some View {
        glassColorSystem.dividerColor()
            .frame(width: 1)
            .ignoresSafeArea()
    }
    
    // MARK: - Helpers
    
    private func hasNotification(for tab: TabIdentifier) -> Bool {
        // TODO: Implement notification detection logic
        // For now, return false
        return false
    }
    
    private func restorePersistedRoute() {
        if let tab = TabIdentifier.allCases.first(where: { $0.rawValue == persistedRoute }) {
            selectedTab = tab
        }
    }
    
    private func checkFocusModeStatus() {
        isFocusModeActive = FocusSessionService.shared.getActiveSession(modelContext: modelContext) != nil
    }
}

// MARK: - Keyboard Shortcuts Extension

extension SidebarNavigationViewV2 {
    /// Handle keyboard shortcuts for navigation
    func handleKeyboardShortcut(_ key: String, modifiers: NSEvent.ModifierFlags) -> Bool {
        // ⌘1-⌘9: Jump to tabs
        if modifiers.contains(.command) {
            if let number = Int(key), number >= 1 && number <= 9 {
                let allTabs = primaryNav + personalNav + systemNav
                if number <= allTabs.count {
                    selectedTab = allTabs[number - 1]
                    return true
                }
            }
        }
        
        // ⌘⇧←/→: Cycle through groups
        if modifiers.contains(.command) && modifiers.contains(.shift) {
            if key == "←" {
                cycleToPreviousGroup()
                return true
            } else if key == "→" {
                cycleToNextGroup()
                return true
            }
        }
        
        return false
    }
    
    private func cycleToPreviousGroup() {
        let allTabs = primaryNav + personalNav + systemNav
        guard let currentIndex = allTabs.firstIndex(of: selectedTab) else { return }
        let previousIndex = currentIndex > 0 ? currentIndex - 1 : allTabs.count - 1
        selectedTab = allTabs[previousIndex]
    }
    
    private func cycleToNextGroup() {
        let allTabs = primaryNav + personalNav + systemNav
        guard let currentIndex = allTabs.firstIndex(of: selectedTab) else { return }
        let nextIndex = (currentIndex + 1) % allTabs.count
        selectedTab = allTabs[nextIndex]
    }
}

#Preview {
    SidebarNavigationViewV2(selectedTab: .constant(.home))
        .environmentObject(GlassColorSystem())
        .frame(width: 260, height: 800)
}

