//
//  StoryArc.swift
//  FocusOS
//
//  Story Arc model for narrative timeline
//

import Foundation
import SwiftData

@Model
final class StoryArc {
    @Attribute(.unique) var id: UUID
    var label: String              // AI-generated arc name
    var startDate: Date
    var endDate: Date?
    var themes: [String] = []
    var momentum: Double = 0.0     // -1 to 1
    var isActive: Bool = true
    var createdAt: Date
    var updatedAt: Date
    
    init(
        label: String,
        startDate: Date,
        endDate: Date? = nil,
        themes: [String] = [],
        momentum: Double = 0.0
    ) {
        self.id = UUID()
        self.label = label
        self.startDate = startDate
        self.endDate = endDate
        self.themes = themes
        self.momentum = momentum
        self.isActive = true
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class StoryChapter {
    @Attribute(.unique) var id: UUID
    var arcId: UUID
    var label: String
    var startDate: Date
    var endDate: Date
    var createdAt: Date
    
    init(
        arcId: UUID,
        label: String,
        startDate: Date,
        endDate: Date
    ) {
        self.id = UUID()
        self.arcId = arcId
        self.label = label
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = Date()
    }
}

@Model
final class StoryScene {
    @Attribute(.unique) var id: UUID
    var chapterId: UUID
    var eventType: String           // "completion", "reflection", "milestone"
    var timestamp: Date
    var title: String
    var sceneDescription: String
    var linkedObjectId: UUID?
    var dialogue: String?           // From AIMessage
    var createdAt: Date
    
    init(
        chapterId: UUID,
        eventType: String,
        timestamp: Date,
        title: String,
        description: String,
        linkedObjectId: UUID? = nil,
        dialogue: String? = nil
    ) {
        self.id = UUID()
        self.chapterId = chapterId
        self.eventType = eventType
        self.timestamp = timestamp
        self.title = title
        self.sceneDescription = description
        self.linkedObjectId = linkedObjectId
        self.dialogue = dialogue
        self.createdAt = Date()
    }
}

