//
//  LuminanceFieldVisualizer.swift
//  Cloutmate
//
//  Real-time ambient visual feedback for Aurora's emotional climate
//

import SwiftUI
import Combine

struct LuminanceFieldVisualizer: View {
    @ObservedObject private var luminara = AuroraLuminara.shared
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @State private var particlePositions: [CGPoint] = []
    @State private var pulsePhase: Double = 0.0
    @State private var shimmerPhase: Double = 0.0
    
    private let particleCount = 50
    
    var body: some View {
        ZStack {
            // Reactive lighting overlay
            if luminara.showReactiveLighting {
                reactiveLightingOverlay
            }
            
            // Particle system
            if luminara.showParticles {
                particleSystem
            }
            
            // Pulse effect
            if luminara.showPulse {
                pulseEffect
            }
            
            // Shimmer effect (only for positive LF)
            if luminara.shimmerIntensity > 0 {
                shimmerEffect
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            initializeParticles()
            startAnimations()
        }
        .onChange(of: luminara.currentLF) { _, _ in
            updateParticleSystem()
        }
    }
    
    // MARK: - Reactive Lighting
    
    private var reactiveLightingOverlay: some View {
        GeometryReader { geometry in
            let intensity = luminara.lightingIntensity
            let colorTemp = luminara.getColorTemperature()
            
            // Warm or cool lighting based on color temperature
            let lightingColor: Color = {
                if colorTemp > 0 {
                    // Warm lighting (orange/yellow)
                    return Color.orange.opacity(intensity * 0.15)
                } else {
                    // Cool lighting (blue/cyan)
                    return Color.cyan.opacity(intensity * 0.15)
                }
            }()
            
            RadialGradient(
                colors: [
                    lightingColor,
                    lightingColor.opacity(0.3),
                    Color.clear
                ],
                center: .center,
                startRadius: geometry.size.width * 0.2,
                endRadius: geometry.size.width * 0.8
            )
            .opacity(intensity)
            .animation(.easeInOut(duration: 2.0), value: intensity)
        }
    }
    
    // MARK: - Particle System
    
    private var particleSystem: some View {
        GeometryReader { geometry in
            ForEach(0..<particleCount, id: \.self) { index in
                if index < particlePositions.count {
                    ParticleView(
                        position: particlePositions[index],
                        speed: luminara.particleMotionSpeed,
                        density: luminara.particleDensity,
                        colorTemperature: luminara.getColorTemperature(),
                        geometrySize: geometry.size
                    )
                }
            }
        }
    }
    
    // MARK: - Pulse Effect
    
    private var pulseEffect: some View {
        GeometryReader { geometry in
            let pulseRadius = geometry.size.width * 0.3
            let pulseIntensity = luminara.pulseFrequency > 0 ? 0.3 : 0.0
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            glassColorSystem.emotionalAccent().opacity(pulseIntensity * (0.5 + 0.5 * sin(pulsePhase))),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: pulseRadius
                    )
                )
                .frame(width: pulseRadius * 2, height: pulseRadius * 2)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
    
    // MARK: - Shimmer Effect
    
    private var shimmerEffect: some View {
        GeometryReader { geometry in
            let shimmer = luminara.shimmerIntensity
            
            if shimmer > 0 {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(shimmer * 0.3 * (0.5 + 0.5 * sin(shimmerPhase))),
                        Color.white.opacity(0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
                .rotationEffect(.degrees(shimmerPhase * 10))
            }
        }
    }
    
    // MARK: - Animation
    
    private func initializeParticles() {
        particlePositions = (0..<particleCount).map { _ in
            CGPoint(
                x: Double.random(in: 0...1000),
                y: Double.random(in: 0...1000)
            )
        }
    }
    
    private func updateParticleSystem() {
        // Update particle system based on new LF values
        // Particles will naturally flow based on motion speed
    }
    
    private func startAnimations() {
        // Use a single timer for all animations to reduce overhead
        Timer.publish(every: 0.016, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                // Pulse animation
                let frequency = luminara.pulseFrequency
                pulsePhase += frequency * 0.1
                if pulsePhase > .pi * 2 {
                    pulsePhase -= .pi * 2
                }
                
                // Shimmer animation
                shimmerPhase += 0.02
                if shimmerPhase > .pi * 2 {
                    shimmerPhase -= .pi * 2
                }
                
                // Particle motion
                updateParticlePositions()
            }
            .store(in: &luminara.cancellables)
    }
    
    private func updateParticlePositions() {
        let speed = luminara.particleMotionSpeed
        
        particlePositions = particlePositions.enumerated().map { index, position in
            // Gentle drift with speed variation
            // Use index for deterministic but varied motion
            let time = Date().timeIntervalSince1970
            let angle = sin(time * 0.5 + Double(index) * 0.1) * .pi * 2
            let distance = speed * 0.3
            
            var newX = position.x + cos(angle) * distance
            var newY = position.y + sin(angle) * distance
            
            // Wrap around screen edges (assuming 1000x1000 coordinate space)
            if newX < 0 { newX += 1000 }
            if newX > 1000 { newX -= 1000 }
            if newY < 0 { newY += 1000 }
            if newY > 1000 { newY -= 1000 }
            
            return CGPoint(x: newX, y: newY)
        }
    }
}

// MARK: - Particle View

private struct ParticleView: View {
    let position: CGPoint
    let speed: Double
    let density: Double
    let colorTemperature: Double
    let geometrySize: CGSize
    
    @State private var opacity: Double = 0.3
    
    var body: some View {
        let particleColor: Color = {
            if colorTemperature > 0 {
                // Warm particles (orange/yellow)
                return Color.orange
            } else {
                // Cool particles (blue/cyan)
                return Color.cyan
            }
        }()
        
        // Scale position to geometry size
        let scaledX = (position.x / 1000.0) * geometrySize.width
        let scaledY = (position.y / 1000.0) * geometrySize.height
        
        Circle()
            .fill(particleColor.opacity(opacity))
            .frame(width: 2 + (density * 3), height: 2 + (density * 3))
            .position(x: scaledX, y: scaledY)
            .blur(radius: 1)
            .onAppear {
                withAnimation(.easeInOut(duration: Double.random(in: 1...3)).repeatForever(autoreverses: true)) {
                    opacity = 0.1 + (density * 0.4)
                }
            }
    }
}

#Preview {
    LuminanceFieldVisualizer()
        .environmentObject(GlassColorSystem())
        .frame(width: 800, height: 600)
}

