//
//  FocusAnalyticsService.swift
//  Cloutmate
//
//  Aggregates focus session analytics for Stats and Streak tabs.
//

import Foundation
import SwiftData
import CloutmateShared

struct FocusDailyMetric: Identifiable {
    let id = UUID()
    let date: Date
    let focusMinutes: Double
    let completedSessions: Int
    let totalSessions: Int
}

struct FocusDomainMetric: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
    let totalDuration: TimeInterval
}

struct FocusStreakPoint: Identifiable {
    let id = UUID()
    let date: Date
    let streakCount: Int
}

struct FocusAnalyticsSnapshot {
    let dailyStats: FocusSessionStats
    let weeklyStats: FocusSessionStats
    let monthlyStats: FocusSessionStats
    let timeline: [FocusDailyMetric]
    let topDomains: [FocusDomainMetric]
    let calmRatio: Double
    let streakTimeline: [FocusStreakPoint]
    let longestStreak: Int
    let recentSessions: [FocusSession]
    let latestForecast: FocusForecast?
}

@MainActor
final class FocusAnalyticsService {
    static let shared = FocusAnalyticsService()
    
    private init() {}
    
    func snapshot(modelContext: ModelContext) -> FocusAnalyticsSnapshot {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? startOfDay
        let startOfMonth = calendar.date(byAdding: .day, value: -29, to: startOfDay) ?? startOfDay
        
        let dailyInterval = DateInterval(start: startOfDay, end: now)
        let weeklyInterval = DateInterval(start: startOfWeek, end: now)
        let monthlyInterval = DateInterval(start: startOfMonth, end: now)
        
        let dailyStats = FocusSessionService.shared.getSessionStats(for: dailyInterval, modelContext: modelContext)
        let weeklyStats = FocusSessionService.shared.getSessionStats(for: weeklyInterval, modelContext: modelContext)
        let monthlyStats = FocusSessionService.shared.getSessionStats(for: monthlyInterval, modelContext: modelContext)
        
        let sessionsLast30 = FocusSessionService.shared.getSessions(in: monthlyInterval, modelContext: modelContext)
        let timeline = buildTimeline(for: sessionsLast30, calendar: calendar, windowDays: 30)
        let topDomains = buildDomainMetrics(from: sessionsLast30)
        let calmRatio = monthlyStats.totalSessions == 0 ? 0.5 : monthlyStats.completionRate
        let streakTimeline = buildStreakTimeline(calendar: calendar, modelContext: modelContext, windowDays: 30)
        let longestStreak = calculateLongestStreak(modelContext: modelContext)
        let recentSessions = FocusSessionService.shared.getRecentSessions(limit: 10, modelContext: modelContext)
        let latestForecast = CognitionPredictor.shared.fetchLatestForecast(modelContext: modelContext)
        
        return FocusAnalyticsSnapshot(
            dailyStats: dailyStats,
            weeklyStats: weeklyStats,
            monthlyStats: monthlyStats,
            timeline: timeline,
            topDomains: topDomains,
            calmRatio: calmRatio,
            streakTimeline: streakTimeline,
            longestStreak: longestStreak,
            recentSessions: recentSessions,
            latestForecast: latestForecast
        )
    }
    
    // MARK: - Builders
    
    private func buildTimeline(for sessions: [FocusSession], calendar: Calendar, windowDays: Int) -> [FocusDailyMetric] {
        var buckets: [Date: (minutes: Double, completed: Int, total: Int)] = [:]
        
        for session in sessions {
            let day = calendar.startOfDay(for: session.startTime)
            var entry = buckets[day] ?? (minutes: 0, completed: 0, total: 0)
            entry.minutes += session.actualDuration / 60.0
            if session.status == .completed {
                entry.completed += 1
            }
            entry.total += 1
            buckets[day] = entry
        }
        
        var timeline: [FocusDailyMetric] = []
        for offset in stride(from: windowDays - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: Date())) else { continue }
            let entry = buckets[date] ?? (minutes: 0, completed: 0, total: 0)
            timeline.append(
                FocusDailyMetric(
                    date: date,
                    focusMinutes: entry.minutes,
                    completedSessions: entry.completed,
                    totalSessions: entry.total
                )
            )
        }
        return timeline
    }
    
    private func buildDomainMetrics(from sessions: [FocusSession]) -> [FocusDomainMetric] {
        var aggregates: [String: (count: Int, duration: TimeInterval)] = [:]
        
        for session in sessions {
            let key = displayName(for: session.targetObjectType)
            var entry = aggregates[key] ?? (count: 0, duration: 0)
            entry.count += 1
            entry.duration += session.actualDuration
            aggregates[key] = entry
        }
        
        return aggregates
            .map { label, value in
                FocusDomainMetric(
                    label: label,
                    count: value.count,
                    totalDuration: value.duration
                )
            }
            .sorted { lhs, rhs in
                lhs.totalDuration == rhs.totalDuration ? lhs.count > rhs.count : lhs.totalDuration > rhs.totalDuration
            }
    }
    
    private func buildStreakTimeline(calendar: Calendar, modelContext: ModelContext, windowDays: Int) -> [FocusStreakPoint] {
        var timeline: [FocusStreakPoint] = []
        var streak = 0
        
        for offset in stride(from: windowDays - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: Date())) else { continue }
            let nextDay = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            let interval = DateInterval(start: date, end: nextDay)
            let sessions = FocusSessionService.shared.getSessions(in: interval, modelContext: modelContext)
            let completed = sessions.contains { $0.status == .completed }
            if completed {
                streak += 1
            } else {
                streak = 0
            }
            timeline.append(FocusStreakPoint(date: date, streakCount: streak))
        }
        
        return timeline
    }
    
    private func calculateLongestStreak(modelContext: ModelContext) -> Int {
        let sessions = (try? modelContext.fetch(FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.statusRaw == FocusSessionStatus.completed.rawValue },
            sortBy: [SortDescriptor(\.startTime, order: .forward)]
        ))) ?? []
        
        guard !sessions.isEmpty else { return 0 }
        let calendar = Calendar.current
        let days = sessions
            .map { calendar.startOfDay(for: $0.startTime) }
            .sorted()
        
        var longest = 0
        var current = 0
        var previousDay: Date?
        
        for day in days {
            if let prev = previousDay,
               calendar.isDate(day, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: prev) ?? prev) {
                current += 1
            } else {
                current = 1
            }
            longest = max(longest, current)
            previousDay = day
        }
        
        return longest
    }
    
    private func displayName(for targetType: String?) -> String {
        guard let raw = targetType, let objectType = ObjectType(rawValue: raw) else {
            return "Ad-hoc"
        }
        switch objectType {
        case .project: return "Projects"
        case .task: return "Tasks"
        case .note: return "Notes"
        case .artifact: return "Artifacts"
        case .area: return "Areas"
        case .event: return "Events"
        case .post: return "Posts"
        case .reminder: return "Reminders"
        case .inboxItem: return "Inbox"
        case .focusSession: return "Focus"
        }
    }
}


