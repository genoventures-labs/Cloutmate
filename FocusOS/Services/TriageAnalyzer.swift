//
//  TriageAnalyzer.swift
//  FocusOS
//
//  Aurora Calendar Cognition Layer - Overload detection and triage recommendations
//

import Foundation
import SwiftData
import os.log
import FocusOSShared

@MainActor
final class TriageAnalyzer {
    static let shared = TriageAnalyzer()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "TriageAnalyzer")
    private let cognitionService = AuroraCalendarCognitionService.shared
    
    private init() {}
    
    func analyzeDay(_ date: Date, modelContext: ModelContext) -> TriageRecommendation? {
        return cognitionService.checkTriageNeeded(for: date, modelContext: modelContext)
    }
    
    func getDailyWorkloadDensity(for date: Date, modelContext: ModelContext) -> Double {
        let dayStart = Calendar.current.startOfDay(for: date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? date
        
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { event in
                event.startDate >= dayStart && event.startDate < dayEnd
            }
        )
        
        guard let events = try? modelContext.fetch(descriptor) else { return 0.0 }
        
        let totalDuration = events.reduce(0.0) { sum, event in
            sum + event.endDate.timeIntervalSince(event.startDate)
        }
        
        let hoursScheduled = totalDuration / 3600
        let hoursInDay = 16.0 // Assume 16 waking hours
        
        return min(1.0, hoursScheduled / hoursInDay)
    }
}

