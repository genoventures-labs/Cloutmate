//
//  ConceptNode.swift
//  FocusOS
//
//  Phase 5: Narrative Engine - Dynamic Weighting System
//  Tracks abstract concepts/themes with "aliveness" scores across workspace
//

import Foundation
import SwiftData

/// A concept or theme tracked across the workspace with dynamic relevance
@Model
final class ConceptNode {
    @Attribute(.unique) var id: UUID
    @Attribute var concept: String              // The concept/theme (e.g., "Consistency", "Growth")
    @Attribute var normalizedConcept: String    // Lowercase for matching
    
    // Multi-factor weighting components (0-1 scale each)
    var recencyScore: Double = 0.0              // How recently mentioned (30% weight)
    var frequencyScore: Double = 0.0            // How often mentioned (30% weight)
    var emotionalImpactScore: Double = 0.0      // Emotional intensity of mentions (20% weight)
    var usageScore: Double = 0.0                // Cross-context usage (20% weight)
    
    // Computed relevance weight
    var relevanceWeight: Double = 0.0           // Weighted sum (0-1)
    
    // Metadata
    var firstMentioned: Date
    var lastMentioned: Date
    var mentionCount: Int = 1
    var emotionalValence: Double = 0.0          // Average emotional tone (-1 to 1)
    var linkedObjects: [UUID] = []              // Tasks, notes, etc. that mention this
    var contextTypes: [String] = []             // Where mentioned: "note", "task", "journal", etc.
    
    init(concept: String) {
        self.id = UUID()
        self.concept = concept
        self.normalizedConcept = concept.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.firstMentioned = Date()
        self.lastMentioned = Date()
        self.mentionCount = 1
        self.linkedObjects = []
        self.contextTypes = []
        self.relevanceWeight = 0.0
    }
    
    /// Calculate relevance weight using dynamic weighting formula
    /// Relevance = Recency(0.3) + Frequency(0.3) + Emotional(0.2) + Usage(0.2)
    func calculateRelevance(referenceDate: Date = Date()) {
        // Recency: Exponential decay with 7-day half-life
        let elapsed = referenceDate.timeIntervalSince(lastMentioned)
        let decayDays = 7.0
        recencyScore = exp(-elapsed / (decayDays * 86400.0))  // 86400 seconds in a day
        
        // Frequency: Logarithmic scale (diminishing returns)
        // Normalize to 0-1 where 10+ mentions = 1.0
        frequencyScore = min(1.0, log(Double(mentionCount) + 1) / log(11))
        
        // Emotional Impact: Already set externally (0-1)
        // emotionalImpactScore is calculated from average emotional intensity
        
        // Usage: Cross-context diversity
        // More diverse contexts = higher score
        // Normalize to 0-1 where 5+ contexts = 1.0
        let uniqueContexts = Set(contextTypes).count
        usageScore = min(1.0, Double(uniqueContexts) / 5.0)
        
        // Weighted sum: Recency(30%) + Frequency(30%) + Emotional(20%) + Usage(20%)
        relevanceWeight = (recencyScore * 0.3) +
                         (frequencyScore * 0.3) +
                         (emotionalImpactScore * 0.2) +
                         (usageScore * 0.2)
        
        relevanceWeight = max(0.0, min(1.0, relevanceWeight))
    }
    
    /// Record a new mention of this concept
    func recordMention(
        from objectId: UUID,
        contextType: String,
        emotionalIntensity: Double = 0.0,
        emotionalValence: Double = 0.0
    ) {
        mentionCount += 1
        lastMentioned = Date()
        
        if !linkedObjects.contains(objectId) {
            linkedObjects.append(objectId)
        }
        
        if !contextTypes.contains(contextType) {
            contextTypes.append(contextType)
        }
        
        // Update emotional scores (running average)
        let totalWeight = Double(mentionCount)
        self.emotionalImpactScore = ((self.emotionalImpactScore * (totalWeight - 1)) + emotionalIntensity) / totalWeight
        self.emotionalValence = ((self.emotionalValence * (totalWeight - 1)) + emotionalValence) / totalWeight
    }
    
    /// Is this concept "alive" (actively relevant)?
    var isAlive: Bool {
        return relevanceWeight > 0.3  // Threshold for "aliveness"
    }
    
    /// Description for display
    var displayString: String {
        let aliveIndicator = isAlive ? "🔥" : "💤"
        let score = String(format: "%.2f", relevanceWeight)
        return "\(aliveIndicator) \(concept) (score: \(score), mentions: \(mentionCount))"
    }
}

/// Lightweight concept summary for AI context
struct ConceptSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    let concept: String
    let relevanceWeight: Double
    let mentionCount: Int
    let contextTypes: [String]
    let isAlive: Bool
    let emotionalTone: String  // "positive", "negative", "neutral"
    
    init(from node: ConceptNode) {
        self.id = node.id
        self.concept = node.concept
        self.relevanceWeight = node.relevanceWeight
        self.mentionCount = node.mentionCount
        self.contextTypes = node.contextTypes
        self.isAlive = node.isAlive
        
        if node.emotionalValence > 0.3 {
            self.emotionalTone = "positive"
        } else if node.emotionalValence < -0.3 {
            self.emotionalTone = "negative"
        } else {
            self.emotionalTone = "neutral"
        }
    }
}

/// Dynamic weighting configuration
struct ConceptWeights {
    let recency: Double
    let frequency: Double
    let emotional: Double
    let usage: Double
    
    static let `default` = ConceptWeights(
        recency: 0.3,
        frequency: 0.3,
        emotional: 0.2,
        usage: 0.2
    )
}

