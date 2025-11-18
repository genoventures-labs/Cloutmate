//
//  TodoistConverter.swift
//  FocusOS
//
//  Converts Todoist API models to FocusOS models
//

import Foundation
import FocusOSShared

struct TodoistConverter {
    
    /// Convert a TodoistProject to a Project
    static func convertProject(_ todoistProject: TodoistProject) -> Project {
        let project = Project(
            title: todoistProject.name,
            status: convertProjectStatus(todoistProject),
            tags: []
        )
        
        // Set external tracking fields
        project.externalProjectId = todoistProject.id
        project.externalSource = "todoist"
        project.lastSyncedAt = Date()
        
        return project
    }
    
    /// Convert a TodoistTask to a Task
    static func convertTask(_ todoistTask: TodoistTask, projectId: UUID?) -> Task {
        let task = Task(
            title: todoistTask.content,
            notes: todoistTask.description,
            status: convertStatus(todoistTask),
            priority: convertPriority(todoistTask),
            dueDate: convertDueDate(todoistTask),
            projectId: projectId
        )
        
        // Set external tracking fields
        task.externalReminderId = todoistTask.id // Reuse field from Reminders
        task.externalSource = "todoist"
        task.lastSyncedAt = Date()
        
        // Set completedAt if task is completed
        if todoistTask.isCompleted, let completedAtString = todoistTask.completedAt {
            task.completedAt = parseDate(completedAtString)
        }
        
        return task
    }
    
    /// Convert Todoist due date to Date
    static func convertDueDate(_ task: TodoistTask) -> Date? {
        guard let due = task.due else {
            return nil
        }
        
        // Prefer datetime if available (includes time)
        if let datetimeString = due.datetime {
            return parseDate(datetimeString)
        }
        
        // Fall back to date (date-only)
        return parseDate(due.date)
    }
    
    /// Parse ISO 8601 date string
    private static func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }
    
    /// Convert Todoist priority (1-4) to TaskPriority
    static func convertPriority(_ task: TodoistTask) -> TaskPriority {
        switch task.priority {
        case 1:
            return .low
        case 2, 3:
            return .medium
        case 4:
            return .high
        default:
            return .medium
        }
    }
    
    /// Convert Todoist completion status to TaskStatus
    static func convertStatus(_ task: TodoistTask) -> TaskStatus {
        return task.isCompleted ? .done : .todo
    }
    
    /// Convert Todoist project archived status to ProjectStatus
    static func convertProjectStatus(_ project: TodoistProject) -> ProjectStatus {
        return project.isArchived ? .completed : .active
    }
    
    /// Update an existing Project with data from TodoistProject
    static func updateProject(_ project: Project, from todoistProject: TodoistProject) {
        project.title = todoistProject.name
        project.status = convertProjectStatus(todoistProject)
        project.lastSyncedAt = Date()
        project.updatedAt = Date()
    }
    
    /// Update an existing Task with data from TodoistTask
    static func updateTask(_ task: Task, from todoistTask: TodoistTask) {
        task.title = todoistTask.content
        task.notes = todoistTask.description
        task.dueDate = convertDueDate(todoistTask)
        task.priority = convertPriority(todoistTask)
        task.status = convertStatus(todoistTask)
        task.lastSyncedAt = Date()
        
        // Update completedAt if task is completed
        if todoistTask.isCompleted {
            if let completedAtString = todoistTask.completedAt {
                task.completedAt = parseDate(completedAtString)
            } else if task.completedAt == nil {
                task.completedAt = Date()
            }
        } else {
            task.completedAt = nil
        }
        
        task.updatedAt = Date()
    }
}

