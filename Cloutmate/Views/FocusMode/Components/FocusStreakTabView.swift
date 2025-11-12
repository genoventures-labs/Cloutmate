//
//  FocusStreakTabView.swift
//  Cloutmate
//
//  Focus Mode V2 - Streak tab content
//

import SwiftUI
import Charts

struct FocusStreakTabView: View {
    let snapshot: FocusAnalyticsSnapshot
    let currentStreak: Int
    let recentSessions: [FocusSession]
    let onStartSession: () -> Void
    
    private var completedSessions: [FocusSession] {
        recentSessions.filter { $0.status == .completed }
    }
    
    private var missedDays: [Date] {
        snapshot.timeline
            .filter { $0.totalSessions == 0 }
            .map { $0.date }
            .suffix(5)
    }
    
    private var lastBreakDescription: String {
        guard let lastBreak = missedDays.last else {
            return "No breaks detected"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastBreak, relativeTo: Date())
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                heroCard
                streakChartCard
                winsCard
                if !missedDays.isEmpty {
                    missedDaysCard
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
        .background(Color(.windowBackgroundColor))
    }
    
    private var heroCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Current Streak")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(currentStreak)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.kosmicBlue)
                        Text("consecutive day\(currentStreak == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 8) {
                        statChip(
                            icon: "flame.fill",
                            title: "Longest Streak",
                            value: "\(snapshot.longestStreak) day\(snapshot.longestStreak == 1 ? "" : "s")"
                        )
                        
                        statChip(
                            icon: "arrow.uturn.left",
                            title: "Last Break",
                            value: lastBreakDescription
                        )
                    }
                }
                
                Button(action: onStartSession) {
                    Label("Keep the streak alive", systemImage: "play.circle.fill")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(22)
        }
    }
    
    private var streakChartCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "chart.xyaxis.line")
                        .foregroundColor(.kosmicPurple)
                    Text("Streak Strength")
                        .font(.headline)
                    Spacer()
                }
                
                if snapshot.streakTimeline.isEmpty {
                    Text("Complete focus sessions to generate your streak strength timeline.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Chart(snapshot.streakTimeline) { point in
                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Streak", point.streakCount)
                        )
                        .foregroundStyle(.linearGradient(
                            colors: [.kosmicBlue.opacity(0.6), .kosmicPurple.opacity(0.6)],
                            startPoint: .bottom,
                            endPoint: .top
                        ))
                    }
                    .transaction { $0.animation = nil }
                    .frame(height: 180)
                }
            }
            .padding(20)
        }
    }
    
    private var winsCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.kosmicGreen)
                    Text("Recent Wins")
                        .font(.headline)
                    Spacer()
                }
                
                if completedSessions.isEmpty {
                    Text("Complete a session to start building momentum.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(completedSessions.prefix(5)) { session in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "target")
                                    .foregroundColor(.kosmicBlue)
                                    .font(.caption)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.objective)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    Text("\(session.startTime.formatted(date: .abbreviated, time: .shortened)) • \(formattedDuration(session.actualDuration))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if let cpsBoost = session.cpsScoreAtStart {
                                    Text(String(format: "+%.0f cps", cpsBoost * 100))
                                        .font(.caption)
                                        .foregroundColor(.kosmicGreen)
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }
    
    private var missedDaysCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .foregroundColor(.orange)
                    Text("Recent Breaks")
                        .font(.headline)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(missedDays.reversed(), id: \.self) { date in
                        HStack {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(daysAgo(from: date))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Helpers
    
    private func statChip(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
            }
        }
    }
    
    private func daysAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        return "\(minutes) min"
    }
}


