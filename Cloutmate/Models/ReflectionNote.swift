//
//  ReflectionNote.swift
//  Cloutmate
//
//  Phase 10: AI Flow Companion & Meta-Reflection
//  Stores every reflection or Aurora-prompt exchange
//

import Foundation
import SwiftData

@Model
final class ReflectionNote {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var prompt: String
    var response: String
    var emotionTone: String              // ARTE emotional tag
    var contextTag: String               // "Drift", "Ritual", "Idle", etc.
    var length: Int                      // Character count
    var insightWeight: Double            // How much CPS should weigh it (0-1)
    var keywords: [String] = []
    var sentimentScore: Double           // -1 to 1
    var summary: String?                 // Short AI-generated recap
    var createdAt: Date
    
    init(
        prompt: String,
        response: String,
        emotionTone: String,
        contextTag: String,
        insightWeight: Double = 0.5,
        keywords: [String] = [],
        sentimentScore: Double = 0.0,
        summary: String? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.prompt = prompt
        self.response = response
        self.emotionTone = emotionTone
        self.contextTag = contextTag
        self.length = response.count
        self.insightWeight = insightWeight
        self.keywords = keywords
        self.sentimentScore = sentimentScore
        self.summary = summary
        self.createdAt = Date()
    }
}

enum ReflectionTriggerType: String, Codable {
    case drift
    case evening
    case idle
    case manual
}

