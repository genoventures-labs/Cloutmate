//
//  EmotionEpoch.swift
//  FocusOS
//
//  Temporal emotional memory - summarizes tone, sentiment, and volatility across time windows
//

import Foundation
import SwiftData

@Model
final class EmotionEpoch: Identifiable {
    @Attribute var id: UUID = UUID()
    @Attribute var epochType: String // "daily" or "weekly"
    @Attribute var startDate: Date
    @Attribute var endDate: Date
    @Attribute var createdAt: Date = Date()
    
    // Aggregated tone data
    @Attribute var dominantTone: String? // AuroraTone rawValue
    @Attribute var toneDistribution: Data? // Encoded [String: Int] - tone counts
    @Attribute var averageToneAccuracy: Double = 0.5
    
    // Sentiment metrics
    @Attribute var averageSentiment: Double = 0.0 // -1.0 to +1.0
    @Attribute var sentimentVariance: Double = 0.0 // 0.0 to 1.0
    @Attribute var positiveSentimentRatio: Double = 0.0 // 0.0 to 1.0
    
    // Volatility metrics
    @Attribute var toneVolatility: Double = 0.5 // 0.0 (stable) to 1.0 (volatile)
    @Attribute var transitionFrequency: Double = 0.0 // Average transitions per conversation
    
    // Emotional baseline
    @Attribute var emotionalBaseline: Double = 0.0 // -1.0 (negative) to +1.0 (positive)
    @Attribute var baselineStability: Double = 0.5 // 0.0 to 1.0
    
    // Sample counts
    @Attribute var conversationCount: Int = 0
    @Attribute var messageCount: Int = 0
    @Attribute var predictionCount: Int = 0
    
    init(
        epochType: EpochType,
        startDate: Date,
        endDate: Date
    ) {
        self.epochType = epochType.rawValue
        self.startDate = startDate
        self.endDate = endDate
    }
    
    var epochTypeValue: EpochType? {
        EpochType(rawValue: epochType)
    }
    
    var dominantToneValue: AuroraTone? {
        guard let toneString = dominantTone else { return nil }
        return AuroraTone(rawValue: toneString)
    }
    
    var toneDistributionDict: [String: Int] {
        get {
            guard let data = toneDistribution,
                  let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else {
                return [:]
            }
            return decoded
        }
        set {
            toneDistribution = try? JSONEncoder().encode(newValue)
        }
    }
    
    /// Update epoch with aggregated metrics
    func updateMetrics(
        dominantTone: AuroraTone?,
        toneDistribution: [AuroraTone: Int],
        averageAccuracy: Double,
        averageSentiment: Double,
        sentimentVariance: Double,
        positiveRatio: Double,
        toneVolatility: Double,
        transitionFrequency: Double,
        emotionalBaseline: Double,
        baselineStability: Double,
        conversationCount: Int,
        messageCount: Int,
        predictionCount: Int
    ) {
        self.dominantTone = dominantTone?.rawValue
        self.toneDistributionDict = Dictionary(uniqueKeysWithValues: toneDistribution.map { ($0.key.rawValue, $0.value) })
        self.averageToneAccuracy = averageAccuracy
        self.averageSentiment = averageSentiment
        self.sentimentVariance = sentimentVariance
        self.positiveSentimentRatio = positiveRatio
        self.toneVolatility = toneVolatility
        self.transitionFrequency = transitionFrequency
        self.emotionalBaseline = emotionalBaseline
        self.baselineStability = baselineStability
        self.conversationCount = conversationCount
        self.messageCount = messageCount
        self.predictionCount = predictionCount
    }
}

enum EpochType: String, Codable {
    case daily = "daily"
    case weekly = "weekly"
}

