//
//  GlassButton.swift
//  Cloutmate
//
//  Minimal Apple Music-inspired Button Component
//

import SwiftUI

struct GlassButton: View {
    let title: String?
    let icon: String?
    let action: () -> Void
    
    var style: ButtonStyle = .standard
    var role: GlassColorSystem.GlassRole = .primary
    var tintColor: Color?
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityGlassManager) private var accessibilityManager
    
    enum ButtonStyle {
        case standard
        case pill
        case iconOnly
    }
    
    init(
        _ title: String? = nil,
        icon: String? = nil,
        style: ButtonStyle = .standard,
        role: GlassColorSystem.GlassRole = .primary,
        tintColor: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.role = role
        self.tintColor = tintColor
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            labelContent
                .frame(minWidth: style == .iconOnly ? iconButtonSize : nil)
                .frame(minHeight: style == .iconOnly ? iconButtonSize : nil)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .background(buttonBackground)
                .clipShape(style == .iconOnly ? AnyShapeWrapper(Circle()) : AnyShapeWrapper(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)))
                .overlay(buttonBorder)
                .scaleEffect(isPressed ? 0.97 : 1.0)
                .opacity(isPressed ? 0.8 : 1.0)
                .shadow(
                    color: shadowColor,
                    radius: shadowRadius,
                    x: 0,
                    y: shadowY
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
    
    // MARK: - Content
    private var labelContent: some View {
        HStack(spacing: icon != nil && title != nil ? 8 : 0) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: iconFontSize, weight: .medium))
            }
            
            if let title = title {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
        }
        .foregroundStyle(textColor)
    }
    
    // MARK: - Styling
    
    @ViewBuilder
    private var buttonBackground: some View {
        let color = tintColor ?? glassColorSystem.buttonColor(for: role)
        let bgColor = isHovered ? color.opacity(0.9) : color
        
            if style == .iconOnly {
                Circle()
                .fill(bgColor)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(bgColor)
            }
        }
    
    @ViewBuilder
    private var buttonBorder: some View {
            if style == .iconOnly {
                Circle()
                .strokeBorder(borderColor, lineWidth: 1)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        }
    }
    
    private var textColor: Color {
        // Primary and accent roles use white text, surface uses adaptive text
        switch role {
        case .primary, .accent, .success, .danger:
            return .white
        case .surface:
            return glassColorSystem.textPrimary()
        }
    }
    
    private var borderColor: Color {
        let color = tintColor ?? glassColorSystem.buttonColor(for: role)
        return color.opacity(0.3)
    }
    
    // MARK: - Metrics
    private var cornerRadius: CGFloat {
        switch style {
        case .pill: return 20
        case .iconOnly: return iconButtonSize / 2
        case .standard: return 10
        }
    }
    
    private var horizontalPadding: CGFloat {
        switch style {
        case .pill: return 20
        case .standard: return 16
        case .iconOnly: return 0
        }
    }
    
    private var verticalPadding: CGFloat {
        switch style {
        case .pill: return 10
        case .standard: return 8
        case .iconOnly: return 0
        }
    }
    
    private var iconButtonSize: CGFloat { 40 }
    private var iconFontSize: CGFloat { style == .iconOnly ? 16 : 14 }

    private var shadowColor: Color {
        Color.black.opacity(isHovered ? 0.15 : 0.10)
    }
    
    private var shadowRadius: CGFloat {
        isHovered ? 6 : 4
    }
    
    private var shadowY: CGFloat {
        isHovered ? 3 : 2
    }
}

#Preview {
    VStack(spacing: 20) {
        GlassButton("Primary Action", icon: "sparkles", style: .standard, role: .primary) {}
        GlassButton("Install", icon: "arrow.down.circle", style: .pill, role: .accent) {}
        GlassButton(icon: "play.fill", style: .iconOnly, role: .primary) {}
    }
    .padding()
    .environmentObject(GlassColorSystem())
}

// MARK: - Type-erased Shape Wrapper
struct AnyShapeWrapper: Shape {
    private let _path: (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        _path = shape.path(in:)
    }
    
    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}
