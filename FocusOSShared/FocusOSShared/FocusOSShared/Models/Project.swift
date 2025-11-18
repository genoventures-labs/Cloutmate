//
//  Project.swift
//  FocusOS
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData
import SwiftUI

public enum ProjectStatus: String, Codable, CaseIterable {
    case active, paused, completed
    
    public var displayName: String {
        switch self {
        case .active: return "Active"
        case .paused: return "Paused"
        case .completed: return "Completed"
        }
    }
}

@Model
public final class Project {
    public var id: UUID = UUID()
    public var title: String = ""
    public var goal: String?
    public var statusRaw: String = ProjectStatus.active.rawValue
    public var dueDate: Date?
    public var areaId: UUID?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var archivedAt: Date?
    public var tags: [String] = []
    
    // Relationships (tracked via IDs for flexibility)
    public var taskIds: [UUID] = []
    public var noteIds: [UUID] = []
    public var postIds: [UUID] = []
    
    // Mention linking
    public var linkedEntityIds: [UUID] = [] // IDs of mentioned items
    public var linkedEntityTypes: [String] = [] // Types of mentioned items
    
    // External project tracking
    public var externalProjectId: String? // Todoist project ID, Notion page ID, etc.
    public var externalSource: String? // "todoist", "notion", etc.
    public var lastSyncedAt: Date?
    
    public init(
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
        self.linkedEntityIds = []
        self.linkedEntityTypes = []
        self.externalProjectId = nil
        self.externalSource = nil
        self.lastSyncedAt = nil
    }
    
    public var status: ProjectStatus {
        get { ProjectStatus(rawValue: statusRaw) ?? .active }
        set { 
            statusRaw = newValue.rawValue
            updatedAt = Date()
        }
    }
}

