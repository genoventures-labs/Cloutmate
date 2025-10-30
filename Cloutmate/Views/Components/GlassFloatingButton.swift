//
//  GlassFloatingButton.swift
//  Cloutmate
//
//  Glassmorphic Harmony UI - Glass Floating Action Button
//

import SwiftUI

struct GlassFloatingButton: View {
    let icon: String
    let action: () -> Void
    
    var tintColor: Color = .blue
    var size: CGFloat = 56
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(tintColor)
                .frame(width: size, height: size)
                .glassPanel(
                    tier: .floatingAction,
                    cornerRadius: size / 2,
                    tintColor: tintColor.opacity(0.15)
                )
                .overlay(
                    // Light trail effect
                    Group {
                        if isHovered || isPressed {
                            Circle()
                                .stroke(
                                    tintColor.opacity(0.4),
                                    lineWidth: 2
                                )
                                .frame(width: size + 4, height: size + 4)
                                .blur(radius: 2)
                        }
                    }
                )
                .shadow(
                    color: (isHovered || isPressed) ? tintColor.opacity(0.3) : .black.opacity(0.2),
                    radius: isHovered ? 16 : 8,
                    y: isHovered ? 8 : 4
                )
                .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.05 : 1.0))
        }
        .buttonStyle(.plain)
        .animation(GlassMotion.Easing.spring, value: isHovered)
        .animation(GlassMotion.Easing.spring, value: isPressed)
        .onHover { hovering in
            isHovered = hovering
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

#Preview {
    ZStack(alignment: .bottomTrailing) {
        Color.gray.opacity(0.1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        
        VStack(spacing: 20) {
            GlassFloatingButton(icon: "plus", action: {}, tintColor: .blue)
            GlassFloatingButton(icon: "heart.fill", action: {}, tintColor: .pink)
            GlassFloatingButton(icon: "bolt.fill", action: {}, tintColor: .yellow)
        }
        .padding()
    }
    .frame(width: 300, height: 300)
}
