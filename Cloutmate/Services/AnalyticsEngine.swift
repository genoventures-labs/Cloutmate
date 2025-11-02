//
//  AnalyticsEngine.swift
//  Cloutmate
//
//  Phase 6.1 - Intelligence Layer Visibility
//  Aggregates metrics from all intelligence subsystems
//

import Foundation
import SwiftData
import CloutmateShared
import os.log

/// Aggregated metrics snapshot for a time period
struct AnalyticsSnapshot: Identifiable, Sendable {
    let id = UUID()
    let startDate: Date
    let endDate: Date
    
    // Productivity metrics
    let tasksCompleted: Int
    let tasksCreated: Int
    let completionRate: Double
    let avgPriorityScore: Double
    let topPriorityItems: [String]
    
    // Focus metrics
    let focusSessionsCount: Int
    let totalFocusMinutes: Int
    let avgSessionLength: Double
    let focusCompletionRate: Double
    
    // Emotional metrics
    let emotionalSnapshot: EmotionalSnapshot
    let emotionalTrend: EmotionalTrend
    let dominantEmotion: EmotionType
    
    // Content metrics
    let postsPublished: Int
    let draftsCreated: Int
    let avgEngagement: Double
    let topPerformingPosts: [String]
    
    // Learning metrics
    let feedbackEventsCount: Int
    let positiveEvents: Int
    let negativeEvents: Int
    let learningScore: Double
    
    // Graph metrics (Phase 6)
    let activeThemes: Int
    let memoryNodes: Int
    let conceptCount: Int
    let graphDensity: Double
}

/// Emotional trend over time
enum EmotionalTrend: String, Codable, Sendable {
    case improving = "improving"
    case stable = "stable"
    case declining = "declining"
    case volatile = "volatile"
}

/// Emotion type for analytics (duplicated from EmotionalSnapshot for independence)
enum EmotionType: String, Codable, Sendable {
    case joyful = "joyful"
    case excited = "excited"
    case calm = "calm"
    case neutral = "neutral"
    case frustrated = "frustrated"
    case anxious = "anxious"
    case motivated = "motivated"
    case overwhelmed = "overwhelmed"
}

/// Time range for analytics
enum AnalyticsTimeRange: String, CaseIterable, Sendable {
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case thisQuarter = "This Quarter"
    case thisYear = "This Year"
    case custom = "Custom"
    
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .today:
            let start = calendar.startOfDay(for: now)
            return (start, now)
            
        case .thisWeek:
            let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            return (start, now)
            
        case .thisMonth:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            return (start, now)
            
        case .thisQuarter:
            let month = calendar.component(.month, from: now)
            let quarterStart = ((month - 1) / 3) * 3 + 1
            let start = calendar.date(from: DateComponents(year: calendar.component(.year, from: now), month: quarterStart))!
            return (start, now)
            
        case .thisYear:
            let start = calendar.date(from: DateComponents(year: calendar.component(.year, from: now)))!
            return (start, now)
            
        case .custom:
            return (now, now) // Placeholder
        }
    }
}

@MainActor
final class AnalyticsEngine {
    static let shared = AnalyticsEngine()
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "Analytics")
    
    private init() {}
    
    // MARK: - Main Analytics Snapshot
    
    /// Generate comprehensive analytics snapshot for time range
    func generateSnapshot(
        for timeRange: AnalyticsTimeRange,
        customRange: (Date, Date)? = nil,
        modelContext: ModelContext
    ) -> AnalyticsSnapshot {
        let (startDate, endDate) = customRange ?? timeRange.dateRange
        
        logger.info("Generating analytics snapshot for \(timeRange.rawValue)")
        
        // Gather all metrics in parallel
        let productivityMetrics = gatherProductivityMetrics(start: startDate, end: endDate, modelContext: modelContext)
        let focusMetrics = gatherFocusMetrics(start: startDate, end: endDate, modelContext: modelContext)
        let emotionalMetrics = gatherEmotionalMetrics(start: startDate, end: endDate, modelContext: modelContext)
        let contentMetrics = gatherContentMetrics(start: startDate, end: endDate, modelContext: modelContext)
        let learningMetrics = gatherLearningMetrics(start: startDate, end: endDate, modelContext: modelContext)
        let graphMetrics = gatherGraphMetrics(modelContext: modelContext)
        
        return AnalyticsSnapshot(
            startDate: startDate,
            endDate: endDate,
            tasksCompleted: productivityMetrics.completed,
            tasksCreated: productivityMetrics.created,
            completionRate: productivityMetrics.completionRate,
            avgPriorityScore: productivityMetrics.avgPriority,
            topPriorityItems: productivityMetrics.topItems,
            focusSessionsCount: focusMetrics.sessionCount,
            totalFocusMinutes: focusMetrics.totalMinutes,
            avgSessionLength: focusMetrics.avgLength,
            focusCompletionRate: focusMetrics.completionRate,
            emotionalSnapshot: emotionalMetrics.snapshot,
            emotionalTrend: emotionalMetrics.trend,
            dominantEmotion: emotionalMetrics.dominant,
            postsPublished: contentMetrics.published,
            draftsCreated: contentMetrics.drafts,
            avgEngagement: contentMetrics.avgEngagement,
            topPerformingPosts: contentMetrics.topPosts,
            feedbackEventsCount: learningMetrics.totalEvents,
            positiveEvents: learningMetrics.positive,
            negativeEvents: learningMetrics.negative,
            learningScore: learningMetrics.score,
            activeThemes: graphMetrics.activeThemes,
            memoryNodes: graphMetrics.nodes,
            conceptCount: graphMetrics.concepts,
            graphDensity: graphMetrics.density
        )
    }
    
    // MARK: - Productivity Metrics
    
    private func gatherProductivityMetrics(
        start: Date,
        end: Date,
        modelContext: ModelContext
    ) -> (completed: Int, created: Int, completionRate: Double, avgPriority: Double, topItems: [String]) {
        let taskDescriptor = FetchDescriptor<CloutmateShared.Task>()
        
        guard let allTasks = try? modelContext.fetch(taskDescriptor) else {
            return (0, 0, 0.0, 0.0, [])
        }
        
        let tasks = allTasks // Simplified - filter by date later if createdAt is optional
        
        let completed = tasks.filter { $0.status == .done }.count
        let created = tasks.count
        let completionRate = created > 0 ? Double(completed) / Double(created) : 0.0
        
        // Get priority scores
        let priorityScores = PriorityEngine.shared.getTopObjects(
            ofType: "Task",
            limit: 10,
            modelContext: modelContext
        )
        
        let avgPriority = priorityScores.isEmpty ? 0.0 : priorityScores.map { $0.score }.reduce(0, +) / Double(priorityScores.count)
        let topItems = priorityScores.prefix(5).map { $0.title }
        
        return (completed, created, completionRate, avgPriority, topItems)
    }
    
    // MARK: - Focus Metrics
    
    private func gatherFocusMetrics(
        start: Date,
        end: Date,
        modelContext: ModelContext
    ) -> (sessionCount: Int, totalMinutes: Int, avgLength: Double, completionRate: Double) {
        let sessionDescriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { session in
                session.startTime >= start && session.startTime <= end
            }
        )
        
        guard let sessions = try? modelContext.fetch(sessionDescriptor) else {
            return (0, 0, 0.0, 0.0)
        }
        
        let completedSessions = sessions.filter { $0.status == .completed }
        let totalMinutes = completedSessions.reduce(into: 0) { $0 += Int($1.plannedDuration / 60) }
        let avgLength = sessions.isEmpty ? 0.0 : Double(totalMinutes) / Double(sessions.count)
        let completionRate = sessions.isEmpty ? 0.0 : Double(completedSessions.count) / Double(sessions.count)
        
        return (sessions.count, totalMinutes, avgLength, completionRate)
    }
    
    // MARK: - Emotional Metrics
    
    private func gatherEmotionalMetrics(
        start: Date,
        end: Date,
        modelContext: ModelContext
    ) -> (snapshot: EmotionalSnapshot, trend: EmotionalTrend, dominant: EmotionType) {
        // Simplified - emotion tracking can be enhanced with ConversationDigest
        let conversationDescriptor = FetchDescriptor<AIConversation>()
        
        guard let conversations = try? modelContext.fetch(conversationDescriptor),
              !conversations.isEmpty else {
            return (EmotionalSnapshot.neutral, .stable, .neutral)
        }
        
        // Simplified - no emotional tracking on AIConversation directly yet
        // Can be enhanced with ConversationDigest emotional data
        var emotionCounts: [EmotionType: Int] = [.neutral: conversations.count]
        var valences: [Double] = [0.0]
        
        let dominantEmotion = emotionCounts.max(by: { $0.value < $1.value })?.key ?? .neutral
        let avgValence = valences.reduce(0, +) / Double(valences.count)
        
        // Determine trend - simplified without direct emotional data
        let midpoint = conversations.count / 2
        
        // Default to stable trend
        let trend: EmotionalTrend = .stable
        
        // Simplified emotion snapshot for now
        let snapshot = EmotionalSnapshot(
            primaryEmotion: .neutral,  // Convert EmotionType to EmotionTone as needed
            secondaryEmotion: nil,
            valence: avgValence,
            intensity: abs(avgValence),
            keywords: []
        )
        
        return (snapshot, trend, .neutral)
    }
    
    // MARK: - Content Metrics
    
    private func gatherContentMetrics(
        start: Date,
        end: Date,
        modelContext: ModelContext
    ) -> (published: Int, drafts: Int, avgEngagement: Double, topPosts: [String]) {
        let postDescriptor = FetchDescriptor<Post>(
            predicate: #Predicate { post in
                post.createdAt >= start && post.createdAt <= end
            }
        )
        
        guard let posts = try? modelContext.fetch(postDescriptor) else {
            return (0, 0, 0.0, [])
        }
        
        let published = posts.filter { $0.status == "published" }.count
        let drafts = posts.filter { $0.status == "draft" }.count
        
        // Calculate engagement (likes + comments)
        let publishedPosts = posts.filter { $0.status == "published" }
        let engagements = publishedPosts.map { post -> Double in
            return Double((post.likes ?? 0) + (post.comments ?? 0))
        }
        
        let avgEngagement = engagements.isEmpty ? 0.0 : engagements.reduce(0, +) / Double(engagements.count)
        
        // Top performing posts - simplified to avoid compiler timeout
        var sortedPosts: [Post] = []
        for post in publishedPosts {
            let engagement = (post.likes ?? 0) + (post.comments ?? 0)
            if sortedPosts.isEmpty || engagement > ((sortedPosts.first?.likes ?? 0) + (sortedPosts.first?.comments ?? 0)) {
                sortedPosts.insert(post, at: 0)
            } else {
                sortedPosts.append(post)
            }
        }
        let topPosts = sortedPosts.prefix(5).map { $0.caption }
        
        return (published, drafts, avgEngagement, Array(topPosts))
    }
    
    // MARK: - Learning Metrics
    
    private func gatherLearningMetrics(
        start: Date,
        end: Date,
        modelContext: ModelContext
    ) -> (totalEvents: Int, positive: Int, negative: Int, score: Double) {
        let feedbackDescriptor = FetchDescriptor<AIFeedbackEvent>()
        
        guard let allEvents = try? modelContext.fetch(feedbackDescriptor) else {
            return (0, 0, 0, 0.0)
        }
        
        let events = allEvents.filter { event in
            event.createdAt >= start && event.createdAt <= end
        }
        
        // Use itemsAffected as a proxy for success/productivity
        let totalItems = events.reduce(0) { $0 + $1.itemsAffected }
        let learningScore = events.isEmpty ? 0.0 : Double(totalItems) / Double(events.count * 5)
        
        return (events.count, events.count, 0, min(1.0, learningScore))
    }
    
    // MARK: - Graph Metrics
    
    private func gatherGraphMetrics(
        modelContext: ModelContext
    ) -> (activeThemes: Int, nodes: Int, concepts: Int, density: Double) {
        // Theme count
        let themes = MemoryGraphService.shared.getActiveThemes(modelContext: modelContext)
        
        // Node count
        let nodeDescriptor = FetchDescriptor<MemoryNode>()
        let nodes = (try? modelContext.fetch(nodeDescriptor))?.count ?? 0
        
        // Edge count
        let edgeDescriptor = FetchDescriptor<MemoryEdge>()
        let edges = (try? modelContext.fetch(edgeDescriptor))?.count ?? 0
        
        // Concept count (all concepts)
        let conceptDescriptor = FetchDescriptor<ConceptNode>()
        let concepts = (try? modelContext.fetch(conceptDescriptor))?.count ?? 0
        
        // Graph density (edges / possible edges)
        let density = nodes > 1 ? Double(edges) / Double(nodes * (nodes - 1) / 2) : 0.0
        
        return (themes.count, nodes, concepts, density)
    }
    
    // MARK: - Time Series Data
    
    /// Get productivity trend over time
    func getProductivityTrend(
        days: Int,
        modelContext: ModelContext
    ) -> [(date: Date, completionRate: Double)] {
        var trends: [(Date, Double)] = []
        let calendar = Calendar.current
        
        for dayOffset in 0..<days {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            let metrics = gatherProductivityMetrics(
                start: startOfDay,
                end: endOfDay,
                modelContext: modelContext
            )
            
            trends.append((startOfDay, metrics.completionRate))
        }
        
        return trends.reversed()
    }
    
    /// Get emotional valence trend over time
    func getEmotionalTrend(
        days: Int,
        modelContext: ModelContext
    ) -> [(date: Date, valence: Double, emotion: EmotionType)] {
        var trends: [(Date, Double, EmotionType)] = []
        let calendar = Calendar.current
        
        for dayOffset in 0..<days {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            let metrics = gatherEmotionalMetrics(
                start: startOfDay,
                end: endOfDay,
                modelContext: modelContext
            )
            
            trends.append((startOfDay, metrics.snapshot.valence, metrics.dominant))
        }
        
        return trends.reversed()
    }
    
    /// Get focus time trend over time
    func getFocusTrend(
        days: Int,
        modelContext: ModelContext
    ) -> [(date: Date, minutes: Int)] {
        var trends: [(Date, Int)] = []
        let calendar = Calendar.current
        
        for dayOffset in 0..<days {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            let metrics = gatherFocusMetrics(
                start: startOfDay,
                end: endOfDay,
                modelContext: modelContext
            )
            
            trends.append((startOfDay, metrics.totalMinutes))
        }
        
        return trends.reversed()
    }
}

