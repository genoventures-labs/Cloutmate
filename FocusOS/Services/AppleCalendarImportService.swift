//
//  AppleCalendarImportService.swift
//  FocusOS
//
//  Main service for importing and syncing Apple Calendar events
//

import Foundation
import EventKit
import SwiftData
import Combine
import os.log
import FocusOSShared

struct ImportResult {
    let importedCount: Int
    let updatedCount: Int
    let deletedCount: Int
    let errors: [Error]
}

@MainActor
final class AppleCalendarImportService: ObservableObject {
    static let shared = AppleCalendarImportService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "AppleCalendarImport")
    private var eventStore: EKEventStore?
    private var cancellables = Set<AnyCancellable>()
    private var syncTask: _Concurrency.Task<Void, Never>?
    private var isRunning = false
    
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncError: Error?
    
    private let settings = AppleCalendarImportSettings.shared
    
    private init() {}
    
    // MARK: - Lifecycle
    
    func start(modelContext: ModelContext) async {
        guard settings.importEnabled else {
            logger.debug("Apple Calendar import disabled")
            return
        }
        
        guard !isRunning else {
            logger.debug("AppleCalendarImportService already running")
            return
        }
        
        isRunning = true
        logger.info("Starting AppleCalendarImportService")
        
        let store = EKEventStore()
        eventStore = store
        
        let authorized = await requestAccess(with: store)
        guard authorized else {
            logger.error("Calendar access not granted")
            settings.importEnabled = false
            isRunning = false
            return
        }
        
        // Initial sync
        do {
            try await syncAllCalendars(modelContext: modelContext)
        } catch {
            logger.error("Initial sync failed: \(error.localizedDescription)")
        }
        
        // Observe calendar changes
        observeCalendarChanges(modelContext: modelContext)
        
        // Start background sync scheduler
        startBackgroundSync(modelContext: modelContext)
    }
    
    func stop() {
        syncTask?.cancel()
        syncTask = nil
        cancellables.removeAll()
        eventStore = nil
        isRunning = false
        logger.info("Stopped AppleCalendarImportService")
    }
    
    // MARK: - Permissions
    
    func checkPermissionStatus() async -> EKAuthorizationStatus {
        return EKEventStore.authorizationStatus(for: .event)
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
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized, .fullAccess:
            return true
        case .notDetermined:
            do {
                return try await store.requestAccess(to: .event)
            } catch {
                logger.error("Calendar access request failed: \(error.localizedDescription, privacy: .public)")
                return false
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
    
    // MARK: - Import & Sync
    
    func importEvents(from startDate: Date, to endDate: Date, modelContext: ModelContext) async throws -> ImportResult {
        guard let store = eventStore else {
            throw ImportError.eventStoreNotAvailable
        }
        
        let calendars = getSelectedCalendars(from: store)
        guard !calendars.isEmpty else {
            throw ImportError.noCalendarsSelected
        }
        
        var importedCount = 0
        var updatedCount = 0
        var deletedCount = 0
        var errors: [Error] = []
        
        // Fetch events from all selected calendars
        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        let ekEvents = store.events(matching: predicate)
        
        logger.info("Found \(ekEvents.count) events in date range")
        
        // Get ALL existing CalendarEvents in the date range to check for duplicates
        let existingEventsDescriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate<CalendarEvent> { event in
                event.startDate >= startDate && event.startDate <= endDate
            }
        )
        let existingEvents = (try? modelContext.fetch(existingEventsDescriptor)) ?? []
        
        // Build lookup dictionaries for efficient duplicate checking
        var existingEventsByExternalId: [String: CalendarEvent] = [:]
        var existingEventsBySignature: [String: CalendarEvent] = [:] // For detecting duplicates by content
        
        for event in existingEvents {
            // Index by external ID if it's an imported event
            if let externalId = event.externalEventId {
                existingEventsByExternalId[externalId] = event
            }
            
            // Also index by signature (title + startDate + endDate) to catch duplicates
            // even if one was manually created and one imported
            let signature = "\(event.title)|\(event.startDate.timeIntervalSince1970)|\(event.endDate.timeIntervalSince1970)"
            if existingEventsBySignature[signature] == nil {
                existingEventsBySignature[signature] = event
            }
        }
        
        // Process events in batches
        let batchSize = 50
        for i in stride(from: 0, to: ekEvents.count, by: batchSize) {
            let batch = Array(ekEvents[i..<min(i + batchSize, ekEvents.count)])
            
            for ekEvent in batch {
                guard let eventId = ekEvent.eventIdentifier else {
                    continue
                }
                let calendarId = ekEvent.calendar.calendarIdentifier
                
                // Check for existing event by external ID first (most reliable)
                if let existingEvent = existingEventsByExternalId[eventId] {
                    // Update existing imported event
                    AppleCalendarEventConverter.update(existingEvent, from: ekEvent)
                    updatedCount += 1
                    existingEventsByExternalId.removeValue(forKey: eventId)
                    continue
                }
                
                // Check for duplicate by content signature (title + dates)
                // This catches cases where an event was manually created and also exists in Apple Calendar
                let eventSignature = "\(ekEvent.title ?? "Untitled Event")|\(ekEvent.startDate.timeIntervalSince1970)|\(ekEvent.endDate.timeIntervalSince1970)"
                if let duplicateEvent = existingEventsBySignature[eventSignature] {
                    // Found a duplicate by content - update it to mark as imported
                    // Only update if it's not already an imported event (to avoid overwriting manual events unnecessarily)
                    if duplicateEvent.externalSource != "apple_calendar" {
                        // It's a manually created event that matches an Apple Calendar event
                        // Update it to link to the external source
                        duplicateEvent.externalEventId = eventId
                        duplicateEvent.externalCalendarId = calendarId
                        duplicateEvent.externalSource = "apple_calendar"
                        duplicateEvent.lastSyncedAt = Date()
                        AppleCalendarEventConverter.update(duplicateEvent, from: ekEvent)
                        updatedCount += 1
                        logger.debug("Linked manually created event to Apple Calendar: \(eventId)")
                    } else {
                        // Already imported, skip
                        continue
                    }
                } else {
                    // Create new event
                    let newEvent = AppleCalendarEventConverter.convert(ekEvent, calendarId: calendarId)
                    modelContext.insert(newEvent)
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
        
        // Delete events that no longer exist in Apple Calendar
        for (externalId, event) in existingEventsByExternalId {
            // Verify event still doesn't exist
            if store.event(withIdentifier: externalId) == nil {
                modelContext.delete(event)
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
        
        return ImportResult(
            importedCount: importedCount,
            updatedCount: updatedCount,
            deletedCount: deletedCount,
            errors: errors
        )
    }
    
    func syncAllCalendars(modelContext: ModelContext) async throws {
        guard !isSyncing else {
            logger.debug("Sync already in progress")
            return
        }
        
        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }
        
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -settings.importRangeDaysBack, to: now) ?? now
        let endDate = Calendar.current.date(byAdding: .day, value: settings.importRangeDaysForward, to: now) ?? now
        
        do {
            let result = try await importEvents(from: startDate, to: endDate, modelContext: modelContext)
            settings.lastSyncDate = Date()
            
            // Trigger Aurora colorization if enabled
            if settings.autoColorize {
                await AuroraCalendarCognitionService.shared.analyzeAndColorizeEvents(modelContext: modelContext)
            }
            
            logger.info("Sync completed: \(result.importedCount) imported, \(result.updatedCount) updated, \(result.deletedCount) deleted")
        } catch {
            lastSyncError = error
            logger.error("Sync failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Change Detection
    
    private func observeCalendarChanges(modelContext: ModelContext) {
        NotificationCenter.default
            .publisher(for: .EKEventStoreChanged)
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.settings.importEnabled else { return }
                _Concurrency.Task { @MainActor in
                    do {
                        try await self.syncAllCalendars(modelContext: modelContext)
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
                    
                    try await syncAllCalendars(modelContext: modelContext)
                } catch is CancellationError {
                    break
                } catch {
                    logger.error("Background sync error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func getSelectedCalendars(from store: EKEventStore) -> [EKCalendar] {
        let allCalendars = store.calendars(for: .event)
        
        let selectedIds = settings.selectedCalendarIds
        if selectedIds.isEmpty {
            // If no calendars selected, use all readable calendars
            return allCalendars.filter { $0.allowsContentModifications || true } // Read-only is fine for import
        }
        
        return allCalendars.filter { selectedIds.contains($0.calendarIdentifier) }
    }
    
    func getAvailableCalendars() -> [EKCalendar] {
        guard let store = eventStore else {
            let store = EKEventStore()
            eventStore = store
            return store.calendars(for: .event)
        }
        return store.calendars(for: .event)
    }
}

// MARK: - Errors

enum ImportError: LocalizedError {
    case eventStoreNotAvailable
    case noCalendarsSelected
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .eventStoreNotAvailable:
            return "Event store is not available"
        case .noCalendarsSelected:
            return "No calendars are selected for import"
        case .permissionDenied:
            return "Calendar access permission denied"
        }
    }
}

