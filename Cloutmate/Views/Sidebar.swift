//
//  Sidebar.swift
//  Cloutmate
//
//  Glassmorphic Harmony UI - Sidebar Redesign
//

import SwiftUI

struct Sidebar: View {
    @Binding var selectedTab: TabIdentifier
    var composerViewModel: ComposerViewModel
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @State private var hoveredTab: TabIdentifier?
    
    var body: some View {
        VStack(spacing: 0) {
            // App Title with Auroral Gradient
            HStack {
                Text("Cloutmate")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(glassColorSystem.auroralGradient())
                    .auroralPulse()
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
                .overlay(Color.white.opacity(0.2))
            
            // Tab Navigation with Collapsible Sections
            ScrollView {
                VStack(spacing: 4) {
                    // Home (always visible, non-collapsible)
                    GlassSidebarButton(
                        tab: .home,
                        isSelected: selectedTab == .home,
                        isHovered: hoveredTab == .home,
                        onSelect: { selectedTab = .home },
                        onHover: { hovering in hoveredTab = hovering ? .home : nil }
                    )
                    .padding(.horizontal, 12)
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    // CAPTURE section
                    CollapsibleSidebarSection(
                        title: "CAPTURE",
                        icon: "plus.circle.fill",
                        tabs: [.inbox, .notes, .journal],
                        selectedTab: $selectedTab,
                        isExpanded: true
                    )
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    // ORGANIZE (PARA) section
                    CollapsibleSidebarSection(
                        title: "ORGANIZE",
                        icon: "folder.fill",
                        tabs: [.projects, .areas, .tasks, .resources, .archives],
                        selectedTab: $selectedTab,
                        isExpanded: true
                    )
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    // EXPRESS section
                    CollapsibleSidebarSection(
                        title: "EXPRESS",
                        icon: "pencil.line",
                        tabs: [.drafts, .calendar, .posts],
                        selectedTab: $selectedTab,
                        isExpanded: true
                    )
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    // TOOLS section
                    CollapsibleSidebarSection(
                        title: "TOOLS",
                        icon: "wrench.and.screwdriver.fill",
                        tabs: [.aiAssistant, .insights, .settings],
                        selectedTab: $selectedTab,
                        isExpanded: selectedTab == .aiAssistant || selectedTab == .insights || selectedTab == .settings
                    )
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
            }
            
            Spacer()
            
            Divider()
                .overlay(Color.white.opacity(0.2))
            
            // Universal New Menu
            VStack(spacing: 0) {
                UniversalCaptureMenu()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        }
        .background(.regularMaterial)
        .overlay(alignment: .trailing) {
            Color.white.opacity(0.15)
                .frame(width: 1)
        }
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
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 24, height: 24)
                
                Text(tab.rawValue)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .blue : Color(NSColor.labelColor))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassPanel(
                tier: isSelected ? .overlay : .sidebar,
                cornerRadius: 12,
                tintColor: isSelected ? glassColorSystem.glassTint(for: .primary).opacity(0.3) : nil
            )
            .overlay(
                // Active tab gradient pulse
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                glassColorSystem.borderGlow(for: .primary),
                                lineWidth: 2
                            )
                            .auroralPulse()
                    }
                }
            )
            .shadow(
                color: isSelected ? .blue.opacity(0.2) : .clear,
                radius: 8
            )
        }
        .buttonStyle(.plain)
        .glassHoverEffect()
        .onHover { hovering in
            onHover(hovering)
        }
    }
}

#Preview {
    Sidebar(selectedTab: .constant(.home), composerViewModel: ComposerViewModel())
}

