//
//  ChronotypeMapper.swift
//  FocusOS
//
//  Learns when user performs best at each type of work
//

import Foundation
import SwiftData
import os.log

@MainActor
final class ChronotypeMapper {
    static let shared = ChronotypeMapper()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "ChronotypeMapper")
    
    private init() {}
    
    /// Learn optimal times from focus session history
    func learnOptimalTimes(
        for energyType: EnergyRequirement,
        modelContext: ModelContext
    ) -> [Int] { // Returns hours of day (0-23) when user performs best
        let completedStatusRaw = FocusSessionStatus.completed.rawValue
        var descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { session in
                session.statusRaw == completedStatusRaw && session.completed == true
            },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = 100
        
        let sessions = (try? modelContext.fetch(descriptor)) ?? []
        
        // Group by hour of day
        var hourPerformance: [Int: (count: Int, totalCompletion: Int)] = [:]
        
        for session in sessions {
            let hour = Calendar.current.component(.hour, from: session.startTime)
            hourPerformance[hour, default: (0, 0)].count += 1
            if session.completed {
                hourPerformance[hour, default: (0, 0)].totalCompletion += 1
            }
        }
        
        // Calculate completion rates per hour
        let hourRates = hourPerformance.map { hour, data in
            (hour: hour, rate: Double(data.totalCompletion) / Double(data.count))
        }
        
        // Return top 3 hours
        return hourRates
            .sorted { $0.rate > $1.rate }
            .prefix(3)
            .map { $0.hour }
    }
    
    /// Get optimal time window for energy type
    func getOptimalWindow(
        for energyType: EnergyRequirement,
        modelContext: ModelContext
    ) -> (startHour: Int, endHour: Int)? {
        let optimalHours = learnOptimalTimes(for: energyType, modelContext: modelContext)
        
        guard !optimalHours.isEmpty else { return nil }
        
        let startHour = optimalHours.min() ?? 9
        let endHour = optimalHours.max() ?? 17
        
        return (startHour, endHour)
    }
}

