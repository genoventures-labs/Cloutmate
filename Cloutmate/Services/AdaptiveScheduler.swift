//
//  AdaptiveScheduler.swift
//  Cloutmate
//
//  Phase 9B: Adaptive Temporal Intelligence
//  Dynamically reflows focus sessions using predictive cognition + CPS urgency + calendar availability.
//

import Foundation
import SwiftData
import Combine
import os.log
import CloutmateShared

@MainActor
final class AdaptiveScheduler: ObservableObject {
    static let shared = AdaptiveScheduler()

    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "AdaptiveScheduler")
    private var cancellables = Set<AnyCancellable>()
    private var isRunning = false

    private init() {}

    // MARK: - Lifecycle

    func start(modelContext: ModelContext) {
        guard !isRunning else {
            logger.debug("AdaptiveScheduler already running")
            return
        }

        isRunning = true
        logger.info("Starting AdaptiveScheduler")

        observeFocusSessionEvents(modelContext: modelContext)
    }

    func stop() {
        guard isRunning else { return }
        cancellables.removeAll()
        isRunning = false
        logger.info("AdaptiveScheduler stopped")
    }

    // MARK: - Public API

    /// Respond to a skipped (abandoned or auto-expired) focus session.
    func handleSkippedSession(_ session: FocusSession, modelContext: ModelContext) {
        guard AdaptiveSchedulerSettings.shared.isDynamicReflowEnabled else {
            logger.debug("Dynamic reflow disabled – skipping reschedule")
            return
        }

        guard session.wasRescheduled == false else {
            logger.debug("Session already rescheduled – skipping duplicate reflow")
            return
        }

        _Concurrency.Task { @MainActor [weak self] in
            guard let self else { return }
            let originalStart = session.startTime
            if let newStart = await self.reflowSchedule(skippedSession: session, modelContext: modelContext) {
                let reason = self.buildReasoning(for: session, from: originalStart, to: newStart, modelContext: modelContext)
                self.deliverReflowNudge(for: session, originalTime: originalStart, newTime: newStart, reason: reason, modelContext: modelContext)
                await CalendarSyncService.shared.syncSessionToCalendar(session, modelContext: modelContext)
            } else {
                self.logger.warning("Failed to compute reflow time for session \(session.id.uuidString, privacy: .public)")
            }
        }
    }

    /// Core reflow algorithm used internally and callable for manual recalculations.
    func reflowSchedule(
        skippedSession: FocusSession,
        modelContext: ModelContext,
        horizonHours: Int = 48
    ) async -> Date? {
        let planningWindow = DateInterval(start: Date(), end: Date().addingTimeInterval(TimeInterval(horizonHours) * 3_600))
        let slotMinutes = max(15, Int(skippedSession.plannedDuration / 60))

        // 1. Fetch urgency & context scores
        let urgencyScore = computeUrgency(for: skippedSession, modelContext: modelContext)

        // 2. Fetch energy windows from cognition predictor (if available)
        let energyWindows = await CognitionPredictor.shared.predictEnergyWindows(daysAhead: 2, modelContext: modelContext)

        // 3. Derive availability slots
        let availableSlots = await fetchAvailabilitySlots(
            in: planningWindow,
            slotMinutes: slotMinutes,
            modelContext: modelContext
        )

        guard !availableSlots.isEmpty else {
            logger.error("No available slots during planning window")
            return nil
        }

        // 4. Score slots based on energy alignment + urgency
        guard let bestSlot = scoreSlots(
            availableSlots,
            energyWindows: energyWindows,
            urgency: urgencyScore,
            session: skippedSession
        ) else {
            return nil
        }

        skippedSession.scheduledTime = bestSlot.start
        skippedSession.wasRescheduled = true
        if skippedSession.endTime == nil {
            skippedSession.endTime = nil
        }

        do {
            try modelContext.save()
            logger.info("Rescheduled session \(skippedSession.id.uuidString, privacy: .public) to \(bestSlot.start, privacy: .public)")
            return bestSlot.start
        } catch {
            logger.error("Failed to persist rescheduled session: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Observers

    private func observeFocusSessionEvents(modelContext: ModelContext) {
        NotificationCenter.default
            .publisher(for: .focusSessionStatusChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self, let session = notification.object as? FocusSession else { return }
                let status = session.status
                if status == .abandoned {
                    self.handleSkippedSession(session, modelContext: modelContext)
                }
            }
            .store(in: &cancellables)
    }

    /// Update internal state when user manually moves a synced calendar event.
    func handleExternalCalendarUpdate(
        for session: FocusSession,
        newStart: Date,
        modelContext: ModelContext
    ) {
        logger.info("Reconciling external calendar move for session \(session.id.uuidString, privacy: .public)")
        session.scheduledTime = newStart
        session.wasRescheduled = true

        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save external calendar update: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Slot Scoring

    private func scoreSlots(
        _ slots: [TimeSlot],
        energyWindows: [EnergyWindow],
        urgency: Double,
        session: FocusSession
    ) -> TimeSlot? {
        let now = Date()
        let urgencyWeight = clamp(urgency, min: 0.0, max: 1.0)

        let scored = slots.map { slot -> (TimeSlot, Double) in
            let energyScore = energyScore(for: slot, energyWindows: energyWindows)

            // Recency bias: prefer sooner slots when urgency is high
            let hoursFromNow = slot.start.timeIntervalSince(now) / 3_600
            let recencyScore = max(0.0, 1.0 - (hoursFromNow / 48.0))

            let objectiveBoost: Double
            if session.targetObjectType == "task" {
                objectiveBoost = 0.1
            } else {
                objectiveBoost = 0.0
            }

            let composite = (energyScore * 0.55) + (urgencyWeight * 0.30) + (recencyScore * 0.10) + objectiveBoost
            return (slot, composite)
        }

        return scored
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
            .first
    }

    private func energyScore(for slot: TimeSlot, energyWindows: [EnergyWindow]) -> Double {
        guard !energyWindows.isEmpty else { return 0.5 }

        let slotInterval = DateInterval(start: slot.start, end: slot.end)
        var bestScore: Double = 0.0
        for window in energyWindows {
            let windowInterval = DateInterval(start: window.windowStart, end: window.windowEnd)
            // Calculate intersection manually
            let intersectionStart = max(slot.start, window.windowStart)
            let intersectionEnd = min(slot.end, window.windowEnd)
            if intersectionStart < intersectionEnd {
                let intersection = DateInterval(start: intersectionStart, end: intersectionEnd)
                let overlapRatio = intersection.duration / slotInterval.duration
                let weighted = window.predictedEnergyScore * overlapRatio * window.confidence
                bestScore = max(bestScore, weighted)
            }
        }
        return bestScore
    }

    // MARK: - Helpers

    private func computeUrgency(for session: FocusSession, modelContext: ModelContext) -> Double {
        var cpsScore: Double = 0.3
        if let objectId = session.targetObjectId,
           let score = PriorityEngine.shared.getScoreValue(for: objectId, modelContext: modelContext) {
            cpsScore = clamp(score, min: 0.0, max: 1.0)
        }

        var deadlineScore: Double = 0.3
        if let objectId = session.targetObjectId,
           session.targetObjectType == "task" {
            let descriptor = FetchDescriptor<CloutmateShared.Task>(predicate: #Predicate { $0.id == objectId })
            if let task = try? modelContext.fetch(descriptor).first,
               let dueDate = task.dueDate {
                let seconds = dueDate.timeIntervalSince(Date())
                if seconds <= 0 {
                    deadlineScore = 1.0
                } else {
                    let days = seconds / 86_400
                    deadlineScore = clamp(1.0 - (days / 7.0), min: 0.0, max: 1.0)
                }
            }
        }

        return (cpsScore * 0.6) + (deadlineScore * 0.4)
    }

    private func fetchAvailabilitySlots(
        in interval: DateInterval,
        slotMinutes: Int,
        modelContext: ModelContext
    ) async -> [TimeSlot] {
        do {
            return try await CalendarAvailabilityService.shared.availableTimeSlots(
                modelContext: modelContext,
                in: interval,
                workdayStartHour: AdaptiveSchedulerSettings.shared.workdayStartHour,
                workdayEndHour: AdaptiveSchedulerSettings.shared.workdayEndHour,
                slotMinutes: slotMinutes
            )
        } catch {
            logger.error("Failed to compute availability slots: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private func buildReasoning(
        for session: FocusSession,
        from original: Date,
        to newTime: Date,
        modelContext: ModelContext
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        var parts: [String] = []
        parts.append("You skipped \(session.objective) during a low-energy block.")
        parts.append("I moved it to \(formatter.string(from: newTime)) when your forecast peaks.")

        if let objectId = session.targetObjectId,
           let score = PriorityEngine.shared.getScoreValue(for: objectId, modelContext: modelContext) {
            let priorityPercent = Int(score * 100)
            parts.append("This work still holds a \(priorityPercent)% priority weight in CPS.")
        }

        return parts.joined(separator: " ")
    }

    private func deliverReflowNudge(
        for session: FocusSession,
        originalTime: Date,
        newTime: Date,
        reason: String,
        modelContext: ModelContext
    ) {
        let message = "I rescheduled \(session.objective) for your next focus spike."
        let detail = reason

        SmartNudgeService.shared.deliverPredictiveNudge(
            trigger: .custom,
            tone: AdaptiveSchedulerSettings.shared.preferredTone,
            message: message,
            detail: detail,
            metadata: [
                "sessionId": session.id.uuidString,
                "originalTime": originalTime.iso8601String,
                "newTime": newTime.iso8601String
            ],
            modelContext: modelContext
        )
    }

    private func clamp(_ value: Double, min lower: Double, max upper: Double) -> Double {
        return max(lower, min(value, upper))
    }
}

// MARK: - Support Types & Settings

@MainActor
final class AdaptiveSchedulerSettings: ObservableObject {
    static let shared = AdaptiveSchedulerSettings()

    private struct Keys {
        static let dynamicReflowEnabled = "adaptiveScheduler.dynamicReflowEnabled"
        static let preferredTone = "adaptiveScheduler.preferredTone"
        static let workdayStartHour = "adaptiveScheduler.workdayStartHour"
        static let workdayEndHour = "adaptiveScheduler.workdayEndHour"
    }

    var isDynamicReflowEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Keys.dynamicReflowEnabled) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.dynamicReflowEnabled) }
    }

    var preferredTone: SmartNudgeTone {
        get {
            if let raw = UserDefaults.standard.string(forKey: Keys.preferredTone),
               let tone = SmartNudgeTone(rawValue: raw) {
                return tone
            }
            return .gentle
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.preferredTone)
        }
    }

    var workdayStartHour: Int {
        get { UserDefaults.standard.object(forKey: Keys.workdayStartHour) as? Int ?? 9 }
        set { UserDefaults.standard.set(newValue, forKey: Keys.workdayStartHour) }
    }

    var workdayEndHour: Int {
        get { UserDefaults.standard.object(forKey: Keys.workdayEndHour) as? Int ?? 17 }
        set { UserDefaults.standard.set(newValue, forKey: Keys.workdayEndHour) }
    }
}

// MARK: - Notification Extension

private extension Date {
    var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }
}


