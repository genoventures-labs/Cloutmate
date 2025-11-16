//
//  EmotionalContinuityEngine.swift
//  Cloutmate
//
//  Unifies tone feedback and temporal memory to calculate global emotional climate
//

import Foundation
import SwiftData
import SwiftUI
import os.log
import Combine
import Combine
import Combine

@MainActor
final class EmotionalContinuityEngine {
    static let shared = EmotionalContinuityEngine()
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "EmotionalContinuityEngine")
    
    // Current AECI cache (updated weekly)
    @Published private(set) var currentAECI: Double = 0.0
    @Published private(set) var currentCategory: AECICategory = .neutral
    @Published private(set) var lastCalculated: Date?
    
    private init() {}
    
    // MARK: - AECI Calculation
    
    /// Calculate Aurora Emotional Climate Index for the current week
    func calculateWeeklyAECI(
        modelContext: ModelContext
    ) async -> AECIHistory? {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        
        logger.info("Calculating AECI for week starting \(weekStart)")
        
        // Check if already calculated for this week
        let descriptor = FetchDescriptor<AECIHistory>(
            predicate: #Predicate<AECIHistory> { history in
                history.weekStartDate >= weekStart && history.weekStartDate < weekEnd
            }
        )
        
        if let existing = try? modelContext.fetch(descriptor).first {
            // Update cache
            currentAECI = existing.aecIndex
            currentCategory = existing.category
            lastCalculated = existing.calculatedAt
            return existing
        }
        
        // Calculate component scores
        
        // 1. Stability Score (from ToneReliabilityProfile)
        let stabilityScore = await calculateStabilityScore(modelContext: modelContext)
        
        // 2. Sentiment Momentum (from TemporalEmotionalMemory)
        let sentimentMomentum = await calculateSentimentMomentum(modelContext: modelContext)
        
        // 3. Volatility Score (inverted: lower volatility = higher score)
        let volatilityScore = await calculateVolatilityScore(modelContext: modelContext)
        
        // Calculate AECI: weighted blend
        // Formula: (stability * 0.4) + (sentiment * 0.4) + ((1.0 - volatility) * 0.2)
        // This gives: stability 40%, sentiment 40%, low volatility 20%
        let aecIndex = (stabilityScore * 0.4) + (sentimentMomentum * 0.4) + ((1.0 - volatilityScore) * 0.2)
        
        // Clamp to -1.0 to +1.0
        let clampedAECI = min(1.0, max(-1.0, aecIndex))
        
        // Get aggregated metrics for history
        let (avgAccuracy, avgSentiment, avgStability, avgVolatility, epochCount, profileCount, metricCount) = await getAggregatedMetrics(
            weekStart: weekStart,
            weekEnd: weekEnd,
            modelContext: modelContext
        )
        
        // Create AECI history entry
        let history = AECIHistory(
            weekStartDate: weekStart,
            weekEndDate: weekEnd,
            aecIndex: clampedAECI,
            stabilityScore: stabilityScore,
            sentimentMomentum: sentimentMomentum,
            volatilityScore: volatilityScore
        )
        
        history.averageToneAccuracy = avgAccuracy
        history.averageSentiment = avgSentiment
        history.averageStability = avgStability
        history.averageVolatility = avgVolatility
        history.epochCount = epochCount
        history.profileCount = profileCount
        history.metricCount = metricCount
        
        modelContext.insert(history)
        
        // Update cache
        currentAECI = clampedAECI
        currentCategory = history.category
        lastCalculated = Date()
        
        do {
            try modelContext.save()
            logger.info("Calculated AECI: \(String(format: "%.2f", clampedAECI)) (category: \(history.category.rawValue))")
        } catch {
            logger.error("Failed to save AECI history: \(error.localizedDescription)")
        }
        
        return history
    }
    
    // MARK: - Component Score Calculations
    
    private func calculateStabilityScore(modelContext: ModelContext) async -> Double {
        let profiles = await ToneFeedbackReinforcementEngine.shared.getAllProfiles(modelContext: modelContext)
        
        guard !profiles.isEmpty else {
            return 0.5 // Default neutral stability
        }
        
        // Average stability across all tones
        let averageStability = profiles.map { $0.stability }.reduce(0.0, +) / Double(profiles.count)
        
        // Weight by sample count (more data = more reliable)
        var weightedSum = 0.0
        var totalWeight = 0.0
        
        for profile in profiles {
            // Use moving average accuracy as weight (more reliable data = higher weight)
            let weight = profile.movingAverageAccuracy
            weightedSum += profile.stability * weight
            totalWeight += weight
        }
        
        return totalWeight > 0 ? weightedSum / totalWeight : averageStability
    }
    
    private func calculateSentimentMomentum(modelContext: ModelContext) async -> Double {
        let momentum = await TemporalEmotionalMemory.shared.forecastEmotionalMomentum(modelContext: modelContext)
        
        // Use momentum value directly (-1.0 to +1.0)
        // Weight by confidence
        return momentum.momentum * momentum.confidence
    }
    
    private func calculateVolatilityScore(modelContext: ModelContext) async -> Double {
        let profiles = await ToneFeedbackReinforcementEngine.shared.getAllProfiles(modelContext: modelContext)
        
        guard !profiles.isEmpty else {
            return 0.5 // Default moderate volatility
        }
        
        // Average volatility across all tones
        let averageVolatility = profiles.map { $0.volatility }.reduce(0.0, +) / Double(profiles.count)
        
        // Also get rolling average volatility from temporal memory
        let temporalVolatility = await TemporalEmotionalMemory.shared.rollingAverageVolatility(days: 7, modelContext: modelContext)
        
        // Blend: 60% from profiles, 40% from temporal memory
        return (averageVolatility * 0.6) + (temporalVolatility * 0.4)
    }
    
    private func getAggregatedMetrics(
        weekStart: Date,
        weekEnd: Date,
        modelContext: ModelContext
    ) async -> (Double, Double, Double, Double, Int, Int, Int) {
        // Get epochs for the week
        let epochDescriptor = FetchDescriptor<EmotionEpoch>(
            predicate: #Predicate<EmotionEpoch> { epoch in
                epoch.startDate >= weekStart && epoch.startDate < weekEnd
            }
        )
        let epochs = (try? modelContext.fetch(epochDescriptor)) ?? []
        
        // Get profiles
        let profiles = await ToneFeedbackReinforcementEngine.shared.getAllProfiles(modelContext: modelContext)
        
        // Get metrics for the week
        let metricDescriptor = FetchDescriptor<ToneForecastMetrics>(
            predicate: #Predicate<ToneForecastMetrics> { metric in
                metric.timestamp >= weekStart && metric.timestamp < weekEnd
            }
        )
        let metrics = (try? modelContext.fetch(metricDescriptor)) ?? []
        
        // Calculate averages
        let avgAccuracy = epochs.isEmpty ? 0.5 : epochs.map { $0.averageToneAccuracy }.reduce(0.0, +) / Double(epochs.count)
        let avgSentiment = epochs.isEmpty ? 0.0 : epochs.map { $0.averageSentiment }.reduce(0.0, +) / Double(epochs.count)
        let avgStability = profiles.isEmpty ? 0.5 : profiles.map { $0.stability }.reduce(0.0, +) / Double(profiles.count)
        let avgVolatility = profiles.isEmpty ? 0.5 : profiles.map { $0.volatility }.reduce(0.0, +) / Double(profiles.count)
        
        return (avgAccuracy, avgSentiment, avgStability, avgVolatility, epochs.count, profiles.count, metrics.count)
    }
    
    // MARK: - AECI History
    
    /// Get AECI history (last N weeks)
    func getAECIHistory(
        weeks: Int = 12,
        modelContext: ModelContext
    ) async -> [AECIHistory] {
        let cutoffDate = Calendar.current.date(byAdding: .weekOfYear, value: -weeks, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<AECIHistory>(
            predicate: #Predicate<AECIHistory> { history in
                history.weekStartDate >= cutoffDate
            },
            sortBy: [SortDescriptor(\.weekStartDate, order: .reverse)]
        )
        
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    /// Get current week's AECI (from cache or calculate)
    func getCurrentAECI(modelContext: ModelContext) async -> Double {
        // Check if cache is fresh (within last 24 hours)
        if let lastCalc = lastCalculated,
           Date().timeIntervalSince(lastCalc) < 86400 {
            return currentAECI
        }
        
        // Recalculate
        if let history = await calculateWeeklyAECI(modelContext: modelContext) {
            return history.aecIndex
        }
        
        return 0.0
    }
    
    // MARK: - Global Behavior Modifiers
    
    /// Get UI hue adjustment based on AECI
    func getUIHueAdjustment(aecIndex: Double) -> Double {
        // Positive AECI → warmer hues (shift toward orange/yellow)
        // Negative AECI → cooler hues (shift toward blue/purple)
        // Range: -15° to +15° hue shift
        return aecIndex * 15.0
    }
    
    /// Get UI saturation adjustment based on AECI
    func getUISaturationAdjustment(aecIndex: Double) -> Double {
        // Positive AECI → higher saturation (more vibrant)
        // Negative AECI → lower saturation (softer)
        // Range: -0.1 to +0.1 saturation modifier
        return aecIndex * 0.1
    }
    
    /// Get response pacing adjustment based on AECI
    func getResponsePacingAdjustment(aecIndex: Double) -> Double {
        // Positive AECI → faster pacing (more energetic)
        // Negative AECI → slower pacing (more measured)
        // Range: 0.7x to 1.3x pacing multiplier
        return 1.0 + (aecIndex * 0.3)
    }
    
    /// Get default tone bias based on AECI
    func getDefaultToneBias(aecIndex: Double) -> AuroraTone? {
        // Positive AECI → favor encouraging/celebratory tones
        if aecIndex > 0.3 {
            return .encouraging
        }
        
        // Negative AECI → favor supportive/restorative tones
        if aecIndex < -0.3 {
            return .supportive
        }
        
        // Neutral → no bias
        return nil
    }
}

