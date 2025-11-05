//
//  FocusSessionService.swift
//  Cloutmate
//
//  Phase 4: Focus Mode MVP
//  Manages focus session lifecycle: Start, Commit, Abandon, and time suggestions
//

import Foundation
import SwiftData
import os.log

@MainActor
final class FocusSessionService {
    static let shared = FocusSessionService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "FocusMode")
    private var config: AIConfig { AIConfigService.shared.config }
    
    private init() {}
    
    // MARK: - Active Session Management
    
    /// Get the current active session, if any
    func getActiveSession(modelContext: ModelContext) -> FocusSession? {
        let activeStatusRaw = "active"
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.statusRaw == activeStatusRaw },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        
        return try? modelContext.fetch(descriptor).first
    }
    
    /// Start a new focus session
    func startSession(
        objective: String,
        plannedDuration: TimeInterval = 1800,  // Default 30 min
        targetObjectId: UUID? = nil,
        targetObjectType: String? = nil,
        modelContext: ModelContext
    ) throws -> FocusSession {
        guard config.featureFlags.focusModeEnabled else {
            throw FocusSessionError.featureDisabled
        }
        
        // Check if there's already an active session
        if let activeSession = getActiveSession(modelContext: modelContext) {
            logger.warning("Attempted to start session while one is active: \(activeSession.id.uuidString)")
            throw FocusSessionError.sessionAlreadyActive
        }
        
        // Create new session
        let session = FocusSession(
            objective: objective,
            plannedDuration: plannedDuration,
            targetObjectId: targetObjectId,
            targetObjectType: targetObjectType
        )
        session.scheduledTime = session.startTime
        
        // Capture CPS score if linked to object
        if let objectId = targetObjectId {
            session.cpsScoreAtStart = PriorityEngine.shared.getScoreValue(for: objectId, modelContext: modelContext)
        }
        
        modelContext.insert(session)
        
        do {
            try modelContext.save()
            logger.info("Focus session started: \(session.objective) for \(session.plannedDuration / 60) minutes")
            AIDebug.log("Focus session started: \(session.id.uuidString)")
            NotificationCenter.default.post(name: .focusSessionStatusChanged, object: session)
        } catch {
            logger.error("Failed to save focus session: \(error.localizedDescription)")
            throw FocusSessionError.saveFailed
        }
        
        return session
    }
    
    /// Complete the active session
    func commitSession(
        completed: Bool,
        notes: String? = nil,
        itemsCompleted: [UUID] = [],
        modelContext: ModelContext
    ) throws -> FocusSession {
        guard config.featureFlags.focusModeEnabled else {
            throw FocusSessionError.featureDisabled
        }
        
        guard let session = getActiveSession(modelContext: modelContext) else {
            throw FocusSessionError.noActiveSession
        }
        
        // Update session
        session.status = .completed
        session.endTime = Date()
        session.actualDuration = session.elapsedTime
        session.completed = completed
        session.notes = notes
        session.itemsCompleted = itemsCompleted
        
        // Boost CPS scores for linked object and completed items
        var objectsToBoost: [UUID] = []
        if let targetId = session.targetObjectId {
            objectsToBoost.append(targetId)
        }
        objectsToBoost.append(contentsOf: itemsCompleted)
        
        if !objectsToBoost.isEmpty {
            let boostAmount = completed ? 0.25 : 0.15  // Higher boost for completed sessions
            PriorityEngine.shared.boostScore(
                for: objectsToBoost,
                amount: boostAmount,
                modelContext: modelContext
            )
        }
        
        do {
            try modelContext.save()
            logger.info("Focus session committed: \(session.completionSummary)")
            AIDebug.log("Focus session \(session.id.uuidString) committed: completed=\(completed)")
            
            // Log to feedback system
            _ = AIFeedbackLogger.shared.recordFocusSession(session: session, modelContext: modelContext)

            NotificationCenter.default.post(name: .focusSessionStatusChanged, object: session)
        } catch {
            logger.error("Failed to commit focus session: \(error.localizedDescription)")
            throw FocusSessionError.saveFailed
        }
        
        return session
    }
    
    /// Abandon the active session
    func abandonSession(
        reason: String? = nil,
        modelContext: ModelContext
    ) throws -> FocusSession {
        guard config.featureFlags.focusModeEnabled else {
            throw FocusSessionError.featureDisabled
        }
        
        guard let session = getActiveSession(modelContext: modelContext) else {
            throw FocusSessionError.noActiveSession
        }
        
        session.status = .abandoned
        session.endTime = Date()
        session.actualDuration = session.elapsedTime
        session.completed = false
        if let reason = reason {
            session.notes = "Abandoned: \(reason)"
        }
        
        do {
            try modelContext.save()
            logger.info("Focus session abandoned: \(session.objective) after \(session.durationFormatted)")
            AIDebug.log("Focus session \(session.id.uuidString) abandoned")
            
            // Log to feedback system
            _ = AIFeedbackLogger.shared.recordFocusSession(session: session, modelContext: modelContext)

            NotificationCenter.default.post(name: .focusSessionStatusChanged, object: session)
        } catch {
            logger.error("Failed to abandon focus session: \(error.localizedDescription)")
            throw FocusSessionError.saveFailed
        }
        
        return session
    }
    
    // MARK: - Session History & Stats
    
    /// Get recent sessions
    func getRecentSessions(limit: Int = 10, modelContext: ModelContext) -> [FocusSession] {
        var descriptor = FetchDescriptor<FocusSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    /// Get sessions for a specific date range
    func getSessions(
        in dateRange: DateInterval,
        modelContext: ModelContext
    ) -> [FocusSession] {
        let start = dateRange.start
        let end = dateRange.end
        
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { session in
                session.startTime >= start && session.startTime <= end
            },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    /// Calculate session statistics
    func getSessionStats(for dateRange: DateInterval? = nil, modelContext: ModelContext) -> FocusSessionStats {
        let sessions: [FocusSession]
        if let range = dateRange {
            sessions = getSessions(in: range, modelContext: modelContext)
        } else {
            sessions = (try? modelContext.fetch(FetchDescriptor<FocusSession>())) ?? []
        }
        
        return FocusSessionStats.calculate(from: sessions)
    }
    
    // MARK: - Time Suggestions
    
    /// Suggest optimal focus session times based on calendar availability
    func suggestFocusTime(
        duration: TimeInterval = 1800,  // 30 minutes
        daysAhead: Int = 3,
        modelContext: ModelContext
    ) async throws -> [GeminiService.TimeSlot] {
        let now = Date()
        let calendar = Calendar.current
        guard let futureDate = calendar.date(byAdding: .day, value: daysAhead, to: now) else {
            return []
        }
        
        let range = DateInterval(start: now, end: futureDate)
        let slotMinutes = Int(duration / 60)
        
        let availableSlots = try await CalendarAvailabilityService.shared.availableTimeSlots(
            modelContext: modelContext,
            in: range,
            workdayStartHour: 9,
            workdayEndHour: 17,
            slotMinutes: slotMinutes
        )
        
        // Get session stats to find best time of day
        let stats = getSessionStats(modelContext: modelContext)
        
        // If we have a productive hour, prioritize slots in that hour
        if let productiveHour = stats.mostProductiveTimeOfDay {
            let prioritized = availableSlots.sorted { slot1, slot2 in
                let hour1 = calendar.component(.hour, from: slot1.start)
                let hour2 = calendar.component(.hour, from: slot2.start)
                let dist1 = abs(hour1 - productiveHour)
                let dist2 = abs(hour2 - productiveHour)
                return dist1 < dist2
            }
            return Array(prioritized.prefix(5))
        }
        
        // Default: return first 5 available slots
        return Array(availableSlots.prefix(5))
    }
    
    /// Suggest optimal focus targets based on CPS scores
    func suggestFocusTargets(limit: Int = 5, modelContext: ModelContext) -> [PriorityItem] {
        return PriorityEngine.shared.getTopObjects(limit: limit, modelContext: modelContext)
    }
    
    /// Generate session summary for feedback loop
    func generateSessionSummary(session: FocusSession) -> FeedbackSummary {
        let title = session.status == .completed ? "Focus Session Completed" : "Focus Session Abandoned"
        let detail = """
Objective: \(session.objective)
Duration: \(session.durationFormatted) (\(session.completed ? "completed" : "partial"))
Items finished: \(session.itemsCompleted.count)
\(session.notes != nil ? "Notes: \(session.notes!)" : "")
"""
        
        return FeedbackSummary(
            title: title,
            detail: detail,
            timestamp: session.endTime ?? session.startTime
        )
    }
}

// MARK: - Errors

enum FocusSessionError: LocalizedError {
    case featureDisabled
    case sessionAlreadyActive
    case noActiveSession
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .featureDisabled:
            return "Focus Mode is not enabled. Enable it in AIConfig.plist."
        case .sessionAlreadyActive:
            return "A focus session is already active. Complete or abandon it before starting a new one."
        case .noActiveSession:
            return "No active focus session found."
        case .saveFailed:
            return "Failed to save focus session data."
        }
    }
}

