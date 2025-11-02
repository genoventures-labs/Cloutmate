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
    }
    
    /// Weaken the edge connection
    func weaken(amount: Double = 0.05) {
        weight = max(0.0, weight - amount)
    }
}

