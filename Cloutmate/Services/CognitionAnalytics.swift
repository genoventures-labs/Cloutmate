//
//  CognitionAnalytics.swift
//  Cloutmate
//
//  Phase 9: Predictive Reflection Engine
//  Aggregates cognition forecasts and evaluates prediction performance
//

import Foundation
import SwiftData
import os.log

struct CognitionSummary {
    let averageAccuracy: Double
    let recentForecasts: [FocusForecast]
    let driftEventsCount: Int
    let nudgesTriggered: Int
    let toneAdaptationCount: Int
    let falsePositiveRate: Double
}

@MainActor
final class CognitionAnalytics {
    static let shared = CognitionAnalytics()

    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "CognitionAnalytics")

    private init() {}

    func calculateForecastAccuracy(days: Int, modelContext: ModelContext) -> Double {
        guard days > 0 else { return 0 }
        let calendar = Calendar.current
        guard let windowStart = calendar.date(byAdding: .day, value: -days, to: Date()) else { return 0 }

        let descriptor = FetchDescriptor<FocusForecast>(
            predicate: #Predicate { forecast in
                forecast.generatedAt >= windowStart && forecast.predictionAccuracy != nil
            }
        )

        guard let forecasts = try? modelContext.fetch(descriptor), !forecasts.isEmpty else {
            return 0
        }

        let total = forecasts.reduce(0.0) { partial, forecast in
            partial + (forecast.predictionAccuracy ?? 0.0)
        }
        return total / Double(forecasts.count)
    }

    func falsePositiveRate(modelContext: ModelContext) -> Double {
        let descriptor = FetchDescriptor<DriftEvent>()
        guard let events = try? modelContext.fetch(descriptor), !events.isEmpty else {
            return 0
        }

        let falsePositives = events.filter { !$0.wasActedOn && $0.severity < 0.3 }
        return Double(falsePositives.count) / Double(events.count)
    }

    func generateSummary(modelContext: ModelContext, limit: Int = 7) -> CognitionSummary {
        let forecastDescriptor = FetchDescriptor<FocusForecast>(
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        )
        let forecasts = (try? modelContext.fetch(forecastDescriptor)) ?? []
        let recentForecasts = Array(forecasts.prefix(limit))

        let driftWindowStart = Calendar.current.date(byAdding: .hour, value: -48, to: Date()) ?? Date().addingTimeInterval(-172_800)
        let driftDescriptor = FetchDescriptor<DriftEvent>(
            predicate: #Predicate { event in
                event.detectedAt >= driftWindowStart
            }
        )
        let driftEvents = (try? modelContext.fetch(driftDescriptor)) ?? []

        let nudgeDescriptor = FetchDescriptor<SmartNudge>(
            predicate: #Predicate { nudge in
                nudge.createdAt >= driftWindowStart
            }
        )
        let nudges = (try? modelContext.fetch(nudgeDescriptor)) ?? []

        let averageAccuracy = calculateForecastAccuracy(days: 7, modelContext: modelContext)
        let falsePositiveRate = self.falsePositiveRate(modelContext: modelContext)
        let toneAdaptations = ToneProfileCache.shared.recentAdaptationCount()

        return CognitionSummary(
            averageAccuracy: averageAccuracy,
            recentForecasts: recentForecasts,
            driftEventsCount: driftEvents.count,
            nudgesTriggered: nudges.count,
            toneAdaptationCount: toneAdaptations,
            falsePositiveRate: falsePositiveRate
        )
    }
}


