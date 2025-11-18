//
//  EmotionalStateDetector.swift
//  FocusOS
//
//  Phase 7: ARTE - Aurora Reactive Theme Engine
//  Analyzes Intelligence Layer metrics to detect current emotional-cognitive state
//

import Foundation
import SwiftData
import os.log

@MainActor
final class EmotionalStateDetector {
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "ARTE")
    
    // Detection thresholds (start with general heuristics, adapt over time)
    private var focusedThreshold: Double = 0.7
    private var energizedThreshold: Double = 0.75
    private var fatigueThreshold: Double = 0.3
    private var reflectiveThreshold: Double = 0.5
    
    /// Detect current emotional state from analytics snapshot
    func detectState(
        from snapshot: AnalyticsSnapshot,
        calibration: ARTECalibration? = nil,
        modelContext: ModelContext
    ) -> EmotionalStateDetection {
        // Apply learned calibration if available
        if let cal = calibration {
            focusedThreshold = cal.focusedThreshold
            energizedThreshold = cal.energizedThreshold
            fatigueThreshold = cal.fatigueThreshold
            reflectiveThreshold = cal.reflectiveThreshold
        }
        
        // Calculate weighted scores for each state
        let focusScore = calculateFocusScore(snapshot: snapshot)
        let energizedScore = calculateEnergizedScore(snapshot: snapshot)
        let fatigueScore = calculateFatigueScore(snapshot: snapshot)
        let reflectiveScore = calculateReflectiveScore(snapshot: snapshot, modelContext: modelContext)
        let calmScore = calculateCalmScore(snapshot: snapshot)
        
        // Find dominant state
        let scores: [(EmotionalState, Double)] = [
            (.focused, focusScore),
            (.energized, energizedScore),
            (.fatigued, fatigueScore),
            (.reflective, reflectiveScore),
            (.calm, calmScore)
        ]
        
        let sorted = scores.sorted { $0.1 > $1.1 }
        let primaryState = sorted[0]
        let secondaryState = sorted[1]
        
        logger.info("ARTE State Detection: \(primaryState.0.rawValue) (confidence: \(String(format: "%.2f", primaryState.1)))")
        
        return EmotionalStateDetection(
            state: primaryState.0,
            confidence: primaryState.1,
            secondaryState: secondaryState.1 > 0.4 ? secondaryState.0 : nil
        )
    }
    
    // MARK: - State Score Calculations
    
    private func calculateFocusScore(snapshot: AnalyticsSnapshot) -> Double {
        var score: Double = 0.0
        
        // Active focus session is strongest signal
        if snapshot.focusSessionsCount > 0 {
            score += 0.5
            
            // High completion rate reinforces focus
            if snapshot.focusCompletionRate > 0.7 {
                score += 0.3
            }
        }
        
        // High CPS engagement (top priorities being worked on)
        if snapshot.avgPriorityScore > 0.7 {
            score += 0.2
        }
        
        // Recent task activity without distraction
        if snapshot.completionRate > 0.6 && snapshot.completionRate < 0.9 {
            score += 0.1
        }
        
        return min(1.0, score)
    }
    
    private func calculateEnergizedScore(snapshot: AnalyticsSnapshot) -> Double {
        var score: Double = 0.0
        
        // High completion rate
        if snapshot.completionRate > energizedThreshold {
            score += 0.4
        }
        
        // Positive emotional valence
        if snapshot.emotionalSnapshot.valence > 0.3 {
            score += 0.3
        }
        
        // Multiple tasks completed
        if snapshot.tasksCompleted > 3 {
            score += 0.2
        }
        
        // High emotional intensity (but positive)
        if snapshot.emotionalSnapshot.intensity > 0.6 && snapshot.emotionalSnapshot.valence > 0 {
            score += 0.2
        }
        
        return min(1.0, score)
    }
    
    private func calculateFatigueScore(snapshot: AnalyticsSnapshot) -> Double {
        var score: Double = 0.0
        
        // Low completion rate
        if snapshot.completionRate < fatigueThreshold {
            score += 0.3
        }
        
        // Extended session times without completion
        if snapshot.focusSessionsCount > 0 && snapshot.focusCompletionRate < 0.4 {
            score += 0.3
        }
        
        // Declining emotional trend
        if snapshot.emotionalTrend == EmotionalTrend.declining {
            score += 0.2
        }
        
        // Time-of-day heuristic (late evening/early morning)
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 22 || hour <= 6 {
            score += 0.2
        }
        
        // Low emotional energy
        if snapshot.emotionalSnapshot.valence < -0.2 {
            score += 0.2
        }
        
        return min(1.0, score)
    }
    
    private func calculateReflectiveScore(snapshot: AnalyticsSnapshot, modelContext: ModelContext) -> Double {
        var score: Double = 0.0
        
        // High memory graph interaction (concepts being explored)
        if snapshot.activeThemes > 3 {
            score += 0.3
        }
        
        // Low task activity but high graph density
        if snapshot.completionRate < 0.5 && snapshot.graphDensity > 0.5 {
            score += 0.3
        }
        
        // Neutral to slightly negative valence (contemplative)
        if snapshot.emotionalSnapshot.valence >= -0.2 && snapshot.emotionalSnapshot.valence <= 0.2 {
            score += 0.2
        }
        
        // Recent Memory Graph or Insights exploration
        // Check if user is in Insights tab (would require additional context)
        // For now, use graph metrics as proxy
        if snapshot.memoryNodes > 5 {
            score += 0.2
        }
        
        return min(1.0, score)
    }
    
    private func calculateCalmScore(snapshot: AnalyticsSnapshot) -> Double {
        var score: Double = 0.0
        
        // Moderate completion rate (steady but not rushing)
        if snapshot.completionRate >= 0.4 && snapshot.completionRate <= 0.7 {
            score += 0.3
        }
        
        // Neutral emotional valence
        if abs(snapshot.emotionalSnapshot.valence) < 0.3 {
            score += 0.3
        }
        
        // Stable emotional trend
        if snapshot.emotionalTrend == EmotionalTrend.stable {
            score += 0.2
        }
        
        // Moderate intensity (not too high, not too low)
        if snapshot.emotionalSnapshot.intensity >= 0.3 && snapshot.emotionalSnapshot.intensity <= 0.6 {
            score += 0.2
        }
        
        return min(1.0, score)
    }
    
    // MARK: - Learning Adaptation
    
    /// Update detection thresholds based on user overrides
    func adaptThresholds(from history: [StateTransitionHistory]) {
        guard !history.isEmpty else { return }
        
        // Filter for manual overrides (these tell us when our detection was wrong)
        let overrides = history.filter { $0.wasManualOverride }
        
        guard !overrides.isEmpty else { return }
        
        // Analyze patterns in overrides
        // If user frequently overrides from state A to state B, adjust A's threshold
        var stateOverrides: [EmotionalState: [StateTransitionHistory]] = [:]
        for override in overrides {
            stateOverrides[override.fromState, default: []].append(override)
        }
        
        // Adjust thresholds slightly (conservative learning)
        for (fromState, transitions) in stateOverrides {
            let avgCompletionRate = transitions.map { $0.completionRate }.reduce(0, +) / Double(transitions.count)
            
            switch fromState {
            case .focused:
                focusedThreshold = lerp(focusedThreshold, avgCompletionRate, t: 0.1)
            case .energized:
                energizedThreshold = lerp(energizedThreshold, avgCompletionRate, t: 0.1)
            case .fatigued:
                fatigueThreshold = lerp(fatigueThreshold, avgCompletionRate, t: 0.1)
            case .reflective:
                reflectiveThreshold = lerp(reflectiveThreshold, avgCompletionRate, t: 0.1)
            case .calm:
                break // Calm is baseline, doesn't need adjustment
            }
        }
        
        logger.info("ARTE thresholds adapted based on \(overrides.count) user overrides")
    }
    
    /// Linear interpolation helper
    private func lerp(_ a: Double, _ b: Double, t: Double) -> Double {
        return a + (b - a) * t
    }
    
    /// Get current calibration state
    func getCurrentCalibration() -> ARTECalibration {
        return ARTECalibration(
            focusedThreshold: focusedThreshold,
            reflectiveThreshold: reflectiveThreshold,
            energizedThreshold: energizedThreshold,
            fatigueThreshold: fatigueThreshold,
            stateHistory: [],
            adaptationLevel: 0.0
        )
    }
}

