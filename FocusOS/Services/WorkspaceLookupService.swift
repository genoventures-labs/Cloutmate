//
//  WorkspaceLookupService.swift
//  FocusOS
//
//  Centralized lookup helpers for workspace objects. Provides deterministic,
//  cache-free queries so callers can safely verify whether referenced objects
//  actually exist before attempting any action.
//

import Foundation
import SwiftData
import FocusOSShared

@MainActor
final class WorkspaceLookupService {
    static let shared = WorkspaceLookupService()

    private init() {}

    private typealias WorkspaceTask = FocusOSShared.Task
    private typealias WorkspaceNote = FocusOSShared.Note

    func lookupProject(name: String, modelContext: ModelContext) -> Project? {
        var descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { project in
                project.title.localizedStandardContains(name)
            },
            sortBy: [SortDescriptor(\Project.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    func lookupTask(name: String, projectId: UUID?, modelContext: ModelContext) -> FocusOSShared.Task? {
        var descriptor: FetchDescriptor<WorkspaceTask>
        if let projectId = projectId {
            descriptor = FetchDescriptor<WorkspaceTask>(
                predicate: #Predicate { task in
                    task.projectId == projectId && task.title.localizedStandardContains(name)
                },
                sortBy: [SortDescriptor(\WorkspaceTask.updatedAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<WorkspaceTask>(
                predicate: #Predicate { task in
                    task.title.localizedStandardContains(name)
                },
                sortBy: [SortDescriptor(\WorkspaceTask.updatedAt, order: .reverse)]
            )
        }
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    func lookupArea(name: String, modelContext: ModelContext) -> Area? {
        var descriptor = FetchDescriptor<Area>(
            predicate: #Predicate { area in
                area.title.localizedStandardContains(name)
            },
            sortBy: [SortDescriptor(\Area.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    func lookupNote(name: String, modelContext: ModelContext) -> FocusOSShared.Note? {
        var descriptor = FetchDescriptor<WorkspaceNote>(
            predicate: #Predicate { note in
                note.title.localizedStandardContains(name)
            },
            sortBy: [SortDescriptor(\WorkspaceNote.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    func lookupReminder(name: String, modelContext: ModelContext) -> Reminder? {
        var descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { reminder in
                reminder.title.localizedStandardContains(name)
            },
            sortBy: [SortDescriptor(\Reminder.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}
