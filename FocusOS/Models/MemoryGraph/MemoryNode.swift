//
//  MemoryNode.swift
//  FocusOS
//
//  Phase 6 - Memory Graph Research Build
//  Represents a node in the memory graph (workspace object or concept)
//

import Foundation
import SwiftData

enum MemoryNodeType: String, Codable {
    case workspaceObject    // Task, Note, Project, Post, etc.
    case concept            // Abstract concept from ConceptNode
    case theme              // Emergent theme cluster
    case conversation       // Conversation digest
    case session            // Focus session
    case insight            // Generated insight or learning
}

@Model
final class MemoryNode {
    @Attribute(.unique) var id: UUID = UUID()
    
    // Node identity
    var nodeType: String                    // MemoryNodeType.rawValue
    var objectId: UUID?                     // Reference to source object (if applicable)
    var label: String                       // Display name
    var content: String                     // Summary content
    
    // Vector embedding (stored as data blob)
    var embeddingData: Data?                // Serialized embedding vector
    var embeddingDimensions: Int = 0        // Vector dimensions (e.g., 768)
    var embeddingModelName: String?         // Which model generated this embedding
    
    // Emotional weighting
    var emotionalToneRaw: String?           // Primary emotional tone (EmotionTone.rawValue)
    var emotionalIntensity: Double = 0.0    // 0.0 to 1.0
    var emotionalVolatility: Double = 0.0   // Variance in emotional intensity over time
    
    // Multi-dimensional importance components
    var recencyScore: Double = 0.5          // 0.0 to 1.0 - based on last access
    var semanticDensity: Double = 0.5       // 0.0 to 1.0 - connection density
    var clusterAssociationStrength: Double = 0.0  // 0.0 to 1.0 - theme/cluster strength
    
    // Temporal data
    var createdAt: Date = Date()
    var lastAccessedAt: Date = Date()
    var lastReinforcedAt: Date?             // When contextual reinforcement last occurred
    var accessCount: Int = 0
    
    // Graph metadata
    var importance: Double = 0.5            // 0.0 to 1.0 (computed from multi-dimensional components)
    var decay: Double = 1.0                 // Decay multiplier (1.0 = no decay)
    var tags: [String] = []
    var themeIds: [UUID] = []               // Themes this node belongs to
    
    // Relationships (edges stored separately for performance)
    var edgeCount: Int = 0                  // Cached count of edges
    
    /// Emotional tone (computed property)
    var emotionalTone: EmotionTone? {
        get {
            guard let raw = emotionalToneRaw else { return nil }
            return EmotionTone(rawValue: raw)
        }
        set {
            emotionalToneRaw = newValue?.rawValue
        }
    }
    
    init(
        nodeType: MemoryNodeType,
        objectId: UUID? = nil,
        label: String,
        content: String
    ) {
        self.nodeType = nodeType.rawValue
        self.objectId = objectId
        self.label = label
        self.content = content
        self.createdAt = Date()
        self.lastAccessedAt = Date()
    }
    
    var type: MemoryNodeType {
        get { MemoryNodeType(rawValue: nodeType) ?? .workspaceObject }
        set { nodeType = newValue.rawValue }
    }
    
    /// Set embedding from float array
    func setEmbedding(_ embedding: [Float]) {
        self.embeddingDimensions = embedding.count
        self.embeddingData = Data(bytes: embedding, count: embedding.count * MemoryLayout<Float>.size)
    }
    
    /// Get embedding as float array
    func getEmbedding() -> [Float]? {
        guard let data = embeddingData, embeddingDimensions > 0 else { return nil }
        let floatCount = embeddingDimensions
        return data.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self).prefix(floatCount))
        }
    }
    
    /// Calculate cosine similarity with another node
    func cosineSimilarity(with other: MemoryNode) -> Double {
        guard let embedding1 = getEmbedding(), let embedding2 = other.getEmbedding(),
              embedding1.count == embedding2.count else {
            return 0.0
        }
        
        var dotProduct: Float = 0.0
        var norm1: Float = 0.0
        var norm2: Float = 0.0
        
        for i in 0..<embedding1.count {
            dotProduct += embedding1[i] * embedding2[i]
            norm1 += embedding1[i] * embedding1[i]
            norm2 += embedding2[i] * embedding2[i]
        }
        
        let denominator = sqrt(norm1) * sqrt(norm2)
        return denominator > 0 ? Double(dotProduct / denominator) : 0.0
    }
    
    /// Apply decay to importance
    func applyDecay(factor: Double) {
        decay *= factor
        importance *= decay
    }
    
    /// Boost importance (e.g., on access)
    func boost(amount: Double = 0.1) {
        importance = min(1.0, importance + amount)
        decay = 1.0 // Reset decay on boost
        lastAccessedAt = Date()
        accessCount += 1
        recalculateImportance()
    }
    
    /// Recalculate multi-dimensional importance score
    func recalculateImportance() {
        // Calculate recency score (0-1, based on days since last access)
        let daysSinceAccess = Date().timeIntervalSince(lastAccessedAt) / 86400.0
        recencyScore = max(0.0, min(1.0, 1.0 - (daysSinceAccess / 90.0)))  // Decay over 90 days
        
        // Calculate semantic density from edge count
        semanticDensity = min(1.0, Double(edgeCount) / 10.0)  // Normalize to 10 edges = 1.0
        
        // Multi-dimensional importance (weighted sum)
        // 0.25 * recencyScore +
        // 0.25 * semanticDensity +
        // 0.20 * emotionalIntensity +
        // 0.15 * clusterAssociationStrength +
        // 0.15 * accessFrequency
        
        let accessFrequency = min(1.0, Double(accessCount) / 100.0)  // Normalize to 100 accesses = 1.0
        
        importance = (
            0.25 * recencyScore +
            0.25 * semanticDensity +
            0.20 * emotionalIntensity +
            0.15 * clusterAssociationStrength +
            0.15 * accessFrequency
        )
        
        // Clamp to 0-1
        importance = max(0.0, min(1.0, importance))
    }
}

