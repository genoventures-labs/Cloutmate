//
//  SidebarCollapseButton.swift
//  FocusOS
//
//  Sidebar V2: Collapse/Expand Toggle Button
//

import SwiftUI

struct SidebarCollapseButton: View {
    @Binding var isCollapsed: Bool
    let onToggle: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    
    private var glowColor: Color {
        AuroraPalette.gradientColors(for: colorScheme).first ?? .clear
    }
    
    var body: some View {
        Button(action: {
            withAnimation(
                reduceMotion 
                    ? nil 
                    : .easeInOut(duration: 0.25)
            ) {
                isCollapsed.toggle()
                onToggle()
            }
        }) {
            ZStack {
                Circle()
                    .fill(glassColorSystem.backgroundSecondary().opacity(0.28))
                    .overlay(
                        AuroraPalette.linearGradient(for: colorScheme)
                            .opacity(isHovered ? 0.35 : 0.18)
                    )
                    .shadow(color: glowColor.opacity(0.22), radius: isHovered ? 8 : 4, y: 3)
                
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(glassColorSystem.textPrimary().opacity(0.9))
            }
            .frame(width: 30, height: 30)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel(isCollapsed ? "Expand sidebar" : "Collapse sidebar")
        .accessibilityHint("Double tap to toggle sidebar width")
    }
}

