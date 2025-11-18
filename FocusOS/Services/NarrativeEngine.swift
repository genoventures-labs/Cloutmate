//
//  NarrativeEngine.swift
//  FocusOS
//
//  Phase 5: Narrative Engine - Story Generation Service
//  Generates weekly summaries from CPS deltas, concepts, focus sessions, and emotions
//

import Foundation
import SwiftData
import FocusOSShared
import os.log

@MainActor
final class NarrativeEngine {
    static let shared = NarrativeEngine()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "Narrative")
    private var config: AIConfig { AIConfigService.shared.config }
    
    private init() {}
    
    // MARK: - Weekly Summary Generation
    
    /// Generate a weekly narrative summary
    func generateWeeklySummary(
        endDate: Date = Date(),
        modelContext: ModelContext
    ) throws -> StoryToken {
        guard config.featureFlags.narrativeEnabled else {
            throw NarrativeError.featureDisabled
        }
        
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) else {
            throw NarrativeError.invalidDateRange
        }
        
        let range = DateInterval(start: startDate, end: endDate)
        
        // Gather data from all sources
        let concepts = ConceptTracker.shared.getConcepts(in: range, modelContext: modelContext)
        let focusStats = FocusSessionService.shared.getSessionStats(for: range, modelContext: modelContext)
        let cpsData = gatherCPSDeltas(in: range, modelContext: modelContext)
        let emotionalData = gatherEmotionalData(in: range, modelContext: modelContext)
        
        // Build narrative
        let narrative = buildNarrative(
            concepts: concepts,
            focusStats: focusStats,
            cpsData: cpsData,
            emotionalData: emotionalData,
            range: range
        )
        
        // Create StoryToken
        let storyToken = StoryToken(
            title: "Week of \(formatDate(startDate))",
            markdown: narrative.markdown,
            summary: narrative.summary,
            startDate: startDate,
            endDate: endDate,
            storyType: "weekly",
            themes: narrative.themes,
            emotionalTone: narrative.emotionalTone
        )
        
        // Add metrics
        storyToken.addMetric(key: "focusHours", value: focusStats.totalFocusTime / 3600)
        storyToken.addMetric(key: "focusCompletionRate", value: focusStats.completionRate)
        storyToken.addMetric(key: "aliveConcepts", value: Double(concepts.filter { $0.isAlive }.count))
        storyToken.topConcepts = concepts.prefix(5).map { $0.concept }
        
        modelContext.insert(storyToken)
        
        do {
            try modelContext.save()
            logger.info("Generated weekly summary: \(storyToken.title)")
        } catch {
            logger.error("Failed to save story token: \(error.localizedDescription)")
            throw NarrativeError.saveFailed
        }
        
        return storyToken
    }
    
    // MARK: - Narrative Building
    
    private func buildNarrative(
        concepts: [ConceptNode],
        focusStats: FocusSessionStats,
        cpsData: CPSAnalysis,
        emotionalData: EmotionalAnalysis,
        range: DateInterval
    ) -> (markdown: String, summary: String, themes: [String], emotionalTone: String) {
        var sections: [String] = []
        
        // Title
        sections.append("# Your Week in Focus")
        sections.append("")
        
        // Overview
        sections.append("## Overview")
        let aliveConcepts = concepts.filter { $0.isAlive }
        let overview = """
This week, you engaged with **\(aliveConcepts.count) active themes** across your workspace. \
\(focusStats.totalSessions > 0 ? "You completed **\(focusStats.totalSessions) focus sessions** totaling **\(formatHours(focusStats.totalFocusTime))** of deep work." : "")
"""
        sections.append(overview)
        sections.append("")
        
        // Live Themes
        if !aliveConcepts.isEmpty {
            sections.append("## 🔥 Live Themes")
            sections.append("Concepts showing high activity and relevance this week:")
            sections.append("")
            
            for (index, concept) in aliveConcepts.prefix(5).enumerated() {
                let scorePercent = Int(concept.relevanceWeight * 100)
                let emotionIndicator = concept.emotionalValence > 0.3 ? "✨" : concept.emotionalValence < -0.3 ? "⚠️" : "📌"
                sections.append("**\(index + 1). \(emotionIndicator) \(concept.concept)** (relevance: \(scorePercent)%)")
                sections.append("   - Mentioned **\(concept.mentionCount) times** across \(concept.contextTypes.joined(separator: ", "))")
                sections.append("")
            }
        }
        
        // Priority Trends
        if !cpsData.rising.isEmpty || !cpsData.falling.isEmpty {
            sections.append("## 📊 Priority Trends")
            
            if !cpsData.rising.isEmpty {
                sections.append("**Rising priorities:**")
                for item in cpsData.rising.prefix(3) {
                    sections.append("- \(item.title) (+\(Int(item.delta * 100))%)")
                }
                sections.append("")
            }
            
            if !cpsData.falling.isEmpty {
                sections.append("**Fading priorities:**")
                for item in cpsData.falling.prefix(2) {
                    sections.append("- \(item.title) (\(Int(item.delta * 100))%)")
                }
                sections.append("")
            }
        }
        
        // Focus Performance
        if focusStats.totalSessions > 0 {
            sections.append("## ⏱️ Focus Performance")
            let completionPct = Int(focusStats.completionRate * 100)
            let avgDuration = focusStats.averageSessionDuration / 60  // minutes
            
            sections.append("- **\(focusStats.totalSessions) sessions** completed")
            sections.append("- **\(completionPct)% completion rate**")
            sections.append("- **\(Int(avgDuration)) minutes** average session length")
            
            if let productiveHour = focusStats.mostProductiveTimeOfDay {
                let hourStr = formatHour(productiveHour)
                sections.append("- Most productive: **\(hourStr)**")
            }
            sections.append("")
        }
        
        // Emotional Tone
        sections.append("## 💫 Emotional Trajectory")
        let emotionalSummary = emotionalData.summary
        sections.append(emotionalSummary)
        sections.append("")
        
        // Key Insight
        let insight = generateKeyInsight(concepts: aliveConcepts, focusStats: focusStats, cpsData: cpsData)
        sections.append("## 💡 Key Insight")
        sections.append(insight)
        sections.append("")
        
        // Build markdown
        let markdown = sections.joined(separator: "\n")
        
        // Build summary
        let topTheme = aliveConcepts.first?.concept ?? "mixed themes"
        let summary = "\(aliveConcepts.count) active themes led by \(topTheme). \(focusStats.totalSessions) focus sessions, \(Int(focusStats.completionRate * 100))% completion."
        
        // Extract themes
        let themes = aliveConcepts.prefix(5).map { $0.concept }
        
        // Determine emotional tone
        let emotionalTone = emotionalData.tone
        
        return (markdown: markdown, summary: summary, themes: Array(themes), emotionalTone: emotionalTone)
    }
    
    private func generateKeyInsight(
        concepts: [ConceptNode],
        focusStats: FocusSessionStats,
        cpsData: CPSAnalysis
    ) -> String {
        // Generate a single-sentence insight
        
        if let topConcept = concepts.first, topConcept.mentionCount >= 5 {
            return "**\(topConcept.concept)** emerged as your dominant theme this week, appearing in \(topConcept.mentionCount) different contexts—this recurring focus suggests deepening engagement."
        }
        
        if focusStats.totalSessions >= 5 && focusStats.completionRate > 0.7 {
            return "You maintained strong focus discipline with \(focusStats.totalSessions) sessions and \(Int(focusStats.completionRate * 100))% completion—momentum is building."
        }
        
        if !cpsData.rising.isEmpty {
            let risingItem = cpsData.rising.first!
            return "**\(risingItem.title)** is gaining gravitational pull in your workspace—your attention and actions are naturally converging here."
        }
        
        return "Your work this week shows balanced engagement across multiple themes, suggesting an exploratory phase."
    }
    
    // MARK: - Data Gathering
    
    private func gatherCPSDeltas(
        in range: DateInterval,
        modelContext: ModelContext
    ) -> CPSAnalysis {
        // Get all priority scores
        let descriptor = FetchDescriptor<PriorityScore>(
            sortBy: [SortDescriptor(\.totalScore, order: .reverse)]
        )
        
        guard let scores = try? modelContext.fetch(descriptor) else {
            return CPSAnalysis(rising: [], falling: [], stable: [])
        }
        
        // For now, identify "rising" based on high scores and recent access
        // In a full implementation, we'd track historical scores
        let rising = scores.prefix(5).filter { score in
            let hoursSinceAccess = Date().timeIntervalSince(score.lastAccessed) / 3600
            return score.totalScore > 0.6 && hoursSinceAccess < 48
        }.map { score in
            CPSDelta(title: score.objectType, delta: score.totalScore - 0.5)
        }
        
        let falling = scores.filter { $0.totalScore < 0.3 }.prefix(3).map { score in
            CPSDelta(title: score.objectType, delta: score.totalScore - 0.5)
        }
        
        return CPSAnalysis(rising: Array(rising), falling: Array(falling), stable: [])
    }
    
    private func gatherEmotionalData(
        in range: DateInterval,
        modelContext: ModelContext
    ) -> EmotionalAnalysis {
        // Get AI messages in range
        let start = range.start
        let end = range.end
        let descriptor = FetchDescriptor<AIMessage>(
            predicate: #Predicate { message in
                message.timestamp != nil && message.timestamp! >= start && message.timestamp! <= end
            }
        )
        
        guard let messages = try? modelContext.fetch(descriptor) else {
            return EmotionalAnalysis(tone: "neutral", summary: "Insufficient emotional data for this period.")
        }
        
        let emotionalMessages = messages.filter { message in
            guard let emotion = message.emotion, !emotion.isEmpty else { return false }
            return message.emotionIntensity > 0.1
        }
        
        guard !emotionalMessages.isEmpty else {
            return EmotionalAnalysis(tone: "neutral", summary: "Your interactions this week maintained a steady, balanced tone.")
        }
        
        // Calculate average valence
        let avgValence = emotionalMessages.reduce(0.0) { $0 + $1.emotionScore } / Double(emotionalMessages.count)
        
        // Determine tone
        let tone: String
        let summary: String
        
        if avgValence > 0.3 {
            tone = "positive"
            summary = "Your week carried positive energy—conversations reflected optimism, progress, and forward momentum."
        } else if avgValence < -0.3 {
            tone = "challenging"
            summary = "This week touched on challenging topics—you engaged thoughtfully with complexity and obstacles."
        } else {
            tone = "neutral"
            summary = "Your interactions maintained a balanced, thoughtful tone—neither overly optimistic nor pessimistic."
        }
        
        return EmotionalAnalysis(tone: tone, summary: summary)
    }
    
    // MARK: - Formatting Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    private func formatHours(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds / 3600)
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatHour(_ hour: Int) -> String {
        if hour == 0 {
            return "12 AM"
        } else if hour < 12 {
            return "\(hour) AM"
        } else if hour == 12 {
            return "12 PM"
        } else {
            return "\(hour - 12) PM"
        }
    }
    
    // MARK: - Context Generation for AI
    
    /// Generate narrative summary for AI payload
    func generateNarrativeSummary(modelContext: ModelContext) -> NarrativeSummaryContext? {
        guard config.featureFlags.narrativeEnabled else { return nil }
        
        let now = Date()
        guard let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) else { return nil }
        
        let range = DateInterval(start: weekAgo, end: now)
        
        let concepts = ConceptTracker.shared.getConcepts(in: range, modelContext: modelContext)
        let aliveConcepts = concepts.filter { $0.isAlive }
        let focusStats = FocusSessionService.shared.getSessionStats(for: range, modelContext: modelContext)
        let cpsData = gatherCPSDeltas(in: range, modelContext: modelContext)
        let emotionalData = gatherEmotionalData(in: range, modelContext: modelContext)
        
        let keyThemes = aliveConcepts.prefix(5).map { $0.concept }
        let liveConcepts = aliveConcepts.prefix(3).map { "\($0.concept) (x\($0.mentionCount))" }
        
        var priorityTrends = ""
        if !cpsData.rising.isEmpty {
            priorityTrends += "Rising: \(cpsData.rising.prefix(2).map { $0.title }.joined(separator: ", "))"
        }
        if !cpsData.falling.isEmpty {
            if !priorityTrends.isEmpty { priorityTrends += " | " }
            priorityTrends += "Fading: \(cpsData.falling.prefix(2).map { $0.title }.joined(separator: ", "))"
        }
        
        let focusPerformance = focusStats.totalSessions > 0 ?
            "\(focusStats.totalSessions) sessions, \(Int(focusStats.completionRate * 100))% completion, \(formatHours(focusStats.totalFocusTime)) focused" : nil
        
        let keyInsight = aliveConcepts.first.map { concept in
            "\(concept.concept) is your dominant theme (x\(concept.mentionCount), \(Int(concept.relevanceWeight * 100))% relevance)"
        }
        
        return NarrativeSummaryContext(
            period: "This week",
            keyThemes: Array(keyThemes),
            liveConcepts: liveConcepts,
            priorityTrends: priorityTrends.isEmpty ? "Stable activity across workspace" : priorityTrends,
            emotionalTone: emotionalData.summary,
            focusPerformance: focusPerformance,
            keyInsight: keyInsight
        )
    }
    
    // MARK: - Artifact Generation
    
    /// Generate an Artifact from a narrative/story
    func generateArtifact(
        from storyToken: StoryToken,
        format: OutputFormat = .summary,
        modelContext: ModelContext
    ) -> FocusOSShared.Artifact {
        let artifact = FocusOSShared.Artifact(
            title: storyToken.title,
            content: storyToken.markdown,
            outputFormat: format,
            state: .final,
            publishedAt: storyToken.endDate,
            tags: storyToken.themes
        )
        
        // Copy metrics to custom properties
        for (key, value) in storyToken.metrics {
            artifact.customProperties[key] = String(value)
        }
        
        modelContext.insert(artifact)
        try? modelContext.save()
        
        logger.info("Generated artifact from story: \(storyToken.title)")
        
        return artifact
    }
    
    /// Generate artifact from weekly summary
    func generateArtifactFromWeeklySummary(
        format: OutputFormat = .summary,
        modelContext: ModelContext
    ) throws -> FocusOSShared.Artifact {
        let storyToken = try generateWeeklySummary(modelContext: modelContext)
        return generateArtifact(from: storyToken, format: format, modelContext: modelContext)
    }
    
    // MARK: - Retrieval
    
    func getRecentStories(limit: Int = 10, modelContext: ModelContext) -> [StoryToken] {
        var descriptor = FetchDescriptor<StoryToken>(
            predicate: #Predicate { $0.isArchived == false },
            sortBy: [SortDescriptor(\.endDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    /// Get recent artifacts
    func getRecentArtifacts(limit: Int = 10, modelContext: ModelContext) -> [FocusOSShared.Artifact] {
        // Fetch all artifacts and filter in memory - SwiftData predicates have issues with enum comparisons
        var descriptor = FetchDescriptor<FocusOSShared.Artifact>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit * 2 // Fetch more to account for filtering
        
        let allArtifacts = (try? modelContext.fetch(descriptor)) ?? []
        // Filter out archived artifacts in memory
        let nonArchived = allArtifacts.filter { $0.artifactState != .archived }
        return Array(nonArchived.prefix(limit))
    }
    
    // MARK: - Arc Detection
    
    /// Detect story arcs from activity patterns
    func detectArcs(
        in dateRange: DateInterval? = nil,
        modelContext: ModelContext
    ) async -> [StoryArc] {
        let range = dateRange ?? DateInterval(
            start: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date(),
            end: Date()
        )
        
        return await ArcDetectionService.shared.detectArcs(
            in: range,
            modelContext: modelContext
        )
    }
    
    // MARK: - Memory Weaving
    
    /// Weave connections to past insights
    func weaveMemory(
        currentText: String,
        currentContext: String? = nil,
        modelContext: ModelContext
    ) async -> [MemoryConnection] {
        return await MemoryWeavingService.shared.findConnections(
            currentText: currentText,
            currentContext: currentContext,
            modelContext: modelContext
        )
    }
}

// MARK: - Supporting Types

struct CPSAnalysis {
    let rising: [CPSDelta]
    let falling: [CPSDelta]
    let stable: [CPSDelta]
}

struct CPSDelta {
    let title: String
    let delta: Double
}

struct EmotionalAnalysis {
    let tone: String
    let summary: String
}

enum NarrativeError: LocalizedError {
    case featureDisabled
    case invalidDateRange
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .featureDisabled:
            return "Narrative Engine is not enabled."
        case .invalidDateRange:
            return "Invalid date range for narrative generation."
        case .saveFailed:
            return "Failed to save story token."
        }
    }
}

