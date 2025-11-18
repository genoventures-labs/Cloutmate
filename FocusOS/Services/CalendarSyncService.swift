//
//  CalendarSyncService.swift
//  FocusOS
//
//  Phase 9B: Calendar synchronization for adaptive scheduling.
//

import Foundation
import EventKit
import SwiftData
import Combine
import os.log

@MainActor
final class CalendarSyncService: ObservableObject {
    static let shared = CalendarSyncService()

    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "CalendarSyncService")
    private(set) var eventStore: EKEventStore?
    private var cancellables = Set<AnyCancellable>()
    private var isRunning = false

    private init() {}

    // MARK: - Lifecycle

    func start(modelContext: ModelContext) async {
        guard CalendarSyncSettings.shared.syncEnabled else {
            logger.debug("Calendar sync disabled – service will not start")
            return
        }

        if isRunning {
            logger.debug("CalendarSyncService already running")
            return
        }

        logger.info("Starting CalendarSyncService")
        isRunning = true

        let store = EKEventStore()
        eventStore = store

        let authorized = await requestCalendarAccess(with: store)
        guard authorized else {
            logger.error("Calendar access not granted – disabling sync")
            CalendarSyncSettings.shared.syncEnabled = false
            isRunning = false
            return
        }

        observeFocusSessions(modelContext: modelContext)
        observeEventStoreChanges(modelContext: modelContext)
    }

    func stop() {
        guard isRunning else { return }
        cancellables.removeAll()
        eventStore = nil
        isRunning = false
        logger.info("CalendarSyncService stopped")
    }

    // MARK: - Permissions

    private func requestCalendarAccess(with store: EKEventStore) async -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized, .fullAccess:
            return true
        case .writeOnly:
            // write-only still acceptable, we only need to write and read by id
            return true
        case .notDetermined:
            do {
                return try await store.requestAccess(to: .event)
            } catch {
                logger.error("Calendar access request failed: \(error.localizedDescription, privacy: .public)")
                return false
            }
        case .restricted, .denied:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Session Sync

    func syncSessionToCalendar(_ session: FocusSession, modelContext: ModelContext) async {
        guard CalendarSyncSettings.shared.syncEnabled else { return }
        guard let store = eventStore else { return }
        guard let calendar = resolveCalendar(using: store) else {
            logger.error("Unable to resolve calendar for sync")
            return
        }

        let startDate = session.scheduledTime ?? session.startTime
        let endDate = startDate.addingTimeInterval(session.plannedDuration)

        let event: EKEvent
        if let identifier = session.calendarEventId,
           let existing = store.event(withIdentifier: identifier) {
            event = existing
            logger.debug("Updating existing calendar event for session \(session.id.uuidString, privacy: .public)")
        } else {
            event = EKEvent(eventStore: store)
            event.calendar = calendar
            logger.debug("Creating new calendar event for session \(session.id.uuidString, privacy: .public)")
        }

        event.title = "Focus: \(session.objective)"
        event.startDate = startDate
        event.endDate = endDate
        event.notes = "Scheduled by Aurora for deep work."

        do {
            try store.save(event, span: .thisEvent, commit: true)
            session.calendarEventId = event.eventIdentifier
            session.scheduledTime = startDate
            try modelContext.save()
            CalendarSyncSettings.shared.lastSyncDate = Date()
            logger.info("Focus session synced to calendar at \(startDate, privacy: .public)")
        } catch {
            logger.error("Failed to save calendar event: \(error.localizedDescription, privacy: .public)")
        }
    }

    func removeCalendarEvent(for session: FocusSession, modelContext: ModelContext) async {
        guard let identifier = session.calendarEventId else { return }
        guard let store = eventStore,
              let event = store.event(withIdentifier: identifier) else { return }

        do {
            try store.remove(event, span: .thisEvent, commit: true)
            session.calendarEventId = nil
            session.wasRescheduled = false
            try modelContext.save()
            CalendarSyncSettings.shared.lastSyncDate = Date()
            logger.info("Removed calendar event for session \(session.id.uuidString, privacy: .public)")
        } catch {
            logger.error("Failed to remove calendar event: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Observers

    private func observeFocusSessions(modelContext: ModelContext) {
        NotificationCenter.default
            .publisher(for: .focusSessionStatusChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self, let session = notification.object as? FocusSession else { return }
                switch session.status {
                case .active:
                    Task { @MainActor in
                        await self.syncSessionToCalendar(session, modelContext: modelContext)
                    }
                case .abandoned:
                    Task { @MainActor in
                        await self.syncSessionToCalendar(session, modelContext: modelContext)
                    }
                case .completed:
                    Task { @MainActor in
                        await self.removeCalendarEvent(for: session, modelContext: modelContext)
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func observeEventStoreChanges(modelContext: ModelContext) {
        NotificationCenter.default
            .publisher(for: .EKEventStoreChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    await self.handleExternalCalendarChanges(modelContext: modelContext)
                }
            }
            .store(in: &cancellables)
    }

    private func handleExternalCalendarChanges(modelContext: ModelContext) async {
        guard let store = eventStore else { return }
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate<FocusSession> { session in
                session.calendarEventId != nil && !session.completed
            }
        )

        guard let sessions = try? modelContext.fetch(descriptor) else { return }

        for session in sessions {
            guard let identifier = session.calendarEventId,
                  let event = store.event(withIdentifier: identifier) else { continue }

            let newStart = event.startDate
            if session.scheduledTime != newStart {
                logger.info("Detected external calendar move for session \(session.id.uuidString, privacy: .public)")
                session.scheduledTime = newStart
                session.wasRescheduled = true
                try? modelContext.save()
                if let newStart = newStart {
                    AdaptiveScheduler.shared.handleExternalCalendarUpdate(for: session, newStart: newStart, modelContext: modelContext)
                }
            }
        }
    }

    // MARK: - Helpers

    private func resolveCalendar(using store: EKEventStore) -> EKCalendar? {
        if let identifier = CalendarSyncSettings.shared.calendarIdentifier,
           let calendar = store.calendar(withIdentifier: identifier) {
            return calendar
        }

        if let defaultCalendar = store.defaultCalendarForNewEvents {
            CalendarSyncSettings.shared.calendarIdentifier = defaultCalendar.calendarIdentifier
            return defaultCalendar
        }

        let writableCalendars = store.calendars(for: .event).filter { $0.allowsContentModifications }
        if let calendar = writableCalendars.first {
            CalendarSyncSettings.shared.calendarIdentifier = calendar.calendarIdentifier
            return calendar
        }

        return nil
    }
}

// MARK: - Settings

@MainActor
final class CalendarSyncSettings: ObservableObject {
    static let shared = CalendarSyncSettings()

    private struct Keys {
        static let syncEnabled = "calendarSync.enabled"
        static let calendarIdentifier = "calendarSync.calendarIdentifier"
        static let lastSync = "calendarSync.lastSync"
    }

    var syncEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Keys.syncEnabled) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: Keys.syncEnabled) }
    }

    var calendarIdentifier: String? {
        get { UserDefaults.standard.string(forKey: Keys.calendarIdentifier) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.calendarIdentifier) }
    }

    var lastSyncDate: Date? {
        get { UserDefaults.standard.object(forKey: Keys.lastSync) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Keys.lastSync) }
    }
}


