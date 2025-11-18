//
//  TodoistImportService.swift
//  FocusOS
//
//  Main service for importing and syncing Todoist projects and tasks
//

import Foundation
import SwiftData
import Combine
import os.log
import FocusOSShared

struct TodoistImportResult {
    let importedCount: Int
    let updatedCount: Int
    let deletedCount: Int
    let errors: [Error]
}

@MainActor
final class TodoistImportService: ObservableObject {
    static let shared = TodoistImportService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "TodoistImport")
    private let todoistService = TodoistService.shared
    private var cancellables = Set<AnyCancellable>()
    private var syncTask: _Concurrency.Task<Void, Never>?
    private var isRunning = false
    
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncError: Error?
    
    private let settings = TodoistImportSettings.shared
    
    private init() {}
    
    // MARK: - Lifecycle
    
    func start(modelContext: ModelContext) async {
        guard settings.importEnabled else {
            logger.debug("Todoist import disabled")
            return
        }
        
        guard settings.isConnected else {
            logger.debug("Todoist not connected (no access token)")
            settings.importEnabled = false
            return
        }
        
        guard !isRunning else {
            logger.debug("TodoistImportService already running")
            return
        }
        
        isRunning = true
        logger.info("Starting TodoistImportService")
        
        // Initial sync
        do {
            try await syncAllProjects(modelContext: modelContext)
        } catch {
            logger.error("Initial sync failed: \(error.localizedDescription)")
        }
        
        // Start background sync scheduler
        startBackgroundSync(modelContext: modelContext)
    }
    
    func stop() {
        syncTask?.cancel()
        syncTask = nil
        cancellables.removeAll()
        isRunning = false
        logger.info("Stopped TodoistImportService")
    }
    
    // MARK: - Import & Sync
    
    func importProjects(modelContext: ModelContext) async throws -> TodoistImportResult {
        guard let accessToken = settings.accessToken else {
            throw TodoistImportError.notAuthenticated
        }
        
        var importedCount = 0
        var updatedCount = 0
        var deletedCount = 0
        var errors: [Error] = []
        
        // Fetch projects from Todoist
        let todoistProjects: [TodoistProject]
        do {
            todoistProjects = try await todoistService.getProjects(accessToken: accessToken)
        } catch {
            if case TodoistAPIError.tokenExpired = error {
                // Try to refresh token
                if let refreshed = try? await refreshAccessToken() {
                    todoistProjects = try await todoistService.getProjects(accessToken: refreshed)
                } else {
                    throw error
                }
            } else {
                throw error
            }
        }
        
        logger.info("Found \(todoistProjects.count) projects in Todoist")
        
        // Filter by selected projects if any are selected
        let projectsToImport: [TodoistProject]
        if settings.selectedProjectIds.isEmpty {
            projectsToImport = todoistProjects.filter { !$0.isArchived }
        } else {
            projectsToImport = todoistProjects.filter { 
                settings.selectedProjectIds.contains($0.id) && !$0.isArchived
            }
        }
        
        // Get ALL existing Projects with external source to check for duplicates
        let existingProjectsDescriptor = FetchDescriptor<FocusOSShared.Project>(
            predicate: #Predicate<FocusOSShared.Project> { project in
                project.externalSource == "todoist"
            }
        )
        let existingProjects = (try? modelContext.fetch(existingProjectsDescriptor)) ?? []
        
        // Build lookup dictionary for efficient duplicate checking
        var existingProjectsByExternalId: [String: FocusOSShared.Project] = [:]
        for project in existingProjects {
            if let externalId = project.externalProjectId {
                existingProjectsByExternalId[externalId] = project
            }
        }
        
        // Process projects
        for todoistProject in projectsToImport {
            if let existingProject = existingProjectsByExternalId[todoistProject.id] {
                // Update existing project
                TodoistConverter.updateProject(existingProject, from: todoistProject)
                updatedCount += 1
                existingProjectsByExternalId.removeValue(forKey: todoistProject.id)
            } else {
                // Create new project
                let newProject = TodoistConverter.convertProject(todoistProject)
                modelContext.insert(newProject)
                importedCount += 1
            }
        }
        
        // Delete projects that no longer exist in Todoist
        for (externalId, project) in existingProjectsByExternalId {
            // Verify project still doesn't exist
            if !projectsToImport.contains(where: { $0.id == externalId }) {
                modelContext.delete(project)
                deletedCount += 1
            }
        }
        
        // Save projects
        if importedCount > 0 || updatedCount > 0 || deletedCount > 0 {
            do {
                try modelContext.save()
            } catch {
                errors.append(error)
                logger.error("Failed to save projects: \(error.localizedDescription)")
            }
        }
        
        logger.info("Projects import complete: \(importedCount) imported, \(updatedCount) updated, \(deletedCount) deleted")
        
        return TodoistImportResult(
            importedCount: importedCount,
            updatedCount: updatedCount,
            deletedCount: deletedCount,
            errors: errors
        )
    }
    
    func importTasks(projectId: String, focusOSProjectId: UUID, modelContext: ModelContext) async throws -> TodoistImportResult {
        guard let accessToken = settings.accessToken else {
            throw TodoistImportError.notAuthenticated
        }
        
        var importedCount = 0
        var updatedCount = 0
        var deletedCount = 0
        var errors: [Error] = []
        
        // Fetch tasks from Todoist for this project
        let todoistTasks: [TodoistTask]
        do {
            todoistTasks = try await todoistService.getTasks(projectId: projectId, accessToken: accessToken)
        } catch {
            if case TodoistAPIError.tokenExpired = error {
                // Try to refresh token
                if let refreshed = try? await refreshAccessToken() {
                    todoistTasks = try await todoistService.getTasks(projectId: projectId, accessToken: refreshed)
                } else {
                    throw error
                }
            } else {
                throw error
            }
        }
        
        // Filter tasks based on completion status
        let tasksToImport = todoistTasks.filter { task in
            if task.isCompleted {
                return settings.importCompletedTasks
            }
            return true
        }
        
        // Get ALL existing Tasks with external source for this project
        let existingTasksDescriptor = FetchDescriptor<FocusOSShared.Task>(
            predicate: #Predicate<FocusOSShared.Task> { task in
                task.externalSource == "todoist" && task.projectId == focusOSProjectId
            }
        )
        let existingTasks = (try? modelContext.fetch(existingTasksDescriptor)) ?? []
        
        // Build lookup dictionaries for efficient duplicate checking
        var existingTasksByExternalId: [String: FocusOSShared.Task] = [:]
        var existingTasksBySignature: [String: FocusOSShared.Task] = [:]
        
        for task in existingTasks {
            if let externalId = task.externalReminderId {
                existingTasksByExternalId[externalId] = task
            }
            
            // Also index by signature (title + dueDate) to catch duplicates
            let dueDateStr = task.dueDate?.timeIntervalSince1970.description ?? "nil"
            let signature = "\(task.title)|\(dueDateStr)"
            if existingTasksBySignature[signature] == nil {
                existingTasksBySignature[signature] = task
            }
        }
        
        // Process tasks in batches
        let batchSize = 50
        for i in stride(from: 0, to: tasksToImport.count, by: batchSize) {
            let batch = Array(tasksToImport[i..<min(i + batchSize, tasksToImport.count)])
            
            for todoistTask in batch {
                // Check for existing task by external ID first (most reliable)
                if let existingTask = existingTasksByExternalId[todoistTask.id] {
                    // Update existing imported task
                    TodoistConverter.updateTask(existingTask, from: todoistTask)
                    updatedCount += 1
                    existingTasksByExternalId.removeValue(forKey: todoistTask.id)
                    continue
                }
                
                // Check for duplicate by content signature
                let dueDateStr = TodoistConverter.convertDueDate(todoistTask)?.timeIntervalSince1970.description ?? "nil"
                let taskSignature = "\(todoistTask.content)|\(dueDateStr)"
                if let duplicateTask = existingTasksBySignature[taskSignature] {
                    // Found a duplicate by content - update it to mark as imported
                    if duplicateTask.externalSource != "todoist" {
                        // It's a manually created task that matches a Todoist task
                        duplicateTask.externalReminderId = todoistTask.id
                        duplicateTask.externalSource = "todoist"
                        duplicateTask.lastSyncedAt = Date()
                        TodoistConverter.updateTask(duplicateTask, from: todoistTask)
                        updatedCount += 1
                        logger.debug("Linked manually created task to Todoist: \(todoistTask.id)")
                    } else {
                        // Already imported, skip
                        continue
                    }
                } else {
                    // Create new task
                    let newTask = TodoistConverter.convertTask(todoistTask, projectId: focusOSProjectId)
                    modelContext.insert(newTask)
                    importedCount += 1
                }
            }
            
            // Save batch
            do {
                try modelContext.save()
            } catch {
                errors.append(error)
                logger.error("Failed to save batch: \(error.localizedDescription)")
            }
        }
        
        // Delete tasks that no longer exist in Todoist
        for (externalId, task) in existingTasksByExternalId {
            // Verify task still doesn't exist
            if !tasksToImport.contains(where: { $0.id == externalId }) {
                modelContext.delete(task)
                deletedCount += 1
            }
        }
        
        if deletedCount > 0 {
            do {
                try modelContext.save()
            } catch {
                errors.append(error)
                logger.error("Failed to save deletions: \(error.localizedDescription)")
            }
        }
        
        logger.info("Tasks import complete for project \(projectId): \(importedCount) imported, \(updatedCount) updated, \(deletedCount) deleted")
        
        return TodoistImportResult(
            importedCount: importedCount,
            updatedCount: updatedCount,
            deletedCount: deletedCount,
            errors: errors
        )
    }
    
    func syncAllProjects(modelContext: ModelContext) async throws {
        guard !isSyncing else {
            logger.debug("Sync already in progress")
            return
        }
        
        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }
        
        do {
            // First, import/update projects
            let projectsResult = try await importProjects(modelContext: modelContext)
            logger.info("Projects sync: \(projectsResult.importedCount) imported, \(projectsResult.updatedCount) updated, \(projectsResult.deletedCount) deleted")
            
            // Then, import tasks for each project
            // Get all Todoist projects (to get their IDs)
            guard let accessToken = settings.accessToken else {
                throw TodoistImportError.notAuthenticated
            }
            
            let todoistProjects = try await todoistService.getProjects(accessToken: accessToken)
            let projectsToSync = settings.selectedProjectIds.isEmpty 
                ? todoistProjects.filter { !$0.isArchived }
                : todoistProjects.filter { settings.selectedProjectIds.contains($0.id) && !$0.isArchived }
            
            // Get FocusOS projects that match
            let existingProjectsDescriptor = FetchDescriptor<FocusOSShared.Project>(
                predicate: #Predicate<FocusOSShared.Project> { project in
                    project.externalSource == "todoist"
                }
            )
            let focusOSProjects = (try? modelContext.fetch(existingProjectsDescriptor)) ?? []
            
            var totalTasksImported = 0
            var totalTasksUpdated = 0
            var totalTasksDeleted = 0
            
            for todoistProject in projectsToSync {
                // Find matching FocusOS project
                if let focusOSProject = focusOSProjects.first(where: { $0.externalProjectId == todoistProject.id }) {
                    let tasksResult = try await importTasks(
                        projectId: todoistProject.id,
                        focusOSProjectId: focusOSProject.id,
                        modelContext: modelContext
                    )
                    totalTasksImported += tasksResult.importedCount
                    totalTasksUpdated += tasksResult.updatedCount
                    totalTasksDeleted += tasksResult.deletedCount
                }
            }
            
            settings.lastSyncDate = Date()
            
            logger.info("Full sync completed: Projects (\(projectsResult.importedCount + projectsResult.updatedCount)), Tasks (\(totalTasksImported + totalTasksUpdated))")
        } catch {
            lastSyncError = error
            logger.error("Sync failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Background Sync
    
    private func startBackgroundSync(modelContext: ModelContext) {
        syncTask?.cancel()
        
        syncTask = _Concurrency.Task { @MainActor in
            while true {
                do {
                    try await _Concurrency.Task.sleep(nanoseconds: UInt64(settings.syncInterval * 1_000_000_000))
                    
                    guard settings.importEnabled && settings.isConnected else { break }
                    
                    try await syncAllProjects(modelContext: modelContext)
                } catch is CancellationError {
                    break
                } catch {
                    logger.error("Background sync error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Token Management
    
    private func refreshAccessToken() async throws -> String {
        guard let refreshToken = settings.refreshToken else {
            throw TodoistImportError.notAuthenticated
        }
        
        let tokenResponse = try await todoistService.refreshToken(refreshToken)
        try settings.storeTokens(accessToken: tokenResponse.accessToken, refreshToken: tokenResponse.refreshToken)
        
        return tokenResponse.accessToken
    }
    
    // MARK: - Helpers
    
    func getAvailableProjects() async throws -> [TodoistProject] {
        guard let accessToken = settings.accessToken else {
            throw TodoistImportError.notAuthenticated
        }
        
        do {
            return try await todoistService.getProjects(accessToken: accessToken)
        } catch {
            if case TodoistAPIError.tokenExpired = error {
                // Try to refresh token
                let refreshed = try await refreshAccessToken()
                return try await todoistService.getProjects(accessToken: refreshed)
            } else {
                throw error
            }
        }
    }
}

// MARK: - Errors

enum TodoistImportError: LocalizedError {
    case notAuthenticated
    case noProjectsSelected
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Todoist. Please connect your account."
        case .noProjectsSelected:
            return "No projects are selected for import"
        case .apiError(let message):
            return "Todoist API error: \(message)"
        }
    }
}

