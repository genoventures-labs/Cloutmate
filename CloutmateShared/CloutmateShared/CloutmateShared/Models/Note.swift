//
//  Note.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData

public enum ResourceType: String, Codable, CaseIterable {
    case note = "Note"
    case article = "Article"
    case video = "Video"
    case book = "Book"
    case podcast = "Podcast"
    case link = "Link"
    case idea = "Idea"
    case reference = "Reference"
}

public enum NoteAuthor: String, Codable, CaseIterable {
    case user
    case aurora
    case unknown
}

@Model
public final class Note {
    public var id: UUID = UUID()
    public var title: String = ""
    public var markdown: String = ""
    public var tags: [String] = []
    public var projectId: UUID?
    public var areaId: UUID?
    public var backlinks: [UUID] = [] // IDs of other notes/projects
    public var highlights: [String] = [] // Array of highlighted text snippets (3.0b feature)
    public var source: String? // URL or reference
    public var type: ResourceType = ResourceType.note
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var archivedAt: Date?
    public var isArchived: Bool = false
    public var isPinned: Bool = false
    public var pinnedAt: Date?
    public var authorRaw: String = NoteAuthor.user.rawValue
    
    public init(
        title: String,
        markdown: String = "",
        tags: [String] = [],
        projectId: UUID? = nil,
        areaId: UUID? = nil,
        source: String? = nil,
        type: ResourceType = ResourceType.note
    ) {
        self.id = UUID()
        self.title = title
        self.markdown = markdown
        self.tags = tags
        self.projectId = projectId
        self.areaId = areaId
        self.source = source
        self.type = type
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isArchived = false
        self.isPinned = false
        self.pinnedAt = nil
        self.authorRaw = NoteAuthor.user.rawValue
        self.backlinks = []
        self.highlights = []
    }

    public var author: NoteAuthor {
        get { NoteAuthor(rawValue: authorRaw) ?? .user }
        set { authorRaw = newValue.rawValue }
    }
}

