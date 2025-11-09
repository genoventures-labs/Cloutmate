//
//  AuroraInsightGenerator.swift
//  Cloutmate
//
//  Emotion + Focus pairing logic for contextual insights
//

import Foundation
import SwiftData
import CloutmateShared

@MainActor
final class AuroraInsightGenerator {
    static let shared = AuroraInsightGenerator()
    
    private init() {}
    
    /// Generate contextual insight combining emotion and focus patterns
    func generateEmotionFocusInsight(
        snapshot: AnalyticsSnapshot,
        focusStats: FocusSessionStats?,
        modelContext: ModelContext
    ) -> String {
        let focusConsistency = calculateFocusConsistency(snapshot: snapshot, focusStats: focusStats)
        let emotionalStability = calculateEmotionalStability(snapshot: snapshot, modelContext: modelContext)
        
        // Detect patterns
        if focusConsistency.isStable && !emotionalStability.isStable {
            // Stable focus but drifting emotion
            return "You've been consistent in focus but drifting emotionally—schedule a short ritual this evening."
        } else if focusConsistency.isStrong && emotionalStability.isRestless {
            // Strong focus but restless emotion
            return "Focus sessions are strong, but emotional state is restless—try a reflective journal entry."
        } else if emotionalStability.isStable && focusConsistency.isDeclining {
            // Stable emotion but declining focus
            return "Emotional stability improved while focus dipped—consider blocking time for deep work tomorrow."
        } else if focusConsistency.isImproving && emotionalStability.isImproving {
            // Both improving
            return "Focus and emotional consistency are aligning—you're building sustainable momentum."
        } else if focusConsistency.isDeclining && emotionalStability.isDeclining {
            // Both declining
            return "Both focus and emotional patterns are shifting—this might be a good time for a weekly review."
        } else if focusConsistency.isStrong && emotionalStability.isLow {
            // High focus + low emotion
            return "High focus output but emotional energy is low—consider grounding activities or rest."
        } else {
            // Default contextual insight
            return generateDefaultInsight(snapshot: snapshot, focusConsistency: focusConsistency, emotionalStability: emotionalStability)
        }
    }
    
    /// Generate forecast-based advice combining predicted focus with emotional state
    func generateForecastAdvice(
        forecast: FocusForecast,
        currentEmotionalState: EmotionalState
    ) -> String {
        let energyTrend = forecast.energyTrend
        let fatigueRisk = forecast.fatigueRisk
        
        // Check if focus peak aligns with emotional state
        if let nextWindow = forecast.nextFocusWindowStart {
            let hour = Calendar.current.component(.hour, from: nextWindow)
            
            switch currentEmotionalState {
            case .energized:
                if energyTrend == .rising {
                    return "Your focus peaks tomorrow morning, and you're in an energized state—prime time for creative work."
                } else {
                    return "Focus window aligns with your energized state—channel this energy into high-impact tasks."
                }
            case .focused:
                if energyTrend == .stable {
                    return "Predicted focus peak matches your current focused state—maintain this momentum."
                } else {
                    return "Focus window approaching while you're already focused—double down on deep work."
                }
            case .fatigued:
                if fatigueRisk > 0.6 {
                    return "Predicted focus dip aligns with fatigue risk—schedule lighter tasks and emotional recovery time."
                } else {
                    return "Focus window matches potential fatigue—prepare with rest and lighter workload."
                }
            case .reflective:
                return "Focus peak tomorrow morning, but you're in a reflective state—consider shifting reflection earlier to maximize focus time."
            case .calm:
                if energyTrend == .rising {
                    return "Focus window approaching with calm baseline—good conditions for steady progress."
                } else {
                    return "Predicted focus aligns with calm state—maintain balance and avoid overexertion."
                }
            }
        }
        
        // Fallback based on fatigue risk and energy trend
        if fatigueRisk > 0.6 {
            return "High fatigue risk detected—prioritize rest and recovery over extended focus sessions."
        } else if energyTrend == .rising {
            return "Energy trend is rising—prepare for productive focus windows ahead."
        } else if energyTrend == .declining {
            return "Energy trend declining—schedule important work earlier and plan for lighter tasks later."
        } else {
            return "Focus patterns are stable—maintain your current rhythm and routines."
        }
    }
    
    // MARK: - Helper Methods
    
    private struct FocusConsistency {
        let isStable: Bool
        let isStrong: Bool
        let isDeclining: Bool
        let isImproving: Bool
    }
    
    private struct EmotionalStability {
        let isStable: Bool
        let isRestless: Bool
        let isLow: Bool
        let isImproving: Bool
        let isDeclining: Bool
    }
    
    private func calculateFocusConsistency(
        snapshot: AnalyticsSnapshot,
        focusStats: FocusSessionStats?
    ) -> FocusConsistency {
        let completionRate = snapshot.completionRate
        let focusCompletionRate = snapshot.focusCompletionRate
        let focusSessionsCount = snapshot.focusSessionsCount
        
        let isStable = completionRate > 0.6 && abs(completionRate - focusCompletionRate) < 0.2
        let isStrong = completionRate > 0.75 && focusSessionsCount > 3
        let isDeclining = completionRate < 0.5 && snapshot.emotionalTrend == .declining
        let isImproving = completionRate > 0.7 && snapshot.emotionalTrend == .improving
        
        return FocusConsistency(
            isStable: isStable,
            isStrong: isStrong,
            isDeclining: isDeclining,
            isImproving: isImproving
        )
    }
    
    private func calculateEmotionalStability(
        snapshot: AnalyticsSnapshot,
        modelContext: ModelContext
    ) -> EmotionalStability {
        let valence = snapshot.emotionalSnapshot.valence
        let intensity = snapshot.emotionalSnapshot.intensity
        let trend = snapshot.emotionalTrend
        
        // Query recent state transitions for volatility check
        var descriptor = FetchDescriptor<StateTransitionHistory>(
            sortBy: [SortDescriptor(\StateTransitionHistory.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 7
        let recentTransitions = (try? modelContext.fetch(descriptor)) ?? []
        
        let transitionCount = recentTransitions.count
        let isRestless = transitionCount > 4 || trend == .volatile
        let isStable = abs(valence) < 0.3 && trend == .stable && transitionCount < 3
        let isLow = intensity < 0.3 || valence < -0.2
        let isImproving = trend == .improving && valence > 0
        let isDeclining = trend == .declining || (valence < -0.3 && intensity > 0.5)
        
        return EmotionalStability(
            isStable: isStable,
            isRestless: isRestless,
            isLow: isLow,
            isImproving: isImproving,
            isDeclining: isDeclining
        )
    }
    
    private func generateDefaultInsight(
        snapshot: AnalyticsSnapshot,
        focusConsistency: FocusConsistency,
        emotionalStability: EmotionalStability
    ) -> String {
        let completionRate = snapshot.completionRate
        let valence = snapshot.emotionalSnapshot.valence
        
        if completionRate > 0.7 && valence > 0.3 {
            return "Strong performance across focus and emotional metrics—keep this momentum going."
        } else if completionRate < 0.5 {
            return "Focus completion is below your usual pace—consider reviewing priorities and blocking time."
        } else if valence < -0.2 {
            return "Emotional patterns suggest some challenges—remember to balance work with reflection and rest."
        } else {
            return "Patterns are evolving—Aurora is learning your rhythms and adapting recommendations."
        }
    }
}

