//
//  FocusSessionService.swift
//  FocusOS
//
//  Phase 4: Focus Mode MVP
//  Manages focus session lifecycle: Start, Commit, Abandon, and time suggestions
//

import Foundation
import SwiftData
import Combine
import os.log

@MainActor
final class FocusSessionService {
    static let shared = FocusSessionService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "FocusMode")
    private var config: AIConfig { AIConfigService.shared.config }
    
    private init() {}
    
    // MARK: - Active Session Management
    
    /// Get the current active session, if any
    /// Validates that the session is actually still active (not expired)
    func getActiveSession(modelContext: ModelContext) -> FocusSession? {
        let activeStatusRaw = "active"
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.statusRaw == activeStatusRaw },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        
        guard let session = try? modelContext.fetch(descriptor).first else {
            return nil
        }
        
        // Validate session is actually still active
        // Auto-abandon sessions that are way past their planned duration (more than 2x planned duration or 24 hours old)
        let elapsed = session.elapsedTime
        let maxAllowedDuration = max(session.plannedDuration * 2, 86400) // 2x planned or 24 hours, whichever is longer
        let isExpired = elapsed > maxAllowedDuration
        
        if isExpired {
            // Auto-abandon expired sessions
            logger.info("Auto-abandoning expired focus session: \(session.id.uuidString) (elapsed: \(elapsed / 60) min, planned: \(session.plannedDuration / 60) min)")
            session.status = .abandoned
            session.endTime = Date()
            session.actualDuration = session.elapsedTime
            session.completed = false
            session.notes = "Auto-abandoned: Session expired (exceeded planned duration)"
            
            do {
                try modelContext.save()
                NotificationCenter.default.post(name: .focusSessionStatusChanged, object: session)
                NotificationCenter.default.post(name: .focusSessionEnded, object: session)
                
                // Deactivate Flow Hold if active
                if FlowHoldService.shared.isActive {
                    FlowHoldService.shared.deactivateFlowHold()
                }
            } catch {
                logger.error("Failed to auto-abandon expired session: \(error.localizedDescription)")
            }
            
            return nil
        }
        
        return session
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
            
            // Auto-activate Flow Hold for deep work sessions
            if shouldActivateFlowHold(for: session) {
                FlowHoldService.shared.activateFlowHold(duration: session.plannedDuration)
                logger.info("Flow Hold activated for deep work session")
            }
            
            NotificationCenter.default.post(name: .focusSessionStatusChanged, object: session)
            NotificationCenter.default.post(name: .focusSessionStarted, object: session)
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
            
            // Link to memory graph
            Task {
                try? await MemoryGraphService.shared.linkFocusSession(session: session, modelContext: modelContext)
            }

            NotificationCenter.default.post(name: .focusSessionStatusChanged, object: session)
            NotificationCenter.default.post(name: .focusSessionEnded, object: session)
            
            // Deactivate Flow Hold when session ends
            if FlowHoldService.shared.isActive {
                FlowHoldService.shared.deactivateFlowHold()
                logger.info("Flow Hold deactivated after session completion")
            }
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
            NotificationCenter.default.post(name: .focusSessionEnded, object: session)
            
            // Deactivate Flow Hold when session ends
            if FlowHoldService.shared.isActive {
                FlowHoldService.shared.deactivateFlowHold()
                logger.info("Flow Hold deactivated after session abandonment")
            }
        } catch {
            logger.error("Failed to abandon focus session: \(error.localizedDescription)")
            throw FocusSessionError.saveFailed
        }
        
        return session
    }
    
    // MARK: - Flow Hold Integration
    
    /// Determine if Flow Hold should be activated for this session
    private func shouldActivateFlowHold(for session: FocusSession) -> Bool {
        // Check if auto-activation is enabled
        guard FlowHoldSettings.shared.isAutoActivationEnabled else {
            return false
        }
        
        // Activate for deep work sessions (longer duration or specific energy requirement)
        // Sessions >= 45 minutes are considered deep work
        if session.plannedDuration >= FlowHoldSettings.shared.minimumDuration {
            return true
        }
        
        // Could also check energy requirement if stored on session
        // For now, use duration as the primary indicator
        
        return false
    }
    
    /// Get current focus streak count (consecutive days with completed sessions)
    func getStreakCount(modelContext: ModelContext) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())
        
        while streak < 365 { // Max 365 day streak
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: checkDate) ?? checkDate
            let dayRange = DateInterval(start: checkDate, end: dayEnd)
            let daySessions = getSessions(in: dayRange, modelContext: modelContext)
            let completed = daySessions.filter { $0.status == .completed }
            
            if completed.isEmpty {
                break
            }
            
            streak += 1
            guard let prevDate = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prevDate
        }
        
        return streak
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
    ) async throws -> [TimeSlot] {
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
    
    // MARK: - V2: Pause/Resume
    
    /// Pause the active session
    func pauseSession(modelContext: ModelContext) throws {
        guard let session = getActiveSession(modelContext: modelContext) else {
            throw FocusSessionError.noActiveSession
        }
        
        guard !session.isPaused else {
            return // Already paused
        }
        
        session.isPaused = true
        session.pauseStartTime = Date()
        
        do {
            try modelContext.save()
            logger.info("Focus session paused: \(session.id.uuidString)")
            NotificationCenter.default.post(name: .focusSessionStatusChanged, object: session)
        } catch {
            logger.error("Failed to pause session: \(error.localizedDescription)")
            throw FocusSessionError.saveFailed
        }
    }
    
    /// Resume a paused session
    func resumeSession(modelContext: ModelContext) throws {
        guard let session = getActiveSession(modelContext: modelContext) else {
            throw FocusSessionError.noActiveSession
        }
        
        guard session.isPaused, let pauseStart = session.pauseStartTime else {
            return // Not paused
        }
        
        let pauseDuration = Date().timeIntervalSince(pauseStart)
        session.pausedDuration += pauseDuration
        session.isPaused = false
        session.pauseStartTime = nil
        
        do {
            try modelContext.save()
            logger.info("Focus session resumed: \(session.id.uuidString)")
            NotificationCenter.default.post(name: .focusSessionStatusChanged, object: session)
        } catch {
            logger.error("Failed to resume session: \(error.localizedDescription)")
            throw FocusSessionError.saveFailed
        }
    }
    
    // MARK: - V2: LF Recording
    
    /// Record a Luminance Field value for the active session
    func recordLFValue(_ value: Double, for session: FocusSession, modelContext: ModelContext) {
        guard session.status == .active else { return }
        
        session.lfHistory.append(value)
        
        // Calculate average LF
        if !session.lfHistory.isEmpty {
            session.averageLF = session.lfHistory.reduce(0.0, +) / Double(session.lfHistory.count)
        }
        
        // Calculate emotional variance (standard deviation)
        if session.lfHistory.count >= 2 {
            let mean = session.averageLF ?? 0.0
            let variance = session.lfHistory.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(session.lfHistory.count)
            session.emotionalVariance = sqrt(variance)
        }
        
        // Calculate focus gravity trend (rolling window of last 5 minutes)
        updateFocusGravityTrend(for: session)
        
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save LF value: \(error.localizedDescription)")
        }
    }
    
    /// Update focus gravity trend for session
    private func updateFocusGravityTrend(for session: FocusSession) {
        guard session.lfHistory.count >= 2 else {
            session.focusGravityTrend = []
            return
        }
        
        // Use rolling window: last 5 minutes of data
        // For simplicity, use last 10 LF values (assuming ~30s intervals)
        let windowSize = min(10, session.lfHistory.count)
        let recentValues = Array(session.lfHistory.suffix(windowSize))
        
        // Calculate stability: inverse of variance
        let mean = recentValues.reduce(0.0, +) / Double(recentValues.count)
        let variance = recentValues.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(recentValues.count)
        let stability = 1.0 / (1.0 + variance) // Normalize to 0-1 range
        
        // Update trend array
        if session.focusGravityTrend == nil {
            session.focusGravityTrend = []
        }
        session.focusGravityTrend?.append(stability)
        
        // Keep trend to reasonable size (last 100 points)
        if let trend = session.focusGravityTrend, trend.count > 100 {
            session.focusGravityTrend = Array(trend.suffix(100))
        }
    }
    
    // MARK: - V2: Session Metrics
    
    /// Calculate comprehensive session metrics
    func calculateSessionMetrics(for session: FocusSession, modelContext: ModelContext) -> FocusSessionMetrics {
        // Calculate stability index
        let stabilityIndex: Double
        if let trend = session.focusGravityTrend, !trend.isEmpty {
            // Average of focus gravity trend
            stabilityIndex = trend.reduce(0.0, +) / Double(trend.count) * 100.0
        } else {
            // Fallback: use LF variance (inverse)
            if let variance = session.emotionalVariance {
                stabilityIndex = max(0, min(100, (1.0 - variance) * 100.0))
            } else {
                stabilityIndex = 50.0 // Default neutral
            }
        }
        
        session.stabilityIndex = stabilityIndex
        
        return FocusSessionMetrics(
            averageLF: session.averageLF ?? 0.0,
            stabilityIndex: stabilityIndex,
            emotionalVariance: session.emotionalVariance ?? 0.0,
            focusGravityTrend: session.focusGravityTrend ?? [],
            focusStabilityPercentage: session.focusStabilityPercentage
        )
    }
    
    /// Calculate streak (consecutive days with completed sessions)
    func calculateStreak(modelContext: ModelContext) -> Int {
        return getStreakCount(modelContext: modelContext)
    }
}

// MARK: - V2: Focus Session Metrics

struct FocusSessionMetrics {
    let averageLF: Double
    let stabilityIndex: Double
    let emotionalVariance: Double
    let focusGravityTrend: [Double]
    let focusStabilityPercentage: Double
}

// MARK: - Flow Hold Settings

@MainActor
final class FlowHoldSettings: ObservableObject {
    static let shared = FlowHoldSettings()
    
    private struct Keys {
        static let autoActivationEnabled = "flowHold.autoActivationEnabled"
        static let minimumDuration = "flowHold.minimumDuration"
    }
    
    @Published var isAutoActivationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAutoActivationEnabled, forKey: Keys.autoActivationEnabled)
        }
    }
    
    @Published var minimumDuration: TimeInterval {
        didSet {
            UserDefaults.standard.set(minimumDuration, forKey: Keys.minimumDuration)
        }
    }
    
    private init() {
        self.isAutoActivationEnabled = UserDefaults.standard.object(forKey: Keys.autoActivationEnabled) as? Bool ?? true
        if let value = UserDefaults.standard.object(forKey: Keys.minimumDuration) as? TimeInterval {
            self.minimumDuration = value
        } else {
            self.minimumDuration = 2700 // Default 45 minutes
        }
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

