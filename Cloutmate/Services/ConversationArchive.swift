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
import CloutmateShared

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
        let cappedLimit = min(max(limit, 1), 5)
        let digests = getRecentDigests(excludingId: excludingId, limit: cappedLimit, modelContext: modelContext)
        
        guard !digests.isEmpty else { return [] }
        
        let toneCounts = Dictionary(grouping: digests, by: { $0.emotionalTone.lowercased() }).mapValues { $0.count }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        return digests.enumerated().map { index, digest in
            let baseWeight: Double
            switch index {
            case 0: baseWeight = 1.0
            case 1: baseWeight = 0.8
            case 2: baseWeight = 0.6
            case 3: baseWeight = 0.45
            default: baseWeight = 0.3
            }
            let toneKey = digest.emotionalTone.lowercased()
            let reinforced = (toneCounts[toneKey] ?? 0) >= 3
            let weight = reinforced ? max(baseWeight, 0.9) : baseWeight
            return ConversationSummaryContext(
                conversationId: digest.conversationId,
                title: digest.title,
                date: dateFormatter.string(from: digest.lastMessageDate),
                summary: digest.summary,
                keyTopics: digest.keyTopics,
                messageCount: digest.messageCount,
                emotionalTone: digest.emotionalTone,
                emotionWeight: min(max(weight, 0.0), 1.0)
            )
        }
    }
    
    /// Extract intent clusters from recent conversations (e.g., empathy vs orchestration topics)
    func extractIntentClusters(
        excludingId: UUID? = nil,
        limit: Int = 10,
        modelContext: ModelContext
    ) async -> IntentClusterSummary? {
        var digests = getRecentDigests(excludingId: excludingId, limit: limit, modelContext: modelContext)
        
        guard !digests.isEmpty else { return nil }
        
        // Apply exponential decay weighting (λ=0.65) for recency bias mitigation
        let now = Date()
        let decayLambda: Double = 0.65
        digests.sort { digest1, digest2 in
            let days1 = Calendar.current.dateComponents([.day], from: digest1.lastMessageDate, to: now).day ?? 0
            let days2 = Calendar.current.dateComponents([.day], from: digest2.lastMessageDate, to: now).day ?? 0
            let weight1 = pow(decayLambda, Double(days1))
            let weight2 = pow(decayLambda, Double(days2))
            return weight1 > weight2  // Most recent (highest weight) first
        }
        
        // Calculate history signal strength
        let totalDays = digests.count > 0 ? Calendar.current.dateComponents([.day], from: digests.last!.lastMessageDate, to: digests.first!.lastMessageDate).day ?? 0 : 0
        let historyLengthScore = min(1.0, Double(digests.count) / 7.0)  // Normalize to 1.0 for 7+ conversations
        
        // Build conversation text with recency weights
        var conversationTexts: [String] = []
        for (idx, digest) in digests.enumerated() {
            let daysAgo = Calendar.current.dateComponents([.day], from: digest.lastMessageDate, to: now).day ?? 0
            let recencyWeight = pow(decayLambda, Double(daysAgo))
            let recencyLabel = daysAgo == 0 ? "today" : daysAgo == 1 ? "yesterday" : "\(daysAgo) days ago"
            let text = "- Conversation \(idx + 1) [\(recencyLabel), weight: \(String(format: "%.2f", recencyWeight))]: \(digest.title)\n  Summary: \(digest.summary)\n  Topics: \(digest.keyTopics.joined(separator: ", "))\n  Tone: \(digest.emotionalTone)"
            conversationTexts.append(text)
        }
        
        // Use AI to categorize into intent clusters with weighted emphasis
        let clusterPrompt = """
        Analyze these recent conversation topics, summaries, and emotional tones to identify intent clusters.
        Note: Conversations are sorted by recency (most recent first). Give more weight to recent conversations based on their recency weight.
        
        Conversations (\(digests.count) total, spanning \(totalDays) days):
        \(conversationTexts.joined(separator: "\n\n"))
        
        Categorize these conversations into intent clusters. Common clusters include:
        - **Empathy/Support**: Conversations focused on emotional support, feelings, personal challenges, relationships
        - **Orchestration/Planning**: Conversations about workflow, systems, organization, structure, efficiency
        - **Creative/Brainstorming**: Conversations about ideas, content creation, innovation, exploration
        - **Execution/Action**: Conversations about doing tasks, completing work, productivity
        - **Reflection/Learning**: Conversations about understanding patterns, growth, insights
        
        Calculate cluster dominance: primary cluster should be significantly more prominent (e.g., 40%+ of conversations). If clusters are tied (<10% difference), note it.
        
        Return ONLY a JSON object with this structure:
        {
          "clusters": [
            {
              "name": "cluster name",
              "topics": ["topic1", "topic2"],
              "conversationCount": 3,
              "dominantEmotions": ["emotion1"],
              "description": "brief description of this cluster",
              "dominance": 0.65
            }
          ],
          "primaryCluster": "most prominent cluster name",
          "secondaryCluster": "second most prominent cluster name",
          "clusterDominanceScore": 0.8,
          "isTied": false,
          "disambiguatingQuestions": ["What would help clarify?", "Question 2"]
        }
        
        - clusterDominanceScore: How much more dominant is the primary cluster vs secondary (0-1, where 1 = very dominant, 0.5 = tied)
        - isTied: true if primary and secondary clusters are within 10% of each other
        - disambiguatingQuestions: 2-3 questions that would help clarify which cluster the user will focus on next (only include if confidence would be low)
        
        JSON only, no markdown:
        """
        
        do {
            let gemini = GeminiService.shared
            let response = try await gemini.generateResponse(for: clusterPrompt)
            
            // Parse JSON response
            let cleaned = response
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard let data = cleaned.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let clustersArray = json["clusters"] as? [[String: Any]] else {
                return nil
            }
            
            let clusters = clustersArray.compactMap { dict -> IntentCluster? in
                guard let name = dict["name"] as? String,
                      let topics = dict["topics"] as? [String],
                      let count = dict["conversationCount"] as? Int,
                      let emotions = dict["dominantEmotions"] as? [String],
                      let description = dict["description"] as? String else {
                    return nil
                }
                return IntentCluster(
                    name: name,
                    topics: topics,
                    conversationCount: count,
                    dominantEmotions: emotions,
                    description: description
                )
            }
            
            let primaryCluster = json["primaryCluster"] as? String
            let secondaryCluster = json["secondaryCluster"] as? String
            let dominanceScore = (json["clusterDominanceScore"] as? Double) ?? 0.5
            let isTied = (json["isTied"] as? Bool) ?? false
            let disambiguatingQuestions = json["disambiguatingQuestions"] as? [String]
            
            guard !clusters.isEmpty else { return nil }
            
            // Calculate confidence score: dominance * history length
            // Confidence = (cluster dominance) * (history length score) * (1.0 if not tied, 0.7 if tied)
            let tiePenalty: Double = isTied ? 0.7 : 1.0
            let confidence = dominanceScore * historyLengthScore * tiePenalty
            
            // Extract tie-breaker info from CPS or action verbs if needed
            var tieBreaker: String? = nil
            if isTied || confidence < 0.4 {
                // Use CPS priorities as tie-breaker
                let topPriorities = PriorityEngine.shared.getTopObjects(limit: 3, modelContext: modelContext)
                if let topPriority = topPriorities.first {
                    tieBreaker = "CPS Priority: \(topPriority.title)"
                } else {
                    // Extract action verbs from recent conversation summaries
                    let actionVerbs = extractActionVerbs(from: digests)
                    if let mostCommonVerb = actionVerbs.first {
                        tieBreaker = "Recent Action Pattern: \(mostCommonVerb.key)"
                    }
                }
            }
            
            let shouldAbstain = confidence < 0.4
            
            return IntentClusterSummary(
                clusters: clusters,
                primaryCluster: primaryCluster,
                secondaryCluster: secondaryCluster,
                confidence: confidence,
                shouldAbstain: shouldAbstain,
                disambiguatingQuestions: shouldAbstain ? (disambiguatingQuestions ?? []) : nil,
                tieBreaker: tieBreaker
            )
        } catch {
            logger.warning("Failed to extract intent clusters: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Extract most common action verbs from conversation summaries
    private func extractActionVerbs(from digests: [ConversationDigest]) -> [(key: String, count: Int)] {
        let actionVerbs = Set(["create", "build", "plan", "organize", "schedule", "write", "edit", "publish", "analyze", "review", "complete", "finish", "start", "work", "focus", "prioritize"])
        
        var verbCounts: [String: Int] = [:]
        for digest in digests {
            let text = (digest.summary + " " + digest.keyTopics.joined(separator: " ")).lowercased()
            let words = text.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
            
            for word in words {
                if actionVerbs.contains(word) {
                    verbCounts[word, default: 0] += 1
                }
            }
        }
        
        return verbCounts.sorted { $0.value > $1.value }.map { (key: $0.key, count: $0.value) }
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

