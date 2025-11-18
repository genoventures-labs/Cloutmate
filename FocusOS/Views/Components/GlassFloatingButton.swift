//
//  GlassFloatingButton.swift
//  FocusOS
//
//  Minimal Floating Action Button
//

import SwiftUI

struct GlassFloatingButton: View {
    let icon: String
    let action: () -> Void
    
    var tintColor: Color = Color(red: 0.36, green: 0.66, blue: 1.0)
    var size: CGFloat = 56
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(tintColor)
                    .overlay(
                        Circle()
                            .strokeBorder(tintColor.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(
                        color: Color.black.opacity(shadowOpacity),
                        radius: shadowRadius,
                        x: 0,
                        y: shadowY
                    )
                    .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.02 : 1.0))
                    .opacity(isPressed ? 0.9 : 1.0)
                
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onHover { hovering in
            isHovered = hovering
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    private var shadowOpacity: Double {
        isHovered ? 0.25 : 0.18
    }
    
    private var shadowRadius: CGFloat {
        isHovered ? 12 : 10
    }
    
    private var shadowY: CGFloat {
        isHovered ? 6 : 4
    }
}

#Preview {
    ZStack(alignment: .bottomTrailing) {
        VStack(spacing: 20) {
            GlassFloatingButton(icon: "plus", action: {}, tintColor: .kosmicBlue)
            GlassFloatingButton(icon: "heart.fill", action: {}, tintColor: .pink)
        }
        .padding()
    }
    .frame(width: 300, height: 300)
    .environmentObject(GlassColorSystem())
}
