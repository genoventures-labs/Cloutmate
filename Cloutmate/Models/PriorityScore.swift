//
//  PriorityScore.swift
//  Cloutmate
//
//  Contextual Priority System (CPS) - Phase 3
//  Tracks dynamic priority scores for objects across the workspace
//

import Foundation
import SwiftData

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
        // Recency decay (exponential)
        let elapsed = referenceDate.timeIntervalSince(lastAccessed)
        let decayHours = 72.0 // 3 days half-life
        recencyScore = exp(-elapsed / (decayHours * 3600.0))
        
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

