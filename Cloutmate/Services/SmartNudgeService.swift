//
//  SmartNudgeService.swift
//  Cloutmate
//
//  Phase 8: Cognitive Loop Completion
//  Contextual micro-coach delivering ARTE-aware nudges
//

import Foundation
import SwiftData
import Combine
import os.log
import CloutmateShared

@MainActor
final class SmartNudgeService: ObservableObject {
    static let shared = SmartNudgeService()

    @Published private(set) var latestNudge: SmartNudge?

    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "SmartNudgeService")
    private var evaluationTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    // MARK: - Lifecycle

    func start(modelContext: ModelContext) {
        guard RitualSettings.shared.nudgesEnabled else {
            logger.info("Smart nudges disabled in settings")
            return
        }

        logger.info("Starting SmartNudgeService")
        scheduleEvaluationTimer(modelContext: modelContext)
        observeSettingsChanges(modelContext: modelContext)
        observeAnalyticsSignals(modelContext: modelContext)
    }

    func stop() {
        evaluationTimer?.invalidate()
        evaluationTimer = nil
        cancellables.removeAll()
    }

    func clearLatestNudge() {
        latestNudge = nil
    }

    /// Deliver a predictive cognition nudge immediately, bypassing scheduled evaluations.
    func deliverPredictiveNudge(
        trigger: SmartNudgeTrigger,
        tone: SmartNudgeTone,
        message: String,
        detail: String? = nil,
        metadata: [String: String] = [:],
        modelContext: ModelContext
    ) {
        let nudge = SmartNudge(
            trigger: trigger,
            tone: tone,
            message: message,
            detail: detail,
            metadata: metadata
        )

        nudge.markDelivered()
        modelContext.insert(nudge)
        latestNudge = nudge
        RitualAnalytics.shared.recordNudge(nudge, modelContext: modelContext)
        saveContext(modelContext)
        logger.info("Delivering predictive nudge with trigger \(trigger.rawValue)")
    }

    // MARK: - Evaluation

    private func scheduleEvaluationTimer(modelContext: ModelContext) {
        evaluationTimer?.invalidate()
        evaluationTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.evaluateTriggers(modelContext: modelContext)
        }
    }

    private func observeSettingsChanges(modelContext: ModelContext) {
        RitualSettings.shared.settingsDidChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if RitualSettings.shared.nudgesEnabled {
                    self.scheduleEvaluationTimer(modelContext: modelContext)
                } else {
                    self.stop()
                }
            }
            .store(in: &cancellables)
    }

    private func observeAnalyticsSignals(modelContext: ModelContext) {
        RitualAnalytics.shared.metricsDidChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.evaluateTriggers(modelContext: modelContext)
            }
            .store(in: &cancellables)
    }

    private func evaluateTriggers(modelContext: ModelContext) {
        guard RitualSettings.shared.nudgesEnabled else { return }
        guard !isWithinQuietHours else { return }
        guard allowAnotherNudge(modelContext: modelContext) else { return }
        guard !NudgeToneAdapter.shared.shouldSuppressDueToFatigue else { return }

        if let candidate = checkStaleHighPriority(modelContext: modelContext) {
            deliver(candidate: candidate, modelContext: modelContext)
            return
        }

        if let candidate = checkCaptureVelocity(modelContext: modelContext) {
            deliver(candidate: candidate, modelContext: modelContext)
            return
        }

        if let candidate = checkFatiguedState(modelContext: modelContext) {
            deliver(candidate: candidate, modelContext: modelContext)
            return
        }

        if let candidate = checkExpressOverweight(modelContext: modelContext) {
            deliver(candidate: candidate, modelContext: modelContext)
            return
        }
    }

    // MARK: - Trigger Checks

    private func checkStaleHighPriority(modelContext: ModelContext) -> NudgeCandidate? {
        guard RitualSettings.shared.isNudgeCategoryEnabled(.stalePriority) else { return nil }

        guard let cutoff = Calendar.current.date(byAdding: .day, value: -3, to: Date()) else { return nil }
        let topTasks = PriorityEngine.shared.getTopObjects(ofType: "task", limit: 5, modelContext: modelContext)

        for item in topTasks {
            let taskId = item.objectId
            let descriptor = FetchDescriptor<Task>(
                predicate: #Predicate { task in task.id == taskId }
            )

            guard let task = try? modelContext.fetch(descriptor).first else { continue }

            let lastUpdated = task.updatedAt
            if lastUpdated < cutoff {
                // Check cooldown for this object
                if hasRecentNudge(for: item.objectId, trigger: .stalePriority, withinHours: 24, modelContext: modelContext) {
                    continue
                }

                let message = "\(task.title) deserves attention today. Ready to make progress?"
                let detail = "This high-priority task hasn't moved in a few days."
                let metadata = [
                    "objectTitle": task.title,
                    "objectType": "Task"
                ]

                return NudgeCandidate(
                    trigger: .stalePriority,
                    message: message,
                    detail: detail,
                    relatedObjectId: task.id,
                    relatedObjectType: "task",
                    metadata: metadata
                )
            }
        }

        return nil
    }

    private func checkCaptureVelocity(modelContext: ModelContext) -> NudgeCandidate? {
        guard RitualSettings.shared.isNudgeCategoryEnabled(.captureVelocityDrop) else { return nil }

        let trend = AnalyticsEngine.shared.getProductivityTrend(days: 7, modelContext: modelContext)
        guard trend.count >= 4 else { return nil }

        let recentAverage = trend.suffix(3).map { $0.completionRate }.reduce(0, +) / Double(3)
        let priorAverage = trend.prefix(trend.count - 3).suffix(3).map { $0.completionRate }.reduce(0, +) / Double(3)

        guard priorAverage > 0, recentAverage < priorAverage * 0.5 else { return nil }
        if hasRecentNudge(for: nil, trigger: .captureVelocityDrop, withinHours: 6, modelContext: modelContext) {
            return nil
        }

        let message = "Your capture rhythm has slowed. Want to revisit your inbox?"
        let detail = "Capture velocity dropped over 50% compared to last week."

        return NudgeCandidate(
            trigger: .captureVelocityDrop,
            message: message,
            detail: detail,
            relatedObjectId: nil,
            relatedObjectType: nil,
            metadata: ["recentAverage": String(recentAverage), "priorAverage": String(priorAverage)]
        )
    }

    private func checkFatiguedState(modelContext: ModelContext) -> NudgeCandidate? {
        guard RitualSettings.shared.isNudgeCategoryEnabled(.fatiguedState) else { return nil }
        guard NudgeToneAdapter.shared.currentEmotion == .fatigued else { return nil }

        if hasRecentNudge(for: nil, trigger: .fatiguedState, withinHours: 4, modelContext: modelContext) {
            return nil
        }

        let message = "Let's reset before we push further. Need a gentle reflection?"
        let detail = "You've remained in a fatigued state for a while."

        return NudgeCandidate(
            trigger: .fatiguedState,
            message: message,
            detail: detail,
            relatedObjectId: nil,
            relatedObjectType: nil,
            metadata: [:]
        )
    }

    private func checkExpressOverweight(modelContext: ModelContext) -> NudgeCandidate? {
        guard RitualSettings.shared.isNudgeCategoryEnabled(.expressOverweight) else { return nil }

        let snapshot = AnalyticsEngine.shared.generateSnapshot(for: .thisWeek, modelContext: modelContext)
        guard snapshot.totalFocusMinutes > 0 else { return nil }

        let expressTime = snapshot.totalFocusMinutes
        let distillTime = Int(Double(snapshot.focusSessionsCount) * 25) // heuristic placeholder

        guard distillTime > 0, Double(expressTime) / Double(distillTime) > 0.8 else { return nil }

        if hasRecentNudge(for: nil, trigger: .expressOverweight, withinHours: 8, modelContext: modelContext) {
            return nil
        }

        let message = "You've been in express mode. Want to distill a few insights?"
        let detail = "Express vs Distill time is unbalanced this week."

        return NudgeCandidate(
            trigger: .expressOverweight,
            message: message,
            detail: detail,
            relatedObjectId: nil,
            relatedObjectType: nil,
            metadata: [:]
        )
    }

    // MARK: - Delivery

    private func deliver(candidate: NudgeCandidate, modelContext: ModelContext) {
        let tone = NudgeToneAdapter.shared.tone(for: candidate.trigger)
        let nudge = SmartNudge(
            trigger: candidate.trigger,
            tone: tone,
            message: candidate.message,
            detail: candidate.detail,
            metadata: candidate.metadata,
            relatedObjectId: candidate.relatedObjectId,
            relatedObjectType: candidate.relatedObjectType
        )

        nudge.markDelivered()
        modelContext.insert(nudge)
        latestNudge = nudge
        RitualAnalytics.shared.recordNudge(nudge, modelContext: modelContext)
        saveContext(modelContext)
        logger.info("Delivered nudge: \(candidate.trigger.rawValue, privacy: .public)")
    }

    // MARK: - Throttling

    private func allowAnotherNudge(modelContext: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<SmartNudge>()
        let allNudges = (try? modelContext.fetch(descriptor)) ?? []
        let nudgesToday = allNudges.filter { nudge in
            guard let deliveredAt = nudge.deliveredAt else { return false }
            return Calendar.current.isDateInToday(deliveredAt)
        }

        if nudgesToday.count >= RitualSettings.shared.maxNudgesPerDay {
            return false
        }

        if let last = nudgesToday.sorted(by: { ($0.deliveredAt ?? .distantPast) > ($1.deliveredAt ?? .distantPast) }).first,
           let deliveredAt = last.deliveredAt,
           Date().timeIntervalSince(deliveredAt) < RitualSettings.shared.minimumNudgeInterval {
            return false
        }

        return true
    }

    private func hasRecentNudge(
        for objectId: UUID?,
        trigger: SmartNudgeTrigger,
        withinHours: Int,
        modelContext: ModelContext
    ) -> Bool {
        let threshold = Date().addingTimeInterval(Double(-withinHours) * 3600)
        let descriptor = FetchDescriptor<SmartNudge>()
        let allNudges = (try? modelContext.fetch(descriptor)) ?? []
        let matches = allNudges.filter { nudge in
            guard let deliveredAt = nudge.deliveredAt else { return false }
            guard deliveredAt >= threshold else { return false }
            guard nudge.trigger == trigger else { return false }
            if let objectId {
                return nudge.relatedObjectId == objectId
            }
            return true
        }
        return !matches.isEmpty
    }

    private var isWithinQuietHours: Bool {
        let now = Date()
        return RitualSettings.shared.isWithinQuietHours(now)
    }

    private func saveContext(_ modelContext: ModelContext) {
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save SmartNudge context: \(error.localizedDescription)")
        }
    }
}

// MARK: - Nudge Candidate

private struct NudgeCandidate {
    let trigger: SmartNudgeTrigger
    let message: String
    let detail: String?
    let relatedObjectId: UUID?
    let relatedObjectType: String?
    let metadata: [String: String]
}


