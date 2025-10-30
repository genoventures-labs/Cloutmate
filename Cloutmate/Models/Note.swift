//
//  Note.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData

enum ResourceType: String, Codable, CaseIterable {
    case note = "Note"
    case article = "Article"
    case video = "Video"
    case book = "Book"
    case podcast = "Podcast"
    case link = "Link"
    case idea = "Idea"
    case reference = "Reference"
}

@Model
final class Note {
    var id: UUID = UUID()
    var title: String = ""
    var markdown: String = ""
    var tags: [String] = []
    var projectId: UUID?
    var areaId: UUID?
    var backlinks: [UUID] = [] // IDs of other notes/projects
    var highlights: [String] = [] // Array of highlighted text snippets (3.0b feature)
    var source: String? // URL or reference
    var type: ResourceType = ResourceType.note
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isArchived: Bool = false
    
    init(
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
        self.backlinks = []
        self.highlights = []
    }
}

