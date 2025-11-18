//
//  AIFeedbackLogger.swift
//  FocusOS
//
//  Records AI-driven actions and produces usage summaries.
//

import Foundation
import SwiftData
import Combine

@Model
final class AIFeedbackEvent {
    var id: UUID = UUID()
    var actionName: String
    var resultMessage: String
    var itemsAffected: Int
    var createdAt: Date
    var metadata: [String: String]
    var affectedObjectIDs: [UUID]
    
    init(
        actionName: String,
        resultMessage: String,
        itemsAffected: Int,
        createdAt: Date = Date(),
        metadata: [String: String] = [:],
        affectedObjectIDs: [UUID] = []
    ) {
        self.id = UUID()
        self.actionName = actionName
        self.resultMessage = resultMessage
        self.itemsAffected = itemsAffected
        self.createdAt = createdAt
        self.metadata = metadata
        self.affectedObjectIDs = affectedObjectIDs
    }
}

@MainActor
final class AIFeedbackLogger {
    static let shared = AIFeedbackLogger()
    
    private init() {}
    
    private var config: AIConfig {
        AIConfigService.shared.config
    }
    
    @discardableResult
    func record(
        action: AIIntentAction,
        result: AIActionResult,
        modelContext: ModelContext
    ) -> FeedbackSummary? {
        guard config.featureFlags.feedbackLoggingEnabled else {
            return nil
        }
        
        let event = AIFeedbackEvent(
            actionName: action.displayName,
            resultMessage: result.message,
            itemsAffected: result.itemsAffected,
            metadata: result.metadata,
            affectedObjectIDs: result.affectedObjectIDs
        )
        
        modelContext.insert(event)
        do {
            try modelContext.save()
        } catch {
            AIDebug.log("Failed to save feedback event: \(error.localizedDescription)")
        }
        
        if !result.affectedObjectIDs.isEmpty {
            // Boost recall importance
            AIRecallService.shared.boostImportance(
                for: result.affectedObjectIDs,
                amount: 0.05,
                engagementIncrement: engagementIncrement(for: action),
                modelContext: modelContext
            )

            // Boost CPS priority (feedback loop)
            PriorityEngine.shared.boostScore(
                for: result.affectedObjectIDs,
                amount: 0.15,
                modelContext: modelContext
            )
        }
        
        return FeedbackSummary(
            title: action.displayName,
            detail: result.message,
            timestamp: event.createdAt
        )
    }
    
    func recentSummaries(
        limit: Int = 5,
        modelContext: ModelContext
    ) -> [FeedbackSummary] {
        guard config.featureFlags.feedbackLoggingEnabled else { return [] }
        
        var descriptor = FetchDescriptor<AIFeedbackEvent>(
            sortBy: [SortDescriptor(\AIFeedbackEvent.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        guard let events = try? modelContext.fetch(descriptor) else {
            return []
        }
        
        return events.map { event in
            FeedbackSummary(
                title: event.actionName,
                detail: event.resultMessage,
                timestamp: event.createdAt
            )
        }
    }
    
    private func engagementIncrement(for action: AIIntentAction) -> Double {
        switch action {
        case .createTask, .updateTask, .deleteTask,
             .createNote, .updateNote, .deleteNote,
             .createProject, .updateProject, .deleteProject,
             .convertInboxItem, .addInboxItem:
            return 0.3
        case .createPost, .publishPost:
            return 0.25
        case .archiveTasks, .summarizePosts, .generateReport, .predictScheduling:
            return 0.2
        case .digestConversation, .digestAllConversations, .searchConversations:
            return 0.1
        default:
            return 0.15
        }
    }
    
    func weeklyActivitySummary(modelContext: ModelContext) -> FeedbackSummary? {
        guard config.featureFlags.feedbackLoggingEnabled else { return nil }
        
        let now = Date()
        guard let startDate = Calendar.current.date(byAdding: .day, value: -7, to: now) else {
            return nil
        }
        
        let descriptor = FetchDescriptor<AIFeedbackEvent>(
            predicate: #Predicate { $0.createdAt >= startDate },
            sortBy: [SortDescriptor(\AIFeedbackEvent.createdAt, order: .reverse)]
        )
        
        guard let events = try? modelContext.fetch(descriptor), !events.isEmpty else {
            return nil
        }
        
        let actionsCount = events.count
        let itemsTouched = events.reduce(0) { $0 + max(0, $1.itemsAffected) }
        
        // Derive top action keywords
        let grouped = Dictionary(grouping: events) { $0.actionName }
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        let topContexts = grouped.prefix(3).map { "\($0.key.lowercased())" }
        let contextPhrase = topContexts.isEmpty ? "no dominant focus" : topContexts.joined(separator: ", ")
        
        // Include focus session stats if enabled
        var focusAddendum = ""
        if config.featureFlags.focusModeEnabled {
            let sessionStats = FocusSessionService.shared.getSessionStats(
                for: DateInterval(start: startDate, end: now),
                modelContext: modelContext
            )
            if sessionStats.totalSessions > 0 {
                let focusHours = Int(sessionStats.totalFocusTime / 3600)
                let focusMinutes = Int((sessionStats.totalFocusTime.truncatingRemainder(dividingBy: 3600)) / 60)
                let completionPct = Int(sessionStats.completionRate * 100)
                focusAddendum = " Focus: \(sessionStats.totalSessions) session\(sessionStats.totalSessions == 1 ? "" : "s"), \(focusHours)h \(focusMinutes)m, \(completionPct)% completion."
            }
        }
        
        let detail = """
AI processed \(actionsCount) action\(actionsCount == 1 ? "" : "s") this week; \(itemsTouched) items touched. Top recurring contexts: \(contextPhrase).\(focusAddendum)
"""
        
        return FeedbackSummary(
            title: "Weekly AI Activity",
            detail: detail,
            timestamp: now
        )
    }
    
    // MARK: - Focus Session Logging
    
    /// Log a focus session completion/abandonment
    func recordFocusSession(
        session: FocusSession,
        modelContext: ModelContext
    ) -> FeedbackSummary? {
        guard config.featureFlags.feedbackLoggingEnabled else { return nil }
        
        let actionName = session.status == .completed ? "Focus Session Completed" : "Focus Session Abandoned"
        let resultMessage = session.completionSummary
        
        let event = AIFeedbackEvent(
            actionName: actionName,
            resultMessage: resultMessage,
            itemsAffected: session.itemsCompleted.count,
            metadata: [
                "objective": session.objective,
                "duration": String(session.actualDuration),
                "completed": String(session.completed)
            ],
            affectedObjectIDs: session.itemsCompleted
        )
        
        modelContext.insert(event)
        do {
            try modelContext.save()
        } catch {
            AIDebug.log("Failed to save focus session feedback: \(error.localizedDescription)")
        }
        
        return FocusSessionService.shared.generateSessionSummary(session: session)
    }
}
