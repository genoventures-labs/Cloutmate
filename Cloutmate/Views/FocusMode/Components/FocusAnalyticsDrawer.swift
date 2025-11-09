//
//  FocusAnalyticsDrawer.swift
//  Cloutmate
//
//  Focus Mode V2 - Analytics & Review Drawer
//

import SwiftUI
import SwiftData
import Charts
import CloutmateShared

struct FocusAnalyticsDrawer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var dailyStats: FocusSessionStats?
    @State private var weeklyStats: FocusSessionStats?
    @State private var topDomains: [(String, Int)] = []
    @State private var calmChaosRatio: Double = 0.5
    @State private var streakTimeline: [(Date, Int)] = []
    @State private var latestForecast: FocusForecast?
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        // Total Sessions
                        totalSessionsCard
                        
                        // Avg Duration
                        avgDurationCard
                        
                        // Top Focus Domains
                        topDomainsCard
                        
                        // Calm vs Chaos Ratio
                        calmChaosRatioCard
                        
                        // Streak Timeline Graph
                        streakTimelineCard
                        
                        // Predictive Drift Score
                        predictiveDriftCard
                    }
                }
                .padding(24)
            }
            .background(Color(.windowBackgroundColor))
            .navigationTitle("Focus Analytics")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 700, height: 600)
        .task {
            await loadAnalytics()
        }
    }
    
    // MARK: - Total Sessions Card
    
    @ViewBuilder
    private var totalSessionsCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.kosmicBlue)
                    Text("Total Sessions")
                        .font(.headline)
                    Spacer()
                }
                
                HStack(spacing: 32) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(dailyStats?.totalSessions ?? 0)")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Today")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(weeklyStats?.totalSessions ?? 0)")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("This Week")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Avg Duration Card
    
    @ViewBuilder
    private var avgDurationCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.kosmicPurple)
                    Text("Average Duration")
                        .font(.headline)
                    Spacer()
                }
                
                if let avgDuration = weeklyStats?.averageSessionDuration {
                    Text(formatDuration(avgDuration))
                        .font(.title2)
                        .fontWeight(.bold)
                } else {
                    Text("No data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Top Focus Domains Card
    
    @ViewBuilder
    private var topDomainsCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.kosmicGreen)
                    Text("Top Focus Domains")
                        .font(.headline)
                    Spacer()
                }
                
                if !topDomains.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(topDomains, id: \.0) { domain, count in
                            HStack {
                                Text(domain.capitalized)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(count)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.kosmicBlue)
                            }
                        }
                    }
                } else {
                    Text("No domain data yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Calm vs Chaos Ratio Card
    
    @ViewBuilder
    private var calmChaosRatioCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "heart.circle.fill")
                        .foregroundColor(.kosmicPurple)
                    Text("Calm vs Chaos Ratio")
                        .font(.headline)
                    Spacer()
                }
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Int(calmChaosRatio * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.kosmicGreen)
                        Text("Calm")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Int((1 - calmChaosRatio) * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        Text("Chaos")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Streak Timeline Card
    
    @ViewBuilder
    private var streakTimelineCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("Streak Timeline")
                        .font(.headline)
                    Spacer()
                }
                
                if !streakTimeline.isEmpty {
                    Chart {
                        ForEach(streakTimeline, id: \.0) { point in
                            LineMark(
                                x: .value("Date", point.0, unit: .day),
                                y: .value("Streak", point.1)
                            )
                            .foregroundStyle(.orange)
                            AreaMark(
                                x: .value("Date", point.0, unit: .day),
                                y: .value("Streak", point.1)
                            )
                            .foregroundStyle(.orange.opacity(0.2))
                        }
                    }
                    .transaction { $0.animation = nil }
                    .frame(height: 120)
                } else {
                    Text("Complete sessions to build your streak timeline")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Predictive Drift Card
    
    @ViewBuilder
    private var predictiveDriftCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.kosmicBlue)
                    Text("Predictive Drift Score")
                        .font(.headline)
                    Spacer()
                }
                
                if let forecast = latestForecast {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Focus Stability:")
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(forecast.focusStability * 100))%")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.kosmicBlue)
                        }
                        
                        HStack {
                            Text("Fatigue Risk:")
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(forecast.fatigueRisk * 100))%")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(forecast.fatigueRisk > 0.65 ? .orange : .kosmicGreen)
                        }
                    }
                } else {
                    Text("No forecast available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Helpers
    
    private func loadAnalytics() async {
        isLoading = true
        
        let calendar = Calendar.current
        let now = Date()
        
        // Daily stats
        let startOfDay = calendar.startOfDay(for: now)
        let dailyRange = DateInterval(start: startOfDay, end: now)
        dailyStats = FocusSessionService.shared.getSessionStats(for: dailyRange, modelContext: modelContext)
        
        // Weekly stats
        if let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) {
            let weeklyRange = DateInterval(start: startOfWeek, end: now)
            weeklyStats = FocusSessionService.shared.getSessionStats(for: weeklyRange, modelContext: modelContext)
        }
        
        // Top domains
        await loadTopDomains()
        
        // Calm vs Chaos ratio
        await loadCalmChaosRatio()
        
        // Streak timeline
        await loadStreakTimeline()
        
        // Latest forecast
        latestForecast = CognitionPredictor.shared.fetchLatestForecast(modelContext: modelContext)
        
        isLoading = false
    }
    
    private func loadTopDomains() async {
        let sessions = FocusSessionService.shared.getRecentSessions(limit: 100, modelContext: modelContext)
        var domainCounts: [String: Int] = [:]
        
        for session in sessions {
            if let type = session.targetObjectType {
                domainCounts[type, default: 0] += 1
            }
        }
        
        topDomains = domainCounts.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
    }
    
    private func loadCalmChaosRatio() async {
        // This is a simplified calculation - in reality, we'd need ARTE state data per session
        // For now, we'll use a placeholder calculation
        let sessions = FocusSessionService.shared.getRecentSessions(limit: 50, modelContext: modelContext)
        let completed = sessions.filter { $0.status == .completed }
        calmChaosRatio = completed.isEmpty ? 0.5 : Double(completed.count) / Double(sessions.count)
    }
    
    private func loadStreakTimeline() async {
        let calendar = Calendar.current
        let now = Date()
        var timeline: [(Date, Int)] = []
        
        // Calculate streak for last 14 days
        for dayOffset in 0..<14 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
            
            let range = DateInterval(start: startOfDay, end: endOfDay)
            let daySessions = FocusSessionService.shared.getSessions(in: range, modelContext: modelContext)
            let completed = daySessions.filter { $0.status == .completed }
            
            // Calculate streak up to this day
            var streak = 0
            var checkDate = startOfDay
            while streak < 365 {
                let checkRange = DateInterval(start: checkDate, end: calendar.date(byAdding: .day, value: 1, to: checkDate) ?? checkDate)
                let checkSessions = FocusSessionService.shared.getSessions(in: checkRange, modelContext: modelContext)
                if checkSessions.filter({ $0.status == .completed }).isEmpty {
                    break
                }
                streak += 1
                guard let prevDate = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prevDate
            }
            
            timeline.append((startOfDay, streak))
        }
        
        streakTimeline = timeline.reversed()
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        return "\(minutes) min"
    }
}

#Preview {
    FocusAnalyticsDrawer()
        .modelContainer(for: [FocusSession.self, FocusForecast.self])
}

