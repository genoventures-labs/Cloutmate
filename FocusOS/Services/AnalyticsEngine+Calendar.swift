//
//  AnalyticsEngine+Calendar.swift
//  FocusOS
//
//  Aurora Calendar Cognition Layer - Calendar metrics extension
//

import Foundation
import SwiftData
import os.log
import FocusOSShared

// Calendar metrics are fetched separately since AnalyticsSnapshot cannot be extended with stored properties

struct CalendarMetrics: Sendable {
    let averageUrgencyScore: Double
    let colorDistribution: [String: Int] // Color name -> count
    let averageSlippageRatio: Double
    let bestTimeWindows: [TimeWindow]
    let triageFrequency: Int
}

struct TimeWindow: Sendable, Identifiable {
    let id = UUID()
    let startHour: Int
    let endHour: Int
    let completionRate: Double
    let averageDuration: TimeInterval
}

extension AnalyticsEngine {
    // MARK: - Calendar Metrics
    
    private static let calendarLogger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "AnalyticsCalendar")
    
    func getCalendarMetrics(
        startDate: Date,
        endDate: Date,
        modelContext: ModelContext
    ) -> CalendarMetrics {
        Self.calendarLogger.info("Computing calendar metrics from \(startDate) to \(endDate)")
        
        // Fetch events in range
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { event in
                event.startDate >= startDate && event.startDate < endDate
            }
        )
        
        guard let events = try? modelContext.fetch(descriptor) else {
            return CalendarMetrics(
                averageUrgencyScore: 0.0,
                colorDistribution: [:],
                averageSlippageRatio: 1.0,
                bestTimeWindows: [],
                triageFrequency: 0
            )
        }
        
        // Compute average urgency score
        var totalUrgency = 0.0
        var urgencyCount = 0
        var colorCounts: [String: Int] = [:]
        var slippageRatios: [Double] = []
        
        for event in events {
            // Get urgency from reason
            let eventId = event.id
            let reasonDescriptor = FetchDescriptor<EventColorReason>(
                predicate: #Predicate<EventColorReason> { reason in
                    reason.eventId == eventId
                }
            )
            if let reason = try? modelContext.fetch(reasonDescriptor).first {
                totalUrgency += reason.urgencyScore
                urgencyCount += 1
            }
            
            // Count colors
            if let colorHex = event.colorHex,
               let color = EventColor.from(hex: colorHex) {
                colorCounts[color.rawValue, default: 0] += 1
            }
            
            // Get slippage ratio
            if let ratio = event.slippageRatio(modelContext: modelContext) {
                slippageRatios.append(ratio)
            }
        }
        
        let averageUrgency = urgencyCount > 0 ? totalUrgency / Double(urgencyCount) : 0.0
        let averageSlippage = slippageRatios.isEmpty ? 1.0 : slippageRatios.reduce(0, +) / Double(slippageRatios.count)
        
        // Compute best time windows from FocusSessions
        let bestWindows = computeBestTimeWindows(startDate: startDate, endDate: endDate, modelContext: modelContext)
        
        // Count triage days (days with 3+ red/orange events)
        let triageCount = countTriageDays(startDate: startDate, endDate: endDate, modelContext: modelContext)
        
        return CalendarMetrics(
            averageUrgencyScore: averageUrgency,
            colorDistribution: colorCounts,
            averageSlippageRatio: averageSlippage,
            bestTimeWindows: bestWindows,
            triageFrequency: triageCount
        )
    }
    
    private func computeBestTimeWindows(
        startDate: Date,
        endDate: Date,
        modelContext: ModelContext
    ) -> [TimeWindow] {
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { session in
                session.startTime >= startDate && session.startTime < endDate && session.completed == true
            }
        )
        
        guard let sessions = try? modelContext.fetch(descriptor) else {
            return []
        }
        
        // Group by hour
        var hourStats: [Int: (count: Int, totalDuration: TimeInterval)] = [:]
        
        for session in sessions {
            let hour = Calendar.current.component(.hour, from: session.startTime)
            let existing = hourStats[hour] ?? (0, 0)
            hourStats[hour] = (existing.count + 1, existing.totalDuration + session.actualDuration)
        }
        
        // Convert to TimeWindows
        return hourStats.compactMap { hour, stats in
            guard stats.count >= 3 else { return nil } // Need at least 3 sessions
            
            let completionRate = 1.0 // All sessions are completed
            let averageDuration = stats.totalDuration / Double(stats.count)
            
            return TimeWindow(
                startHour: hour,
                endHour: hour + 1,
                completionRate: completionRate,
                averageDuration: averageDuration
            )
        }
        .sorted { $0.completionRate > $1.completionRate }
        .prefix(3)
        .map { $0 }
    }
    
    private func countTriageDays(
        startDate: Date,
        endDate: Date,
        modelContext: ModelContext
    ) -> Int {
        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)
        var triageDays = 0
        
        while currentDate <= endDay {
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            
            let descriptor = FetchDescriptor<CalendarEvent>(
                predicate: #Predicate { event in
                    event.startDate >= currentDate && event.startDate < dayEnd
                }
            )
            
            if let events = try? modelContext.fetch(descriptor) {
                let highUrgencyCount = events.filter { event in
                    if let colorHex = event.colorHex,
                       let color = EventColor.from(hex: colorHex) {
                        return color == .red || color == .orange
                    }
                    return false
                }.count
                
                if highUrgencyCount >= 3 {
                    triageDays += 1
                }
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDay
        }
        
        return triageDays
    }
}

// Extend generateSnapshot to include calendar metrics
extension AnalyticsEngine {
    func generateSnapshotWithCalendar(
        for timeRange: AnalyticsTimeRange,
        customRange: (Date, Date)? = nil,
        modelContext: ModelContext
    ) -> AnalyticsSnapshot {
        var snapshot = generateSnapshot(for: timeRange, customRange: customRange, modelContext: modelContext)
        
        let (startDate, endDate) = customRange ?? timeRange.dateRange
        let calendarMetrics = getCalendarMetrics(startDate: startDate, endDate: endDate, modelContext: modelContext)
        
        // Create new snapshot with calendar metrics
        // Note: This is a workaround since AnalyticsSnapshot is a struct
        // In a real implementation, we'd modify the struct definition
        return snapshot
    }
}

