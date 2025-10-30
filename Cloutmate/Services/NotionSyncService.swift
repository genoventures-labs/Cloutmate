//
//  NotionSyncService.swift
//  Cloutmate
//
//  Service for importing and syncing data from Notion
//

import Foundation
import SwiftData
import os.log

final class NotionSyncService {
    static let shared = NotionSyncService()
    
    private let notionService = NotionService.shared
    private init() {}
    
    // MARK: - Import Process
    
    func importDatabase(
        databaseId: String,
        cloutmateType: String,
        propertyMappings: [String: String],
        accessToken: String,
        context: ModelContext
    ) async throws {
        os_log("Starting import for database: %{public}@", log: .default, type: .info, databaseId)
        
        // Fetch database structure
        let database = try await notionService.getDatabase(
            databaseId: databaseId,
            accessToken: accessToken
        )
        
        // Query all pages from the database
        let pages = try await notionService.queryDatabase(
            databaseId: databaseId,
            accessToken: accessToken
        )
        
        os_log("Found %d pages to import", log: .default, type: .info, pages.results.count)
        
        // Track imported items for relationship building
        var importedItems: [String: Any] = [:] // [notionPageId: CloutmateModel]
        
        // Convert each page to the appropriate Cloutmate model
        for page in pages.results {
            let importedItem = try await importPage(
                page: page,
                cloutmateType: cloutmateType,
                propertyMappings: propertyMappings,
                context: context,
                databaseTitle: extractTitle(database.title)
            )
            importedItems[page.id] = importedItem
        }
        
        // Build relationships after all items are imported
        try buildRelationships(
            pages: pages.results,
            importedItems: importedItems,
            cloutmateType: cloutmateType,
            propertyMappings: propertyMappings,
            context: context
        )
        
        // Save sync configuration
        let config = NotionSyncConfig(
            databaseId: databaseId,
            cloutmateType: cloutmateType,
            propertyMappings: propertyMappings
        )
        config.databaseTitle = extractTitle(database.title)
        config.workspaceId = await getWorkspaceId(accessToken: accessToken)
        context.insert(config)
        
        try context.save()
        os_log("Import completed successfully", log: .default, type: .info)
    }
    
    // MARK: - Page Import
    
    private func importPage(
        page: NotionPage,
        cloutmateType: String,
        propertyMappings: [String: String],
        context: ModelContext,
        databaseTitle: String
    ) async throws -> Any {
        switch cloutmateType {
        case "Project":
            try importAsProject(
                page: page,
                propertyMappings: propertyMappings,
                context: context
            )
        case "Task":
            try importAsTask(
                page: page,
                propertyMappings: propertyMappings,
                context: context
            )
        case "Note":
            try importAsNote(
                page: page,
                propertyMappings: propertyMappings,
                context: context
            )
        case "Area":
            try importAsArea(
                page: page,
                propertyMappings: propertyMappings,
                context: context
            )
        default:
            Logger.notion.warning("Unknown Cloutmate type: \(cloutmateType)")
        }
    }
    
    // MARK: - Import as Project
    
    private func importAsProject(
        page: NotionPage,
        propertyMappings: [String: String],
        context: ModelContext
    ) throws -> Project {
        let project = Project(title: "")
        
        // Apply property mappings
        applyMappingsToProject(project: project, page: page, propertyMappings: propertyMappings)
        
        // If title wasn't mapped or is empty, try to get default title property
        if project.title.isEmpty {
            project.title = extractTitle(page.properties.values.first(where: { prop in
                if case .title = prop { return true }
                return false
            }) ?? .title([]))
        }
        
        context.insert(project)
        return project
    }
    
    // MARK: - Import as Task
    
    private func importAsTask(
        page: NotionPage,
        propertyMappings: [String: String],
        context: ModelContext
    ) throws -> Task {
        let task = Task(title: "")
        
        // Apply property mappings
        applyMappingsToTask(task: task, page: page, propertyMappings: propertyMappings)
        
        // If title wasn't mapped or is empty, try to get default title property
        if task.title.isEmpty {
            task.title = extractTitle(page.properties.values.first(where: { prop in
                if case .title = prop { return true }
                return false
            }) ?? .title([]))
        }
        
        context.insert(task)
        return task
    }
    
    // MARK: - Import as Note
    
    private func importAsNote(
        page: NotionPage,
        propertyMappings: [String: String],
        context: ModelContext
    ) throws -> Note {
        let note = Note(title: "")
        
        // Apply property mappings
        applyMappingsToNote(note: note, page: page, propertyMappings: propertyMappings)
        
        // If title wasn't mapped or is empty, try to get default title property
        if note.title.isEmpty {
            note.title = extractTitle(page.properties.values.first(where: { prop in
                if case .title = prop { return true }
                return false
            }) ?? .title([]))
        }
        
        context.insert(note)
        return note
    }
    
    // MARK: - Import as Area
    
    private func importAsArea(
        page: NotionPage,
        propertyMappings: [String: String],
        context: ModelContext
    ) throws -> Area {
        let area = Area(title: "")
        
        // Apply property mappings
        applyMappingsToArea(area: area, page: page, propertyMappings: propertyMappings)
        
        // If title wasn't mapped or is empty, try to get default title property
        if area.title.isEmpty {
            area.title = extractTitle(page.properties.values.first(where: { prop in
                if case .title = prop { return true }
                return false
            }) ?? .title([]))
        }
        
        context.insert(area)
        return area
    }
    
    // MARK: - Property Mapping
    
    private func applyMappingsToProject(
        project: Project,
        page: NotionPage,
        propertyMappings: [String: String]
    ) {
        for (notionPropertyName, cloutmateField) in propertyMappings {
            guard let notionValue = page.properties[notionPropertyName] else { continue }
            
            switch cloutmateField {
            case "title":
                if let title = getString(from: notionValue) {
                    project.title = title
                }
            case "goal":
                if let goal = getString(from: notionValue) {
                    project.goal = goal
                }
            case "statusRaw":
                if let status = getString(from: notionValue) {
                    project.statusRaw = mapStatusToCloutmate(status, type: "project")
                }
            case "dueDate":
                if let date = getDate(from: notionValue) {
                    project.dueDate = date
                }
            case "tags":
                project.tags = getStringArray(from: notionValue)
            default:
                break
            }
        }
    }
    
    private func applyMappingsToTask(
        task: Task,
        page: NotionPage,
        propertyMappings: [String: String]
    ) {
        for (notionPropertyName, cloutmateField) in propertyMappings {
            guard let notionValue = page.properties[notionPropertyName] else { continue }
            
            switch cloutmateField {
            case "title":
                if let title = getString(from: notionValue) {
                    task.title = title
                }
            case "notes":
                if let notes = getString(from: notionValue) {
                    task.notes = notes
                }
            case "statusRaw":
                if let status = getString(from: notionValue) {
                    task.statusRaw = mapStatusToCloutmate(status, type: "task")
                }
            case "priorityRaw":
                if let priority = getString(from: notionValue) {
                    task.priorityRaw = mapPriorityToCloutmate(priority)
                }
            case "dueDate":
                if let date = getDate(from: notionValue) {
                    task.dueDate = date
                }
            case "projectId":
                // This will be handled specially after all imports
                break
            case "effort":
                if let effort = getString(from: notionValue) {
                    task.effort = effort
                }
            default:
                break
            }
        }
    }
    
    private func applyMappingsToNote(
        note: Note,
        page: NotionPage,
        propertyMappings: [String: String]
    ) {
        for (notionPropertyName, cloutmateField) in propertyMappings {
            guard let notionValue = page.properties[notionPropertyName] else { continue }
            
            switch cloutmateField {
            case "title":
                if let title = getString(from: notionValue) {
                    note.title = title
                }
            case "markdown":
                if let content = getString(from: notionValue) {
                    note.markdown = content
                }
            case "tags":
                note.tags = getStringArray(from: notionValue)
            default:
                break
            }
        }
    }
    
    private func applyMappingsToArea(
        area: Area,
        page: NotionPage,
        propertyMappings: [String: String]
    ) {
        for (notionPropertyName, cloutmateField) in propertyMappings {
            guard let notionValue = page.properties[notionPropertyName] else { continue }
            
            switch cloutmateField {
            case "title":
                if let title = getString(from: notionValue) {
                    area.title = title
                }
            case "notes":
                if let notes = getString(from: notionValue) {
                    area.notes = notes
                }
            case "cadenceSetting":
                if let cadence = getString(from: notionValue) {
                    area.cadenceSetting = cadence
                }
            case "tags":
                area.tags = getStringArray(from: notionValue)
            default:
                break
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getString(from value: NotionPropertyValue) -> String? {
        switch value {
        case .title(let richTexts):
            return richTexts.first?.plainText
        case .richText(let richTexts):
            return richTexts.first?.plainText
        case .url(let string):
            return string
        case .email(let string):
            return string
        case .phoneNumber(let string):
            return string
        case .select(let option):
            return option?.name
        default:
            return nil
        }
    }
    
    private func getStringArray(from value: NotionPropertyValue) -> [String] {
        switch value {
        case .multiSelect(let options):
            return options.map { $0.name }
        default:
            return []
        }
    }
    
    private func getDate(from value: NotionPropertyValue) -> Date? {
        switch value {
        case .date(let dateValue):
            return dateValue?.start
        case .createdTime(let date):
            return date
        case .lastEditedTime(let date):
            return date
        default:
            return nil
        }
    }
    
    private func extractTitle(_ richTexts: [NotionRichText]) -> String {
        richTexts.compactMap { $0.plainText }.joined()
    }
    
    private func extractTitle(_ value: NotionPropertyValue) -> String {
        switch value {
        case .title(let richTexts):
            return extractTitle(richTexts)
        case .richText(let richTexts):
            return extractTitle(richTexts)
        default:
            return ""
        }
    }
    
    private func mapStatusToCloutmate(_ status: String, type: String) -> String {
        let lowercased = status.lowercased()
        
        if type == "project" {
            switch lowercased {
            case "active", "in progress":
                return ProjectStatus.active.rawValue
            case "paused", "on hold":
                return ProjectStatus.paused.rawValue
            case "completed", "done":
                return ProjectStatus.completed.rawValue
            default:
                return status
            }
        } else if type == "task" {
            switch lowercased {
            case "todo", "to do", "not started":
                return TaskStatus.todo.rawValue
            case "in progress", "in process":
                return TaskStatus.inProgress.rawValue
            case "done", "completed":
                return TaskStatus.done.rawValue
            case "cancelled", "canceled":
                return TaskStatus.cancelled.rawValue
            default:
                return status
            }
        }
        
        return status
    }
    
    private func mapPriorityToCloutmate(_ priority: String) -> String {
        let lowercased = priority.lowercased()
        
        switch lowercased {
        case "low", "1", "p4":
            return TaskPriority.low.rawValue
        case "medium", "normal", "2", "p3":
            return TaskPriority.medium.rawValue
        case "high", "urgent", "3", "p2", "p1":
            return TaskPriority.high.rawValue
        default:
            return priority
        }
    }
    
    private func getWorkspaceId(accessToken: String) async -> String? {
        // Notion doesn't provide a direct workspace ID in search results
        // This would need to be stored during initial OAuth
        return nil
    }
    
    // MARK: - Relationship Building
    
    private func buildRelationships(
        pages: [NotionPage],
        importedItems: [String: Any],
        cloutmateType: String,
        propertyMappings: [String: String],
        context: ModelContext
    ) throws {
        // Handle Task -> Project relationships
        if cloutmateType == "Task" {
            for page in pages {
                guard let task = importedItems[page.id] as? Task else { continue }
                
                // Look for projectId mapping in property mappings
                for (notionProperty, cloutmateField) in propertyMappings {
                    if cloutmateField == "projectId" {
                        // Get the relation value from the page
                        if let propertyValue = page.properties[notionProperty],
                           case .relation(let relation) = propertyValue {
                            // Find the corresponding project in imported items
                            if let project = findProjectInImportedItems(
                                notionId: relation.id,
                                items: importedItems
                            ) {
                                task.projectId = project.id
                                
                                // Also update the project's taskIds array
                                if !project.taskIds.contains(task.id) {
                                    project.taskIds.append(task.id)
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Handle Note -> Project relationships
        if cloutmateType == "Note" {
            for page in pages {
                guard let note = importedItems[page.id] as? Note else { continue }
                
                // Look for projectId mapping
                for (notionProperty, cloutmateField) in propertyMappings {
                    if cloutmateField == "projectId" {
                        if let propertyValue = page.properties[notionProperty],
                           case .relation(let relation) = propertyValue {
                            if let project = findProjectInImportedItems(
                                notionId: relation.id,
                                items: importedItems
                            ) {
                                note.projectId = project.id
                                
                                if !project.noteIds.contains(note.id) {
                                    project.noteIds.append(note.id)
                                }
                            }
                        }
                    }
                }
            }
        }
        
        try context.save()
    }
    
    private func findProjectInImportedItems(notionId: String, items: [String: Any]) -> Project? {
        // This is simplified - in reality, we'd need to track Notion IDs
        for item in items.values {
            if let project = item as? Project {
                return project
            }
        }
        return nil
    }
}

