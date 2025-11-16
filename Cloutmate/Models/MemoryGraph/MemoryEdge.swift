//
//  MemoryEdge.swift
//  Cloutmate
//
//  Phase 6 - Memory Graph Research Build
//  Represents a connection between memory nodes
//

import Foundation
import SwiftData

enum MemoryEdgeType: String, Codable {
    case references         // A references B
    case similarTo          // A is conceptually similar to B
    case partOf             // A is part of B (hierarchical)
    case precedes           // A happened before B (temporal)
    case relatedTo          // Generic relationship
    case contradicts        // A contradicts B
    case supports           // A supports/reinforces B
}

@Model
final class MemoryEdge {
    @Attribute(.unique) var id: UUID = UUID()
    
    // Edge endpoints
    var sourceNodeId: UUID
    var targetNodeId: UUID
    
    // Edge properties
    var edgeType: String                    // MemoryEdgeType.rawValue
    var weight: Double = 0.5                // Connection strength (0.0 to 1.0)
    var confidence: Double = 1.0            // How confident we are in this edge
    var semanticAffinity: Double = 0.0      // Cosine similarity of source and target embeddings
    var importanceScore: Double = 0.5       // Dynamic importance score (0.0 to 1.0)
    
    // Decay and reinforcement
    var lastReinforcedAt: Date?             // When edge was last reinforced
    var decayRate: Double = 0.001           // Exponential decay rate per day
    var isArchived: Bool = false            // Edge has decayed below threshold
    
    // Temporal data
    var createdAt: Date = Date()
    var lastTraversedAt: Date?
    var traversalCount: Int = 0
    
    // Metadata
    var reason: String?                     // Why this edge exists
    var sourceContext: String?              // Context where edge was discovered
    
    init(
        sourceNodeId: UUID,
        targetNodeId: UUID,
        edgeType: MemoryEdgeType,
        weight: Double = 0.5,
        reason: String? = nil
    ) {
        self.sourceNodeId = sourceNodeId
        self.targetNodeId = targetNodeId
        self.edgeType = edgeType.rawValue
        self.weight = weight
        self.reason = reason
        self.createdAt = Date()
    }
    
    var type: MemoryEdgeType {
        get { MemoryEdgeType(rawValue: edgeType) ?? .relatedTo }
        set { edgeType = newValue.rawValue }
    }
    
    /// Record a traversal of this edge
    func traverse() {
        lastTraversedAt = Date()
        traversalCount += 1
    }
    
    /// Strengthen the edge connection
    func strengthen(amount: Double = 0.1) {
        weight = min(1.0, weight + amount)
        confidence = min(1.0, confidence + 0.05)
        lastReinforcedAt = Date()
    }
    
    /// Weaken the edge connection
    func weaken(amount: Double = 0.05) {
        weight = max(0.0, weight - amount)
    }
    
    /// Apply exponential decay based on time since last reinforcement
    func applyDecay() {
        guard let lastReinforced = lastReinforcedAt ?? createdAt else {
            return
        }
        
        let daysSinceReinforcement = Date().timeIntervalSince(lastReinforced) / 86400.0
        
        // Exponential decay: weight = weight * exp(-days * decayRate)
        let decayFactor = exp(-daysSinceReinforcement * decayRate)
        weight = weight * decayFactor
        
        // Archive if weight drops below threshold
        if weight < 0.1 {
            isArchived = true
        }
    }
    
    /// Reinforce edge (reset decay and boost)
    func reinforce(amount: Double = 0.1) {
        lastReinforcedAt = Date()
        strengthen(amount: amount)
        isArchived = false
    }
}

