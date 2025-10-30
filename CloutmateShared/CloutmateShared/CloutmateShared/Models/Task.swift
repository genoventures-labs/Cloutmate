//
//  Task.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData
import SwiftUI

enum TaskStatus: String, Codable, CaseIterable {
    case todo, inProgress, done, cancelled
    
    var displayName: String {
        switch self {
        case .todo: return "To Do"
        case .inProgress: return "In Progress"
        case .done: return "Done"
        case .cancelled: return "Cancelled"
        }
    }
}

enum TaskPriority: String, Codable, CaseIterable {
    case low, medium, high
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .red
        }
    }
}

@Model
final class Task {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String?
    var statusRaw: String = TaskStatus.todo.rawValue
    var priorityRaw: String = TaskPriority.medium.rawValue
    var dueDate: Date?
    var projectId: UUID?
    var areaId: UUID?
    var dependsOnIds: [UUID] = []
    var effort: String? // small, medium, large
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var completedAt: Date?
    
    init(
        title: String,
        notes: String? = nil,
        status: TaskStatus = .todo,
        priority: TaskPriority = .medium,
        dueDate: Date? = nil,
        projectId: UUID? = nil,
        areaId: UUID? = nil,
        effort: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.statusRaw = status.rawValue
        self.priorityRaw = priority.rawValue
        self.dueDate = dueDate
        self.projectId = projectId
        self.areaId = areaId
        self.effort = effort
        self.createdAt = Date()
        self.updatedAt = Date()
        self.dependsOnIds = []
    }
    
    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .todo }
        set { 
            statusRaw = newValue.rawValue
            updatedAt = Date()
            if newValue == .done && completedAt == nil {
                completedAt = Date()
            }
        }
    }
    
    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .medium }
        set { 
            priorityRaw = newValue.rawValue
            updatedAt = Date()
        }
    }
}

