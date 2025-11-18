//
//  FocusRitualManager.swift
//  FocusOS
//
//  Phase 8: Cognitive Loop Completion
//  Coordinates scheduling and lifecycle of morning/evening focus rituals
//

import Foundation
import SwiftData
import Combine
import os.log

@MainActor
final class FocusRitualManager: ObservableObject {
    static let shared = FocusRitualManager()

    @Published private(set) var activeRitual: FocusRitual?
    @Published private(set) var upcomingRituals: [FocusRitual] = []

    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "FocusRitualManager")
    private var evaluationTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    // MARK: - Public API

    /// Starts ritual monitoring, generating schedules and handling triggers.
    func start(modelContext: ModelContext) {
        logger.info("Starting FocusRitualManager")
        refreshRitualSchedule(modelContext: modelContext)
        observeSettingsChanges(modelContext: modelContext)
        scheduleEvaluationTimer(modelContext: modelContext)
    }

    /// Force refresh of ritual schedule (e.g., after settings change).
    func refreshRitualSchedule(modelContext: ModelContext) {
        logger.debug("Refreshing ritual schedule")
        do {
            // Ensure we have the standard morning/evening rituals scheduled FIRST
            for type in FocusRitualType.allCases {
                try ensureRitualExists(for: type, modelContext: modelContext)
            }
            saveContext(modelContext)

            var descriptor = FetchDescriptor<FocusRitual>(
                sortBy: [SortDescriptor(\.scheduledFor, order: .forward)]
            )
            descriptor.fetchLimit = 20
            let rituals = try modelContext.fetch(descriptor)
            upcomingRituals = rituals.filter { $0.status == .upcoming || $0.status == .snoozed }
            activeRitual = rituals.first { $0.status == .inProgress }
        } catch {
            logger.error("Failed to refresh ritual schedule: \(error.localizedDescription)")
        }
    }

    /// Manually trigger a ritual (e.g., after user taps notification).
    func triggerRitual(_ ritual: FocusRitual, modelContext: ModelContext) {
        logger.info("Triggering ritual \(ritual.type.rawValue, privacy: .public)")
        ritual.markTriggered()
        activeRitual = ritual
        saveContext(modelContext)
    }

    /// Called when ritual flow is completed.
    @discardableResult
    func completeRitual(
        _ ritual: FocusRitual,
        input: RitualCompletionInput,
        modelContext: ModelContext
    ) -> RitualCompletion {
        ritual.markCompleted(at: input.completedAt)
        activeRitual = nil

        let completion = RitualCompletion(
            ritualType: ritual.type,
            outcome: input.outcome,
            scheduledFor: ritual.scheduledFor,
            completedAt: input.completedAt,
            duration: input.duration,
            userNotes: input.userNotes,
            aiRecap: input.aiRecap,
            highlights: input.highlights,
            focusItemIds: input.focusItemIds,
            taskStatusCounts: input.taskStatusCounts,
            cpsBoostApplied: input.cpsBoostApplied,
            momentumDelta: input.momentumDelta,
            metadata: input.metadata
        )

        modelContext.insert(completion)
        RitualAnalytics.shared.recordCompletion(completion, modelContext: modelContext)
        scheduleNextOccurrence(for: ritual, modelContext: modelContext)
        saveContext(modelContext)
        return completion
    }

    /// Marks a ritual as missed when outside of its active window.
    func markMissedRituals(modelContext: ModelContext) {
        let now = Date()
        let missed = upcomingRituals.filter { $0.windowEnd < now && $0.status == .upcoming }
        guard !missed.isEmpty else { return }

        for ritual in missed {
            ritual.markMissed()
            ritual.streakCount = 0
            RitualAnalytics.shared.recordMissed(ritual, at: now, modelContext: modelContext)
            scheduleNextOccurrence(for: ritual, modelContext: modelContext)
        }
        saveContext(modelContext)
        refreshRitualSchedule(modelContext: modelContext)
    }

    /// Reschedules ritual to a new time (used for snooze flow).
    func snoozeRitual(
        _ ritual: FocusRitual,
        to newDate: Date,
        windowEnd: Date,
        modelContext: ModelContext
    ) {
        ritual.snooze(until: newDate, windowEnd: windowEnd)
        saveContext(modelContext)
        refreshRitualSchedule(modelContext: modelContext)
    }

    /// Cancels timers and observers (e.g., on app shutdown).
    func stop() {
        evaluationTimer?.invalidate()
        evaluationTimer = nil
        cancellables.removeAll()
    }

    // MARK: - Private Helpers

    private func ensureRitualExists(for type: FocusRitualType, modelContext: ModelContext) throws {
        let descriptor = FetchDescriptor<FocusRitual>(
            predicate: #Predicate { $0.typeRaw == type.rawValue }
        )

        if let ritual = try modelContext.fetch(descriptor).first {
            // Ensure schedule aligns with current settings
            alignRitual(ritual, with: type, modelContext: modelContext)
        } else {
            createRitual(for: type, modelContext: modelContext)
        }
    }

    private func createRitual(for type: FocusRitualType, modelContext: ModelContext) {
        let schedule = RitualSettings.shared.nextWindow(for: type)
        let ritual = FocusRitual(
            type: type,
            scheduledFor: schedule.start,
            windowEnd: schedule.end
        )
        modelContext.insert(ritual)
        logger.debug("Created ritual \(type.rawValue, privacy: .public) for \(schedule.start as NSDate)")
    }

    private func alignRitual(_ ritual: FocusRitual, with type: FocusRitualType, modelContext: ModelContext) {
        let schedule = RitualSettings.shared.nextWindow(for: type, after: Date())
        // Only reschedule if upcoming window is in the past
        if ritual.scheduledFor < Date().addingTimeInterval(-300) && ritual.status != .inProgress {
            ritual.reschedule(to: schedule.start, windowEnd: schedule.end)
        }
    }

    private func scheduleNextOccurrence(for ritual: FocusRitual, modelContext: ModelContext) {
        let nextWindow = RitualSettings.shared.nextWindow(for: ritual.type, after: ritual.scheduledFor)
        ritual.reschedule(to: nextWindow.start, windowEnd: nextWindow.end)
    }

    private func observeSettingsChanges(modelContext: ModelContext) {
        RitualSettings.shared.settingsDidChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.logger.debug("Ritual settings changed – refreshing schedule")
                self.refreshRitualSchedule(modelContext: modelContext)
            }
            .store(in: &cancellables)
    }

    private func scheduleEvaluationTimer(modelContext: ModelContext) {
        evaluationTimer?.invalidate()
        evaluationTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.logger.debug("Evaluating rituals for triggers")
            self.markMissedRituals(modelContext: modelContext)
            self.evaluateTriggers(modelContext: modelContext)
        }
    }

    private func evaluateTriggers(modelContext: ModelContext) {
        let now = Date()
        let candidates = upcomingRituals.filter { ritual in
            ritual.status == .upcoming && ritual.scheduledFor <= now && ritual.windowEnd >= now
        }

        guard let ritualToTrigger = candidates.first else { return }
        triggerRitual(ritualToTrigger, modelContext: modelContext)
    }

    private func saveContext(_ modelContext: ModelContext) {
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save ritual context: \(error.localizedDescription)")
        }
    }
}

// MARK: - Ritual Completion Input

struct RitualCompletionInput {
    let outcome: RitualCompletionOutcome
    let completedAt: Date
    let duration: TimeInterval
    let userNotes: String?
    let aiRecap: String?
    let highlights: [String]
    let focusItemIds: [UUID]
    let taskStatusCounts: [String: Int]
    let cpsBoostApplied: Bool
    let momentumDelta: Double
    let metadata: [String: String]

    init(
        outcome: RitualCompletionOutcome,
        completedAt: Date = Date(),
        duration: TimeInterval = 0,
        userNotes: String? = nil,
        aiRecap: String? = nil,
        highlights: [String] = [],
        focusItemIds: [UUID] = [],
        taskStatusCounts: [String: Int] = [:],
        cpsBoostApplied: Bool = false,
        momentumDelta: Double = 0,
        metadata: [String: String] = [:]
    ) {
        self.outcome = outcome
        self.completedAt = completedAt
        self.duration = duration
        self.userNotes = userNotes
        self.aiRecap = aiRecap
        self.highlights = highlights
        self.focusItemIds = focusItemIds
        self.taskStatusCounts = taskStatusCounts
        self.cpsBoostApplied = cpsBoostApplied
        self.momentumDelta = momentumDelta
        self.metadata = metadata
    }
}


