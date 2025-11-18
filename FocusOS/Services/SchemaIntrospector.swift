//
//  SchemaIntrospector.swift
//  FocusOS
//
//  Produces a concise schema document for AI prompts
//

import Foundation

nonisolated enum SchemaIntrospector {
    static func generateSchemaDocument() -> String {
        var doc = "# FocusOS Data Schema (Concise)\n\n"
        doc += section("Task", fields: [
            "id: UUID",
            "title: String",
            "notes: String?",
            "status: enum TaskStatus { todo, inProgress, done, cancelled }",
            "priority: enum TaskPriority { low, medium, high }",
            "dueDate: Date?",
            "projectId: UUID?",
            "areaId: UUID?",
            "dependsOnIds: [UUID]",
            "effort: String? (small|medium|large)",
            "createdAt: Date",
            "updatedAt: Date",
            "completedAt: Date?"
        ])
        doc += section("Project", fields: [
            "id: UUID",
            "title: String",
            "goal: String?",
            "status: enum ProjectStatus { active, paused, completed }",
            "dueDate: Date?",
            "areaId: UUID?",
            "tags: [String]",
            "taskIds: [UUID]",
            "noteIds: [UUID]",
            "postIds: [UUID]",
            "createdAt: Date",
            "updatedAt: Date"
        ])
        doc += section("Post", fields: [
            "id: UUID",
            "caption: String",
            "mediaURLs: [String]",
            "scheduledDate: Date?",
            "publishedDate: Date?",
            "status: String (PostStatus)",
            "tags: [String]",
            "engagementRate: Double?",
            "impressions: Int?",
            "likes: Int?",
            "comments: Int?",
            "saves: Int?",
            "reach: Int?",
            "retryCount: Int",
            "lastError: String?",
            "projectId: UUID?",
            "areaId: UUID?",
            "createdAt: Date",
            "updatedAt: Date"
        ])
        doc += section("Draft", fields: [
            "id: UUID",
            "title: String",
            "caption: String",
            "mediaURLs: [String]",
            "tags: [String]",
            "updatedAt: Date",
            "createdAt: Date"
        ])
        doc += section("Template", fields: [
            "id: UUID",
            "title: String",
            "body: String",
            "tags: [String]",
            "createdAt: Date",
            "updatedAt: Date"
        ])
        doc += section("Note", fields: [
            "id: UUID",
            "title: String",
            "markdown: String",
            "tags: [String]",
            "projectId: UUID?",
            "areaId: UUID?",
            "backlinks: [UUID]",
            "highlights: [String]",
            "source: String?",
            "type: enum ResourceType { note, article, video, book, podcast, link, idea, reference }",
            "authorRaw: String (NoteAuthor)",
            "createdAt: Date",
            "updatedAt: Date",
            "isArchived: Bool"
        ])
        doc += section("Journal", fields: [
            "id: UUID",
            "title: String",
            "content: String",
            "entryDate: Date",
            "entryType: String (JournalEntryType)",
            "mood: String (JournalMood)",
            "tags: [String]",
            "projectId: UUID?",
            "areaId: UUID?",
            "linkedNoteIds: [UUID]",
            "linkedAreaIds: [UUID]",
            "linkedProjectIds: [UUID]",
            "aiPrompt: String?",
            "aiGeneratedContent: String?",
            "authorRaw: String (JournalAuthor)",
            "createdAt: Date",
            "updatedAt: Date",
            "isArchived: Bool"
        ])
        doc += section("InboxItem", fields: [
            "id: UUID",
            "content: String",
            "itemType: String (text|image|file|url)",
            "fileURL: String?",
            "createdAt: Date",
            "convertedToType: String? (task|note|post|project)",
            "convertedToId: UUID?",
            "convertedAt: Date?"
        ])
        doc += section("InsightSnapshot", fields: [
            "id: UUID",
            "createdAt: Date",
            "metrics: {...} (aggregated engagement)"
        ])
        doc += section("Area", fields: [
            "id: UUID",
            "title: String",
            "notes: String?"
        ])
        doc += section("PARATemplate", fields: [
            "id: UUID",
            "title: String",
            "sections: [String]"
        ])
        return doc
    }

    private static func section(_ name: String, fields: [String]) -> String {
        var s = "## \(name)\n"
        for f in fields { s += "- \(f)\n" }
        s += "\n"
        return s
    }
}


