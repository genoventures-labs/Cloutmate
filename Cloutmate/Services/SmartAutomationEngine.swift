//
//  SmartAutomationEngine.swift
//  Cloutmate
//
//  Phase 6.1 - Smart Automation Engine
//  Pattern recognition, workflow suggestions, and automated actions
//

import Foundation
import SwiftData
import CloutmateShared
import os.log

@MainActor
final class SmartAutomationEngine {
    static let shared = SmartAutomationEngine()
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "Automation")
    
    private var isPatternDetectionActive = false
    private var isRuleExecutionActive = false
    
    private init() {}
    
    func getPendingSuggestions(
        limit: Int = 1,
        modelContext: ModelContext
    ) -> [WorkflowPattern] {
        var descriptor = FetchDescriptor<WorkflowPattern>(
            predicate: #Predicate { pattern in
                pattern.isActive &&
                !pattern.userDismissedSuggestion &&
                !pattern.userAcceptedSuggestion &&
                pattern.confidence >= 0.7
            },
            sortBy: [SortDescriptor(\WorkflowPattern.confidence, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    // MARK: - Pattern Detection
    
    /// Analyze user behavior and detect recurring patterns
    func detectPatterns(modelContext: ModelContext) async {
        guard !isPatternDetectionActive else { return }
        isPatternDetectionActive = true
        defer { isPatternDetectionActive = false }
        
        logger.info("Starting pattern detection")
        
        // Detect different pattern types in parallel
        await detectRecurringTaskPatterns(modelContext: modelContext)
        await detectTimeBlockPatterns(modelContext: modelContext)
        await detectContentSchedulePatterns(modelContext: modelContext)
        await detectEmotionalCyclePatterns(modelContext: modelContext)
        
        logger.info("Pattern detection complete")
    }
    
    /// Detect tasks that user creates repeatedly
    private func detectRecurringTaskPatterns(modelContext: ModelContext) async {
        let taskDescriptor = FetchDescriptor<CloutmateShared.Task>()
        guard let tasks = try? modelContext.fetch(taskDescriptor) else { return }
        
        // Group tasks by similar titles
        var titleGroups: [String: [CloutmateShared.Task]] = [:]
        
        for task in tasks {
            let normalizedTitle = task.title.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            // Check for similar titles (simple substring matching)
            var foundGroup = false
            for existingTitle in titleGroups.keys {
                if normalizedTitle.contains(existingTitle) || existingTitle.contains(normalizedTitle) {
                    titleGroups[existingTitle, default: []].append(task)
                    foundGroup = true
                    break
                }
            }
            
            if !foundGroup {
                titleGroups[normalizedTitle] = [task]
            }
        }
        
        // Identify recurring patterns (3+ occurrences)
        for (baseTitle, groupedTasks) in titleGroups where groupedTasks.count >= 3 {
            // Check if pattern already exists
            let patternDescriptor = FetchDescriptor<WorkflowPattern>(
                predicate: #Predicate { pattern in
                    pattern.patternType == "recurring_task" && pattern.name.contains(baseTitle)
                }
            )
            
            if let existingPattern = try? modelContext.fetch(patternDescriptor).first {
                // Update existing pattern
                existingPattern.recordOccurrence()
            } else {
                // Create new pattern
                let pattern = WorkflowPattern(
                    patternType: WorkflowPatternType.recurringTask.rawValue,
                    name: "Recurring: \(baseTitle.capitalized)",
                    patternDescription: "You create this task regularly (\(groupedTasks.count) times)",
                    confidence: min(1.0, Double(groupedTasks.count) * 0.2)
                )
                
                pattern.occurrenceCount = groupedTasks.count
                pattern.suggestedActions = ["Create recurring task template", "Set up automation rule"]
                
                modelContext.insert(pattern)
                logger.info("Detected recurring task pattern: \(baseTitle)")
            }
        }
        
        try? modelContext.save()
    }
    
    /// Detect when user typically does focus work
    private func detectTimeBlockPatterns(modelContext: ModelContext) async {
        let sessionDescriptor = FetchDescriptor<FocusSession>()
        guard let sessions = try? modelContext.fetch(sessionDescriptor) else { return }
        
        // Group sessions by hour of day
        var hourlyDistribution: [Int: Int] = [:]
        
        for session in sessions {
            let hour = Calendar.current.component(.hour, from: session.startTime)
            hourlyDistribution[hour, default: 0] += 1
        }
        
        // Find peak hours (>= 3 sessions)
        for (hour, count) in hourlyDistribution where count >= 3 {
            let patternDescriptor = FetchDescriptor<WorkflowPattern>(
                predicate: #Predicate { pattern in
                    pattern.patternType == "time_block" && pattern.timeOfDay == hour
                }
            )
            
            if let existingPattern = try? modelContext.fetch(patternDescriptor).first {
                existingPattern.recordOccurrence()
            } else {
                let pattern = WorkflowPattern(
                    patternType: WorkflowPatternType.timeBlockPattern.rawValue,
                    name: "Focus Time: \(hour):00",
                    patternDescription: "You typically focus around \(hour):00 (\(count) sessions)",
                    confidence: min(1.0, Double(count) * 0.15)
                )
                
                pattern.timeOfDay = hour
                pattern.occurrenceCount = count
                pattern.suggestedActions = ["Schedule recurring focus session", "Block calendar"]
                
                modelContext.insert(pattern)
                logger.info("Detected time block pattern: \(hour):00")
            }
        }
        
        try? modelContext.save()
    }
    
    /// Detect when user typically publishes content
    private func detectContentSchedulePatterns(modelContext: ModelContext) async {
        let postDescriptor = FetchDescriptor<Post>()
        
        guard let allPosts = try? modelContext.fetch(postDescriptor) else { return }
        
        let posts = allPosts.filter { $0.publishedDate != nil }
        
        // Group by day of week and hour
        var scheduleDistribution: [Int: [Int: Int]] = [:] // [dayOfWeek: [hour: count]]
        
        for post in posts {
            guard let publishedAt = post.publishedDate else { continue }
            
            let dayOfWeek = Calendar.current.component(.weekday, from: publishedAt)
            let hour = Calendar.current.component(.hour, from: publishedAt)
            
            if scheduleDistribution[dayOfWeek] == nil {
                scheduleDistribution[dayOfWeek] = [:]
            }
            scheduleDistribution[dayOfWeek]?[hour, default: 0] += 1
        }
        
        // Find patterns (>= 3 posts at same day/time)
        for (dayOfWeek, hourDistribution) in scheduleDistribution {
            for (hour, count) in hourDistribution where count >= 3 {
                let dayName = Calendar.current.weekdaySymbols[dayOfWeek - 1]
                
                let patternDescriptor = FetchDescriptor<WorkflowPattern>(
                    predicate: #Predicate { pattern in
                        pattern.patternType == "content_schedule" && 
                        pattern.dayOfWeek == dayOfWeek && 
                        pattern.timeOfDay == hour
                    }
                )
                
                if let existingPattern = try? modelContext.fetch(patternDescriptor).first {
                    existingPattern.recordOccurrence()
                } else {
                    let pattern = WorkflowPattern(
                        patternType: WorkflowPatternType.contentSchedule.rawValue,
                        name: "Post Schedule: \(dayName) \(hour):00",
                        patternDescription: "You typically post on \(dayName)s around \(hour):00",
                        confidence: min(1.0, Double(count) * 0.2)
                    )
                    
                    pattern.dayOfWeek = dayOfWeek
                    pattern.timeOfDay = hour
                    pattern.frequency = "weekly"
                    pattern.occurrenceCount = count
                    pattern.suggestedActions = ["Schedule posts automatically", "Set up content calendar"]
                    
                    modelContext.insert(pattern)
                    logger.info("Detected content schedule pattern: \(dayName) \(hour):00")
                }
            }
        }
        
        try? modelContext.save()
    }
    
    /// Detect emotional cycles in user behavior
    private func detectEmotionalCyclePatterns(modelContext: ModelContext) async {
        // Skip for now - emotional tracking needs ConversationDigest integration
        // This can be enhanced when emotional valence is tracked in AIConversation
        return

    }
    
    // MARK: - Workflow Suggestions
    
    /// Get actionable suggestions based on detected patterns
    func getWorkflowSuggestions(modelContext: ModelContext) -> [WorkflowSuggestion] {
        let patternDescriptor = FetchDescriptor<WorkflowPattern>(
            predicate: #Predicate { pattern in
                pattern.isActive && 
                !pattern.userDismissedSuggestion && 
                !pattern.automationEnabled &&
                pattern.confidence >= 0.5
            },
            sortBy: [SortDescriptor(\WorkflowPattern.confidence, order: .reverse)]
        )
        
        guard let patterns = try? modelContext.fetch(patternDescriptor) else { return [] }
        
        return patterns.map { pattern in
            WorkflowSuggestion(
                id: pattern.id,
                title: pattern.name,
                description: pattern.patternDescription,
                confidence: pattern.confidence,
                patternType: WorkflowPatternType(rawValue: pattern.patternType) ?? .recurringTask,
                suggestedActions: pattern.suggestedActions,
                canAutomate: true
            )
        }
    }
    
    // MARK: - Rule Execution
    
    /// Execute automation rules based on current context
    func executeRules(context: [String: Any], modelContext: ModelContext) async {
        guard !isRuleExecutionActive else { return }
        isRuleExecutionActive = true
        defer { isRuleExecutionActive = false }
        
        let ruleDescriptor = FetchDescriptor<AutomationRule>(
            predicate: #Predicate { rule in
                rule.isEnabled
            }
        )
        
        guard let rules = try? modelContext.fetch(ruleDescriptor) else { return }
        
        for rule in rules {
            await executeRule(rule, context: context, modelContext: modelContext)
        }
    }
    
    private func executeRule(_ rule: AutomationRule, context: [String: Any], modelContext: ModelContext) async {
        let startTime = Date()
        
        do {
            // Decode conditions
            guard let conditionsData = rule.triggerConditions,
                  let conditions = try? JSONDecoder().decode([TriggerCondition].self, from: conditionsData) else {
                return
            }
            
            // Check if all conditions are met
            let allConditionsMet = conditions.allSatisfy { $0.evaluate(context: context) }
            guard allConditionsMet else { return }
            
            logger.info("Executing automation rule: \(rule.name)")
            
            // Decode actions
            guard let actionsData = rule.actions,
                  let actions = try? JSONDecoder().decode([AutomationAction].self, from: actionsData) else {
                return
            }
            
            // Execute actions
            for action in actions {
                try await executeAction(action, modelContext: modelContext)
            }
            
            // Record successful execution
            let duration = Date().timeIntervalSince(startTime)
            rule.recordExecution(success: true, duration: duration)
            try? modelContext.save()
            
        } catch {
            logger.error("Failed to execute rule '\(rule.name)': \(error.localizedDescription)")
            
            let duration = Date().timeIntervalSince(startTime)
            rule.recordExecution(success: false, duration: duration)
            try? modelContext.save()
        }
    }
    
    private func executeAction(_ action: AutomationAction, modelContext: ModelContext) async throws {
        switch action.type {
        case .createTask:
            guard let title = action.parameters["title"] else { return }
            let task = CloutmateShared.Task(title: title)
            if let priorityStr = action.parameters["priority"],
               let priority = TaskPriority(rawValue: priorityStr) {
                task.priority = priority
            }
            modelContext.insert(task)
            
        case .updateTask:
            // Implementation depends on task lookup logic
            break
            
        case .createNote:
            guard let title = action.parameters["title"] else { return }
            let note = CloutmateShared.Note(title: title)
            modelContext.insert(note)
            
        case .startFocus:
            guard let objective = action.parameters["objective"] else { return }
            let duration = TimeInterval(Int(action.parameters["duration"] ?? "25") ?? 25)
            let session = FocusSession(
                objective: objective,
                plannedDuration: duration
            )
            modelContext.insert(session)
            
        case .sendNotification:
            // Notification handling
            break
            
        case .updatePriority:
            // Priority update logic
            break
            
        case .createDraft:
            guard let caption = action.parameters["caption"] else { return }
            let post = Post(caption: caption, platforms: ["facebook"])
            modelContext.insert(post)
            
        case .schedulePost:
            // Scheduling logic
            break
            
        case .logFeedback:
            // Feedback events are logged by AIFeedbackLogger, not inserted directly
            break
        }
        
        try modelContext.save()
    }
    
    // MARK: - Template Management
    
    /// Get built-in workflow templates
    func getBuiltInTemplates() -> [WorkflowTemplate] {
        // These would be pre-populated on first launch
        return []
    }
    
    /// Apply workflow template
    func applyTemplate(_ template: WorkflowTemplate, modelContext: ModelContext) async throws {
        template.recordUsage()
        
        // Decode and create automation rules from template
        if let rulesData = template.automationRules,
           let rules = try? JSONDecoder().decode([[String: String]].self, from: rulesData) {
            
            for ruleDict in rules {
                guard let name = ruleDict["name"],
                      let description = ruleDict["description"],
                      let triggerType = ruleDict["triggerType"] else { continue }
                
                let rule = AutomationRule(
                    name: name,
                    ruleDescription: description,
                    triggerType: triggerType
                )
                
                rule.createdBy = "template:\(template.name)"
                modelContext.insert(rule)
            }
        }
        
        try modelContext.save()
        logger.info("Applied workflow template: \(template.name)")
    }
}

/// Workflow suggestion presented to user
struct WorkflowSuggestion: Identifiable, Sendable {
    let id: UUID
    let title: String
    let description: String
    let confidence: Double
    let patternType: WorkflowPatternType
    let suggestedActions: [String]
    let canAutomate: Bool
}

