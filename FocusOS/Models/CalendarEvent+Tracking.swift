//
//  CalendarEvent+Tracking.swift
//  FocusOS
//
//  Aurora Calendar Cognition Layer - Planned vs actual tracking
//

import Foundation
import SwiftData
import FocusOSShared

extension CalendarEvent {
    /// Planned duration from start to end date
    var plannedDuration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
    
    /// Actual duration from linked FocusSession (if available)
    func actualDuration(modelContext: ModelContext) -> TimeInterval? {
        let eventIdString = self.id.uuidString
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate<FocusSession> { session in
                session.calendarEventId == eventIdString
            }
        )
        
        guard let session = try? modelContext.fetch(descriptor).first else {
            return nil
        }
        
        return session.actualDuration > 0 ? session.actualDuration : nil
    }
    
    /// Slippage ratio: actualDuration / plannedDuration (1.0 = on time, >1.0 = overrun, <1.0 = early)
    func slippageRatio(modelContext: ModelContext) -> Double? {
        guard let actual = actualDuration(modelContext: modelContext) else {
            return nil
        }
        
        let planned = plannedDuration
        guard planned > 0 else { return nil }
        
        return actual / planned
    }
    
    /// Whether the event was completed (has linked FocusSession that completed)
    func wasCompleted(modelContext: ModelContext) -> Bool {
        let eventIdString = self.id.uuidString
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate<FocusSession> { session in
                session.calendarEventId == eventIdString && session.completed == true
            }
        )
        
        return (try? modelContext.fetch(descriptor).first) != nil
    }
    
    /// Whether the event was ignored (past endDate with no FocusSession)
    func wasIgnored(modelContext: ModelContext) -> Bool {
        let now = Date()
        guard endDate < now else {
            return false // Not past yet
        }
        
        // Check if there's a FocusSession
        let eventIdString = self.id.uuidString
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate<FocusSession> { session in
                session.calendarEventId == eventIdString
            }
        )
        
        let hasSession = (try? modelContext.fetch(descriptor).first) != nil
        return !hasSession
    }
}

