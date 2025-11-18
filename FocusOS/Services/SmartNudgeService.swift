//
//  SmartNudgeService.swift
//  FocusOS
//
//  Phase 8: Cognitive Loop Completion
//  Contextual micro-coach delivering ARTE-aware nudges
//

import Foundation
import SwiftData
import Combine
import os.log
import FocusOSShared

@MainActor
final class SmartNudgeService: ObservableObject {
    static let shared = SmartNudgeService()

    @Published private(set) var latestNudge: SmartNudge?

    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "SmartNudgeService")
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
    
    /// Deliver a Flow Companion nudge with personality-aware tone
    func deliverFlowCompanionNudge(
        trigger: FlowCompanionTrigger,
        message: String,
        detail: String?,
        personality: FlowCompanionPersonality,
        modelContext: ModelContext
    ) {
        // Map Flow Companion trigger to SmartNudgeTrigger
        let nudgeTrigger: SmartNudgeTrigger
        switch trigger {
        case .deferredHighImpactItems:
            nudgeTrigger = .stalePriority
        case .strongMomentum, .focusDrift:
            nudgeTrigger = .reflectionReminder
        case .fatigueRisk:
            nudgeTrigger = .fatiguedState
        case .reflectionOpportunity:
            nudgeTrigger = .reflectionReminder
        }
        
        // Map personality to tone
        let tone: SmartNudgeTone
        switch personality {
        case .clarityCoach:
            tone = .focused
        case .momentumGuide:
            tone = .energized
        case .reflectionPartner:
            tone = .reflective
        }
        
        deliverPredictiveNudge(
            trigger: nudgeTrigger,
            tone: tone,
            message: message,
            detail: detail,
            metadata: ["source": "flow_companion", "personality": personality.rawValue],
            modelContext: modelContext
        )
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
        
        if let candidate = checkRitualReminder(modelContext: modelContext) {
            deliver(candidate: candidate, modelContext: modelContext)
            return
        }
    }

    /// Force evaluation of triggers for testing - bypasses some guards to show actual nudges
    func forceEvaluateTriggers(modelContext: ModelContext) {
        // Check all triggers and deliver the first available actual nudge
        // This bypasses quiet hours and cooldown for testing purposes
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
        
        if let candidate = checkRitualReminder(modelContext: modelContext) {
            deliver(candidate: candidate, modelContext: modelContext)
            return
        }
        
        // If no actual nudge is available, create a sample one to show the structure
        logger.info("No actual nudge conditions met - showing sample nudge for testing")
        deliverPredictiveNudge(
            trigger: .reflectionReminder,
            tone: NudgeToneAdapter.shared.tone(for: .reflectionReminder),
            message: "Time for a moment of reflection.",
            detail: "This is how Aurora's nudges appear when conditions are met.",
            metadata: ["source": "test_evaluation", "triggered_from": "settings"],
            modelContext: modelContext
        )
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

    private func checkRitualReminder(modelContext: ModelContext) -> NudgeCandidate? {
        guard RitualSettings.shared.isNudgeCategoryEnabled(.reflectionReminder) else { return nil }
        
        // Check for upcoming rituals within the next hour
        let now = Date()
        let oneHourFromNow = now.addingTimeInterval(3600)
        
        let descriptor = FetchDescriptor<FocusRitual>()
        let allRituals = (try? modelContext.fetch(descriptor)) ?? []
        
        // Find rituals that are scheduled soon and haven't been triggered
        let upcomingRituals = allRituals.filter { ritual in
            ritual.status == .upcoming &&
            ritual.scheduledFor >= now &&
            ritual.scheduledFor <= oneHourFromNow
        }
        
        guard let nextRitual = upcomingRituals.first else { return nil }
        
        // Check if we've already nudged about this ritual recently
        if hasRecentNudge(for: nil, trigger: .reflectionReminder, withinHours: 1, modelContext: modelContext) {
            return nil
        }
        
        // Check fatigue - don't nudge if user is fatigued (unless settings allow)
        if NudgeToneAdapter.shared.shouldSuppressDueToFatigue {
            return nil
        }
        
        let ritualType = nextRitual.type
        let minutesUntil = Int(nextRitual.scheduledFor.timeIntervalSince(now) / 60)
        
        let message: String
        let detail: String?
        
        if minutesUntil <= 15 {
            // Very soon
            message = ritualType == .morning
                ? "Let's set the day's intention."
                : "Want to reflect on what went well?"
            detail = "Your \(ritualType.displayName) is starting soon."
        } else {
            // Within the hour
            message = ritualType == .morning
                ? "Top 3 focus items are waiting — ready to begin?"
                : "Your calm streak is \(nextRitual.streakCount) days strong."
            detail = "\(ritualType.displayName) in \(minutesUntil) minutes"
        }
        
        return NudgeCandidate(
            trigger: .reflectionReminder,
            message: message,
            detail: detail,
            relatedObjectId: nextRitual.id,
            relatedObjectType: "ritual",
            metadata: ["ritual_type": ritualType.rawValue, "minutes_until": "\(minutesUntil)"]
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
    
    // MARK: - Focus Mode Nudges
    
    /// Check focus stability during active session and deliver nudge if needed
    func checkFocusStability(
        session: FocusSession,
        previousStability: Double?,
        currentStability: Double,
        modelContext: ModelContext
    ) {
        guard let previous = previousStability else { return }
        
        let drop = previous - currentStability
        if drop > 0.20 { // 20% drop
            deliverPredictiveNudge(
                trigger: .reflectionReminder,
                tone: .gentle,
                message: "Let's pause and reset your rhythm.",
                detail: "Your focus stability has dropped. Take a moment to recenter.",
                metadata: [
                    "source": "focus_mode",
                    "session_id": session.id.uuidString,
                    "stability_drop": String(format: "%.2f", drop)
                ],
                modelContext: modelContext
            )
        }
    }
    
    /// Check if LF remains high for extended period (deep flow state)
    func checkDeepFlowState(
        session: FocusSession,
        lfHistory: [Double],
        modelContext: ModelContext
    ) {
        guard lfHistory.count >= 20 else { return } // Need at least 20 samples (2.5+ minutes at 8s intervals)
        
        let recentLF = Array(lfHistory.suffix(20))
        let averageLF = recentLF.reduce(0.0, +) / Double(recentLF.count)
        
        if averageLF > 0.5 { // High positive LF
            deliverPredictiveNudge(
                trigger: .reflectionReminder,
                tone: .energized,
                message: "Excellent consistency — you're in deep flow.",
                detail: "You've maintained high focus for an extended period.",
                metadata: [
                    "source": "focus_mode",
                    "session_id": session.id.uuidString,
                    "lf_average": String(format: "%.2f", averageLF)
                ],
                modelContext: modelContext
            )
        }
    }
    
    /// Deliver nudge when session ends early
    func deliverEarlyEndNudge(
        session: FocusSession,
        plannedDuration: TimeInterval,
        actualDuration: TimeInterval,
        modelContext: ModelContext
    ) {
        let completionRatio = actualDuration / plannedDuration
        if completionRatio < 0.5 { // Less than 50% of planned time
            deliverPredictiveNudge(
                trigger: .reflectionReminder,
                tone: .gentle,
                message: "Even short sessions matter. Let's note what pulled you away.",
                detail: "Understanding interruptions helps improve future focus.",
                metadata: [
                    "source": "focus_mode",
                    "session_id": session.id.uuidString,
                    "completion_ratio": String(format: "%.2f", completionRatio)
                ],
                modelContext: modelContext
            )
        }
    }
    
    /// Deliver post-session summary nudge
    func deliverPostSessionNudge(
        session: FocusSession,
        stabilityPercentage: Double,
        modelContext: ModelContext
    ) {
        let message = String(format: "You sustained calm focus for %.0f%% of this session.", stabilityPercentage * 100)
        
        deliverPredictiveNudge(
            trigger: .reflectionReminder,
            tone: .reflective,
            message: message,
            detail: "Take a moment to reflect on what helped you stay focused.",
            metadata: [
                "source": "focus_mode",
                "session_id": session.id.uuidString,
                "stability_percentage": String(format: "%.2f", stabilityPercentage)
            ],
            modelContext: modelContext
        )
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


