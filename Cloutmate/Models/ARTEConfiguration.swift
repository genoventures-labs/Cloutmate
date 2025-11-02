//
//  ARTEConfiguration.swift
//  Cloutmate
//
//  Phase 7: ARTE - Aurora Reactive Theme Engine
//  User preferences and calibration data for ARTE
//

import Foundation
import SwiftData

/// ARTE operation mode
enum ARTEMode: String, Codable, CaseIterable, Sendable {
    case auto = "auto"         // Fully automatic state detection
    case manual = "manual"     // User manually selects state
    case blend = "blend"       // Auto with manual overrides
    
    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .manual: return "Manual"
        case .blend: return "Blend"
        }
    }
    
    var description: String {
        switch self {
        case .auto:
            return "ARTE automatically adapts to your cognitive state"
        case .manual:
            return "You choose the emotional state manually"
        case .blend:
            return "ARTE adapts automatically but respects your overrides"
        }
    }
}

/// Persisted ARTE configuration
@Model
final class ARTEConfiguration {
    @Attribute(.unique) var id: UUID
    var isEnabled: Bool
    var modeRaw: String
    var intensity: Double
    var lockedStateRaw: String?
    var adaptiveTiming: Bool
    var learningEnabled: Bool
    var calibrationData: Data?
    var lastUpdated: Date
    
    // State override tracking
    var manualOverrideCount: Int
    var lastManualOverride: Date?
    
    init(
        isEnabled: Bool = true,
        mode: ARTEMode = .auto,
        intensity: Double = 0.7,
        lockedState: EmotionalState? = nil,
        adaptiveTiming: Bool = true,
        learningEnabled: Bool = true
    ) {
        self.id = UUID()
        self.isEnabled = isEnabled
        self.modeRaw = mode.rawValue
        self.intensity = intensity
        self.lockedStateRaw = lockedState?.rawValue
        self.adaptiveTiming = adaptiveTiming
        self.learningEnabled = learningEnabled
        self.calibrationData = nil
        self.lastUpdated = Date()
        self.manualOverrideCount = 0
        self.lastManualOverride = nil
    }
    
    var mode: ARTEMode {
        get { ARTEMode(rawValue: modeRaw) ?? .auto }
        set { modeRaw = newValue.rawValue }
    }
    
    var lockedState: EmotionalState? {
        get {
            guard let raw = lockedStateRaw else { return nil }
            return EmotionalState(rawValue: raw)
        }
        set { lockedStateRaw = newValue?.rawValue }
    }
    
    /// Record a manual override
    func recordManualOverride() {
        manualOverrideCount += 1
        lastManualOverride = Date()
        lastUpdated = Date()
    }
    
    /// Get effective intensity (0.0-1.0 normalized)
    var effectiveIntensity: Double {
        return min(1.0, max(0.0, intensity))
    }
}

/// Learning calibration data
struct ARTECalibration: Codable {
    var focusedThreshold: Double
    var reflectiveThreshold: Double
    var energizedThreshold: Double
    var fatigueThreshold: Double
    var stateHistory: [StateHistoryEntry]
    var adaptationLevel: Double  // 0.0 - 1.0, how much to trust learning
    
    struct StateHistoryEntry: Codable {
        let state: String
        let timestamp: Date
        let metrics: MetricsSnapshot
        let wasOverridden: Bool
    }
    
    struct MetricsSnapshot: Codable {
        let completionRate: Double
        let focusSessionActive: Bool
        let emotionalValence: Double
        let cpsDelta: Double
    }
    
    static var initial: ARTECalibration {
        ARTECalibration(
            focusedThreshold: 0.7,
            reflectiveThreshold: 0.5,
            energizedThreshold: 0.75,
            fatigueThreshold: 0.3,
            stateHistory: [],
            adaptationLevel: 0.0
        )
    }
}

