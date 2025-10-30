//
//  Project.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData
import SwiftUI

enum ProjectStatus: String, Codable, CaseIterable {
    case active, paused, completed
    
    var displayName: String {
        switch self {
        case .active: return "Active"
        case .paused: return "Paused"
        case .completed: return "Completed"
        }
    }
}

@Model
final class Project {
    var id: UUID = UUID()
    var title: String = ""
    var goal: String?
    var statusRaw: String = ProjectStatus.active.rawValue
    var dueDate: Date?
    var areaId: UUID?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var tags: [String] = []
    
    // Relationships (tracked via IDs for flexibility)
    var taskIds: [UUID] = []
    var noteIds: [UUID] = []
    var postIds: [UUID] = []
    
    init(
        title: String,
        goal: String? = nil,
        status: ProjectStatus = .active,
        dueDate: Date? = nil,
        areaId: UUID? = nil,
        tags: [String] = []
    ) {
        self.id = UUID()
        self.title = title
        self.goal = goal
        self.statusRaw = status.rawValue
        self.dueDate = dueDate
        self.areaId = areaId
        self.tags = tags
        self.createdAt = Date()
        self.updatedAt = Date()
        self.taskIds = []
        self.noteIds = []
        self.postIds = []
    }
    
    var status: ProjectStatus {
        get { ProjectStatus(rawValue: statusRaw) ?? .active }
        set { 
            statusRaw = newValue.rawValue
            updatedAt = Date()
        }
    }
}

