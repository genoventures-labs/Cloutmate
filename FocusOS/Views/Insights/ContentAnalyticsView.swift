//
//  ContentAnalyticsView.swift
//  FocusOS
//
//  Content Analytics View - Full implementation for artifact-based analytics
//

import SwiftUI
import SwiftData
import Charts
import FocusOSShared

struct ContentAnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    let snapshot: AnalyticsSnapshot
    let timeRange: AnalyticsTimeRange
    
    @State private var artifactTrend: [(date: Date, count: Int)] = []
    @State private var formatDistribution: [(format: OutputFormat, count: Int)] = []
    @State private var stateDistribution: [(state: ArtifactState, count: Int)] = []
    @State private var recentArtifacts: [FocusOSShared.Artifact] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Stats
                HStack(spacing: 16) {
                    ContentMetricCard(
                        title: "Total Artifacts",
                        value: "\(artifactTrend.reduce(0) { $0 + $1.count })",
                        subtitle: "created",
                        icon: "doc.text.fill",
                        color: .kosmicBlue
                    )
                    
                    ContentMetricCard(
                        title: "Published",
                        value: "\(stateDistribution.first(where: { $0.state == .final })?.count ?? 0)",
                        subtitle: "final state",
                        icon: "checkmark.circle.fill",
                        color: .kosmicGreen
                    )
                    
                    ContentMetricCard(
                        title: "Formats",
                        value: "\(formatDistribution.count)",
                        subtitle: "types used",
                        icon: "square.stack.3d.up.fill",
                        color: .kosmicPurple
                    )
                }
                .padding(.horizontal)
                
                // Artifact Creation Trend
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Artifact Creation Trend", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.headline)
                        
                        if !artifactTrend.isEmpty {
                            Chart(artifactTrend, id: \.date) { dataPoint in
                                LineMark(
                                    x: .value("Date", dataPoint.date, unit: .day),
                                    y: .value("Count", dataPoint.count)
                                )
                                .foregroundStyle(Color.kosmicBlue)
                                .interpolationMethod(.catmullRom)
                                
                                AreaMark(
                                    x: .value("Date", dataPoint.date, unit: .day),
                                    y: .value("Count", dataPoint.count)
                                )
                                .foregroundStyle(Color.kosmicBlue.opacity(0.2))
                                .interpolationMethod(.catmullRom)
                            }
                            .transaction { $0.animation = nil }
                            .frame(height: 200)
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
                                    AxisValueLabel {
                                        if let count = value.as(Int.self) {
                                            Text("\(count)")
                                        }
                                    }
                                    AxisGridLine()
                                }
                            }
                            .chartXAxis {
                                AxisMarks { value in
                                    AxisValueLabel(format: .dateTime.month().day())
                                    AxisGridLine()
                                }
                            }
                        } else {
                            ContentUnavailableView(
                                "No Trend Data",
                                systemImage: "chart.line.downtrend.xyaxis",
                                description: Text("Create artifacts to see trends")
                            )
                            .frame(height: 200)
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)
                
                // Format Distribution
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Format Distribution", systemImage: "square.stack.3d.up.fill")
                            .font(.headline)
                        
                        if !formatDistribution.isEmpty {
                            Chart(formatDistribution, id: \.format) { data in
                                BarMark(
                                    x: .value("Format", data.format.displayName),
                                    y: .value("Count", data.count)
                                )
                                .foregroundStyle(formatColor(for: data.format))
                                .cornerRadius(8)
                            }
                            .frame(height: 200)
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
                                    AxisValueLabel {
                                        if let count = value.as(Int.self) {
                                            Text("\(count)")
                                        }
                                    }
                                    AxisGridLine()
                                }
                            }
                            .chartXAxis {
                                AxisMarks { _ in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel()
                                }
                            }
                        } else {
                            ContentUnavailableView(
                                "No Format Data",
                                systemImage: "square.stack",
                                description: Text("Create artifacts with different formats")
                            )
                            .frame(height: 200)
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)
                
                // State Distribution
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("State Distribution", systemImage: "circle.grid.2x2.fill")
                            .font(.headline)
                        
                        if !stateDistribution.isEmpty {
                            Chart(stateDistribution, id: \.state) { data in
                                SectorMark(
                                    angle: .value("Count", data.count),
                                    innerRadius: .ratio(0.5),
                                    angularInset: 2
                                )
                                .foregroundStyle(stateColor(for: data.state))
                                .annotation(position: .overlay) {
                                    Text("\(data.count)")
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(height: 250)
                        } else {
                            ContentUnavailableView(
                                "No State Data",
                                systemImage: "circle.grid",
                                description: Text("Create artifacts to see state distribution")
                            )
                            .frame(height: 250)
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)
                
                // Recent Artifacts
                if !recentArtifacts.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Recent Artifacts", systemImage: "clock.fill")
                                .font(.headline)
                            
                            ForEach(recentArtifacts.prefix(10)) { artifact in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(artifact.title.isEmpty ? "Untitled" : artifact.title)
                                            .font(.body)
                                        HStack(spacing: 8) {
                                            Text(artifact.format.displayName)
                                                .font(.caption)
                                                .foregroundColor(formatColor(for: artifact.format))
                                            Text("•")
                                                .foregroundColor(.secondary)
                                            Text(artifact.createdAt, format: .dateTime.month().day())
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    ArtifactStateBadge(state: artifact.artifactState)
                                }
                                .padding(.vertical, 4)
                                
                                if artifact.id != recentArtifacts.prefix(10).last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                }
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
    
    private func loadData() {
        let (startDate, endDate) = timeRange.dateRange
        
        // Load artifacts in date range - fetch all and filter in memory to avoid predicate issues
        let artifactDescriptor = FetchDescriptor<FocusOSShared.Artifact>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        guard let allArtifacts = try? modelContext.fetch(artifactDescriptor) else {
            return
        }
        
        // Filter by date range in memory
        let artifacts = allArtifacts.filter { artifact in
            artifact.createdAt >= startDate && artifact.createdAt <= endDate
        }
        
        // Calculate artifact trend (grouped by day)
        let calendar = Calendar.current
        var trendDict: [Date: Int] = [:]
        for artifact in artifacts {
            let day = calendar.startOfDay(for: artifact.createdAt)
            trendDict[day, default: 0] += 1
        }
        
        artifactTrend = trendDict.map { (date: $0.key, count: $0.value) }
            .sorted { $0.date < $1.date }
        
        // Calculate format distribution
        var formatCounts: [OutputFormat: Int] = [:]
        for artifact in artifacts {
            formatCounts[artifact.format, default: 0] += 1
        }
        
        formatDistribution = formatCounts.map { (format: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
        
        // Calculate state distribution (filter out archived)
        var stateCounts: [ArtifactState: Int] = [:]
        for artifact in artifacts {
            if artifact.artifactState != .archived {
                stateCounts[artifact.artifactState, default: 0] += 1
            }
        }
        
        stateDistribution = stateCounts.map { (state: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
        
        // Get recent artifacts
        recentArtifacts = Array(artifacts.prefix(10))
    }
    
    private func formatColor(for format: OutputFormat) -> Color {
        switch format {
        case .brief: return .kosmicCyan
        case .summary: return .kosmicBlue
        case .reflection: return .kosmicPurple
        case .report: return .kosmicPurple
        case .releaseNote: return .kosmicGreen
        case .lessonLearned: return .orange
        }
    }
    
    private func stateColor(for state: ArtifactState) -> Color {
        switch state {
        case .idea: return .gray
        case .draft: return .kosmicBlue
        case .final: return .kosmicGreen
        case .published: return .kosmicGreen
        case .archived: return .secondary
        }
    }
}

struct ContentMetricCard: View {
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
    ContentAnalyticsView(
        snapshot: AnalyticsSnapshot(
            startDate: Date(),
            endDate: Date(),
            tasksCompleted: 0,
            tasksCreated: 0,
            completionRate: 0,
            avgPriorityScore: 0,
            topPriorityItems: [],
            focusSessionsCount: 0,
            totalFocusMinutes: 0,
            avgSessionLength: 0,
            focusCompletionRate: 0,
            emotionalSnapshot: EmotionalSnapshot(
                primaryEmotion: .calm,
                secondaryEmotion: nil,
                valence: 0.7,
                intensity: 0.7,
                keywords: []
            ),
            emotionalTrend: .stable,
            dominantEmotion: .calm,
            postsPublished: 0,
            draftsCreated: 0,
            avgEngagement: 0,
            topPerformingPosts: [],
            feedbackEventsCount: 0,
            positiveEvents: 0,
            negativeEvents: 0,
            learningScore: 0,
            activeThemes: 0,
            memoryNodes: 0,
            conceptCount: 0,
            graphDensity: 0,
            ritualCompletionRate: 0,
            morningRitualStreak: 0,
            eveningRitualStreak: 0,
            lastWeeklyReview: nil,
            nudgeResponseRate: 0,
            latestForecast: nil,
            driftEventsCount: 0,
            predictionAccuracy: 0,
            toneAdaptations: 0
        ),
        timeRange: .thisWeek
    )
    .modelContainer(for: [FocusOSShared.Artifact.self])
}
