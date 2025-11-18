//
//  MondayConverter.swift
//  FocusOS
//
//  Converts Monday.com models to FocusOS models
//

import Foundation
import FocusOSShared

struct MondayConverter {
    
    /// Convert a MondayBoard to a Project
    static func convertToProject(_ mondayBoard: MondayBoard) -> Project {
        let project = Project(
            title: mondayBoard.name,
            goal: mondayBoard.description,
            status: .active, // Monday.com boards don't have a direct status, default to active
            tags: []
        )
        
        // Set external tracking fields
        project.externalProjectId = mondayBoard.id
        project.externalSource = "monday"
        project.lastSyncedAt = Date()
        
        return project
    }
    
    /// Convert a MondayItem to a Task
    static func convertToTask(_ mondayItem: MondayItem, boardId: String) -> Task {
        let task = Task(
            title: mondayItem.name,
            notes: extractNotes(mondayItem.columnValues),
            status: extractStatus(mondayItem.columnValues) ?? .todo,
            priority: extractPriority(mondayItem.columnValues) ?? .medium,
            dueDate: extractDueDate(mondayItem.columnValues)
        )
        
        // Set external tracking fields
        task.externalReminderId = mondayItem.id
        task.externalReminderListId = boardId // Track which board the item belongs to
        task.externalSource = "monday"
        task.lastSyncedAt = Date()
        
        // Set completedAt if item is in done state
        if mondayItem.state == "done" || extractStatus(mondayItem.columnValues) == .done {
            task.completedAt = mondayItem.updatedAt.flatMap { parseDate($0) } ?? Date()
        }
        
        return task
    }
    
    /// Extract task status from column values
    static func extractStatus(_ columnValues: [MondayColumnValue]) -> TaskStatus? {
        for columnValue in columnValues {
            // Look for status column
            if columnValue.type == "status" {
                guard let text = columnValue.text?.lowercased() else { continue }
                
                if text.contains("done") || text.contains("completed") || text.contains("complete") {
                    return .done
                } else if text.contains("working") || text.contains("in progress") || text.contains("doing") {
                    return .inProgress
                } else if text.contains("todo") || text.contains("to do") || text.contains("not started") {
                    return .todo
                } else if text.contains("cancelled") || text.contains("canceled") {
                    return .cancelled
                }
            }
        }
        return nil
    }
    
    /// Extract due date from column values
    static func extractDueDate(_ columnValues: [MondayColumnValue]) -> Date? {
        for columnValue in columnValues {
            // Look for date column
            if columnValue.type == "date" {
                // Try to parse from value (JSON string) or text
                if let value = columnValue.value {
                    // Monday.com date values are often JSON strings
                    if let jsonData = value.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let dateString = json["date"] as? String {
                        return parseDate(dateString)
                    }
                }
                
                // Fall back to text if available
                if let text = columnValue.text {
                    return parseDate(text)
                }
            }
        }
        return nil
    }
    
    /// Extract priority from column values
    static func extractPriority(_ columnValues: [MondayColumnValue]) -> TaskPriority? {
        for columnValue in columnValues {
            let lowerType = columnValue.type?.lowercased() ?? ""
            let lowerText = columnValue.text?.lowercased() ?? ""
            
            // Look for priority or urgency columns
            if lowerType.contains("priority") || lowerType.contains("urgency") {
                if lowerText.contains("high") || lowerText.contains("urgent") || lowerText.contains("critical") {
                    return .high
                } else if lowerText.contains("medium") || lowerText.contains("normal") {
                    return .medium
                } else if lowerText.contains("low") {
                    return .low
                }
            }
        }
        return nil
    }
    
    /// Extract notes/description from column values
    static func extractNotes(_ columnValues: [MondayColumnValue]) -> String? {
        var notes: [String] = []
        
        for columnValue in columnValues {
            let lowerType = columnValue.type?.lowercased() ?? ""
            let lowerId = columnValue.id.lowercased()
            
            // Look for text, note, description, or long text columns
            if lowerType == "text" || lowerType == "long_text" || 
               lowerId.contains("note") || lowerId.contains("description") || lowerId.contains("detail") {
                if let text = columnValue.text, !text.isEmpty {
                    notes.append(text)
                }
            }
        }
        
        return notes.isEmpty ? nil : notes.joined(separator: "\n\n")
    }
    
    /// Parse date string (ISO 8601 or common formats)
    private static func parseDate(_ dateString: String) -> Date? {
        // Try ISO 8601 first
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        
        // Try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        
        // Try common date formats
        let formatters = [
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "dd/MM/yyyy",
            "yyyy-MM-dd HH:mm:ss"
        ]
        
        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    /// Update an existing Project with data from MondayBoard
    static func updateProject(_ project: Project, from mondayBoard: MondayBoard) {
        project.title = mondayBoard.name
        if let description = mondayBoard.description {
            project.goal = description
        }
        project.lastSyncedAt = Date()
        project.updatedAt = Date()
    }
    
    /// Update an existing Task with data from MondayItem
    static func updateTask(_ task: Task, from mondayItem: MondayItem, boardId: String) {
        task.title = mondayItem.name
        task.notes = extractNotes(mondayItem.columnValues)
        if let status = extractStatus(mondayItem.columnValues) {
            task.status = status
        }
        if let priority = extractPriority(mondayItem.columnValues) {
            task.priority = priority
        }
        task.dueDate = extractDueDate(mondayItem.columnValues)
        task.externalReminderListId = boardId
        task.lastSyncedAt = Date()
        
        // Update completedAt
        if mondayItem.state == "done" || extractStatus(mondayItem.columnValues) == .done {
            if task.completedAt == nil {
                task.completedAt = mondayItem.updatedAt.flatMap { parseDate($0) } ?? Date()
            }
        } else {
            task.completedAt = nil
        }
        
        task.updatedAt = Date()
    }
}

