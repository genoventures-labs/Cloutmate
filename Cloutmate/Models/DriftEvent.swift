//
//  DriftEvent.swift
//  Cloutmate
//
//  Phase 9: Predictive Reflection Engine
//  Captures real-time focus or momentum drift detected by DriftMonitor
//

import Foundation
import SwiftData

/// Types of drift captured by the predictive cognition layer.
enum DriftEventType: String, Codable, CaseIterable, Sendable {
    case focus
    case momentum
    case energy

    var displayName: String {
        switch self {
        case .focus: return "Focus"
        case .momentum: return "Momentum"
        case .energy: return "Energy"
        }
    }
}

/// SwiftData model representing a detected drift event.
@Model
final class DriftEvent {
    @Attribute(.unique) var id: UUID

    /// When the drift was detected.
    var detectedAt: Date

    /// Backing storage for the drift type enum.
    private(set) var driftTypeRaw: String

    /// How severe the drift is (0 - 1, higher = more severe).
    var severity: Double

    /// Expected metric value at this time.
    var expectedValue: Double

    /// Actual observed metric value.
    var actualValue: Double

    /// Percentage deviation from expectation (positive numbers only).
    var deviation: Double

    /// Trigger or rule that generated the drift event (identifier used by service layer).
    var trigger: String

    /// Optional contextual snapshot (JSON or markdown summary).
    var contextSnapshot: String?

    /// Indicates whether the system or user acted on this drift.
    var wasActedOn: Bool

    /// Description of corrective action taken, if any.
    var actionTaken: String?

    /// Confidence in the drift detection (0 - 1).
    var confidence: Double

    /// Optional identifiers linking the drift back to other primary records.
    var relatedFocusSessionId: UUID?
    var relatedRitualCompletionId: UUID?

    init(
        driftType: DriftEventType,
        severity: Double,
        expectedValue: Double,
        actualValue: Double,
        deviation: Double,
        trigger: String,
        confidence: Double,
        contextSnapshot: String? = nil,
        relatedFocusSessionId: UUID? = nil,
        relatedRitualCompletionId: UUID? = nil
    ) {
        self.id = UUID()
        self.detectedAt = Date()
        self.driftTypeRaw = driftType.rawValue
        self.severity = min(max(severity, 0.0), 1.0)
        self.expectedValue = expectedValue
        self.actualValue = actualValue
        self.deviation = deviation
        self.trigger = trigger
        self.contextSnapshot = contextSnapshot
        self.wasActedOn = false
        self.actionTaken = nil
        self.confidence = min(max(confidence, 0.0), 1.0)
        self.relatedFocusSessionId = relatedFocusSessionId
        self.relatedRitualCompletionId = relatedRitualCompletionId
    }

    var driftType: DriftEventType {
        get { DriftEventType(rawValue: driftTypeRaw) ?? .focus }
        set { driftTypeRaw = newValue.rawValue }
    }

    /// Convenience metric representing the absolute deviation ratio (actual/expected).
    var deviationRatio: Double {
        guard expectedValue != 0 else { return 0 }
        return actualValue / expectedValue
    }

    func markActedOn(with description: String? = nil) {
        wasActedOn = true
        actionTaken = description
    }
}

