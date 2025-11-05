//
//  WorkflowPattern.swift
//  Cloutmate
//
//  Phase 6.1 - Smart Automation Engine
//  Models for workflow patterns and automation rules
//

import Foundation
import SwiftData
import Combine

/// A detected recurring pattern in user behavior
@Model
final class WorkflowPattern {
    @Attribute(.unique) var id: UUID = UUID()
    
    var patternType: String                 // WorkflowPatternType
    var name: String
    var patternDescription: String
    var confidence: Double = 0.0            // 0.0-1.0 confidence score
    var occurrenceCount: Int = 0
    var lastOccurred: Date = Date()
    var firstDetected: Date = Date()
    
    // Pattern metadata
    var triggerConditions: [String] = []    // JSON-serialized conditions
    var suggestedActions: [String] = []     // JSON-serialized actions
    var frequency: String = "daily"         // daily, weekly, monthly
    var dayOfWeek: Int?                     // For weekly patterns
    var timeOfDay: Int?                     // Hour of day (0-23)
    
    // User interaction
    var isActive: Bool = true
    var userAcceptedSuggestion: Bool = false
    var userDismissedSuggestion: Bool = false
    var automationEnabled: Bool = false
    
    init(
        patternType: String,
        name: String,
        patternDescription: String,
        confidence: Double = 0.0
    ) {
        self.patternType = patternType
        self.name = name
        self.patternDescription = patternDescription
        self.confidence = confidence
        self.firstDetected = Date()
        self.lastOccurred = Date()
    }
    
    func recordOccurrence() {
        occurrenceCount += 1
        lastOccurred = Date()
        
        // Increase confidence with each occurrence (max 1.0)
        confidence = min(1.0, confidence + 0.1)
    }
}

/// Types of workflow patterns
enum WorkflowPatternType: String, Codable, CaseIterable {
    case recurringTask = "recurring_task"           // User creates same task regularly
    case timeBlockPattern = "time_block"            // User focuses at specific times
    case contentSchedule = "content_schedule"       // User posts at specific times
    case projectSequence = "project_sequence"       // User follows specific workflow
    case emotionalCycle = "emotional_cycle"         // User has emotional patterns
    case contextSwitch = "context_switch"           // User switches contexts predictably
}

/// Automation rule created from pattern or user-defined
@Model
final class AutomationRule {
    @Attribute(.unique) var id: UUID = UUID()
    
    var name: String
    var ruleDescription: String
    var isEnabled: Bool = true
    var patternId: UUID?                    // Optional link to WorkflowPattern
    
    // Rule definition
    var triggerType: String                 // AutomationTriggerType
    var triggerConditions: Data?            // JSON-serialized conditions
    var actions: Data?                      // JSON-serialized actions
    
    // Execution tracking
    var executionCount: Int = 0
    var lastExecuted: Date?
    var successCount: Int = 0
    var failureCount: Int = 0
    var avgExecutionTime: Double = 0.0      // Seconds
    
    // Metadata
    var createdAt: Date = Date()
    var createdBy: String = "system"        // "system" or "user"
    var category: String = "general"
    
    init(
        name: String,
        ruleDescription: String,
        triggerType: String,
        patternId: UUID? = nil
    ) {
        self.name = name
        self.ruleDescription = ruleDescription
        self.triggerType = triggerType
        self.patternId = patternId
        self.createdAt = Date()
    }
    
    func recordExecution(success: Bool, duration: Double) {
        executionCount += 1
        lastExecuted = Date()
        
        if success {
            successCount += 1
        } else {
            failureCount += 1
        }
        
        // Update average execution time
        avgExecutionTime = (avgExecutionTime * Double(executionCount - 1) + duration) / Double(executionCount)
    }
}

/// Trigger types for automation rules
enum AutomationTriggerType: String, Codable, CaseIterable {
    case timeOfDay = "time_of_day"          // Trigger at specific time
    case dayOfWeek = "day_of_week"          // Trigger on specific day
    case taskComplete = "task_complete"     // Trigger when task completed
    case projectStart = "project_start"     // Trigger when project starts
    case emotionDetected = "emotion"        // Trigger on emotional state
    case focusStart = "focus_start"         // Trigger when focus session starts
    case contentPublish = "content_publish" // Trigger when content published
    case contextSwitch = "context_switch"   // Trigger on workspace context change
}

/// Workflow template for quick setup
@Model
final class WorkflowTemplate {
    @Attribute(.unique) var id: UUID = UUID()
    
    var name: String
    var templateDescription: String
    var category: String                    // "productivity", "content", "learning", etc.
    var icon: String = "star"
    
    // Template definition
    var steps: Data?                        // JSON-serialized workflow steps
    var automationRules: Data?              // JSON-serialized rules to create
    var defaultSettings: Data?              // JSON-serialized settings
    
    // Usage tracking
    var usageCount: Int = 0
    var lastUsed: Date?
    var avgSuccessRate: Double = 0.0
    var userRating: Double = 0.0            // 0.0-5.0 stars
    
    // Metadata
    var isBuiltIn: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    init(
        name: String,
        templateDescription: String,
        category: String,
        isBuiltIn: Bool = false
    ) {
        self.name = name
        self.templateDescription = templateDescription
        self.category = category
        self.isBuiltIn = isBuiltIn
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    func recordUsage() {
        usageCount += 1
        lastUsed = Date()
    }
}

/// Serializable automation action
struct AutomationAction: Codable, Sendable {
    let type: ActionType
    let parameters: [String: String]
    
    enum ActionType: String, Codable {
        case createTask = "create_task"
        case updateTask = "update_task"
        case createNote = "create_note"
        case startFocus = "start_focus"
        case sendNotification = "notification"
        case updatePriority = "update_priority"
        case createDraft = "create_draft"
        case schedulePost = "schedule_post"
        case logFeedback = "log_feedback"
    }
}

/// Serializable trigger condition
struct TriggerCondition: Codable, Sendable {
    let field: String                       // e.g., "time", "dayOfWeek", "taskStatus"
    let operation: Operation
    let value: String
    
    enum Operation: String, Codable {
        case equals = "=="
        case notEquals = "!="
        case greaterThan = ">"
        case lessThan = "<"
        case contains = "contains"
        case matches = "matches"
    }
    
    func evaluate(context: [String: Any]) -> Bool {
        guard let actualValue = context[field] else { return false }
        
        switch operation {
        case .equals:
            return "\(actualValue)" == value
        case .notEquals:
            return "\(actualValue)" != value
        case .greaterThan:
            if let actual = actualValue as? Double, let expected = Double(value) {
                return actual > expected
            }
            return false
        case .lessThan:
            if let actual = actualValue as? Double, let expected = Double(value) {
                return actual < expected
            }
            return false
        case .contains:
            return "\(actualValue)".localizedCaseInsensitiveContains(value)
        case .matches:
            // Simple regex matching
            return "\(actualValue)".range(of: value, options: .regularExpression) != nil
        }
    }
}

