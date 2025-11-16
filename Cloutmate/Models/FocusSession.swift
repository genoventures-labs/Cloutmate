//
//  FocusSession.swift
//  Cloutmate
//
//  Phase 4: Focus Mode MVP
//  Tracks focused work sessions with objectives and outcomes
//

import Foundation
import SwiftData

/// Status of a focus session
enum FocusSessionStatus: String, Codable {
    case active = "active"           // Currently in progress
    case completed = "completed"     // Finished successfully
    case abandoned = "abandoned"     // Stopped early
}

/// Focus session tracking model
@Model
final class FocusSession {
    @Attribute(.unique) var id: UUID
    var objective: String                 // What the user intends to work on
    var targetObjectId: UUID?            // Optional: linked task/project/note
    var targetObjectType: String?        // "task", "project", "note", etc.
    var statusRaw: String                // active, completed, abandoned
    
    // Timing
    var startTime: Date
    var endTime: Date?
    var plannedDuration: TimeInterval    // In seconds (e.g., 1800 = 30 min)
    var actualDuration: TimeInterval     // Actual time spent
    
    // Outcomes
    var completed: Bool                  // Did user finish what they set out to do?
    var notes: String?                   // Session reflections/notes
    var itemsCompleted: [UUID]           // IDs of tasks/items finished during session
    
    // Metadata
    var createdAt: Date
    var cpsScoreAtStart: Double?         // CPS score when session started (if linked to object)
    var scheduledTime: Date?
    var calendarEventId: String?
    var wasRescheduled: Bool
    
    // V2: Luminance Field tracking
    var lfHistory: [Double] = []        // Array of LF values sampled during session
    var averageLF: Double?               // Calculated average LF
    var focusGravityTrend: [Double]?    // Focus consistency over time
    var stabilityIndex: Double?         // Session stability score
    var emotionalVariance: Double?      // LF variance (volatility measure)
    var isPaused: Bool = false           // Pause state
    var pausedDuration: TimeInterval = 0 // Total paused time
    var pauseStartTime: Date?            // When pause started
    
    init(
        objective: String,
        plannedDuration: TimeInterval = 1800,  // Default 30 minutes
        targetObjectId: UUID? = nil,
        targetObjectType: String? = nil
    ) {
        self.id = UUID()
        self.objective = objective
        self.targetObjectId = targetObjectId
        self.targetObjectType = targetObjectType
        self.statusRaw = FocusSessionStatus.active.rawValue
        self.startTime = Date()
        self.endTime = nil
        self.plannedDuration = plannedDuration
        self.actualDuration = 0
        self.completed = false
        self.notes = nil
        self.itemsCompleted = []
        self.createdAt = Date()
        self.cpsScoreAtStart = nil
        self.scheduledTime = nil
        self.calendarEventId = nil
        self.wasRescheduled = false
        self.lfHistory = []
        self.averageLF = nil
        self.focusGravityTrend = nil
        self.stabilityIndex = nil
        self.emotionalVariance = nil
        self.isPaused = false
        self.pausedDuration = 0
        self.pauseStartTime = nil
    }
    
    var status: FocusSessionStatus {
        get { FocusSessionStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }
    
    /// Calculate elapsed time for active session (excluding paused time)
    var elapsedTime: TimeInterval {
        let baseTime: TimeInterval
        if let end = endTime {
            baseTime = end.timeIntervalSince(startTime)
        } else {
            baseTime = Date().timeIntervalSince(startTime)
        }
        
        // Subtract paused duration
        let currentPauseTime: TimeInterval
        if isPaused, let pauseStart = pauseStartTime {
            currentPauseTime = Date().timeIntervalSince(pauseStart)
        } else {
            currentPauseTime = 0
        }
        
        return baseTime - pausedDuration - currentPauseTime
    }
    
    /// Remaining time (if active)
    var remainingTime: TimeInterval {
        let remaining = plannedDuration - elapsedTime
        return max(0, remaining)
    }
    
    /// Is session currently active?
    var isActive: Bool {
        return status == .active
    }
    
    /// Did session run over planned time?
    var ranOverTime: Bool {
        return actualDuration > plannedDuration
    }
    
    /// Session duration as formatted string
    var durationFormatted: String {
        let duration = endTime != nil ? actualDuration : elapsedTime
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Completion summary for feedback loop
    var completionSummary: String {
        let durationStr = durationFormatted
        let outcomeStr = completed ? "✓ Completed" : "Partial progress"
        let itemsStr = itemsCompleted.isEmpty ? "" : " (\(itemsCompleted.count) items finished)"
        return "\(outcomeStr) • \(durationStr)\(itemsStr)"
    }
    
    /// Effective duration (actual duration minus paused time)
    var effectiveDuration: TimeInterval {
        return actualDuration - pausedDuration
    }
    
    /// Percentage of session with stable focus (based on LF variance)
    var focusStabilityPercentage: Double {
        guard let trend = focusGravityTrend, !trend.isEmpty else { return 0.0 }
        // Calculate percentage of time with focus gravity above 0.5
        let stableCount = trend.filter { $0 >= 0.5 }.count
        return Double(stableCount) / Double(trend.count)
    }
}

/// Focus session statistics (for aggregation)
struct FocusSessionStats {
    let totalSessions: Int
    let completedSessions: Int
    let totalFocusTime: TimeInterval
    let averageSessionDuration: TimeInterval
    let completionRate: Double
    let mostProductiveTimeOfDay: Int?  // Hour (0-23)
    
    static func calculate(from sessions: [FocusSession]) -> FocusSessionStats {
        let total = sessions.count
        let completed = sessions.filter { $0.status == .completed }.count
        let totalTime = sessions.reduce(0.0) { $0 + $1.actualDuration }
        let avgDuration = total > 0 ? totalTime / Double(total) : 0
        let completionRate = total > 0 ? Double(completed) / Double(total) : 0
        
        // Find most productive hour
        var hourCounts: [Int: Int] = [:]
        for session in sessions.filter({ $0.status == .completed }) {
            let hour = Calendar.current.component(.hour, from: session.startTime)
            hourCounts[hour, default: 0] += 1
        }
        let mostProductiveHour = hourCounts.max(by: { $0.value < $1.value })?.key
        
        return FocusSessionStats(
            totalSessions: total,
            completedSessions: completed,
            totalFocusTime: totalTime,
            averageSessionDuration: avgDuration,
            completionRate: completionRate,
            mostProductiveTimeOfDay: mostProductiveHour
        )
    }
}

