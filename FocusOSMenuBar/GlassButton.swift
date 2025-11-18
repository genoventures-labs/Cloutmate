//
//  GlassButton.swift
//  FocusOSMenuBar
//
//  Simplified GlassButton component matching Archives V2 design system
//

import SwiftUI
import FocusOSShared

struct GlassButton: View {
    let title: String?
    let icon: String?
    let action: () -> Void
    
    var style: ButtonStyle = .standard
    var role: GlassColorSystem.GlassRole = .primary
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
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
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.role = role
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: icon != nil && title != nil ? 8 : 0) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
                
                if let title = title {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .foregroundColor(textColor)
            .frame(maxWidth: style == .pill || style == .iconOnly ? nil : .infinity)
            .frame(width: style == .iconOnly ? 44 : nil, height: style == .iconOnly ? 44 : nil)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(buttonBackground)
            .clipShape(buttonShape)
            .overlay(buttonBorder)
            .scaleEffect(isPressed ? 0.97 : (isHovered ? 1.02 : 1.0))
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
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .animation(.linear(duration: 0.15), value: isPressed)
    }
    
    private var buttonBackground: some ShapeStyle {
        let color = glassColorSystem.buttonColor(for: role)
        let bgColor = isHovered ? color.opacity(0.9) : color
        return AnyShapeStyle(bgColor)
    }
    
    private var textColor: Color {
        switch role {
        case .primary, .accent, .success, .danger:
            return .white
        case .surface:
            return glassColorSystem.textPrimary()
        }
    }
    
    private var buttonShape: AnyShapeWrapper {
        style == .iconOnly 
            ? AnyShapeWrapper(Circle())
            : AnyShapeWrapper(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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
    
    private var borderColor: Color {
        let color = glassColorSystem.buttonColor(for: role)
        return color.opacity(0.3)
    }
    
    private var cornerRadius: CGFloat {
        switch style {
        case .pill: return 20
        case .standard: return 10
        case .iconOnly: return 22 // Half of 44 for circle
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
    
    private var shadowColor: Color {
        Color.black.opacity(0.15)
    }
    
    private var shadowRadius: CGFloat {
        isHovered ? 8 : 4
    }
    
    private var shadowY: CGFloat {
        isHovered ? 4 : 2
    }
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

