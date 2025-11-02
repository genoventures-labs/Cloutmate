//
//  Task.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData
import SwiftUI

public enum TaskStatus: String, Codable, CaseIterable {
    case todo, inProgress, done, cancelled
    
    public var displayName: String {
        switch self {
        case .todo: return "To Do"
        case .inProgress: return "In Progress"
        case .done: return "Done"
        case .cancelled: return "Cancelled"
        }
    }
}

public enum TaskPriority: String, Codable, CaseIterable {
    case low, medium, high
    
    public var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
    
    public var color: Color {
        switch self {
        case .low: return Color(white: 0.5) // Gray
        case .medium: return Color(red: 72/255, green: 131/255, blue: 255/255) // Kosmic blue
        case .high: return Color(red: 229/255, green: 57/255, blue: 53/255) // Red
        }
    }
}

@Model
public final class Task {
    public var id: UUID = UUID()
    public var title: String = ""
    public var notes: String?
    public var statusRaw: String = TaskStatus.todo.rawValue
    public var priorityRaw: String = TaskPriority.medium.rawValue
    public var dueDate: Date?
    public var projectId: UUID?
    public var areaId: UUID?
    public var dependsOnIds: [UUID] = []
    public var effort: String? // small, medium, large
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var completedAt: Date?
    
    public init(
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
    
    public var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .todo }
        set { 
            statusRaw = newValue.rawValue
            updatedAt = Date()
            if newValue == .done && completedAt == nil {
                completedAt = Date()
            }
        }
    }
    
    public var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .medium }
        set { 
            priorityRaw = newValue.rawValue
            updatedAt = Date()
        }
    }
}

