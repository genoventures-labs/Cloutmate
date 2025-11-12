//
//  Journal.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData

enum JournalEntryType: String, Codable, CaseIterable {
    case reflection = "Personal Reflection"
    case contentIdea = "Content Idea"
    case projectTracker = "Project Tracker"
    
    var icon: String {
        switch self {
        case .reflection: return "heart.fill"
        case .contentIdea: return "lightbulb.fill"
        case .projectTracker: return "chart.bar.doc.horizontal.fill"
        }
    }
}

enum JournalMood: String, Codable, CaseIterable {
    case excited = "Excited"
    case grateful = "Grateful"
    case reflective = "Reflective"
    case motivated = "Motivated"
    case contemplative = "Contemplative"
    case creative = "Creative"
    case frustrated = "Frustrated"
    case calm = "Calm"
    case none = "None"
    
    var color: String {
        switch self {
        case .excited: return "orange"
        case .grateful: return "yellow"
        case .reflective: return "blue"
        case .motivated: return "green"
        case .contemplative: return "purple"
        case .creative: return "pink"
        case .frustrated: return "red"
        case .calm: return "cyan"
        case .none: return "gray"
        }
    }
}

enum JournalAuthor: String, Codable, CaseIterable {
    case user
    case aurora
    case unknown
}

@Model
final class Journal {
    var id: UUID = UUID()
    var title: String = ""
    var content: String = ""
    var entryDate: Date = Date()
    var entryType: String = JournalEntryType.reflection.rawValue
    var mood: String = JournalMood.none.rawValue
    var tags: [String] = []
    
    // Linking system
    var projectId: UUID?
    var areaId: UUID?
    var linkedNoteIds: [UUID] = []
    var linkedAreaIds: [UUID] = []
    var linkedProjectIds: [UUID] = []
    
    // Mention linking
    var linkedEntityIds: [UUID] = [] // IDs of mentioned items
    var linkedEntityTypes: [String] = [] // Types of mentioned items
    
    // AI-related fields
    var aiPrompt: String?
    var aiGeneratedContent: String?
    var auroraNotes: String?
    var authorRaw: String = JournalAuthor.user.rawValue
    
    // Metadata
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isArchived: Bool = false
    
    init(
        title: String,
        content: String = "",
        entryDate: Date = Date(),
        entryType: JournalEntryType = .reflection,
        mood: JournalMood = .none,
        tags: [String] = [],
        projectId: UUID? = nil,
        areaId: UUID? = nil,
        linkedNoteIds: [UUID] = [],
        linkedAreaIds: [UUID] = [],
        linkedProjectIds: [UUID] = []
    ) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.entryDate = entryDate
        self.entryType = entryType.rawValue
        self.mood = mood.rawValue
        self.tags = tags
        self.projectId = projectId
        self.areaId = areaId
        self.linkedNoteIds = linkedNoteIds
        self.linkedAreaIds = linkedAreaIds
        self.linkedProjectIds = linkedProjectIds
        self.linkedEntityIds = []
        self.linkedEntityTypes = []
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isArchived = false
        self.authorRaw = JournalAuthor.user.rawValue
    }
    
    // Computed properties for type safety
    var journalEntryType: JournalEntryType {
        get { JournalEntryType(rawValue: entryType) ?? .reflection }
        set { entryType = newValue.rawValue }
    }
    
    var journalMood: JournalMood {
        get { JournalMood(rawValue: mood) ?? .none }
        set { mood = newValue.rawValue }
    }
    
    var author: JournalAuthor {
        get { JournalAuthor(rawValue: authorRaw) ?? .user }
        set { authorRaw = newValue.rawValue }
    }
}

