//
//  CalendarInsightsCard.swift
//  FocusOS
//
//  Aurora Calendar Cognition Layer - Calendar insights card
//

import SwiftUI
import SwiftData
import FocusOSShared

struct CalendarInsightsCard: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @State private var metrics: CalendarMetrics?
    @State private var insights: [String] = []
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.kosmicBlue)
                    
                    Text("Calendar Intelligence")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                    
                    Spacer()
                }
                
                if let metrics = metrics {
                    // Insights text
                    if !insights.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(insights, id: \.self) { insight in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color.kosmicBlue)
                                    
                                    Text(insight)
                                        .font(.system(size: 13, weight: .regular, design: .rounded))
                                        .foregroundStyle(glassColorSystem.textSecondary())
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Color distribution
                    if !metrics.colorDistribution.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Color Distribution")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(glassColorSystem.textSecondary())
                            
                            HStack(spacing: 12) {
                                ForEach(EventColor.allCases, id: \.rawValue) { color in
                                    if let count = metrics.colorDistribution[color.rawValue], count > 0 {
                                        VStack(spacing: 4) {
                                            Circle()
                                                .fill(color.color)
                                                .frame(width: 24, height: 24)
                                            
                                            Text("\(count)")
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundStyle(glassColorSystem.textSecondary())
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    
                    // Urgency score
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Average Urgency")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(glassColorSystem.textSecondary())
                            
                            Spacer()
                            
                            Text(String(format: "%.0f%%", metrics.averageUrgencyScore * 100))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(glassColorSystem.textPrimary())
                        }
                        
                        ProgressView(value: metrics.averageUrgencyScore)
                            .tint(Color.kosmicBlue)
                    }
                    .padding(.top, 8)
                    
                    // Slippage info
                    if metrics.averageSlippageRatio != 1.0 {
                        HStack(spacing: 8) {
                            Image(systemName: metrics.averageSlippageRatio > 1.0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(metrics.averageSlippageRatio > 1.0 ? Color.orange : Color.green)
                            
                            Text(String(format: "Events run %.0f%% %@ planned time",
                                       abs(metrics.averageSlippageRatio - 1.0) * 100,
                                       metrics.averageSlippageRatio > 1.0 ? "over" : "under"))
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundStyle(glassColorSystem.textSecondary())
                        }
                        .padding(.top, 4)
                    }
                    
                    // Triage frequency
                    if metrics.triageFrequency > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.orange)
                            
                            Text("\(metrics.triageFrequency) overloaded day\(metrics.triageFrequency == 1 ? "" : "s") this week")
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundStyle(glassColorSystem.textSecondary())
                        }
                        .padding(.top, 4)
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .padding(20)
        }
        .task {
            loadMetrics()
        }
    }
    
    private func loadMetrics() {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let weekEnd = now
        
        let analytics = AnalyticsEngine.shared
        let loadedMetrics = analytics.getCalendarMetrics(startDate: weekStart, endDate: weekEnd, modelContext: modelContext)
        
        metrics = loadedMetrics
        
        // Generate insights
        var generatedInsights: [String] = []
        
        if loadedMetrics.averageSlippageRatio > 1.25 {
            generatedInsights.append("Your afternoon blocks tend to overrun by \(Int((loadedMetrics.averageSlippageRatio - 1.0) * 100))%")
        }
        
        if let bestWindow = loadedMetrics.bestTimeWindows.first {
            generatedInsights.append("You consistently complete deep work fastest between \(bestWindow.startHour):00–\(bestWindow.endHour):00")
        }
        
        if loadedMetrics.triageFrequency >= 3 {
            generatedInsights.append("This week has \(loadedMetrics.triageFrequency) red blocks; consider redistributing")
        }
        
        insights = generatedInsights
    }
}

