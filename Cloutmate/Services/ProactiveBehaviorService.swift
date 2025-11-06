//
//  ProactiveBehaviorService.swift
//  Cloutmate
//
//  Enables proactive check-ins, pattern recognition, and contextual awareness
//

import Foundation
import SwiftData
import CloutmateShared

@MainActor
@Observable
final class ProactiveBehaviorService {
    static let shared = ProactiveBehaviorService()
    
    private var lastCheckInDate: Date?
    private let checkInInterval: TimeInterval = 3600 * 4 // 4 hours
    private var userPatterns: [UserPattern] = []
    
    private init() {}
    
    struct UserPattern {
        let type: PatternType
        let timeOfDay: Date
        let frequency: Int
        let lastOccurrence: Date
        
        enum PatternType {
            case focusSession
            case taskCreation
            case projectWork
            case noteTaking
        }
    }
    
    /// Check if a proactive check-in should be triggered
    func shouldTriggerCheckIn(lastInteraction: Date?) -> Bool {
        guard let lastInteraction = lastInteraction else {
            // First time, don't check in immediately
            return false
        }
        
        let timeSinceLastInteraction = Date().timeIntervalSince(lastInteraction)
        
        // Check in if it's been more than 4 hours
        return timeSinceLastInteraction >= checkInInterval
    }
    
    /// Generate a proactive check-in message
    func generateCheckInMessage(
        lastInteraction: Date?,
        modelContext: ModelContext
    ) async -> String? {
        guard shouldTriggerCheckIn(lastInteraction: lastInteraction) else {
            return nil
        }
        
        let timeSince = lastInteraction.map { Date().timeIntervalSince($0) } ?? 0
        let hoursAgo = Int(timeSince / 3600)
        
        // Pre-compute date values outside predicate
        let now = Date()
        let doneStatusRaw = TaskStatus.done.rawValue
        
        // Check for overdue tasks
        let overdueTasks = try? modelContext.fetch(
            FetchDescriptor<Task>(
                predicate: #Predicate<Task> { task in
                    task.dueDate != nil && task.dueDate! < now && task.statusRaw != doneStatusRaw
                }
            )
        )
        
        // Check for upcoming deadlines
        let threeDaysFromNow = Calendar.current.date(byAdding: .day, value: 3, to: now) ?? now
        let upcomingTasks = try? modelContext.fetch(
            FetchDescriptor<Task>(
                predicate: #Predicate<Task> { task in
                    task.dueDate != nil && task.dueDate! >= now && task.dueDate! <= threeDaysFromNow && task.statusRaw != doneStatusRaw
                }
            )
        )
        
        var messages: [String] = []
        
        if hoursAgo > 24 {
            messages.append("Haven't seen you in a while! How's everything going?")
        } else if hoursAgo > 8 {
            messages.append("Hey! How's your day going?")
        } else {
            messages.append("Quick check-in - how are things?")
        }
        
        if let overdue = overdueTasks, !overdue.isEmpty {
            messages.append("I noticed you have \(overdue.count) overdue task\(overdue.count == 1 ? "" : "s"). Want me to help prioritize?")
        }
        
        if let upcoming = upcomingTasks, !upcoming.isEmpty {
            messages.append("You have \(upcoming.count) task\(upcoming.count == 1 ? "" : "s") due in the next few days. Need help planning?")
        }
        
        return messages.joined(separator: " ")
    }
    
    /// Detect user patterns from workspace activity
    func detectPatterns(modelContext: ModelContext) async {
        // Analyze task creation times
        if let tasks = try? modelContext.fetch(FetchDescriptor<Task>()) {
            analyzeTaskCreationPatterns(tasks)
        }
        
        // Analyze focus session times
        if let sessions = try? modelContext.fetch(FetchDescriptor<FocusSession>()) {
            analyzeFocusSessionPatterns(sessions)
        }
    }
    
    private func analyzeTaskCreationPatterns(_ tasks: [Task]) {
        // Group tasks by hour of day
        var hourlyCounts: [Int: Int] = [:]
        for task in tasks {
            let hour = Calendar.current.component(.hour, from: task.createdAt)
            hourlyCounts[hour, default: 0] += 1
        }
        
        // Find peak hours
        if let peakHour = hourlyCounts.max(by: { $0.value < $1.value })?.key,
           hourlyCounts[peakHour] ?? 0 > 5 {
            // Pattern detected: user creates tasks around this hour
            let pattern = UserPattern(
                type: .taskCreation,
                timeOfDay: Calendar.current.date(bySettingHour: peakHour, minute: 0, second: 0, of: Date()) ?? Date(),
                frequency: hourlyCounts[peakHour] ?? 0,
                lastOccurrence: Date()
            )
            userPatterns.append(pattern)
        }
    }
    
    private func analyzeFocusSessionPatterns(_ sessions: [FocusSession]) {
        // Similar pattern detection for focus sessions
        var hourlyCounts: [Int: Int] = [:]
        for session in sessions {
            let hour = Calendar.current.component(.hour, from: session.startTime)
            hourlyCounts[hour, default: 0] += 1
        }
        
        if let peakHour = hourlyCounts.max(by: { $0.value < $1.value })?.key,
           hourlyCounts[peakHour] ?? 0 > 3 {
            let pattern = UserPattern(
                type: .focusSession,
                timeOfDay: Calendar.current.date(bySettingHour: peakHour, minute: 0, second: 0, of: Date()) ?? Date(),
                frequency: hourlyCounts[peakHour] ?? 0,
                lastOccurrence: Date()
            )
            userPatterns.append(pattern)
        }
    }
    
    /// Generate proactive message based on patterns
    func generatePatternBasedMessage(currentTime: Date = Date()) -> String? {
        let currentHour = Calendar.current.component(.hour, from: currentTime)
        
        for pattern in userPatterns {
            let patternHour = Calendar.current.component(.hour, from: pattern.timeOfDay)
            
            // Check if we're approaching the user's typical time
            if abs(currentHour - patternHour) <= 1 {
                switch pattern.type {
                case .focusSession:
                    return "Are you about to start a focus session? You usually do around this time."
                case .taskCreation:
                    return "I notice you often create tasks around this time. Need help organizing anything?"
                case .projectWork:
                    return "This is usually when you work on projects. Want me to help prioritize?"
                case .noteTaking:
                    return "Looks like a good time for note-taking based on your patterns. Anything on your mind?"
                }
            }
        }
        
        return nil
    }
    
    /// Get contextual awareness message
    func getContextualAwarenessMessage(modelContext: ModelContext) async -> String? {
        let now = Date()
        let doneStatusRaw = TaskStatus.done.rawValue
        let overdueTasks = try? modelContext.fetch(
            FetchDescriptor<Task>(
                predicate: #Predicate<Task> { task in
                    task.dueDate != nil && task.dueDate! < now && task.statusRaw != doneStatusRaw
                }
            )
        )
        
        if let overdue = overdueTasks, !overdue.isEmpty {
            return "I notice you have \(overdue.count) overdue task\(overdue.count == 1 ? "" : "s"). Want me to help you tackle them?"
        }
        
        return nil
    }
}

