//
//  AIReflectionService.swift
//  FocusOS
//
//  Phase 6.1 - Intelligence Layer Reflection & Introspection
//  Enables Aurora to analyze and reflect on user patterns, not just execute actions
//

import Foundation
import SwiftData
import Combine
import os.log

/// Service for introspective queries about user patterns and analytics
@MainActor
final class AIReflectionService {
    static let shared = AIReflectionService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.focusos", category: "AIReflection")
    
    private init() {}
    
    // MARK: - Reflection Query Types
    
    enum ReflectionQuery: String, Codable {
        case productivityPatterns = "productivity_patterns"
        case emotionalTrends = "emotional_trends"
        case focusEffectiveness = "focus_effectiveness"
        case learningProgress = "learning_progress"
        case recurringThemes = "recurring_themes"
        case cognitiveState = "cognitive_state"
        case weekOverview = "week_overview"
        case monthOverview = "month_overview"
        case detectedPatterns = "detected_patterns"
        case workingStyle = "working_style"
    }
    
    // MARK: - Main Reflection Router
    
    /// Main router function to handle all reflection intents
    func reflect(
        on intent: ReflectionIntent,
        timeRange: AnalyticsTimeRange,
        modelContext: ModelContext
    ) async -> String {
        logger.info("Processing reflection intent: \(intent.rawValue)")
        
        switch intent {
        case .productivityPatterns:
            return await reflectOnProductivity(timeRange: timeRange, modelContext: modelContext)
        case .emotionalTrends:
            return await reflectOnEmotions(timeRange: timeRange, modelContext: modelContext)
        case .focusEffectiveness:
            return await reflectOnFocus(timeRange: timeRange, modelContext: modelContext)
        case .learningProgress:
            return await reflectOnLearning(timeRange: timeRange, modelContext: modelContext)
        case .recurringThemes:
            return await reflectOnThemes(timeRange: timeRange, modelContext: modelContext)
        case .cognitiveState:
            return await reflectOnCognitiveState(modelContext: modelContext)
        case .weekOverview:
            return await reflectOnWeekOverview(modelContext: modelContext)
        case .monthOverview:
            // Month overview uses week overview as base with extended timeRange
            return await reflectOnWeekOverview(modelContext: modelContext)
        case .detectedPatterns:
            // Detected patterns are surfaced through themes and productivity
            let productivity = await reflectOnProductivity(timeRange: timeRange, modelContext: modelContext)
            let themes = await reflectOnThemes(timeRange: timeRange, modelContext: modelContext)
            return """
            ## Detected Patterns
            
            \(productivity)
            
            \(themes)
            """
        case .workingStyle:
            // Working style combines productivity, focus, and emotional insights
            let productivity = await reflectOnProductivity(timeRange: timeRange, modelContext: modelContext)
            let focus = await reflectOnFocus(timeRange: timeRange, modelContext: modelContext)
            let emotional = await reflectOnEmotions(timeRange: timeRange, modelContext: modelContext)
            return """
            ## Your Working Style (\(timeRange.displayName))
            
            \(productivity)
            
            \(focus)
            
            \(emotional)
            """
        }
    }
    
    // MARK: - Specific Reflection Functions
    
    /// Reflects on user's productivity patterns
    func reflectOnProductivity(
        timeRange: AnalyticsTimeRange,
        modelContext: ModelContext
    ) async -> String {
        logger.info("Reflecting on productivity patterns for \(timeRange.displayName)")
        
        let snapshot = await AnalyticsEngine.shared.generateSnapshot(
            for: timeRange,
            modelContext: modelContext
        )
        
        var reflection = "## Productivity Reflection (\(timeRange.displayName))\n\n"
        
        // Completion analysis
        let completionPct = Int(snapshot.completionRate * 100)
        reflection += "**Task Completion:** You've completed \(snapshot.tasksCompleted) out of \(snapshot.tasksCreated) tasks (\(completionPct)%).\n"
        
        if snapshot.completionRate > 0.7 {
            reflection += "This is strong momentum—you're maintaining good follow-through.\n\n"
        } else if snapshot.completionRate > 0.4 {
            reflection += "You're making steady progress. Consider starting fewer tasks or breaking them down smaller.\n\n"
        } else {
            reflection += "Many tasks remain open. Let's focus on closing a few high-priority items first.\n\n"
        }
        
        // Priority analysis
        if snapshot.avgPriorityScore > 0.7 {
            reflection += "**Focus Quality:** Your top priorities (avg score: \(String(format: "%.2f", snapshot.avgPriorityScore))) show strong gravitational pull. These items are getting consistent attention.\n\n"
        } else {
            reflection += "**Focus Quality:** Your priority scores are more distributed. Consider identifying 2-3 core focuses.\n\n"
        }
        
        // Top items
        if !snapshot.topPriorityItems.isEmpty {
            reflection += "**Current Gravitational Centers:**\n"
            for (index, item) in snapshot.topPriorityItems.prefix(3).enumerated() {
                reflection += "\(index + 1). \(item)\n"
            }
            reflection += "\n"
        }
        
        return reflection
    }
    
    /// Reflects on emotional trends
    func reflectOnEmotions(
        timeRange: AnalyticsTimeRange,
        modelContext: ModelContext
    ) async -> String {
        logger.info("Reflecting on emotional trends for \(timeRange.displayName)")
        
        let snapshot = await AnalyticsEngine.shared.generateSnapshot(
            for: timeRange,
            modelContext: modelContext
        )
        
        var reflection = "## Emotional Reflection (\(timeRange.displayName))\n\n"
        
        let valence = snapshot.emotionalSnapshot.valence
        let intensity = snapshot.emotionalSnapshot.intensity
        
        // Valence interpretation
        reflection += "**Emotional Tone:** "
        if valence > 0.5 {
            reflection += "Positive and energized"
        } else if valence > 0 {
            reflection += "Stable and steady"
        } else if valence > -0.5 {
            reflection += "Reflective and contemplative"
        } else {
            reflection += "Challenging and intense"
        }
        reflection += " (valence: \(String(format: "%.2f", valence)))\n\n"
        
        // Intensity interpretation
        reflection += "**Emotional Intensity:** "
        if intensity > 0.7 {
            reflection += "High—you're feeling things strongly right now.\n"
        } else if intensity > 0.4 {
            reflection += "Moderate—balanced emotional energy.\n"
        } else {
            reflection += "Low—you're in a calm, neutral state.\n"
        }
        
        // Trend analysis
        reflection += "\n**Trend:** "
        switch snapshot.emotionalTrend {
        case .improving:
            reflection += "Improving ↗️—your emotional state is trending more positive."
        case .stable:
            reflection += "Stable →—consistent emotional patterns."
        case .declining:
            reflection += "Declining ↘️—you might be experiencing more stress or fatigue."
        case .volatile:
            reflection += "Volatile ↕️—experiencing emotional swings. Consider what's driving the variability."
        }
        reflection += "\n\n"
        
        // Dominant emotion
        reflection += "**Dominant Emotion:** \(snapshot.dominantEmotion.rawValue.capitalized)\n"
        
        return reflection
    }
    
    /// Reflects on focus effectiveness
    func reflectOnFocus(
        timeRange: AnalyticsTimeRange,
        modelContext: ModelContext
    ) async -> String {
        logger.info("Reflecting on focus effectiveness for \(timeRange.displayName)")
        
        let snapshot = await AnalyticsEngine.shared.generateSnapshot(
            for: timeRange,
            modelContext: modelContext
        )
        
        var reflection = "## Focus Reflection (\(timeRange.displayName))\n\n"
        
        // Session count
        reflection += "**Sessions:** You completed \(snapshot.focusSessionsCount) focus session\(snapshot.focusSessionsCount == 1 ? "" : "s")"
        if snapshot.focusSessionsCount > 0 {
            let hours = Double(snapshot.totalFocusMinutes) / 60.0
            reflection += ", totaling \(String(format: "%.1f", hours)) hours of deep work.\n\n"
            
            // Average length
            reflection += "**Average Session Length:** \(Int(snapshot.avgSessionLength)) minutes"
            if snapshot.avgSessionLength >= 90 {
                reflection += "—excellent deep work blocks.\n"
            } else if snapshot.avgSessionLength >= 45 {
                reflection += "—solid focus periods.\n"
            } else {
                reflection += "—consider longer sessions for deeper flow.\n"
            }
            
            // Completion rate
            let focusCompletionPct = Int(snapshot.focusCompletionRate * 100)
            reflection += "\n**Completion Rate:** \(focusCompletionPct)%"
            if snapshot.focusCompletionRate > 0.8 {
                reflection += "—you're following through on your focus objectives.\n"
            } else if snapshot.focusCompletionRate > 0.5 {
                reflection += "—room to improve on completing what you start.\n"
            } else {
                reflection += "—many sessions interrupted. Protect your focus time.\n"
            }
        } else {
            reflection += ".\n\n**Observation:** No formal focus sessions yet. Starting even one 45-minute block can transform your productivity.\n"
        }
        
        return reflection
    }
    
    /// Reflects on learning and growth
    func reflectOnLearning(
        timeRange: AnalyticsTimeRange,
        modelContext: ModelContext
    ) async -> String {
        logger.info("Reflecting on learning progress for \(timeRange.displayName)")
        
        let snapshot = await AnalyticsEngine.shared.generateSnapshot(
            for: timeRange,
            modelContext: modelContext
        )
        
        var reflection = "## Learning Reflection (\(timeRange.displayName))\n\n"
        
        // Learning score
        let scorePct = Int(snapshot.learningScore)
        reflection += "**Learning Score:** \(scorePct)%"
        if snapshot.learningScore > 70 {
            reflection += "—I'm learning rapidly from your patterns.\n"
        } else if snapshot.learningScore > 40 {
            reflection += "—building a solid understanding of your workflow.\n"
        } else {
            reflection += "—still learning your patterns. More interactions help me adapt.\n"
        }
        
        // Feedback events
        reflection += "\n**Feedback Events:** \(snapshot.feedbackEventsCount) action\(snapshot.feedbackEventsCount == 1 ? "" : "s") logged"
        if snapshot.feedbackEventsCount > 0 {
            let positivePct = Int((Double(snapshot.positiveEvents) / Double(snapshot.feedbackEventsCount)) * 100)
            reflection += " (\(positivePct)% successful)\n"
            
            if positivePct > 80 {
                reflection += "Most actions are succeeding—the system is well-tuned to your needs.\n"
            } else if positivePct > 50 {
                reflection += "Majority of actions work well, with some opportunities to improve.\n"
            } else {
                reflection += "Several actions aren't landing as expected. I'm adjusting my approach.\n"
            }
        } else {
            reflection += ".\n\nNo feedback data yet—start using workspace actions to build my learning.\n"
        }
        
        return reflection
    }
    
    /// Reflects on recurring themes
    func reflectOnThemes(
        timeRange: AnalyticsTimeRange,
        modelContext: ModelContext
    ) async -> String {
        logger.info("Reflecting on recurring themes for \(timeRange.displayName)")
        
        let snapshot = await AnalyticsEngine.shared.generateSnapshot(
            for: timeRange,
            modelContext: modelContext
        )
        
        var reflection = "## Theme Reflection (\(timeRange.displayName))\n\n"
        
        // Active themes count
        reflection += "**Active Themes:** \(snapshot.activeThemes) concept\(snapshot.activeThemes == 1 ? "" : "s") showing gravitational pull.\n\n"
        
        // Memory graph stats
        if snapshot.memoryNodes > 0 {
            reflection += "**Memory Graph:** \(snapshot.memoryNodes) memory node\(snapshot.memoryNodes == 1 ? "" : "s"), \(snapshot.conceptCount) distinct concept\(snapshot.conceptCount == 1 ? "" : "s").\n"
            let densityPct = Int(snapshot.graphDensity * 100)
            reflection += "**Graph Density:** \(densityPct)%"
            if snapshot.graphDensity > 0.7 {
                reflection += "—highly interconnected thinking.\n"
            } else if snapshot.graphDensity > 0.4 {
                reflection += "—moderate connections emerging.\n"
            } else {
                reflection += "—concepts are relatively independent.\n"
            }
            
            reflection += "\n**Insight:** Check Insights → Memory Graph for visual theme exploration, or Connections for top recurring motifs.\n"
        } else {
            reflection += "**Memory Graph:** No themes detected yet. Continue working to build your conceptual map.\n"
        }
        
        return reflection
    }
    
    /// Reflects on current cognitive state
    func reflectOnCognitiveState(
        modelContext: ModelContext
    ) async -> String {
        logger.info("Reflecting on current cognitive state")
        
        let snapshot = await AnalyticsEngine.shared.generateSnapshot(
            for: .thisWeek,
            modelContext: modelContext
        )
        
        var reflection = "## Current Cognitive State\n\n"
        
        // Determine mode
        let mode = determineCognitiveMode(from: snapshot)
        reflection += "**Mode:** \(mode.name)\n\n"
        reflection += "**Description:** \(mode.description)\n\n"
        
        // Key metrics
        reflection += "**Key Metrics:**\n"
        reflection += "- Task Completion: \(Int(snapshot.completionRate * 100))%\n"
        reflection += "- Focus Sessions: \(snapshot.focusSessionsCount)\n"
        reflection += "- Emotional Valence: \(snapshot.emotionalSnapshot.valence > 0 ? "Positive" : snapshot.emotionalSnapshot.valence == 0 ? "Neutral" : "Reflective")\n"
        reflection += "- Active Themes: \(snapshot.activeThemes)\n\n"
        
        reflection += "**Recommendation:** \(mode.recommendation)\n"
        
        return reflection
    }
    
    /// Comprehensive week overview
    func reflectOnWeekOverview(
        modelContext: ModelContext
    ) async -> String {
        logger.info("Generating comprehensive week overview")
        
        let snapshot = await AnalyticsEngine.shared.generateSnapshot(
            for: .thisWeek,
            modelContext: modelContext
        )
        
        var overview = "## Week in Review\n\n"
        
        // Cognitive state
        let mode = determineCognitiveMode(from: snapshot)
        overview += "### Current State: \(mode.name)\n"
        overview += "\(mode.description)\n\n"
        
        // Productivity
        overview += "### Productivity\n"
        overview += "- **Tasks:** \(snapshot.tasksCompleted) completed, \(snapshot.tasksCreated - snapshot.tasksCompleted) remaining (\(Int(snapshot.completionRate * 100))% completion)\n"
        overview += "- **Priority Score:** \(String(format: "%.2f", snapshot.avgPriorityScore)) average\n"
        if !snapshot.topPriorityItems.isEmpty {
            overview += "- **Top Focus:** \(snapshot.topPriorityItems[0])\n"
        }
        overview += "\n"
        
        // Focus
        overview += "### Focus\n"
        if snapshot.focusSessionsCount > 0 {
            let hours = Double(snapshot.totalFocusMinutes) / 60.0
            overview += "- **Sessions:** \(snapshot.focusSessionsCount) (\(String(format: "%.1f", hours))h total)\n"
            overview += "- **Completion:** \(Int(snapshot.focusCompletionRate * 100))%\n"
        } else {
            overview += "- No focus sessions this week\n"
        }
        overview += "\n"
        
        // Emotional
        overview += "### Emotional\n"
        overview += "- **Tone:** \(formatEmotionalTone(snapshot.emotionalSnapshot.valence))\n"
        overview += "- **Trend:** \(snapshot.emotionalTrend.rawValue.capitalized)\n"
        overview += "- **Dominant:** \(snapshot.dominantEmotion.rawValue.capitalized)\n\n"
        
        // Learning
        overview += "### Learning\n"
        overview += "- **Score:** \(Int(snapshot.learningScore))%\n"
        overview += "- **Feedback Events:** \(snapshot.feedbackEventsCount)\n"
        if snapshot.feedbackEventsCount > 0 {
            let successRate = Int((Double(snapshot.positiveEvents) / Double(snapshot.feedbackEventsCount)) * 100)
            overview += "- **Success Rate:** \(successRate)%\n"
        }
        overview += "\n"
        
        // Themes
        overview += "### Themes\n"
        overview += "- **Active Concepts:** \(snapshot.activeThemes)\n"
        overview += "- **Memory Nodes:** \(snapshot.memoryNodes)\n\n"
        
        overview += "---\n\n"
        overview += "**💡 Explore More:** Check Intelligence Dashboard (Insights tab) for visual analytics and deeper patterns.\n"
        
        return overview
    }
    
    /// Reflects on journal entries for a time range
    func reflectOnJournalEntries(
        timeRange: AnalyticsTimeRange,
        modelContext: ModelContext
    ) async -> String {
        logger.info("Reflecting on journal entries for \(timeRange.displayName)")
        
        let (startDate, endDate) = timeRange.dateRange
        
        // Fetch journal entries in range
        let descriptor = FetchDescriptor<Journal>(
            predicate: #Predicate { journal in
                journal.entryDate >= startDate && journal.entryDate <= endDate && !journal.isArchived
            },
            sortBy: [SortDescriptor(\.entryDate, order: .reverse)]
        )
        
        guard let entries = try? modelContext.fetch(descriptor) else {
            return "Unable to load journal entries for reflection."
        }
        
        guard !entries.isEmpty else {
            return "No journal entries found for this period."
        }
        
        // Analyze mood patterns
        let moodCounts = Dictionary(grouping: entries, by: { $0.journalMood })
            .mapValues { $0.count }
        
        let dominantMood = moodCounts.max(by: { $0.value < $1.value })?.key ?? .none
        
        // Build reflection
        var reflection = "## Journal Reflection (\(timeRange.displayName))\n\n"
        reflection += "**Total Entries:** \(entries.count)\n\n"
        
        if dominantMood != .none {
            reflection += "**Dominant Mood:** \(dominantMood.rawValue) (\(moodCounts[dominantMood] ?? 0) entries)\n\n"
        }
        
        // Analyze mood shifts
        let halfCount = entries.count / 2
        let earlyEntries = Array(entries.suffix(halfCount))
        let recentEntries = Array(entries.prefix(halfCount))
        
        let earlyMood = earlyEntries.compactMap { $0.journalMood != .none ? $0.journalMood : nil }
            .mostCommonElement()
        let recentMood = recentEntries.compactMap { $0.journalMood != .none ? $0.journalMood : nil }
            .mostCommonElement()
        
        if let early = earlyMood, let recent = recentMood, early != recent {
            reflection += "**Mood Shift:** From \(early.rawValue) to \(recent.rawValue)\n\n"
        }
        
        // Extract themes from content
        let allContent = entries.map { $0.content }.joined(separator: " ")
        let commonWords = extractCommonWords(from: allContent, limit: 5)
        
        if !commonWords.isEmpty {
            reflection += "**Recurring Themes:** \(commonWords.joined(separator: ", "))\n\n"
        }
        
        reflection += "Your journal entries show a pattern of reflection and growth. Continue capturing your thoughts and emotions to build deeper self-awareness."
        
        return reflection
    }
    
    private func extractCommonWords(from text: String, limit: Int) -> [String] {
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 4 }
        
        let wordCounts = Dictionary(grouping: words, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        return Array(wordCounts.prefix(limit).map { $0.key })
    }
    
    // MARK: - Helper Functions
    
    private func determineCognitiveMode(from snapshot: AnalyticsSnapshot) -> (name: String, description: String, recommendation: String) {
        let focusScore = snapshot.focusSessionsCount > 0 ? Double(snapshot.focusSessionsCount) : 0
        let taskScore = snapshot.completionRate
        let emotionalScore = abs(snapshot.emotionalSnapshot.valence)
        
        if focusScore > 3 && taskScore > 0.7 {
            return (
                "Deep Work",
                "You're in a highly focused state with multiple deep work sessions and strong task completion.",
                "Keep this momentum going. Block calendar time for continued deep work."
            )
        } else if taskScore > 0.5 {
            return (
                "Productive Flow",
                "You're completing tasks at a steady pace with healthy follow-through.",
                "Maintain rhythm. Consider adding focus sessions to deepen concentration."
            )
        } else if emotionalScore > 0.6 {
            return (
                "High Energy",
                "Your emotional state is vibrant with strong valence.",
                "Channel this energy into creative work or tackling challenging priorities."
            )
        } else if snapshot.feedbackEventsCount > 10 {
            return (
                "Learning Mode",
                "I'm learning rapidly from your patterns with high interaction volume.",
                "Continue this engagement—it's building better intelligence."
            )
        } else {
            return (
                "Exploring",
                "You're building habits and exploring workflows.",
                "Start focus sessions and tackle top CPS priorities to build momentum."
            )
        }
    }
    
    private func formatEmotionalTone(_ valence: Double) -> String {
        if valence > 0.5 {
            return "Positive (\(String(format: "%.2f", valence)))"
        } else if valence > 0 {
            return "Stable (\(String(format: "%.2f", valence)))"
        } else if valence > -0.5 {
            return "Reflective (\(String(format: "%.2f", valence)))"
        } else {
            return "Challenging (\(String(format: "%.2f", valence)))"
        }
    }
}

// MARK: - Array Extension for Most Common Element

extension Array where Element: Hashable {
    func mostCommonElement() -> Element? {
        let counts = Dictionary(grouping: self, by: { $0 })
            .mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}

