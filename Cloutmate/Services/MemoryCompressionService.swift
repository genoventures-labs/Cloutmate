//
//  MemoryCompressionService.swift
//  Cloutmate
//
//  Long-term memory compression with evolutionary decay
//

import Foundation
import SwiftData
import os.log
import CloutmateShared

@MainActor
final class MemoryCompressionService {
    static let shared = MemoryCompressionService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "MemoryCompression")
    
    private init() {}
    
    /// Compress old/inactive data (>90 days)
    func compressOldData(
        olderThanDays: Int = 90,
        modelContext: ModelContext
    ) async throws -> CompressionResult {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -olderThanDays, to: Date()) ?? Date()
        
        var compressedCount = 0
        var totalSpaceSaved: Int64 = 0
        
        // Compress old journal entries
        let journalResult = try await compressJournals(before: cutoffDate, modelContext: modelContext)
        compressedCount += journalResult.count
        totalSpaceSaved += journalResult.spaceSaved
        
        // Compress old notes
        let noteResult = try await compressNotes(before: cutoffDate, modelContext: modelContext)
        compressedCount += noteResult.count
        totalSpaceSaved += noteResult.spaceSaved
        
        // Compress old tasks (completed)
        let taskResult = try await compressTasks(before: cutoffDate, modelContext: modelContext)
        compressedCount += taskResult.count
        totalSpaceSaved += taskResult.spaceSaved
        
        // Archive inactive themes
        let themeResult = await archiveInactiveThemes(modelContext: modelContext)
        
        logger.info("Compressed \(compressedCount) items, saved \(totalSpaceSaved) bytes")
        
        return CompressionResult(
            itemsCompressed: compressedCount,
            spaceSaved: totalSpaceSaved,
            themesArchived: themeResult
        )
    }
    
    /// Compress journal entries
    private func compressJournals(
        before date: Date,
        modelContext: ModelContext
    ) async throws -> (count: Int, spaceSaved: Int64) {
        let descriptor = FetchDescriptor<Journal>(
            predicate: #Predicate { journal in
                journal.createdAt < date && journal.entryType == "Personal Reflection"
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        
        let journals = (try? modelContext.fetch(descriptor)) ?? []
        var compressed = 0
        var spaceSaved: Int64 = 0
        
        for journal in journals {
            // Check if already compressed
            let journalId = journal.id
            let existingSummary = try? modelContext.fetch(
                FetchDescriptor<MemorySummary>(
                    predicate: #Predicate { summary in
                        summary.originalObjectId == journalId
                    }
                )
            ).first
            
            if existingSummary != nil {
                continue // Already compressed
            }
            
            // Generate summary
            let summary = await generateSummary(for: journal.content, type: "journal")
            let originalSize = Int64(journal.content.utf8.count)
            let summarySize = Int64(summary.utf8.count)
            
            // Create MemorySummary
            let memorySummary = MemorySummary(
                originalObjectId: journal.id,
                originalObjectType: "journal",
                summaryText: summary,
                compressionRatio: Double(summarySize) / Double(originalSize)
            )
            
            // Generate embedding
            if let embedding = try? await generateEmbedding(for: summary) {
                memorySummary.setEmbedding(embedding)
            }
            
            // Extract keywords and themes
            memorySummary.keywords = extractKeywords(from: journal.content)
            memorySummary.themes = extractThemes(from: journal.content, modelContext: modelContext)
            
            modelContext.insert(memorySummary)
            
            // Mark journal as archived (or delete if desired)
            journal.isArchived = true
            
            compressed += 1
            spaceSaved += (originalSize - summarySize)
        }
        
        try modelContext.save()
        
        return (compressed, spaceSaved)
    }
    
    /// Compress notes
    private func compressNotes(
        before date: Date,
        modelContext: ModelContext
    ) async throws -> (count: Int, spaceSaved: Int64) {
        let descriptor = FetchDescriptor<CloutmateShared.Note>(
            predicate: #Predicate { note in
                note.createdAt < date && note.isArchived == false
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        
        let notes = (try? modelContext.fetch(descriptor)) ?? []
        var compressed = 0
        var spaceSaved: Int64 = 0
        
        for note in notes {
            // Check if already compressed
            let noteId = note.id
            let existingSummary = try? modelContext.fetch(
                FetchDescriptor<MemorySummary>(
                    predicate: #Predicate { summary in
                        summary.originalObjectId == noteId
                    }
                )
            ).first
            
            if existingSummary != nil {
                continue
            }
            
            let summary = await generateSummary(for: note.markdown, type: "note")
            let originalSize = Int64(note.markdown.utf8.count)
            let summarySize = Int64(summary.utf8.count)
            
            let memorySummary = MemorySummary(
                originalObjectId: note.id,
                originalObjectType: "note",
                summaryText: summary,
                compressionRatio: Double(summarySize) / Double(originalSize)
            )
            
            if let embedding = try? await generateEmbedding(for: summary) {
                memorySummary.setEmbedding(embedding)
            }
            
            memorySummary.keywords = extractKeywords(from: note.markdown)
            memorySummary.themes = extractThemes(from: note.markdown, modelContext: modelContext)
            
            modelContext.insert(memorySummary)
            note.isArchived = true
            
            compressed += 1
            spaceSaved += (originalSize - summarySize)
        }
        
        try modelContext.save()
        
        return (compressed, spaceSaved)
    }
    
    /// Compress completed tasks
    private func compressTasks(
        before date: Date,
        modelContext: ModelContext
    ) async throws -> (count: Int, spaceSaved: Int64) {
        let descriptor = FetchDescriptor<CloutmateShared.Task>(
            predicate: #Predicate { task in
                task.statusRaw == "done" && task.completedAt != nil && task.completedAt! < date
            },
            sortBy: [SortDescriptor(\.completedAt, order: .forward)]
        )
        
        let tasks = (try? modelContext.fetch(descriptor)) ?? []
        var compressed = 0
        var spaceSaved: Int64 = 0
        
        for task in tasks {
            let taskId = task.id
            let existingSummary = try? modelContext.fetch(
                FetchDescriptor<MemorySummary>(
                    predicate: #Predicate { summary in
                        summary.originalObjectId == taskId
                    }
                )
            ).first
            
            if existingSummary != nil {
                continue
            }
            
            let content = "\(task.title)\n\(task.notes ?? "")"
            let summary = await generateSummary(for: content, type: "task")
            let originalSize = Int64(content.utf8.count)
            let summarySize = Int64(summary.utf8.count)
            
            let memorySummary = MemorySummary(
                originalObjectId: task.id,
                originalObjectType: "task",
                summaryText: summary,
                compressionRatio: Double(summarySize) / Double(originalSize)
            )
            
            if let embedding = try? await generateEmbedding(for: summary) {
                memorySummary.setEmbedding(embedding)
            }
            
            memorySummary.keywords = extractKeywords(from: content)
            
            modelContext.insert(memorySummary)
            
            compressed += 1
            spaceSaved += (originalSize - summarySize)
        }
        
        try modelContext.save()
        
        return (compressed, spaceSaved)
    }
    
    /// Archive inactive themes (>90 days of inactivity)
    private func archiveInactiveThemes(modelContext: ModelContext) async -> Int {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<ThemeNode>(
            predicate: #Predicate { theme in
                theme.isActive == true && theme.lastUpdateAt < cutoffDate
            }
        )
        
        let inactiveThemes = (try? modelContext.fetch(descriptor)) ?? []
        
        for theme in inactiveThemes {
            theme.isActive = false
        }
        
        try? modelContext.save()
        
        return inactiveThemes.count
    }
    
    /// Revive a compressed memory on mention/reuse
    func reviveMemory(
        for objectId: UUID,
        modelContext: ModelContext
    ) -> MemorySummary? {
        let descriptor = FetchDescriptor<MemorySummary>(
            predicate: #Predicate { summary in
                summary.originalObjectId == objectId && summary.isArchived == true
            }
        )
        
        guard let summary = try? modelContext.fetch(descriptor).first else {
            return nil
        }
        
        summary.revive()
        try? modelContext.save()
        
        logger.info("Revived memory summary for object \(objectId.uuidString)")
        
        return summary
    }
    
    /// Gradually reduce relevance weight for unused nodes
    func applyEvolutionaryDecay(
        modelContext: ModelContext
    ) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<MemoryNode>(
            predicate: #Predicate { node in
                node.lastAccessedAt < cutoffDate
            }
        )
        
        let unusedNodes = (try? modelContext.fetch(descriptor)) ?? []
        
        for node in unusedNodes {
            // Apply decay multiplier
            let daysSinceAccess = Date().timeIntervalSince(node.lastAccessedAt) / 86400
            let decayFactor = max(0.1, 1.0 - (daysSinceAccess / 365.0)) // Decay over a year
            node.decay = decayFactor
            node.importance *= decayFactor
        }
        
        try? modelContext.save()
        
        logger.info("Applied evolutionary decay to \(unusedNodes.count) nodes")
    }
    
    // MARK: - Helper Methods
    
    private func generateSummary(for content: String, type: String) async -> String {
        // Use NarrativeEngine or OllamaBridgeService to generate summary
        // For now, return a simple truncation
        // In production, would use AI to generate meaningful summaries
        
        if content.count > 500 {
            return String(content.prefix(200)) + "... [compressed]"
        }
        return content
    }
    
    private func generateEmbedding(for text: String) async throws -> [Float] {
        // Use MemoryGraphService embedding generation
        return try await MemoryGraphService.shared.generateEmbedding(for: text)
    }
    
    private func extractKeywords(from text: String) -> [String] {
        // Simple keyword extraction
        // In production, would use NLP or AI
        let words = text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 4 }
        
        let wordCounts = Dictionary(grouping: words, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        return Array(wordCounts.prefix(5).map { $0.key })
    }
    
    private func extractThemes(from text: String, modelContext: ModelContext) -> [String] {
        // Get themes from MemoryGraphService
        let themes = MemoryGraphService.shared.getActiveThemes(modelContext: modelContext)
        
        // Match text content to themes
        let textLower = text.lowercased()
        return themes.filter { theme in
            theme.keywords.contains { keyword in
                textLower.contains(keyword.lowercased())
            }
        }.map { $0.label }
    }
}

// MARK: - Compression Result

struct CompressionResult {
    let itemsCompressed: Int
    let spaceSaved: Int64
    let themesArchived: Int
}

