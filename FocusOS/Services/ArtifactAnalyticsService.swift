//
//  ArtifactAnalyticsService.swift
//  FocusOS
//
//  Artifacts V2 - Analytics and insights for artifacts
//

import Foundation
import SwiftData
import os.log
import FocusOSShared

@MainActor
final class ArtifactAnalyticsService {
    static let shared = ArtifactAnalyticsService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "ArtifactAnalytics")
    
    private init() {}
    
    // MARK: - Streak Analysis
    
    /// Calculate consecutive days with artifacts
    func streakCount(modelContext: ModelContext) -> Int {
        let descriptor = FetchDescriptor<Artifact>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        guard let artifacts = try? modelContext.fetch(descriptor), !artifacts.isEmpty else {
            return 0
        }
        
        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        for artifact in artifacts {
            let artifactDate = calendar.startOfDay(for: artifact.createdAt)
            
            if calendar.isDate(artifactDate, inSameDayAs: currentDate) {
                // Same day, continue
                continue
            } else if calendar.date(byAdding: .day, value: -1, to: currentDate) == artifactDate {
                // Previous day, increment streak
                streak += 1
                currentDate = artifactDate
            } else {
                // Gap found, break streak
                break
            }
        }
        
        // Check if today has an artifact
        if let firstArtifact = artifacts.first,
           calendar.isDate(calendar.startOfDay(for: firstArtifact.createdAt), inSameDayAs: Date()) {
            streak += 1
        }
        
        return streak
    }
    
    // MARK: - Frequency Stats
    
    struct FrequencyStats {
        let artifactsPerWeek: Double
        let artifactsPerMonth: Double
        let totalArtifacts: Int
        let averageConfidence: Double
    }
    
    /// Calculate frequency statistics
    func frequencyStats(modelContext: ModelContext) -> FrequencyStats {
        let descriptor = FetchDescriptor<Artifact>()
        guard let allArtifacts = try? modelContext.fetch(descriptor) else {
            return FrequencyStats(artifactsPerWeek: 0, artifactsPerMonth: 0, totalArtifacts: 0, averageConfidence: 0)
        }
        
        let totalArtifacts = allArtifacts.count
        
        // Calculate artifacts per week (last 4 weeks)
        let calendar = Calendar.current
        let fourWeeksAgo = calendar.date(byAdding: .day, value: -28, to: Date()) ?? Date()
        let recentArtifacts = allArtifacts.filter { $0.createdAt >= fourWeeksAgo }
        let artifactsPerWeek = Double(recentArtifacts.count) / 4.0
        
        // Calculate artifacts per month (last 3 months)
        let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        let monthlyArtifacts = allArtifacts.filter { $0.createdAt >= threeMonthsAgo }
        let artifactsPerMonth = Double(monthlyArtifacts.count) / 3.0
        
        // Calculate average confidence
        let averageConfidence = allArtifacts.isEmpty ? 0.0 : 
            allArtifacts.reduce(0.0) { $0 + $1.confidenceScore } / Double(allArtifacts.count)
        
        return FrequencyStats(
            artifactsPerWeek: artifactsPerWeek,
            artifactsPerMonth: artifactsPerMonth,
            totalArtifacts: totalArtifacts,
            averageConfidence: averageConfidence
        )
    }
    
    // MARK: - Tone Deviation
    
    /// Compare artifact tone vs ARTE tone
    func toneDeviation(artifact: Artifact) -> Double {
        guard let arteToneString = artifact.arteToneSnapshot,
              let arteTone = EmotionalState(rawValue: arteToneString) else {
            return 0.0 // No ARTE tone recorded
        }
        
        // Get current ARTE tone
        let currentTone = ReactiveThemeManager.shared.currentState
        
        // Simple deviation calculation: 0.0 = same, 1.0 = completely different
        if arteTone == currentTone {
            return 0.0
        }
        
        // Calculate deviation based on state similarity
        // This is a simplified calculation - could be enhanced with state transition weights
        return 0.5 // Default deviation for different states
    }
    
    // MARK: - Linked Entity Stats
    
    struct LinkedEntityStats {
        let projectCount: Int
        let areaCount: Int
        let taskCount: Int
        let focusSessionCount: Int
        let totalLinked: Int
    }
    
    /// Count linked entities for an artifact
    func linkedEntityStats(artifact: Artifact) -> LinkedEntityStats {
        var projectCount = 0
        var areaCount = 0
        var taskCount = 0
        var focusSessionCount = 0
        
        for (index, type) in artifact.linkedEntityTypes.enumerated() {
            switch type {
            case "project":
                projectCount += 1
            case "area":
                areaCount += 1
            case "task":
                taskCount += 1
            case "focusSession":
                focusSessionCount += 1
            default:
                break
            }
        }
        
        // Also count direct links
        if artifact.projectId != nil {
            projectCount += 1
        }
        if artifact.areaId != nil {
            areaCount += 1
        }
        if artifact.focusSessionId != nil {
            focusSessionCount += 1
        }
        
        let totalLinked = projectCount + areaCount + taskCount + focusSessionCount
        
        return LinkedEntityStats(
            projectCount: projectCount,
            areaCount: areaCount,
            taskCount: taskCount,
            focusSessionCount: focusSessionCount,
            totalLinked: totalLinked
        )
    }
    
    // MARK: - Confidence Trends
    
    struct ConfidenceTrend {
        let recentAverage: Double
        let previousAverage: Double
        let trend: TrendDirection
    }
    
    enum TrendDirection {
        case improving
        case declining
        case stable
    }
    
    /// Calculate confidence score trends over time
    func confidenceTrend(limit: Int = 20, modelContext: ModelContext) -> ConfidenceTrend {
        var descriptor = FetchDescriptor<Artifact>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        guard let artifacts = try? modelContext.fetch(descriptor), artifacts.count >= 4 else {
            return ConfidenceTrend(recentAverage: 0.5, previousAverage: 0.5, trend: .stable)
        }
        
        let midpoint = artifacts.count / 2
        let recentArtifacts = Array(artifacts.prefix(midpoint))
        let previousArtifacts = Array(artifacts.suffix(midpoint))
        
        let recentAverage = recentArtifacts.isEmpty ? 0.0 :
            recentArtifacts.reduce(0.0) { $0 + $1.confidenceScore } / Double(recentArtifacts.count)
        
        let previousAverage = previousArtifacts.isEmpty ? 0.0 :
            previousArtifacts.reduce(0.0) { $0 + $1.confidenceScore } / Double(previousArtifacts.count)
        
        let difference = recentAverage - previousAverage
        let trend: TrendDirection
        if abs(difference) < 0.05 {
            trend = .stable
        } else if difference > 0 {
            trend = .improving
        } else {
            trend = .declining
        }
        
        return ConfidenceTrend(
            recentAverage: recentAverage,
            previousAverage: previousAverage,
            trend: trend
        )
    }
}

