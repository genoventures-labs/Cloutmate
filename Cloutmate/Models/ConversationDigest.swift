//
//  ConversationDigest.swift
//  Cloutmate
//
//  Conversation Digest System - Cross-Conversation Memory
//  Allows Aurora to reference and access past conversations
//

import Foundation
import SwiftData

/// A digest/summary of a past conversation for cross-conversation reference
@Model
final class ConversationDigest {
    @Attribute(.unique) var conversationId: UUID
    var title: String
    var summary: String                     // AI-generated summary of conversation
    var keyTopics: [String] = []           // Main topics discussed
    var emotionalTone: String              // Overall emotional tone
    var messageCount: Int = 0
    var startDate: Date
    var lastMessageDate: Date
    var isDigested: Bool = false           // Has AI generated summary?
    
    // Quick references
    var actionItems: [String] = []         // Tasks/actions mentioned
    var decisions: [String] = []           // Decisions made
    var insights: [String] = []            // Key insights surfaced
    
    // Searchability
    var searchableContent: String = ""     // Full text for searching
    
    init(conversationId: UUID, title: String, startDate: Date, lastMessageDate: Date) {
        self.conversationId = conversationId
        self.title = title
        self.summary = ""
        self.keyTopics = []
        self.emotionalTone = "neutral"
        self.messageCount = 0
        self.startDate = startDate
        self.lastMessageDate = lastMessageDate
        self.actionItems = []
        self.decisions = []
        self.insights = []
    }
    
    /// Brief display string for lists
    var displaySummary: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        return "\(title) - \(dateFormatter.string(from: startDate)) (\(messageCount) messages)"
    }
}

/// Lightweight conversation summary for AI context
struct ConversationSummaryContext: Sendable {
    let conversationId: UUID
    let title: String
    let date: String
    let summary: String
    let keyTopics: [String]
    let messageCount: Int
    let emotionalTone: String
    let emotionWeight: Double
}

/// Intent cluster extracted from conversation patterns
struct IntentCluster: Sendable, Identifiable {
    let id = UUID()
    let name: String
    let topics: [String]
    let conversationCount: Int
    let dominantEmotions: [String]
    let description: String
}

/// Summary of intent clusters from recent conversations
struct IntentClusterSummary: Sendable {
    let clusters: [IntentCluster]
    let primaryCluster: String?
    let secondaryCluster: String?
    let confidence: Double  // 0.0 to 1.0
    let shouldAbstain: Bool  // True if confidence < 0.4
    let disambiguatingQuestions: [String]?  // Questions to ask when abstaining
    let tieBreaker: String?  // CPS priority or action verb used for tie-breaking
}

