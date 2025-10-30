//
//  AIMessage.swift
//  Cloutmate
//
//  AI Chat Message Model
//

import Foundation
import SwiftData

@Model
final class AIMessage: Identifiable {
    @Attribute var id: UUID = UUID()
    @Attribute var role: String? = "user" // "user" or "assistant"
    @Attribute var content: String? = ""
    @Attribute var timestamp: Date? = Date()
    @Attribute var toolUsed: String?
    @Attribute var isSystemMessage: Bool = false
    
    // Inverse relationship
    var conversation: AIConversation?
    
    init(role: String, content: String, toolUsed: String? = nil, isSystemMessage: Bool = false) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.toolUsed = toolUsed
        self.isSystemMessage = isSystemMessage
    }
}

@Model
final class AIConversation: Identifiable {
    @Attribute var id: UUID = UUID()
    @Attribute var title: String? = ""
    @Attribute var createdAt: Date? = Date()
    @Attribute var isPinned: Bool = false
    @Attribute var pinnedAt: Date?
    @Attribute var summary: String?
    @Attribute var lastSummaryGeneratedAt: Date?
    @Attribute var tagsData: Data?
    
    // Make relationship optional for CloudKit compatibility
    @Relationship(deleteRule: .cascade, inverse: \AIMessage.conversation)
    var messages: [AIMessage]? = []
    
    init(title: String = "New Conversation") {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.isPinned = false
    }
    
    // Helper for tags storage (encoded as Data for SwiftData compatibility)
    var tags: [String] {
        get {
            guard let tagsData = tagsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: tagsData)) ?? []
        }
        set {
            tagsData = try? JSONEncoder().encode(newValue)
        }
    }
}
