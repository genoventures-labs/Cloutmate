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
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollContentHeight: CGFloat = 1
    @State private var viewportHeight: CGFloat = 1
    
    // Navigation groups
    private let primaryNav: [TabIdentifier] = [.home, .tasks, .projects, .calendar, .insights]
    private let personalNav: [TabIdentifier] = [.inbox, .journal, .notes, .rituals, .areas]
    private let systemNav: [TabIdentifier] = [.focusMode, .archives, .aiAssistant, .settings]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Zone
            headerZone
            
            // Navigation Content
            GeometryReader { containerProxy in
                ScrollView(showsIndicators: false) {
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
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .preference(key: SidebarScrollMetricsPreferenceKey.self, value: SidebarScrollMetrics(contentHeight: proxy.size.height, contentOffset: -proxy.frame(in: .named("SidebarScrollSpace")).origin.y))
                        }
                    )
                }
                .onAppear { viewportHeight = max(containerProxy.size.height, 1) }
                .onChange(of: containerProxy.size.height) { _, newValue in
                    viewportHeight = max(newValue, 1)
                }
                .coordinateSpace(name: "SidebarScrollSpace")
                .onPreferenceChange(SidebarScrollMetricsPreferenceKey.self) { metrics in
                    let viewport = max(containerProxy.size.height, 1)
                    DispatchQueue.main.async {
                        viewportHeight = viewport
                        scrollContentHeight = max(metrics.contentHeight, 1)
                        let maxScrollable = max(scrollContentHeight - viewport, 0)
                        let sanitizedOffset = min(max(metrics.contentOffset, 0), maxScrollable)
                        scrollOffset = sanitizedOffset
                    }
                }
                .overlay(scrollbarOverlay.padding(.trailing, isCollapsed ? 2 : 4), alignment: .trailing)
            }
            
            // Collapse Control
            collapseControl
                .padding(.bottom, 12)
        }
        .frame(width: isCollapsed ? 76 : 268)
        .background(sidebarBackground)
        .overlay(
            accentRail
                .frame(width: isCollapsed ? 3 : 4)
                .padding(.top, 12)
                .padding(.bottom, 12),
            alignment: .leading
        )
        .clipShape(
            .rect(
                topLeadingRadius: 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 20,
                topTrailingRadius: 20
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(glassColorSystem.backgroundSecondary().opacity(0.22), lineWidth: 1)
                .blendMode(.screen)
                .padding(.top, 1)
                .padding(.bottom, 1)
                .padding(.trailing, 1)
                .padding(.leading, -1)
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
        ZStack {
            headerBackground
                .padding(.horizontal, isCollapsed ? 12 : 20)
                .padding(.top, 8)
                .padding(.bottom, 12)

            HStack(spacing: isCollapsed ? 0 : 12) {
                appOrb
                
                if !isCollapsed {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cloutmate")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(glassColorSystem.textPrimary())
                        
                        Text("Aurora Workspace OS")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(glassColorSystem.textSecondary().opacity(0.7))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
            .padding(.horizontal, isCollapsed ? 0 : 24)
        }
        .frame(height: isCollapsed ? 72 : 88)
    }
    
    private var headerBackground: some View {
        let cornerRadius: CGFloat = isCollapsed ? 18 : 22
        let tint = glassColorSystem.glassTint(for: .primary)
        
        return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(glassColorSystem.backgroundSecondary().opacity(isCollapsed ? 0.32 : 0.26))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(glassColorSystem.backgroundSecondary().opacity(0.28), lineWidth: 0.8)
            )
            .overlay(
                AuroraPalette.linearGradient(for: colorScheme, start: .topLeading, end: .bottomTrailing)
                    .opacity(isCollapsed ? 0.18 : 0.12)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
            .shadow(color: tint.opacity(0.18), radius: 10, y: 8)
    }
    
    private var appOrb: some View {
        let glowColor = AuroraPalette.gradientColors(for: colorScheme).first ?? Color.kosmicBlue
        
        return ZStack {
            Circle()
                .fill(AuroraPalette.radialGradient(for: colorScheme, startRadius: 4, endRadius: isCollapsed ? 32 : 40))
                .frame(width: isCollapsed ? 36 : 44, height: isCollapsed ? 36 : 44)
                .shadow(color: glowColor.opacity(0.45), radius: 14, y: 6)
            
            Circle()
                .strokeBorder(Color.white.opacity(0.28), lineWidth: 1.2)
                .frame(width: isCollapsed ? 34 : 42, height: isCollapsed ? 34 : 42)
        }
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
                    isCollapsed: isCollapsed,
                    hasNotification: hasNotification(for: tab),
                    onSelect: {
                        selectedTab = tab
                    },
                    onHover: { hovering in
                        hoveredTab = hovering ? tab : nil
                    }
                )
                .padding(.leading, indent)
            }
        }
    }
    
    // MARK: - Dividers
    
    @ViewBuilder
    private func sectionHeader(title: String, isCollapsed: Bool) -> some View {
        if !isCollapsed {
            HStack(spacing: 8) {
                Circle()
                    .fill(glassColorSystem.glassTint(for: .primary))
                    .frame(width: 6, height: 6)
                    .opacity(0.75)
                
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary().opacity(0.78))
                    .tracking(0.8)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(glassColorSystem.backgroundSecondary().opacity(0.22))
            )
            .padding(.horizontal, 6)
        }
    }
    
    private var divider: some View {
        Rectangle()
            .fill(glassColorSystem.dividerColor().opacity(isCollapsed ? 0.35 : 0.28))
            .frame(height: 1)
            .padding(.horizontal, isCollapsed ? 10 : 18)
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
    
    private var sidebarBackground: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(glassColorSystem.backgroundElevated().opacity(isCollapsed ? 0.82 : 0.72))
            
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(glassColorSystem.backgroundSecondary().opacity(0.22), lineWidth: 0.8)
            
            SidebarToneSyncService.shared.currentGradient
                .opacity(SidebarToneSyncService.shared.gradientOpacity * 0.12)
                .blendMode(.plusLighter)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
    
    private var accentRail: some View {
        AuroraPalette.linearGradient(for: colorScheme, start: .top, end: .bottom)
            .opacity(isCollapsed ? 0.7 : 0.5)
    }
    
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

// MARK: - Scrollbar Overlay

private extension SidebarNavigationViewV2 {
    @ViewBuilder
    var scrollbarOverlay: some View {
        let contentExceedsViewport = scrollContentHeight > viewportHeight + 1
        if contentExceedsViewport {
            let trackPaddingTop: CGFloat = 20
            let trackPaddingBottom: CGFloat = 20
            let availableHeight = max(viewportHeight - (trackPaddingTop + trackPaddingBottom), 40)
            let sizeRatio = min(max(viewportHeight / scrollContentHeight, 0.0), 1.0)
            let handleHeight = max(availableHeight * sizeRatio, 42)
            let maxScrollable = max(scrollContentHeight - viewportHeight, 1)
            let progress = min(max(scrollOffset / maxScrollable, 0), 1)
            let handleOffset = (availableHeight - handleHeight) * progress
            
            VStack {
                Spacer().frame(height: trackPaddingTop)
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(glassColorSystem.backgroundSecondary().opacity(0.28))
                        .frame(width: 4, height: availableHeight)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AuroraPalette.linearGradient(for: colorScheme))
                        .frame(width: 4, height: handleHeight)
                        .offset(y: handleOffset)
                        .shadow(color: glassColorSystem.glassTint(for: .primary).opacity(0.35), radius: 4, y: 2)
                }
                Spacer().frame(height: trackPaddingBottom)
            }
            .animation(.easeInOut(duration: 0.2), value: scrollOffset)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Preference Keys

private struct SidebarScrollMetricsPreferenceKey: PreferenceKey {
    static var defaultValue: SidebarScrollMetrics = .init(contentHeight: 1, contentOffset: 0)
    
    static func reduce(value: inout SidebarScrollMetrics, nextValue: () -> SidebarScrollMetrics) {
        let next = nextValue()
        value = SidebarScrollMetrics(
            contentHeight: max(1, next.contentHeight),
            contentOffset: next.contentOffset
        )
    }
}

private struct SidebarScrollMetrics: Equatable {
    var contentHeight: CGFloat
    var contentOffset: CGFloat
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
