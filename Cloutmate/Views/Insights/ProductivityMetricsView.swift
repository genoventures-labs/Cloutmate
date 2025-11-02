//
//  ProductivityMetricsView.swift
//  Cloutmate
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
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Completion Rate Trend
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Task Completion Trend", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.headline)
                        
                        if !productivityTrend.isEmpty {
                            Chart(productivityTrend, id: \.date) { dataPoint in
                                LineMark(
                                    x: .value("Date", dataPoint.date),
                                    y: .value("Rate", dataPoint.completionRate * 100)
                                )
                                .foregroundStyle(Color.kosmicGreen)
                                .interpolationMethod(.catmullRom)
                                
                                AreaMark(
                                    x: .value("Date", dataPoint.date),
                                    y: .value("Rate", dataPoint.completionRate * 100)
                                )
                                .foregroundStyle(Color.kosmicGreen.opacity(0.2))
                                .interpolationMethod(.catmullRom)
                            }
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
                
                // Focus Time Trend
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Focus Time Trend", systemImage: "timer")
                            .font(.headline)
                        
                        if !focusTrend.isEmpty {
                            Chart(focusTrend, id: \.date) { dataPoint in
                                BarMark(
                                    x: .value("Date", dataPoint.date),
                                    y: .value("Minutes", dataPoint.minutes)
                                )
                                .foregroundStyle(Color.kosmicBlue)
                            }
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
                
                // Current Stats
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
                
                // Top Priority Items (CPS)
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
            .padding(.vertical)
        }
        .task {
            loadData()
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

#Preview {
    ProductivityMetricsView(
        snapshot: nil,
        timeRange: .thisWeek
    )
    .modelContainer(for: [FocusSession.self, PriorityScore.self])
}

