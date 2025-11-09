//
//  CurrentRitualCard.swift
//  Cloutmate
//
//  Rituals V2: Card displaying active ritual or start button
//

import SwiftUI
import SwiftData

struct CurrentRitualCard: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @StateObject private var ritualManager = FocusRitualManager.shared
    
    let ritualType: FocusRitualType
    let ritualDuration: TimeInterval
    let progress: Double
    let isRitualActive: Bool
    let onStartRitual: () -> Void
    let onEndEarly: () -> Void
    
    @State private var currentRitual: FocusRitual?
    @State private var currentStepIndex: Int = 0
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(spacing: 20) {
                switch cardState {
                case .idle:
                    idleState
                case .active:
                    activeState
                case .complete:
                    completeState
                }
            }
            .padding(24)
        }
        .task {
            await loadCurrentRitual()
        }
        .onChange(of: ritualManager.activeRitual) { _, newRitual in
            currentRitual = newRitual
        }
    }
    
    private enum CardState {
        case idle
        case active
        case complete
    }
    
    private var cardState: CardState {
        guard let ritual = currentRitual else { return .idle }
        
        if ritual.status == .completed {
            return .complete
        } else if isRitualActive {
            return .active
        } else {
            return .idle
        }
    }
    
    private var idleState: some View {
        VStack(spacing: 16) {
            Image(systemName: ritualType == .morning ? "sunrise.fill" : "moon.stars.fill")
                .font(.system(size: 48))
                .foregroundColor(ritualType == .morning ? .kosmicBlue : .kosmicPurple)
            
            Text("Start \(ritualType.displayName)")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(glassColorSystem.textPrimary())
            
            Text(ritualType == .morning ? "Begin your morning focus ritual" : "Begin your evening reflection")
                .font(.system(size: 14))
                .foregroundColor(glassColorSystem.textSecondary())
                .multilineTextAlignment(.center)
            
            Button {
                onStartRitual()
            } label: {
                Text("Start Ritual")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: ritualType == .morning 
                                ? [.kosmicBlue, .kosmicPurple]
                                : [.kosmicPurple, .kosmicGreen],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var activeState: some View {
        VStack(spacing: 20) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: stepProgress)
                    .stroke(
                        LinearGradient(
                            colors: ritualType == .morning 
                                ? [.kosmicBlue, .kosmicPurple]
                                : [.kosmicPurple, .kosmicGreen],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.25), value: stepProgress)
                
                VStack(spacing: 2) {
                    Text(formatTime(ritualDuration))
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(glassColorSystem.textPrimary())
                        .monospacedDigit()
                }
            }
            
            if let ritual = currentRitual {
                VStack(spacing: 8) {
                    Text("Ritual in progress")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(glassColorSystem.textPrimary())
                    
                    Text("Step \(currentStepIndex + 1) of 5")
                        .font(.system(size: 14))
                        .foregroundColor(glassColorSystem.textSecondary())
                }
            }
            
            Button {
                onEndEarly()
            } label: {
                Text("End Early")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var completeState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.kosmicGreen)
            
            Text("Ritual Complete")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(glassColorSystem.textPrimary())
            
            if let ritual = currentRitual {
                Text("\(ritual.streakCount) day streak")
                    .font(.system(size: 14))
                    .foregroundColor(.kosmicGreen)
            }
        }
    }
    
    private var stepProgress: Double {
        // Progress is passed from parent based on steps completed
        return progress
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    @MainActor
    private func loadCurrentRitual() async {
        ritualManager.refreshRitualSchedule(modelContext: modelContext)
        currentRitual = ritualManager.activeRitual
    }
}

#Preview {
    CurrentRitualCard(
        ritualType: .morning,
        ritualDuration: 125,
        progress: 0.4,
        isRitualActive: true,
        onStartRitual: {},
        onEndEarly: {}
    )
    .padding()
    .environmentObject(GlassColorSystem())
}

