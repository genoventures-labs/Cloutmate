//
//  MemoryCompressionService.swift
//  Cloutmate
//
//  AI-powered memory compression with multi-dimensional decay and contextual revival
//  Upgraded to OpenAI-style persistent memory layer
//

import Foundation
import SwiftData
import os.log
import CloutmateShared

/// Compression bundle containing all metadata for a compressed memory
struct CompressionBundle {
    let summary: String
    let semanticSummary: String?
    let structuralInsights: String?
    let emotionalTone: EmotionalSnapshot
    let keywords: [String]
    let themes: [String]
    let modelName: String
    let promptVersion: String
    let compressionMode: CompressionMode
    let arteState: EmotionalState?
    let clusterId: String?
}

@MainActor
final class MemoryCompressionService {
    static let shared = MemoryCompressionService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "MemoryCompression")
    
    // Compression configuration
    private let semanticModel = "gemma3:4b"
    private let structuralModel = "deepseek-r1:1.5b"
    private let similarityThreshold = 0.75  // For duplicate detection
    
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
        
        // Detect and merge similar memories
        let mergedCount = await detectAndMergeSimilarMemories(modelContext: modelContext)
        
        logger.info("Compressed \(compressedCount) items, saved \(totalSpaceSaved) bytes, merged \(mergedCount) duplicates")
        
        return CompressionResult(
            itemsCompressed: compressedCount,
            spaceSaved: totalSpaceSaved,
            themesArchived: themeResult,
            duplicatesMerged: mergedCount
        )
    }
    
    // MARK: - Compression Methods
    
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
            
            // Generate AI-powered summary bundle
            let bundle = try await generateCompressionBundle(
                for: journal.content,
                type: "journal",
                modelContext: modelContext
            )
            
            let originalSize = Int64(journal.content.utf8.count)
            let summarySize = Int64(bundle.summary.utf8.count)
            
            // Create MemorySummary with full metadata
            let memorySummary = MemorySummary(
                originalObjectId: journal.id,
                originalObjectType: "journal",
                summaryText: bundle.summary,
                compressionRatio: Double(summarySize) / Double(originalSize),
                modelName: bundle.modelName,
                promptVersion: bundle.promptVersion,
                compressionMode: bundle.compressionMode
            )
            
            // Store additional metadata in summary text if needed
            if let semantic = bundle.semanticSummary, !semantic.isEmpty {
                memorySummary.summaryText += "\n\n[Semantic: \(semantic)]"
            }
            
            // Generate embedding
            if let embedding = try? await generateEmbedding(for: bundle.summary) {
                memorySummary.setEmbedding(embedding)
            }
            
            // Set keywords and themes
            memorySummary.keywords = bundle.keywords
            memorySummary.themes = bundle.themes
            
            // Store content hash for deduplication
            memorySummary.originalContentHash = journal.content.hashValue.description
            
            modelContext.insert(memorySummary)
            
            // Mark journal as archived
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
            
            let bundle = try await generateCompressionBundle(
                for: note.markdown,
                type: "note",
                modelContext: modelContext
            )
            
            let originalSize = Int64(note.markdown.utf8.count)
            let summarySize = Int64(bundle.summary.utf8.count)
            
            let memorySummary = MemorySummary(
                originalObjectId: note.id,
                originalObjectType: "note",
                summaryText: bundle.summary,
                compressionRatio: Double(summarySize) / Double(originalSize),
                modelName: bundle.modelName,
                promptVersion: bundle.promptVersion,
                compressionMode: bundle.compressionMode
            )
            
            if let semantic = bundle.semanticSummary, !semantic.isEmpty {
                memorySummary.summaryText += "\n\n[Semantic: \(semantic)]"
            }
            
            if let embedding = try? await generateEmbedding(for: bundle.summary) {
                memorySummary.setEmbedding(embedding)
            }
            
            memorySummary.keywords = bundle.keywords
            memorySummary.themes = bundle.themes
            memorySummary.originalContentHash = note.markdown.hashValue.description
            
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
            let bundle = try await generateCompressionBundle(
                for: content,
                type: "task",
                modelContext: modelContext
            )
            
            let originalSize = Int64(content.utf8.count)
            let summarySize = Int64(bundle.summary.utf8.count)
            
            let memorySummary = MemorySummary(
                originalObjectId: task.id,
                originalObjectType: "task",
                summaryText: bundle.summary,
                compressionRatio: Double(summarySize) / Double(originalSize),
                modelName: bundle.modelName,
                promptVersion: bundle.promptVersion,
                compressionMode: bundle.compressionMode
            )
            
            if let embedding = try? await generateEmbedding(for: bundle.summary) {
                memorySummary.setEmbedding(embedding)
            }
            
            memorySummary.keywords = bundle.keywords
            memorySummary.originalContentHash = content.hashValue.description
            
            modelContext.insert(memorySummary)
            
            compressed += 1
            spaceSaved += (originalSize - summarySize)
        }
        
        try modelContext.save()
        
        return (compressed, spaceSaved)
    }
    
    // MARK: - AI-Powered Summary Generation
    
    /// Generate compression bundle using AI models
    private func generateCompressionBundle(
        for content: String,
        type: String,
        modelContext: ModelContext
    ) async throws -> CompressionBundle {
        // Get current prompt version
        let promptVersion = await AuroraSystemPromptBuilder.shared.getCurrentVersion()
        
        // Get current ARTE state
        let arteState = ReactiveThemeManager.shared.currentEmotion()
        
        // Analyze emotional tone
        let emotionalTone = EmotionAnalyzer.analyzeTone(text: content)
        
        // Determine compression mode based on content
        let compressionMode: CompressionMode = content.count > 2000 ? .hybrid : .semantic
        
        // Generate semantic summary using gemma3:4b
        let semanticSummary = try await generateSemanticSummary(
            content: content,
            type: type,
            model: semanticModel
        )
        
        // Generate structural insights using deepseek-r1 (optional, for long content)
        let structuralInsights: String? = content.count > 1000 ? try? await generateStructuralInsights(
            content: content,
            model: structuralModel
        ) : nil
        
        // Combine summaries based on compression mode
        let finalSummary: String
        switch compressionMode {
        case .semantic:
            finalSummary = semanticSummary
        case .extractive:
            finalSummary = extractKeySentences(from: content)
        case .hybrid:
            let extractive = extractKeySentences(from: content)
            finalSummary = "\(semanticSummary)\n\n[Key points: \(extractive)]"
        }
        
        // Extract keywords using MemoryGraphService context
        let keywords = await extractContextualKeywords(
            from: content,
            modelContext: modelContext
        )
        
        // Extract themes using embedding similarity
        let themes = await extractThemesWithEmbeddings(
            from: content,
            modelContext: modelContext
        )
        
        // Get cluster context if available
        let clusterId = await getClusterContext(for: content, modelContext: modelContext)
        
        return CompressionBundle(
            summary: finalSummary,
            semanticSummary: semanticSummary,
            structuralInsights: structuralInsights,
            emotionalTone: emotionalTone,
            keywords: keywords,
            themes: themes,
            modelName: semanticModel,
            promptVersion: promptVersion,
            compressionMode: compressionMode,
            arteState: arteState,
            clusterId: clusterId
        )
    }
    
    /// Generate semantic summary using AI model
    private func generateSemanticSummary(
        content: String,
        type: String,
        model: String
    ) async throws -> String {
        // Use OllamaBridgeService to generate summary
        // For now, use a prompt-based approach
        let prompt = """
        Summarize this \(type) entry, preserving key insights, emotional context, and important details.
        Keep it concise but meaningful (aim for 20-30% of original length).
        
        Content:
        \(content)
        
        Summary:
        """
        
        // Try to use OllamaBridgeService - fallback to heuristic if unavailable
        do {
            // This would call OllamaBridgeService.generateResponse with the model
            // For now, use a fallback heuristic
            return try await generateSummaryWithOllama(prompt: prompt, model: model) ?? extractKeySentences(from: content)
        } catch {
            logger.warning("Failed to generate AI summary, using fallback: \(error.localizedDescription)")
            return extractKeySentences(from: content)
        }
    }
    
    /// Generate structural insights using reasoning model
    private func generateStructuralInsights(
        content: String,
        model: String
    ) async throws -> String {
        let prompt = """
        Extract structural insights from this content:
        - Key events or milestones
        - Logical flow or sequence
        - Important relationships or connections
        - Action items or decisions
        
        Content:
        \(content)
        
        Insights:
        """
        
        return try await generateSummaryWithOllama(prompt: prompt, model: model) ?? ""
    }
    
    /// Generate summary using Ollama (placeholder - would integrate with OllamaBridgeService)
    private func generateSummaryWithOllama(prompt: String, model: String) async throws -> String? {
        // TODO: Integrate with OllamaBridgeService.generateResponse
        // For now, return nil to trigger fallback
        return nil
    }
    
    /// Extract key sentences (extractive mode fallback)
    private func extractKeySentences(from text: String) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 20 }
        
        // Score sentences by position, length, and keyword density
        let importantKeywords = ["important", "key", "note", "action", "task", "goal", "objective", "summary", "conclusion", "result"]
        
        let scored = sentences.enumerated().map { index, sentence -> (sentence: String, score: Double) in
            let positionScore = index < 3 ? 1.0 : max(0.3, 1.0 - Double(index) * 0.05)
            let lengthScore = sentence.count > 50 && sentence.count < 200 ? 1.0 : 0.7
            let keywordScore = importantKeywords.contains { sentence.lowercased().contains($0.lowercased()) } ? 1.2 : 1.0
            
            return (sentence, positionScore * lengthScore * keywordScore)
        }
        
        let topSentences = scored
            .sorted { $0.score > $1.score }
            .prefix(min(5, sentences.count / 3))
            .map { $0.sentence }
        
        return topSentences.joined(separator: ". ") + "."
    }
    
    // MARK: - Enhanced Theme Extraction
    
    /// Extract themes using embedding similarity
    private func extractThemesWithEmbeddings(
        from text: String,
        modelContext: ModelContext
    ) async -> [String] {
        guard AIConfigService.shared.config.featureFlags.memoryGraphEnabled else {
            return extractThemesLegacy(from: text, modelContext: modelContext)
        }
        
        do {
            // Generate embedding for text
            let textEmbedding = try await MemoryGraphService.shared.generateEmbedding(for: text)
            
        // Get all active themes
        let themeDescriptor = FetchDescriptor<ThemeNode>(
            predicate: #Predicate { theme in
                theme.isActive == true
            }
        )
        let themes = (try? modelContext.fetch(themeDescriptor)) ?? []
            
            var matchingThemes: [String] = []
            
            for theme in themes {
                // Get theme embedding (would need to be stored in ThemeNode)
                // For now, use keyword matching as fallback
                let themeKeywords = theme.keywords
                let textLower = text.lowercased()
                
                // Check keyword overlap
                let keywordMatches = themeKeywords.filter { keyword in
                    textLower.contains(keyword.lowercased())
                }.count
                
                // If significant keyword overlap, consider it a match
                if keywordMatches >= max(1, themeKeywords.count / 2) {
                    matchingThemes.append(theme.label)
                }
            }
            
            return matchingThemes
        } catch {
            logger.error("Failed to extract themes with embeddings: \(error.localizedDescription)")
            return extractThemesLegacy(from: text, modelContext: modelContext)
        }
    }
    
    /// Legacy theme extraction (fallback)
    private func extractThemesLegacy(from text: String, modelContext: ModelContext) -> [String] {
        let themeDescriptor = FetchDescriptor<ThemeNode>(
            predicate: #Predicate { theme in
                theme.isActive == true
            }
        )
        let themes = (try? modelContext.fetch(themeDescriptor)) ?? []
        let textLower = text.lowercased()
        return themes.filter { theme in
            theme.keywords.contains { keyword in
                textLower.contains(keyword.lowercased())
            }
        }.map { $0.label }
    }
    
    /// Extract contextual keywords using MemoryGraphService
    private func extractContextualKeywords(
        from text: String,
        modelContext: ModelContext
    ) async -> [String] {
        // Use MemoryGraphService to find related concepts
        let words = text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 4 }
        
        let wordCounts = Dictionary(grouping: words, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        // Get top keywords
        var keywords = Array(wordCounts.prefix(5).map { $0.key })
        
        // Enhance with MemoryGraph context if available
        if AIConfigService.shared.config.featureFlags.memoryGraphEnabled {
            // Could add semantic keyword extraction here
        }
        
        return keywords
    }
    
    /// Get cluster context for content
    private func getClusterContext(
        for content: String,
        modelContext: ModelContext
    ) async -> String? {
        // This would integrate with IntentClusterSummary from ConversationArchive
        // For now, return nil
        return nil
    }
    
    // MARK: - Multi-Dimensional Decay
    
    /// Apply multi-dimensional decay to memory nodes
    func applyMultiDimensionalDecay(
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
            let decayFactor = calculateDecayFactor(
                for: node,
                modelContext: modelContext
            )
            
            node.decay = decayFactor
            node.importance *= decayFactor
        }
        
        try? modelContext.save()
        
        logger.info("Applied multi-dimensional decay to \(unusedNodes.count) nodes")
    }
    
    /// Calculate decay factor using multiple dimensions
    private func calculateDecayFactor(
        for node: MemoryNode,
        modelContext: ModelContext
    ) -> Double {
        var factors: [Double] = []
        
        // 1. Time since access
        let daysSinceAccess = Date().timeIntervalSince(node.lastAccessedAt) / 86400
        let timeFactor = max(0.1, 1.0 - (daysSinceAccess / 365.0))
        factors.append(timeFactor)
        
        // 2. Memory importance (higher importance = slower decay)
        let importanceFactor = min(1.0, node.importance + 0.2)
        factors.append(importanceFactor)
        
        // 3. Connection density (more connections = slower decay)
        let connectionFactor = min(1.0, 0.5 + (Double(node.edgeCount) / 10.0))
        factors.append(connectionFactor)
        
        // 4. Emotional intensity (if available from related summaries)
        let emotionalFactor = 1.0 // Would check related MemorySummary emotional tone
        factors.append(emotionalFactor)
        
        // 5. Cluster predictive likelihood (if in active cluster)
        let clusterFactor = 1.0 // Would check if node is in active intent cluster
        factors.append(clusterFactor)
        
        // Weighted average
        let weights: [Double] = [0.3, 0.2, 0.2, 0.15, 0.15]
        let weightedSum = zip(factors, weights).map { $0 * $1 }.reduce(0, +)
        let weightSum = weights.reduce(0, +)
        
        return max(0.1, min(1.0, weightedSum / weightSum))
    }
    
    // MARK: - Memory Graph Reinforcement
    
    /// Revive a compressed memory with graph reinforcement
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
        
        // Reinforce memory graph
        reinforceMemoryGraph(
            for: summary,
            modelContext: modelContext
        )
        
        try? modelContext.save()
        
        logger.info("Revived memory summary for object \(objectId.uuidString) with graph reinforcement")
        
        return summary
    }
    
    /// Reinforce memory graph on revival
    private func reinforceMemoryGraph(
        for summary: MemorySummary,
        modelContext: ModelContext
    ) {
        guard AIConfigService.shared.config.featureFlags.memoryGraphEnabled else {
            return
        }
        
        // Find related memory nodes
        guard let summaryEmbedding = summary.getEmbedding() else {
            return
        }
        
        // Find similar nodes in memory graph
        let descriptor = FetchDescriptor<MemoryNode>()
        guard let allNodes = try? modelContext.fetch(descriptor) else {
            return
        }
        
        // Boost importance of similar nodes
        for node in allNodes {
            guard let nodeEmbedding = node.getEmbedding(),
                  nodeEmbedding.count == summaryEmbedding.count else {
                continue
            }
            
            // Calculate similarity
            let similarity = cosineSimilarity(summaryEmbedding, nodeEmbedding)
            
            if similarity > 0.7 {
                // Boost this node
                node.boost(amount: 0.1)
                
                // Boost neighbors (would need to fetch edges)
                // For now, just boost the node itself
            }
        }
        
        // Update theme activity
        for themeLabel in summary.themes {
            // Would update ThemeNode activity here
        }
    }
    
    /// Calculate cosine similarity between two embeddings
    private func cosineSimilarity(_ vecA: [Float], _ vecB: [Float]) -> Double {
        guard vecA.count == vecB.count else { return 0.0 }
        
        var dotProduct: Float = 0.0
        var normA: Float = 0.0
        var normB: Float = 0.0
        
        for i in 0..<vecA.count {
            dotProduct += vecA[i] * vecB[i]
            normA += vecA[i] * vecA[i]
            normB += vecB[i] * vecB[i]
        }
        
        let denominator = sqrt(normA) * sqrt(normB)
        return denominator > 0 ? Double(dotProduct / denominator) : 0.0
    }
    
    // MARK: - Similarity Clustering
    
    /// Detect and merge similar memories
    private func detectAndMergeSimilarMemories(
        modelContext: ModelContext
    ) async -> Int {
        let descriptor = FetchDescriptor<MemorySummary>(
            predicate: #Predicate { summary in
                summary.isArchived == false
            }
        )
        
        guard let summaries = try? modelContext.fetch(descriptor) else {
            return 0
        }
        
        var mergedCount = 0
        var processed: Set<UUID> = []
        
        for summary in summaries {
            guard !processed.contains(summary.id),
                  let embedding = summary.getEmbedding() else {
                continue
            }
            
            // Find similar summaries
            var similarSummaries: [MemorySummary] = []
            
            for other in summaries {
                guard other.id != summary.id,
                      !processed.contains(other.id),
                      let otherEmbedding = other.getEmbedding() else {
                    continue
                }
                
                let similarity = cosineSimilarity(embedding, otherEmbedding)
                
                if similarity >= similarityThreshold {
                    similarSummaries.append(other)
                }
            }
            
            if !similarSummaries.isEmpty {
                // Merge similar summaries
                await mergeSummaries(
                    primary: summary,
                    duplicates: similarSummaries,
                    modelContext: modelContext
                )
                
                processed.insert(summary.id)
                for duplicate in similarSummaries {
                    processed.insert(duplicate.id)
                }
                
                mergedCount += similarSummaries.count
            }
        }
        
        try? modelContext.save()
        
        return mergedCount
    }
    
    /// Merge duplicate summaries
    private func mergeSummaries(
        primary: MemorySummary,
        duplicates: [MemorySummary],
        modelContext: ModelContext
    ) async {
        // Combine themes and keywords
        var allThemes = Set(primary.themes)
        var allKeywords = Set(primary.keywords)
        
        for duplicate in duplicates {
            allThemes.formUnion(duplicate.themes)
            allKeywords.formUnion(duplicate.keywords)
            
            // Update primary summary
            primary.themes = Array(allThemes)
            primary.keywords = Array(allKeywords)
            
            // Mark duplicate as archived
            duplicate.isArchived = true
        }
        
        logger.info("Merged \(duplicates.count) duplicate summaries into \(primary.id)")
    }
    
    // MARK: - Contextual Auto-Revive
    
    /// Auto-revive related summaries based on conversation context
    func autoReviveRelatedSummaries(
        for themeCluster: String,
        similarityThreshold: Double = 0.7,
        modelContext: ModelContext
    ) async -> [MemorySummary] {
        guard AIConfigService.shared.config.featureFlags.memoryGraphEnabled else {
            return []
        }
        
        // Find summaries matching the theme cluster
        let descriptor = FetchDescriptor<MemorySummary>(
            predicate: #Predicate { summary in
                summary.isArchived == true
            }
        )
        
        guard let archivedSummaries = try? modelContext.fetch(descriptor) else {
            return []
        }
        
        var revived: [MemorySummary] = []
        
        for summary in archivedSummaries {
            // Check if summary matches theme
            if summary.themes.contains(themeCluster) {
                summary.revive()
                reinforceMemoryGraph(for: summary, modelContext: modelContext)
                revived.append(summary)
            }
        }
        
        try? modelContext.save()
        
        logger.info("Auto-revived \(revived.count) summaries for theme cluster: \(themeCluster)")
        
        return revived
    }
    
    // MARK: - Helper Methods
    
    private func generateEmbedding(for text: String) async throws -> [Float] {
        return try await MemoryGraphService.shared.generateEmbedding(for: text)
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
}

// MARK: - Compression Result

struct CompressionResult {
    let itemsCompressed: Int
    let spaceSaved: Int64
    let themesArchived: Int
    var duplicatesMerged: Int = 0
}
