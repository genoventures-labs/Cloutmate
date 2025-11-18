//
//  AuroraAvatar.swift
//  FocusOS
//
//  Aurora avatar component with facial expressions and micro-animations
//

import SwiftUI

struct AuroraAvatar: View {
    let emotionalState: EmotionalState
    let isThinking: Bool
    
    @State private var breathingPhase: CGFloat = 0
    @State private var expressionPhase: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(avatarBackgroundColor)
                .frame(width: 40, height: 40)
            
            // Sparkles icon (Aurora's symbol)
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(avatarIconColor)
                .symbolEffect(.pulse, options: .repeating.speed(breathingSpeed), isActive: isThinking)
                .opacity(0.8 + 0.2 * Darwin.cos(breathingPhase))
        }
        .onAppear {
            startBreathingAnimation()
        }
    }
    
    private var avatarBackgroundColor: Color {
        switch emotionalState {
        case .focused:
            return Color.kosmicBlue.opacity(0.2)
        case .energized:
            return Color.kosmicBlue.opacity(0.25)
        case .reflective:
            return Color.kosmicPurple.opacity(0.2)
        case .calm:
            return Color.gray.opacity(0.15)
        case .fatigued:
            return Color.gray.opacity(0.1)
        }
    }
    
    private var avatarIconColor: Color {
        switch emotionalState {
        case .focused:
            return .kosmicBlue
        case .energized:
            return .kosmicBlue
        case .reflective:
            return .kosmicPurple
        case .calm:
            return .secondary
        case .fatigued:
            return .secondary.opacity(0.7)
        }
    }
    
    private var breathingSpeed: Double {
        switch emotionalState {
        case .focused, .energized:
            return 0.5 // Faster breathing
        case .reflective:
            return 0.4
        case .calm:
            return 0.3 // Slower, calmer breathing
        case .fatigued:
            return 0.25 // Very slow
        }
    }
    
    private func startBreathingAnimation() {
        withAnimation(
            Animation.linear(duration: 3.0 / breathingSpeed)
                .repeatForever(autoreverses: false)
        ) {
            breathingPhase = .pi * 2
        }
    }
}

