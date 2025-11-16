//
//  Sidebar.swift
//  Cloutmate
//
//  Cosmic Deck UI - Sidebar
//

import SwiftUI

struct Sidebar: View {
    @Binding var selectedTab: TabIdentifier
    var composerViewModel: ComposerViewModel
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @State private var hoveredTab: TabIdentifier?
    @AppStorage("sidebar.captureExpanded") private var captureExpanded = true
    @AppStorage("sidebar.organizeExpanded") private var organizeExpanded = true
    @AppStorage("sidebar.expressExpanded") private var expressExpanded = true
    @AppStorage("sidebar.toolsExpanded") private var toolsExpanded = true
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            ScrollView {
                VStack(spacing: 0) {
                    GlassSidebarButton(
                        tab: .home,
                        isSelected: selectedTab == .home,
                        isHovered: hoveredTab == .home,
                        onSelect: { selectedTab = .home },
                        onHover: { hovered in hoveredTab = hovered ? .home : nil }
                    )
                    .padding(.top, 8)
                    
                    collapsibleSection(
                        label: "CAPTURE",
                        icon: "plus.circle.fill",
                        isExpanded: $captureExpanded,
                        tabs: [.inbox, .notes, .journal]
                    )
                    
                    collapsibleSection(
                        label: "ORGANIZE",
                        icon: "folder.fill",
                        isExpanded: $organizeExpanded,
                        tabs: [.projects, .areas, .tasks, .resources, .archives]
                    )
                    
                    collapsibleSection(
                        label: "EXPRESS",
                        icon: "pencil.line",
                        isExpanded: $expressExpanded,
                        tabs: [.drafts, .calendar]
                    )
                    
                    collapsibleSection(
                        label: "TOOLS",
                        icon: "wand.and.stars.inverse",
                        isExpanded: $toolsExpanded,
                        tabs: [.aiAssistant, .focusMode, .focusGravity, .rituals, .insights, .settings]
                    )
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 20)
            }
            
            UniversalCaptureMenu()
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(sidebarBackground)
        .overlay(sideEdgeHighlight, alignment: .trailing)
    }
    
    // MARK: - Subviews
    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Cloutmate")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(glassColorSystem.glassTint(for: .primary))
                
                Text("Creative control center")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(glassColorSystem.textSecondary())
            }
            
            Spacer()
            
            GlassButton(icon: "plus", style: .iconOnly, role: .accent, tintColor: glassColorSystem.glassTint(for: .accent)) {
                // Pass current tab context in notification
                NotificationCenter.default.post(name: .openContextualCreate, object: selectedTab)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }
    
    private func collapsibleSection(
        label: String,
        icon: String,
        isExpanded: Binding<Bool>,
        tabs: [TabIdentifier]
    ) -> some View {
        let accentColor = glassColorSystem.emotionalAccent()
        return VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.wrappedValue.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(accentColor)
                    
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(accentColor.opacity(0.9))
                        .textCase(.uppercase)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(accentColor.opacity(0.7))
                }
                .padding(.top, 16)
                .padding(.bottom, 4)
                .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)
            
            if isExpanded.wrappedValue {
                sidebarButtons(for: tabs)
            }
        }
    }
    
    @ViewBuilder
    private func sidebarButtons(for tabs: [TabIdentifier]) -> some View {
        VStack(spacing: 2) {
            ForEach(tabs, id: \.self) { tab in
                GlassSidebarButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    isHovered: hoveredTab == tab,
                    onSelect: { selectedTab = tab },
                    onHover: { hovering in hoveredTab = hovering ? tab : nil }
                )
            }
        }
    }
    
    // MARK: - Background layers
    private var sidebarBackground: some View {
        glassColorSystem.backgroundElevated()
        .ignoresSafeArea()
    }
    
    private var sideEdgeHighlight: some View {
        glassColorSystem.dividerColor()
            .frame(width: 1)
            .ignoresSafeArea()
    }
}

struct GlassSidebarButton: View {
    let tab: TabIdentifier
    let isSelected: Bool
    let isHovered: Bool
    let onSelect: () -> Void
    let onHover: (Bool) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: tab.icon)
                    .font(.system(size: 17, weight: .regular))
                    .frame(width: 22, height: 22)
                
                Text(tab.rawValue)
                    .font(.system(size: 14, weight: isSelected ? .medium : .regular))
            }
            .foregroundStyle(isSelected ? glassColorSystem.textPrimary() : glassColorSystem.textSecondary())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(backgroundHighlight)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            onHover(hovering)
        }
    }
    
    private var backgroundHighlight: some View {
        Group {
            if isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(glassColorSystem.glassTint(for: .primary).opacity(0.12))
            } else if isHovered {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(glassColorSystem.backgroundSecondary().opacity(0.3))
            } else {
                Color.clear
            }
        }
    }
}

#Preview {
    Sidebar(selectedTab: .constant(.home), composerViewModel: ComposerViewModel())
        .frame(width: 280)
        .environmentObject(GlassColorSystem())
}
