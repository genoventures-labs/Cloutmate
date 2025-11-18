//
//  AuroraOrbView.swift
//  FocusOS
//
//  Shared orb animation used by Aurora chat surfaces.
//

import SwiftUI

struct AuroraOrbView: View {
    var accent: Color
    var glow: Color
    var size: CGFloat = 56
    var isActive: Bool = true
    var showsPulse: Bool = false

    @State private var breathingPhase: Double = 0
    @State private var pulseScale: CGFloat = 1

    private var breathingAnimation: Animation {
        Animation.easeInOut(duration: 3.0)
            .repeatForever(autoreverses: true)
    }

    private var pulseAnimation: Animation {
        Animation.easeOut(duration: 0.45)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            accent.opacity(0.45 + 0.15 * sin(breathingPhase)),
                            glow.opacity(0.25)
                        ]),
                        center: .center,
                        startRadius: 4,
                        endRadius: size * 0.75
                    )
                )
                .scaleEffect(CGFloat(1.05 + 0.025 * sin(breathingPhase)))
                .blur(radius: 22)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [accent, glow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 1.2)
                )
                .shadow(color: glow.opacity(0.45), radius: 18, y: 10)
                .scaleEffect(pulseScale)
                .animation(showsPulse ? pulseAnimation : .default, value: pulseScale)
        }
        .frame(width: size, height: size)
        .onAppear {
            guard isActive else { return }
            withAnimation(breathingAnimation) {
                breathingPhase = .pi * 2
            }
        }
        .onChange(of: showsPulse) { _, newValue in
            guard newValue else { return }
            pulseScale = 1.12
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.46) {
                withAnimation(pulseAnimation) {
                    pulseScale = 1.0
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.edgesIgnoringSafeArea(.all)
        AuroraOrbView(
            accent: .kosmicBlue,
            glow: .kosmicPurple,
            size: 84,
            isActive: true,
            showsPulse: true
        )
    }
}

