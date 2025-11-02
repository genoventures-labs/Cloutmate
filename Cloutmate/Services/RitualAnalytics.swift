//
//  RitualAnalytics.swift
//  Cloutmate
//
//  Phase 8: Cognitive Loop Completion
//  Dedicated analytics layer for ritual engagement and consistency metrics
//

import Foundation
import SwiftData
import Combine
import os.log

@MainActor
final class RitualAnalytics {
    static let shared = RitualAnalytics()

    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "RitualAnalytics")
    private(set) var latestSummary: RitualMetricsSummary?

    let metricsDidChange = PassthroughSubject<Void, Never>()

    private init() {}

    // MARK: - Recording Events

    func recordCompletion(_ completion: RitualCompletion, modelContext: ModelContext) {
        logger.debug("Recording ritual completion for \(completion.ritualType.rawValue, privacy: .public)")
        saveContext(modelContext)
        metricsDidChange.send()
    }

    func recordMissed(_ ritual: FocusRitual, at date: Date = Date(), modelContext: ModelContext) {
        logger.debug("Recording missed ritual for \(ritual.type.rawValue, privacy: .public)")
        let missed = RitualCompletion(
            ritualType: ritual.type,
            outcome: .skipped,
            scheduledFor: ritual.scheduledFor,
            completedAt: date,
            metadata: ["reason": "missed-window"]
        )
        modelContext.insert(missed)
        saveContext(modelContext)
        metricsDidChange.send()
    }

    func recordWeeklyReview(_ review: WeeklyReview, modelContext: ModelContext) {
        saveContext(modelContext)
        metricsDidChange.send()
    }

    func recordNudge(_ nudge: SmartNudge, modelContext: ModelContext) {
        saveContext(modelContext)
        metricsDidChange.send()
    }

    // MARK: - Summary Generation

    func generateSummary(
        for timeRange: AnalyticsTimeRange,
        customRange: (Date, Date)? = nil,
        modelContext: ModelContext
    ) -> RitualMetricsSummary {
        let bounds = timeBounds(for: timeRange, customRange: customRange)
        let completions = fetchCompletions(in: bounds, modelContext: modelContext)
        let completionRate = computeCompletionRate(from: completions)
        let streaks = fetchStreaks(modelContext: modelContext)
        let weeklyReviewDate = fetchLastWeeklyReviewDate(modelContext: modelContext)
        let nudgeRate = computeNudgeResponseRate(in: bounds, modelContext: modelContext)

        let summary = RitualMetricsSummary(
            timeRange: bounds,
            completionRate: completionRate,
            morningStreak: streaks.morning.current,
            eveningStreak: streaks.evening.current,
            bestMorningStreak: streaks.morning.best,
            bestEveningStreak: streaks.evening.best,
            lastWeeklyReview: weeklyReviewDate,
            nudgeResponseRate: nudgeRate,
            completions: completions
        )

        latestSummary = summary
        return summary
    }

    func completionTrend(
        days: Int,
        modelContext: ModelContext
    ) -> [(date: Date, completionRate: Double)] {
        var trend: [(Date, Double)] = []
        let calendar = Calendar.current

        for offset in (0..<days) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let start = calendar.startOfDay(for: day)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { continue }
            let completions = fetchCompletions(in: (start, end), modelContext: modelContext)
            trend.append((start, computeCompletionRate(from: completions)))
        }

        return trend.reversed()
    }

    // MARK: - Internal Fetch Helpers

    private func fetchCompletions(
        in bounds: (Date, Date),
        modelContext: ModelContext
    ) -> [RitualCompletion] {
        let descriptor = FetchDescriptor<RitualCompletion>(
            sortBy: [SortDescriptor(\.completedAt, order: .forward)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.filter { $0.completedAt >= bounds.0 && $0.completedAt <= bounds.1 }
    }

    private func fetchStreaks(modelContext: ModelContext) -> (morning: (current: Int, best: Int), evening: (current: Int, best: Int)) {
        let descriptor = FetchDescriptor<FocusRitual>()
        guard let rituals = try? modelContext.fetch(descriptor) else {
            return ((0, 0), (0, 0))
        }

        let morning = rituals.first { $0.type == .morning }
        let evening = rituals.first { $0.type == .evening }

        return (
            morning: (morning?.streakCount ?? 0, morning?.bestStreak ?? 0),
            evening: (evening?.streakCount ?? 0, evening?.bestStreak ?? 0)
        )
    }

    private func fetchLastWeeklyReviewDate(modelContext: ModelContext) -> Date? {
        var descriptor = FetchDescriptor<WeeklyReview>(
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        let reviews = (try? modelContext.fetch(descriptor)) ?? []
        return reviews.first { $0.status == .completed }?.completedAt
    }

    private func computeCompletionRate(from completions: [RitualCompletion]) -> Double {
        guard !completions.isEmpty else { return 0 }
        let successful = completions.filter { $0.outcome == .completed }.count
        return Double(successful) / Double(completions.count)
    }

    private func computeNudgeResponseRate(
        in bounds: (Date, Date),
        modelContext: ModelContext
    ) -> Double {
        let descriptor = FetchDescriptor<SmartNudge>()
        guard let nudges = try? modelContext.fetch(descriptor), !nudges.isEmpty else {
            return 0
        }

        let inRange = nudges.filter { nudge in
            guard let delivered = nudge.deliveredAt else { return false }
            return delivered >= bounds.0 && delivered <= bounds.1
        }

        guard !inRange.isEmpty else { return 0 }
        let responded = inRange.filter { $0.response != nil && $0.response != .ignored }
        return Double(responded.count) / Double(inRange.count)
    }

    private func timeBounds(
        for timeRange: AnalyticsTimeRange,
        customRange: (Date, Date)?
    ) -> (Date, Date) {
        if let customRange {
            return customRange
        }
        return timeRange.dateRange
    }

    private func saveContext(_ modelContext: ModelContext) {
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save ritual analytics context: \(error.localizedDescription)")
        }
    }
}

// MARK: - Ritual Metrics Summary

struct RitualMetricsSummary {
    let timeRange: (start: Date, end: Date)
    let completionRate: Double
    let morningStreak: Int
    let eveningStreak: Int
    let bestMorningStreak: Int
    let bestEveningStreak: Int
    let lastWeeklyReview: Date?
    let nudgeResponseRate: Double
    let completions: [RitualCompletion]
}


