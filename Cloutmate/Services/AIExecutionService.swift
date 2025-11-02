//
//  AIExecutionService.swift
//  Cloutmate
//
//  AI Execution Service for performing app-wide operations
//

import Foundation
import SwiftData
import os.log
import CloutmateShared

@MainActor
final class AIExecutionService {
    static let shared = AIExecutionService()
    
    private init() {}
    
    // MARK: - Execution Results
    
    struct ExecutionResult {
        let success: Bool
        let message: String
        let itemsAffected: Int
        let details: [String]
        
        init(success: Bool, message: String, itemsAffected: Int = 0, details: [String] = []) {
            self.success = success
            self.message = message
            self.itemsAffected = itemsAffected
            self.details = details
        }
        
        func asMarkdown() -> String {
            var result = "✅ **\(message)**"
            if itemsAffected > 0 {
                result += "\n\nAffected: \(itemsAffected) items"
            }
            if !details.isEmpty {
                result += "\n\n"
                for detail in details {
                    result += "• \(detail)\n"
                }
            }
            return result
        }
    }
    
    // MARK: - Archive Tasks
    
    enum ArchiveCriteria: String, Codable {
        case all
        case completed
        case olderThan
        case byProject
    }
    
    func archiveTasks(
        criteria: ArchiveCriteria,
        daysAgo: Int? = nil,
        projectId: UUID? = nil,
        context: ModelContext
    ) async throws -> ExecutionResult {
        os_log("Archiving tasks with criteria: %{public}@", log: .default, type: .info, criteria.rawValue)
        
        let allTasks = try context.fetch(FetchDescriptor<Task>())
        var tasksToArchive: [Task] = []
        
        switch criteria {
        case .all:
            tasksToArchive = Array(allTasks)
            
        case .completed:
            tasksToArchive = allTasks.filter { $0.status == .done }
            
        case .olderThan:
            guard let days = daysAgo else {
                throw ExecutionError.invalidParameter("daysAgo required for olderThan criteria")
            }
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            tasksToArchive = allTasks.filter { task in
                task.status == .done && (task.completedAt ?? task.updatedAt) < cutoffDate
            }
            
        case .byProject:
            guard let projId = projectId else {
                throw ExecutionError.invalidParameter("projectId required for byProject criteria")
            }
            tasksToArchive = allTasks.filter { $0.projectId == projId && $0.status == .done }
        }
        
        // Apply status filter - only archive completed tasks
        tasksToArchive = tasksToArchive.filter { $0.status == .done }
        
        let count = tasksToArchive.count
        
        // Archive by updating status to cancelled (effectively hiding them)
        for task in tasksToArchive {
            task.status = .cancelled
            task.updatedAt = Date()
        }
        
        try? context.save()
        
        os_log("Archived %d tasks", log: .default, type: .info, count)
        
        return ExecutionResult(
            success: true,
            message: "Archived \(count) completed task\(count == 1 ? "" : "s")",
            itemsAffected: count,
            details: tasksToArchive.prefix(5).map { $0.title }
        )
    }
    
    // MARK: - Summarize Posts
    
    enum PostFilter: String, Codable {
        case all
        case byArea
        case byProject
        case byPlatform
        case byTag
        case published
        case scheduled
    }
    
    func summarizePosts(
        filter: PostFilter,
        filterValue: String? = nil,
        context: ModelContext
    ) async throws -> ExecutionResult {
        os_log("Summarizing posts with filter: %{public}@", log: .default, type: .info, filter.rawValue)
        
        let allPosts = try context.fetch(FetchDescriptor<Post>())
        var filteredPosts: [Post] = []
        
        switch filter {
        case .all:
            filteredPosts = Array(allPosts)
            
        case .published:
            filteredPosts = allPosts.filter { $0.status == "published" || $0.publishedDate != nil }
            
        case .scheduled:
            filteredPosts = allPosts.filter { $0.status == "scheduled" }
            
        case .byPlatform:
            guard let platformValue = filterValue else {
                throw ExecutionError.invalidParameter("platform required for byPlatform filter")
            }
            filteredPosts = allPosts.filter { post in
                post.platforms.contains(platformValue)
            }
            
        case .byTag:
            guard let tag = filterValue else {
                throw ExecutionError.invalidParameter("tag required for byTag filter")
            }
            filteredPosts = allPosts.filter { $0.tags.contains(tag) }
            
        case .byArea:
            // Filter by area via project association
            filteredPosts = allPosts.filter { $0.areaId != nil }
            
        case .byProject:
            guard let projectStr = filterValue, let projectId = UUID(uuidString: projectStr) else {
                throw ExecutionError.invalidParameter("valid projectId required")
            }
            filteredPosts = allPosts.filter { $0.projectId == projectId }
        }
        
        // Generate summary
        let count = filteredPosts.count
        let publishedCount = filteredPosts.filter { $0.publishedDate != nil }.count
        let scheduledCount = filteredPosts.filter { $0.status == "scheduled" }.count
        let avgEngagement = filteredPosts.compactMap { $0.engagementRate }.reduce(0, +)
        let avgEngagementValue = filteredPosts.isEmpty ? 0 : avgEngagement / Double(filteredPosts.count)
        
        var summaryLines: [String] = []
        summaryLines.append("Total posts: \(count)")
        summaryLines.append("Published: \(publishedCount)")
        summaryLines.append("Scheduled: \(scheduledCount)")
        if avgEngagementValue > 0 {
            summaryLines.append(String(format: "Average engagement: %.2f%%", avgEngagementValue))
        }
        
        // Top performing posts
        let topPosts = filteredPosts
            .filter { $0.engagementRate != nil }
            .sorted { ($0.engagementRate ?? 0) > ($1.engagementRate ?? 0) }
            .prefix(3)
        
        if !topPosts.isEmpty {
            summaryLines.append("\nTop performing posts:")
            for (index, post) in topPosts.enumerated() {
                let preview = post.caption.prefix(50)
                summaryLines.append("\(index + 1). \(preview)")
            }
        }
        
        return ExecutionResult(
            success: true,
            message: "Summary of \(filter.rawValue) posts",
            itemsAffected: count,
            details: summaryLines
        )
    }
    
    // MARK: - Generate Progress Report
    
    enum ReportType: String, Codable {
        case weekly
        case daily
        case monthly
        case custom
    }
    
    func generateProgressReport(
        type: ReportType,
        context: ModelContext
    ) async throws -> ExecutionResult {
        os_log("Generating %{public}@ progress report", log: .default, type: .info, type.rawValue)
        
        let now = Date()
        let calendar = Calendar.current
        var startDate: Date
        let endDate = now
        
        switch type {
        case .daily:
            startDate = calendar.startOfDay(for: now)
            
        case .weekly:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            
        case .monthly:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            
        case .custom:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        }
        
        // Gather data
        let tasks = try context.fetch(FetchDescriptor<Task>())
        let posts = try context.fetch(FetchDescriptor<Post>())
        let projects = try context.fetch(FetchDescriptor<Project>())
        
        // Filter by date range
        let completedTasks = tasks.filter { task in
            if let completedAt = task.completedAt {
                return completedAt >= startDate && completedAt <= endDate
            }
            return false
        }
        
        let recentPosts = posts.filter { post in
            if let publishedDate = post.publishedDate {
                return publishedDate >= startDate && publishedDate <= endDate
            }
            if let scheduledDate = post.scheduledDate {
                return scheduledDate >= startDate && scheduledDate <= endDate
            }
            return post.createdAt >= startDate && post.createdAt <= endDate
        }
        
        // Generate report
        var reportLines: [String] = []
        reportLines.append("📊 **Progress Report**")
        reportLines.append("Period: \(type.rawValue.capitalized)")
        reportLines.append("")
        reportLines.append("**Tasks:**")
        reportLines.append("• Completed: \(completedTasks.count)")
        reportLines.append("• In progress: \(tasks.filter { $0.status == .inProgress }.count)")
        let dueSoonCount = tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= startDate && dueDate <= endDate && task.status != .done
        }.count
        reportLines.append("• Due soon: \(dueSoonCount)")
        reportLines.append("")
        reportLines.append("**Posts:**")
        let publishedCount = recentPosts.filter { $0.publishedDate != nil }.count
        reportLines.append("• Published: \(publishedCount)")
        let scheduledCount = recentPosts.filter { $0.status == "scheduled" }.count
        reportLines.append("• Scheduled: \(scheduledCount)")
        reportLines.append("")
        
        // Projects progress
        reportLines.append("**Projects:**")
        reportLines.append("• Active: \(projects.filter { $0.status == .active }.count)")
        reportLines.append("• Completed: \(projects.filter { $0.status == .completed }.count)")
        
        // Engagement summary
        let publishedPosts = recentPosts.filter { $0.publishedDate != nil }
        if !publishedPosts.isEmpty {
            let avgEngagement = publishedPosts.compactMap { $0.engagementRate }.reduce(0, +) / Double(publishedPosts.count)
            reportLines.append("")
            reportLines.append(String(format: "**Average Engagement:** %.2f%%", avgEngagement))
        }
        
        return ExecutionResult(
            success: true,
            message: "Generated \(type.rawValue) progress report",
            itemsAffected: completedTasks.count + recentPosts.count,
            details: reportLines
        )
    }
    
    // MARK: - Predict Scheduling Needs
    
    func predictSchedulingNeeds(
        daysAhead: Int = 7,
        context: ModelContext
    ) async throws -> ExecutionResult {
        os_log("Predicting scheduling needs for next %d days", log: .default, type: .info, daysAhead)
        
        let tasks = try context.fetch(FetchDescriptor<Task>())
        let posts = try context.fetch(FetchDescriptor<Post>())
        
        let now = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: daysAhead, to: now) ?? now
        
        // Analyze upcoming tasks
        let upcomingTasks = tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= now && dueDate <= endDate && task.status != .done
        }
        
        // Analyze upcoming posts
        let upcomingPosts = posts.filter { post in
            if let scheduledDate = post.scheduledDate {
                return scheduledDate >= now && scheduledDate <= endDate
            }
            return false
        }
        
        // Predict needs
        var predictions: [String] = []
        
        // Task predictions
        predictions.append("**Task Predictions:**")
        predictions.append("• Tasks due: \(upcomingTasks.count)")
        if !upcomingTasks.isEmpty {
            let highPriorityTasks = upcomingTasks.filter { $0.priority == .high }
            if !highPriorityTasks.isEmpty {
                predictions.append("• High priority tasks: \(highPriorityTasks.count)")
            }
            let inProgressCount = upcomingTasks.filter { $0.status == .inProgress }.count
            if inProgressCount > 0 {
                predictions.append("• In progress: \(inProgressCount)")
            }
        }
        
        // Post predictions
        predictions.append("")
        predictions.append("**Scheduling Predictions:**")
        predictions.append("• Posts scheduled: \(upcomingPosts.count)")
        
        if !upcomingPosts.isEmpty {
            let dateGroups = Dictionary(grouping: upcomingPosts) { post in
                Calendar.current.startOfDay(for: post.scheduledDate ?? now)
            }
            
            let busiestDay = dateGroups.max { $0.value.count < $1.value.count }
            if let busiest = busiestDay, busiest.value.count > 1 {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                predictions.append("• Busiest day: \(formatter.string(from: busiest.key)) (\(busiest.value.count) posts)")
            }
        }
        
        // Recommendation
        predictions.append("")
        if upcomingTasks.count > 5 {
            predictions.append("**💡 Recommendation:**")
            predictions.append("Consider breaking down tasks into smaller chunks to maintain focus.")
        } else if upcomingTasks.isEmpty && upcomingPosts.count < 3 {
            predictions.append("**💡 Recommendation:**")
            predictions.append("Good time to schedule more content or tackle larger projects.")
        }
        
        return ExecutionResult(
            success: true,
            message: "Prediction for next \(daysAhead) days",
            itemsAffected: upcomingTasks.count + upcomingPosts.count,
            details: predictions
        )
    }
}

// MARK: - Execution Errors

enum ExecutionError: LocalizedError {
    case invalidParameter(String)
    case executionFailed(String)
    case notFound(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidParameter(let message):
            return "Invalid parameter: \(message)"
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        case .notFound(let message):
            return "Not found: \(message)"
        }
    }
}

// MARK: - Logger

extension Logger {
    static let execution = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "AIExecution")
}
