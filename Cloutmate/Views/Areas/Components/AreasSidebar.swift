//
//  AreasSidebar.swift
//  Cloutmate
//
//  Areas V2 - Stability overview sidebar
//

import SwiftUI
import SwiftData
import Charts
import CloutmateShared

struct AreasSidebar: View {
    let areas: [Area]
    let onAreaSelected: (Area) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var isStabilityExpanded = true
    @State private var isTrendExpanded = true
    @State private var isReviewExpanded = true
    @State private var overallStability: Double = 0.0
    @State private var focusGravityTrend: [(Date, Double)] = []
    @State private var auroraInsight: String = ""
    
    var areasNeedingReview: [Area] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return areas.filter { area in
            area.status == .reviewNeeded ||
            (area.lastReviewDate == nil || area.lastReviewDate! < sevenDaysAgo)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Overall Stability Index
                DashboardTile(accent: stabilityColor) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "gauge.with.dots.needle.67percent")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(stabilityColor)
                            Text("Overall Stability Index")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(glassColorSystem.textPrimary())
                            Spacer()
                            Button(action: {
                                withAnimation(reduceMotion ? nil : GlassMotion.Easing.spring) {
                                    isStabilityExpanded.toggle()
                                }
                            }) {
                                Image(systemName: isStabilityExpanded ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(glassColorSystem.textSecondary())
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if isStabilityExpanded {
                    VStack(spacing: 12) {
                        Text("\(Int(overallStability))")
                            .font(.system(size: 48, weight: .bold))
                                    .foregroundStyle(stabilityColor)
                            .contentTransition(.numericText())
                            .animation(reduceMotion ? nil : .spring(duration: 0.3), value: overallStability)
                        
                        Text("Stability Score")
                            .font(.caption)
                                    .foregroundStyle(glassColorSystem.textSecondary())
                        
                        if overallStability >= 70 {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.circle.fill")
                                            .foregroundStyle(.kosmicGreen)
                                Text("Trending positive")
                                    .font(.caption)
                                            .foregroundStyle(.kosmicGreen)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                    }
                }
                .accessibilityLabel("Overall Stability Index: \(Int(overallStability))")
                .accessibilityHint("Double tap to expand or collapse")
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                
                // Focus Gravity Trend Chart
                DashboardTile(accent: .kosmicBlue) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.kosmicBlue)
                            Text("Focus Gravity Trend")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(glassColorSystem.textPrimary())
                            Spacer()
                            Button(action: {
                                withAnimation(reduceMotion ? nil : GlassMotion.Easing.spring) {
                                    isTrendExpanded.toggle()
                                }
                            }) {
                                Image(systemName: isTrendExpanded ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(glassColorSystem.textSecondary())
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if isTrendExpanded {
                    if focusGravityTrend.isEmpty {
                        ContentUnavailableView(
                            "No Trend Data",
                            systemImage: "chart.line.downtrend.xyaxis",
                            description: Text("Link projects to areas to see trends")
                        )
                        .frame(height: 150)
                    } else {
                        Chart(focusGravityTrend, id: \.0) { dataPoint in
                            LineMark(
                                x: .value("Date", dataPoint.0, unit: .day),
                                y: .value("Focus", dataPoint.1)
                            )
                            .foregroundStyle(Color.kosmicBlue)
                            .interpolationMethod(.catmullRom)
                            
                            AreaMark(
                                x: .value("Date", dataPoint.0, unit: .day),
                                y: .value("Focus", dataPoint.1)
                            )
                            .foregroundStyle(Color.kosmicBlue.opacity(0.2))
                            .interpolationMethod(.catmullRom)
                        }
                        .transaction { $0.animation = nil }
                        .frame(height: 150)
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisValueLabel {
                                    if let focus = value.as(Double.self) {
                                        Text(String(format: "%.1f", focus))
                                    }
                                }
                                AxisGridLine()
                            }
                        }
                    }
                }
                    }
                }
                
                // Areas Needing Review
                DashboardTile(accent: .red) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.red)
                            Text("Areas Needing Review")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(glassColorSystem.textPrimary())
                            Spacer()
                            Button(action: {
                                withAnimation(reduceMotion ? nil : GlassMotion.Easing.spring) {
                                    isReviewExpanded.toggle()
                                }
                            }) {
                                Image(systemName: isReviewExpanded ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(glassColorSystem.textSecondary())
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if isReviewExpanded {
                    if areasNeedingReview.isEmpty {
                        Text("All areas are up to date")
                            .font(.caption)
                                    .foregroundStyle(glassColorSystem.textTertiary())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(areasNeedingReview.prefix(5)) { area in
                                Button(action: {
                                    onAreaSelected(area)
                                }) {
                                    HStack {
                                        Text(area.title)
                                            .font(.body)
                                                    .foregroundStyle(glassColorSystem.textPrimary())
                                            .lineLimit(1)
                                        
                                        Spacer()
                                        
                                        if let lastReview = area.lastReviewDate {
                                            Text(lastReview, style: .relative)
                                                .font(.caption2)
                                                        .foregroundStyle(glassColorSystem.textTertiary())
                                        } else {
                                            Text("Never")
                                                .font(.caption2)
                                                        .foregroundStyle(.red)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if areasNeedingReview.count > 5 {
                                Text("+\(areasNeedingReview.count - 5) more")
                                    .font(.caption)
                                            .foregroundStyle(glassColorSystem.textTertiary())
                                    .padding(.top, 4)
                            }
                        }
                    }
                }
                    }
                }
                
                // Aurora Insight Card
                if !auroraInsight.isEmpty {
                    DashboardTile(accent: .kosmicPurple) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(Color.kosmicPurple)
                                Text("Aurora Insight")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(glassColorSystem.textPrimary())
                            }
                            
                            Text(auroraInsight)
                                .font(.body)
                                .foregroundStyle(glassColorSystem.textSecondary())
                        }
                    }
                }
            }
        }
        .task {
            await updateStabilityMetrics()
            loadAuroraInsight()
        }
    }
    
    var stabilityColor: Color {
        if overallStability >= 70 {
            return .kosmicGreen
        } else if overallStability >= 40 {
            return .kosmicBlue
        } else {
            return .red
        }
    }
    
    @MainActor
    private func updateStabilityMetrics() async {
        // Safely calculate stability metrics with error handling
        do {
            // Verify modelContext is accessible by attempting a simple fetch
            let testDescriptor = FetchDescriptor<Area>()
            _ = try modelContext.fetch(testDescriptor)
            
            // Calculate overall stability (average of all areas)
            let scores = areas.map { area in
                AreaStabilityService.shared.stabilityScore(for: area, modelContext: modelContext)
            }
            overallStability = scores.isEmpty ? 0.0 : scores.reduce(0.0, +) / Double(scores.count)
            
            // Aggregate Focus Gravity trend from all areas
            var aggregatedTrend: [Date: [Double]] = [:]
            for area in areas {
                let trend = AreaStabilityService.shared.focusGravityTrend(for: area, days: 30, modelContext: modelContext)
                for (date, value) in trend {
                    if aggregatedTrend[date] == nil {
                        aggregatedTrend[date] = []
                    }
                    aggregatedTrend[date]?.append(value)
                }
            }
            
            // Average values per date
            let calendar = Calendar.current
            let now = Date()
            var result: [(Date, Double)] = []
            
            for i in 0..<30 {
                guard let date = calendar.date(byAdding: .day, value: -i, to: now) else { continue }
                let dayStart = calendar.startOfDay(for: date)
                
                if let values = aggregatedTrend[dayStart], !values.isEmpty {
                    let average = values.reduce(0.0, +) / Double(values.count)
                    result.append((dayStart, average))
                } else {
                    result.append((dayStart, 0.0))
                }
            }
            
            focusGravityTrend = result.reversed()
        } catch {
            // If modelContext is invalid, use default values
            overallStability = 50.0
            focusGravityTrend = []
        }
    }
    
    private func loadAuroraInsight() {
        // Placeholder - will be integrated with AuroraPredictiveService
        if areasNeedingReview.isEmpty {
            auroraInsight = "Your areas show stable energy. All domains are up to date."
        } else {
            auroraInsight = "\(areasNeedingReview.count) area\(areasNeedingReview.count == 1 ? "" : "s") need\(areasNeedingReview.count == 1 ? "s" : "") review. Consider scheduling time to update them."
        }
    }
}

#Preview {
    AreasSidebar(
        areas: [],
        onAreaSelected: { _ in }
    )
    .environmentObject(GlassColorSystem())
}

