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
    let hasNotification: Bool
    let onSelect: () -> Void
    let onHover: (Bool) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Focus Mode pulsing accent bar
                if tab == .focusMode && isFocusModeActive {
                    focusModeAccentBar
                }
                
                // Icon
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: .thin))
                    .frame(width: 20, height: 20)
                    .foregroundStyle(iconColor)
                
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(backgroundHighlight)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
    
    private var isCollapsed: Bool {
        // This will be passed from parent, for now assume false
        false
    }
    
    private var iconColor: Color {
        if isSelected {
            return glassColorSystem.glassTint(for: .primary)
        }
        return glassColorSystem.textSecondary()
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
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(glassColorSystem.glassTint(for: .primary).opacity(0.12))
        } else if isHovered {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(glassColorSystem.backgroundSecondary().opacity(0.3))
        } else {
            Color.clear
        }
    }
    
    @ViewBuilder
    private var activeIndicator: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            glassColorSystem.glassTint(for: .primary),
                            glassColorSystem.glassTint(for: .primary).opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        }
    }
    
    @ViewBuilder
    private var focusModeAccentBar: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.kosmicBlue)
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
        hasNotification: Bool = false,
        onSelect: @escaping () -> Void,
        onHover: @escaping (Bool) -> Void
    ) {
        self.tab = tab
        self.isSelected = isSelected
        self.isHovered = isHovered
        self.isFocusModeActive = isFocusModeActive
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

