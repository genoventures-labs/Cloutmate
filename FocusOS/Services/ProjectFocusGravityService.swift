//
//  ProjectFocusGravityService.swift
//  FocusOS
//
//  Calculate and cache Focus Gravity metrics per project
//

import Foundation
import SwiftData
import FocusOSShared
import os.log

struct ProjectFocusMetrics {
    let cognitiveFocus: Double    // 0.0 - 1.0
    let creativeFlow: Double      // 0.0 - 1.0
    let completionEnergy: Double  // 0.0 - 1.0
    let lastActiveAt: Date?
    let avgSessionDuration: TimeInterval
    let weeklyTrend: [(Date, Double)]
}

@MainActor
final class ProjectFocusGravityService {
    static let shared = ProjectFocusGravityService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "ProjectFocusGravity")
    private var cache: [UUID: (metrics: ProjectFocusMetrics, timestamp: Date)] = [:]
    private let cacheTTL: TimeInterval = 300 // 5 minutes
    
    private init() {}
    
    func focusMetrics(for project: Project, modelContext: ModelContext) -> ProjectFocusMetrics {
        // Check cache first
        if let cached = cache[project.id],
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.metrics
        }
        
        // Calculate fresh metrics
        let metrics = calculateMetrics(for: project, modelContext: modelContext)
        
        // Cache result
        cache[project.id] = (metrics: metrics, timestamp: Date())
        
        return metrics
    }
    
    func weeklyFocusTrend(for project: Project, days: Int = 7, modelContext: ModelContext) -> [(Date, Double)] {
        let calendar = Calendar.current
        let now = Date()
        var trend: [(Date, Double)] = []
        
        for i in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -i, to: now) else { continue }
            
            // Get priority score for this date (simplified - use current score)
            let priorityScore = getPriorityScore(for: project, modelContext: modelContext)
            
            // Calculate focus strength based on activity
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
            let activityScore = calculateActivityScore(for: project, from: dayStart, to: dayEnd, modelContext: modelContext)
            
            let focusStrength = (priorityScore + activityScore) / 2.0
            trend.append((date, focusStrength))
        }
        
        return trend.reversed()
    }
    
    func invalidateCache(for projectId: UUID) {
        cache.removeValue(forKey: projectId)
    }
    
    func invalidateAllCache() {
        cache.removeAll()
    }
    
    // MARK: - Reintegration
    
    func reintegrate(project: Project, modelContext: ModelContext) {
        // Reset focus metrics cache
        cache.removeValue(forKey: project.id)
        // Recalculate priority score
        // Update CPS ranking (PriorityEngine will handle this automatically)
        logger.info("Reintegrated project \(project.id) - cache cleared")
    }
    
    // MARK: - Private Calculation Methods
    
    private func calculateMetrics(for project: Project, modelContext: ModelContext) -> ProjectFocusMetrics {
        // Get priority score from PriorityEngine
        let priorityScore = getPriorityScore(for: project, modelContext: modelContext)
        
        // Get linked tasks
        let tasks = getLinkedTasks(for: project, modelContext: modelContext)
        
        // Calculate focus types based on task patterns
        let cognitiveFocus = calculateCognitiveFocus(for: project, tasks: tasks, priorityScore: priorityScore)
        let creativeFlow = calculateCreativeFlow(for: project, tasks: tasks, priorityScore: priorityScore)
        let completionEnergy = calculateCompletionEnergy(for: project, tasks: tasks, priorityScore: priorityScore)
        
        // Calculate last active time
        let lastActiveAt = calculateLastActiveAt(for: project, tasks: tasks)
        
        // Calculate average session duration (simplified - based on task completion patterns)
        let avgSessionDuration = calculateAvgSessionDuration(for: project, tasks: tasks)
        
        // Get weekly trend
        let weeklyTrend = weeklyFocusTrend(for: project, days: 7, modelContext: modelContext)
        
        return ProjectFocusMetrics(
            cognitiveFocus: cognitiveFocus,
            creativeFlow: creativeFlow,
            completionEnergy: completionEnergy,
            lastActiveAt: lastActiveAt,
            avgSessionDuration: avgSessionDuration,
            weeklyTrend: weeklyTrend
        )
    }
    
    private func getPriorityScore(for project: Project, modelContext: ModelContext) -> Double {
        // Get priority from PriorityEngine
        let priorityItems = PriorityEngine.shared.getTopObjects(ofType: "project", limit: 100, modelContext: modelContext)
        
        if let item = priorityItems.first(where: { $0.objectId == project.id }) {
            return item.score
        }
        
        // Fallback: calculate based on recency and activity
        let daysSinceUpdate = Calendar.current.dateComponents([.day], from: project.updatedAt, to: Date()).day ?? 0
        let recencyScore = max(0.0, 1.0 - (Double(daysSinceUpdate) / 30.0))
        
        return recencyScore * 0.5 // Default moderate score
    }
    
    private func getLinkedTasks(for project: Project, modelContext: ModelContext) -> [Task] {
        // Use fetch then filter instead of predicate to avoid type issues
        let descriptor = FetchDescriptor<Task>()
        guard let allTasks = try? modelContext.fetch(descriptor) else {
            return []
        }
        
        return allTasks.filter { $0.projectId == project.id }
    }
    
    private func calculateCognitiveFocus(for project: Project, tasks: [Task], priorityScore: Double) -> Double {
        // Cognitive focus = high priority tasks + recent activity
        let highPriorityTasks = tasks.filter { $0.priority == .high }.count
        let totalTasks = max(1, tasks.count)
        let priorityRatio = Double(highPriorityTasks) / Double(totalTasks)
        
        // Recent activity boosts cognitive focus
        let daysSinceUpdate = Calendar.current.dateComponents([.day], from: project.updatedAt, to: Date()).day ?? 0
        let recencyBoost = max(0.0, 1.0 - (Double(daysSinceUpdate) / 7.0))
        
        return min(1.0, (priorityRatio * 0.6 + priorityScore * 0.3 + recencyBoost * 0.1))
    }
    
    private func calculateCreativeFlow(for project: Project, tasks: [Task], priorityScore: Double) -> Double {
        // Creative flow = tasks in progress + linked notes/artifacts
        let inProgressTasks = tasks.filter { $0.status == .inProgress }.count
        let totalTasks = max(1, tasks.count)
        let flowRatio = Double(inProgressTasks) / Double(totalTasks)
        
        // Notes and artifacts indicate creative work
        let notesCount = project.noteIds.count
        let artifactsCount = project.postIds.count // Using postIds as artifact IDs
        let creativeContentRatio = min(1.0, Double(notesCount + artifactsCount) / 10.0)
        
        return min(1.0, (flowRatio * 0.5 + creativeContentRatio * 0.3 + priorityScore * 0.2))
    }
    
    private func calculateCompletionEnergy(for project: Project, tasks: [Task], priorityScore: Double) -> Double {
        // Completion energy = completed tasks + approaching deadline
        let completedTasks = tasks.filter { $0.status == .done }.count
        let totalTasks = max(1, tasks.count)
        let completionRatio = Double(completedTasks) / Double(totalTasks)
        
        // Deadline proximity boosts completion energy
        var deadlineBoost: Double = 0.0
        if let dueDate = project.dueDate {
            let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
            if daysUntilDue >= 0 && daysUntilDue <= 7 {
                deadlineBoost = 1.0 - (Double(daysUntilDue) / 7.0)
            }
        }
        
        return min(1.0, (completionRatio * 0.6 + deadlineBoost * 0.3 + priorityScore * 0.1))
    }
    
    private func calculateLastActiveAt(for project: Project, tasks: [Task]) -> Date? {
        var lastActive = project.updatedAt
        
        // Check task completion dates
        for task in tasks {
            if let completedAt = task.completedAt, completedAt > lastActive {
                lastActive = completedAt
            }
            if task.updatedAt > lastActive {
                lastActive = task.updatedAt
            }
        }
        
        return lastActive > project.updatedAt ? lastActive : project.updatedAt
    }
    
    private func calculateAvgSessionDuration(for project: Project, tasks: [Task]) -> TimeInterval {
        // Simplified: estimate based on task completion patterns
        // Assume each completed task took ~30 minutes
        let completedTasks = tasks.filter { $0.status == .done }.count
        return TimeInterval(completedTasks * 30 * 60) // Convert to seconds
    }
    
    private func calculateActivityScore(for project: Project, from startDate: Date, to endDate: Date, modelContext: ModelContext) -> Double {
        // Check if project or tasks were updated in this timeframe
        if project.updatedAt >= startDate && project.updatedAt < endDate {
            return 0.8
        }
        
        // Check tasks
        let tasks = getLinkedTasks(for: project, modelContext: modelContext)
        let activeTasks = tasks.filter { task in
            (task.updatedAt >= startDate && task.updatedAt < endDate) ||
            (task.completedAt != nil && task.completedAt! >= startDate && task.completedAt! < endDate)
        }
        
        if !activeTasks.isEmpty {
            return min(1.0, Double(activeTasks.count) / 5.0)
        }
        
        return 0.0
    }
}

