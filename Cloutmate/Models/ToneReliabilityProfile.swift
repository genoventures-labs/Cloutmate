//
//  ToneReliabilityProfile.swift
//  Cloutmate
//
//  Long-term tone reliability and sentiment tracking
//

import Foundation
import SwiftData

@Model
final class ToneReliabilityProfile: Identifiable {
    @Attribute var id: UUID = UUID()
    @Attribute var tone: String // AuroraTone rawValue
    @Attribute var lastUpdated: Date = Date()
    
    // Stability metrics (how consistent the tone is)
    @Attribute var stability: Double = 0.5 // 0.0 (unstable) to 1.0 (very stable)
    @Attribute var stabilitySampleCount: Int = 0
    
    // Volatility metrics (how much the tone varies)
    @Attribute var volatility: Double = 0.5 // 0.0 (low variance) to 1.0 (high variance)
    @Attribute var volatilitySampleCount: Int = 0
    
    // Sentiment polarity (overall emotional direction)
    @Attribute var sentimentPolarity: Double = 0.0 // -1.0 (negative) to +1.0 (positive)
    @Attribute var sentimentSampleCount: Int = 0
    
    // Moving averages (last 30 days)
    @Attribute var movingAverageAccuracy: Double = 0.5
    @Attribute var movingAverageSentiment: Double = 0.0
    
    // Tone characteristic modifiers (based on reliability)
    @Attribute var warmthModifier: Double = 1.0 // 0.5 to 1.5
    @Attribute var clarityModifier: Double = 1.0 // 0.5 to 1.5
    @Attribute var energyModifier: Double = 1.0 // 0.5 to 1.5
    
    init(tone: AuroraTone) {
        self.tone = tone.rawValue
    }
    
    var toneValue: AuroraTone? {
        AuroraTone(rawValue: tone)
    }
    
    /// Update stability based on consistency of predictions
    func updateStability(accuracy: Double, sampleCount: Int) {
        // Stability = weighted average of accuracy consistency
        // Higher accuracy = more stable
        let newStability = accuracy
        
        if stabilitySampleCount == 0 {
            self.stability = newStability
        } else {
            // Exponential moving average
            let alpha = 0.3 // Smoothing factor
            self.stability = (alpha * newStability) + ((1.0 - alpha) * stability)
        }
        
        self.stabilitySampleCount += sampleCount
        self.lastUpdated = Date()
    }
    
    /// Update volatility based on variance in outcomes
    func updateVolatility(variance: Double, sampleCount: Int) {
        // Volatility = normalized variance (0.0 to 1.0)
        let newVolatility = min(1.0, max(0.0, variance))
        
        if volatilitySampleCount == 0 {
            self.volatility = newVolatility
        } else {
            // Exponential moving average
            let alpha = 0.3
            self.volatility = (alpha * newVolatility) + ((1.0 - alpha) * volatility)
        }
        
        self.volatilitySampleCount += sampleCount
        self.lastUpdated = Date()
    }
    
    /// Update sentiment polarity based on outcome sentiments
    func updateSentimentPolarity(polarity: Double, sampleCount: Int) {
        // Polarity: -1.0 (negative) to +1.0 (positive)
        let newPolarity = min(1.0, max(-1.0, polarity))
        
        if sentimentSampleCount == 0 {
            self.sentimentPolarity = newPolarity
        } else {
            // Exponential moving average
            let alpha = 0.3
            self.sentimentPolarity = (alpha * newPolarity) + ((1.0 - alpha) * sentimentPolarity)
        }
        
        self.sentimentSampleCount += sampleCount
        self.lastUpdated = Date()
    }
    
    /// Update moving averages
    func updateMovingAverages(accuracy: Double, sentiment: Double) {
        let alpha = 0.1 // Slower smoothing for moving averages
        self.movingAverageAccuracy = (alpha * accuracy) + ((1.0 - alpha) * movingAverageAccuracy)
        self.movingAverageSentiment = (alpha * sentiment) + ((1.0 - alpha) * movingAverageSentiment)
    }
    
    /// Calculate tone characteristic modifiers based on reliability profile
    func calculateModifiers() {
        // Warmth: Higher stability + positive sentiment = more warmth
        let warmthBase = 1.0 + (stability * 0.2) + (sentimentPolarity * 0.15)
        self.warmthModifier = min(1.5, max(0.5, warmthBase))
        
        // Clarity: Higher stability + lower volatility = more clarity
        let clarityBase = 1.0 + (stability * 0.2) - (volatility * 0.15)
        self.clarityModifier = min(1.5, max(0.5, clarityBase))
        
        // Energy: Positive sentiment + moderate volatility = more energy
        let energyBase = 1.0 + (sentimentPolarity * 0.2) + (min(volatility, 0.5) * 0.1)
        self.energyModifier = min(1.5, max(0.5, energyBase))
    }
}

