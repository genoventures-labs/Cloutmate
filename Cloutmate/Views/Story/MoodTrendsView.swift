//
//  MoodTrendsView.swift
//  Cloutmate
//
//  Mood Trends Visualization - Time-based mood tracking
//

import SwiftUI
import SwiftData
import Charts

struct MoodTrendsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MoodEntry.date, order: .forward) private var allEntries: [MoodEntry]
    
    @State private var timeRange: TimeRange = .month
    @State private var trendAnalysis: MoodTrendAnalysis?
    @State private var isLoading = false
    
    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case quarter = "Quarter"
        case year = "Year"
    }
    
    var filteredEntries: [MoodEntry] {
        let calendar = Calendar.current
        let now = Date()
        let cutoff: Date
        
        switch timeRange {
        case .week:
            cutoff = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            cutoff = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .quarter:
            cutoff = calendar.date(byAdding: .month, value: -3, to: now) ?? now
        case .year:
            cutoff = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        }
        
        return allEntries.filter { $0.date >= cutoff }
    }
    
    var chartData: [(date: Date, valence: Double, mood: MoodType)] {
        filteredEntries.map { entry in
            (date: entry.date, valence: entry.valence, mood: entry.moodType)
        }
    }
    
    var moodDistribution: [(mood: MoodType, count: Int)] {
        let counts = Dictionary(grouping: filteredEntries, by: { $0.moodType })
        return MoodType.allCases.map { mood in
            (mood: mood, count: counts[mood]?.count ?? 0)
        }.filter { $0.count > 0 }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Trend Analysis Card
                if let analysis = trendAnalysis {
                    trendAnalysisCard(analysis: analysis)
                }
                
                // Time-based Chart
                if !chartData.isEmpty {
                    timeBasedChart
                }
                
                // Mood Distribution
                if !moodDistribution.isEmpty {
                    moodDistributionChart
                }
                
                // Mood Entries List
                if !filteredEntries.isEmpty {
                    moodEntriesList
                } else {
                    emptyState
                }
            }
            .padding(24)
        }
        .background(Color(.windowBackgroundColor))
        .task {
            await loadTrendAnalysis()
        }
        .onChange(of: timeRange) { _, _ in
            Task {
                await loadTrendAnalysis()
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mood Trends")
                        .font(.system(size: 28, weight: .bold))
                    
                    Text("Track your emotional patterns over time")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Time range picker
                Picker("Time Range", selection: $timeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
            }
            
            if !filteredEntries.isEmpty {
                Text("\(filteredEntries.count) mood entry\(filteredEntries.count == 1 ? "" : "s")")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func trendAnalysisCard(analysis: MoodTrendAnalysis) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Label("Trend Analysis", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                
                HStack(spacing: 32) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dominant Mood")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            Circle()
                                .fill(moodColor(analysis.dominantMood))
                                .frame(width: 16, height: 16)
                            
                            Text(analysis.dominantMood.rawValue.capitalized)
                                .font(.title3.bold())
                        }
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Trend")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: trendIcon(analysis.trend))
                                .foregroundColor(trendColor(analysis.trend))
                            Text(trendText(analysis.trend))
                                .font(.title3.bold())
                                .foregroundColor(trendColor(analysis.trend))
                        }
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Average Valence")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(String(format: "%.2f", analysis.averageValence))
                            .font(.title3.bold())
                            .foregroundColor(valenceColor(analysis.averageValence))
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Average Intensity")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(String(format: "%.0f%%", analysis.averageIntensity * 100))
                            .font(.title3.bold())
                    }
                }
            }
            .padding()
        }
        .padding(.horizontal)
    }
    
    private var timeBasedChart: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Label("Mood Over Time", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                
                Chart(chartData, id: \.date) { dataPoint in
                    AreaMark(
                        x: .value("Date", dataPoint.date, unit: .day),
                        y: .value("Valence", dataPoint.valence)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [moodColor(dataPoint.mood).opacity(0.3), moodColor(dataPoint.mood).opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    LineMark(
                        x: .value("Date", dataPoint.date, unit: .day),
                        y: .value("Valence", dataPoint.valence)
                    )
                    .foregroundStyle(moodColor(dataPoint.mood))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    PointMark(
                        x: .value("Date", dataPoint.date, unit: .day),
                        y: .value("Valence", dataPoint.valence)
                    )
                    .foregroundStyle(moodColor(dataPoint.mood))
                    .symbolSize(40)
                }
                .chartYScale(domain: -1.0...1.0)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: timeRange == .week ? 1 : timeRange == .month ? 7 : 30)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(String(format: "%.1f", doubleValue))
                            }
                        }
                    }
                }
                .frame(height: 300)
            }
            .padding()
        }
        .padding(.horizontal)
    }
    
    private var moodDistributionChart: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Label("Mood Distribution", systemImage: "chart.pie")
                    .font(.headline)
                
                Chart(moodDistribution, id: \.mood) { item in
                    SectorMark(
                        angle: .value("Count", item.count),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(moodColor(item.mood))
                    .annotation(position: .overlay) {
                        if item.count > 0 {
                            Text("\(item.count)")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                    }
                }
                .frame(height: 250)
                
                // Legend
                HStack(spacing: 16) {
                    ForEach(moodDistribution, id: \.mood) { item in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(moodColor(item.mood))
                                .frame(width: 12, height: 12)
                            Text(item.mood.rawValue.capitalized)
                                .font(.caption)
                            Text("(\(item.count))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
        }
        .padding(.horizontal)
    }
    
    private var moodEntriesList: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Label("Recent Entries", systemImage: "list.bullet")
                    .font(.headline)
                
                ForEach(filteredEntries.suffix(10).reversed(), id: \.id) { entry in
                    MoodEntryRow(entry: entry)
                }
            }
            .padding()
        }
        .padding(.horizontal)
    }
    
    private var emptyState: some View {
        ContentUnavailableView(
            "No Mood Data",
            systemImage: "heart.text.square",
            description: Text("Start logging moods through reflections or journal entries to see trends here.")
        )
        .padding()
    }
    
    private func loadTrendAnalysis() async {
        isLoading = true
        defer { isLoading = false }
        
        let days: Int
        switch timeRange {
        case .week: days = 7
        case .month: days = 30
        case .quarter: days = 90
        case .year: days = 365
        }
        
        let analysis = EmotionalContextEngine.shared.analyzeMoodTrends(
            days: days,
            modelContext: modelContext
        )
        
        await MainActor.run {
            trendAnalysis = analysis
        }
    }
    
    private func moodColor(_ mood: MoodType) -> Color {
        switch mood {
        case .calm: return .kosmicBlue
        case .ambitious: return .kosmicGreen
        case .drained: return .orange
        case .inspired: return .kosmicPurple
        }
    }
    
    private func valenceColor(_ valence: Double) -> Color {
        if valence > 0.3 {
            return .kosmicGreen
        } else if valence < -0.3 {
            return .orange
        } else {
            return .kosmicBlue
        }
    }
    
    private func trendIcon(_ trend: MoodTrend) -> String {
        switch trend {
        case .improving: return "arrow.up.right"
        case .declining: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }
    
    private func trendColor(_ trend: MoodTrend) -> Color {
        switch trend {
        case .improving: return .kosmicGreen
        case .declining: return .orange
        case .stable: return .kosmicBlue
        }
    }
    
    private func trendText(_ trend: MoodTrend) -> String {
        switch trend {
        case .improving: return "Improving"
        case .declining: return "Declining"
        case .stable: return "Stable"
        }
    }
}

// MARK: - Mood Entry Row

struct MoodEntryRow: View {
    let entry: MoodEntry
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(moodColor(entry.moodType))
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.moodType.rawValue.capitalized)
                    .font(.subheadline.bold())
                
                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 8) {
                    Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(entry.source)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2f", entry.valence))
                    .font(.caption.bold())
                    .foregroundColor(valenceColor(entry.valence))
                
                Text(String(format: "%.0f%%", entry.intensity * 100))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func moodColor(_ mood: MoodType) -> Color {
        switch mood {
        case .calm: return .kosmicBlue
        case .ambitious: return .kosmicGreen
        case .drained: return .orange
        case .inspired: return .kosmicPurple
        }
    }
    
    private func valenceColor(_ valence: Double) -> Color {
        if valence > 0.3 {
            return .kosmicGreen
        } else if valence < -0.3 {
            return .orange
        } else {
            return .kosmicBlue
        }
    }
}

#Preview {
    MoodTrendsView()
        .modelContainer(for: [MoodEntry.self], inMemory: true)
}

