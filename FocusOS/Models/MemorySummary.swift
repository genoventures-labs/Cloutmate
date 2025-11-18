//
//  MemorySummary.swift
//  FocusOS
//
//  Compressed memory summaries with vector embeddings
//

import Foundation
import SwiftData

/// Compression mode used for generating memory summaries
enum CompressionMode: String, Codable, CaseIterable {
    case semantic = "semantic"       // AI-generated semantic summary
    case extractive = "extractive"   // Key sentence extraction
    case hybrid = "hybrid"           // Combination of semantic + extractive
}

@Model
final class MemorySummary {
    @Attribute(.unique) var id: UUID
    var originalObjectId: UUID?              // Reference to original object
    var originalObjectType: String           // "task", "note", "journal", etc.
    var summaryText: String                  // Compressed summary
    var compressedAt: Date                   // When compression occurred
    var compressionRatio: Double             // 0.0 to 1.0 (how much was compressed)
    
    // Vector embedding for fast recall
    var embeddingData: Data?                 // Serialized embedding vector
    var embeddingDimensions: Int = 0
    
    // Metadata
    var keywords: [String] = []              // Key terms extracted
    var themes: [String] = []                // Associated themes
    var isArchived: Bool = false             // Archived from active memory
    var revivalCount: Int = 0                // Times this summary was revived
    
    // Link to original for full recall
    var originalContentHash: String?         // Hash of original content
    
    // Generation metadata (for forward compatibility with Aurora version upgrades)
    var modelName: String?                   // Which model was used (e.g., "qwen3:1.7b", "granite3.2:2b")
    var promptVersion: String?               // Which prompt version ID was used (from AuroraSystemPromptBuilder)
    var compressionModeRaw: String?          // Which compression mode was used (semantic, extractive, hybrid)
    
    /// Compression mode (computed property for type safety)
    var compressionMode: CompressionMode? {
        get {
            guard let raw = compressionModeRaw else { return nil }
            return CompressionMode(rawValue: raw)
        }
        set {
            compressionModeRaw = newValue?.rawValue
        }
    }
    
    init(
        originalObjectId: UUID?,
        originalObjectType: String,
        summaryText: String,
        compressionRatio: Double,
        modelName: String? = nil,
        promptVersion: String? = nil,
        compressionMode: CompressionMode? = nil
    ) {
        self.id = UUID()
        self.originalObjectId = originalObjectId
        self.originalObjectType = originalObjectType
        self.summaryText = summaryText
        self.compressionRatio = compressionRatio
        self.compressedAt = Date()
        self.isArchived = false
        self.revivalCount = 0
        self.modelName = modelName
        self.promptVersion = promptVersion
        self.compressionMode = compressionMode
    }
    
    /// Set embedding vector
    func setEmbedding(_ embedding: [Float]) {
        self.embeddingDimensions = embedding.count
        self.embeddingData = try? JSONEncoder().encode(embedding)
    }
    
    /// Get embedding vector
    func getEmbedding() -> [Float]? {
        guard let data = embeddingData else { return nil }
        return try? JSONDecoder().decode([Float].self, from: data)
    }
    
    /// Revive this summary (mark as active again)
    func revive() {
        isArchived = false
        revivalCount += 1
    }
}

