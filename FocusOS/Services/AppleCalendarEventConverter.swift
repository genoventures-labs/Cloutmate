//
//  AppleCalendarEventConverter.swift
//  FocusOS
//
//  Converts EKEvent properties to CalendarEvent models
//

import Foundation
import EventKit
import FocusOSShared

struct AppleCalendarEventConverter {
    
    /// Convert an EKEvent to a CalendarEvent
    static func convert(_ ekEvent: EKEvent, calendarId: String) -> CalendarEvent {
        let event = CalendarEvent(
            title: ekEvent.title ?? "Untitled Event",
            notes: ekEvent.notes,
            location: ekEvent.location,
            startDate: ekEvent.startDate,
            endDate: ekEvent.endDate,
            allDay: ekEvent.isAllDay,
            recurrence: convertRecurrence(ekEvent.recurrenceRules),
            remindMinutesBefore: extractReminderMinutes(ekEvent.alarms),
            colorHex: nil, // Will be set by AuroraCalendarCognitionService
            auroraGenerated: false
        )
        
        // Set external tracking fields
        event.externalEventId = ekEvent.eventIdentifier
        event.externalCalendarId = calendarId
        event.externalSource = "apple_calendar"
        event.lastSyncedAt = Date()
        
        return event
    }
    
    /// Convert EKRecurrenceRule array to EventRecurrence
    static func convertRecurrence(_ rules: [EKRecurrenceRule]?) -> EventRecurrence? {
        guard let rule = rules?.first else { return nil }
        
        let frequency: EventRecurrenceFrequency
        switch rule.frequency {
        case .daily:
            frequency = .daily
        case .weekly:
            frequency = .weekly
        case .monthly:
            frequency = .monthly
        case .yearly:
            frequency = .yearly
        @unknown default:
            return nil
        }
        
        let interval = rule.interval
        let endDate = rule.recurrenceEnd?.endDate
        
        // Convert days of the week
        var weekdays: [Int]?
        if let daysOfWeek = rule.daysOfTheWeek, !daysOfWeek.isEmpty {
            weekdays = daysOfWeek.map { dayOfWeek in
                // EKRecurrenceDayOfWeek uses 1=Sunday, 2=Monday, etc.
                // Our EventRecurrence uses same format
                return dayOfWeek.dayOfTheWeek.rawValue
            }
        }
        
        return EventRecurrence(
            frequency: frequency,
            interval: interval,
            endDate: endDate,
            weekdays: weekdays
        )
    }
    
    /// Extract reminder minutes from EKAlarm array
    static func extractReminderMinutes(_ alarms: [EKAlarm]?) -> Int? {
        guard let alarm = alarms?.first else { return nil }
        
        // EKAlarm has relativeOffset in seconds (negative for before event)
        // We need to convert to minutes before
        let offsetSeconds = alarm.relativeOffset
        if offsetSeconds < 0 {
            // Negative means before event, convert to positive minutes
            return abs(Int(offsetSeconds / 60))
        } else if offsetSeconds == 0 {
            // At event time
            return 0
        } else {
            // After event (unusual but possible)
            return nil
        }
    }
    
    /// Update an existing CalendarEvent with data from EKEvent
    static func update(_ event: CalendarEvent, from ekEvent: EKEvent) {
        event.title = ekEvent.title ?? "Untitled Event"
        event.notes = ekEvent.notes
        event.location = ekEvent.location
        event.startDate = ekEvent.startDate
        event.endDate = ekEvent.endDate
        event.allDay = ekEvent.isAllDay
        event.recurrence = convertRecurrence(ekEvent.recurrenceRules)
        event.remindMinutesBefore = extractReminderMinutes(ekEvent.alarms)
        event.lastSyncedAt = Date()
        event.touch()
    }
}

