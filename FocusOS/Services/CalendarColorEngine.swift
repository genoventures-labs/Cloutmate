//
//  CalendarColorEngine.swift
//  FocusOS
//
//  Aurora Calendar Cognition Layer - Core color assignment logic
//

import Foundation
import SwiftData
import os.log
import FocusOSShared

@MainActor
final class CalendarColorEngine {
    static let shared = CalendarColorEngine()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "CalendarColorEngine")
    
    private init() {}
    
    // MARK: - Weight Configuration
    
    private struct FactorWeights {
        let deadlineProximity: Double = 0.25
        let overdueTasks: Double = 0.20
        let projectPhase: Double = 0.15
        let userPriority: Double = 0.10
        let slippage: Double = 0.10
        let effort: Double = 0.08
        let energyMatch: Double = 0.05
        let streakRisk: Double = 0.04
        let ritualStatus: Double = 0.02
        let workloadDensity: Double = 0.01
    }
    
    private let weights = FactorWeights()
    
    // MARK: - Core Color Assignment
    
    struct ColorAnalysisResult {
        let color: EventColor
        let urgencyScore: Double
        let primaryFactor: String
        let secondaryFactors: [String]
        let explanation: String
        let factors: [String: Double]
    }
    
    func computeColor(
        for event: CalendarEvent,
        context: ColorAnalysisContext,
        modelContext: ModelContext
    ) -> ColorAnalysisResult {
        var factors: [String: Double] = [:]
        var factorDescriptions: [String] = []
        
        // 1. Deadline proximity
        let deadlineScore = computeDeadlineProximityScore(for: event, context: context)
        factors["deadline"] = deadlineScore
        if deadlineScore > 0.7 {
            factorDescriptions.append("deadline")
        }
        
        // 2. Overdue linked tasks
        let overdueScore = computeOverdueTasksScore(for: event, context: context, modelContext: modelContext)
        factors["overdue"] = overdueScore
        if overdueScore > 0.5 {
            factorDescriptions.append("overdue")
        }
        
        // 3. Project phase urgency
        let projectScore = computeProjectPhaseScore(for: event, context: context, modelContext: modelContext)
        factors["project"] = projectScore
        if projectScore > 0.6 {
            factorDescriptions.append("project")
        }
        
        // 4. User-set priority
        let priorityScore = computePriorityScore(for: event, context: context, modelContext: modelContext)
        factors["priority"] = priorityScore
        if priorityScore > 0.6 {
            factorDescriptions.append("priority")
        }
        
        // 5. Actual vs planned slippage
        let slippageScore = computeSlippageScore(for: event, context: context, modelContext: modelContext)
        factors["slippage"] = slippageScore
        if slippageScore > 0.5 {
            factorDescriptions.append("slippage")
        }
        
        // 6. Effort required
        let effortScore = computeEffortScore(for: event, context: context, modelContext: modelContext)
        factors["effort"] = effortScore
        if effortScore > 0.6 {
            factorDescriptions.append("effort")
        }
        
        // 7. Energy/time of day match
        let energyScore = computeEnergyMatchScore(for: event, context: context)
        factors["energy"] = energyScore
        if energyScore > 0.7 {
            factorDescriptions.append("energy")
        }
        
        // 8. Streak risk
        let streakScore = computeStreakRiskScore(for: event, context: context)
        factors["streak"] = streakScore
        if streakScore > 0.5 {
            factorDescriptions.append("streak")
        }
        
        // 9. Ritual/anchor status
        let ritualScore = computeRitualScore(for: event, context: context)
        factors["ritual"] = ritualScore
        if ritualScore > 0.5 {
            factorDescriptions.append("ritual")
        }
        
        // 10. Daily workload density
        let workloadScore = computeWorkloadDensityScore(for: event, context: context)
        factors["workload"] = workloadScore
        
        // Compute weighted urgency score
        let urgencyScore = (
            deadlineScore * weights.deadlineProximity +
            overdueScore * weights.overdueTasks +
            projectScore * weights.projectPhase +
            priorityScore * weights.userPriority +
            slippageScore * weights.slippage +
            effortScore * weights.effort +
            energyScore * weights.energyMatch +
            streakScore * weights.streakRisk +
            ritualScore * weights.ritualStatus +
            workloadScore * weights.workloadDensity
        )
        
        // Assign color based on urgency
        let color = EventColor.from(urgencyScore: urgencyScore)
        
        // Determine primary factor
        let primaryFactor = factors.max(by: { $0.value < $1.value })?.key ?? "workload"
        
        // Generate explanation
        let explanation = generateExplanation(
            color: color,
            urgencyScore: urgencyScore,
            primaryFactor: primaryFactor,
            factors: factors,
            event: event
        )
        
        return ColorAnalysisResult(
            color: color,
            urgencyScore: urgencyScore,
            primaryFactor: primaryFactor,
            secondaryFactors: factorDescriptions.filter { $0 != primaryFactor },
            explanation: explanation,
            factors: factors
        )
    }
    
    // MARK: - Factor Computations
    
    private func computeDeadlineProximityScore(for event: CalendarEvent, context: ColorAnalysisContext) -> Double {
        let now = Date()
        let eventStart = event.startDate
        
        // Check if event has a deadline (linked task due date)
        if let linkedTaskId = event.linkedEntityIds.first(where: { id in
            event.linkedEntityTypes[event.linkedEntityIds.firstIndex(of: id) ?? 0] == "task"
        }) {
            // We'll need to fetch the task, but for now use event timing
            let hoursUntilEvent = eventStart.timeIntervalSince(now) / 3600
            
            if hoursUntilEvent < 0 {
                return 1.0 // Past deadline
            } else if hoursUntilEvent < 1 {
                return 0.95 // < 1 hour
            } else if hoursUntilEvent < 24 {
                return 0.85 // < 24 hours
            } else if hoursUntilEvent < 72 {
                return 0.65 // < 3 days
            } else if hoursUntilEvent < 168 {
                return 0.40 // < 7 days
            } else {
                return 0.20 // > 7 days
            }
        }
        
        // No linked deadline, use event start time
        let hoursUntilEvent = eventStart.timeIntervalSince(now) / 3600
        if hoursUntilEvent < 1 {
            return 0.60
        } else if hoursUntilEvent < 24 {
            return 0.40
        } else {
            return 0.10
        }
    }
    
    private func computeOverdueTasksScore(for event: CalendarEvent, context: ColorAnalysisContext, modelContext: ModelContext) -> Double {
        let taskIds = event.linkedEntityIds.enumerated().compactMap { index, id -> UUID? in
            guard index < event.linkedEntityTypes.count,
                  event.linkedEntityTypes[index] == "task" else { return nil }
            return id
        }
        
        guard !taskIds.isEmpty else { return 0.0 }
        
        let now = Date()
        var overdueCount = 0
        
        for taskId in taskIds {
            let descriptor = FetchDescriptor<FocusOSShared.Task>(
                predicate: #Predicate { $0.id == taskId }
            )
            if let task = try? modelContext.fetch(descriptor).first,
               let dueDate = task.dueDate,
               dueDate < now,
               task.status != .done {
                overdueCount += 1
            }
        }
        
        return min(1.0, Double(overdueCount) / Double(max(taskIds.count, 1)))
    }
    
    private func computeProjectPhaseScore(for event: CalendarEvent, context: ColorAnalysisContext, modelContext: ModelContext) -> Double {
        let projectIds = event.linkedEntityIds.enumerated().compactMap { index, id -> UUID? in
            guard index < event.linkedEntityTypes.count,
                  event.linkedEntityTypes[index] == "project" else { return nil }
            return id
        }
        
        guard !projectIds.isEmpty else { return 0.0 }
        
        var maxScore = 0.0
        for projectId in projectIds {
            let descriptor = FetchDescriptor<FocusOSShared.Project>(
                predicate: #Predicate { $0.id == projectId }
            )
            if let project = try? modelContext.fetch(descriptor).first {
                let score: Double
                if let dueDate = project.dueDate {
                    let daysUntilDue = dueDate.timeIntervalSince(Date()) / 86400
                    if daysUntilDue < 0 {
                        score = 0.9 // Overdue
                    } else if daysUntilDue < 7 {
                        score = 0.7 // Final push
                    } else if daysUntilDue < 30 {
                        score = 0.5 // Mid phase
                    } else {
                        score = 0.2 // Early phase
                    }
                } else {
                    score = 0.3 // No deadline
                }
                maxScore = max(maxScore, score)
            }
        }
        
        return maxScore
    }
    
    private func computePriorityScore(for event: CalendarEvent, context: ColorAnalysisContext, modelContext: ModelContext) -> Double {
        let taskIds = event.linkedEntityIds.enumerated().compactMap { index, id -> UUID? in
            guard index < event.linkedEntityTypes.count,
                  event.linkedEntityTypes[index] == "task" else { return nil }
            return id
        }
        
        guard !taskIds.isEmpty else { return 0.0 }
        
        var maxPriority = 0.0
        for taskId in taskIds {
            let descriptor = FetchDescriptor<FocusOSShared.Task>(
                predicate: #Predicate { $0.id == taskId }
            )
            if let task = try? modelContext.fetch(descriptor).first {
                let score: Double
                switch task.priority {
                case .high: score = 0.9
                case .medium: score = 0.5
                case .low: score = 0.2
                }
                maxPriority = max(maxPriority, score)
            }
        }
        
        return maxPriority
    }
    
    private func computeSlippageScore(for event: CalendarEvent, context: ColorAnalysisContext, modelContext: ModelContext) -> Double {
        // Check for linked focus sessions with actual vs planned duration
        let plannedDuration = event.endDate.timeIntervalSince(event.startDate)
        
        // Look for focus sessions linked to this event
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { session in
                session.calendarEventId != nil
            }
        )
        
        if let sessions = try? modelContext.fetch(descriptor),
           let session = sessions.first(where: { $0.calendarEventId == event.id.uuidString }) {
            let actualDuration = session.actualDuration
            if actualDuration > 0 {
                let ratio = actualDuration / plannedDuration
                if ratio > 1.25 {
                    return 0.8 // Significant overrun
                } else if ratio > 1.1 {
                    return 0.5 // Moderate overrun
                } else if ratio < 0.75 {
                    return 0.3 // Completed early
                }
            }
        }
        
        return 0.0
    }
    
    private func computeEffortScore(for event: CalendarEvent, context: ColorAnalysisContext, modelContext: ModelContext) -> Double {
        let taskIds = event.linkedEntityIds.enumerated().compactMap { index, id -> UUID? in
            guard index < event.linkedEntityTypes.count,
                  event.linkedEntityTypes[index] == "task" else { return nil }
            return id
        }
        
        guard !taskIds.isEmpty else {
            // Check event duration
            let duration = event.endDate.timeIntervalSince(event.startDate)
            if duration > 3600 { // > 1 hour
                return 0.6
            } else if duration > 1800 { // > 30 min
                return 0.4
            } else {
                return 0.2
            }
        }
        
        var maxEffort = 0.0
        for taskId in taskIds {
            let descriptor = FetchDescriptor<FocusOSShared.Task>(
                predicate: #Predicate { $0.id == taskId }
            )
            if let task = try? modelContext.fetch(descriptor).first,
               let effort = task.effort {
                let score: Double
                switch effort.lowercased() {
                case "large": score = 0.9
                case "medium": score = 0.5
                case "small": score = 0.2
                default: score = 0.4
                }
                maxEffort = max(maxEffort, score)
            }
        }
        
        return maxEffort
    }
    
    private func computeEnergyMatchScore(for event: CalendarEvent, context: ColorAnalysisContext) -> Double {
        // Use CognitionPredictor to get energy forecast for event time
        // For now, use time of day heuristics
        let hour = Calendar.current.component(.hour, from: event.startDate)
        
        // Typical high-energy windows: 9-11am, 2-4pm
        if (9...11).contains(hour) || (14...16).contains(hour) {
            return 0.8
        } else if (7...9).contains(hour) || (11...14).contains(hour) {
            return 0.6
        } else if (16...18).contains(hour) {
            return 0.4
        } else {
            return 0.2
        }
    }
    
    private func computeStreakRiskScore(for event: CalendarEvent, context: ColorAnalysisContext) -> Double {
        // Check if missing this event would break a ritual streak
        // This would require integration with FocusRitualManager
        // For now, return 0.0 (will be enhanced later)
        return 0.0
    }
    
    private func computeRitualScore(for event: CalendarEvent, context: ColorAnalysisContext) -> Double {
        // Check if event is linked to a ritual
        // For now, check event title/notes for ritual keywords
        let title = event.title.lowercased()
        let notes = (event.notes ?? "").lowercased()
        let text = title + " " + notes
        
        if text.contains("ritual") || text.contains("morning") || text.contains("evening") ||
           text.contains("reflection") || text.contains("review") {
            return 0.8
        }
        
        return 0.0
    }
    
    private func computeWorkloadDensityScore(for event: CalendarEvent, context: ColorAnalysisContext) -> Double {
        // Count events on the same day
        let dayStart = Calendar.current.startOfDay(for: event.startDate)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? event.startDate
        
        let eventCount = context.eventsOnDay.filter { otherEvent in
            otherEvent.startDate >= dayStart && otherEvent.startDate < dayEnd
        }.count
        
        // Normalize: 0-5 events = low, 6-10 = medium, 11+ = high
        if eventCount > 10 {
            return 0.8
        } else if eventCount > 5 {
            return 0.5
        } else {
            return 0.2
        }
    }
    
    // MARK: - Explanation Generation
    
    private func generateExplanation(
        color: EventColor,
        urgencyScore: Double,
        primaryFactor: String,
        factors: [String: Double],
        event: CalendarEvent
    ) -> String {
        let hoursUntil = event.startDate.timeIntervalSince(Date()) / 3600
        
        switch primaryFactor {
        case "deadline":
            if hoursUntil < 1 {
                return "Deadline in less than 1 hour"
            } else if hoursUntil < 24 {
                return "Deadline approaching within 24 hours"
            } else {
                return "Deadline within 3 days"
            }
        case "overdue":
            return "Linked to overdue tasks"
        case "project":
            return "Project in final phase"
        case "priority":
            return "High priority task"
        case "slippage":
            return "Tends to run over planned time"
        case "effort":
            return "Requires significant effort"
        case "energy":
            return "Matches your high-energy window"
        case "streak":
            return "Important for maintaining streak"
        case "ritual":
            return "Linked to daily ritual"
        default:
            return color.description
        }
    }
}

// MARK: - Analysis Context

struct ColorAnalysisContext {
    let eventsOnDay: [CalendarEvent]
    let currentDate: Date
    let energyForecast: EnergyForecast?
    
    struct EnergyForecast {
        let peakWindows: [DateInterval]
        let lowEnergyWindows: [DateInterval]
    }
}

