//
//  MondayImportService.swift
//  FocusOS
//
//  Main service for importing and syncing Monday.com data
//

import Foundation
import SwiftData
import Combine
import os.log
import FocusOSShared

struct MondayImportResult {
    let importedCount: Int
    let updatedCount: Int
    let deletedCount: Int
    let errors: [Error]
}

enum MondayImportError: Error {
    case notAuthenticated
    case noBoardsSelected
    case boardNotFound(String)
    case importFailed(Error)
}

@MainActor
final class MondayImportService: ObservableObject {
    static let shared = MondayImportService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "MondayImport")
    private let mondayService = MondayService.shared
    private var cancellables = Set<AnyCancellable>()
    private var syncTask: _Concurrency.Task<Void, Never>?
    private var isRunning = false
    
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncError: Error?
    
    private let settings = MondayImportSettings.shared
    
    private init() {}
    
    // MARK: - Lifecycle
    
    func start(modelContext: ModelContext) async {
        guard settings.importEnabled else {
            logger.debug("Monday.com import disabled")
            return
        }
        
        guard settings.isConnected else {
            logger.debug("Monday.com not connected (no access token)")
            settings.importEnabled = false
            return
        }
        
        guard !isRunning else {
            logger.debug("MondayImportService already running")
            return
        }
        
        isRunning = true
        logger.info("Starting MondayImportService")
        
        // Initial sync
        do {
            try await syncAllBoards(modelContext: modelContext)
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
        logger.info("Stopped MondayImportService")
    }
    
    // MARK: - Import & Sync
    
    func syncAllBoards(modelContext: ModelContext) async throws {
        guard let accessToken = settings.accessToken else {
            throw MondayImportError.notAuthenticated
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        logger.info("Starting sync of all Monday.com boards")
        
        // Fetch all boards
        let boards: [MondayBoard]
        do {
            boards = try await mondayService.getBoards(accessToken: accessToken)
        } catch {
            logger.error("Failed to fetch boards: \(error.localizedDescription)")
            throw MondayImportError.importFailed(error)
        }
        
        logger.info("Found \(boards.count) boards in Monday.com")
        
        // Filter by selected boards if any are selected
        let boardsToSync: [MondayBoard]
        if settings.selectedBoardIds.isEmpty {
            boardsToSync = boards
        } else {
            boardsToSync = boards.filter { board in
                settings.selectedBoardIds.contains(board.id)
            }
        }
        
        // Sync each board
        var totalImported = 0
        var totalUpdated = 0
        var totalDeleted = 0
        var allErrors: [Error] = []
        
        for board in boardsToSync {
            do {
                let result = try await importBoard(board, modelContext: modelContext)
                totalImported += result.importedCount
                totalUpdated += result.updatedCount
                totalDeleted += result.deletedCount
                allErrors.append(contentsOf: result.errors)
            } catch {
                logger.error("Failed to import board: \(error.localizedDescription)")
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
    
    func importBoard(_ board: MondayBoard, modelContext: ModelContext) async throws -> MondayImportResult {
        guard let accessToken = settings.accessToken else {
            throw MondayImportError.notAuthenticated
        }
        
        var importedCount = 0
        var updatedCount = 0
        var deletedCount = 0
        var errors: [Error] = []
        
        let boardId = board.id
        
        // Import board as Project
        do {
            let (imported, _) = try await importBoardAsProject(board, modelContext: modelContext)
            if imported {
                importedCount += 1
            } else {
                updatedCount += 1
            }
        } catch {
            logger.error("Failed to import board as project: \(error.localizedDescription)")
            errors.append(error)
        }
        
        // Import board items as Tasks
        do {
            let result = try await importBoardItems(boardId: boardId, modelContext: modelContext)
            importedCount += result.importedCount
            updatedCount += result.updatedCount
            deletedCount += result.deletedCount
            errors.append(contentsOf: result.errors)
        } catch {
            logger.error("Failed to import board items: \(error.localizedDescription)")
            errors.append(error)
        }
        
        return MondayImportResult(
            importedCount: importedCount,
            updatedCount: updatedCount,
            deletedCount: deletedCount,
            errors: errors
        )
    }
    
    func importBoardAsProject(_ board: MondayBoard, modelContext: ModelContext) async throws -> (imported: Bool, project: FocusOSShared.Project) {
        // Get board ID for duplicate checking
        let boardId = board.id
        
        // Check for existing project
        let existingProjectsDescriptor = FetchDescriptor<FocusOSShared.Project>(
            predicate: #Predicate<FocusOSShared.Project> { project in
                project.externalSource == "monday" && project.externalProjectId == boardId
            }
        )
        
        if let existingProject = try? modelContext.fetch(existingProjectsDescriptor).first {
            // Update existing project
            MondayConverter.updateProject(existingProject, from: board)
            return (false, existingProject)
        }
        
        // Create new project
        let newProject = MondayConverter.convertToProject(board)
        modelContext.insert(newProject)
        return (true, newProject)
    }
    
    func importBoardItems(boardId: String, modelContext: ModelContext) async throws -> MondayImportResult {
        guard let accessToken = settings.accessToken else {
            throw MondayImportError.notAuthenticated
        }
        
        var importedCount = 0
        var updatedCount = 0
        var deletedCount = 0
        var errors: [Error] = []
        
        // Fetch items from board
        let items: [MondayItem]
        do {
            items = try await mondayService.getBoardItems(boardId: boardId, accessToken: accessToken)
        } catch {
            logger.error("Failed to fetch items from board: \(error.localizedDescription)")
            throw MondayImportError.importFailed(error)
        }
        
        logger.info("Found \(items.count) items in board")
        
        // Filter completed items if needed
        let itemsToImport: [MondayItem]
        if settings.importCompletedItems {
            itemsToImport = items
        } else {
            itemsToImport = items.filter { item in
                item.state != "done" && MondayConverter.extractStatus(item.columnValues) != .done
            }
        }
        
        // Get existing tasks for this board
        let existingTasksDescriptor = FetchDescriptor<FocusOSShared.Task>(
            predicate: #Predicate<FocusOSShared.Task> { task in
                task.externalSource == "monday" && task.externalReminderListId == boardId
            }
        )
        let existingTasks = (try? modelContext.fetch(existingTasksDescriptor)) ?? []
        
        // Build lookup dictionary for efficient duplicate checking
        var existingTasksByExternalId: [String: FocusOSShared.Task] = [:]
        for task in existingTasks {
            if let externalId = task.externalReminderId {
                existingTasksByExternalId[externalId] = task
            }
        }
        
        // Process items
        for item in itemsToImport {
            if let existingTask = existingTasksByExternalId[item.id] {
                // Update existing task
                MondayConverter.updateTask(existingTask, from: item, boardId: boardId)
                updatedCount += 1
                existingTasksByExternalId.removeValue(forKey: item.id)
            } else {
                // Create new task
                let newTask = MondayConverter.convertToTask(item, boardId: boardId)
                modelContext.insert(newTask)
                importedCount += 1
            }
        }
        
        // Delete tasks that no longer exist in Monday.com
        for (externalId, task) in existingTasksByExternalId {
            // Verify task still doesn't exist
            if !itemsToImport.contains(where: { $0.id == externalId }) {
                modelContext.delete(task)
                deletedCount += 1
            }
        }
        
        // Save changes
        if importedCount > 0 || updatedCount > 0 || deletedCount > 0 {
            do {
                try modelContext.save()
            } catch {
                errors.append(error)
                logger.error("Failed to save: \(error.localizedDescription)")
            }
        }
        
        return MondayImportResult(
            importedCount: importedCount,
            updatedCount: updatedCount,
            deletedCount: deletedCount,
            errors: errors
        )
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
                    try await self.syncAllBoards(modelContext: modelContext)
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
    
    func getAvailableBoards() async throws -> [MondayBoard] {
        guard let accessToken = settings.accessToken else {
            throw MondayImportError.notAuthenticated
        }
        
        return try await mondayService.getBoards(accessToken: accessToken)
    }
}

