//
//  AppContextService.swift
//  FocusOS
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData
import os.log
import Combine
import FocusOSShared

@MainActor
final class AppContextService {
    static let shared = AppContextService()
    
    private var cachedContext: String?
    private var cacheTimestamp: Date?
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes
    
    private init() {}
    
    func buildContextForAI(modelContext: ModelContext) async throws -> String {
        // Check cache first
        if let cached = cachedContext,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheValidityDuration {
            return cached
        }
        
        // Build fresh context
        var context = "# FocusOS App Context\n\n"
        
        // 1. Inbox count (unconverted items)
        let inboxItems = try modelContext.fetch(FetchDescriptor<InboxItem>())
        let unconvertedCount = inboxItems.filter { $0.convertedAt == nil }.count
        context += "## Inbox\n"
        context += "- \(unconvertedCount) unconverted inbox items\n"
        
        // 2. Tasks (upcoming and overdue)
        let tasks = try modelContext.fetch(FetchDescriptor<Task>())
        let todoTasks = tasks.filter { $0.status == .todo }
        let inProgressTasks = tasks.filter { $0.status == .inProgress }
        let tasksDueToday = tasks.filter { task in
            guard let due = task.dueDate else { return false }
            return Calendar.current.isDateInToday(due) && task.status != .done
        }
        let overdueTasks = tasks.filter { task in
            guard let due = task.dueDate else { return false }
            return due < Date() && task.status != .done
        }
        
        context += "\n## Tasks\n"
        context += "- \(todoTasks.count) tasks to do\n"
        context += "- \(inProgressTasks.count) tasks in progress\n"
        context += "- \(tasksDueToday.count) tasks due today\n"
        context += "- \(overdueTasks.count) overdue tasks\n\n"
        
        if !tasksDueToday.isEmpty {
            context += "Tasks due today:\n"
            for task in tasksDueToday.prefix(5) {
                context += "- [\(task.status.rawValue.capitalized)] \(task.title)"
                if let due = task.dueDate {
                    let formatter = DateFormatter()
                    formatter.timeStyle = .short
                    context += " (due \(formatter.string(from: due)))"
                }
                context += "\n"
            }
        }
        
        // 3. Projects
        let projects = try modelContext.fetch(FetchDescriptor<Project>())
        let activeProjects = projects.filter { $0.status == .active }
        let pausedProjects = projects.filter { $0.status == .paused }
        
        context += "\n## Projects\n"
        context += "- \(activeProjects.count) active projects\n"
        context += "- \(pausedProjects.count) paused projects\n\n"
        
        if !activeProjects.isEmpty {
            context += "Active projects:\n"
            for project in activeProjects.prefix(5) {
                context += "- \(project.title)"
                if let goal = project.goal {
                    context += ": \(goal)"
                }
                context += "\n"
            }
        }
        
        // 4. Areas
        let areas = try modelContext.fetch(FetchDescriptor<Area>())
        context += "\n## Areas of Responsibility\n"
        context += "- \(areas.count) areas defined\n"
        for area in areas.prefix(5) {
            context += "- \(area.title)"
            if let notes = area.notes {
                context += ": \(notes)"
            }
            context += "\n"
        }
        
        // 5. Posts (upcoming and recent)
        let posts = try modelContext.fetch(FetchDescriptor<Post>())
        let scheduledPosts = posts.filter { $0.status == "scheduled" }
        let todayPosts = posts.filter { post in
            guard let scheduled = post.scheduledDate else { return false }
            return Calendar.current.isDateInToday(scheduled)
        }
        
        context += "\n## Social Publishing\n"
        context += "- \(scheduledPosts.count) posts scheduled\n"
        context += "- \(todayPosts.count) posts scheduled for today\n\n"
        
        if !todayPosts.isEmpty {
            context += "Posts scheduled today:\n"
            for post in todayPosts.prefix(5) {
                context += "- \(post.caption.prefix(100))\n"
            }
        }
        
        // 6. Drafts & Templates
        let drafts = try modelContext.fetch(FetchDescriptor<Draft>())
        let templates = try modelContext.fetch(FetchDescriptor<Template>())
        context += "\n## Drafts & Templates\n"
        context += "- \(drafts.count) drafts\n"
        context += "- \(templates.count) templates\n\n"
        let recentDrafts = drafts.sorted(by: { $0.updatedAt > $1.updatedAt }).prefix(5)
        if !recentDrafts.isEmpty {
            context += "Recent drafts:\n"
            for draft in recentDrafts {
                let preview = draft.caption.prefix(50)
                context += "- \(preview)\n"
            }
        }

        // 7. Notes (recent)
        let notes = try modelContext.fetch(FetchDescriptor<Note>())
        let recentNotes = Array(notes.filter { !$0.isArchived }.prefix(5))
        context += "\n## Recent Notes\n"
        if recentNotes.isEmpty {
            context += "- None\n"
        } else {
            for note in recentNotes {
                context += "- \(note.title)\n"
            }
        }

        // 8. Inbox
        context += "\n## Inbox Details\n"
        context += "- Total inbox items: \(inboxItems.count)\n"
        context += "- Unconverted: \(unconvertedCount)\n"
        if !inboxItems.isEmpty {
            let latestInbox = inboxItems.sorted(by: { $0.createdAt > $1.createdAt }).prefix(3)
            context += "Latest inbox items:\n"
            for item in latestInbox {
                let preview = item.content.prefix(80)
                context += "- (\(item.itemType)) \(preview)\n"
            }
        }

        // 9. Accounts (removed - social media accounts no longer supported)
        // Platform accounts removed

        // 10. Insights
        let insights = try modelContext.fetch(FetchDescriptor<InsightSnapshot>())
        context += "\n## Insights\n"
        context += "- Snapshots: \(insights.count)\n"
        if !insights.sorted(by: { $0.capturedAt > $1.capturedAt }).isEmpty {
            context += "- Latest snapshot available\n"
        }

        // 11. PARA Templates
        let paraTemplates = try modelContext.fetch(FetchDescriptor<PARATemplate>())
        context += "\n## PARA Templates\n"
        context += "- Templates: \(paraTemplates.count)\n"
        
        // 12. Notion Integration (new implementation)
        // Note: Notion integration now uses NotionImportService
        // This section can be updated to reflect the new integration once fully implemented
        context += "\n## Notion Integration\n"
        context += "- Integration status: Check via NotionImportService\n"
        
        // Check if Notion is connected (has token)
        if (try? KeychainService.shared.getToken(forAccount: "notion_access_token")) != nil {
            context += "- Notion account connected\n"
        }
        
        // 13. Post Performance (recent analytics)
        let publishedPosts = posts.filter { $0.publishedDate != nil }
        if !publishedPosts.isEmpty {
            context += "\n## Post Performance\n"
            let last7Days = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let recentPosts = publishedPosts.filter { ($0.publishedDate ?? Date.distantPast) >= last7Days }
            context += "- Posts published in last 7 days: \(recentPosts.count)\n"
            
            let postsWithEngagement = recentPosts.filter { $0.engagementRate != nil }
            if !postsWithEngagement.isEmpty {
                let avgEngagement = postsWithEngagement.map { $0.engagementRate ?? 0 }.reduce(0, +) / Double(postsWithEngagement.count)
                context += String(format: "- Average engagement rate: %.2f%%\n", avgEngagement)
                
                let totalImpressions = recentPosts.compactMap { $0.impressions }.reduce(0, +)
                if totalImpressions > 0 {
                    context += "- Total impressions: \(totalImpressions)\n"
                }
            }
        }
        
        // 13. Task Completion Patterns
        let doneTasks = tasks.filter { $0.status == .done }
        if doneTasks.count > 0 {
            context += "\n## Task Patterns\n"
            context += "- Total completed tasks: \(doneTasks.count)\n"
            
            let last7Days = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let recentCompleted = doneTasks.filter { ($0.completedAt ?? Date.distantPast) >= last7Days }
            context += "- Completed in last 7 days: \(recentCompleted.count)\n"
            
            // Average completion time for tasks with due dates
            let tasksWithDuration = doneTasks.filter { task in
                guard let completed = task.completedAt else { return false }
                return completed > task.createdAt
            }
            if !tasksWithDuration.isEmpty && !tasksWithDuration.allSatisfy({ $0.dueDate == nil }) {
                context += "- Recent task activity: \(recentCompleted.count) tasks completed\n"
            }
        }
        
        // 14. Upcoming Deadlines
        let upcomingWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        let now = Date()
        let upcomingTasks = tasks.filter { task in
            guard let dueDate = task.dueDate, task.status != .done else { return false }
            return dueDate >= now && dueDate <= upcomingWeek
        }
        
        if !upcomingTasks.isEmpty {
            context += "\n## Upcoming Deadlines (next 7 days)\n"
            let sortedTasks = upcomingTasks.sorted(by: { ($0.dueDate ?? Date.distantFuture) < ($1.dueDate ?? Date.distantFuture) }).prefix(5)
            for task in sortedTasks {
                // Capture the task's values before the async call to avoid Sendable warnings
                let taskTitle = task.title
                let taskDueDate = task.dueDate
                let taskPriority = task.priority
                context += "- \(taskTitle) (Priority: \(taskPriority.displayName))"
                if let due = taskDueDate {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    context += " - Due: \(formatter.string(from: due))"
                }
                context += "\n"
            }
        }
        
        // Update recall snapshot for AI context payloads
        AIRecallService.shared.recordSnapshot(
            tasks: Array(tasksDueToday.prefix(10)),
            projects: Array(activeProjects.prefix(5)),
            posts: Array(todayPosts.prefix(5)),
            notes: recentNotes,
            drafts: Array(recentDrafts),
            modelContext: modelContext
        )
        
        // Cache the result
        cachedContext = context
        cacheTimestamp = Date()
        
        return context
    }
    
    func contextFreshness() -> TimeInterval? {
        guard let timestamp = cacheTimestamp else { return nil }
        return Date().timeIntervalSince(timestamp)
    }
    
    func invalidateCache() {
        cachedContext = nil
        cacheTimestamp = nil
    }
}

extension Logger {
    static let appContext = Logger(subsystem: "com.kosmicapps.FocusOS", category: "AppContext")
}
