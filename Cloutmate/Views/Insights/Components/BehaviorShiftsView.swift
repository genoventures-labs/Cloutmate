//
//  BehaviorShiftsView.swift
//  Cloutmate
//
//  V2-styled dashboard showing behavior shift trends and cause/effect patterns
//

import SwiftUI
import SwiftData

struct BehaviorShiftsView: View {
    let timeRange: AnalyticsTimeRange
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var behaviorShifts: [BehaviorShift] = []
    @State private var isLoading = false
    
    private var lookbackDays: Int {
        switch timeRange {
        case .today: return 7
        case .thisWeek: return 14
        case .thisMonth: return 30
        case .thisYear: return 90
        @unknown default:
            return 30
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Section Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Behavior Shifts")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.kosmicPurple, Color.kosmicBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Pattern changes and cause/effect insights")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if behaviorShifts.isEmpty {
                emptyState
            } else {
                shiftsContent
            }
        }
        .task {
            await loadBehaviorShifts()
        }
        .onChange(of: timeRange) { _, _ in
            Task {
                await loadBehaviorShifts()
            }
        }
    }
    
    private var emptyState: some View {
        DashboardTile(accent: .kosmicPurple.opacity(0.7), padding: 40) {
            VStack(spacing: 16) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(glassColorSystem.textSecondary().opacity(0.5))
                
                Text("No behavior shifts detected")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                Text("Complete more rituals to see pattern changes over time")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var shiftsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(behaviorShifts) { shift in
                BehaviorShiftCard(shift: shift)
            }
        }
        .padding(.horizontal, 20)
    }
    
    @MainActor
    private func loadBehaviorShifts() async {
        isLoading = true
        defer { isLoading = false }
        
        let shifts = RitualPatternLearner.shared.calculateBehaviorShifts(
            for: nil, // All ritual types
            modelContext: modelContext,
            lookbackDays: lookbackDays
        )
        
        behaviorShifts = shifts
    }
}

struct BehaviorShiftCard: View {
    let shift: BehaviorShift
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var accentColor: Color {
        shift.trend == .improving ? .kosmicGreen : .orange
    }
    
    private var changeIcon: String {
        shift.trend == .improving ? "arrow.up.right" : "arrow.down.right"
    }
    
    private var changeText: String {
        let sign = shift.percentageChange > 0 ? "+" : ""
        let formatted = String(format: "%.0f", abs(shift.percentageChange))
        return "\(sign)\(formatted)%"
    }
    
    var body: some View {
        DashboardTile(accent: accentColor.opacity(0.8), padding: 24) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(shift.metric)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(glassColorSystem.textPrimary())
                        
                        if let cause = shift.cause {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12, weight: .medium))
                                Text("\(changeText) \(cause)")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(accentColor)
                        } else {
                            Text(changeText)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(accentColor)
                        }
                    }
                    
                    Spacer()
                    
                    // Trend indicator
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.15))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: changeIcon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(accentColor)
                    }
                }
                
                // Value comparison
                HStack(spacing: 16) {
                    valueComparison(
                        label: "Recent",
                        value: shift.recentValue,
                        color: accentColor
                    )
                    
                    Divider()
                        .frame(height: 40)
                    
                    valueComparison(
                        label: "Earlier",
                        value: shift.earlierValue,
                        color: glassColorSystem.textSecondary()
                    )
                }
                .padding(.top, 4)
                
                // Visual trend bar
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        // Earlier value bar
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(glassColorSystem.borderColor().opacity(0.3))
                            .frame(width: geometry.size.width * 0.4)
                        
                        // Arrow
                        Image(systemName: changeIcon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .frame(width: geometry.size.width * 0.2)
                        
                        // Recent value bar
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [accentColor, accentColor.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * 0.4)
                    }
                }
                .frame(height: 8)
                .padding(.top, 8)
            }
        }
    }
    
    private func valueComparison(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(glassColorSystem.textSecondary())
            
            Text(formatValue(value))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
    }
    
    private func formatValue(_ value: Double) -> String {
        if value < 1.0 {
            return String(format: "%.0f%%", value * 100)
        } else if value < 100 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.0f", value)
        }
    }
}

#Preview {
    BehaviorShiftsView(timeRange: .thisMonth)
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [RitualCompletion.self])
}

