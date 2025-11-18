//
//  EventCategoryDetector.swift
//  FocusOS
//
//  Aurora Calendar Cognition Layer - Event categorization
//

import Foundation
import SwiftData
import os.log
import FocusOSShared

enum EventCategory: String, CaseIterable {
    case deepWork
    case lightAdmin
    case personal
    case highUrgency
    case negotiable
    case nonNegotiable
    case blocker
    case independent
    
    var displayName: String {
        switch self {
        case .deepWork: return "Deep Work"
        case .lightAdmin: return "Light Admin"
        case .personal: return "Personal"
        case .highUrgency: return "High Urgency"
        case .negotiable: return "Negotiable"
        case .nonNegotiable: return "Non-Negotiable"
        case .blocker: return "Blocker"
        case .independent: return "Independent"
        }
    }
}

@MainActor
final class EventCategoryDetector {
    static let shared = EventCategoryDetector()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "EventCategoryDetector")
    
    private init() {}
    
    func categorizeEvent(_ event: CalendarEvent, modelContext: ModelContext) -> EventCategory {
        // Check for high urgency first
        if isHighUrgency(event: event, modelContext: modelContext) {
            return .highUrgency
        }
        
        // Check for deep work
        if isDeepWork(event: event, modelContext: modelContext) {
            return .deepWork
        }
        
        // Check for personal/ritual
        if isPersonal(event: event) {
            return .personal
        }
        
        // Check for blocker
        if isBlocker(event: event, modelContext: modelContext) {
            return .blocker
        }
        
        // Check for non-negotiable
        if isNonNegotiable(event: event) {
            return .nonNegotiable
        }
        
        // Check for light admin
        if isLightAdmin(event: event, modelContext: modelContext) {
            return .lightAdmin
        }
        
        // Check for negotiable
        if isNegotiable(event: event, modelContext: modelContext) {
            return .negotiable
        }
        
        // Default to independent
        return .independent
    }
    
    // MARK: - Category Checks
    
    private func isHighUrgency(event: CalendarEvent, modelContext: ModelContext) -> Bool {
        // Check deadline proximity
        let hoursUntil = event.startDate.timeIntervalSince(Date()) / 3600
        if hoursUntil < 24 {
            return true
        }
        
        // Check for overdue linked tasks
        let taskIds = event.linkedEntityIds.enumerated().compactMap { index, id -> UUID? in
            guard index < event.linkedEntityTypes.count,
                  event.linkedEntityTypes[index] == "task" else { return nil }
            return id
        }
        
        for taskId in taskIds {
            let taskIdValue = taskId
            let descriptor = FetchDescriptor<FocusOSShared.Task>(
                predicate: #Predicate<FocusOSShared.Task> { task in
                    task.id == taskIdValue
                }
            )
            if let task = try? modelContext.fetch(descriptor).first,
               let dueDate = task.dueDate,
               dueDate < Date(),
               task.status != .done {
                return true
            }
        }
        
        return false
    }
    
    private func isDeepWork(event: CalendarEvent, modelContext: ModelContext) -> Bool {
        // Check if linked to focus session
        let eventIdString = event.id.uuidString
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate<FocusSession> { session in
                session.calendarEventId == eventIdString
            }
        )
        if let _ = try? modelContext.fetch(descriptor).first {
            return true
        }
        
        // Check duration (> 30 min)
        let duration = event.endDate.timeIntervalSince(event.startDate)
        if duration < 1800 { // Less than 30 minutes
            return false
        }
        
        // Check for high effort tasks
        let taskIds = event.linkedEntityIds.enumerated().compactMap { index, id -> UUID? in
            guard index < event.linkedEntityTypes.count,
                  event.linkedEntityTypes[index] == "task" else { return nil }
            return id
        }
        
        for taskId in taskIds {
            let taskIdValue = taskId
            let descriptor = FetchDescriptor<FocusOSShared.Task>(
                predicate: #Predicate<FocusOSShared.Task> { task in
                    task.id == taskIdValue
                }
            )
            if let task = try? modelContext.fetch(descriptor).first,
               let effort = task.effort,
               effort.lowercased() == "large" {
                return true
            }
        }
        
        return false
    }
    
    private func isPersonal(event: CalendarEvent) -> Bool {
        let title = event.title.lowercased()
        let notes = (event.notes ?? "").lowercased()
        let text = title + " " + notes
        
        let keywords = ["ritual", "break", "recovery", "rest", "personal", "reflection", "review", "meditation", "exercise"]
        return keywords.contains { text.contains($0) }
    }
    
    private func isBlocker(event: CalendarEvent, modelContext: ModelContext) -> Bool {
        let taskIds = event.linkedEntityIds.enumerated().compactMap { index, id -> UUID? in
            guard index < event.linkedEntityTypes.count,
                  event.linkedEntityTypes[index] == "task" else { return nil }
            return id
        }
        
        for taskId in taskIds {
            let taskIdValue = taskId
            let descriptor = FetchDescriptor<FocusOSShared.Task>(
                predicate: #Predicate<FocusOSShared.Task> { task in
                    task.id == taskIdValue
                }
            )
            if let task = try? modelContext.fetch(descriptor).first,
               !task.dependsOnIds.isEmpty {
                return true
            }
        }
        
        return false
    }
    
    private func isNonNegotiable(event: CalendarEvent) -> Bool {
        // External meetings, fixed times, high priority
        let title = event.title.lowercased()
        let notes = (event.notes ?? "").lowercased()
        let text = title + " " + notes
        
        // Check for external meeting indicators
        if text.contains("meeting") || text.contains("call") || text.contains("interview") {
            return true
        }
        
        // Check if event has location (likely external)
        if let location = event.location, !location.isEmpty {
            return true
        }
        
        return false
    }
    
    private func isLightAdmin(event: CalendarEvent, modelContext: ModelContext) -> Bool {
        // Short duration, low effort, no focus session
        let duration = event.endDate.timeIntervalSince(event.startDate)
        if duration > 1800 { // More than 30 minutes
            return false
        }
        
        // Check for focus session
        let eventIdString = event.id.uuidString
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate<FocusSession> { session in
                session.calendarEventId == eventIdString
            }
        )
        if let _ = try? modelContext.fetch(descriptor).first {
            return false
        }
        
        // Check for low effort
        let taskIds = event.linkedEntityIds.enumerated().compactMap { index, id -> UUID? in
            guard index < event.linkedEntityTypes.count,
                  event.linkedEntityTypes[index] == "task" else { return nil }
            return id
        }
        
        if taskIds.isEmpty {
            return true // No linked tasks, likely admin
        }
        
        for taskId in taskIds {
            let taskIdValue = taskId
            let descriptor = FetchDescriptor<FocusOSShared.Task>(
                predicate: #Predicate<FocusOSShared.Task> { task in
                    task.id == taskIdValue
                }
            )
            if let task = try? modelContext.fetch(descriptor).first,
               let effort = task.effort,
               effort.lowercased() == "small" {
                return true
            }
        }
        
        return false
    }
    
    private func isNegotiable(event: CalendarEvent, modelContext: ModelContext) -> Bool {
        // No deadline, low CPS, flexible timing
        let hoursUntil = event.startDate.timeIntervalSince(Date()) / 3600
        if hoursUntil < 24 {
            return false // Too soon to be negotiable
        }
        
        // Check for linked tasks with no due date
        let taskIds = event.linkedEntityIds.enumerated().compactMap { index, id -> UUID? in
            guard index < event.linkedEntityTypes.count,
                  event.linkedEntityTypes[index] == "task" else { return nil }
            return id
        }
        
        if taskIds.isEmpty {
            return true // No linked tasks, likely negotiable
        }
        
        // Check if all linked tasks have no due date
        for taskId in taskIds {
            let taskIdValue = taskId
            let descriptor = FetchDescriptor<FocusOSShared.Task>(
                predicate: #Predicate<FocusOSShared.Task> { task in
                    task.id == taskIdValue
                }
            )
            if let task = try? modelContext.fetch(descriptor).first,
               task.dueDate != nil {
                return false // Has deadline, not negotiable
            }
        }
        
        return true
    }
}

