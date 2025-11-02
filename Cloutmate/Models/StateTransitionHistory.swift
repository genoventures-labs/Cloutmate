//
//  StateTransitionHistory.swift
//  Cloutmate
//
//  Phase 7: ARTE - Aurora Reactive Theme Engine
//  Tracks state transitions for learning and telemetry
//

import Foundation
import SwiftData

/// Records a state transition for learning and analytics
@Model
final class StateTransitionHistory {
    @Attribute(.unique) var id: UUID
    var fromStateRaw: String
    var toStateRaw: String
    var timestamp: Date
    var confidence: Double
    var wasManualOverride: Bool
    var transitionDuration: TimeInterval
    
    // Metrics at transition time
    var completionRate: Double
    var focusSessionActive: Bool
    var emotionalValence: Double
    var activeThemes: Int
    var timeOfDay: Int  // Hour (0-23)
    
    init(
        fromState: EmotionalState,
        toState: EmotionalState,
        confidence: Double,
        wasManualOverride: Bool = false,
        completionRate: Double = 0.0,
        focusSessionActive: Bool = false,
        emotionalValence: Double = 0.0,
        activeThemes: Int = 0
    ) {
        self.id = UUID()
        self.fromStateRaw = fromState.rawValue
        self.toStateRaw = toState.rawValue
        self.timestamp = Date()
        self.confidence = confidence
        self.wasManualOverride = wasManualOverride
        self.transitionDuration = 0.0
        self.completionRate = completionRate
        self.focusSessionActive = focusSessionActive
        self.emotionalValence = emotionalValence
        self.activeThemes = activeThemes
        
        let calendar = Calendar.current
        self.timeOfDay = calendar.component(.hour, from: Date())
    }
    
    var fromState: EmotionalState {
        EmotionalState(rawValue: fromStateRaw) ?? .calm
    }
    
    var toState: EmotionalState {
        EmotionalState(rawValue: toStateRaw) ?? .calm
    }
    
    /// Mark transition as completed
    func complete() {
        transitionDuration = Date().timeIntervalSince(timestamp)
    }
}

