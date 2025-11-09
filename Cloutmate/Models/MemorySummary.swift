//
//  MemorySummary.swift
//  Cloutmate
//
//  Compressed memory summaries with vector embeddings
//

import Foundation
import SwiftData

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
    
    init(
        originalObjectId: UUID?,
        originalObjectType: String,
        summaryText: String,
        compressionRatio: Double
    ) {
        self.id = UUID()
        self.originalObjectId = originalObjectId
        self.originalObjectType = originalObjectType
        self.summaryText = summaryText
        self.compressionRatio = compressionRatio
        self.compressedAt = Date()
        self.isArchived = false
        self.revivalCount = 0
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

