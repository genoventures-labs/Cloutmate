//
//  ToneFeedbackReinforcementEngine.swift
//  FocusOS
//
//  Aggregates tone feedback and builds reliability profiles
//

import Foundation
import SwiftData
import os.log

@MainActor
final class ToneFeedbackReinforcementEngine {
    static let shared = ToneFeedbackReinforcementEngine()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "ToneFeedbackReinforcementEngine")
    
    // Track conversation batches (3-5 turns)
    private var conversationBatchCounts: [UUID: Int] = [:]
    private let batchSizeRange = 3...5
    
    private init() {}
    
    // MARK: - Batch Tracking
    
    /// Track a conversation turn and determine if batch is complete
    func trackTurn(conversationId: UUID) -> Bool {
        let currentCount = conversationBatchCounts[conversationId, default: 0] + 1
        conversationBatchCounts[conversationId] = currentCount
        
        // Check if we've reached batch size (randomized between 3-5)
        let batchSize = batchSizeRange.randomElement() ?? 4
        if currentCount >= batchSize {
            conversationBatchCounts[conversationId] = 0 // Reset
            return true // Batch complete
        }
        
        return false
    }
    
    // MARK: - Batch Aggregation
    
    /// Aggregate metrics for a conversation batch and update reliability profiles
    func processBatch(
        conversationId: UUID,
        modelContext: ModelContext
    ) async {
        logger.info("Processing tone feedback batch for conversation \(conversationId.uuidString)")
        
        // Fetch metrics for this conversation in the last batch period
        let cutoffDate = Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<ToneForecastMetrics>(
            predicate: #Predicate<ToneForecastMetrics> { metric in
                metric.conversationId == conversationId && metric.timestamp >= cutoffDate
            },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        
        guard let metrics = try? modelContext.fetch(descriptor), !metrics.isEmpty else {
            logger.info("No metrics found for batch processing")
            return
        }
        
        // Group metrics by predicted tone
        let metricsByTone = Dictionary(grouping: metrics) { metric in
            metric.predictedTone
        }
        
        // Process each tone's metrics
        for (toneString, toneMetrics) in metricsByTone {
            guard let tone = AuroraTone(rawValue: toneString) else { continue }
            
            // Get or create reliability profile
            let profile = await getOrCreateProfile(for: tone, modelContext: modelContext)
            
            // Calculate batch statistics
            let accuracy = calculateBatchAccuracy(metrics: toneMetrics)
            let variance = calculateBatchVariance(metrics: toneMetrics)
            let sentimentPolarity = calculateBatchSentimentPolarity(metrics: toneMetrics)
            let averageSentiment = calculateAverageSentiment(metrics: toneMetrics)
            
            // Update profile
            profile.updateStability(accuracy: accuracy, sampleCount: toneMetrics.count)
            profile.updateVolatility(variance: variance, sampleCount: toneMetrics.count)
            profile.updateSentimentPolarity(polarity: sentimentPolarity, sampleCount: toneMetrics.count)
            profile.updateMovingAverages(accuracy: accuracy, sentiment: averageSentiment)
            profile.calculateModifiers()
            
            logger.info("Updated profile for \(tone.displayName): stability=\(String(format: "%.2f", profile.stability)), volatility=\(String(format: "%.2f", profile.volatility)), sentiment=\(String(format: "%.2f", profile.sentimentPolarity))")
        }
        
        // Save updates
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save tone reliability profiles: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Profile Management
    
    /// Get or create reliability profile for a tone
    private func getOrCreateProfile(for tone: AuroraTone, modelContext: ModelContext) async -> ToneReliabilityProfile {
        let toneRawValue = tone.rawValue
        let descriptor = FetchDescriptor<ToneReliabilityProfile>(
            predicate: #Predicate<ToneReliabilityProfile> { profile in
                profile.tone == toneRawValue
            }
        )
        
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        
        // Create new profile
        let profile = ToneReliabilityProfile(tone: tone)
        modelContext.insert(profile)
        return profile
    }
    
    /// Get reliability profile for a tone
    func getProfile(for tone: AuroraTone, modelContext: ModelContext) async -> ToneReliabilityProfile? {
        let toneRawValue = tone.rawValue
        let descriptor = FetchDescriptor<ToneReliabilityProfile>(
            predicate: #Predicate<ToneReliabilityProfile> { profile in
                profile.tone == toneRawValue
            }
        )
        
        return try? modelContext.fetch(descriptor).first
    }
    
    /// Get all reliability profiles
    func getAllProfiles(modelContext: ModelContext) async -> [ToneReliabilityProfile] {
        let descriptor = FetchDescriptor<ToneReliabilityProfile>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    // MARK: - Batch Statistics
    
    private func calculateBatchAccuracy(metrics: [ToneForecastMetrics]) -> Double {
        guard !metrics.isEmpty else { return 0.5 }
        let accurateCount = metrics.filter { $0.wasAccurate }.count
        return Double(accurateCount) / Double(metrics.count)
    }
    
    private func calculateBatchVariance(metrics: [ToneForecastMetrics]) -> Double {
        guard metrics.count > 1 else { return 0.0 }
        
        // Calculate variance in accuracy outcomes
        let accuracies = metrics.map { $0.wasAccurate ? 1.0 : 0.0 }
        let mean = accuracies.reduce(0.0, +) / Double(accuracies.count)
        let variance = accuracies.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(accuracies.count)
        
        return min(1.0, variance * 4.0) // Normalize to 0.0-1.0
    }
    
    private func calculateBatchSentimentPolarity(metrics: [ToneForecastMetrics]) -> Double {
        guard !metrics.isEmpty else { return 0.0 }
        
        var polaritySum = 0.0
        var count = 0
        
        for metric in metrics {
            switch metric.outcomeSentimentValue {
            case .positive:
                polaritySum += 1.0
            case .neutral:
                polaritySum += 0.0
            case .negative:
                polaritySum -= 1.0
            case .none:
                continue
            }
            count += 1
        }
        
        guard count > 0 else { return 0.0 }
        return polaritySum / Double(count) // -1.0 to +1.0
    }
    
    private func calculateAverageSentiment(metrics: [ToneForecastMetrics]) -> Double {
        return calculateBatchSentimentPolarity(metrics: metrics)
    }
    
    // MARK: - Moving Averages
    
    /// Calculate moving average accuracy for a tone (last 30 days)
    func movingAverageAccuracy(for tone: AuroraTone, modelContext: ModelContext) -> Double {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let toneRawValue = tone.rawValue
        
        let descriptor = FetchDescriptor<ToneForecastMetrics>(
            predicate: #Predicate<ToneForecastMetrics> { metric in
                metric.predictedTone == toneRawValue && metric.timestamp >= cutoffDate
            }
        )
        
        guard let metrics = try? modelContext.fetch(descriptor), !metrics.isEmpty else {
            return 0.5 // Default neutral
        }
        
        return calculateBatchAccuracy(metrics: metrics)
    }
    
    /// Calculate moving average sentiment drift (last 30 days)
    func movingAverageSentimentDrift(for tone: AuroraTone, modelContext: ModelContext) -> Double {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let toneRawValue = tone.rawValue
        
        let descriptor = FetchDescriptor<ToneForecastMetrics>(
            predicate: #Predicate<ToneForecastMetrics> { metric in
                metric.predictedTone == toneRawValue && metric.timestamp >= cutoffDate
            }
        )
        
        guard let metrics = try? modelContext.fetch(descriptor), !metrics.isEmpty else {
            return 0.0 // Default neutral
        }
        
        return calculateBatchSentimentPolarity(metrics: metrics)
    }
}

