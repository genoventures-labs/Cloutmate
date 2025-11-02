//
//  ConceptTracker.swift
//  Cloutmate
//
//  Phase 5: Narrative Engine - Concept Tracking Service
//  Extracts and tracks concepts with dynamic weighting across workspace
//

import Foundation
import SwiftData
import os.log
import NaturalLanguage

@MainActor
final class ConceptTracker {
    static let shared = ConceptTracker()
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "ConceptTracker")
    private var cache: [String: ConceptNode] = [:]
    private var lastCacheRefresh: Date?
    private let cacheValidity: TimeInterval = 300  // 5 minutes
    
    private init() {}
    
    private var config: AIConfig { AIConfigService.shared.config }
    
    // MARK: - Concept Extraction
    
    /// Extract concepts from text and update tracking
    func trackConcepts(
        in text: String,
        fromObjectId objectId: UUID,
        contextType: String,  // "note", "task", "journal", "draft", etc.
        modelContext: ModelContext
    ) {
        guard config.featureFlags.narrativeEnabled else { return }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Extract concepts using NLP
        let concepts = extractConcepts(from: text)
        
        // Analyze emotional tone
        let emotionalSnapshot = EmotionAnalyzer.analyzeTone(text: text)
        
        // Update or create concept nodes
        for concept in concepts {
            updateConcept(
                concept: concept,
                objectId: objectId,
                contextType: contextType,
                emotionalIntensity: emotionalSnapshot.intensity,
                emotionalValence: emotionalSnapshot.valence,
                modelContext: modelContext
            )
        }
        
        AIDebug.log("Tracked \(concepts.count) concepts from \(contextType)")
    }
    
    /// Extract meaningful concepts from text using NLP
    private func extractConcepts(from text: String) -> [String] {
        var concepts: [String] = []
        
        // Use NaturalLanguage framework for named entity recognition
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = text
        
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]
        let tags: [NLTag] = [.personalName, .placeName, .organizationName]
        
        // Extract named entities
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            if let tag = tag, tags.contains(tag) {
                let concept = String(text[tokenRange])
                if concept.count >= 3 {  // Minimum length
                    concepts.append(concept)
                }
            }
            return true
        }
        
        // Extract significant nouns and noun phrases
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, tokenRange in
            if tag == .noun {
                let word = String(text[tokenRange])
                // Only track meaningful nouns (length >= 4, not common words)
                if word.count >= 4 && !isCommonWord(word) {
                    concepts.append(word.capitalized)
                }
            }
            return true
        }
        
        // Extract keywords based on capitalization patterns (likely important)
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        for word in words {
            let cleaned = word.trimmingCharacters(in: .punctuationCharacters)
            // Look for capitalized words that aren't sentence starts
            if cleaned.count >= 4 && cleaned.first?.isUppercase == true {
                if !concepts.contains(cleaned) {
                    concepts.append(cleaned)
                }
            }
        }
        
        // Deduplicate and limit
        let uniqueConcepts = Array(Set(concepts)).prefix(10)
        return Array(uniqueConcepts)
    }
    
    /// Check if word is a common word (stopword)
    private func isCommonWord(_ word: String) -> Bool {
        let stopWords = Set([
            "this", "that", "these", "those", "what", "which", "who", "when", "where",
            "have", "been", "will", "would", "could", "should", "might", "must",
            "some", "many", "much", "more", "most", "other", "such", "here", "there"
        ])
        return stopWords.contains(word.lowercased())
    }
    
    // MARK: - Concept Management
    
    /// Update or create a concept node
    private func updateConcept(
        concept: String,
        objectId: UUID,
        contextType: String,
        emotionalIntensity: Double,
        emotionalValence: Double,
        modelContext: ModelContext
    ) {
        let normalized = concept.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try to find existing concept
        let existingNode = getNode(for: normalized, modelContext: modelContext)
        
        if let node = existingNode {
            // Update existing
            node.recordMention(
                from: objectId,
                contextType: contextType,
                emotionalIntensity: emotionalIntensity,
                emotionalValence: emotionalValence
            )
            node.calculateRelevance()
            cache[normalized] = node
        } else {
            // Create new
            let newNode = ConceptNode(concept: concept)
            newNode.recordMention(
                from: objectId,
                contextType: contextType,
                emotionalIntensity: emotionalIntensity,
                emotionalValence: emotionalValence
            )
            newNode.calculateRelevance()
            modelContext.insert(newNode)
            cache[normalized] = newNode
        }
        
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save concept node: \(error.localizedDescription)")
        }
    }
    
    /// Get concept node by normalized name
    private func getNode(for normalizedConcept: String, modelContext: ModelContext) -> ConceptNode? {
        // Check cache first
        if let cached = cache[normalizedConcept] {
            return cached
        }
        
        // Fetch from database
        let descriptor = FetchDescriptor<ConceptNode>(
            predicate: #Predicate { $0.normalizedConcept == normalizedConcept }
        )
        
        if let node = try? modelContext.fetch(descriptor).first {
            cache[normalizedConcept] = node
            return node
        }
        
        return nil
    }
    
    // MARK: - Retrieval
    
    /// Get all "alive" concepts (relevanceWeight > 0.3)
    func getAliveConcepts(modelContext: ModelContext) -> [ConceptNode] {
        refreshCacheIfNeeded(modelContext: modelContext)
        
        let descriptor = FetchDescriptor<ConceptNode>(
            sortBy: [SortDescriptor(\.relevanceWeight, order: .reverse)]
        )
        
        guard let nodes = try? modelContext.fetch(descriptor) else { return [] }
        
        // Recalculate relevance for all nodes
        for node in nodes {
            node.calculateRelevance()
        }
        
        // Save updates
        try? modelContext.save()
        
        return nodes.filter { $0.isAlive }
    }
    
    /// Get top N concepts by relevance
    func getTopConcepts(limit: Int = 10, modelContext: ModelContext) -> [ConceptNode] {
        refreshCacheIfNeeded(modelContext: modelContext)
        
        var descriptor = FetchDescriptor<ConceptNode>(
            sortBy: [SortDescriptor(\.relevanceWeight, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        guard let nodes = try? modelContext.fetch(descriptor) else { return [] }
        
        // Recalculate relevance for top nodes
        for node in nodes {
            node.calculateRelevance()
        }
        
        // Save updates
        try? modelContext.save()
        
        return nodes
    }
    
    /// Get concepts for a specific time range
    func getConcepts(
        in dateRange: DateInterval,
        modelContext: ModelContext
    ) -> [ConceptNode] {
        let start = dateRange.start
        let end = dateRange.end
        
        let descriptor = FetchDescriptor<ConceptNode>(
            predicate: #Predicate { node in
                node.lastMentioned >= start && node.lastMentioned <= end
            },
            sortBy: [SortDescriptor(\.relevanceWeight, order: .reverse)]
        )
        
        guard let nodes = try? modelContext.fetch(descriptor) else { return [] }
        
        for node in nodes {
            node.calculateRelevance()
        }
        
        return nodes
    }
    
    /// Get concept summaries for AI payload
    func getConceptSummaries(limit: Int = 5, modelContext: ModelContext) -> [ConceptSummary] {
        let topNodes = getTopConcepts(limit: limit, modelContext: modelContext)
        return topNodes.map { ConceptSummary(from: $0) }
    }
    
    // MARK: - Cache Management
    
    private func refreshCacheIfNeeded(modelContext: ModelContext) {
        guard cache.isEmpty || (lastCacheRefresh == nil || Date().timeIntervalSince(lastCacheRefresh ?? .distantPast) > cacheValidity) else {
            return
        }
        
        let descriptor = FetchDescriptor<ConceptNode>()
        if let nodes = try? modelContext.fetch(descriptor) {
            cache = Dictionary(uniqueKeysWithValues: nodes.map { ($0.normalizedConcept, $0) })
            lastCacheRefresh = Date()
            let cacheCount = cache.count
            logger.debug("Concept cache refreshed: \(cacheCount) nodes loaded")
        }
    }
    
    /// Decay all concepts (should be called periodically, e.g., daily)
    func decayAllConcepts(modelContext: ModelContext) {
        guard config.featureFlags.narrativeEnabled else { return }
        
        let descriptor = FetchDescriptor<ConceptNode>()
        guard let nodes = try? modelContext.fetch(descriptor) else { return }
        
        for node in nodes {
            node.calculateRelevance()
        }
        
        do {
            try modelContext.save()
            logger.info("Decayed \(nodes.count) concept nodes")
        } catch {
            logger.error("Failed to decay concepts: \(error.localizedDescription)")
        }
    }
}

