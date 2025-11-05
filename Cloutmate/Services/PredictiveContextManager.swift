//
//  PredictiveContextManager.swift
//  Cloutmate
//
//  Phase 9: Predictive Reflection Engine
//  Bridges cognition forecasts to tone adaptation and proactive nudges
//

import Foundation
import SwiftData
import Combine
import os.log

@MainActor
final class PredictiveContextManager: ObservableObject {
    static let shared = PredictiveContextManager()

    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "PredictiveContextManager")
    private var cancellables = Set<AnyCancellable>()
    private weak var modelContext: ModelContext?
    private var latestForecast: FocusForecast?

    private init() {}

    func start(modelContext: ModelContext) async {
        self.modelContext = modelContext
        cancellables.removeAll()

        CognitionPredictor.shared.forecastPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] forecast in
                guard let self else { return }
                self.latestForecast = forecast
                self.handleForecast(forecast)
            }
            .store(in: &cancellables)

        DriftMonitor.shared.driftPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                self?.handleDriftEvent(event)
            }
            .store(in: &cancellables)

        logger.info("Predictive context manager active")
    }

    func stop() {
        cancellables.removeAll()
    }

    // MARK: - Forecast Handling

    private func handleForecast(_ forecast: FocusForecast) {
        updateToneProfile(for: forecast)
        updateSuppressionFlags(for: forecast)
    }

    private func updateToneProfile(for forecast: FocusForecast) {
        guard UserDefaults.standard.bool(forKey: "toneAdaptationEnabled") else {
            logger.debug("Tone adaptation disabled by user settings")
            return
        }
        let threshold = ToneProfileCache.shared.confidenceThreshold
        guard forecast.confidence >= threshold else {
            logger.debug("Forecast confidence below threshold (\(forecast.confidence)). Skipping tone adaptation")
            return
        }

        var profile = ToneProfileCache.shared.load()
        var weights = profile.toneWeights

        for state in EmotionalState.allCases {
            let current = weights[state] ?? 1.0
            if state == forecast.toneRecommendation {
                let boost = 0.15 + 0.35 * forecast.confidence
                weights[state] = min(current + boost, 1.8)
            } else {
                weights[state] = max(current * 0.92, 0.6)
            }
        }

        ToneProfileCache.shared.setToneWeights(weights)
        logger.info("Tone profile adjusted for \(forecast.toneRecommendation.rawValue)")
    }

    private func updateSuppressionFlags(for forecast: FocusForecast) {
        if forecast.fatigueRisk > 0.65 {
            ToneProfileCache.shared.setSuppressionFlag(true, for: "fatigue_suppression")
        } else {
            ToneProfileCache.shared.setSuppressionFlag(false, for: "fatigue_suppression")
        }
    }

    // MARK: - Drift Handling

    private func handleDriftEvent(_ event: DriftEvent) {
        guard let context = modelContext else { return }

        if event.severity > 0.2 {
            triggerProactiveNudge(for: event, modelContext: context)
        }

        if event.driftType == .energy && event.severity > 0.3 {
            ToneProfileCache.shared.setSuppressionFlag(true, for: "energy_conservation")
        }
    }

    private func triggerProactiveNudge(for event: DriftEvent, modelContext: ModelContext) {
        let tone = NudgeToneAdapter.shared.tone(for: .fatiguedState)
        let message: String
        let detail: String

        switch event.driftType {
        case .focus:
            message = "Focus is dipping. Want to reset with a quick ritual?"
            detail = "Progress fell below expectations during your current session."
        case .momentum:
            message = "Momentum is slipping. Ready for a micro-break?"
            detail = "Momentum drift detected—taking a pause could help you recover."
        case .energy:
            message = "Energy trending low. Schedule a recharge?"
            detail = "Energy levels are declining faster than expected."
        }

        SmartNudgeService.shared.deliverPredictiveNudge(
            trigger: .fatiguedState,
            tone: tone,
            message: message,
            detail: detail,
            metadata: [
                "driftSeverity": String(format: "%.2f", event.severity),
                "expected": String(format: "%.2f", event.expectedValue),
                "actual": String(format: "%.2f", event.actualValue)
            ],
            modelContext: modelContext
        )
    }
}


