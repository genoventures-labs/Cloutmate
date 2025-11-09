//
//  AnalyticsEngine.swift
//  Cloutmate
//
//  Phase 6.1 - Intelligence Layer Visibility
//  Aggregates metrics from all intelligence subsystems
//

import Foundation
import SwiftData
import Combine
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

    // Ritual metrics (Phase 8)
    let ritualCompletionRate: Double
    let morningRitualStreak: Int
    let eveningRitualStreak: Int
    let lastWeeklyReview: Date?
    let nudgeResponseRate: Double
    // Predictive cognition metrics (Phase 9)
    let latestForecast: FocusForecast?
    let driftEventsCount: Int
    let predictionAccuracy: Double
    let toneAdaptations: Int
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
        let ritualSummary = RitualAnalytics.shared.generateSummary(
            for: timeRange,
            customRange: customRange,
            modelContext: modelContext
        )
        let cognitionMetrics = gatherCognitionMetrics(modelContext: modelContext)
        
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
            graphDensity: graphMetrics.density,
            ritualCompletionRate: ritualSummary.completionRate,
            morningRitualStreak: ritualSummary.morningStreak,
            eveningRitualStreak: ritualSummary.eveningStreak,
            lastWeeklyReview: ritualSummary.lastWeeklyReview,
            nudgeResponseRate: ritualSummary.nudgeResponseRate,
            latestForecast: cognitionMetrics.forecast,
            driftEventsCount: cognitionMetrics.driftCount,
            predictionAccuracy: cognitionMetrics.accuracy,
            toneAdaptations: cognitionMetrics.adaptations
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
        
        // Filter tasks by date range - include tasks created or completed in range
        let tasks = allTasks.filter { task in
            let wasCreated = task.createdAt >= start && task.createdAt <= end
            let wasCompleted: Bool
            if let completedAt = task.completedAt {
                wasCompleted = task.status == .done && completedAt >= start && completedAt <= end
            } else {
                wasCompleted = task.status == .done && task.createdAt >= start && task.createdAt <= end
            }
            return wasCreated || wasCompleted
        }
        
        // Count completed tasks that finished in this range
        let completed = tasks.filter { task in
            guard task.status == .done else { return false }
            let completionDate = task.completedAt ?? task.createdAt
            return completionDate >= start && completionDate <= end
        }.count
        
        // Count created tasks in this range
        let created = tasks.filter { $0.createdAt >= start && $0.createdAt <= end }.count
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
        // Collect emotional data from multiple sources
        var emotionalDataPoints: [(timestamp: Date, valence: Double, intensity: Double, emotion: EmotionType)] = []
        var emotionCounts: [EmotionType: Int] = [:]
        
        // 1. Fetch user messages in the date range
        let messageDescriptor = FetchDescriptor<AIMessage>(
            predicate: #Predicate { message in
                message.role == "user" &&
                message.timestamp != nil &&
                message.timestamp! >= start &&
                message.timestamp! <= end &&
                message.content != nil &&
                !message.content!.isEmpty
            },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        
        if let messages = try? modelContext.fetch(messageDescriptor) {
            for message in messages {
                var emotionStr: String?
                var emotionScore: Double = 0.0
                var emotionIntensity: Double = 0.0
                
                // Use existing emotional data if available, otherwise analyze on-the-fly
                if let existingEmotion = message.emotion, !existingEmotion.isEmpty, message.emotionIntensity > 0.1 {
                    emotionStr = existingEmotion
                    emotionScore = message.emotionScore
                    emotionIntensity = message.emotionIntensity
                } else if let content = message.content, !content.isEmpty {
                    // Analyze message content if no emotional data exists
                    let snapshot = EmotionAnalyzer.analyzeTone(text: content)
                    emotionStr = snapshot.primaryEmotion.rawValue
                    emotionScore = snapshot.valence
                    emotionIntensity = snapshot.intensity
                    
                    // Update message with analyzed data for future use
                    message.emotion = emotionStr
                    message.emotionScore = emotionScore
                    message.emotionIntensity = emotionIntensity
                }
                
                if let emotion = emotionStr, emotionIntensity > 0.05 { // Lower threshold
                    let emotionType = mapEmotionStringToType(emotion)
                    emotionCounts[emotionType, default: 0] += 1
                    if let timestamp = message.timestamp {
                        emotionalDataPoints.append((timestamp: timestamp, valence: emotionScore, intensity: emotionIntensity, emotion: emotionType))
                    }
                }
            }
        }
        
        // 2. Include Journal entries
        let journalDescriptor = FetchDescriptor<Journal>(
            predicate: #Predicate { journal in
                journal.createdAt >= start && journal.createdAt <= end &&
                (!journal.content.isEmpty || !journal.title.isEmpty)
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        
        if let journals = try? modelContext.fetch(journalDescriptor) {
            for journal in journals {
                let content = "\(journal.title) \(journal.content)".trimmingCharacters(in: .whitespacesAndNewlines)
                if !content.isEmpty {
                    let snapshot = EmotionAnalyzer.analyzeTone(text: content)
                    if snapshot.intensity > 0.05 {
                        let emotionType = mapEmotionStringToType(snapshot.primaryEmotion.rawValue)
                        emotionCounts[emotionType, default: 0] += 1
                        emotionalDataPoints.append((timestamp: journal.createdAt, valence: snapshot.valence, intensity: snapshot.intensity, emotion: emotionType))
                    }
                }
            }
        }
        
        // 3. Include ReflectionNotes
        let reflectionDescriptor = FetchDescriptor<ReflectionNote>(
            predicate: #Predicate { note in
                note.timestamp >= start && note.timestamp <= end &&
                !note.response.isEmpty
            },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        
        if let reflections = try? modelContext.fetch(reflectionDescriptor) {
            for reflection in reflections {
                var valence = reflection.sentimentScore
                var emotionStr = reflection.emotionTone
                
                // Analyze if not already done
                if valence == 0.0 || emotionStr.isEmpty {
                    let snapshot = EmotionAnalyzer.analyzeTone(text: reflection.response)
                    valence = snapshot.valence
                    emotionStr = snapshot.primaryEmotion.rawValue
                    reflection.sentimentScore = valence
                    reflection.emotionTone = emotionStr
                }
                
                if abs(valence) > 0.05 {
                    let emotionType = mapEmotionStringToType(emotionStr)
                    emotionCounts[emotionType, default: 0] += 1
                    emotionalDataPoints.append((timestamp: reflection.timestamp, valence: valence, intensity: abs(valence), emotion: emotionType))
                }
            }
        }
        
        // 4. Include Notes (from CloutmateShared)
        let noteDescriptor = FetchDescriptor<CloutmateShared.Note>(
            predicate: #Predicate { note in
                note.createdAt >= start && note.createdAt <= end &&
                (!note.markdown.isEmpty || !note.title.isEmpty)
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        
        if let notes = try? modelContext.fetch(noteDescriptor) {
            for note in notes {
                let content = "\(note.title) \(note.markdown)".trimmingCharacters(in: .whitespacesAndNewlines)
                if !content.isEmpty {
                    let snapshot = EmotionAnalyzer.analyzeTone(text: content)
                    if snapshot.intensity > 0.05 {
                        let emotionType = mapEmotionStringToType(snapshot.primaryEmotion.rawValue)
                        emotionCounts[emotionType, default: 0] += 1
                        emotionalDataPoints.append((timestamp: note.createdAt, valence: snapshot.valence, intensity: snapshot.intensity, emotion: emotionType))
                    }
                }
            }
        }
        
        // If no data found, return neutral
        guard !emotionalDataPoints.isEmpty else {
            return (EmotionalSnapshot.neutral, .stable, .neutral)
        }
        
        // Determine dominant emotion
        let dominantEmotion = emotionCounts.max(by: { $0.value < $1.value })?.key ?? .neutral
        
        // Calculate averages
        let allValences = emotionalDataPoints.map { $0.valence }
        let allIntensities = emotionalDataPoints.map { $0.intensity }
        let avgValence = allValences.reduce(0, +) / Double(allValences.count)
        let avgIntensity = allIntensities.reduce(0, +) / Double(allIntensities.count)
        
        // Determine trend by comparing first half vs second half (sorted by timestamp)
        let sortedDataPoints = emotionalDataPoints.sorted { $0.timestamp < $1.timestamp }
        let sortedValences = sortedDataPoints.map { $0.valence }
        
        let midpoint = sortedValences.count / 2
        let firstHalfValences = Array(sortedValences.prefix(midpoint))
        let secondHalfValences = Array(sortedValences.suffix(sortedValences.count - midpoint))
        
        let firstHalfAvg = firstHalfValences.isEmpty ? 0.0 : firstHalfValences.reduce(0, +) / Double(firstHalfValences.count)
        let secondHalfAvg = secondHalfValences.isEmpty ? 0.0 : secondHalfValences.reduce(0, +) / Double(secondHalfValences.count)
        
        let trend: EmotionalTrend
        let delta = secondHalfAvg - firstHalfAvg
        if abs(delta) < 0.1 {
            trend = .stable
        } else if delta > 0.2 {
            trend = .improving
        } else if delta < -0.2 {
            trend = .declining
        } else {
            // Check for volatility
            let variance = allValences.map { pow($0 - avgValence, 2) }.reduce(0, +) / Double(allValences.count)
            trend = variance > 0.3 ? .volatile : .stable
        }
        
        // Map EmotionType to EmotionTone for snapshot
        let primaryTone = mapEmotionTypeToTone(dominantEmotion)
        
        let snapshot = EmotionalSnapshot(
            primaryEmotion: primaryTone,
            secondaryEmotion: nil,
            valence: avgValence,
            intensity: avgIntensity,
            keywords: []
        )
        
        // Save updated messages and reflections
        try? modelContext.save()
        
        return (snapshot, trend, dominantEmotion)
    }
    
    private func mapEmotionStringToType(_ emotion: String) -> EmotionType {
        let lowercased = emotion.lowercased()
        switch lowercased {
        case "joyful", "happy", "glad":
            return .joyful
        case "excited", "enthusiastic", "energized":
            return .excited
        case "calm", "peaceful", "relaxed":
            return .calm
        case "frustrated", "annoyed", "irritated":
            return .frustrated
        case "anxious", "worried", "nervous", "stressed":
            return .anxious
        case "motivated", "determined", "focused":
            return .motivated
        case "overwhelmed", "burdened":
            return .overwhelmed
        default:
            return .neutral
        }
    }
    
    private func mapEmotionTypeToTone(_ emotion: EmotionType) -> EmotionTone {
        switch emotion {
        case .joyful:
            return .joyful
        case .excited:
            return .excited
        case .calm:
            return .calm
        case .frustrated:
            return .frustrated
        case .anxious:
            return .overwhelmed // Closest match
        case .motivated:
            return .determined
        case .overwhelmed:
            return .overwhelmed
        case .neutral:
            return .neutral
        }
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
    
    /// Backfill emotional data for all existing content
    func backfillEmotionalData(modelContext: ModelContext) async {
        let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "AnalyticsEngine")
        logger.info("Starting emotional data backfill...")
        
        var processedCount = 0
        
        // Backfill AIMessages
        let messageDescriptor = FetchDescriptor<AIMessage>(
            predicate: #Predicate { message in
                message.role == "user" &&
                message.content != nil &&
                !message.content!.isEmpty
            }
        )
        
        if let messages = try? modelContext.fetch(messageDescriptor) {
            for message in messages {
                // Only process if missing or low-quality emotional data
                let needsBackfill = message.emotion == nil || 
                                   message.emotion!.isEmpty || 
                                   message.emotionIntensity <= 0.1
                
                if needsBackfill, let content = message.content, !content.isEmpty {
                    let snapshot = EmotionAnalyzer.analyzeTone(text: content)
                    message.emotion = snapshot.primaryEmotion.rawValue
                    message.emotionScore = snapshot.valence
                    message.emotionIntensity = snapshot.intensity
                    processedCount += 1
                }
            }
        }
        
        // Backfill Journals
        let journalDescriptor = FetchDescriptor<Journal>()
        if let journals = try? modelContext.fetch(journalDescriptor) {
            for journal in journals {
                let content = "\(journal.title) \(journal.content)"
                if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let snapshot = EmotionAnalyzer.analyzeTone(text: content)
                    // Journals don't have emotion fields, but we can use them in trend calculation
                    processedCount += 1
                }
            }
        }
        
        // Backfill ReflectionNotes
        let reflectionDescriptor = FetchDescriptor<ReflectionNote>()
        if let reflections = try? modelContext.fetch(reflectionDescriptor) {
            for reflection in reflections {
                if reflection.sentimentScore == 0.0 && !reflection.response.isEmpty {
                    let snapshot = EmotionAnalyzer.analyzeTone(text: reflection.response)
                    reflection.sentimentScore = snapshot.valence
                    reflection.emotionTone = snapshot.primaryEmotion.rawValue
                    processedCount += 1
                }
            }
        }
        
        // Save all changes
        do {
            try modelContext.save()
            logger.info("Backfilled emotional data for \(processedCount) items")
        } catch {
            logger.error("Failed to save backfilled emotional data: \(error.localizedDescription)")
        }
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

    /// Get ritual completion trend over time
    func getRitualCompletionTrend(
        days: Int,
        modelContext: ModelContext
    ) -> [(date: Date, completionRate: Double)] {
        RitualAnalytics.shared.completionTrend(days: days, modelContext: modelContext)
    }

    // MARK: - Cognition Metrics (Phase 9)

    private func gatherCognitionMetrics(
        modelContext: ModelContext
    ) -> (forecast: FocusForecast?, driftCount: Int, accuracy: Double, adaptations: Int) {
        var forecastDescriptor = FetchDescriptor<FocusForecast>(
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        )
        forecastDescriptor.fetchLimit = 1
        let latestForecast = try? modelContext.fetch(forecastDescriptor).first

        let driftWindowStart = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date().addingTimeInterval(-86_400)
        let driftDescriptor = FetchDescriptor<DriftEvent>(
            predicate: #Predicate { event in
                event.detectedAt >= driftWindowStart
            }
        )
        let driftEvents = (try? modelContext.fetch(driftDescriptor)) ?? []

        let accuracy = CognitionAnalytics.shared.calculateForecastAccuracy(days: 7, modelContext: modelContext)
        let adaptations = ToneProfileCache.shared.recentAdaptationCount()

        return (latestForecast ?? nil, driftEvents.count, accuracy, adaptations)
    }
}

