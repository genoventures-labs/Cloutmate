//
//  CalendarEventOccurrenceService.swift
//  FocusOS
//
//  Created by Assistant on 11/12/25.
//

import Foundation
import SwiftData
import FocusOSShared

struct CalendarEventOccurrence: Identifiable, Hashable {
    let id: String
    let event: CalendarEvent
    let startDate: Date
    let endDate: Date
    
    init(event: CalendarEvent, startDate: Date, endDate: Date) {
        self.event = event
        self.startDate = startDate
        self.endDate = endDate
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.id = "\(event.id.uuidString)-\(isoFormatter.string(from: startDate))"
    }
}

final class CalendarEventOccurrenceService {
    static let shared = CalendarEventOccurrenceService()
    
    private let calendar: Calendar
    
    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }
    
    func occurrences(
        for events: [CalendarEvent],
        in range: DateInterval
    ) -> [CalendarEventOccurrence] {
        var all: [CalendarEventOccurrence] = []
        for event in events {
            all.append(contentsOf: occurrences(for: event, in: range))
        }
        return all.sorted { $0.startDate < $1.startDate }
    }
    
    func occurrences(
        for event: CalendarEvent,
        in range: DateInterval
    ) -> [CalendarEventOccurrence] {
        var results: [CalendarEventOccurrence] = []
        
        let baseDuration = max(event.endDate.timeIntervalSince(event.startDate), 60)
        
        if let recurrence = event.recurrence {
            var occurrenceStart = event.startDate
            let limitDate = recurrence.endDate ?? range.end.addingTimeInterval(60 * 60 * 24 * 365)
            
            while occurrenceStart <= range.end && occurrenceStart <= limitDate {
                let occurrenceEnd = occurrenceStart.addingTimeInterval(baseDuration)
                let occurrenceInterval = DateInterval(start: occurrenceStart, duration: baseDuration)
                if occurrenceInterval.intersects(range) {
                    results.append(CalendarEventOccurrence(event: event, startDate: occurrenceStart, endDate: occurrenceEnd))
                }
                
                guard let nextStart = nextOccurrenceStart(
                    after: occurrenceStart,
                    event: event,
                    recurrence: recurrence
                ) else {
                    break
                }
                occurrenceStart = nextStart
            }
        } else {
            let eventInterval = DateInterval(start: event.startDate, end: event.endDate)
            if eventInterval.intersects(range) {
                results.append(CalendarEventOccurrence(event: event, startDate: event.startDate, endDate: event.endDate))
            }
        }
        
        return results
    }
    
    private func nextOccurrenceStart(
        after current: Date,
        event: CalendarEvent,
        recurrence: EventRecurrence
    ) -> Date? {
        var components = DateComponents()
        switch recurrence.frequency {
        case .daily:
            components.day = recurrence.interval
            return calendar.date(byAdding: components, to: current)
        case .weekly:
            if let weekdays = recurrence.weekdays, !weekdays.isEmpty {
                guard var nextDate = calendar.date(byAdding: .day, value: 1, to: current) else {
                    return nil
                }
                let maxIterations = 366 * recurrence.interval
                for _ in 0..<maxIterations {
                    let weekday = calendar.component(.weekday, from: nextDate)
                    let weeksBetween = calendar.dateComponents([.weekOfYear], from: event.startDate, to: nextDate).weekOfYear ?? 0
                    if weekdays.contains(weekday) && weeksBetween % recurrence.interval == 0 {
                        return nextDate
                    }
                    guard let candidate = calendar.date(byAdding: .day, value: 1, to: nextDate) else {
                        break
                    }
                    nextDate = candidate
                }
                return nil
            } else {
                components.day = recurrence.interval * 7
                return calendar.date(byAdding: components, to: current)
            }
        case .monthly:
            components.month = recurrence.interval
            return calendar.date(byAdding: components, to: current)
        case .yearly:
            components.year = recurrence.interval
            return calendar.date(byAdding: components, to: current)
        }
    }
}

