//
//  FocusAnalyticsView.swift
//  Cloutmate
//
//  Insights V2 - Focus Analytics Panel
//

import SwiftUI
import SwiftData
import Charts
import CloutmateShared

struct FocusAnalyticsView: View {
    let snapshot: AnalyticsSnapshot?
    let timeRange: AnalyticsTimeRange
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var focusStats: FocusSessionStats?
    @State private var weeklyTrend: [(Date, Double)] = []
    @State private var flowHeatmap: [[Double]] = []
    @State private var topFocusWindows: [(hour: Int, count: Int)] = []
    
    var body: some View {
        ScrollView {
            contentView
        }
        .task {
            await loadFocusData()
        }
        .onChange(of: timeRange) { _, _ in
            _Concurrency.Task {
                await loadFocusData()
            }
        }
    }
    
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader
            if !weeklyTrend.isEmpty {
                focusGravityChart
            }
            metricsGrid
            if !topFocusWindows.isEmpty {
                topFocusWindowsCard
            }
            if !flowHeatmap.isEmpty {
                flowHeatmapCard
            }
        }
        .padding(.bottom, 40)
    }
    
    private var sectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Focus & Energy")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.kosmicBlue, Color.kosmicPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Your focus patterns and productivity rhythm")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    private var focusGravityChart: some View {
        DashboardTile(accent: .kosmicBlue, padding: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Focus Gravity Trendline")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.primary)
                
                Chart {
                    ForEach(weeklyTrend, id: \.0) { point in
                        LineMark(
                            x: .value("Date", point.0, unit: .day),
                            y: .value("Gravity", point.1)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.kosmicBlue, Color.kosmicPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Date", point.0, unit: .day),
                            y: .value("Gravity", point.1)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.kosmicBlue.opacity(0.3), Color.kosmicPurple.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 1)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month().day(), centered: false)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .frame(height: 200)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var metricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            MetricCard(
                title: "Avg Session",
                value: formatDuration(focusStats?.averageSessionDuration ?? 0),
                icon: "clock.fill",
                color: .kosmicBlue
            )
            .accessibilityLabel("Average session duration, \(formatDuration(focusStats?.averageSessionDuration ?? 0))")
            
            MetricCard(
                title: "Completion",
                value: String(format: "%.0f%%", (snapshot?.focusCompletionRate ?? 0) * 100),
                icon: "checkmark.circle.fill",
                color: .kosmicPurple
            )
            .accessibilityLabel("Focus completion rate, \(Int((snapshot?.focusCompletionRate ?? 0) * 100)) percent")
            
            MetricCard(
                title: "Sessions",
                value: "\(snapshot?.focusSessionsCount ?? 0)",
                icon: "target",
                color: .kosmicGreen
            )
            .accessibilityLabel("Total focus sessions, \(snapshot?.focusSessionsCount ?? 0)")
        }
        .padding(.horizontal, 20)
    }
    
    private var topFocusWindowsCard: some View {
        DashboardTile(accent: .kosmicPurple.opacity(0.85), padding: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Top Focus Windows")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.primary)
                
                VStack(spacing: 12) {
                    ForEach(Array(topFocusWindows.prefix(3).enumerated()), id: \.offset) { index, window in
                        HStack {
                            Text("\(index + 1).")
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .frame(width: 30)
                            
                            Text(formatHour(window.hour))
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(window.count) sessions")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.05))
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var flowHeatmapCard: some View {
        DashboardTile(accent: .kosmicBlue.opacity(0.75), padding: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Flow Heatmap")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Deep work concentration by hour")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                FlowHeatmapView(data: flowHeatmap)
                    .frame(height: 200)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Data Loading
    
    private func loadFocusData() async {
        guard let snapshot = snapshot else { return }
        
        let (startDate, endDate) = timeRange.dateRange
        
        // Load focus sessions
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { session in
                session.startTime >= startDate && session.startTime <= endDate
            },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        
        let sessions = (try? modelContext.fetch(descriptor)) ?? []
        focusStats = FocusSessionStats.calculate(from: sessions)
        
        // Calculate weekly trend (last 7 days)
        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -7, to: end) ?? end
        
        let weeklySessions = sessions.filter { $0.startTime >= start }
        var dailyGravity: [Date: Double] = [:]
        
        for session in weeklySessions {
            let day = calendar.startOfDay(for: session.startTime)
            let gravity = session.completed ? 1.0 : 0.5
            dailyGravity[day, default: 0] += gravity
        }
        
        weeklyTrend = dailyGravity.sorted(by: { $0.key < $1.key })
            .map { ($0.key, $0.value) }
        
        // Calculate top focus windows
        var hourCounts: [Int: Int] = [:]
        for session in sessions.filter({ $0.status == .completed }) {
            let hour = calendar.component(.hour, from: session.startTime)
            hourCounts[hour, default: 0] += 1
        }
        
        topFocusWindows = hourCounts.sorted(by: { $0.value > $1.value })
            .map { (hour: $0.key, count: $0.value) }
        
        // Calculate flow heatmap (24 hours × 7 days)
        flowHeatmap = calculateFlowHeatmap(sessions: sessions)
    }
    
    private func calculateFlowHeatmap(sessions: [FocusSession]) -> [[Double]] {
        let calendar = Calendar.current
        let now = Date()
        var heatmap: [[Double]] = Array(repeating: Array(repeating: 0.0, count: 24), count: 7)
        
        for session in sessions.filter({ $0.status == .completed }) {
            let dayIndex = calendar.component(.weekday, from: session.startTime) - 1
            let hour = calendar.component(.hour, from: session.startTime)
            
            if dayIndex >= 0 && dayIndex < 7 && hour >= 0 && hour < 24 {
                let intensity = min(1.0, session.actualDuration / 3600.0) // Normalize to 1 hour
                heatmap[dayIndex][hour] += intensity
            }
        }
        
        // Normalize values
        let maxValue = heatmap.flatMap { $0 }.max() ?? 1.0
        if maxValue > 0 {
            for i in 0..<7 {
                for j in 0..<24 {
                    heatmap[i][j] = min(1.0, heatmap[i][j] / maxValue)
                }
            }
        }
        
        return heatmap
    }
    
    // MARK: - Helpers
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
    }
    
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("calmModeEnabled") private var calmModeEnabled = false
    
    var body: some View {
        DashboardTile(accent: color.opacity(0.9), padding: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(calmModeEnabled ? color.opacity(0.6) : color)
                
                Text(value)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Flow Heatmap View

struct FlowHeatmapView: View {
    let data: [[Double]]
    @State private var selectedCell: (day: Int, hour: Int)? = nil
    
    var body: some View {
        VStack(spacing: 8) {
            // Hour labels
            HStack(spacing: 0) {
                Text("")
                    .frame(width: 40)
                ForEach(0..<24, id: \.self) { hour in
                    if hour % 6 == 0 {
                        Text("\(hour)")
                            .font(.system(.caption2))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    } else {
                        Spacer()
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            
            // Heatmap grid
            HStack(spacing: 4) {
                // Day labels
                VStack(spacing: 4) {
                    ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                        Text(day)
                            .font(.system(.caption2))
                            .foregroundColor(.secondary)
                            .frame(height: 24)
                    }
                }
                .frame(width: 20)
                
                // Heatmap cells
                ForEach(0..<24, id: \.self) { hour in
                    VStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { day in
                            let intensity = data[safe: day]?[safe: hour] ?? 0.0
                            RoundedRectangle(cornerRadius: 4)
                                .fill(heatmapColor(for: intensity))
                                .frame(width: 20, height: 24)
                                .onTapGesture {
                                    withAnimation(GlassMotion.Easing.spring) {
                                        selectedCell = (day: day, hour: hour)
                                    }
                                    
                                    // Reset selection after animation
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        selectedCell = nil
                                    }
                                }
                                .scaleEffect(selectedCell?.day == day && selectedCell?.hour == hour ? 1.2 : 1.0)
                                .ripple(color: .kosmicBlue)
                        }
                    }
                }
            }
        }
    }
    
    private func heatmapColor(for value: Double) -> Color {
        if value < 0.2 {
            return Color.kosmicBlue.opacity(0.3)
        } else if value < 0.4 {
            return Color.kosmicGreen.opacity(0.5)
        } else if value < 0.6 {
            return Color.yellow.opacity(0.7)
        } else if value < 0.8 {
            return Color.orange.opacity(0.8)
        } else {
            return Color.red
        }
    }
}

// MARK: - Array Safe Access Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    FocusAnalyticsView(
        snapshot: nil,
        timeRange: .thisWeek
    )
    .modelContainer(for: [FocusSession.self])
    .environmentObject(GlassColorSystem())
    .padding()
}

