//
//  PriorityScore.swift
//  FocusOS
//
//  Contextual Priority System (CPS) - Phase 3
//  Tracks dynamic priority scores for objects across the workspace
//

import Foundation
import SwiftData
import Combine

/// Priority score tracking for CPS (Contextual Priority System)
@Model
final class PriorityScore {
    @Attribute(.unique) var objectId: UUID
    var objectType: String  // "task", "project", "note", "draft", "post", "inbox"
    
    // Core CPS components
    var recencyScore: Double = 0.0      // How recently accessed/updated (0-1)
    var frequencyScore: Double = 0.0    // How often accessed (0-1)
    var connectionScore: Double = 0.0   // How many links/relationships (0-1)
    var aiMentionScore: Double = 0.0    // How often AI surfaces it (0-1)
    var manualBoost: Double = 0.0       // User-initiated boost (0-1)
    
    // Computed total (weighted sum)
    var totalScore: Double = 0.0
    
    // Metadata
    var lastUpdated: Date = Date()
    var lastAccessed: Date = Date()
    var accessCount: Int = 0
    var aiMentionCount: Int = 0
    var connectionCount: Int = 0
    
    init(objectId: UUID, objectType: String) {
        self.objectId = objectId
        self.objectType = objectType
        self.lastUpdated = Date()
        self.lastAccessed = Date()
        self.accessCount = 0
        self.aiMentionCount = 0
        self.connectionCount = 0
        self.totalScore = 0.0
    }
    
    /// Recalculate total score using CPS weights
    func recalculate(using weights: CPSWeights, referenceDate: Date = Date()) {
        // Soft forgetting: Gradual decay based on days since last access
        recencyScore = calculateRecencyDecay(lastAccessed: lastAccessed, referenceDate: referenceDate)
        
        // Frequency normalization
        frequencyScore = min(1.0, Double(accessCount) / 10.0)
        
        // Connection score (already set externally)
        // AI mention score (already set externally)
        // Manual boost (already set externally)
        
        // Weighted sum
        totalScore = (weights.recency * recencyScore) +
                    (weights.frequency * frequencyScore) +
                    (weights.connections * connectionScore) +
                    (weights.aiMentions * aiMentionScore) +
                    (weights.manualBoost * manualBoost)
        
        totalScore = max(0.0, min(1.0, totalScore))
        lastUpdated = Date()
    }
    
    /// Soft forgetting function: Gradual decay that makes Aurora feel like a presence that shifts with you
    /// - Today = 1.0 (full presence)
    /// - Yesterday = 0.7 (strong memory)
    /// - 3 days ago = 0.4 (fading)
    /// - 2 weeks ago = 0.1 (distant)
    /// - Beyond 2 weeks = approaches 0.0 (forgotten)
    private func calculateRecencyDecay(lastAccessed: Date, referenceDate: Date) -> Double {
        let elapsedSeconds = referenceDate.timeIntervalSince(lastAccessed)
        let elapsedDays = elapsedSeconds / (24.0 * 3600.0)
        
        // Defined decay points (days: score)
        let decayPoints: [(days: Double, score: Double)] = [
            (0.0, 1.0),    // Today: full presence
            (1.0, 0.7),    // Yesterday: strong memory
            (3.0, 0.4),    // 3 days ago: fading
            (14.0, 0.1)    // 2 weeks ago: distant
        ]
        
        // If accessed today (same calendar day), return 1.0
        let calendar = Calendar.current
        if calendar.isDate(lastAccessed, inSameDayAs: referenceDate) {
            return 1.0
        }
        
        // If beyond 2 weeks, use exponential decay from 0.1 towards 0.0
        if elapsedDays >= 14.0 {
            let daysBeyond14 = elapsedDays - 14.0
            // Decay from 0.1 to ~0.01 over 14 more days (28 total = very forgotten)
            let decayFactor = exp(-daysBeyond14 / 14.0)
            return max(0.0, 0.1 * decayFactor)
        }
        
        // Interpolate between defined points for smooth decay
        for i in 0..<(decayPoints.count - 1) {
            let current = decayPoints[i]
            let next = decayPoints[i + 1]
            
            if elapsedDays >= current.days && elapsedDays <= next.days {
                // Linear interpolation between current and next point
                let range = next.days - current.days
                let position = elapsedDays - current.days
                let ratio = position / range
                let scoreRange = current.score - next.score
                return current.score - (scoreRange * ratio)
            }
        }
        
        // Fallback (shouldn't reach here)
        return 1.0
    }
}

/// CPS weight configuration
struct CPSWeights {
    let recency: Double
    let frequency: Double
    let connections: Double
    let aiMentions: Double
    let manualBoost: Double
    
    static let `default` = CPSWeights(
        recency: 0.3,
        frequency: 0.25,
        connections: 0.25,
        aiMentions: 0.15,
        manualBoost: 0.05
    )
}

// PriorityItem is defined in AIRecallService.swift

