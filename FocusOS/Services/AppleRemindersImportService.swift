//
//  AppleRemindersImportService.swift
//  FocusOS
//
//  Main service for importing and syncing Apple Reminders
//

import Foundation
import EventKit
import SwiftData
import Combine
import os.log
import FocusOSShared

struct RemindersImportResult {
    let importedCount: Int
    let updatedCount: Int
    let deletedCount: Int
    let errors: [Error]
}

@MainActor
final class AppleRemindersImportService: ObservableObject {
    static let shared = AppleRemindersImportService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "AppleRemindersImport")
    private var eventStore: EKEventStore?
    private var cancellables = Set<AnyCancellable>()
    private var syncTask: _Concurrency.Task<Void, Never>?
    private var isRunning = false
    
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncError: Error?
    
    private let settings = AppleRemindersImportSettings.shared
    
    private init() {}
    
    // MARK: - Lifecycle
    
    func start(modelContext: ModelContext) async {
        guard settings.importEnabled else {
            logger.debug("Apple Reminders import disabled")
            return
        }
        
        guard !isRunning else {
            logger.debug("AppleRemindersImportService already running")
            return
        }
        
        isRunning = true
        logger.info("Starting AppleRemindersImportService")
        
        let store = EKEventStore()
        eventStore = store
        
        let authorized = await requestAccess(with: store)
        guard authorized else {
            logger.error("Reminders access not granted")
            settings.importEnabled = false
            isRunning = false
            return
        }
        
        // Initial sync
        do {
            try await syncAllReminderLists(modelContext: modelContext)
        } catch {
            logger.error("Initial sync failed: \(error.localizedDescription)")
        }
        
        // Observe reminder changes
        observeReminderChanges(modelContext: modelContext)
        
        // Start background sync scheduler
        startBackgroundSync(modelContext: modelContext)
    }
    
    func stop() {
        syncTask?.cancel()
        syncTask = nil
        cancellables.removeAll()
        eventStore = nil
        isRunning = false
        logger.info("Stopped AppleRemindersImportService")
    }
    
    // MARK: - Permissions
    
    func checkPermissionStatus() async -> EKAuthorizationStatus {
        return EKEventStore.authorizationStatus(for: .reminder)
    }
    
    func requestAccess() async -> Bool {
        guard let store = eventStore else {
            let store = EKEventStore()
            eventStore = store
            return await requestAccess(with: store)
        }
        return await requestAccess(with: store)
    }
    
    private func requestAccess(with store: EKEventStore) async -> Bool {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .authorized, .fullAccess:
            return true
        case .notDetermined:
            do {
                return try await store.requestAccess(to: .reminder)
            } catch {
                logger.error("Reminders access request failed: \(error.localizedDescription, privacy: .public)")
                return false
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
    
    // MARK: - Import & Sync
    
    func importReminders(from startDate: Date, to endDate: Date, modelContext: ModelContext) async throws -> RemindersImportResult {
        guard let store = eventStore else {
            throw RemindersImportError.eventStoreNotAvailable
        }
        
        let reminderLists = getSelectedReminderLists(from: store)
        guard !reminderLists.isEmpty else {
            throw RemindersImportError.noReminderListsSelected
        }
        
        var importedCount = 0
        var updatedCount = 0
        var deletedCount = 0
        var errors: [Error] = []
        
        // Fetch reminders from all selected lists
        let predicate = store.predicateForReminders(in: reminderLists)
        let allReminders = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[EKReminder], Error>) in
            store.fetchReminders(matching: predicate) { reminders in
                if let reminders = reminders {
                    continuation.resume(returning: reminders)
                } else {
                    continuation.resume(returning: [])
                }
            }
        }
        
        // Filter reminders by date range and completion status
        let ekReminders = allReminders.filter { reminder in
            // Filter by date range if reminder has due date
            if let dueDate = convertDueDate(reminder) {
                return dueDate >= startDate && dueDate <= endDate
            }
            // If no due date, include if not completed (or if we're importing completed)
            if reminder.isCompleted {
                return settings.importCompletedReminders
            }
            // Include incomplete reminders without due dates
            return true
        }
        
        logger.info("Found \(ekReminders.count) reminders in date range")
        
        // Get ALL existing Tasks with external source to check for duplicates
        let existingTasksDescriptor = FetchDescriptor<FocusOSShared.Task>(
            predicate: #Predicate<FocusOSShared.Task> { task in
                task.externalSource == "apple_reminders"
            }
        )
        let existingTasks = (try? modelContext.fetch(existingTasksDescriptor)) ?? []
        
        // Build lookup dictionaries for efficient duplicate checking
        var existingTasksByExternalId: [String: FocusOSShared.Task] = [:]
        var existingTasksBySignature: [String: FocusOSShared.Task] = [:] // For detecting duplicates by content
        
        for task in existingTasks {
            // Index by external ID if it's an imported task
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
        
        // Process reminders in batches
        let batchSize = 50
        for i in stride(from: 0, to: ekReminders.count, by: batchSize) {
            let batch = Array(ekReminders[i..<min(i + batchSize, ekReminders.count)])
            
            for ekReminder in batch {
                let reminderId = ekReminder.calendarItemIdentifier
                let listId = ekReminder.calendar.calendarIdentifier
                
                // Check for existing task by external ID first (most reliable)
                if let existingTask = existingTasksByExternalId[reminderId] {
                    // Update existing imported task
                    AppleRemindersEventConverter.update(existingTask, from: ekReminder)
                    updatedCount += 1
                    existingTasksByExternalId.removeValue(forKey: reminderId)
                    continue
                }
                
                // Check for duplicate by content signature (title + dueDate)
                let dueDateStr = convertDueDate(ekReminder)?.timeIntervalSince1970.description ?? "nil"
                let reminderSignature = "\(ekReminder.title ?? "Untitled Reminder")|\(dueDateStr)"
                if let duplicateTask = existingTasksBySignature[reminderSignature] {
                    // Found a duplicate by content - update it to mark as imported
                    if duplicateTask.externalSource != "apple_reminders" {
                        // It's a manually created task that matches an Apple Reminder
                        duplicateTask.externalReminderId = reminderId
                        duplicateTask.externalReminderListId = listId
                        duplicateTask.externalSource = "apple_reminders"
                        duplicateTask.lastSyncedAt = Date()
                        AppleRemindersEventConverter.update(duplicateTask, from: ekReminder)
                        updatedCount += 1
                        logger.debug("Linked manually created task to Apple Reminder: \(reminderId)")
                    } else {
                        // Already imported, skip
                        continue
                    }
                } else {
                    // Create new task
                    let newTask = AppleRemindersEventConverter.convert(ekReminder, listId: listId)
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
        
        // Delete tasks that no longer exist in Apple Reminders
        for (externalId, task) in existingTasksByExternalId {
            // Verify reminder still doesn't exist
            if store.calendarItem(withIdentifier: externalId) == nil {
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
        
        logger.info("Import complete: \(importedCount) imported, \(updatedCount) updated, \(deletedCount) deleted")
        
        return RemindersImportResult(
            importedCount: importedCount,
            updatedCount: updatedCount,
            deletedCount: deletedCount,
            errors: errors
        )
    }
    
    func syncAllReminderLists(modelContext: ModelContext) async throws {
        guard !isSyncing else {
            logger.debug("Sync already in progress")
            return
        }
        
        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }
        
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now // Always check 30 days back
        let endDate = Calendar.current.date(byAdding: .day, value: settings.importRangeDaysForward, to: now) ?? now
        
        do {
            let result = try await importReminders(from: startDate, to: endDate, modelContext: modelContext)
            settings.lastSyncDate = Date()
            
            logger.info("Sync completed: \(result.importedCount) imported, \(result.updatedCount) updated, \(result.deletedCount) deleted")
        } catch {
            lastSyncError = error
            logger.error("Sync failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Change Detection
    
    private func observeReminderChanges(modelContext: ModelContext) {
        NotificationCenter.default
            .publisher(for: .EKEventStoreChanged)
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.settings.importEnabled else { return }
                _Concurrency.Task { @MainActor in
                    do {
                        try await self.syncAllReminderLists(modelContext: modelContext)
                    } catch {
                        self.logger.error("Change detection sync failed: \(error.localizedDescription)")
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Background Sync
    
    private func startBackgroundSync(modelContext: ModelContext) {
        syncTask?.cancel()
        
        syncTask = _Concurrency.Task { @MainActor in
            while true {
                do {
                    try await _Concurrency.Task.sleep(nanoseconds: UInt64(settings.syncInterval * 1_000_000_000))
                    
                    guard settings.importEnabled else { break }
                    
                    try await syncAllReminderLists(modelContext: modelContext)
                } catch is CancellationError {
                    break
                } catch {
                    logger.error("Background sync error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func convertDueDate(_ reminder: EKReminder) -> Date? {
        guard let dueDateComponents = reminder.dueDateComponents else {
            return nil
        }
        return Calendar.current.date(from: dueDateComponents)
    }
    
    private func getSelectedReminderLists(from store: EKEventStore) -> [EKCalendar] {
        let allReminderLists = store.calendars(for: .reminder)
        
        let selectedIds = settings.selectedReminderListIds
        if selectedIds.isEmpty {
            // If no lists selected, use all readable lists
            return allReminderLists
        }
        
        return allReminderLists.filter { selectedIds.contains($0.calendarIdentifier) }
    }
    
    func getAvailableReminderLists() -> [EKCalendar] {
        guard let store = eventStore else {
            let store = EKEventStore()
            eventStore = store
            return store.calendars(for: .reminder)
        }
        return store.calendars(for: .reminder)
    }
}

// MARK: - Errors

enum RemindersImportError: LocalizedError {
    case eventStoreNotAvailable
    case noReminderListsSelected
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .eventStoreNotAvailable:
            return "Event store is not available"
        case .noReminderListsSelected:
            return "No reminder lists are selected for import"
        case .permissionDenied:
            return "Reminders access permission denied"
        }
    }
}

