//
//  RitualPatternLearner.swift
//  FocusOS
//
//  Pattern detection service for ritual completion behavior analysis
//

import Foundation
import SwiftData
import os.log

@MainActor
final class RitualPatternLearner {
    static let shared = RitualPatternLearner()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "RitualPatternLearner")
    
    private init() {}
    
    // MARK: - Pattern Detection
    
    /// Analyzes historical ritual completions to detect behavioral patterns
    func detectPatterns(
        for ritualType: FocusRitualType,
        modelContext: ModelContext,
        lookbackDays: Int = 30
    ) -> [RitualPattern] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<RitualCompletion>(
            predicate: #Predicate<RitualCompletion> { completion in
                completion.ritualTypeRaw == ritualType.rawValue &&
                completion.completedAt >= cutoffDate
            },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        
        guard let completions = try? modelContext.fetch(descriptor) else {
            logger.warning("Failed to fetch ritual completions for pattern detection")
            return []
        }
        
        guard completions.count >= 3 else {
            logger.debug("Insufficient data for pattern detection (need at least 3 completions)")
            return []
        }
        
        var patterns: [RitualPattern] = []
        
        // Pattern 1: Skipped steps correlation with active projects
        if let skippedPattern = detectSkippedStepsPattern(completions: completions) {
            patterns.append(skippedPattern)
        }
        
        // Pattern 2: Step completion speed correlation with task load
        if let speedPattern = detectCompletionSpeedPattern(completions: completions) {
            patterns.append(speedPattern)
        }
        
        // Pattern 3: Breathing exercise skipped during project peaks
        if let breathingPattern = detectBreathingSkipPattern(completions: completions) {
            patterns.append(breathingPattern)
        }
        
        return patterns.sorted { $0.confidence > $1.confidence }
    }
    
    /// Detects pattern: User tends to skip specific steps when Focus Gravity metrics are high
    private func detectSkippedStepsPattern(completions: [RitualCompletion]) -> RitualPattern? {
        var skippedWithHighProjects: Int = 0
        var skippedWithLowProjects: Int = 0
        var totalHighProjects: Int = 0
        var totalLowProjects: Int = 0
        
        for completion in completions {
            guard let activeProjectsStr = completion.metadata["fg_active_projects"],
                  let activeProjects = Int(activeProjectsStr) else { continue }
            
            let hasSkippedSteps = !(completion.metadata["skipped_steps"]?.isEmpty ?? true)
            
            if activeProjects >= 3 {
                totalHighProjects += 1
                if hasSkippedSteps {
                    skippedWithHighProjects += 1
                }
            } else {
                totalLowProjects += 1
                if hasSkippedSteps {
                    skippedWithLowProjects += 1
                }
            }
        }
        
        guard totalHighProjects >= 2 && totalLowProjects >= 2 else { return nil }
        
        let highProjectSkipRate = Double(skippedWithHighProjects) / Double(totalHighProjects)
        let lowProjectSkipRate = Double(skippedWithLowProjects) / Double(totalLowProjects)
        
        // Pattern detected if skip rate is significantly higher with high project count
        if highProjectSkipRate > lowProjectSkipRate + 0.3 && highProjectSkipRate > 0.5 {
            let confidence = min(1.0, (highProjectSkipRate - lowProjectSkipRate) * 1.5)
            
            return RitualPattern(
                id: UUID(),
                type: .skippedStepsWithHighProjects,
                description: "You tend to skip mindfulness steps when 3+ projects are active",
                confidence: confidence,
                frequency: skippedWithHighProjects,
                lastOccurred: completions.first?.completedAt ?? Date(),
                metadata: [
                    "high_project_skip_rate": String(format: "%.2f", highProjectSkipRate),
                    "low_project_skip_rate": String(format: "%.2f", lowProjectSkipRate),
                    "threshold": "3"
                ]
            )
        }
        
        return nil
    }
    
    /// Detects pattern: Step completion speed correlates with task load
    private func detectCompletionSpeedPattern(completions: [RitualCompletion]) -> RitualPattern? {
        var fastWithLowTasks: Int = 0
        var fastWithHighTasks: Int = 0
        var totalLowTasks: Int = 0
        var totalHighTasks: Int = 0
        
        for completion in completions {
            guard let taskCountStr = completion.metadata["fg_high_priority_tasks"],
                  let taskCount = Int(taskCountStr),
                  let avgDurationStr = completion.metadata["avg_step_duration"],
                  let avgDuration = Double(avgDurationStr) else { continue }
            
            let isFast = avgDuration < 60.0 // Less than 1 minute per step
            
            if taskCount <= 3 {
                totalLowTasks += 1
                if isFast {
                    fastWithLowTasks += 1
                }
            } else {
                totalHighTasks += 1
                if isFast {
                    fastWithHighTasks += 1
                }
            }
        }
        
        guard totalLowTasks >= 2 && totalHighTasks >= 2 else { return nil }
        
        let lowTaskFastRate = Double(fastWithLowTasks) / Double(totalLowTasks)
        let highTaskFastRate = Double(fastWithHighTasks) / Double(totalHighTasks)
        
        // Pattern detected if completion is faster with low task load
        if lowTaskFastRate > highTaskFastRate + 0.3 && lowTaskFastRate > 0.6 {
            let confidence = min(1.0, (lowTaskFastRate - highTaskFastRate) * 1.2)
            
            return RitualPattern(
                id: UUID(),
                type: .fasterCompletionWithLowTasks,
                description: "You complete gratitude steps faster when task load is low",
                confidence: confidence,
                frequency: fastWithLowTasks,
                lastOccurred: completions.first?.completedAt ?? Date(),
                metadata: [
                    "low_task_fast_rate": String(format: "%.2f", lowTaskFastRate),
                    "high_task_fast_rate": String(format: "%.2f", highTaskFastRate)
                ]
            )
        }
        
        return nil
    }
    
    /// Detects pattern: Breathing exercise skipped during project peaks
    private func detectBreathingSkipPattern(completions: [RitualCompletion]) -> RitualPattern? {
        var skippedWithPeaks: Int = 0
        var skippedWithoutPeaks: Int = 0
        var totalWithPeaks: Int = 0
        var totalWithoutPeaks: Int = 0
        
        for completion in completions {
            let hasProjectPeaks = !(completion.metadata["fg_project_peaks"]?.isEmpty ?? true)
            let skippedSteps = completion.metadata["skipped_steps"]?.split(separator: ",") ?? []
            let skippedBreathing = skippedSteps.contains { stepId in
                // Check if breathing step was skipped (would need step type mapping)
                true // Simplified for now
            }
            
            if hasProjectPeaks {
                totalWithPeaks += 1
                if skippedBreathing {
                    skippedWithPeaks += 1
                }
            } else {
                totalWithoutPeaks += 1
                if skippedBreathing {
                    skippedWithoutPeaks += 1
                }
            }
        }
        
        guard totalWithPeaks >= 2 && totalWithoutPeaks >= 2 else { return nil }
        
        let peakSkipRate = Double(skippedWithPeaks) / Double(totalWithPeaks)
        let noPeakSkipRate = Double(skippedWithoutPeaks) / Double(totalWithoutPeaks)
        
        if peakSkipRate > noPeakSkipRate + 0.4 && peakSkipRate > 0.5 {
            let confidence = min(1.0, (peakSkipRate - noPeakSkipRate) * 1.3)
            
            return RitualPattern(
                id: UUID(),
                type: .breathingSkippedDuringPeaks,
                description: "Breathing exercise skipped during project peaks",
                confidence: confidence,
                frequency: skippedWithPeaks,
                lastOccurred: completions.first?.completedAt ?? Date(),
                metadata: [
                    "peak_skip_rate": String(format: "%.2f", peakSkipRate),
                    "no_peak_skip_rate": String(format: "%.2f", noPeakSkipRate)
                ]
            )
        }
        
        return nil
    }
    
    // MARK: - Pattern Matching
    
    /// Finds patterns matching current Focus Gravity state
    func patternsMatchingCurrentState(
        for ritualType: FocusRitualType,
        activeProjects: Int,
        highPriorityTasks: Int,
        hasProjectPeaks: Bool,
        modelContext: ModelContext
    ) -> [RitualPattern] {
        let allPatterns = detectPatterns(for: ritualType, modelContext: modelContext)
        
        return allPatterns.filter { pattern in
            switch pattern.type {
            case .skippedStepsWithHighProjects:
                return activeProjects >= 3
            case .fasterCompletionWithLowTasks:
                return highPriorityTasks <= 3
            case .breathingSkippedDuringPeaks:
                return hasProjectPeaks
            }
        }
    }
    
    // MARK: - Suggestion Generation
    
    /// Generates contextual suggestions based on detected patterns
    func generateSuggestions(
        for ritualType: FocusRitualType,
        patterns: [RitualPattern],
        modelContext: ModelContext
    ) -> [RitualPatternSuggestion] {
        let tone = AuroraToneKit.tone(for: ritualType)
        let promptPrefix = AuroraToneKit.promptPrefix(for: tone)
        
        return patterns.map { pattern in
            let message = generateSuggestionMessage(for: pattern, ritualType: ritualType, promptPrefix: promptPrefix)
            
            return RitualPatternSuggestion(
                id: UUID(),
                pattern: pattern,
                message: message,
                createdAt: Date()
            )
        }
    }
    
    private func generateSuggestionMessage(
        for pattern: RitualPattern,
        ritualType: FocusRitualType,
        promptPrefix: String
    ) -> String {
        switch pattern.type {
        case .skippedStepsWithHighProjects:
            return ritualType == .morning
                ? "\(promptPrefix). You tend to skip mindfulness when projects peak — want me to schedule that earlier tomorrow?"
                : "\(promptPrefix). Your mindfulness steps are more effective when you have fewer active projects — consider doing it first today."
        case .fasterCompletionWithLowTasks:
            return ritualType == .morning
                ? "\(promptPrefix). You complete gratitude faster when task load is low — take your time today."
                : "\(promptPrefix). Your breathing exercises are more effective when you have fewer tasks — consider doing it first today."
        case .breathingSkippedDuringPeaks:
            return ritualType == .morning
                ? "\(promptPrefix). Breathing exercises help during busy periods — want to try it first today?"
                : "\(promptPrefix). Your breathing exercises are more effective when you have fewer tasks — consider doing it first today."
        }
    }
    
    // MARK: - Trend Analysis
    
    /// Calculates behavior shift trends over time periods
    func calculateBehaviorShifts(
        for ritualType: FocusRitualType?,
        modelContext: ModelContext,
        lookbackDays: Int = 30
    ) -> [BehaviorShift] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<RitualCompletion>(
            predicate: #Predicate<RitualCompletion> { completion in
                if let type = ritualType {
                    return completion.ritualTypeRaw == type.rawValue && completion.completedAt >= cutoffDate
                } else {
                    return completion.completedAt >= cutoffDate
                }
            },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        
        guard let completions = try? modelContext.fetch(descriptor) else {
            logger.warning("Failed to fetch completions for behavior shift analysis")
            return []
        }
        
        guard completions.count >= 6 else {
            return [] // Need at least 6 completions to compare periods
        }
        
        var shifts: [BehaviorShift] = []
        
        // Split into two periods: recent (last 15 days) and earlier (15-30 days ago)
        let midPoint = Calendar.current.date(byAdding: .day, value: -15, to: Date()) ?? Date()
        let recentCompletions = completions.filter { $0.completedAt >= midPoint }
        let earlierCompletions = completions.filter { $0.completedAt < midPoint }
        
        guard !recentCompletions.isEmpty && !earlierCompletions.isEmpty else {
            return []
        }
        
        // Shift 1: Mindfulness step completion rate
        if let mindfulnessShift = calculateMindfulnessShift(recent: recentCompletions, earlier: earlierCompletions) {
            shifts.append(mindfulnessShift)
        }
        
        // Shift 2: Average completion speed
        if let speedShift = calculateSpeedShift(recent: recentCompletions, earlier: earlierCompletions) {
            shifts.append(speedShift)
        }
        
        // Shift 3: Step skipping correlation with project count
        if let skippingShift = calculateSkippingShift(recent: recentCompletions, earlier: earlierCompletions) {
            shifts.append(skippingShift)
        }
        
        return shifts.sorted { abs($0.percentageChange) > abs($1.percentageChange) }
    }
    
    private func calculateMindfulnessShift(recent: [RitualCompletion], earlier: [RitualCompletion]) -> BehaviorShift? {
        let recentMindfulnessRate = calculateMindfulnessCompletionRate(completions: recent)
        let earlierMindfulnessRate = calculateMindfulnessCompletionRate(completions: earlier)
        
        guard earlierMindfulnessRate > 0 else { return nil }
        
        let change = recentMindfulnessRate - earlierMindfulnessRate
        let percentageChange = (change / earlierMindfulnessRate) * 100
        
        guard abs(percentageChange) >= 10 else { return nil } // Only show significant changes
        
        // Find correlation with project count
        let recentAvgProjects = averageActiveProjects(completions: recent)
        let earlierAvgProjects = averageActiveProjects(completions: earlier)
        
        let projectChange = recentAvgProjects - earlierAvgProjects
        
        var cause: String? = nil
        if abs(projectChange) >= 1 {
            if percentageChange > 0 && projectChange < 0 {
                cause = "after reducing active projects"
            } else if percentageChange < 0 && projectChange > 0 {
                cause = "as active projects increased"
            }
        }
        
        return BehaviorShift(
            id: UUID(),
            metric: "Mindfulness step completion",
            percentageChange: percentageChange,
            recentValue: recentMindfulnessRate,
            earlierValue: earlierMindfulnessRate,
            cause: cause,
            trend: percentageChange > 0 ? .improving : .declining,
            lastUpdated: recent.first?.completedAt ?? Date()
        )
    }
    
    private func calculateSpeedShift(recent: [RitualCompletion], earlier: [RitualCompletion]) -> BehaviorShift? {
        let recentAvgSpeed = averageCompletionSpeed(completions: recent)
        let earlierAvgSpeed = averageCompletionSpeed(completions: earlier)
        
        guard earlierAvgSpeed > 0 else { return nil }
        
        let change = recentAvgSpeed - earlierAvgSpeed
        let percentageChange = (change / earlierAvgSpeed) * 100
        
        guard abs(percentageChange) >= 15 else { return nil }
        
        let recentAvgTasks = averageHighPriorityTasks(completions: recent)
        let earlierAvgTasks = averageHighPriorityTasks(completions: earlier)
        let taskChange = recentAvgTasks - earlierAvgTasks
        
        var cause: String? = nil
        if abs(taskChange) >= 2 {
            if percentageChange < 0 && taskChange < 0 {
                cause = "after reducing task load"
            } else if percentageChange > 0 && taskChange > 0 {
                cause = "as task load increased"
            }
        }
        
        return BehaviorShift(
            id: UUID(),
            metric: "Ritual completion speed",
            percentageChange: abs(percentageChange), // Always positive for "faster" or "slower"
            recentValue: recentAvgSpeed,
            earlierValue: earlierAvgSpeed,
            cause: cause,
            trend: percentageChange < 0 ? .improving : .declining, // Faster is better
            lastUpdated: recent.first?.completedAt ?? Date()
        )
    }
    
    private func calculateSkippingShift(recent: [RitualCompletion], earlier: [RitualCompletion]) -> BehaviorShift? {
        let recentSkipRate = stepSkippingRate(completions: recent)
        let earlierSkipRate = stepSkippingRate(completions: earlier)
        
        guard earlierSkipRate > 0 else { return nil }
        
        let change = recentSkipRate - earlierSkipRate
        let percentageChange = (change / earlierSkipRate) * 100
        
        guard abs(percentageChange) >= 20 else { return nil }
        
        let recentAvgProjects = averageActiveProjects(completions: recent)
        let earlierAvgProjects = averageActiveProjects(completions: earlier)
        let projectChange = recentAvgProjects - earlierAvgProjects
        
        var cause: String? = nil
        if abs(projectChange) >= 1 {
            if percentageChange < 0 && projectChange < 0 {
                cause = "after reducing active projects"
            } else if percentageChange > 0 && projectChange > 0 {
                cause = "as active projects increased"
            }
        }
        
        return BehaviorShift(
            id: UUID(),
            metric: "Step skipping rate",
            percentageChange: abs(percentageChange),
            recentValue: recentSkipRate,
            earlierValue: earlierSkipRate,
            cause: cause,
            trend: percentageChange < 0 ? .improving : .declining,
            lastUpdated: recent.first?.completedAt ?? Date()
        )
    }
    
    // MARK: - Helper Calculations
    
    private func calculateMindfulnessCompletionRate(completions: [RitualCompletion]) -> Double {
        guard !completions.isEmpty else { return 0 }
        
        var totalSteps = 0
        var completedMindfulness = 0
        
        for completion in completions {
            let completedSteps = completion.metadata["completed_steps"]?.split(separator: ",") ?? []
            let skippedSteps = completion.metadata["skipped_steps"]?.split(separator: ",") ?? []
            totalSteps += completedSteps.count + skippedSteps.count
            
            // Check if breathing or gratitude steps were completed (simplified check)
            if !completedSteps.isEmpty {
                completedMindfulness += 1 // Count completions with mindfulness steps
            }
        }
        
        return totalSteps > 0 ? Double(completedMindfulness) / Double(completions.count) : 0
    }
    
    private func averageCompletionSpeed(completions: [RitualCompletion]) -> Double {
        let speeds = completions.compactMap { completion -> Double? in
            guard let durationStr = completion.metadata["avg_step_duration"],
                  let duration = Double(durationStr) else { return nil }
            return duration
        }
        return speeds.isEmpty ? 0 : speeds.reduce(0, +) / Double(speeds.count)
    }
    
    private func stepSkippingRate(completions: [RitualCompletion]) -> Double {
        guard !completions.isEmpty else { return 0 }
        
        var totalCompletions = 0
        var skippedCompletions = 0
        
        for completion in completions {
            totalCompletions += 1
            let skippedSteps = completion.metadata["skipped_steps"]?.split(separator: ",") ?? []
            if !skippedSteps.isEmpty {
                skippedCompletions += 1
            }
        }
        
        return totalCompletions > 0 ? Double(skippedCompletions) / Double(totalCompletions) : 0
    }
    
    private func averageActiveProjects(completions: [RitualCompletion]) -> Double {
        let projects = completions.compactMap { completion -> Int? in
            guard let projectsStr = completion.metadata["fg_active_projects"],
                  let projects = Int(projectsStr) else { return nil }
            return projects
        }
        return projects.isEmpty ? 0 : Double(projects.reduce(0, +)) / Double(projects.count)
    }
    
    private func averageHighPriorityTasks(completions: [RitualCompletion]) -> Double {
        let tasks = completions.compactMap { completion -> Int? in
            guard let tasksStr = completion.metadata["fg_high_priority_tasks"],
                  let tasks = Int(tasksStr) else { return nil }
            return tasks
        }
        return tasks.isEmpty ? 0 : Double(tasks.reduce(0, +)) / Double(tasks.count)
    }
}

// MARK: - Behavior Shift Model

struct BehaviorShift: Identifiable {
    let id: UUID
    let metric: String
    let percentageChange: Double
    let recentValue: Double
    let earlierValue: Double
    let cause: String?
    let trend: BehaviorTrend
    let lastUpdated: Date
}

enum BehaviorTrend {
    case improving
    case declining
}

// MARK: - Supporting Types

struct RitualPattern: Identifiable {
    let id: UUID
    let type: RitualPatternType
    let description: String
    let confidence: Double // 0.0 - 1.0
    let frequency: Int
    let lastOccurred: Date
    let metadata: [String: String]
}

enum RitualPatternType: String {
    case skippedStepsWithHighProjects
    case fasterCompletionWithLowTasks
    case breathingSkippedDuringPeaks
}

struct RitualPatternSuggestion: Identifiable {
    let id: UUID
    let pattern: RitualPattern
    let message: String
    let createdAt: Date
}

