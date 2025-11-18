//
//  RitualHistoryView.swift
//  FocusOS
//
//  Rituals V2: Streak visualization and ritual history metrics
//

import SwiftUI
import SwiftData

struct RitualHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @StateObject private var reactiveThemeManager = ReactiveThemeManager.shared
    
    let ritualType: FocusRitualType
    
    @State private var metricsSummary: RitualMetricsSummary?
    @State private var completionTrend: [(date: Date, completionRate: Double)] = []
    @State private var isHovered = false
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 18))
                        .foregroundColor(ritualType == .morning ? .kosmicBlue : .kosmicPurple)
                    
                    Text("History & Streaks")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(glassColorSystem.textPrimary())
                }
                
                if let summary = metricsSummary {
                    metricsGrid(summary: summary)
                    
                    if !completionTrend.isEmpty {
                        Divider()
                        trendChart
                    }
                } else {
                    Text("No ritual data available yet")
                        .font(.system(size: 13))
                        .foregroundColor(glassColorSystem.textSecondary())
                }
            }
            .padding(20)
        }
        .onHover { hovering in
            withAnimation(.spring(duration: 0.25)) {
                isHovered = hovering
            }
        }
        .task {
            await loadMetrics()
        }
    }
    
    @ViewBuilder
    private func metricsGrid(summary: RitualMetricsSummary) -> some View {
        let currentStreak = ritualType == .morning ? summary.morningStreak : summary.eveningStreak
        let bestStreak = ritualType == .morning ? summary.bestMorningStreak : summary.bestEveningStreak
        
        VStack(spacing: 16) {
            // Streak ring visualization
            HStack(spacing: 24) {
                StreakRingView(
                    currentStreak: currentStreak,
                    bestStreak: bestStreak,
                    color: ritualType == .morning ? .kosmicBlue : .kosmicPurple,
                    isHovered: isHovered
                )
                
                VStack(alignment: .leading, spacing: 12) {
                    RitualMetricRow(
                        label: "Current Streak",
                        value: "\(currentStreak) days",
                        color: ritualType == .morning ? Color.kosmicBlue : Color.kosmicPurple
                    )
                    
                    RitualMetricRow(
                        label: "Best Streak",
                        value: "\(bestStreak) days",
                        color: Color.secondary
                    )
                    
                    RitualMetricRow(
                        label: "Completion Rate",
                        value: String(format: "%.0f%%", summary.completionRate * 100),
                        color: summary.completionRate > 0.8 ? Color.kosmicGreen : Color.secondary
                    )
                    
                    RitualMetricRow(
                        label: "Emotional Avg",
                        value: emotionalStateLabel,
                        color: emotionalAccentColor
                    )
                }
            }
        }
    }
    
    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("14-Day Trend")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(glassColorSystem.textPrimary())
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.1))
                    
                    // Trend bars
                    HStack(spacing: 2) {
                        ForEach(completionTrend.prefix(14), id: \.date) { point in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            (ritualType == .morning ? Color.kosmicBlue : Color.kosmicPurple).opacity(0.6),
                                            (ritualType == .morning ? Color.kosmicBlue : Color.kosmicPurple)
                                        ],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .frame(width: max(2, geometry.size.width / CGFloat(min(14, completionTrend.count)) - 2))
                                .frame(height: geometry.size.height * point.completionRate)
                        }
                    }
                }
            }
            .frame(height: 60)
        }
    }
    
    private var emotionalStateLabel: String {
        let state = reactiveThemeManager.currentState
        switch state {
        case .calm:
            return "Calm"
        case .energized:
            return "Energized"
        case .focused:
            return "Focused"
        case .reflective:
            return "Reflective"
        case .fatigued:
            return "Fatigued"
        }
    }
    
    private var emotionalAccentColor: Color {
        switch reactiveThemeManager.currentState {
        case .calm:
            return .kosmicBlue
        case .energized:
            return .kosmicGreen
        case .focused:
            return .kosmicBlue
        case .reflective:
            return .kosmicPurple
        case .fatigued:
            return .kosmicPurple.opacity(0.7)
        }
    }
    
    @MainActor
    private func loadMetrics() async {
        metricsSummary = RitualAnalytics.shared.generateSummary(
            for: .thisWeek,
            modelContext: modelContext
        )
        
        completionTrend = RitualAnalytics.shared.completionTrend(
            days: 14,
            modelContext: modelContext
        )
    }
}

private struct StreakRingView: View {
    let currentStreak: Int
    let bestStreak: Int
    let color: Color
    let isHovered: Bool
    
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                .frame(width: 80, height: 80)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: isHovered
                            ? [color, color.opacity(0.6)]
                            : [color.opacity(0.8), color],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(-90 + rotation))
                .animation(.spring(duration: 0.35), value: isHovered)
                .animation(.spring(duration: 0.35), value: progress)
            
            // Center text
            VStack(spacing: 2) {
                Text("\(currentStreak)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(color)
                Text("days")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.5)) {
                rotation = isHovered ? 360 : 0
            }
        }
        .onChange(of: isHovered) { _, newValue in
            withAnimation(.spring(duration: 0.5)) {
                rotation = newValue ? 360 : 0
            }
        }
    }
    
    private var progress: Double {
        guard bestStreak > 0 else { return 0 }
        return min(Double(currentStreak) / Double(bestStreak), 1.0)
    }
}

private struct RitualMetricRow: View {
    let label: String
    let value: String
    let color: Color
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(glassColorSystem.textSecondary())
            
            Spacer()
            
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
        }
    }
}

#Preview {
    RitualHistoryView(ritualType: .morning)
        .padding()
        .environmentObject(GlassColorSystem())
}

