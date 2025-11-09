//
//  MemoryWeavingService.swift
//  Cloutmate
//
//  Memory Weaving - Connects present work to past insights
//

import Foundation
import SwiftData
import os.log

@MainActor
final class MemoryWeavingService {
    static let shared = MemoryWeavingService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "MemoryWeaving")
    
    private init() {}
    
    /// Find repeated motifs and connections to past insights
    func findConnections(
        currentText: String,
        currentContext: String? = nil,
        modelContext: ModelContext
    ) async -> [MemoryConnection] {
        var connections: [MemoryConnection] = []
        
        // 1. Find repeated motifs using ConceptTracker
        let motifs = findRepeatedMotifs(in: currentText, modelContext: modelContext)
        connections.append(contentsOf: motifs)
        
        // 2. Find semantic connections using MemoryGraphService
        if AIConfigService.shared.config.featureFlags.memoryGraphEnabled {
            let semanticConnections = await findSemanticConnections(
                text: currentText,
                modelContext: modelContext
            )
            connections.append(contentsOf: semanticConnections)
        }
        
        // 3. Find quotes from past reflections/notes
        let quotes = findRelevantQuotes(for: currentText, modelContext: modelContext)
        connections.append(contentsOf: quotes)
        
        return connections.sorted { $0.relevanceScore > $1.relevanceScore }
    }
    
    /// Generate contextual callback message
    func generateCallbackMessage(
        connection: MemoryConnection,
        modelContext: ModelContext
    ) -> String {
        switch connection.type {
        case .motif:
            return "You mentioned '\(connection.motif ?? "")' before. Want to see related insights?"
        case .semantic:
            return "This connects to your past work on '\(connection.title)'. Want to review it?"
        case .quote:
            if let quote = connection.quote {
                return "You said something similar in your \(connection.dateString): \"\(quote)\""
            }
            return "You explored this topic before. Want to see what you learned?"
        }
    }
    
    // MARK: - Private Methods
    
    private func findRepeatedMotifs(
        in text: String,
        modelContext: ModelContext
    ) -> [MemoryConnection] {
        let commonMotifs = ["balance", "launch", "clarity", "focus", "momentum", "growth", "consistency"]
        var connections: [MemoryConnection] = []
        
        let lowerText = text.lowercased()
        for motif in commonMotifs {
            if lowerText.contains(motif) {
                // Find past mentions of this motif
                let concepts = ConceptTracker.shared.getConcepts(
                    in: DateInterval(start: Date().addingTimeInterval(-90 * 24 * 3600), end: Date()),
                    modelContext: modelContext
                )
                
                let matchingConcepts = concepts.filter { concept in
                    concept.concept.lowercased().contains(motif)
                }
                
                if !matchingConcepts.isEmpty {
                    let mostRelevant = matchingConcepts.max { $0.relevanceWeight < $1.relevanceWeight }
                    if let concept = mostRelevant {
                        connections.append(MemoryConnection(
                            type: .motif,
                            title: concept.concept,
                            relevanceScore: concept.relevanceWeight,
                            motif: motif,
                            dateString: formatDate(concept.firstMentioned),
                            quote: nil
                        ))
                    }
                }
            }
        }
        
        return connections
    }
    
    private func findSemanticConnections(
        text: String,
        modelContext: ModelContext
    ) async -> [MemoryConnection] {
        guard let memoryGraphService = try? MemoryGraphService.shared else {
            return []
        }
        
        // Create temporary node for current text
        do {
            let tempNode = try await memoryGraphService.createConceptNode(
                concept: "current_context",
                content: text,
                modelContext: modelContext
            )
            
            // Find similar nodes
            let similarNodes = memoryGraphService.findSimilarNodes(
                to: tempNode.id,
                threshold: 0.7,
                limit: 5,
                modelContext: modelContext
            )
            
            return similarNodes.map { node in
                MemoryConnection(
                    type: .semantic,
                    title: node.label,
                    relevanceScore: node.importance,
                    motif: nil,
                    dateString: formatDate(node.createdAt),
                    quote: node.content
                )
            }
        } catch {
            logger.error("Failed to find semantic connections: \(error.localizedDescription)")
            return []
        }
    }
    
    private func findRelevantQuotes(
        for text: String,
        modelContext: ModelContext
    ) -> [MemoryConnection] {
        var connections: [MemoryConnection] = []
        
        // Search in Journal entries
        var journalDescriptor = FetchDescriptor<Journal>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        journalDescriptor.fetchLimit = 50
        
        if let journals = try? modelContext.fetch(journalDescriptor) {
            let keywords = extractKeywords(from: text)
            
            for journal in journals {
                if matchesKeywords(journal.content, keywords: keywords) {
                    let quote = extractRelevantQuote(from: journal.content, keywords: keywords)
                    connections.append(MemoryConnection(
                        type: .quote,
                        title: "Journal Entry",
                        relevanceScore: calculateRelevance(content: journal.content, keywords: keywords),
                        motif: nil,
                        dateString: formatDate(journal.createdAt),
                        quote: quote
                    ))
                }
            }
        }
        
        // Search in StoryTokens
        var tokenDescriptor = FetchDescriptor<StoryToken>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        tokenDescriptor.fetchLimit = 20
        
        if let tokens = try? modelContext.fetch(tokenDescriptor) {
            let keywords = extractKeywords(from: text)
            
            for token in tokens {
                if matchesKeywords(token.markdown, keywords: keywords) {
                    let quote = extractRelevantQuote(from: token.summary, keywords: keywords)
                    connections.append(MemoryConnection(
                        type: .quote,
                        title: token.title,
                        relevanceScore: calculateRelevance(content: token.markdown, keywords: keywords),
                        motif: nil,
                        dateString: formatDate(token.createdAt),
                        quote: quote
                    ))
                }
            }
        }
        
        return connections
    }
    
    private func extractKeywords(from text: String) -> [String] {
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 }
        
        // Remove common stop words
        let stopWords = Set(["this", "that", "with", "from", "have", "been", "will", "would", "could", "should"])
        return Array(Set(words.filter { !stopWords.contains($0) }).prefix(5))
    }
    
    private func matchesKeywords(_ text: String, keywords: [String]) -> Bool {
        let lowerText = text.lowercased()
        return keywords.contains { lowerText.contains($0) }
    }
    
    private func extractRelevantQuote(from text: String, keywords: [String]) -> String {
        let sentences = text.components(separatedBy: ". ")
        for sentence in sentences {
            if matchesKeywords(sentence, keywords: keywords) {
                return String(sentence.prefix(150)) + (sentence.count > 150 ? "..." : "")
            }
        }
        return String(text.prefix(150)) + (text.count > 150 ? "..." : "")
    }
    
    private func calculateRelevance(content: String, keywords: [String]) -> Double {
        let lowerContent = content.lowercased()
        let matches = keywords.filter { lowerContent.contains($0) }.count
        return Double(matches) / Double(keywords.count)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Types

enum MemoryConnectionType {
    case motif      // Repeated theme/motif
    case semantic   // Semantic similarity
    case quote      // Direct quote from past
}

struct MemoryConnection {
    let type: MemoryConnectionType
    let title: String
    let relevanceScore: Double
    let motif: String?
    let dateString: String
    let quote: String?
}

