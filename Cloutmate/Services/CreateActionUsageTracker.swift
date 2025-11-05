//
//  CreateActionUsageTracker.swift
//  Cloutmate
//
//  Tracks and queries usage patterns for create actions
//

import Foundation
import SwiftData
import os.log

@MainActor
final class CreateActionUsageTracker {
    static let shared = CreateActionUsageTracker()
    
    private init() {}
    
    /// Record usage of a create action
    func recordUsage(
        tab: TabIdentifier,
        actionType: String,
        modelContext: ModelContext
    ) {
        let usage = CreateActionUsage(tab: tab, actionType: actionType)
        modelContext.insert(usage)
        
        do {
            try modelContext.save()
            os_log("Recorded usage: %{public}@ in %{public}@", log: .default, type: .info, actionType, tab.rawValue)
        } catch {
            os_log("Failed to record usage: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
    }
    
    /// Get most used actions in a tab within a time range
    func mostUsedActions(
        in tab: TabIdentifier,
        timeRange: TimeRange = .lastWeek,
        limit: Int = 2,
        modelContext: ModelContext
    ) -> [String] {
        let calendar = Calendar.current
        let now = Date()
        
        let startDate: Date
        switch timeRange {
        case .lastWeek:
            startDate = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
        case .lastMonth:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .allTime:
            startDate = Date.distantPast
        }
        
        let descriptor = FetchDescriptor<CreateActionUsage>(
            predicate: #Predicate { usage in
                usage.tabRaw == tab.rawValue && usage.timestamp >= startDate
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        guard let usages = try? modelContext.fetch(descriptor) else {
            return []
        }
        
        // Count occurrences of each action type
        var actionCounts: [String: Int] = [:]
        for usage in usages {
            actionCounts[usage.actionType, default: 0] += 1
        }
        
        // Sort by count and return top actions
        let sortedActions = actionCounts.sorted { $0.value > $1.value }
        return Array(sortedActions.prefix(limit).map { $0.key })
    }
    
    /// Get the most recently created type in a tab
    func recentlyCreatedType(
        in tab: TabIdentifier,
        modelContext: ModelContext
    ) -> String? {
        let descriptor = FetchDescriptor<CreateActionUsage>(
            predicate: #Predicate { usage in
                usage.tabRaw == tab.rawValue
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        guard let usages = try? modelContext.fetch(descriptor),
              let mostRecent = usages.first else {
            return nil
        }
        
        return mostRecent.actionType
    }
    
    /// Get usage count for a specific action in a tab
    func usageCount(
        for actionType: String,
        in tab: TabIdentifier,
        timeRange: TimeRange = .lastWeek,
        modelContext: ModelContext
    ) -> Int {
        let calendar = Calendar.current
        let now = Date()
        
        let startDate: Date
        switch timeRange {
        case .lastWeek:
            startDate = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
        case .lastMonth:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .allTime:
            startDate = Date.distantPast
        }
        
        let descriptor = FetchDescriptor<CreateActionUsage>(
            predicate: #Predicate { usage in
                usage.tabRaw == tab.rawValue &&
                usage.actionType == actionType &&
                usage.timestamp >= startDate
            }
        )
        
        guard let usages = try? modelContext.fetch(descriptor) else {
            return 0
        }
        
        return usages.count
    }
}

enum TimeRange {
    case lastWeek
    case lastMonth
    case allTime
}

