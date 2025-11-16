//
//  ToneForecastService.swift
//  Cloutmate
//
//  Service for tracking tone prediction accuracy and building adaptive bias
//

import Foundation
import SwiftData
import os.log

@MainActor
final class ToneForecastService {
    static let shared = ToneForecastService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "ToneForecastService")
    
    private init() {}
    
    // MARK: - Recording Predictions
    
    /// Record a tone prediction outcome
    func recordPrediction(
        predictedTone: AuroraTone,
        actualTone: AuroraTone,
        outcomeSentiment: OutcomeSentiment,
        predictionConfidence: Double,
        conversationId: UUID? = nil,
        messageId: UUID? = nil,
        modelContext: ModelContext
    ) {
        let metric = ToneForecastMetrics(
            predictedTone: predictedTone,
            actualTone: actualTone,
            outcomeSentiment: outcomeSentiment,
            predictionConfidence: predictionConfidence,
            conversationId: conversationId,
            messageId: messageId
        )
        
        modelContext.insert(metric)
        
        do {
            try modelContext.save()
            logger.info("Recorded tone prediction: \(predictedTone.rawValue) → \(actualTone.rawValue) (accurate: \(metric.wasAccurate))")
        } catch {
            logger.error("Failed to save tone forecast metric: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Accuracy Calculation
    
    /// Calculate accuracy score for a specific tone
    func accuracyScore(for tone: AuroraTone, modelContext: ModelContext, lookbackDays: Int = 30) -> Double {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: Date()) ?? Date()
        let toneRawValue = tone.rawValue
        
        let descriptor = FetchDescriptor<ToneForecastMetrics>(
            predicate: #Predicate<ToneForecastMetrics> { metric in
                metric.predictedTone == toneRawValue && metric.timestamp >= cutoffDate
            }
        )
        
        guard let metrics = try? modelContext.fetch(descriptor), !metrics.isEmpty else {
            return 0.5 // Default neutral accuracy if no data
        }
        
        let accurateCount = metrics.filter { $0.wasAccurate }.count
        let accuracy = Double(accurateCount) / Double(metrics.count)
        
        return accuracy
    }
    
    /// Calculate accuracy score for a tone pair (predicted → actual)
    func accuracyScoreForPair(
        predicted: AuroraTone,
        actual: AuroraTone,
        modelContext: ModelContext,
        lookbackDays: Int = 30
    ) -> Double {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: Date()) ?? Date()
        let predictedRawValue = predicted.rawValue
        let actualRawValue = actual.rawValue
        
        let descriptor = FetchDescriptor<ToneForecastMetrics>(
            predicate: #Predicate<ToneForecastMetrics> { metric in
                metric.predictedTone == predictedRawValue &&
                metric.actualTone == actualRawValue &&
                metric.timestamp >= cutoffDate
            }
        )
        
        guard let metrics = try? modelContext.fetch(descriptor), !metrics.isEmpty else {
            return 0.0 // No data for this specific pair
        }
        
        // Calculate weighted accuracy based on outcome sentiment
        var weightedScore = 0.0
        var totalWeight = 0.0
        
        for metric in metrics {
            let weight: Double = {
                switch metric.outcomeSentimentValue {
                case .positive: return 1.2 // Positive outcomes weighted higher
                case .neutral: return 1.0
                case .negative: return 0.8 // Negative outcomes weighted lower
                case .none: return 1.0
                }
            }()
            
            if metric.wasAccurate {
                weightedScore += weight
            }
            totalWeight += weight
        }
        
        return totalWeight > 0 ? weightedScore / totalWeight : 0.0
    }
    
    /// Get adaptive bias factor for a tone pair
    /// Higher accuracy = higher bias (up to 1.5x multiplier)
    func adaptiveBiasFactor(
        predicted: AuroraTone,
        actual: AuroraTone,
        modelContext: ModelContext
    ) -> Double {
        let pairAccuracy = accuracyScoreForPair(predicted: predicted, actual: actual, modelContext: modelContext)
        
        // Convert accuracy (0.0-1.0) to bias factor (1.0-1.5)
        // 0.0 accuracy = 1.0x (no bias)
        // 1.0 accuracy = 1.5x (maximum bias)
        let biasFactor = 1.0 + (pairAccuracy * 0.5)
        
        return biasFactor
    }
    
    /// Get overall tone accuracy scores for all tones
    func allToneAccuracyScores(modelContext: ModelContext, lookbackDays: Int = 30) -> [AuroraTone: Double] {
        var scores: [AuroraTone: Double] = [:]
        
        for tone in AuroraTone.allCases {
            scores[tone] = accuracyScore(for: tone, modelContext: modelContext, lookbackDays: lookbackDays)
        }
        
        return scores
    }
    
    // MARK: - Outcome Sentiment Analysis
    
    /// Infer outcome sentiment from conversation context
    /// This is a simple heuristic - could be enhanced with sentiment analysis
    func inferOutcomeSentiment(
        predictedTone: AuroraTone,
        actualTone: AuroraTone,
        userMessage: String? = nil
    ) -> OutcomeSentiment {
        // If prediction was accurate, generally positive
        if predictedTone == actualTone {
            return .positive
        }
        
        // If same category, neutral
        let predictedCategory = AuroraToneKit.category(for: predictedTone)
        let actualCategory = AuroraToneKit.category(for: actualTone)
        
        if predictedCategory == actualCategory {
            return .neutral
        }
        
        // Different categories - check if transition was smooth
        // For now, default to neutral (could be enhanced with user feedback)
        return .neutral
    }
}

