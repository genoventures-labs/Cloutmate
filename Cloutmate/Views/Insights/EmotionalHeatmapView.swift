//
//  EmotionalHeatmapView.swift
//  Cloutmate
//
//  Phase 6.1 - Emotional Continuity Visualization
//

import SwiftUI
import SwiftData
import Charts

struct EmotionalHeatmapView: View {
    @Environment(\.modelContext) private var modelContext
    let snapshot: AnalyticsSnapshot?
    let timeRange: AnalyticsTimeRange
    
    @State private var emotionalTrend: [(date: Date, valence: Double, emotion: EmotionType)] = []
    @State private var selectedDate: Date?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Current Emotional State
                if let snapshot = snapshot {
                    GroupBox {
                        if hasMeaningfulSnapshot(snapshot) {
                            VStack(spacing: 16) {
                                Label("Current Emotional State", systemImage: "heart.text.square")
                                    .font(.headline)
                                
                                HStack(spacing: 32) {
                                    VStack {
                                        Image(systemName: emotionIcon(snapshot.dominantEmotion))
                                            .font(.system(size: 60))
                                            .foregroundColor(emotionColor(snapshot.dominantEmotion))
                                        
                                        Text(snapshot.dominantEmotion.rawValue.capitalized)
                                            .font(.title2.bold())
                                    }
                                    
                                    Divider()
                                    
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Text("Trend:")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            Text(snapshot.emotionalTrend.rawValue.capitalized)
                                                .font(.subheadline.bold())
                                                .foregroundColor(trendColor(snapshot.emotionalTrend))
                                        }
                                        
                                        HStack {
                                            Text("Valence:")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            Text(String(format: "%.2f", snapshot.emotionalSnapshot.valence))
                                                .font(.subheadline.bold())
                                        }
                                        
                                        HStack {
                                            Text("Intensity:")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            Text(String(format: "%.1f%%", snapshot.emotionalSnapshot.intensity * 100))
                                                .font(.subheadline.bold())
                                        }
                                    }
                                }
                                .padding()
                            }
                            .padding()
                        } else {
                            ContentUnavailableView(
                                "No Emotional Signals",
                                systemImage: "heart.slash",
                                description: Text("Chat with Aurora or log reflections to see your current emotional state.")
                            )
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Emotional Trend Chart
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Emotional Valence Over Time", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.headline)
                        
                        if !emotionalTrend.isEmpty && hasMeaningfulTrend {
                            Chart(emotionalTrend, id: \.date) { dataPoint in
                                LineMark(
                                    x: .value("Date", dataPoint.date, unit: .day),
                                    y: .value("Valence", dataPoint.valence)
                                )
                                .foregroundStyle(valenceColor(dataPoint.valence))
                                
                                PointMark(
                                    x: .value("Date", dataPoint.date, unit: .day),
                                    y: .value("Valence", dataPoint.valence)
                                )
                                .foregroundStyle(emotionColor(dataPoint.emotion))
                                .symbolSize(80)
                            }
                            .transaction { $0.animation = nil }
                            .frame(height: 250)
                            .chartYScale(domain: -1...1)
                            .chartYAxis {
                                AxisMarks(position: .leading, values: [-1, -0.5, 0, 0.5, 1]) { value in
                                    AxisValueLabel {
                                        if let valence = value.as(Double.self) {
                                            Text(valenceLabel(valence))
                                        }
                                    }
                                    AxisGridLine()
                                }
                            }
                        } else {
                            ContentUnavailableView(
                                "No Emotional Data",
                                systemImage: "heart.slash",
                                description: Text("Chat with Aurora to track emotional continuity")
                            )
                            .frame(height: 250)
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)
                
                // Emotion Distribution
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Emotion Distribution", systemImage: "chart.pie")
                            .font(.headline)
                        
                        if !emotionalTrend.isEmpty && hasMeaningfulTrend {
                            let emotionCounts = Dictionary(grouping: emotionalTrend, by: { $0.emotion })
                                .mapValues { $0.count }
                                .sorted { $0.value > $1.value }
                            
                            ForEach(emotionCounts, id: \.key) { emotion, count in
                                HStack {
                                    Image(systemName: emotionIcon(emotion))
                                        .foregroundColor(emotionColor(emotion))
                                    
                                    Text(emotion.rawValue.capitalized)
                                        .font(.body)
                                    
                                    Spacer()
                                    
                                    Text("\(count) days")
                                        .font(.body.bold())
                                        .foregroundColor(.secondary)
                                    
                                    // Percentage bar
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(emotionColor(emotion).opacity(0.3))
                                        .frame(width: emotionBarWidth(for: count), height: 8)
                                        .frame(width: 100, alignment: .leading)
                                }
                                .padding(.vertical, 4)
                                
                                if emotion != emotionCounts.last?.key {
                                    Divider()
                                }
                            }
                        } else {
                            ContentUnavailableView(
                                "No Emotion Distribution",
                                systemImage: "chart.pie",
                                description: Text("Keep interacting with Aurora to build richer emotional data.")
                            )
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)
                
                // Calendar Heatmap
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Emotional Calendar", systemImage: "calendar")
                            .font(.headline)
                        
                        if hasMeaningfulTrend {
                            EmotionalCalendarView(emotionalData: emotionalTrend)
                        } else {
                            ContentUnavailableView(
                                "No Emotional Timeline",
                                systemImage: "calendar",
                                description: Text("Once emotional data is captured, your monthly heatmap will appear here.")
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
            // Backfill emotional data on first load
            await AnalyticsEngine.shared.backfillEmotionalData(modelContext: modelContext)
            loadData()
        }
        .onChange(of: timeRange) { _ in
            loadData()
        }
    }
    
    private func loadData() {
        let days = timeRange == .thisWeek ? 7 : (timeRange == .thisMonth ? 30 : 90)
        emotionalTrend = AnalyticsEngine.shared.getEmotionalTrend(
            days: days,
            modelContext: modelContext
        )
    }
    
    // MARK: - Helper Functions
    
    private func emotionIcon(_ emotion: EmotionType) -> String {
        switch emotion {
        case .joyful: return "face.smiling.fill"
        case .excited: return "sparkles"
        case .calm: return "wind"
        case .neutral: return "minus.circle"
        case .frustrated: return "exclamationmark.triangle.fill"
        case .anxious: return "bolt.fill"
        default: return "circle"
        }
    }
    
    private func emotionColor(_ emotion: EmotionType) -> Color {
        switch emotion {
        case .joyful, .excited: return .kosmicGreen
        case .calm: return .kosmicBlue
        case .neutral: return .gray
        case .frustrated: return .orange
        case .anxious: return .red
        default: return .gray
        }
    }
    
    private func valenceColor(_ valence: Double) -> Color {
        if valence > 0.5 { return .kosmicGreen }
        if valence > 0 { return .kosmicBlue }
        if valence > -0.5 { return .orange }
        return .red
    }
    
    private func valenceLabel(_ valence: Double) -> String {
        if valence > 0.5 { return "Very Positive" }
        if valence > 0 { return "Positive" }
        if valence == 0 { return "Neutral" }
        if valence > -0.5 { return "Negative" }
        return "Very Negative"
    }
    
    private func trendColor(_ trend: EmotionalTrend) -> Color {
        switch trend {
        case .improving: return .kosmicGreen
        case .stable: return .kosmicBlue
        case .declining: return .orange
        case .volatile: return .kosmicPurple
        }
    }

    private func emotionBarWidth(for count: Int) -> CGFloat {
        guard !emotionalTrend.isEmpty else { return 0 }
        let ratio = max(0, min(1, Double(count) / Double(emotionalTrend.count)))
        return CGFloat(ratio) * 100
    }

    private var hasMeaningfulTrend: Bool {
        !emotionalTrend.isEmpty // Show data if we have any data points
    }

    private func hasMeaningfulSnapshot(_ snapshot: AnalyticsSnapshot) -> Bool {
        // Show snapshot if we have any emotional data, even if neutral
        true // Always show if snapshot exists
    }
}

// MARK: - Emotional Calendar View

struct EmotionalCalendarView: View {
    let emotionalData: [(date: Date, valence: Double, emotion: EmotionType)]
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Day labels
            HStack {
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(calendarDays, id: \.self) { date in
                    if let emotion = emotionForDate(date) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(emotionColor(emotion.emotion))
                            .frame(height: 40)
                            .overlay(
                                Text("\(calendar.component(.day, from: date))")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 40)
                            .overlay(
                                Text("\(calendar.component(.day, from: date))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            )
                    }
                }
            }
        }
    }
    
    private var calendarDays: [Date] {
        guard let firstDate = emotionalData.first?.date else { return [] }
        
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: firstDate))!
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!
        
        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
    }
    
    private func emotionForDate(_ date: Date) -> (date: Date, valence: Double, emotion: EmotionType)? {
        emotionalData.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    private func emotionColor(_ emotion: EmotionType) -> Color {
        switch emotion {
        case .joyful, .excited: return .kosmicGreen
        case .calm: return .kosmicBlue
        case .neutral: return .gray
        case .frustrated: return .orange
        case .anxious: return .red
        default: return .gray
        }
    }
}

#Preview {
    EmotionalHeatmapView(
        snapshot: nil,
        timeRange: .thisWeek
    )
    .modelContainer(for: [AIConversation.self])
}

