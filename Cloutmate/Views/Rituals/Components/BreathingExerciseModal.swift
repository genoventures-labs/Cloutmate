//
//  BreathingExerciseModal.swift
//  Cloutmate
//
//  V2-styled breathing exercise modal with animated guide
//

import SwiftUI

struct BreathingExerciseModal: View {
    @Binding var isPresented: Bool
    let ritualType: FocusRitualType
    let onComplete: () -> Void
    let onSkip: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var timeRemaining: TimeInterval = 120 // 2 minutes
    @State private var isBreathingIn = true
    @State private var breathingPhase: BreathingPhase = .inhale
    @State private var timer: Timer?
    @State private var breathingScale: CGFloat = 0.8
    @State private var isStarted = false
    @State private var isPaused = false
    
    private var tone: AuroraTone {
        AuroraToneKit.tone(for: ritualType)
    }
    
    // Use nav bar style - AuroraPalette gradients and colors
    private var navBarGradient: LinearGradient {
        AuroraPalette.linearGradient(for: colorScheme)
    }
    
    private var navBarGradientColors: [Color] {
        AuroraPalette.gradientColors(for: colorScheme)
    }
    
    // Aurora Orb colors from nav bar gradient
    private var auroraAccent: Color {
        navBarGradientColors.first ?? Color.cyan
    }
    
    private var auroraGlow: Color {
        navBarGradientColors.last ?? Color.purple
    }
    
    private var textPrimary: Color {
        glassColorSystem.textPrimary()
    }
    
    private var textSecondary: Color {
        glassColorSystem.textSecondary()
    }
    
    private var backdropColor: Color {
        glassColorSystem.backgroundColor().opacity(0.85)
    }
    
    enum BreathingPhase {
        case inhale
        case hold
        case exhale
        case pause
        
        var duration: TimeInterval {
            switch self {
            case .inhale: return 4.0
            case .hold: return 2.0
            case .exhale: return 6.0
            case .pause: return 2.0
            }
        }
        
        var instruction: String {
            switch self {
            case .inhale: return "Breathe in"
            case .hold: return "Hold"
            case .exhale: return "Breathe out"
            case .pause: return "Pause"
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Backdrop with blur
            backdropColor
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
                .onTapGesture {
                    closeModal()
                }
            
            // Modal content
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    // Main content card
                    VStack(spacing: 32) {
                        // Header Section
                        VStack(spacing: 10) {
                            Text("Breathing Exercise")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(textPrimary)
                            
                            Text("Take a moment to center yourself")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(textSecondary)
                        }
                        .padding(.top, 40)
                        
                        // Aurora Orb Section - using the same orb from nav bar
                        ZStack {
                            // Use AuroraOrbView - the same component used in nav bar/headers
                            // The orb has its own breathing animation, we scale it for breathing phases
                            AuroraOrbView(
                                accent: auroraAccent,
                                glow: auroraGlow,
                                size: 200,
                                isActive: isStarted,
                                showsPulse: isStarted && (breathingPhase == .inhale || breathingPhase == .hold)
                            )
                            .scaleEffect(isStarted ? breathingScale : 1.0)
                            .animation(.spring(response: 2.0, dampingFraction: 0.7), value: breathingScale)
                            
                            // Faint Aurora shimmer reflection during "breathe in" phase
                            if isStarted && breathingPhase == .inhale {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            gradient: Gradient(colors: navBarGradientColors.map { $0.opacity(0.08) }),
                                            center: .center,
                                            startRadius: 50,
                                            endRadius: 120
                                        )
                                    )
                                    .frame(width: 240, height: 240)
                                    .blur(radius: 20)
                                    .opacity(0.08)
                                    .overlay(
                                        // Additional shimmer layer with angular gradient
                                        Circle()
                                            .fill(
                                                AngularGradient(
                                                    gradient: Gradient(colors: navBarGradientColors.map { $0.opacity(0.06) }),
                                                    center: .center,
                                                    angle: .degrees(0)
                                                )
                                            )
                                            .frame(width: 240, height: 240)
                                            .blur(radius: 15)
                                    )
                            }
                            
                            // Content overlay on top of orb - with background for visibility
                            VStack(spacing: 12) {
                                if !isStarted {
                                    Text("Ready to begin?")
                                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Color.white)
                                        .shadow(color: Color.black.opacity(0.5), radius: 4, x: 0, y: 2)
                                        .shadow(color: navBarGradientColors.first?.opacity(0.6) ?? Color.cyan.opacity(0.6), radius: 8)
                                } else {
                                    Text(breathingPhase.instruction)
                                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Color.white)
                                        .shadow(color: Color.black.opacity(0.5), radius: 4, x: 0, y: 2)
                                        .shadow(color: navBarGradientColors.first?.opacity(0.6) ?? Color.cyan.opacity(0.6), radius: 8)
                                }
                                
                                Text(formatTime(timeRemaining))
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.white)
                                    .shadow(color: Color.black.opacity(0.5), radius: 4, x: 0, y: 2)
                                    .shadow(color: navBarGradientColors.first?.opacity(0.6) ?? Color.cyan.opacity(0.6), radius: 8)
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                // Subtle background for text readability
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(
                                        colorScheme == .dark
                                            ? Color.black.opacity(0.3)
                                            : Color.white.opacity(0.2)
                                    )
                                    .blur(radius: 8)
                            )
                        }
                        .frame(height: 300)
                        
                        // Instructions Section
                        VStack(spacing: 10) {
                            Text("Follow the rhythm")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(textPrimary.opacity(0.9))
                                .opacity(isStarted ? 1.0 : 0.0)
                                .animation(.easeIn(duration: 0.6).delay(0.3), value: isStarted)
                            
                            Text("Inhale for 4 counts, hold for 2, exhale for 6, pause for 2")
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundStyle(textSecondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        .padding(.horizontal, 40)
                        
                        // Action Buttons
                        HStack(spacing: 16) {
                            if !isStarted {
                                // Start button
                                GlassButton(
                                    "Start",
                                    icon: "play.fill",
                                    style: .pill,
                                    role: .primary
                                ) {
                                    startBreathing()
                                }
                            } else {
                                // Pause/Resume button
                                GlassButton(
                                    isPaused ? "Resume" : "Pause",
                                    icon: isPaused ? "play.fill" : "pause.fill",
                                    style: .pill,
                                    role: .accent
                                ) {
                                    if isPaused {
                                        resumeBreathing()
                                    } else {
                                        pauseBreathing()
                                    }
                                }
                            }
                            
                            GlassButton(
                                "Skip",
                                icon: "forward.fill",
                                style: .pill,
                                role: .surface
                            ) {
                                onSkip()
                                closeModal()
                            }
                            
                            if isStarted {
                                GlassButton(
                                    "Complete",
                                    icon: "checkmark",
                                    style: .pill,
                                    role: .primary
                                ) {
                                    onComplete()
                                    closeModal()
                                }
                            }
                        }
                        .padding(.bottom, 40)
                    }
                    .frame(maxWidth: 520)
                    .background(
                        ZStack {
                            // Use same background style as nav bar header
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .fill(glassColorSystem.backgroundElevated().opacity(0.72))
                            
                            // Nav bar gradient overlay
                            navBarGradient
                                .opacity(0.16)
                                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                            
                            // Aurora shimmer effect like nav bar
                            if !reduceMotion {
                                navBarGradient
                                    .opacity(0.10)
                                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                                    .auroraShimmer()
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .stroke(glassColorSystem.borderColor(), lineWidth: 0.9)
                        )
                    )
                    .shadow(
                        color: glassColorSystem.backgroundSecondary().opacity(0.18),
                        radius: 24,
                        y: 12
                    )
                }
            }
            .padding(60)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .onDisappear {
            stopTimer()
            stopBreathingCycle()
        }
    }
    
    private func startBreathing() {
        isStarted = true
        isPaused = false
        startBreathingCycle()
        startTimer()
    }
    
    private func pauseBreathing() {
        isPaused = true
        stopBreathingCycle()
        stopTimer()
    }
    
    private func resumeBreathing() {
        isPaused = false
        startBreathingCycle()
        startTimer()
    }
    
    private func startBreathingCycle() {
        guard !reduceMotion && isStarted && !isPaused else { return }
        
        let phase = breathingPhase
        let duration = phase.duration
        
        // Smooth animation with spring physics for natural breathing feel
        withAnimation(.spring(response: duration * 0.8, dampingFraction: 0.7, blendDuration: 0.2)) {
            switch phase {
            case .inhale:
                breathingScale = 1.25
            case .hold:
                breathingScale = 1.25
            case .exhale:
                breathingScale = 0.75
            case .pause:
                breathingScale = 0.75
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            if isPresented && isStarted && !isPaused {
                cycleToNextPhase()
            }
        }
    }
    
    private func stopBreathingCycle() {
        // Reset breathing scale when stopped
        breathingScale = 0.8
    }
    
    private func cycleToNextPhase() {
        switch breathingPhase {
        case .inhale:
            breathingPhase = .hold
        case .hold:
            breathingPhase = .exhale
        case .exhale:
            breathingPhase = .pause
        case .pause:
            breathingPhase = .inhale
        }
        startBreathingCycle()
    }
    
    private func startTimer() {
        guard isStarted && !isPaused else { return }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard isPresented && isStarted && !isPaused else { return }
            if timeRemaining > 0 {
                timeRemaining -= 1.0
            } else {
                onComplete()
                self.closeModal()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func closeModal() {
        withAnimation(GlassMotion.Easing.modalOpen) {
            isPresented = false
        }
    }
}

#Preview {
    BreathingExerciseModal(
        isPresented: .constant(true),
        ritualType: .morning,
        onComplete: {},
        onSkip: {}
    )
    .environmentObject(GlassColorSystem())
}

