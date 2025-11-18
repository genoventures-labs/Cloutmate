//
//  ToneForecastMetrics.swift
//  FocusOS
//
//  Tone prediction feedback and accuracy tracking
//

import Foundation
import SwiftData
import FocusOSShared

@Model
final class ToneForecastMetrics: Identifiable {
    @Attribute var id: UUID = UUID()
    @Attribute var timestamp: Date = Date()
    
    // Prediction data
    @Attribute var predictedTone: String // AuroraTone rawValue
    @Attribute var actualTone: String // AuroraTone rawValue
    @Attribute var outcomeSentiment: String // "positive", "neutral", "negative"
    
    // Context data
    @Attribute var predictionConfidence: Double = 0.0
    @Attribute var conversationId: UUID?
    @Attribute var messageId: UUID?
    
    // Accuracy tracking
    @Attribute var wasAccurate: Bool = false // predictedTone == actualTone
    @Attribute var categoryMatch: Bool = false // Same category even if different tone
    
    init(
        predictedTone: AuroraTone,
        actualTone: AuroraTone,
        outcomeSentiment: OutcomeSentiment,
        predictionConfidence: Double,
        conversationId: UUID? = nil,
        messageId: UUID? = nil
    ) {
        self.predictedTone = predictedTone.rawValue
        self.actualTone = actualTone.rawValue
        self.outcomeSentiment = outcomeSentiment.rawValue
        self.predictionConfidence = predictionConfidence
        self.conversationId = conversationId
        self.messageId = messageId
        self.wasAccurate = predictedTone == actualTone
        self.categoryMatch = AuroraToneKit.category(for: predictedTone) == AuroraToneKit.category(for: actualTone)
    }
    
    var predictedToneValue: AuroraTone? {
        AuroraTone(rawValue: predictedTone)
    }
    
    var actualToneValue: AuroraTone? {
        AuroraTone(rawValue: actualTone)
    }
    
    var outcomeSentimentValue: OutcomeSentiment? {
        OutcomeSentiment(rawValue: outcomeSentiment)
    }
}

enum OutcomeSentiment: String, Codable {
    case positive = "positive"
    case neutral = "neutral"
    case negative = "negative"
}

