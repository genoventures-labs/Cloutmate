//
//  ContextualAdaptationService.swift
//  Cloutmate
//
//  Adapts tone based on time-of-day, energy matching, workload awareness, and success celebration
//

import Foundation
import SwiftData
import CloutmateShared

@MainActor
@Observable
final class ContextualAdaptationService {
    static let shared = ContextualAdaptationService()
    
    private init() {}
    
    /// Get time-of-day awareness
    func getTimeOfDayContext() -> TimeOfDayContext {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5..<9:
            return .morning
        case 9..<12:
            return .lateMorning
        case 12..<14:
            return .midday
        case 14..<17:
            return .afternoon
        case 17..<21:
            return .evening
        default:
            return .night
        }
    }
    
    /// Get tone adaptation based on time of day
    func getTimeBasedTone(context: TimeOfDayContext, casual: Bool = false) -> String {
        switch context {
        case .morning:
            return casual ? "Morning! What's on your mind?" : "Good morning! Ready to tackle the day?"
        case .lateMorning:
            return casual ? "Late morning vibes—how's it going?" : "Hope your morning is going well!"
        case .midday:
            return casual ? "Midday check-in—what's up?" : "How's your day going so far?"
        case .afternoon:
            return casual ? "Hey, afternoon! Need anything?" : "Afternoon! How can I help?"
        case .evening:
            return casual ? "Evening! Taking it easy?" : "Evening! Winding down or still going?"
        case .night:
            return casual ? "Late night—hope you're staying cozy." : "Late night! Take it easy."
        }
    }
    
    /// Match user's energy level
    func matchEnergyLevel(userEnergy: Double) -> String {
        if userEnergy < 0.4 {
            return "Take your time. I'm here when you need me."
        } else if userEnergy > 0.7 {
            return "Let's go! What can we tackle?"
        } else {
            return "How can I help?"
        }
    }
    
    /// Assess workload awareness
    func assessWorkload(modelContext: ModelContext) async -> WorkloadLevel {
        let tasks = try? modelContext.fetch(FetchDescriptor<Task>())
        let overdueTasks = tasks?.filter { task in
            guard let due = task.dueDate else { return false }
            return due < Date() && task.status != .done
        } ?? []
        
        let upcomingTasks = tasks?.filter { task in
            guard let due = task.dueDate else { return false }
            let daysFromNow = Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0
            return daysFromNow >= 0 && daysFromNow <= 3 && task.status != .done
        } ?? []
        
        if overdueTasks.count > 5 || upcomingTasks.count > 10 {
            return .heavy
        } else if overdueTasks.count > 2 || upcomingTasks.count > 5 {
            return .moderate
        } else {
            return .light
        }
    }
    
    /// Get workload-aware tone
    func getWorkloadAwareTone(workload: WorkloadLevel) -> String {
        switch workload {
        case .heavy:
            return "I notice you have quite a bit on your plate. Want me to help prioritize?"
        case .moderate:
            return "You've got some things coming up. Need help planning?"
        case .light:
            return "Looks like a manageable workload. What can we tackle?"
        }
    }
    
    /// Celebrate success
    func celebrateSuccess(achievement: String) -> String {
        let celebrations = [
            "Nice! \(achievement)",
            "Awesome! \(achievement)",
            "Great job on \(achievement)!",
            "That's awesome! \(achievement)",
            "Congrats on \(achievement)!"
        ]
        
        return celebrations.randomElement() ?? "Nice! \(achievement)"
    }
    
    /// Generate contextual adaptation instructions
    func generateContextualInstructions(
        timeContext: TimeOfDayContext,
        userEnergy: Double,
        workload: WorkloadLevel?,
        isCasualConversation: Bool,
        includeWorkloadCues: Bool,
        conversationIntent: ConversationIntent?
    ) -> String {
        var instructions: [String] = []
        
        // Time-based
        instructions.append(getTimeBasedTone(context: timeContext, casual: isCasualConversation))
        
        if isCasualConversation {
            instructions.append("Keep it easy-going—treat this moment like a light check-in unless they steer it toward work.")
        }
        
        // Energy-based
        if userEnergy < 0.35 {
            instructions.append("Their energy is low—slow your pacing and be extra gentle.")
        } else if userEnergy > 0.7 {
            instructions.append("They're energized—mirror that spark, but stay natural.")
        }
        
        // Workload-based
        if includeWorkloadCues,
           !isCasualConversation,
           conversationIntent != .social,
           let workload {
            switch workload {
            case .heavy:
                instructions.append("They're juggling a heavy workload—offer prioritization help without piling on pressure.")
            case .moderate:
                instructions.append("Workload is moderate—offer support if they ask, otherwise stay conversational.")
            case .light:
                break
            }
        }
        
        if instructions.isEmpty {
            return ""
        }
        
        return instructions.joined(separator: "\n- ")
    }
}

enum TimeOfDayContext {
    case morning      // 5-9 AM
    case lateMorning  // 9-12 PM
    case midday       // 12-2 PM
    case afternoon    // 2-5 PM
    case evening      // 5-9 PM
    case night        // 9 PM - 5 AM
}

enum WorkloadLevel {
    case light
    case moderate
    case heavy
}

