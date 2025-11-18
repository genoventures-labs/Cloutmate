//
//  CalendarSuggestionEngine.swift
//  FocusOS
//
//  Aurora Calendar Cognition Layer - Auto-scheduling suggestions
//

import Foundation
import SwiftData
import os.log
import FocusOSShared

@MainActor
final class CalendarSuggestionEngine {
    static let shared = CalendarSuggestionEngine()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "CalendarSuggestionEngine")
    private let adaptiveScheduler = AdaptiveScheduler.shared
    
    private init() {}
    
    // MARK: - Optimal Time Suggestions
    
    func suggestOptimalTime(
        for task: FocusOSShared.Task,
        modelContext: ModelContext
    ) -> Date? {
        // Get energy forecast from CognitionPredictor
        // For now, use time-of-day heuristics
        
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        
        // Typical high-energy windows: 9-11am, 2-4pm
        let hour9 = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: todayStart) ?? now
        let hour11 = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: todayStart) ?? now
        let hour14 = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: todayStart) ?? now
        let hour16 = calendar.date(bySettingHour: 16, minute: 0, second: 0, of: todayStart) ?? now
        
        // Check availability in high-energy windows
        if let available = findAvailableSlot(start: hour9, end: hour11, modelContext: modelContext) {
            return available
        }
        
        if let available = findAvailableSlot(start: hour14, end: hour16, modelContext: modelContext) {
            return available
        }
        
        // Fallback: find any available slot today
        return findAvailableSlot(start: now, end: calendar.date(byAdding: .day, value: 1, to: todayStart) ?? now, modelContext: modelContext)
    }
    
    func recommendReschedule(
        _ event: CalendarEvent,
        modelContext: ModelContext
    ) -> Date? {
        // Check if event is negotiable
        let category = EventCategoryDetector.shared.categorizeEvent(event, modelContext: modelContext)
        guard category == .negotiable || category == .lightAdmin else {
            return nil // Not negotiable
        }
        
        // Find better time slot
        return suggestOptimalTime(for: event, modelContext: modelContext)
    }
    
    private func suggestOptimalTime(
        for event: CalendarEvent,
        modelContext: ModelContext
    ) -> Date? {
        let duration = event.endDate.timeIntervalSince(event.startDate)
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        
        // Try high-energy windows
        let hour9 = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: todayStart) ?? now
        let hour11 = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: todayStart) ?? now
        
        if let available = findAvailableSlot(
            start: hour9,
            end: hour11,
            duration: duration,
            modelContext: modelContext
        ) {
            return available
        }
        
        // Try afternoon window
        let hour14 = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: todayStart) ?? now
        let hour16 = calendar.date(bySettingHour: 16, minute: 0, second: 0, of: todayStart) ?? now
        
        return findAvailableSlot(
            start: hour14,
            end: hour16,
            duration: duration,
            modelContext: modelContext
        )
    }
    
    // MARK: - Availability Checking
    
    private func findAvailableSlot(
        start: Date,
        end: Date,
        duration: TimeInterval = 3600, // Default 1 hour
        modelContext: ModelContext
    ) -> Date? {
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { event in
                event.startDate >= start && event.startDate < end
            },
            sortBy: [SortDescriptor(\.startDate, order: .forward)]
        )
        
        guard let events = try? modelContext.fetch(descriptor) else {
            return start // No events, slot is available
        }
        
        var currentTime = start
        
        for event in events {
            if currentTime.addingTimeInterval(duration) <= event.startDate {
                return currentTime // Found gap
            }
            currentTime = max(currentTime, event.endDate)
        }
        
        // Check if there's time after last event
        if currentTime.addingTimeInterval(duration) <= end {
            return currentTime
        }
        
        return nil // No available slot
    }
    
    // MARK: - Conflict Resolution
    
    func resolveConflicts(
        for date: Date,
        modelContext: ModelContext
    ) -> [ConflictResolution] {
        let dayStart = Calendar.current.startOfDay(for: date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? date
        
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { event in
                event.startDate >= dayStart && event.startDate < dayEnd
            },
            sortBy: [SortDescriptor(\.startDate, order: .forward)]
        )
        
        guard let events = try? modelContext.fetch(descriptor) else {
            return []
        }
        
        var resolutions: [ConflictResolution] = []
        
        for i in 0..<events.count - 1 {
            let current = events[i]
            let next = events[i + 1]
            
            // Check for overlap
            if current.endDate > next.startDate {
                // Conflict detected
                let category = EventCategoryDetector.shared.categorizeEvent(next, modelContext: modelContext)
                
                if category == .negotiable || category == .lightAdmin {
                    // Suggest moving the negotiable event
                    if let newTime = recommendReschedule(next, modelContext: modelContext) {
                        resolutions.append(.reschedule(next.id, newTime))
                    }
                } else {
                    // Suggest buffer time
                    resolutions.append(.addBuffer(current.id, next.startDate.timeIntervalSince(current.endDate)))
                }
            }
        }
        
        return resolutions
    }
}

enum ConflictResolution {
    case reschedule(UUID, Date)
    case addBuffer(UUID, TimeInterval)
    case split(UUID)
}

