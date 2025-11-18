//
//  NotionImportService.swift
//  FocusOS
//
//  Main service for importing and syncing Notion data
//

import Foundation
import SwiftData
import Combine
import os.log
import FocusOSShared
import NotionSwift

struct NotionImportResult {
    let importedCount: Int
    let updatedCount: Int
    let deletedCount: Int
    let errors: [Error]
}

enum NotionImportError: Error {
    case notAuthenticated
    case noDatabasesSelected
    case databaseNotFound(String)
    case importFailed(Error)
}

@MainActor
final class NotionImportService: ObservableObject {
    static let shared = NotionImportService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "NotionImport")
    private let notionService = NotionService.shared
    private var cancellables = Set<AnyCancellable>()
    private var syncTask: _Concurrency.Task<Void, Never>?
    private var isRunning = false
    
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncError: Error?
    
    private let settings = NotionImportSettings.shared
    
    private init() {}
    
    // MARK: - Lifecycle
    
    func start(modelContext: ModelContext) async {
        guard settings.importEnabled else {
            logger.debug("Notion import disabled")
            return
        }
        
        guard settings.isConnected else {
            logger.debug("Notion not connected (no access token)")
            settings.importEnabled = false
            return
        }
        
        guard !isRunning else {
            logger.debug("NotionImportService already running")
            return
        }
        
        isRunning = true
        logger.info("Starting NotionImportService")
        
        // Initial sync
        do {
            try await syncAllDatabases(modelContext: modelContext)
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
        logger.info("Stopped NotionImportService")
    }
    
    // MARK: - Import & Sync
    
    func syncAllDatabases(modelContext: ModelContext) async throws {
        guard let accessToken = settings.accessToken else {
            throw NotionImportError.notAuthenticated
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        logger.info("Starting sync of all Notion databases")
        
        // First, cleanup invalid tasks that don't meet new strict criteria
        do {
            let deletedCount = try await cleanupInvalidTasks(modelContext: modelContext)
            if deletedCount > 0 {
                logger.info("Cleaned up \(deletedCount) invalid tasks during sync")
            }
        } catch {
            logger.warning("Cleanup failed during sync: \(error.localizedDescription)")
            // Continue with sync even if cleanup fails
        }
        
        // Fetch all databases
        let databases: [Database]
        do {
            databases = try await notionService.getDatabases(accessToken: accessToken)
        } catch {
            logger.error("Failed to fetch databases: \(error.localizedDescription)")
            throw NotionImportError.importFailed(error)
        }
        
        logger.info("Found \(databases.count) databases in Notion")
        
        // Filter by selected databases if any are selected
        let databasesToSync: [Database]
        if settings.selectedDatabaseIds.isEmpty {
            databasesToSync = databases
        } else {
            databasesToSync = databases.filter { database in
                settings.selectedDatabaseIds.contains(database.id.rawValue)
            }
        }
        
        // Sync each database
        var totalImported = 0
        var totalUpdated = 0
        var totalDeleted = 0
        var allErrors: [Error] = []
        
        for database in databasesToSync {
            do {
                let result = try await importDatabase(database, modelContext: modelContext)
                totalImported += result.importedCount
                totalUpdated += result.updatedCount
                totalDeleted += result.deletedCount
                allErrors.append(contentsOf: result.errors)
            } catch {
                logger.error("Failed to import database: \(error.localizedDescription)")
                allErrors.append(error)
            }
        }
        
        // Update last sync date
        settings.lastSyncDate = Date()
        
        logger.info("Sync completed: \(totalImported) imported, \(totalUpdated) updated, \(totalDeleted) deleted")
        
        if !allErrors.isEmpty {
            logger.error("Sync completed with \(allErrors.count) errors")
        }
    }
    
    func importDatabase(_ database: Database, modelContext: ModelContext) async throws -> NotionImportResult {
        guard let accessToken = settings.accessToken else {
            throw NotionImportError.notAuthenticated
        }
        
        var importedCount = 0
        var updatedCount = 0
        var deletedCount = 0
        var errors: [Error] = []
        
        let databaseId = database.id.rawValue
        
        // Fetch pages from database
        let pages: [Page]
        do {
            pages = try await notionService.getPages(databaseId: databaseId, accessToken: accessToken)
        } catch {
            logger.error("Failed to fetch pages from database: \(error.localizedDescription)")
            throw NotionImportError.importFailed(error)
        }
        
        logger.info("Found \(pages.count) pages in database")
        
        // Process each page
        for page in pages {
            do {
                // Determine page type
                let pageType = NotionConverter.determinePageType(page, database: database)
                
                // Convert based on type
                switch pageType {
                case .task:
                    let result = try await importTask(page, modelContext: modelContext)
                    if result.imported {
                        importedCount += 1
                    } else {
                        updatedCount += 1
                    }
                case .project:
                    let result = try await importProject(page, modelContext: modelContext)
                    if result.imported {
                        importedCount += 1
                    } else {
                        updatedCount += 1
                    }
                case .note:
                    let result = try await importNote(page, modelContext: modelContext)
                    if result.imported {
                        importedCount += 1
                    } else {
                        updatedCount += 1
                    }
                case .area:
                    let result = try await importArea(page, modelContext: modelContext)
                    if result.imported {
                        importedCount += 1
                    } else {
                        updatedCount += 1
                    }
                case .unknown:
                    // Default to note
                    let result = try await importNote(page, modelContext: modelContext)
                    if result.imported {
                        importedCount += 1
                    } else {
                        updatedCount += 1
                    }
                }
            } catch {
                logger.error("Failed to import page: \(error.localizedDescription)")
                errors.append(error)
            }
        }
        
        // Save changes
        if importedCount > 0 || updatedCount > 0 {
            do {
                try modelContext.save()
            } catch {
                errors.append(error)
                logger.error("Failed to save: \(error.localizedDescription)")
            }
        }
        
        return NotionImportResult(
            importedCount: importedCount,
            updatedCount: updatedCount,
            deletedCount: deletedCount,
            errors: errors
        )
    }
    
    // MARK: - Cleanup Methods
    
    /// Clean up existing Notion tasks that don't meet the new strict task criteria
    func cleanupInvalidTasks(modelContext: ModelContext) async throws -> Int {
        guard let accessToken = settings.accessToken else {
            throw NotionImportError.notAuthenticated
        }
        
        logger.info("Starting cleanup of invalid Notion tasks")
        
        // Fetch all tasks imported from Notion
        let allNotionTasksDescriptor = FetchDescriptor<FocusOSShared.Task>(
            predicate: #Predicate<FocusOSShared.Task> { task in
                task.externalSource == "notion" && task.externalReminderId != nil
            }
        )
        
        let allNotionTasks = try modelContext.fetch(allNotionTasksDescriptor)
        logger.info("Found \(allNotionTasks.count) Notion tasks to validate")
        
        var deletedCount = 0
        var errors: [Error] = []
        
        // For each task, fetch the corresponding Notion page and validate
        for task in allNotionTasks {
            guard let pageId = task.externalReminderId else { continue }
            
            do {
                // Fetch the page from Notion
                let page = try await notionService.getPage(pageId: pageId, accessToken: accessToken)
                
                // Re-determine the page type with new strict criteria
                let pageType = NotionConverter.determinePageType(page, database: nil)
                
                // If it's no longer a task, delete it
                if pageType != .task {
                    logger.info("Deleting task '\(task.title)' - Notion page is now type: \(pageType.description)")
                    modelContext.delete(task)
                    deletedCount += 1
                }
            } catch {
                // If page doesn't exist in Notion anymore, delete the task
                logger.warning("Page \(pageId) not found in Notion, deleting task '\(task.title)'")
                modelContext.delete(task)
                deletedCount += 1
            }
        }
        
        // Save changes
        if deletedCount > 0 {
            do {
                try modelContext.save()
                logger.info("Cleanup completed: deleted \(deletedCount) invalid tasks")
            } catch {
                errors.append(error)
                logger.error("Failed to save after cleanup: \(error.localizedDescription)")
            }
        } else {
            logger.info("Cleanup completed: no invalid tasks found")
        }
        
        if !errors.isEmpty {
            logger.error("Cleanup completed with \(errors.count) errors")
        }
        
        return deletedCount
    }
    
    // MARK: - Individual Import Methods
    
    private func importTask(_ page: Page, modelContext: ModelContext) async throws -> (imported: Bool, task: FocusOSShared.Task) {
        // Get page ID for duplicate checking
        let pageId = page.id.rawValue
        
        // Check for existing task
        let existingTasksDescriptor = FetchDescriptor<FocusOSShared.Task>(
            predicate: #Predicate<FocusOSShared.Task> { task in
                task.externalSource == "notion" && task.externalReminderId == pageId
            }
        )
        
        if let existingTask = try? modelContext.fetch(existingTasksDescriptor).first {
            // Update existing task
            NotionConverter.updateTask(existingTask, from: page)
            return (false, existingTask)
        }
        
        // Create new task
        let newTask = NotionConverter.convertToTask(page)
        modelContext.insert(newTask)
        return (true, newTask)
    }
    
    private func importProject(_ page: Page, modelContext: ModelContext) async throws -> (imported: Bool, project: FocusOSShared.Project) {
        // Get page ID for duplicate checking
        let pageId = page.id.rawValue
        
        // Check for existing project
        let existingProjectsDescriptor = FetchDescriptor<FocusOSShared.Project>(
            predicate: #Predicate<FocusOSShared.Project> { project in
                project.externalSource == "notion" && project.externalProjectId == pageId
            }
        )
        
        if let existingProject = try? modelContext.fetch(existingProjectsDescriptor).first {
            // Update existing project
            NotionConverter.updateProject(existingProject, from: page)
            return (false, existingProject)
        }
        
        // Create new project
        let newProject = NotionConverter.convertToProject(page)
        modelContext.insert(newProject)
        return (true, newProject)
    }
    
    private func importNote(_ page: Page, modelContext: ModelContext) async throws -> (imported: Bool, note: FocusOSShared.Note) {
        // Note model doesn't have external tracking fields yet
        // For now, always create new note (could be improved later)
        
        let newNote = NotionConverter.convertToNote(page)
        modelContext.insert(newNote)
        return (true, newNote)
    }
    
    private func importArea(_ page: Page, modelContext: ModelContext) async throws -> (imported: Bool, area: Area) {
        // Area model doesn't have external tracking fields
        // For now, always create new area (could be improved later)
        
        let newArea = NotionConverter.convertToArea(page)
        modelContext.insert(newArea)
        return (true, newArea)
    }
    
    // MARK: - Background Sync
    
    private func startBackgroundSync(modelContext: ModelContext) {
        syncTask?.cancel()
        
        syncTask = _Concurrency.Task { [weak self] in
            guard let self = self else { return }
            
            while true {
                do {
                    // Wait for sync interval
                    let interval = self.settings.syncInterval
                    if interval > 0 {
                        try await _Concurrency.Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                    } else {
                        // Manual sync only - wait indefinitely
                        try await _Concurrency.Task.sleep(nanoseconds: UInt64.max)
                    }
                    
                    // Check if still enabled
                    guard self.settings.importEnabled else {
                        break
                    }
                    
                    // Perform sync
                    try await self.syncAllDatabases(modelContext: modelContext)
                } catch is CancellationError {
                    break
                } catch {
                    self.logger.error("Background sync error: \(error.localizedDescription)")
                    // Continue syncing even on error
                }
            }
        }
    }
    
    // MARK: - Public Methods
    
    func getAvailableDatabases() async throws -> [Database] {
        guard let accessToken = settings.accessToken else {
            throw NotionImportError.notAuthenticated
        }
        
        return try await notionService.getDatabases(accessToken: accessToken)
    }
}

