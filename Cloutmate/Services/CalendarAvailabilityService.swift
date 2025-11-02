//
//  CalendarAvailabilityService.swift
//  Cloutmate
//
//  Computes free time windows based on tasks and scheduled posts
//

import Foundation
import SwiftData
import CloutmateShared

@MainActor
final class CalendarAvailabilityService {
    static let shared = CalendarAvailabilityService()
    
    func availableTimeSlots(
        modelContext: ModelContext,
        in range: DateInterval,
        workdayStartHour: Int = 9,
        workdayEndHour: Int = 17,
        slotMinutes: Int = 30
    ) async throws -> [GeminiService.TimeSlot] {
        let tasks = try modelContext.fetch(FetchDescriptor<Task>())
        let posts = try modelContext.fetch(FetchDescriptor<Post>())
        let cal = Calendar.current
        
        // Build busy intervals from tasks (dueDate as a point) and posts (scheduledDate)
        var busy: [DateInterval] = []
        for t in tasks {
            if let d = t.dueDate, range.contains(d) {
                let end = cal.date(byAdding: .minute, value: 30, to: d) ?? d
                busy.append(DateInterval(start: d, end: end))
            }
        }
        for p in posts {
            if let d = p.scheduledDate, range.contains(d) {
                let end = cal.date(byAdding: .minute, value: 30, to: d) ?? d
                busy.append(DateInterval(start: d, end: end))
            }
        }
        busy.sort { $0.start < $1.start }
        
        // Iterate each day in range within work hours
        var slots: [GeminiService.TimeSlot] = []
        var dayStart = range.start
        while dayStart <= range.end {
            var comps = cal.dateComponents([.year, .month, .day], from: dayStart)
            comps.hour = workdayStartHour; comps.minute = 0
            let workStart = cal.date(from: comps) ?? dayStart
            comps.hour = workdayEndHour; comps.minute = 0
            let workEnd = cal.date(from: comps) ?? dayStart
            
            var slotStart = max(workStart, range.start)
            while slotStart < min(workEnd, range.end) {
                let slotEnd = cal.date(byAdding: .minute, value: slotMinutes, to: slotStart) ?? slotStart
                let slotInterval = DateInterval(start: slotStart, end: slotEnd)
                // Check conflict
                let conflicts = busy.contains { $0.intersects(slotInterval) }
                if !conflicts && slotEnd <= workEnd && slotEnd <= range.end {
                    slots.append(GeminiService.TimeSlot(start: slotStart, end: slotEnd))
                }
                slotStart = slotEnd
            }
            guard let nextDay = cal.date(byAdding: .day, value: 1, to: dayStart) else { break }
            dayStart = nextDay
        }
        return slots
    }
}


