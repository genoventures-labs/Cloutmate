//
//  AIFloatingButton.swift
//  FocusOS
//
//  AI Floating Action Button
//

import SwiftUI

struct AIFloatingButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    ZStack {
                        // Gradient background
                        LinearGradient(
                            colors: [.kosmicBlue, .kosmicPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        
                        // Glass effect
                        .background(.ultraThinMaterial)
                    }
                )
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: Color.kosmicBlue.opacity(0.3), radius: 12, x: 0, y: 6)
                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .scaleEffect(1.0)
        .animation(GlassMotion.Easing.spring, value: 1.0)
    }
}
