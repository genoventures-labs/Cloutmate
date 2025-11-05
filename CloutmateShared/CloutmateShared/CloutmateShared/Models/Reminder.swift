//
//  Reminder.swift
//  Cloutmate
//
//  Reminder model for in-app notifications
//

import Foundation
import SwiftData
import SwiftUI

@Model
public final class Reminder {
    @Attribute public var id: UUID = UUID()
    @Attribute public var title: String = ""
    @Attribute public var notes: String?
    @Attribute public var reminderDate: Date = Date()
    @Attribute public var isCompleted: Bool = false
    @Attribute public var notificationIdentifier: String?
    @Attribute public var createdAt: Date = Date()
    @Attribute public var updatedAt: Date = Date()
    
    // Optional linking to tasks/projects
    @Attribute public var taskId: UUID?
    @Attribute public var projectId: UUID?
    
    public init(
        title: String,
        notes: String? = nil,
        reminderDate: Date,
        taskId: UUID? = nil,
        projectId: UUID? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.reminderDate = reminderDate
        self.taskId = taskId
        self.projectId = projectId
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isCompleted = false
    }
}

