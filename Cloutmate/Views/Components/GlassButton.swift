//
//  GlassButton.swift
//  Cloutmate
//
//  Glassmorphic Harmony UI - Glass Button Component
//

import SwiftUI

struct GlassButton: View {
    let title: String?
    let icon: String?
    let action: () -> Void
    
    var style: ButtonStyle = .standard
    var tier: GlassTier = .overlay
    var tintColor: Color = .blue
    
    @State private var isPressed = false
    @State private var rippleScale: CGFloat = 0
    @State private var rippleOpacity: Double = 0
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
        tier: GlassTier = .overlay,
        tintColor: Color = .blue,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.tier = tier
        self.tintColor = tintColor
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            triggerRipple()
            action()
        }) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                
                if let title = title {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundColor(tintColor)
            .padding(.horizontal, style == .iconOnly ? 12 : 16)
            .padding(.vertical, 10)
            .frame(minWidth: style == .iconOnly ? 44 : nil)
            .glassPanel(tier: tier, cornerRadius: style == .pill ? 20 : 10, tintColor: tintColor.opacity(0.15))
            .scaleEffect(isPressed ? GlassMotion.Transform.pressScale : 1.0)
            .overlay(
                // Ripple effect
                Circle()
                    .fill(tintColor.opacity(0.3))
                    .scaleEffect(rippleScale)
                    .opacity(rippleOpacity)
            )
        }
        .buttonStyle(.plain)
        .glassHoverEffect()
        .animation(GlassMotion.Easing.spring, value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    private func triggerRipple() {
        withAnimation(GlassMotion.Easing.buttonPress) {
            rippleScale = 2.0
            rippleOpacity = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + GlassMotion.Duration.buttonPress) {
            rippleScale = 0
            rippleOpacity = 0
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        GlassButton("Standard", icon: "plus", action: {})
        GlassButton("Pill Style", icon: "checkmark", style: .pill, action: {})
        GlassButton(icon: "heart.fill", style: .iconOnly, tintColor: .pink, action: {})
    }
    .padding()
}
