//
//  ConversationArchive.swift
//  Cloutmate
//
//  Conversation Archive Service - Cross-Conversation Memory Management
//  Manages digestion and retrieval of past conversations
//

import Foundation
import SwiftData
import os.log

@MainActor
final class ConversationArchive {
    static let shared = ConversationArchive()
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "ConversationArchive")
    private init() {}
    
    // MARK: - Digest Generation
    
    /// Generate a digest for a conversation using AI
    func digestConversation(
        _ conversation: AIConversation,
        modelContext: ModelContext
    ) async throws -> ConversationDigest {
        guard let messages = conversation.messages, !messages.isEmpty else {
            throw ArchiveError.emptyConversation
        }
        
        // Check if digest already exists
        if let existing = getDigest(for: conversation.id, modelContext: modelContext) {
            return existing
        }
        
        // Gather conversation data
        let firstMessage = messages.first!
        let lastMessage = messages.last!
        let assistantMessages = messages.filter { $0.role == "assistant" }
        
        // Build conversation text for analysis
        let conversationText = messages.prefix(50).map { message in
            let role = message.role == "user" ? "User" : "Aurora"
            return "\(role): \(message.content ?? "")"
        }.joined(separator: "\n\n")
        
        // Generate AI summary
        let summary = try await generateSummary(conversationText: conversationText)
        
        // Analyze emotional tone
        let emotionalTones = messages.compactMap { $0.emotion }.filter { !$0.isEmpty }
        let dominantTone = Dictionary(grouping: emotionalTones, by: { $0 })
            .max(by: { $0.value.count < $1.value.count })?.key ?? "neutral"
        
        // Extract topics using ConceptTracker
        let topics = extractTopics(from: conversationText)
        
        // Create digest
        let digest = ConversationDigest(
            conversationId: conversation.id,
            title: conversation.title ?? "Untitled Conversation",
            startDate: firstMessage.timestamp ?? Date(),
            lastMessageDate: lastMessage.timestamp ?? Date()
        )
        
        digest.summary = summary
        digest.keyTopics = topics
        digest.emotionalTone = dominantTone
        digest.messageCount = messages.count
        digest.isDigested = true
        digest.searchableContent = conversationText
        
        // Extract action items, decisions, insights
        digest.actionItems = extractActionItems(from: assistantMessages)
        digest.decisions = extractDecisions(from: messages)
        digest.insights = extractInsights(from: assistantMessages)
        
        modelContext.insert(digest)
        
        do {
            try modelContext.save()
            logger.info("Digested conversation: \(conversation.title ?? "Untitled")")
        } catch {
            logger.error("Failed to save digest: \(error.localizedDescription)")
            throw ArchiveError.saveFailed
        }
        
        return digest
    }
    
    /// Generate AI summary of conversation
    private func generateSummary(conversationText: String) async throws -> String {
        let prompt = """
        Summarize this conversation between a user and Aurora (AI assistant) in 2-3 sentences. \
        Focus on the main topics discussed and any outcomes or decisions.
        
        Conversation:
        \(conversationText.prefix(2000))
        
        Provide ONLY the summary, no preamble.
        """
        
        do {
            let gemini = GeminiService.shared
            let summary = try await gemini.generateResponse(for: prompt)
            return summary.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            // Fallback: generate basic summary
            return "Conversation covering various topics and questions."
        }
    }
    
    /// Extract key topics from conversation
    private func extractTopics(from text: String) -> [String] {
        // Use simple keyword extraction for now
        // In future, could use ConceptTracker for more sophisticated extraction
        let words = text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 4 }
        
        let stopWords = Set(["aurora", "could", "would", "should", "there", "where", "which"])
        let filtered = words.filter { !stopWords.contains($0) }
        
        // Get most common words
        let wordCounts = Dictionary(grouping: filtered, by: { $0 })
            .mapValues { $0.count }
            .filter { $0.value >= 2 }
            .sorted { $0.value > $1.value }
        
        return Array(wordCounts.prefix(5).map { $0.key.capitalized })
    }
    
    /// Extract action items mentioned
    private func extractActionItems(from messages: [AIMessage]) -> [String] {
        var items: [String] = []
        for message in messages {
            guard let content = message.content else { continue }
            
            // Look for action-oriented phrases
            if content.contains("created") || content.contains("added") ||
               content.contains("scheduled") || content.contains("updated") {
                // Extract first sentence or two
                let sentences = content.components(separatedBy: ". ")
                items.append(contentsOf: sentences.prefix(2).map { $0.trimmingCharacters(in: .whitespaces) })
            }
        }
        return Array(items.prefix(5))
    }
    
    /// Extract decisions made
    private func extractDecisions(from messages: [AIMessage]) -> [String] {
        var decisions: [String] = []
        for message in messages {
            guard let content = message.content else { continue }
            
            // Look for decision-oriented phrases
            if content.lowercased().contains("decided") || content.lowercased().contains("let's") ||
               content.lowercased().contains("will") || content.lowercased().contains("plan to") {
                let sentences = content.components(separatedBy: ". ")
                decisions.append(contentsOf: sentences.prefix(1).map { $0.trimmingCharacters(in: .whitespaces) })
            }
        }
        return Array(decisions.prefix(3))
    }
    
    /// Extract key insights
    private func extractInsights(from messages: [AIMessage]) -> [String] {
        var insights: [String] = []
        for message in messages {
            guard let content = message.content else { continue }
            
            // Look for insight-oriented phrases
            if content.lowercased().contains("insight") || content.lowercased().contains("notice") ||
               content.lowercased().contains("pattern") || content.lowercased().contains("emerging") {
                let sentences = content.components(separatedBy: ". ")
                insights.append(contentsOf: sentences.prefix(1).map { $0.trimmingCharacters(in: .whitespaces) })
            }
        }
        return Array(insights.prefix(3))
    }
    
    // MARK: - Retrieval
    
    /// Get digest for a specific conversation
    func getDigest(for conversationId: UUID, modelContext: ModelContext) -> ConversationDigest? {
        let descriptor = FetchDescriptor<ConversationDigest>(
            predicate: #Predicate { $0.conversationId == conversationId }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    /// Get recent conversation digests (excluding current conversation)
    func getRecentDigests(
        excludingId: UUID? = nil,
        limit: Int = 5,
        modelContext: ModelContext
    ) -> [ConversationDigest] {
        var descriptor = FetchDescriptor<ConversationDigest>(
            predicate: excludingId != nil ? #Predicate { $0.conversationId != excludingId! } : nil,
            sortBy: [SortDescriptor(\.lastMessageDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    /// Search conversations by topic or keyword
    func searchConversations(
        query: String,
        limit: Int = 10,
        modelContext: ModelContext
    ) -> [ConversationDigest] {
        let normalizedQuery = query.lowercased()
        
        let descriptor = FetchDescriptor<ConversationDigest>(
            sortBy: [SortDescriptor(\.lastMessageDate, order: .reverse)]
        )
        
        guard let all = try? modelContext.fetch(descriptor) else { return [] }
        
        // Filter by title, summary, topics, or searchable content
        let matching = all.filter { digest in
            digest.title.lowercased().contains(normalizedQuery) ||
            digest.summary.lowercased().contains(normalizedQuery) ||
            digest.keyTopics.contains(where: { $0.lowercased().contains(normalizedQuery) }) ||
            digest.searchableContent.lowercased().contains(normalizedQuery)
        }
        
        return Array(matching.prefix(limit))
    }
    
    /// Get conversation summaries for AI context
    func getConversationSummariesForContext(
        excludingId: UUID? = nil,
        limit: Int = 3,
        modelContext: ModelContext
    ) -> [ConversationSummaryContext] {
        let digests = getRecentDigests(excludingId: excludingId, limit: limit, modelContext: modelContext)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        return digests.map { digest in
            ConversationSummaryContext(
                conversationId: digest.conversationId,
                title: digest.title,
                date: dateFormatter.string(from: digest.lastMessageDate),
                summary: digest.summary,
                keyTopics: digest.keyTopics,
                messageCount: digest.messageCount,
                emotionalTone: digest.emotionalTone
            )
        }
    }
    
    // MARK: - Batch Operations
    
    /// Digest all undigested conversations
    func digestAllConversations(modelContext: ModelContext) async {
        let conversationDescriptor = FetchDescriptor<AIConversation>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        guard let conversations = try? modelContext.fetch(conversationDescriptor) else { return }
        
        var digestedCount = 0
        for conversation in conversations {
            // Skip if already digested
            if getDigest(for: conversation.id, modelContext: modelContext) != nil {
                continue
            }
            
            // Skip if no messages
            guard let messages = conversation.messages, !messages.isEmpty else { continue }
            
            do {
                _ = try await digestConversation(conversation, modelContext: modelContext)
                digestedCount += 1
            } catch {
                logger.warning("Failed to digest conversation \(conversation.id.uuidString): \(error.localizedDescription)")
            }
        }
        
        logger.info("Digested \(digestedCount) conversations")
    }
}

// MARK: - Errors

enum ArchiveError: LocalizedError {
    case emptyConversation
    case saveFailed
    case digestFailed
    
    var errorDescription: String? {
        switch self {
        case .emptyConversation:
            return "Cannot digest empty conversation"
        case .saveFailed:
            return "Failed to save conversation digest"
        case .digestFailed:
            return "Failed to generate conversation summary"
        }
    }
}

