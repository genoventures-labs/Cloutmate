//
//  DriftMonitor.swift
//  Cloutmate
//
//  Phase 9: Predictive Reflection Engine
//  Observes real-time focus sessions to detect drift against forecasts
//

import Foundation
import SwiftData
import Combine
import os.log

@MainActor
final class DriftMonitor: ObservableObject {
    static let shared = DriftMonitor()

    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "DriftMonitor")
    private var evaluationTimer: Timer?
    private var lastEventTimestamps: [UUID: Date] = [:]
    private let driftSubject = PassthroughSubject<DriftEvent, Never>()
    private let momentumSubject = PassthroughSubject<MomentumMetrics, Never>()
    private(set) var latestMomentum: MomentumMetrics?
    private var isRunning = false

    var driftPublisher: AnyPublisher<DriftEvent, Never> {
        driftSubject.eraseToAnyPublisher()
    }

    var momentumPublisher: AnyPublisher<MomentumMetrics, Never> {
        momentumSubject.eraseToAnyPublisher()
    }

    private var driftThreshold: Double {
        let stored = UserDefaults.standard.double(forKey: "driftDetectionThreshold")
        return stored == 0 ? 0.10 : stored
    }

    private init() {}

    func start(modelContext: ModelContext) async {
        guard !isRunning else {
            refreshTimer(modelContext: modelContext)
            return
        }

        isRunning = true
        logger.info("Starting drift monitor")
        await evaluateCurrentSession(modelContext: modelContext)
        publishMomentumMetrics(modelContext: modelContext)
        scheduleTimer(modelContext: modelContext)
    }

    func stop() {
        evaluationTimer?.invalidate()
        evaluationTimer = nil
        isRunning = false
        logger.info("Stopped drift monitor")
    }

    func refreshTimer(modelContext: ModelContext) {
        guard isRunning else { return }
        scheduleTimer(modelContext: modelContext)
    }

    // MARK: - Evaluation

    func evaluateCurrentSession(modelContext: ModelContext) async {
        guard let activeSession = fetchActiveSession(modelContext: modelContext) else { return }
        guard let latestForecast = fetchLatestForecast(modelContext: modelContext) else { return }

        let elapsed = max(Date().timeIntervalSince(activeSession.startTime), 1)
        let planned = max(activeSession.plannedDuration, 1)
        let actualProgress = min(elapsed / planned, 1.0)
        let expectedProgress = max(min(latestForecast.focusStability, 1.0), 0.0)
        let deviation = expectedProgress - actualProgress

        let threshold = driftThreshold
        guard deviation > threshold else { return } // require deviation greater than sensitivity setting

        if let last = lastEventTimestamps[activeSession.id], Date().timeIntervalSince(last) < 1_800 {
            return // cooldown 30 minutes per session
        }

        if NudgeToneAdapter.shared.shouldSuppressDueToFatigue {
            logger.debug("Drift detected but suppressed due to fatigue state")
            return
        }

        let severity = min(max(deviation / max(threshold, 0.01), 0.0), 1.0)
        let driftType: DriftEventType = latestForecast.energyTrend == .declining ? .energy : .focus

        let snapshot = "Session: \(activeSession.objective)\nElapsed: \(Int(elapsed / 60))m / \(Int(planned / 60))m\nExpected focus stability: \(String(format: "%.2f", expectedProgress))\nActual progress: \(String(format: "%.2f", actualProgress))"

        let event = DriftEvent(
            driftType: driftType,
            severity: severity,
            expectedValue: expectedProgress,
            actualValue: actualProgress,
            deviation: deviation,
            trigger: "active_session_deviation",
            confidence: latestForecast.confidence,
            contextSnapshot: snapshot,
            relatedFocusSessionId: activeSession.id,
            relatedRitualCompletionId: nil
        )

        modelContext.insert(event)
        do {
            try modelContext.save()
            lastEventTimestamps[activeSession.id] = Date()
            driftSubject.send(event)
            logger.info("Drift event recorded for session \(activeSession.id.uuidString)")
        } catch {
            logger.error("Failed to save drift event: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func scheduleTimer(modelContext: ModelContext) {
        evaluationTimer?.invalidate()
        evaluationTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.evaluateCurrentSession(modelContext: modelContext)
                self.publishMomentumMetrics(modelContext: modelContext)
            }
        }
    }

    private func fetchActiveSession(modelContext: ModelContext) -> FocusSession? {
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { session in
                session.statusRaw == "active"
            }
        )
        let sessions = (try? modelContext.fetch(descriptor)) ?? []
        return sessions.sorted { $0.startTime > $1.startTime }.first
    }

    private func fetchLatestForecast(modelContext: ModelContext) -> FocusForecast? {
        var descriptor = FetchDescriptor<FocusForecast>(
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first ?? nil
    }

    private func publishMomentumMetrics(modelContext: ModelContext) {
        let metrics = calculateMomentum(modelContext: modelContext)
        latestMomentum = metrics
        momentumSubject.send(metrics)
        if MomentumSettings.shared.adjustmentsEnabled {
            PriorityEngine.shared.applyMomentumModifier(metrics: metrics, modelContext: modelContext)
        }
    }

    private func calculateMomentum(modelContext: ModelContext) -> MomentumMetrics {
        let calendar = Calendar.current
        let now = Date()
        let cutoff = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        var descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { session in
                session.startTime >= cutoff
            },
            sortBy: [SortDescriptor(\.startTime, order: .forward)]
        )

        let sessions = (try? modelContext.fetch(descriptor)) ?? []
        let completedSessions = sessions.filter { $0.status == .completed }

        let daysDelta = max(1, calendar.dateComponents([.day], from: calendar.startOfDay(for: cutoff), to: calendar.startOfDay(for: now)).day ?? 1)
        let completionVelocity = Double(completedSessions.count) / Double(daysDelta)

        let streak = computeStreakDays(sessions: completedSessions, calendar: calendar, now: now)
        let recovery = computeAverageRecovery(sessions: sessions)

        let flowState: MomentumMetrics.FlowState
        switch completionVelocity {
        case let v where v >= 1.5:
            flowState = .highFlow
        case let v where v >= 0.9:
            flowState = .steadyFlow
        case let v where v >= 0.4:
            flowState = .slowingFlow
        default:
            flowState = .stalled
        }

        return MomentumMetrics(
            streakDays: streak,
            completionVelocity: completionVelocity,
            averageRecoveryTime: recovery,
            flowState: flowState,
            calculatedAt: now
        )
    }

    private func computeStreakDays(sessions: [FocusSession], calendar: Calendar, now: Date) -> Int {
        guard !sessions.isEmpty else { return 0 }
        let completionDays = Set(sessions.map { calendar.startOfDay(for: $0.startTime) })
        var streak = 0
        var cursor = calendar.startOfDay(for: now)

        while completionDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return streak
    }

    private func computeAverageRecovery(sessions: [FocusSession]) -> TimeInterval {
        guard sessions.count > 1 else { return 0 }
        var intervals: [TimeInterval] = []
        for index in 0..<(sessions.count - 1) {
            let current = sessions[index]
            let next = sessions[index + 1]
            guard current.status == .abandoned, next.status == .completed else { continue }
            let end = current.endTime ?? current.startTime
            let interval = next.startTime.timeIntervalSince(end)
            if interval >= 0 {
                intervals.append(interval)
            }
        }

        guard !intervals.isEmpty else { return 0 }
        return intervals.reduce(0.0, +) / Double(intervals.count)
    }
}


