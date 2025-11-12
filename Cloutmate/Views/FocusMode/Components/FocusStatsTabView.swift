//
//  FocusStatsTabView.swift
//  Cloutmate
//
//  Focus Mode V2 - Stats tab content
//

import SwiftUI
import Charts

struct FocusStatsTabView: View {
    let snapshot: FocusAnalyticsSnapshot
    let onStartSession: () -> Void
    let onOpenAnalytics: () -> Void
    
    private var last14DayTimeline: [FocusDailyMetric] {
        Array(snapshot.timeline.suffix(14))
    }
    
    private var totalFocusHoursThisWeek: Double {
        snapshot.weeklyStats.totalFocusTime / 3600.0
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerRow
                
                focusMomentumCard
                
                if !snapshot.topDomains.isEmpty {
                    topDomainsCard
                }
                
                productivityHighlightsCard
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
        .background(Color(.windowBackgroundColor))
    }
    
    // MARK: - Sections
    
    private var headerRow: some View {
        HStack(spacing: 16) {
            metricTile(
                title: "Sessions",
                value: "\(snapshot.weeklyStats.totalSessions)",
                subtitle: "Completed this week",
                icon: "bolt.fill",
                tint: .kosmicBlue
            )
            
            metricTile(
                title: "Focus Time",
                value: String(format: "%.1f h", totalFocusHoursThisWeek),
                subtitle: "Total this week",
                icon: "clock.arrow.circlepath",
                tint: .kosmicPurple
            )
            
            metricTile(
                title: "Completion",
                value: "\(Int(snapshot.weeklyStats.completionRate * 100))%",
                subtitle: "Session success",
                icon: "checkmark.circle.fill",
                tint: .kosmicGreen
            )
        }
    }
    
    private var focusMomentumCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(.kosmicBlue)
                    Text("Focus Momentum")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Button(action: onOpenAnalytics) {
                        Label("View Analytics", systemImage: "chart.bar")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                }
                
                if last14DayTimeline.allSatisfy({ $0.totalSessions == 0 }) {
                    Text("Complete a focus session to see your momentum build.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Chart(last14DayTimeline) { day in
                        LineMark(
                            x: .value("Date", day.date, unit: .day),
                            y: .value("Minutes", day.focusMinutes)
                        )
                        .foregroundStyle(.kosmicBlue)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Date", day.date, unit: .day),
                            y: .value("Minutes", day.focusMinutes)
                        )
                        .foregroundStyle(LinearGradient(
                            colors: [.kosmicBlue.opacity(0.35), .kosmicBlue.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        
                        PointMark(
                            x: .value("Date", day.date, unit: .day),
                            y: .value("Minutes", day.focusMinutes)
                        )
                        .foregroundStyle(day.completedSessions > 0 ? .kosmicBlue : .gray.opacity(0.4))
                    }
                    .frame(height: 180)
                    .transaction { $0.animation = nil }
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Most Productive Hour")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(productiveHourDescription)
                            .font(.subheadline.weight(.semibold))
                    }
                    
                    Spacer()
                    
                    Button(action: onStartSession) {
                        Label("Start Focus Session", systemImage: "play.circle.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
        }
    }
    
    private var topDomainsCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "circle.grid.3x3.fill")
                        .foregroundColor(.kosmicGreen)
                    Text("Where Your Focus Went")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                
                VStack(spacing: 12) {
                    ForEach(snapshot.topDomains.prefix(5)) { domain in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(domain.label)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(shortDuration(domain.totalDuration))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            GeometryReader { geometry in
                                let progress = min(max(domain.totalDuration / maxDomainDuration, 0), 1)
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.primary.opacity(0.08))
                                        .frame(height: 8)
                                    
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(LinearGradient(
                                            colors: [.kosmicBlue, .kosmicPurple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ))
                                        .frame(width: geometry.size.width * progress, height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                }
            }
            .padding(20)
        }
    }
    
    private var productivityHighlightsCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.kosmicPurple)
                    Text("Productivity Highlights")
                        .font(.headline)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    highlightRow(
                        title: "Completion rate",
                        value: "\(Int(snapshot.monthlyStats.completionRate * 100))%",
                        detail: "Across the last 30 days"
                    )
                    
                    highlightRow(
                        title: "Longest streak",
                        value: "\(snapshot.longestStreak) day\(snapshot.longestStreak == 1 ? "" : "s")",
                        detail: "Focus momentum to beat"
                    )
                    
                    let totalHours = snapshot.monthlyStats.totalFocusTime / 3600.0
                    highlightRow(
                        title: "Total focus time",
                        value: String(format: "%.1f h", totalHours),
                        detail: "Logged in the last 30 days"
                    )
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Helpers
    
    private func metricTile(title: String, value: String, subtitle: String, icon: String, tint: Color) -> some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(tint)
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
        }
    }
    
    private func highlightRow(title: String, value: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundColor(.kosmicBlue)
        }
    }
    
    private var productiveHourDescription: String {
        guard let hour = snapshot.weeklyStats.mostProductiveTimeOfDay else {
            return "Not enough data yet"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let components = DateComponents(calendar: Calendar.current, hour: hour)
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }
    
    private var maxDomainDuration: Double {
        snapshot.topDomains.map { $0.totalDuration }.max() ?? 1
    }
    
    private func shortDuration(_ duration: TimeInterval) -> String {
        if duration >= 3600 {
            return String(format: "%.1fh", duration / 3600)
        }
        return String(format: "%.0fmin", duration / 60)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        return "\(minutes) min"
    }
}


