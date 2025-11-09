//
//  FocusSessionPanel.swift
//  Cloutmate
//
//  Focus Mode V2 - Core Session Panel
//

import SwiftUI
import SwiftData
import Combine
import CloutmateShared

enum DurationMode: String, CaseIterable {
    case pomodoro = "Pomodoro"
    case custom = "Custom"
}

struct FocusSessionPanel: View {
    let session: FocusSession?
    let streakCount: Int
    let cpsScore: Double?
    let durationMode: DurationMode
    let onDurationModeChange: (DurationMode) -> Void
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentTime = Date()
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var isPaused = false
    @State private var sessionState: SessionState = .idle
    
    enum SessionState {
        case idle
        case active
        case paused
        case complete
    }
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(spacing: 24) {
                // Central Timer Display
                timerDisplay
                
                // Objective Label
                if let session = session {
                    objectiveLabel(session: session)
                }
                
                // Mini-Stats Row
                if let session = session {
                    miniStatsRow(session: session)
                }
                
                // Duration Mode Toggle
                durationModeToggle
            }
            .padding(32)
        }
        .opacity(sessionState == .paused ? 0.6 : 1.0)
        .saturation(sessionState == .paused ? 0.6 : 1.0)
        .animation(GlassMotion.Easing.spring, value: sessionState)
        .onReceive(timer) { _ in
            if session != nil && !isPaused {
                currentTime = Date()
            }
        }
        .onChange(of: session) { _, newSession in
            updateSessionState(newSession)
        }
        .onAppear {
            updateSessionState(session)
        }
    }
    
    // MARK: - Timer Display
    
    @ViewBuilder
    private var timerDisplay: some View {
        if let session = session {
            VStack(spacing: 8) {
                Text(formattedTime(session: session))
                    .font(.system(size: timerFontSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(timerGradient)
                    .dynamicTypeSize(.large)
                    .minimumScaleFactor(0.5)
                    .accessibilityLabel("Session timer: \(accessibilityTimeString(session: session))")
                    .accessibilityValue(formattedTime(session: session))
                    .accessibilityAddTraits(.updatesFrequently)
                
                Text(sessionState == .paused ? "Paused" : (session.elapsedTime > session.plannedDuration ? "Overtime" : "Remaining"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } else {
            VStack(spacing: 8) {
                Text("00:00")
                    .font(.system(size: timerFontSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.kosmicBlue, Color.kosmicPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .dynamicTypeSize(.large)
                
                Text("Ready to begin")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var timerFontSize: CGFloat {
        // Responsive scaling based on window size
        // Base size 64, scales down for smaller windows
        return 64
    }
    
    private var timerGradient: LinearGradient {
        switch sessionState {
        case .idle:
            return LinearGradient(
                colors: [Color.kosmicBlue, Color.kosmicPurple],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .active:
            return LinearGradient(
                colors: [
                    glassColorSystem.emotionalAccent(),
                    Color.kosmicPurple
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .paused:
            return LinearGradient(
                colors: [Color.secondary, Color.secondary.opacity(0.7)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .complete:
            return LinearGradient(
                colors: [Color.kosmicGreen, Color.kosmicPurple],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    // MARK: - Objective Label
    
    @ViewBuilder
    private func objectiveLabel(session: FocusSession) -> some View {
        VStack(spacing: 4) {
            Text("Current Focus")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            if let targetId = session.targetObjectId,
               let targetType = session.targetObjectType {
                Text("\(targetType.capitalized): \(session.objective)")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            } else {
                Text(session.objective)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Mini-Stats Row
    
    @ViewBuilder
    private func miniStatsRow(session: FocusSession) -> some View {
        HStack(spacing: 24) {
            // Elapsed Time
            statItem(
                title: "Elapsed",
                value: formatDuration(session.elapsedTime),
                icon: "clock.fill"
            )
            
            // Focus Gravity %
            if let score = cpsScore {
                statItem(
                    title: "Gravity",
                    value: "\(Int(score * 100))%",
                    icon: "gauge.with.dots.needle.67percent"
                )
            }
            
            // Streak Count
            statItem(
                title: "Streak",
                value: "\(streakCount)",
                icon: "flame.fill"
            )
            
            // Session Mood (ARTE tone)
            statItem(
                title: "Mood",
                value: ReactiveThemeManager.shared.currentState.rawValue.capitalized,
                icon: "heart.fill",
                color: glassColorSystem.emotionalAccent()
            )
        }
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private func statItem(title: String, value: String, icon: String, color: Color? = nil) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color ?? .kosmicBlue)
            
            Text(value)
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Duration Mode Toggle
    
    @ViewBuilder
    private var durationModeToggle: some View {
        Picker("Duration Mode", selection: Binding(
            get: { durationMode },
            set: { onDurationModeChange($0) }
        )) {
            ForEach(DurationMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.top, 8)
    }
    
    // MARK: - Helpers
    
    private func formattedTime(session: FocusSession) -> String {
        let remaining = max(0, session.plannedDuration - session.elapsedTime)
        let minutes = Int(remaining / 60)
        let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func accessibilityTimeString(session: FocusSession) -> String {
        let remaining = max(0, session.plannedDuration - session.elapsedTime)
        let minutes = Int(remaining / 60)
        let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))
        return "\(minutes) minutes and \(seconds) seconds"
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
    
    private func updateSessionState(_ session: FocusSession?) {
        guard let session = session else {
            sessionState = .idle
            isPaused = false
            return
        }
        
        if session.status == .completed {
            sessionState = .complete
            isPaused = false
        } else if isPaused {
            sessionState = .paused
        } else {
            sessionState = .active
        }
    }
}

#Preview {
    FocusSessionPanel(
        session: nil,
        streakCount: 5,
        cpsScore: 0.75,
        durationMode: .pomodoro,
        onDurationModeChange: { _ in }
    )
    .environmentObject(GlassColorSystem())
    .padding()
    .modelContainer(for: [FocusSession.self])
}

