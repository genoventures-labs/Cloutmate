//
//  FocusModeActiveView.swift
//  FocusOS
//
//  V2: Immersive active session view with orb timer and ambient visuals
//

import SwiftUI
import SwiftData
import Combine
import FocusOSShared

struct FocusModeActiveView: View {
    let session: FocusSession
    let breathingEnabled: Bool
    let onPause: () -> Void
    let onResume: () -> Void
    let onSkip: () -> Void
    let onEnd: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var currentTime = Date()
    @State private var sessionLFHistory: [Double] = []
    @State private var currentLF: Double = 0.0
    @State private var previousStability: Double?
    
    @ObservedObject private var luminara = AuroraLuminara.shared
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let lfTimer = Timer.publish(every: 8, on: .main, in: .common).autoconnect() // Update LF every 8 seconds
    
    // Aurora palette colors
    private var navBarGradient: LinearGradient {
        AuroraPalette.linearGradient(for: colorScheme)
    }
    
    private var navBarGradientColors: [Color] {
        AuroraPalette.gradientColors(for: colorScheme)
    }
    
    private var auroraAccent: Color {
        navBarGradientColors.first ?? Color.cyan
    }
    
    private var auroraGlow: Color {
        navBarGradientColors.last ?? Color.purple
    }
    
    var body: some View {
        ZStack {
            // Dark background with static gradient (no animation)
            ZStack {
                Color.black.opacity(0.95)
                    .ignoresSafeArea()
                
                // Static Aurora gradient (no moving animation)
                navBarGradient
                    .opacity(0.12)
                    .ignoresSafeArea()
            }
            
            // Luminance Field Visualizer overlay (particles, pulse, etc. - but no moving overlay)
            LuminanceFieldVisualizer()
                .allowsHitTesting(false)
            
            HStack(spacing: 0) {
                // Main content area
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Center orb timer
                    VStack(spacing: 24) {
                        // Orb with timer overlay
                        ZStack {
                            // Aurora Orb
                            AuroraOrbView(
                                accent: orbAccentColor,
                                glow: orbGlowColor,
                                size: 220,
                                isActive: !session.isPaused,
                                showsPulse: breathingEnabled && !session.isPaused
                            )
                            .scaleEffect(orbScale)
                            .animation(.spring(response: 2.0, dampingFraction: 0.7), value: orbScale)
                            
                            // Timer text overlay
                            VStack(spacing: 8) {
                                if session.isPaused {
                                    Text("Paused")
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Color.white.opacity(0.8))
                                } else {
                                    Text(formatTime(session.remainingTime))
                                        .font(.system(size: 48, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.white)
                                        .monospacedDigit()
                                        .shadow(color: Color.black.opacity(0.5), radius: 4, x: 0, y: 2)
                                        .shadow(color: orbAccentColor.opacity(0.6), radius: 8)
                                    
                                    Text(session.remainingTime > 0 ? "Remaining" : "Overtime")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color.white.opacity(0.7))
                                }
                            }
                        }
                        .frame(height: 280)
                        
                        // Objective and context
                        VStack(spacing: 8) {
                            Text(session.objective)
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .shadow(color: Color.black.opacity(0.3), radius: 2)
                            
                            if let targetId = session.targetObjectId,
                               let targetType = session.targetObjectType {
                                Text("Linked to \(targetType)")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 40)
                    }
                    
                    Spacer()
                    
                    // Session controls
                    HStack(spacing: 16) {
                        if session.isPaused {
                            GlassButton(
                                "Resume",
                                icon: "play.fill",
                                style: .pill,
                                role: .primary
                            ) {
                                onResume()
                            }
                        } else {
                            GlassButton(
                                "Pause",
                                icon: "pause.fill",
                                style: .pill,
                                role: .accent
                            ) {
                                onPause()
                            }
                        }
                        
                        GlassButton(
                            "Skip",
                            icon: "forward.fill",
                            style: .pill,
                            role: .surface
                        ) {
                            onSkip()
                        }
                        
                        GlassButton(
                            "End Session",
                            icon: "checkmark.circle.fill",
                            style: .pill,
                            role: .primary
                        ) {
                            onEnd()
                        }
                    }
                    .padding(.bottom, 60)
                }
                .frame(maxWidth: .infinity)
                
                // Stats sidebar (always visible)
                Divider()
                    .opacity(0.1)
                
                FocusModeStatsSidebar(
                    session: session,
                    sessionLFHistory: sessionLFHistory,
                    focusGravityTrend: session.focusGravityTrend ?? [],
                    stabilityIndex: session.stabilityIndex ?? 50.0,
                    emotionalAvg: session.averageLF ?? 0.0,
                    streak: FocusSessionService.shared.calculateStreak(modelContext: modelContext),
                    completionRate: calculateCompletionRate()
                )
                .frame(width: 320)
                .background(glassColorSystem.backgroundElevated().opacity(0.85))
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .onReceive(lfTimer) { _ in
            updateLF()
        }
        .task {
            loadSessionLFHistory()
            updateLF()
        }
    }
    
    // MARK: - Computed Properties
    
    private var orbAccentColor: Color {
        // Color temperature based on LF
        if currentLF > 0.5 {
            // Warm (positive LF)
            return Color.orange
        } else if currentLF > 0.0 {
            return auroraAccent
        } else {
            // Cool (negative LF)
            return Color.cyan
        }
    }
    
    private var orbGlowColor: Color {
        if currentLF > 0.5 {
            return Color.yellow
        } else if currentLF > 0.0 {
            return auroraGlow
        } else {
            return Color.blue
        }
    }
    
    private var orbScale: CGFloat {
        if breathingEnabled && !session.isPaused {
            // Breathing animation: 0.95 to 1.05
            let phase = sin(Date().timeIntervalSince1970 * 0.5) * 0.05
            return 1.0 + phase
        }
        return 1.0
    }
    
    // MARK: - Methods
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let absInterval = abs(interval)
        let totalSeconds = Int(absInterval)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let sign = interval < 0 ? "-" : ""
        return String(format: "\(sign)%d:%02d", minutes, seconds)
    }
    
    private func calculateCompletionRate() -> Double {
        // Get all sessions and calculate completion rate
        let descriptor = FetchDescriptor<FocusSession>()
        let allSessions = (try? modelContext.fetch(descriptor)) ?? []
        let completed = allSessions.filter { $0.status == .completed }.count
        return allSessions.isEmpty ? 0.0 : Double(completed) / Double(allSessions.count)
    }
    
    private func loadSessionLFHistory() {
        sessionLFHistory = session.lfHistory
    }
    
    private func updateLF() {
        guard !session.isPaused else { return }
        
        _Concurrency.Task {
            // Calculate LF
            if let lfHistory = await AuroraLuminara.shared.calculateLuminanceField(modelContext: modelContext) {
                await MainActor.run {
                    currentLF = lfHistory.luminanceField
                    sessionLFHistory.append(currentLF)
                    
                    // Record in session
                    FocusSessionService.shared.recordLFValue(currentLF, for: session, modelContext: modelContext)
                    
                    // Calculate current stability
                    let metrics = FocusSessionService.shared.calculateSessionMetrics(for: session, modelContext: modelContext)
                    let currentStability = metrics.stabilityIndex / 100.0 // Normalize to 0-1
                    
                    // Check focus stability drop
                    if let previous = previousStability {
                        SmartNudgeService.shared.checkFocusStability(
                            session: session,
                            previousStability: previous,
                            currentStability: currentStability,
                            modelContext: modelContext
                        )
                    }
                    previousStability = currentStability
                    
                    // Check deep flow state (every 20 samples, ~2.5 minutes)
                    if sessionLFHistory.count % 20 == 0 {
                        SmartNudgeService.shared.checkDeepFlowState(
                            session: session,
                            lfHistory: sessionLFHistory,
                            modelContext: modelContext
                        )
                    }
                }
            }
        }
    }
}

#Preview {
    let session = FocusSession(objective: "Write blog post", plannedDuration: 1800)
    return FocusModeActiveView(
        session: session,
        breathingEnabled: false,
        onPause: {},
        onResume: {},
        onSkip: {},
        onEnd: {}
    )
    .environmentObject(GlassColorSystem())
    .modelContainer(for: [FocusSession.self])
}

