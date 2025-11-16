//
//  FocusModeStatsSidebar.swift
//  Cloutmate
//
//  V2: Stats sidebar for active focus sessions
//

import SwiftUI
import SwiftData
import Charts
import CloutmateShared

struct FocusModeStatsSidebar: View {
    let session: FocusSession
    let sessionLFHistory: [Double]
    let focusGravityTrend: [Double]
    let stabilityIndex: Double
    let emotionalAvg: Double
    let streak: Int
    let completionRate: Double
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Focus Gravity Trend Chart
                DashboardTile(accent: .kosmicBlue) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.kosmicBlue)
                            Text("Focus Gravity Trend")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(glassColorSystem.textPrimary())
                        }
                        
                        if focusGravityTrend.isEmpty {
                            ContentUnavailableView(
                                "No Data Yet",
                                systemImage: "chart.line.downtrend.xyaxis",
                                description: Text("Trend will appear as session progresses")
                            )
                            .frame(height: 120)
                        } else {
                            Chart {
                                ForEach(Array(focusGravityTrend.enumerated()), id: \.offset) { index, value in
                                    LineMark(
                                        x: .value("Time", index),
                                        y: .value("Focus", value)
                                    )
                                    .foregroundStyle(Color.kosmicBlue)
                                    .interpolationMethod(.catmullRom)
                                    
                                    AreaMark(
                                        x: .value("Time", index),
                                        y: .value("Focus", value)
                                    )
                                    .foregroundStyle(Color.kosmicBlue.opacity(0.2))
                                    .interpolationMethod(.catmullRom)
                                }
                            }
                            .frame(height: 120)
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
                                    AxisValueLabel {
                                        if let focus = value.as(Double.self) {
                                            Text(String(format: "%.1f", focus))
                                                .font(.caption2)
                                        }
                                    }
                                    AxisGridLine()
                                }
                            }
                            .chartXAxis(.hidden)
                        }
                    }
                }
                
                // Current Stability Index
                DashboardTile(accent: stabilityColor) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "gauge.with.dots.needle.67percent")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(stabilityColor)
                            Text("Stability Index")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(glassColorSystem.textPrimary())
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(Int(stabilityIndex))")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundStyle(stabilityColor)
                                .contentTransition(.numericText())
                                .animation(reduceMotion ? nil : .spring(duration: 0.3), value: stabilityIndex)
                            
                            Text(stabilityLabel)
                                .font(.caption)
                                .foregroundStyle(glassColorSystem.textSecondary())
                        }
                    }
                }
                
                // Emotional Avg
                DashboardTile(accent: emotionalColor) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(emotionalColor)
                            Text("Emotional Avg")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(glassColorSystem.textPrimary())
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(format: "%.2f", emotionalAvg))
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(emotionalColor)
                                .contentTransition(.numericText())
                            
                            Text(emotionalCategory)
                                .font(.caption)
                                .foregroundStyle(glassColorSystem.textSecondary())
                        }
                    }
                }
                
                // Session Streak + Completion Rate
                DashboardTile(accent: .kosmicPurple) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.kosmicPurple)
                            Text("Session Stats")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(glassColorSystem.textPrimary())
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(streak)")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundStyle(Color.kosmicPurple)
                                    Text("day streak")
                                        .font(.caption)
                                        .foregroundStyle(glassColorSystem.textSecondary())
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(String(format: "%.0f%%", completionRate * 100))
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundStyle(Color.kosmicPurple)
                                    Text("completion")
                                        .font(.caption)
                                        .foregroundStyle(glassColorSystem.textSecondary())
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var stabilityColor: Color {
        if stabilityIndex >= 70 {
            return .kosmicGreen
        } else if stabilityIndex >= 40 {
            return .kosmicBlue
        } else {
            return .red
        }
    }
    
    private var stabilityLabel: String {
        if stabilityIndex >= 70 {
            return "Excellent stability"
        } else if stabilityIndex >= 40 {
            return "Good stability"
        } else {
            return "Needs attention"
        }
    }
    
    private var emotionalColor: Color {
        if emotionalAvg > 0.5 {
            return .kosmicGreen
        } else if emotionalAvg > 0.0 {
            return .kosmicBlue
        } else if emotionalAvg > -0.5 {
            return .kosmicPurple
        } else {
            return .red
        }
    }
    
    private var emotionalCategory: String {
        if emotionalAvg > 0.5 {
            return "Radiant"
        } else if emotionalAvg > 0.0 {
            return "Gentle"
        } else if emotionalAvg > -0.5 {
            return "Neutral"
        } else {
            return "Subtle"
        }
    }
}

#Preview {
    let session = FocusSession(objective: "Test Session", plannedDuration: 1800)
    return FocusModeStatsSidebar(
        session: session,
        sessionLFHistory: [0.2, 0.3, 0.4, 0.5, 0.6],
        focusGravityTrend: [0.7, 0.75, 0.8, 0.85, 0.9],
        stabilityIndex: 75.0,
        emotionalAvg: 0.4,
        streak: 5,
        completionRate: 0.85
    )
    .padding()
    .environmentObject(GlassColorSystem())
}

