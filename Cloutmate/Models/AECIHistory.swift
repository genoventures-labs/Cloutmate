//
//  AECIHistory.swift
//  Cloutmate
//
//  Weekly Aurora Emotional Climate Index history for longitudinal analytics
//

import Foundation
import SwiftData

@Model
final class AECIHistory: Identifiable {
    @Attribute var id: UUID = UUID()
    @Attribute var weekStartDate: Date
    @Attribute var weekEndDate: Date
    @Attribute var calculatedAt: Date = Date()
    
    // AECI Score (-1.0 to +1.0)
    @Attribute var aecIndex: Double = 0.0 // -1.0 (negative climate) to +1.0 (positive climate)
    
    // Component scores (for analysis)
    @Attribute var stabilityScore: Double = 0.5 // 0.0 to 1.0
    @Attribute var sentimentMomentum: Double = 0.0 // -1.0 to +1.0
    @Attribute var volatilityScore: Double = 0.5 // 0.0 to 1.0 (inverted: lower = better)
    
    // Aggregated metrics
    @Attribute var averageToneAccuracy: Double = 0.5
    @Attribute var averageSentiment: Double = 0.0
    @Attribute var averageStability: Double = 0.5
    @Attribute var averageVolatility: Double = 0.5
    
    // Sample counts
    @Attribute var epochCount: Int = 0
    @Attribute var profileCount: Int = 0
    @Attribute var metricCount: Int = 0
    
    init(
        weekStartDate: Date,
        weekEndDate: Date,
        aecIndex: Double,
        stabilityScore: Double,
        sentimentMomentum: Double,
        volatilityScore: Double
    ) {
        self.weekStartDate = weekStartDate
        self.weekEndDate = weekEndDate
        self.aecIndex = aecIndex
        self.stabilityScore = stabilityScore
        self.sentimentMomentum = sentimentMomentum
        self.volatilityScore = volatilityScore
    }
    
    /// Get AECI category for UI theming
    var category: AECICategory {
        if aecIndex > 0.3 {
            return .positive
        } else if aecIndex < -0.3 {
            return .negative
        } else {
            return .neutral
        }
    }
    
    /// Get UI warmth modifier (0.8 to 1.2)
    var uiWarmthModifier: Double {
        // Positive AECI = warmer UI
        return 0.8 + (aecIndex + 1.0) * 0.2 // Maps -1.0→0.8, +1.0→1.2
    }
    
    /// Get response pacing modifier (0.7 to 1.3)
    var pacingModifier: Double {
        // Positive AECI = faster pacing, negative = slower
        return 1.0 + (aecIndex * 0.3) // Maps -1.0→0.7, +1.0→1.3
    }
}

enum AECICategory: String, Codable {
    case positive = "positive"
    case negative = "negative"
    case neutral = "neutral"
}

