//
//  CognitionPredictor.swift
//  Cloutmate
//
//  Phase 9: Predictive Reflection Engine
//  Generates anticipatory cognition forecasts every few hours
//

import Foundation
import SwiftData
import Combine
import os.log

private struct PredictionContext {
    let windowStart: Date
    let windowEnd: Date
    let ritualCompletions: [RitualCompletion]
    let focusSessions: [FocusSession]
    let stateTransitions: [StateTransitionHistory]
    let nudges: [SmartNudge]
}

@MainActor
final class CognitionPredictor: ObservableObject {
    static let shared = CognitionPredictor()

    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "CognitionPredictor")
    private var predictionTimer: Timer?
    private var isRunning = false
    private let forecastSubject = PassthroughSubject<FocusForecast, Never>()

    var forecastPublisher: AnyPublisher<FocusForecast, Never> {
        forecastSubject.eraseToAnyPublisher()
    }

    private init() {}

    // MARK: - Lifecycle

    func start(modelContext: ModelContext) async {
        guard !isRunning else {
            refreshTimer(modelContext: modelContext)
            return
        }

        guard UserDefaults.standard.bool(forKey: "predictiveModeEnabled") else {
            logger.info("Predictive mode disabled – skipping predictor start")
            return
        }

        isRunning = true
        logger.info("Starting cognition predictor")
        await runPredictionCycle(modelContext: modelContext)
        scheduleTimer(modelContext: modelContext)
    }

    func stop() {
        predictionTimer?.invalidate()
        predictionTimer = nil
        isRunning = false
        logger.info("Stopped cognition predictor")
    }

    func refreshTimer(modelContext: ModelContext) {
        guard isRunning else { return }
        scheduleTimer(modelContext: modelContext)
    }

    // MARK: - Prediction

    func runPredictionCycle(modelContext: ModelContext) async {
        let now = Date()
        let windowEnd = now
        guard let windowStart = Calendar.current.date(byAdding: .hour, value: -48, to: now) else { return }

        logger.debug("Running cognition prediction cycle")

        let context = gatherContext(windowStart: windowStart, windowEnd: windowEnd, modelContext: modelContext)
        let forecast = generateForecast(context: context)

        modelContext.insert(forecast)
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save forecast: \(error.localizedDescription)")
        }

        ToneProfileCache.shared.markPredictionRun(at: now)
        forecastSubject.send(forecast)

        evaluateHistoricalForecasts(modelContext: modelContext)
    }

    func predictEnergyWindows(
        daysAhead: Int,
        modelContext: ModelContext
    ) async -> [EnergyWindow] {
        guard daysAhead > 0 else { return [] }

        let now = Date()
        let calendar = Calendar.current

        // Normalize start to next full hour for cleaner window boundaries
        let normalizedStart = calendar.nextDate(
            after: now,
            matching: DateComponents(minute: 0, second: 0),
            matchingPolicy: .nextTimePreservingSmallerComponents
        ) ?? now

        // 1. Historical focus performance (last 14 days)
        let sessionCutoff = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        let sessionDescriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { session in
                session.startTime >= sessionCutoff
            }
        )
        let historicalSessions = (try? modelContext.fetch(sessionDescriptor)) ?? []

        var sessionScores = Array(repeating: 0.0, count: 24)
        var sessionCounts = Array(repeating: 0, count: 24)

        for session in historicalSessions {
            let hour = calendar.component(.hour, from: session.startTime)
            let effectiveness: Double
            if session.status == .completed {
                effectiveness = 1.0
            } else {
                let ratio = session.plannedDuration <= 0 ? 0.0 : session.actualDuration / session.plannedDuration
                effectiveness = clamp(ratio, min: 0.1, max: 1.0)
            }

            sessionScores[hour] += effectiveness
            sessionCounts[hour] += 1
        }

        var sessionAverages = Array(repeating: 0.5, count: 24)
        for hour in 0..<24 {
            if sessionCounts[hour] > 0 {
                sessionAverages[hour] = sessionScores[hour] / Double(sessionCounts[hour])
            }
        }

        // 2. ARTE state transitions (last 7 days)
        let transitionCutoff = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let transitionDescriptor = FetchDescriptor<StateTransitionHistory>(
            predicate: #Predicate { transition in
                transition.timestamp >= transitionCutoff
            }
        )
        let transitions = (try? modelContext.fetch(transitionDescriptor)) ?? []

        var arteScores = Array(repeating: 0.0, count: 24)
        var arteCounts = Array(repeating: 0, count: 24)
        for transition in transitions {
            let hour = calendar.component(.hour, from: transition.timestamp)
            let weight: Double
            switch transition.toState {
            case .energized:
                weight = 1.0
            case .focused:
                weight = 0.85
            case .calm:
                weight = 0.6
            case .reflective:
                weight = 0.45
            case .fatigued:
                weight = 0.15
            }

            arteScores[hour] += weight * transition.confidence
            arteCounts[hour] += 1
        }

        var arteAverages = Array(repeating: 0.5, count: 24)
        for hour in 0..<24 {
            if arteCounts[hour] > 0 {
                arteAverages[hour] = clamp(arteScores[hour] / Double(arteCounts[hour]), min: 0.0, max: 1.0)
            }
        }

        // 3. Combine into hourly energy map
        let latestForecast = fetchLatestForecast(modelContext: modelContext)
        var hourlyEnergy = Array(repeating: 0.5, count: 24)
        var hourlyConfidence = Array(repeating: 0.35, count: 24)
        for hour in 0..<24 {
            let combined = (sessionAverages[hour] * 0.6) + (arteAverages[hour] * 0.4)
            hourlyEnergy[hour] = clamp(combined, min: 0.0, max: 1.0)

            let sessionContribution = min(0.5, Double(sessionCounts[hour]) / 10.0 * 0.5)
            let arteContribution = min(0.3, Double(arteCounts[hour]) / 8.0 * 0.3)
            hourlyConfidence[hour] = clamp(0.2 + sessionContribution + arteContribution, min: 0.2, max: 0.85)
        }

        adjustHourlyMaps(
            hourlyEnergy: &hourlyEnergy,
            hourlyConfidence: &hourlyConfidence,
            latestForecast: latestForecast,
            currentDate: now
        )

        // 4. Build future windows by scanning through upcoming hours
        let forecastEnd = calendar.date(byAdding: .day, value: daysAhead, to: normalizedStart) ?? normalizedStart
        var pointer = normalizedStart

        var tempWindows: [(start: Date, end: Date, energy: Double, confidence: Double)] = []
        var currentStart: Date?
        var energyAccum: Double = 0.0
        var confidenceAccum: Double = 0.0
        var slotCount = 0

        while pointer < forecastEnd {
            let hour = calendar.component(.hour, from: pointer)
            let energyScore = hourlyEnergy[hour]
            let confidenceScore = hourlyConfidence[hour]

            if energyScore >= 0.55 {
                if currentStart == nil {
                    currentStart = pointer
                    energyAccum = 0.0
                    confidenceAccum = 0.0
                    slotCount = 0
                }
                energyAccum += energyScore
                confidenceAccum += confidenceScore
                slotCount += 1
            } else if let start = currentStart, slotCount > 0 {
                let end = pointer
                let avgEnergy = energyAccum / Double(slotCount)
                let avgConfidence = clamp(confidenceAccum / Double(slotCount), min: 0.2, max: 0.95)
                tempWindows.append((start: start, end: end, energy: avgEnergy, confidence: avgConfidence))
                currentStart = nil
            }

            guard let nextHour = calendar.date(byAdding: .hour, value: 1, to: pointer) else { break }
            pointer = nextHour
        }

        if let start = currentStart, slotCount > 0 {
            let end = min(forecastEnd, calendar.date(byAdding: .hour, value: slotCount, to: start) ?? forecastEnd)
            let avgEnergy = energyAccum / Double(slotCount)
            let avgConfidence = clamp(confidenceAccum / Double(slotCount), min: 0.2, max: 0.95)
            tempWindows.append((start: start, end: end, energy: avgEnergy, confidence: avgConfidence))
        }

        if tempWindows.isEmpty {
            let fallbackStart = normalizedStart.addingTimeInterval(3_600)
            let fallbackEnd = fallbackStart.addingTimeInterval(90 * 60)
            tempWindows.append((start: fallbackStart, end: fallbackEnd, energy: 0.6, confidence: 0.4))
        }

        let sortedWindows = tempWindows
            .sorted { lhs, rhs in
                if abs(lhs.energy - rhs.energy) < 0.05 {
                    return lhs.start < rhs.start
                }
                return lhs.energy > rhs.energy
            }
            .prefix(6)

        // Persist new windows (replace prior predictions)
        let existingDescriptor = FetchDescriptor<EnergyWindow>()
        if let existing = try? modelContext.fetch(existingDescriptor) {
            for window in existing {
                modelContext.delete(window)
            }
        }

        var result: [EnergyWindow] = []
        for item in sortedWindows {
            let energyWindow = EnergyWindow(
                windowStart: item.start,
                windowEnd: item.end,
                predictedEnergyScore: clamp(item.energy, min: 0.0, max: 1.0),
                confidence: clamp(item.confidence, min: 0.0, max: 1.0)
            )
            modelContext.insert(energyWindow)
            result.append(energyWindow)
        }

        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to persist energy windows: \(error.localizedDescription)")
        }

        return result
    }

    // MARK: - Internal Helpers

    private func scheduleTimer(modelContext: ModelContext) {
        predictionTimer?.invalidate()
        let interval = currentInterval()
        predictionTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.runPredictionCycle(modelContext: modelContext)
            }
        }
        logger.info("Cognition predictor timer scheduled every \(interval) seconds")
    }

    private func currentInterval() -> TimeInterval {
        let stored = UserDefaults.standard.integer(forKey: "forecastInterval")
        switch stored {
        case 1:
            return 3_600 // 1 hour
        case 4:
            return 14_400 // 4 hours
        default:
            return 7_200 // 2 hours default
        }
    }

    private func gatherContext(windowStart: Date, windowEnd: Date, modelContext: ModelContext) -> PredictionContext {
        let completionDescriptor = FetchDescriptor<RitualCompletion>(
            predicate: #Predicate { completion in
                completion.completedAt >= windowStart && completion.completedAt <= windowEnd
            }
        )

        let focusDescriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { session in
                session.startTime >= windowStart && session.startTime <= windowEnd
            }
        )

        let transitionDescriptor = FetchDescriptor<StateTransitionHistory>(
            predicate: #Predicate { transition in
                transition.timestamp >= windowStart && transition.timestamp <= windowEnd
            }
        )

        let nudgeDescriptor = FetchDescriptor<SmartNudge>(
            predicate: #Predicate { nudge in
                nudge.createdAt >= windowStart && nudge.createdAt <= windowEnd
            }
        )

        let completions = (try? modelContext.fetch(completionDescriptor)) ?? []
        let sessions = (try? modelContext.fetch(focusDescriptor)) ?? []
        let transitions = (try? modelContext.fetch(transitionDescriptor)) ?? []
        let nudges = (try? modelContext.fetch(nudgeDescriptor)) ?? []

        return PredictionContext(
            windowStart: windowStart,
            windowEnd: windowEnd,
            ritualCompletions: completions,
            focusSessions: sessions,
            stateTransitions: transitions,
            nudges: nudges
        )
    }

    private func generateForecast(context: PredictionContext) -> FocusForecast {
        let horizonStart = Date()
        let horizonEnd = horizonStart.addingTimeInterval(currentInterval())

        let fatigueMetrics = computeFatigueMetrics(context: context)
        let focusStability = computeFocusStability(sessions: context.focusSessions)
        let energyTrend = determineEnergyTrend(context: context)
        let nextWindow = estimateNextFocusWindow(sessions: context.focusSessions)
        let confidence = computeConfidence(
            context: context,
            fatigueRisk: fatigueMetrics.fatigueRisk,
            focusStability: focusStability
        )

        var metadata: [String: String] = [:]
        metadata["ritualCompletionRate"] = String(format: "%.2f", fatigueMetrics.completionRate)
        metadata["fatigueComponentRitual"] = String(format: "%.2f", fatigueMetrics.ritualComponent)
        metadata["fatigueComponentFocus"] = String(format: "%.2f", fatigueMetrics.focusComponent)
        metadata["fatigueComponentArte"] = String(format: "%.2f", fatigueMetrics.arteComponent)
        metadata["nudgesLast48h"] = String(context.nudges.count)

        return FocusForecast(
            horizonStart: horizonStart,
            horizonEnd: horizonEnd,
            fatigueRisk: fatigueMetrics.fatigueRisk,
            focusStability: focusStability,
            energyTrend: energyTrend,
            toneRecommendation: fatigueMetrics.recommendedTone,
            confidence: confidence,
            nextFocusWindowStart: nextWindow?.start,
            nextFocusWindowEnd: nextWindow?.end,
            metadata: metadata
        )
    }

    private func computeFatigueMetrics(context: PredictionContext) -> (fatigueRisk: Double, completionRate: Double, ritualComponent: Double, focusComponent: Double, arteComponent: Double, recommendedTone: EmotionalState) {
        let completions = context.ritualCompletions
        let completedCount = completions.filter { $0.outcome == .completed }.count
        let completionRate = completions.isEmpty ? 1.0 : Double(completedCount) / Double(completions.count)
        let ritualComponent = 1.0 - completionRate

        let completedSessions = context.focusSessions.filter { $0.status == .completed }
        let averageActual = completedSessions.isEmpty ? 0.0 : completedSessions.reduce(0.0) { $0 + $1.actualDuration } / Double(completedSessions.count)
        let averagePlanned = completedSessions.isEmpty ? 1.0 : completedSessions.reduce(0.0) { $0 + $1.plannedDuration } / Double(completedSessions.count)
        let focusRatio = averagePlanned == 0 ? 1.0 : min(averageActual / averagePlanned, 1.0)
        let focusComponent = 1.0 - focusRatio

        let fatiguedTransitions = context.stateTransitions.filter { $0.toState == .fatigued }
        let arteComponent = context.stateTransitions.isEmpty ? 0.0 : Double(fatiguedTransitions.count) / Double(context.stateTransitions.count)

        let fatigueRisk = min(max(0.3 * ritualComponent + 0.4 * focusComponent + 0.3 * arteComponent, 0.0), 1.0)

        let recommendedTone: EmotionalState
        if fatigueRisk > 0.65 {
            recommendedTone = .fatigued
        } else if focusComponent > 0.4 {
            recommendedTone = .reflective
        } else if ritualComponent < 0.2 && arteComponent < 0.2 {
            recommendedTone = .energized
        } else {
            recommendedTone = .calm
        }

        return (fatigueRisk, completionRate, ritualComponent, focusComponent, arteComponent, recommendedTone)
    }

    private func computeFocusStability(sessions: [FocusSession]) -> Double {
        let completed = sessions.filter { $0.status == .completed }
        guard !completed.isEmpty else { return 0.6 }

        let durations = completed.map { max($0.actualDuration, 1) }
        let mean = durations.reduce(0.0, +) / Double(durations.count)
        guard mean > 0 else { return 0.0 }
        let variance = durations.reduce(0.0) { partial, value in
            let diff = value - mean
            return partial + diff * diff
        } / Double(durations.count)
        let stdDev = sqrt(variance)
        let coefficientOfVariation = min(stdDev / mean, 1.0)
        return max(0.0, 1.0 - coefficientOfVariation)
    }

    private func determineEnergyTrend(context: PredictionContext) -> FocusEnergyTrend {
        guard !context.focusSessions.isEmpty || !context.ritualCompletions.isEmpty else {
            return .stable
        }

        let midpoint = context.windowStart.addingTimeInterval((context.windowEnd.timeIntervalSince(context.windowStart)) / 2)

        let firstHalfSessions = context.focusSessions.filter { $0.startTime < midpoint }
        let secondHalfSessions = context.focusSessions.filter { $0.startTime >= midpoint }

        let firstHalfScore = Double(firstHalfSessions.filter { $0.status == .completed }.count)
        let secondHalfScore = Double(secondHalfSessions.filter { $0.status == .completed }.count)

        let firstHalfRituals = context.ritualCompletions.filter { $0.completedAt < midpoint && $0.outcome == .completed }.count
        let secondHalfRituals = context.ritualCompletions.filter { $0.completedAt >= midpoint && $0.outcome == .completed }.count

        let aggregateFirst = firstHalfScore + Double(firstHalfRituals)
        let aggregateSecond = secondHalfScore + Double(secondHalfRituals)

        if aggregateSecond > aggregateFirst * 1.1 {
            return .rising
        } else if aggregateSecond < aggregateFirst * 0.9 {
            return .declining
        } else {
            return .stable
        }
    }

    private func estimateNextFocusWindow(sessions: [FocusSession]) -> DateInterval? {
        let completedSessions = sessions.filter { $0.status == .completed }
        guard !completedSessions.isEmpty else { return nil }

        var hourBuckets: [Int: Double] = [:]
        let calendar = Calendar.current
        for session in completedSessions {
            let hour = calendar.component(.hour, from: session.startTime)
            hourBuckets[hour, default: 0.0] += session.actualDuration
        }

        guard let bestHour = hourBuckets.max(by: { $0.value < $1.value })?.key else { return nil }

        let nextStart = calendar.nextDate(after: Date(), matching: DateComponents(hour: bestHour), matchingPolicy: .nextTimePreservingSmallerComponents) ?? Date().addingTimeInterval(3_600)
        let nextEnd = nextStart.addingTimeInterval(7_200) // 2-hour window
        return DateInterval(start: nextStart, end: nextEnd)
    }

    private func computeConfidence(context: PredictionContext, fatigueRisk: Double, focusStability: Double) -> Double {
        var confidence = 0.55
        if context.ritualCompletions.count >= 6 { confidence += 0.1 }
        if context.focusSessions.count >= 4 { confidence += 0.1 }
        if context.stateTransitions.count >= 5 { confidence += 0.1 }
        if focusStability > 0.7 { confidence += 0.05 }
        if fatigueRisk < 0.3 { confidence += 0.05 }
        return min(confidence, 0.95)
    }

    private func evaluateHistoricalForecasts(modelContext: ModelContext) {
        let now = Date()
        let descriptor = FetchDescriptor<FocusForecast>(
            predicate: #Predicate<FocusForecast> { forecast in
                forecast.predictionAccuracy == nil && forecast.horizonEnd < now
            },
            sortBy: [SortDescriptor(\.horizonEnd, order: .forward)]
        )

        guard let pastForecasts = try? modelContext.fetch(descriptor), !pastForecasts.isEmpty else { return }

        for forecast in pastForecasts {
            let context = gatherContext(windowStart: forecast.horizonStart, windowEnd: forecast.horizonEnd, modelContext: modelContext)
            let actualMetrics = computeFatigueMetrics(context: context)
            let accuracy = 1.0 - min(abs(actualMetrics.fatigueRisk - forecast.fatigueRisk), 1.0)
            forecast.recordAccuracy(accuracy)
        }

        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to update forecast accuracy: \(error.localizedDescription)")
        }
    }

    private func adjustHourlyMaps(
        hourlyEnergy: inout [Double],
        hourlyConfidence: inout [Double],
        latestForecast: FocusForecast?,
        currentDate: Date
    ) {
        guard let forecast = latestForecast else { return }
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: currentDate)

        if let focusWindow = forecast.nextFocusWindow {
            var pointer = focusWindow.start
            while pointer < focusWindow.end {
                let hour = calendar.component(.hour, from: pointer)
                hourlyEnergy[hour] = clamp(hourlyEnergy[hour] + 0.15 + forecast.focusStability * 0.1, min: 0.0, max: 1.0)
                hourlyConfidence[hour] = clamp(max(hourlyConfidence[hour], forecast.confidence), min: 0.2, max: 1.0)
                guard let nextHour = calendar.date(byAdding: .hour, value: 1, to: pointer) else { break }
                pointer = nextHour
            }
        }

        let horizonHours = max(1, Int(forecast.forecastHorizon.duration / 3_600))
        for offset in 0..<min(8, horizonHours + 2) {
            let index = (currentHour + offset) % 24
            switch forecast.energyTrend {
            case .rising:
                hourlyEnergy[index] = clamp(hourlyEnergy[index] + 0.08, min: 0.0, max: 1.0)
            case .declining:
                hourlyEnergy[index] = clamp(hourlyEnergy[index] - 0.08, min: 0.0, max: 1.0)
                hourlyConfidence[index] = clamp(hourlyConfidence[index] - 0.04, min: 0.2, max: 1.0)
            case .stable:
                break
            }
        }

        if forecast.fatigueRisk > 0.65 {
            for offset in 0..<4 {
                let index = (currentHour + offset) % 24
                hourlyEnergy[index] = clamp(hourlyEnergy[index] - 0.12, min: 0.0, max: 1.0)
                hourlyConfidence[index] = clamp(hourlyConfidence[index] - 0.05, min: 0.2, max: 1.0)
            }
        } else if forecast.fatigueRisk < 0.3 {
            for offset in 0..<4 {
                let index = (currentHour + offset) % 24
                hourlyEnergy[index] = clamp(hourlyEnergy[index] + 0.07, min: 0.0, max: 1.0)
                hourlyConfidence[index] = clamp(hourlyConfidence[index] + 0.04, min: 0.2, max: 1.0)
            }
        }
    }

    private func fetchLatestForecast(modelContext: ModelContext) -> FocusForecast? {
        var descriptor = FetchDescriptor<FocusForecast>(
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first ?? nil
    }

    private func clamp(_ value: Double, min lower: Double, max upper: Double) -> Double {
        return max(lower, min(value, upper))
    }
}


