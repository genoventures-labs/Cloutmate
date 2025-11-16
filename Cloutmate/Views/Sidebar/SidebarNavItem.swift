//
//  SidebarNavItem.swift
//  Cloutmate
//
//  Sidebar V2: Individual Navigation Item Component
//

import SwiftUI

struct SidebarNavItem: View {
    let tab: TabIdentifier
    let isSelected: Bool
    let isHovered: Bool
    let isFocusModeActive: Bool
    let isCollapsed: Bool
    let hasNotification: Bool
    let onSelect: () -> Void
    let onHover: (Bool) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: isCollapsed ? 0 : 12) {
                // Focus Mode pulsing accent bar
                if tab == .focusMode && isFocusModeActive {
                    focusModeAccentBar
                }
                
                // Icon
                iconBadge
                
                // Label (hidden when collapsed)
                if !isCollapsed {
                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(textColor)
                    
                    Spacer()
                    
                    // Notification dot
                    if hasNotification {
                        notificationDot
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
            .padding(.horizontal, isCollapsed ? 6 : 12)
            .padding(.vertical, isCollapsed ? 12 : 10)
            .background(backgroundHighlight)
            .clipShape(RoundedRectangle(cornerRadius: isCollapsed ? 14 : 12, style: .continuous))
            .overlay(activeIndicator)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .modifier(HoverModifier(
            isHovered: isHovered,
            reduceMotion: reduceMotion,
            onHover: onHover
        ))
    }
    
    // MARK: - Computed Properties
    
    private var iconSize: CGFloat { isCollapsed ? 20 : 18 }
    
    @ViewBuilder
    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: isCollapsed ? 12 : 10, style: .continuous)
                .fill(iconBackground)
                .frame(width: isCollapsed ? 32 : 28, height: isCollapsed ? 32 : 28)
                .overlay(
                    RoundedRectangle(cornerRadius: isCollapsed ? 12 : 10, style: .continuous)
                        .stroke(iconBorder, lineWidth: isSelected ? 1 : 0.8)
                )
                .shadow(color: iconGlow.opacity(isSelected ? 0.45 : 0.12), radius: isCollapsed ? 10 : 8, y: 4)
            
            Image(systemName: tab.icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(iconForeground)
        }
        .animation(.easeInOut(duration: 0.18), value: isSelected)
        .animation(.easeInOut(duration: 0.18), value: isHovered)
    }

    private var iconBackground: Color {
        if isSelected {
            return glassColorSystem.glassTint(for: .primary).opacity(0.18)
        }
        if isHovered {
            return glassColorSystem.backgroundSecondary().opacity(0.22)
        }
        return glassColorSystem.backgroundSecondary().opacity(isCollapsed ? 0.16 : 0.12)
    }
    
    private var iconBorder: Color {
        if isSelected {
            return glassColorSystem.glassTint(for: .primary).opacity(0.7)
        }
        if isHovered {
            return glassColorSystem.backgroundSecondary().opacity(0.3)
        }
        return glassColorSystem.backgroundSecondary().opacity(0.18)
    }
    
    private var iconForeground: Color {
        if isSelected {
            return glassColorSystem.textPrimary()
        }
        return glassColorSystem.textSecondary().opacity(0.9)
    }
    
    private var iconGlow: Color {
        glassColorSystem.glassTint(for: .primary)
    }
    
    private var textColor: Color {
        if isSelected {
            return glassColorSystem.textPrimary()
        }
        return glassColorSystem.textSecondary()
    }
    
    @ViewBuilder
    private var backgroundHighlight: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: isCollapsed ? 15 : 13, style: .continuous)
                .fill(
                    AuroraPalette.linearGradient(for: colorScheme)
                        .opacity(isCollapsed ? 0.24 : 0.2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: isCollapsed ? 15 : 13, style: .continuous)
                        .stroke(glassColorSystem.glassTint(for: .primary).opacity(0.46), lineWidth: 1)
                )
                .shadow(color: glassColorSystem.glassTint(for: .primary).opacity(0.24), radius: isCollapsed ? 8 : 11, y: 6)
        } else if isHovered {
            RoundedRectangle(cornerRadius: isCollapsed ? 15 : 13, style: .continuous)
                .fill(glassColorSystem.backgroundSecondary().opacity(isCollapsed ? 0.28 : 0.24))
                .shadow(color: glassColorSystem.backgroundSecondary().opacity(0.14), radius: isCollapsed ? 6 : 8, y: 4)
        } else {
            Color.clear
        }
    }
    
    @ViewBuilder
    private var activeIndicator: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: isCollapsed ? 16 : 14, style: .continuous)
                .stroke(
                        AuroraPalette.linearGradient(for: colorScheme, start: .topLeading, end: .bottomTrailing),
                        lineWidth: 1.1
                )
                .shadow(color: glassColorSystem.glassTint(for: .primary).opacity(0.18), radius: 4, y: 2)
        }
    }
    
    @ViewBuilder
    private var focusModeAccentBar: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(AuroraPalette.linearGradient(for: colorScheme))
            .frame(width: 3)
            .opacity(pulsingOpacity)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                value: pulsingOpacity
            )
    }
    
    @State private var pulsingOpacity: Double = 0.6
    
    @ViewBuilder
    private var notificationDot: some View {
        Circle()
            .fill(Color.kosmicGreen)
            .frame(width: 6, height: 6)
            .shadow(color: Color.kosmicGreen.opacity(0.5), radius: 3)
    }
    
    // MARK: - Accessibility
    
    private var accessibilityLabel: String {
        var label = tab.rawValue
        if isSelected {
            label += ", active"
        }
        if tab == .focusMode && isFocusModeActive {
            label += ", focus mode active"
        }
        if hasNotification {
            label += ", unread"
        }
        return label
    }
    
    private var accessibilityHint: String {
        "Double tap to navigate to \(tab.rawValue)"
    }
    
    // MARK: - Lifecycle
    
    init(
        tab: TabIdentifier,
        isSelected: Bool,
        isHovered: Bool = false,
        isFocusModeActive: Bool = false,
        isCollapsed: Bool,
        hasNotification: Bool = false,
        onSelect: @escaping () -> Void,
        onHover: @escaping (Bool) -> Void
    ) {
        self.tab = tab
        self.isSelected = isSelected
        self.isHovered = isHovered
        self.isFocusModeActive = isFocusModeActive
        self.isCollapsed = isCollapsed
        self.hasNotification = hasNotification
        self.onSelect = onSelect
        self.onHover = onHover
    }
}

// MARK: - Hover Modifier

private struct HoverModifier: ViewModifier {
    let isHovered: Bool
    let reduceMotion: Bool
    let onHover: (Bool) -> Void
    
    func body(content: Content) -> some View {
        if reduceMotion {
            content
                .modifier(NoMotionHoverModifier(onHover: onHover))
        } else {
            content
                .modifier(FloatLiftHoverModifier(onHover: onHover))
        }
    }
}

private struct FloatLiftHoverModifier: ViewModifier {
    @State private var isHovered = false
    let onHover: (Bool) -> Void
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? GlassMotion.Transform.hoverScale : 1.0)
            .shadow(
                color: .black.opacity(isHovered ? 0.15 : 0.05),
                radius: isHovered ? 12 : 4,
                y: isHovered ? 8 : 2
            )
            .animation(.spring(response: 0.15, dampingFraction: 0.7), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
                onHover(hovering)
            }
    }
}

private struct NoMotionHoverModifier: ViewModifier {
    let onHover: (Bool) -> Void
    
    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                onHover(hovering)
            }
    }
}

