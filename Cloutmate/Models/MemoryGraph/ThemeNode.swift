//
//  ThemeNode.swift
//  Cloutmate
//
//  Phase 6 - Memory Graph Research Build
//  Represents an emergent theme cluster in the memory graph
//

import Foundation
import SwiftData

@Model
final class ThemeNode {
    @Attribute(.unique) var id: UUID = UUID()
    
    // Theme identity
    var label: String                       // Theme name (e.g., "Content Strategy")
    var themeDescription: String            // Generated description
    
    // Cluster membership
    var memberNodeIds: [UUID] = []          // Nodes that belong to this theme
    var centroidEmbedding: Data?            // Average embedding of cluster
    var embeddingDimensions: Int = 0
    
    // Theme metrics
    var coherence: Double = 0.0             // How cohesive the theme is (0.0-1.0)
    var salience: Double = 0.0              // How important/prominent (0.0-1.0)
    var momentum: Double = 0.0              // Growth rate (-1.0 to 1.0)
    
    // Temporal data
    var emergedAt: Date = Date()
    var lastUpdateAt: Date = Date()
    var peakSalienceAt: Date?
    var peakSalienceValue: Double = 0.0
    
    // Lifecycle
    var isActive: Bool = true               // Theme is currently relevant
    var decayStarted: Bool = false          // Theme is fading
    
    // Keywords
    var keywords: [String] = []             // Representative keywords
    var relatedConcepts: [String] = []      // Related ConceptNode labels
    
    init(label: String, themeDescription: String) {
        self.label = label
        self.themeDescription = themeDescription
        self.emergedAt = Date()
        self.lastUpdateAt = Date()
    }
    
    /// Set centroid embedding from float array
    func setCentroid(_ embedding: [Float]) {
        self.embeddingDimensions = embedding.count
        self.centroidEmbedding = Data(bytes: embedding, count: embedding.count * MemoryLayout<Float>.size)
    }
    
    /// Get centroid embedding as float array
    func getCentroid() -> [Float]? {
        guard let data = centroidEmbedding, embeddingDimensions > 0 else { return nil }
        let floatCount = embeddingDimensions
        return data.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self).prefix(floatCount))
        }
    }
    
    /// Add a node to this theme
    func addMember(_ nodeId: UUID) {
        if !memberNodeIds.contains(nodeId) {
            memberNodeIds.append(nodeId)
            lastUpdateAt = Date()
        }
    }
    
    /// Remove a node from this theme
    func removeMember(_ nodeId: UUID) {
        memberNodeIds.removeAll { $0 == nodeId }
        lastUpdateAt = Date()
    }
    
    /// Calculate salience based on member count and momentum
    func recalculateSalience() {
        // Salience is a function of cluster size and momentum
        let sizeFactor = min(1.0, Double(memberNodeIds.count) / 10.0)
        let momentumFactor = (momentum + 1.0) / 2.0 // Normalize -1..1 to 0..1
        salience = (sizeFactor * 0.7) + (momentumFactor * 0.3)
        
        // Track peak salience
        if salience > peakSalienceValue {
            peakSalienceValue = salience
            peakSalienceAt = Date()
        }
    }
    
    /// Check if theme should decay
    func shouldDecay() -> Bool {
        let daysSinceUpdate = Date().timeIntervalSince(lastUpdateAt) / (24 * 3600)
        return daysSinceUpdate > 7.0 && memberNodeIds.count < 3
    }
    
    /// Start decay process
    func beginDecay() {
        decayStarted = true
        isActive = false
    }
}

/// Lightweight theme summary for AI payload
struct ThemeSummary: Sendable, Identifiable, Hashable {
    let id: UUID
    let label: String
    let description: String
    let salience: Double
    let memberCount: Int
    let keywords: [String]
    let isActive: Bool
}

