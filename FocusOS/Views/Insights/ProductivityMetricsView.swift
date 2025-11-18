//
//  ProductivityMetricsView.swift
//  FocusOS
//
//  Phase 6.1 - Productivity Metrics & CPS Trends
//

import SwiftUI
import SwiftData
import Charts

struct ProductivityMetricsView: View {
    @Environment(\.modelContext) private var modelContext
    let snapshot: AnalyticsSnapshot?
    let timeRange: AnalyticsTimeRange
    
    @State private var productivityTrend: [(date: Date, completionRate: Double)] = []
    @State private var focusTrend: [(date: Date, minutes: Int)] = []
    @State private var topPriorityItems: [PriorityItem] = []
    @State private var focusDistribution: FocusEnergyProfile?
    @State private var focusGravityTrend: [(date: Date, cognitive: Double, creative: Double, completion: Double)] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                completionRateTrendSection
                focusTimeTrendSection
                currentStatsSection
                topPriorityItemsSection
                focusGravityDistributionSection
            }
            .padding(.vertical)
        }
        .task {
            loadData()
        }
        .onChange(of: timeRange) { _ in
            loadData()
        }
    }
    
    // MARK: - Sections
    
    private var completionRateTrendSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Label("Task Completion Trend", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                
                if !productivityTrend.isEmpty {
                    Chart(productivityTrend, id: \.date) { dataPoint in
                        LineMark(
                            x: .value("Date", dataPoint.date, unit: .day),
                            y: .value("Rate", dataPoint.completionRate * 100)
                        )
                        .foregroundStyle(Color.kosmicGreen)
                        
                        AreaMark(
                            x: .value("Date", dataPoint.date, unit: .day),
                            y: .value("Rate", dataPoint.completionRate * 100)
                        )
                        .foregroundStyle(Color.kosmicGreen.opacity(0.2))
                    }
                    .transaction { $0.animation = nil }
                    .frame(height: 200)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let rate = value.as(Double.self) {
                                    Text("\(Int(rate))%")
                                }
                            }
                            AxisGridLine()
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No Trend Data",
                        systemImage: "chart.line.downtrend.xyaxis",
                        description: Text("Complete tasks to see trends")
                    )
                    .frame(height: 200)
                }
            }
            .padding()
        }
        .padding(.horizontal)
    }
    
    private var focusTimeTrendSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Label("Focus Time Trend", systemImage: "timer")
                    .font(.headline)
                
                if !focusTrend.isEmpty {
                    Chart(focusTrend, id: \.date) { dataPoint in
                        BarMark(
                            x: .value("Date", dataPoint.date, unit: .day),
                            y: .value("Minutes", dataPoint.minutes)
                        )
                        .foregroundStyle(Color.kosmicBlue)
                    }
                    .transaction { $0.animation = nil }
                    .frame(height: 200)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let minutes = value.as(Int.self) {
                                    Text("\(minutes)m")
                                }
                            }
                            AxisGridLine()
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No Focus Data",
                        systemImage: "timer.square",
                        description: Text("Start focus sessions to track time")
                    )
                    .frame(height: 200)
                }
            }
            .padding()
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var currentStatsSection: some View {
        if let snapshot = snapshot {
            HStack(spacing: 16) {
                ProductivityMetricCard(
                    title: "Tasks Completed",
                    value: "\(snapshot.tasksCompleted)",
                    subtitle: "out of \(snapshot.tasksCreated) created",
                    icon: "checkmark.circle.fill",
                    color: .kosmicGreen
                )
                
                ProductivityMetricCard(
                    title: "Avg Priority Score",
                    value: String(format: "%.2f", snapshot.avgPriorityScore),
                    subtitle: "CPS average",
                    icon: "star.fill",
                    color: .yellow
                )
                
                ProductivityMetricCard(
                    title: "Focus Sessions",
                    value: "\(snapshot.focusSessionsCount)",
                    subtitle: String(format: "%.1fm avg", snapshot.avgSessionLength),
                    icon: "flame.fill",
                    color: .orange
                )
            }
            .padding(.horizontal)
        }
    }
    
    private var topPriorityItemsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Top Priority Items (CPS)", systemImage: "star.fill")
                    .font(.headline)
                
                if !topPriorityItems.isEmpty {
                    ForEach(topPriorityItems.prefix(10)) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.body)
                                Text(item.objectType)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(String(format: "%.2f", item.score))
                                .font(.headline)
                                .foregroundColor(.kosmicBlue)
                        }
                        .padding(.vertical, 4)
                        
                        if item.id != topPriorityItems.prefix(10).last?.id {
                            Divider()
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No Priority Data",
                        systemImage: "star",
                        description: Text("Create tasks and notes to see priority rankings")
                    )
                }
            }
            .padding()
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var focusGravityDistributionSection: some View {
        if let distribution = focusDistribution {
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Focus Gravity Distribution", systemImage: "sparkles")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 20) {
                            FocusDistributionItem(
                                label: "Cognitive",
                                value: distribution.cognitive,
                                color: .kosmicBlue
                            )
                            FocusDistributionItem(
                                label: "Creative",
                                value: distribution.creative,
                                color: .kosmicPurple
                            )
                            FocusDistributionItem(
                                label: "Completion",
                                value: distribution.completion,
                                color: .kosmicGreen
                            )
                        }
                        
                        Text("Dominant: \(distribution.dominantType.displayName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !focusGravityTrend.isEmpty {
                        focusGravityChart
                    }
                }
                .padding()
            }
            .padding(.horizontal)
        }
    }
    
    private var focusGravityChart: some View {
        Chart {
            ForEach(Array(focusGravityTrend.enumerated()), id: \.offset) { index, data in
                BarMark(
                    x: .value("Day", dayLabel(for: data.date)),
                    y: .value("Cognitive", data.cognitive * 100)
                )
                .foregroundStyle(Color.kosmicBlue)
                
                BarMark(
                    x: .value("Day", dayLabel(for: data.date)),
                    y: .value("Creative", data.creative * 100)
                )
                .foregroundStyle(Color.kosmicPurple)
                
                BarMark(
                    x: .value("Day", dayLabel(for: data.date)),
                    y: .value("Completion", data.completion * 100)
                )
                .foregroundStyle(Color.kosmicGreen)
            }
        }
        .frame(height: 150)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let intValue = value.as(Double.self) {
                        Text("\(Int(intValue))%")
                            .font(.caption2)
                    }
                }
            }
        }
    }
    
    private func loadData() {
        // Load productivity trend
        let days = timeRange == .thisWeek ? 7 : 30
        productivityTrend = AnalyticsEngine.shared.getProductivityTrend(
            days: days,
            modelContext: modelContext
        )
        
        // Load focus trend
        focusTrend = AnalyticsEngine.shared.getFocusTrend(
            days: days,
            modelContext: modelContext
        )
        
        // Load top priority items (get all top items)
        topPriorityItems = PriorityEngine.shared.getTopObjects(
            limit: 20,
            modelContext: modelContext
        )
        
        // Load Focus Gravity V2 data
        let entities = FocusGravityService.shared.fetchFocusEntities(
            timeScope: timeRange == .thisWeek ? .week : .month,
            filter: .all,
            modelContext: modelContext
        )
        focusDistribution = FocusGravityService.shared.getFocusDistribution(entities: entities)
        focusGravityTrend = FocusGravityService.shared.getWeeklyTrend(modelContext: modelContext)
    }
    
    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

struct ProductivityMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title.bold())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct FocusDistributionItem: View {
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(Int(value * 100))%")
                .font(.headline)
                .foregroundColor(color)
        }
    }
}

#Preview {
    ProductivityMetricsView(
        snapshot: nil,
        timeRange: .thisWeek
    )
    .modelContainer(for: [FocusSession.self, PriorityScore.self])
}

