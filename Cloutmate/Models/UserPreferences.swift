//
//  UserPreferences.swift
//  Cloutmate
//
//  Stores user-level AI and posting preferences
//

import Foundation
import SwiftData
import Combine

@Model
final class UserPreferences {
    var id: UUID = UUID()
    var preferredPostingHours: [Int] = [9, 12, 15] // 24h clock suggested hours
    var defaultPlatforms: [String] = [] // Platform.rawValue
    var defaultTone: String = "friendly"
    
    // Typing style preferences (learned from user conversations)
    var formalityScore: Double = 0.5
    var capitalizationPattern: String = "proper" // proper / lowercase / mixed
    var punctuationDensity: Double = 0.5
    var averageSentenceLength: Double = 12.0
    var emojiUsageFrequency: Double = 0.0
    var contractionUsageFrequency: Double = 0.3
    var exclamationFrequency: Double = 0.1
    var energyLevel: Double = 0.5
    var styleUpdateCount: Int = 0
    var lastUserEmotion: String? = nil
    var lastConversationTopic: String? = nil
    var lastEmotionalUpdate: Date? = nil
    var suggestedLinkingConcepts: [String] = []
    
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    init() {
        self.id = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}


