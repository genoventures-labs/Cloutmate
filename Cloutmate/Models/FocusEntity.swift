//
//  FocusEntity.swift
//  Cloutmate
//
//  Focus Gravity V2 - Data model for cognitive priority visualization
//  Represents an entity (task, project, note, artifact) with focus metrics
//

import Foundation
import SwiftData

/// Energy profile breakdown for focus types
struct FocusEnergyProfile: Hashable {
    let cognitive: Double  // 0-1: analytical, problem-solving focus
    let creative: Double   // 0-1: ideation, exploration focus
    let completion: Double // 0-1: finishing, execution focus
    
    /// Determine dominant energy type
    var dominantType: FocusEnergyType {
        let maxValue = max(cognitive, creative, completion)
        if maxValue == cognitive {
            return .cognitive
        } else if maxValue == creative {
            return .creative
        } else {
            return .completion
        }
    }
    
    /// Normalize values so they sum to 1.0 (for percentage display)
    var normalized: FocusEnergyProfile {
        let sum = cognitive + creative + completion
        guard sum > 0 else {
            return FocusEnergyProfile(cognitive: 0.33, creative: 0.33, completion: 0.34)
        }
        return FocusEnergyProfile(
            cognitive: cognitive / sum,
            creative: creative / sum,
            completion: completion / sum
        )
    }
}

/// Dominant energy type for visualization
enum FocusEnergyType: String {
    case cognitive  // Blue
    case creative   // Purple
    case completion // Green
    
    var displayName: String {
        switch self {
        case .cognitive: return "Cognitive"
        case .creative: return "Creative"
        case .completion: return "Completion"
        }
    }
}

/// Time scope for filtering focus entities
enum FocusTimeScope: String, CaseIterable {
    case today
    case week
    case month
    
    var displayName: String {
        switch self {
        case .today: return "Today"
        case .week: return "Week"
        case .month: return "Month"
        }
    }
    
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
            return (start, end)
            
        case .week:
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return (start, now)
            
        case .month:
            let start = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return (start, now)
        }
    }
}

/// Entity filter type
enum FocusEntityFilter: String, CaseIterable {
    case all
    case tasks
    case projects
    case artifacts
    case notes
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .tasks: return "Tasks"
        case .projects: return "Projects"
        case .artifacts: return "Artifacts"
        case .notes: return "Notes"
        }
    }
    
    var objectType: String? {
        switch self {
        case .all: return nil
        case .tasks: return "task"
        case .projects: return "project"
        case .artifacts: return "draft" // Using draft as artifact proxy
        case .notes: return "note"
        }
    }
}

/// Focus entity with aggregated metrics
struct FocusEntity: Identifiable, Hashable {
    let id: UUID
    let name: String
    let type: String  // "task", "project", "note", "artifact"
    let cpsScore: Double
    let energy: FocusEnergyProfile
    let forecast: FocusForecast?
    let lastActivity: Date?
    let sessionCount: Int
    let ritualWeight: Double  // Morning/evening streak contribution
    
    /// Computed gravity weight for orbit visualization
    var gravityWeight: Double {
        let baseWeight = cpsScore
        let sessionBoost = min(0.2, Double(sessionCount) * 0.05)
        let ritualBoost = ritualWeight * 0.1
        return min(1.0, baseWeight + sessionBoost + ritualBoost)
    }
    
    /// Focus allocation percentage (for display)
    var focusAllocation: Double {
        gravityWeight * 100
    }
    
    // Custom Hashable conformance (excluding forecast since it's a SwiftData model)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(type)
        hasher.combine(cpsScore)
        hasher.combine(energy)
        hasher.combine(forecast?.id) // Use forecast ID instead of the object
        hasher.combine(lastActivity)
        hasher.combine(sessionCount)
        hasher.combine(ritualWeight)
    }
    
    static func == (lhs: FocusEntity, rhs: FocusEntity) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.type == rhs.type &&
        lhs.cpsScore == rhs.cpsScore &&
        lhs.energy == rhs.energy &&
        lhs.forecast?.id == rhs.forecast?.id &&
        lhs.lastActivity == rhs.lastActivity &&
        lhs.sessionCount == rhs.sessionCount &&
        lhs.ritualWeight == rhs.ritualWeight
    }
}

