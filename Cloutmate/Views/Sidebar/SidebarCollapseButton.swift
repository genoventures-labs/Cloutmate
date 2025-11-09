//
//  SidebarCollapseButton.swift
//  Cloutmate
//
//  Sidebar V2: Collapse/Expand Toggle Button
//

import SwiftUI

struct SidebarCollapseButton: View {
    @Binding var isCollapsed: Bool
    let onToggle: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
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
            Image(systemName: isCollapsed ? "chevron.right" : "chevron.left")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(glassColorSystem.textSecondary())
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCollapsed ? "Expand sidebar" : "Collapse sidebar")
        .accessibilityHint("Double tap to toggle sidebar width")
    }
}

