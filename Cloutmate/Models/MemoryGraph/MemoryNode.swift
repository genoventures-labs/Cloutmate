//
//  MemoryNode.swift
//  Cloutmate
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
    
    // Temporal data
    var createdAt: Date = Date()
    var lastAccessedAt: Date = Date()
    var accessCount: Int = 0
    
    // Graph metadata
    var importance: Double = 0.5            // 0.0 to 1.0
    var decay: Double = 1.0                 // Decay multiplier (1.0 = no decay)
    var tags: [String] = []
    
    // Relationships (edges stored separately for performance)
    var edgeCount: Int = 0                  // Cached count of edges
    
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
    }
}

