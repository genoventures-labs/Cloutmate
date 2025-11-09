//
//  RitualsSummaryView.swift
//  Cloutmate
//
//  Dashboard V2 - Rituals & Streaks Panel
//

import SwiftUI
import SwiftData

struct RitualsSummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @StateObject private var reactiveThemeManager = ReactiveThemeManager.shared
    @State private var metricsSummary: RitualMetricsSummary?
    @State private var upcomingRituals: [FocusRitual] = []
    @State private var pulsePhase: Double = 0.0
    @State private var showRitualsView = false
    
    private var hasActiveStreak: Bool {
        (metricsSummary?.morningStreak ?? 0) > 0 || (metricsSummary?.eveningStreak ?? 0) > 0
    }
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18))
                        .foregroundColor(.kosmicPurple)
                    Text("Rituals & Streaks")
                        .font(.headline)
                        .foregroundColor(glassColorSystem.textPrimary())
                    
                    Spacer()
                    
                    Button {
                        showRitualsView = true
                    } label: {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.kosmicPurple)
                    }
                    .buttonStyle(.plain)
                }
                
                if let summary = metricsSummary {
                    // Morning & Evening completion bars
                    VStack(spacing: 12) {
                        RitualCompletionBar(
                            title: "Morning",
                            streak: summary.morningStreak,
                            bestStreak: summary.bestMorningStreak,
                            completionRate: summary.completionRate,
                            color: .kosmicGreen
                        )
                        
                        RitualCompletionBar(
                            title: "Evening",
                            streak: summary.eveningStreak,
                            bestStreak: summary.bestEveningStreak,
                            completionRate: summary.completionRate,
                            color: .kosmicBlue
                        )
                    }
                    
                    // Next Nudge forecast
                    if let nextRitual = upcomingRituals.first {
                        HStack {
                            Image(systemName: "bell.fill")
                                .font(.caption)
                                .foregroundColor(.kosmicPurple)
                            Text("Next: \(nextRitual.scheduledFor, style: .time)")
                                .font(.caption)
                                .foregroundColor(glassColorSystem.textSecondary())
                        }
                    }
                } else {
                    Text("No ritual data available")
                        .font(.caption)
                        .foregroundColor(glassColorSystem.textSecondary())
                }
            }
            .padding(16)
        }
        .overlay(
            // ARTE adaptive icon animation
            Group {
                if hasActiveStreak && !reduceMotion {
                    Circle()
                        .stroke(reactiveThemeManager.currentState == .energized ? .kosmicGreen : .kosmicBlue, lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .opacity(0.3 + pulsePhase * 0.3)
                        .scaleEffect(1.0 + pulsePhase * 0.1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(16)
        )
        .task {
            await loadData()
        }
        .onAppear {
            if hasActiveStreak {
                startPulseAnimation()
            }
        }
        .sheet(isPresented: $showRitualsView) {
            RitualsViewV2()
                .environmentObject(glassColorSystem)
        }
    }
    
    @MainActor
    private func loadData() async {
        metricsSummary = RitualAnalytics.shared.generateSummary(
            for: .thisWeek,
            modelContext: modelContext
        )
        
        // Fetch upcoming rituals
        let descriptor = FetchDescriptor<FocusRitual>()
        let allRituals = (try? modelContext.fetch(descriptor)) ?? []
        upcomingRituals = allRituals.filter { $0.scheduledFor > Date() }
            .sorted { $0.scheduledFor < $1.scheduledFor }
    }
    
    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulsePhase = 1.0
        }
    }
}

struct RitualCompletionBar: View {
    let title: String
    let streak: Int
    let bestStreak: Int
    let completionRate: Double
    let color: Color
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(glassColorSystem.textPrimary())
                Spacer()
                HStack(spacing: 8) {
                    Text("\(streak) day streak")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(color)
                    if bestStreak > streak {
                        Text("(Best: \(bestStreak))")
                            .font(.caption2)
                            .foregroundColor(glassColorSystem.textSecondary())
                    }
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.6), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * completionRate, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

#Preview {
    RitualsSummaryView()
        .padding()
        .environmentObject(GlassColorSystem())
}

