//
//  EnergyWindow.swift
//  FocusOS
//
//  Phase 9B: Predictive energy windows for adaptive scheduling.
//

import Foundation
import SwiftData

@Model
final class EnergyWindow {
    @Attribute(.unique) var id: UUID
    var windowStart: Date
    var windowEnd: Date
    var predictedEnergyScore: Double
    var confidence: Double
    var generatedAt: Date

    init(
        windowStart: Date,
        windowEnd: Date,
        predictedEnergyScore: Double,
        confidence: Double,
        generatedAt: Date = Date()
    ) {
        self.id = UUID()
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.predictedEnergyScore = max(0.0, min(predictedEnergyScore, 1.0))
        self.confidence = max(0.0, min(confidence, 1.0))
        self.generatedAt = generatedAt
    }
}


