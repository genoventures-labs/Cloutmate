//
//  NotionConverter.swift
//  FocusOS
//
//  Converts NotionSwift models to FocusOS models
//

import Foundation
import FocusOSShared
import NotionSwift

enum NotionPageType: CustomStringConvertible {
    case task
    case project
    case note
    case area
    case unknown
    
    var description: String {
        switch self {
        case .task:
            return "task"
        case .project:
            return "project"
        case .note:
            return "note"
        case .area:
            return "area"
        case .unknown:
            return "unknown"
        }
    }
}

struct NotionConverter {
    
    /// Determine the FocusOS type for a Notion page based on its properties
    static func determinePageType(_ notionPage: Page, database: Database?) -> NotionPageType {
        let properties = notionPage.properties
        
        // Check for task-like properties: status, due date, priority, completion checkbox
        var hasStatus = false
        var hasDueDate = false
        var hasPriority = false
        var hasCheckbox = false
        var hasTaskKeywords = false
        
        // Check property names for task-specific keywords
        for (key, property) in properties {
            let lowerKey = key.lowercased()
            
            // Check for task-specific property names
            if lowerKey.contains("task") || lowerKey.contains("todo") || lowerKey.contains("action") || lowerKey.contains("item") {
                hasTaskKeywords = true
            }
            
            // Check for status property (must be named "status" or similar)
            if lowerKey.contains("status") {
                if case .status = property.type {
                    hasStatus = true
                } else if case .select = property.type {
                    hasStatus = true
                }
            }
            
            // Check for priority property (must be named "priority" or similar)
            if lowerKey.contains("priority") || lowerKey.contains("urgent") {
                if case .select(let select) = property.type {
                    hasPriority = true
                }
            }
            
            // Check for due date property (must be named "due" or "due date", not just any date)
            if lowerKey.contains("due") && !lowerKey.contains("created") && !lowerKey.contains("updated") && !lowerKey.contains("last edited") {
                if case .date = property.type {
                    hasDueDate = true
                }
            }
            
            // Check for checkbox/boolean completion field
            if case .checkbox = property.type {
                if lowerKey.contains("done") || lowerKey.contains("complete") || lowerKey.contains("finished") || lowerKey.contains("checked") {
                    hasCheckbox = true
                }
            }
        }
        
        // STRICT task detection: Must have clear task indicators
        // Option 1: Has status AND due date (classic task)
        if hasStatus && hasDueDate {
            return .task
        }
        
        // Option 2: Has checkbox completion field AND (status OR due date)
        if hasCheckbox && (hasStatus || hasDueDate) {
            return .task
        }
        
        // Option 3: Has task keywords AND status AND (priority OR due date)
        if hasTaskKeywords && hasStatus && (hasPriority || hasDueDate) {
            return .task
        }
        
        // Option 4: Has status AND priority AND task keywords
        if hasStatus && hasPriority && hasTaskKeywords {
            return .task
        }
        
        // Check for project-like properties: goal, status, due date
        var hasGoal = false
        for (key, property) in properties {
            let lowerKey = key.lowercased()
            if lowerKey.contains("goal") || lowerKey.contains("objective") || lowerKey.contains("purpose") {
                if case .title = property.type {
                    hasGoal = true
                } else if case .richText = property.type {
                    hasGoal = true
                }
            }
        }
        
        // Project detection: Has goal AND status AND due date
        if hasGoal && hasStatus && hasDueDate {
            return .project
        }
        
        // Default to Note if no specific type detected
        return .note
    }
    
    /// Convert a Notion page to a Task
    static func convertToTask(_ notionPage: Page) -> FocusOSShared.Task {
        let task = FocusOSShared.Task(
            title: extractTitle(notionPage) ?? "Untitled Task",
            notes: extractNotes(notionPage),
            status: convertStatus(extractStatus(notionPage)) ?? .todo,
            priority: convertPriority(extractPriority(notionPage)) ?? .medium,
            dueDate: extractDueDate(notionPage)
        )
        
        // Set external tracking fields
        task.externalReminderId = notionPage.id.rawValue
        task.externalSource = "notion"
        task.lastSyncedAt = Date()
        
        return task
    }
    
    /// Convert a Notion page to a Project
    static func convertToProject(_ notionPage: Page) -> FocusOSShared.Project {
        let project = FocusOSShared.Project(
            title: extractTitle(notionPage) ?? "Untitled Project",
            goal: extractGoal(notionPage),
            status: convertProjectStatus(extractStatus(notionPage)) ?? .active,
            dueDate: extractDueDate(notionPage)
        )
        
        // Set external tracking fields
        project.externalProjectId = notionPage.id.rawValue
        project.externalSource = "notion"
        project.lastSyncedAt = Date()
        
        return project
    }
    
    /// Convert a Notion page to a Note
    static func convertToNote(_ notionPage: Page) -> FocusOSShared.Note {
        let note = FocusOSShared.Note(
            title: extractTitle(notionPage) ?? "Untitled Note",
            markdown: extractContent(notionPage) ?? "",
            tags: extractTags(notionPage)
        )
        
        return note
    }
    
    /// Convert a Notion page to an Area
    static func convertToArea(_ notionPage: Page) -> Area {
        let area = Area(
            title: extractTitle(notionPage) ?? "Untitled Area",
            notes: extractContent(notionPage),
            tags: extractTags(notionPage)
        )
        
        return area
    }
    
    /// Update an existing Task with data from Notion page
    static func updateTask(_ task: FocusOSShared.Task, from notionPage: Page) {
        if let title = extractTitle(notionPage) {
            task.title = title
        }
        if let notes = extractNotes(notionPage) {
            task.notes = notes
        }
        if let status = convertStatus(extractStatus(notionPage)) {
            task.status = status
        }
        if let priority = convertPriority(extractPriority(notionPage)) {
            task.priority = priority
        }
        if let dueDate = extractDueDate(notionPage) {
            task.dueDate = dueDate
        }
        task.lastSyncedAt = Date()
        task.updatedAt = Date()
    }
    
    /// Update an existing Project with data from Notion page
    static func updateProject(_ project: FocusOSShared.Project, from notionPage: Page) {
        if let title = extractTitle(notionPage) {
            project.title = title
        }
        if let goal = extractGoal(notionPage) {
            project.goal = goal
        }
        if let status = convertProjectStatus(extractStatus(notionPage)) {
            project.status = status
        }
        if let dueDate = extractDueDate(notionPage) {
            project.dueDate = dueDate
        }
        project.lastSyncedAt = Date()
        project.updatedAt = Date()
    }
    
    /// Update an existing Note with data from Notion page
    static func updateNote(_ note: FocusOSShared.Note, from notionPage: Page) {
        if let title = extractTitle(notionPage) {
            note.title = title
        }
        if let content = extractContent(notionPage) {
            note.markdown = content
        }
        note.updatedAt = Date()
    }
    
    // MARK: - Property Extraction
    
    private static func extractTitle(_ page: Page) -> String? {
        let properties = page.properties
        
        // Try to find title property (usually the first property or named "Name" or "Title")
        for (key, property) in properties {
            if case .title(let titleArray) = property.type {
                return convertRichText(titleArray)
            } else if case .richText(let richTextArray) = property.type {
                if key.lowercased().contains("name") || key.lowercased().contains("title") {
                    return convertRichText(richTextArray)
                }
            }
        }
        
        return nil
    }
    
    private static func extractNotes(_ page: Page) -> String? {
        let properties = page.properties
        
        // Look for description, notes, or similar properties
        for (key, property) in properties {
            let lowerKey = key.lowercased()
            if lowerKey.contains("note") || lowerKey.contains("description") || lowerKey.contains("detail") {
                if case .richText(let richTextArray) = property.type {
                    return convertRichText(richTextArray)
                }
            }
        }
        
        return nil
    }
    
    private static func extractContent(_ page: Page) -> String? {
        // Content is typically in blocks, not properties
        // This would require fetching blocks separately
        // For now, return notes/description
        return extractNotes(page)
    }
    
    private static func extractStatus(_ page: Page) -> String? {
        let properties = page.properties
        
        // Look for status or select property
        for (key, property) in properties {
            let lowerKey = key.lowercased()
            if lowerKey.contains("status") {
                if case .status(let status) = property.type {
                    return status?.name
                } else if case .select(let select) = property.type {
                    return select?.name
                }
            }
        }
        
        return nil
    }
    
    private static func extractPriority(_ page: Page) -> String? {
        let properties = page.properties
        
        // Look for priority property
        for (key, property) in properties {
            let lowerKey = key.lowercased()
            if lowerKey.contains("priority") || lowerKey.contains("urgent") {
                if case .select(let select) = property.type {
                    return select?.name
                }
            }
        }
        
        return nil
    }
    
    private static func extractDueDate(_ page: Page) -> Date? {
        let properties = page.properties
        
        // Look for due date or date property
        for (key, property) in properties {
            let lowerKey = key.lowercased()
            if lowerKey.contains("due") || lowerKey.contains("date") {
                if case .date(let dateValue) = property.type {
                    guard let dateRange = dateValue else { return nil }
                    switch dateRange.start {
                    case .dateOnly(let date), .dateAndTime(let date):
                        return date
                    }
                }
            }
        }
        
        return nil
    }
    
    private static func extractGoal(_ page: Page) -> String? {
        let properties = page.properties
        
        // Look for goal property
        for (key, property) in properties {
            let lowerKey = key.lowercased()
            if lowerKey.contains("goal") || lowerKey.contains("objective") {
                if case .richText(let richTextArray) = property.type {
                    return convertRichText(richTextArray)
                }
            }
        }
        
        return nil
    }
    
    private static func extractTags(_ page: Page) -> [String] {
        let properties = page.properties
        
        var tags: [String] = []
        
        // Look for multi-select or select properties that might be tags
        for (key, property) in properties {
            let lowerKey = key.lowercased()
            if lowerKey.contains("tag") || lowerKey.contains("label") || lowerKey.contains("category") {
                if case .multiSelect(let multiSelect) = property.type {
                    tags.append(contentsOf: multiSelect.compactMap { $0.name })
                }
            }
        }
        
        return tags
    }
    
    // MARK: - Type Conversions
    
    private static func convertStatus(_ notionStatus: String?) -> TaskStatus? {
        guard let status = notionStatus?.lowercased() else { return nil }
        
        switch status {
        case "todo", "not started", "to do":
            return .todo
        case "in progress", "in-progress", "doing":
            return .inProgress
        case "done", "completed", "complete":
            return .done
        case "cancelled", "canceled":
            return .cancelled
        default:
            return nil
        }
    }
    
    private static func convertProjectStatus(_ notionStatus: String?) -> ProjectStatus? {
        guard let status = notionStatus?.lowercased() else { return nil }
        
        switch status {
        case "active", "in progress", "doing":
            return .active
        case "paused", "on hold":
            return .paused
        case "completed", "done", "complete":
            return .completed
        default:
            return nil
        }
    }
    
    private static func convertPriority(_ notionPriority: String?) -> TaskPriority? {
        guard let priority = notionPriority?.lowercased() else { return nil }
        
        switch priority {
        case "high", "urgent", "critical":
            return .high
        case "medium", "normal":
            return .medium
        case "low":
            return .low
        default:
            return nil
        }
    }
    
    /// Convert Notion rich text array to plain string
    static func convertRichText(_ richText: [RichText]) -> String {
        return richText.compactMap { $0.plainText }.joined()
    }
}

