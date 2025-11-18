//
//  EmotionAnalyticsView.swift
//  FocusOS
//
//  Insights V2 - Emotional Continuity Panel
//

import SwiftUI
import SwiftData
import Charts
import FocusOSShared

struct EmotionAnalyticsView: View {
    let snapshot: AnalyticsSnapshot?
    let timeRange: AnalyticsTimeRange
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var themeManager = ReactiveThemeManager.shared
    
    @State private var moodWeights: [EmotionalState: Double] = [:]
    @State private var dailySentiment: [(Date, Double)] = []
    @State private var reflectionCount: Int = 0
    @State private var auroraComment: String = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Section Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Emotional & Reflective")
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.kosmicPurple, Color.kosmicGreen],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("Your emotional landscape over time")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Mood Distribution Wheel
                if !moodWeights.isEmpty {
                    DashboardTile(accent: .kosmicPurple.opacity(0.85), padding: 24) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Mood Distribution")
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.primary)
                            
                            MoodDistributionWheel(weights: moodWeights)
                                .frame(height: 200)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Weekly Sentiment Arc
                if !dailySentiment.isEmpty {
                    DashboardTile(accent: .kosmicGreen.opacity(0.75), padding: 24) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Weekly Sentiment Arc")
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Chart {
                                ForEach(dailySentiment, id: \.0) { point in
                                    LineMark(
                                        x: .value("Date", point.0, unit: .day),
                                        y: .value("Sentiment", point.1)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.kosmicPurple, Color.kosmicGreen],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .interpolationMethod(.catmullRom)
                                    
                                    AreaMark(
                                        x: .value("Date", point.0, unit: .day),
                                        y: .value("Sentiment", point.1)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.kosmicPurple.opacity(0.3), Color.kosmicGreen.opacity(0.1)],
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
                            .frame(height: 180)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Reflection Frequency
                DashboardTile(accent: .kosmicPurple.opacity(0.8), padding: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "book.fill")
                                .foregroundColor(.kosmicPurple)
                            Text("Reflection Frequency")
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        
                        Text("\(reflectionCount) entries")
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("Journal + Ritual entries")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                
                // Aurora's Comment Card
                if !auroraComment.isEmpty {
                    DashboardTile(accent: .kosmicPurple.opacity(0.9), padding: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.kosmicPurple)
                                Text("Aurora's Reflection")
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                            
                            Text(auroraComment)
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 40)
        }
        .task {
            await loadEmotionData()
        }
        .onChange(of: timeRange) { _, _ in
            _Concurrency.Task {
                await loadEmotionData()
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadEmotionData() async {
        guard let snapshot = snapshot else { return }
        
        let (startDate, endDate) = timeRange.dateRange
        
        // Load state transitions for mood weights
        let transitionDescriptor = FetchDescriptor<StateTransitionHistory>(
            predicate: #Predicate { transition in
                transition.timestamp >= startDate && transition.timestamp <= endDate
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        let transitions = (try? modelContext.fetch(transitionDescriptor)) ?? []
        
        // Calculate mood weights
        var stateCounts: [EmotionalState: Int] = [:]
        for transition in transitions {
            stateCounts[transition.toState, default: 0] += 1
        }
        
        let total = stateCounts.values.reduce(0, +)
        if total > 0 {
            moodWeights = Dictionary(uniqueKeysWithValues: stateCounts.map { ($0.key, Double($0.value) / Double(total)) })
        } else {
            // Default weights if no transitions
            moodWeights = [
                .calm: 0.4,
                .focused: 0.3,
                .energized: 0.15,
                .reflective: 0.1,
                .fatigued: 0.05
            ]
        }
        
        // Calculate daily sentiment
        let calendar = Calendar.current
        var dailyValence: [Date: [Double]] = [:]
        
        for transition in transitions {
            let day = calendar.startOfDay(for: transition.timestamp)
            dailyValence[day, default: []].append(transition.emotionalValence)
        }
        
        dailySentiment = dailyValence.sorted(by: { $0.key < $1.key })
            .map { (date, values) in
                let avg = values.reduce(0, +) / Double(values.count)
                return (date, avg)
            }
        
        // Count reflection entries (RitualCompletion + any Journal entries if they exist)
        let ritualDescriptor = FetchDescriptor<RitualCompletion>(
            predicate: #Predicate { completion in
                completion.completedAt >= startDate && completion.completedAt <= endDate
            }
        )
        
        let ritualCompletions = (try? modelContext.fetch(ritualDescriptor)) ?? []
        reflectionCount = ritualCompletions.count
        
        // Generate Aurora comment using emotion + focus pairing
        let focusStats = await getFocusStats(startDate: startDate, endDate: endDate)
        auroraComment = AuroraInsightGenerator.shared.generateEmotionFocusInsight(
            snapshot: snapshot,
            focusStats: focusStats,
            modelContext: modelContext
        )
    }
    
    private func getFocusStats(startDate: Date, endDate: Date) async -> FocusSessionStats? {
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { session in
                session.startTime >= startDate && session.startTime <= endDate
            }
        )
        
        let sessions = (try? modelContext.fetch(descriptor)) ?? []
        return FocusSessionStats.calculate(from: sessions)
    }
}

// MARK: - Mood Distribution Wheel

struct MoodDistributionWheel: View {
    let weights: [EmotionalState: Double]
    
    private var sortedWeights: [(state: EmotionalState, weight: Double)] {
        weights.sorted(by: { $0.value > $1.value })
            .map { (state: $0.key, weight: $0.value) }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2 - 20
            
            ZStack {
                ForEach(Array(sortedWeights.enumerated()), id: \.offset) { index, item in
                    let startAngle = cumulativeAngle(before: index)
                    let endAngle = startAngle + (item.weight * 2 * .pi)
                    
                    PieSlice(
                        center: center,
                        radius: radius,
                        startAngle: startAngle,
                        endAngle: endAngle
                    )
                    .fill(colorForState(item.state))
                    
                    // Label
                    if item.weight > 0.1 {
                        let labelAngle = startAngle + (endAngle - startAngle) / 2
                        let labelRadius = radius * 0.7
                        let labelX = center.x + cos(labelAngle) * labelRadius
                        let labelY = center.y + sin(labelAngle) * labelRadius
                        
                        Text(item.state.displayName)
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .position(x: labelX, y: labelY)
                    }
                }
            }
        }
    }
    
    private func cumulativeAngle(before index: Int) -> Double {
        var angle: Double = -(.pi / 2) // Start at top
        for i in 0..<index {
            angle += sortedWeights[i].weight * 2 * .pi
        }
        return angle
    }
    
    private func colorForState(_ state: EmotionalState) -> Color {
        switch state {
        case .calm:
            return .kosmicGreen
        case .focused:
            return .kosmicBlue
        case .energized:
            return .kosmicPurple
        case .reflective:
            return Color(red: 0.6, green: 0.4, blue: 0.9) // Purple variant
        case .fatigued:
            return Color(red: 0.7, green: 0.7, blue: 0.7) // Gray
        }
    }
}

// MARK: - Pie Slice Shape

struct PieSlice: Shape {
    let center: CGPoint
    let radius: CGFloat
    let startAngle: Double
    let endAngle: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .radians(startAngle),
            endAngle: .radians(endAngle),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}


#Preview {
    EmotionAnalyticsView(
        snapshot: nil,
        timeRange: .thisWeek
    )
    .modelContainer(for: [StateTransitionHistory.self, RitualCompletion.self, FocusSession.self])
    .environmentObject(GlassColorSystem())
    .environmentObject(ReactiveThemeManager.shared)
    .padding()
}

