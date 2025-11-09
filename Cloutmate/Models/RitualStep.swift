//
//  RitualStep.swift
//  Cloutmate
//
//  Rituals V2: Data structure for ritual steps
//

import Foundation

/// Represents a single step in a ritual flow
struct RitualStep: Identifiable, Equatable {
    let id: UUID
    let type: RitualStepType
    let title: String
    let description: String
    var isCompleted: Bool
    var duration: TimeInterval? // Optional timer duration (e.g., for breathing exercises)
    
    init(
        type: RitualStepType,
        title: String,
        description: String,
        isCompleted: Bool = false,
        duration: TimeInterval? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.description = description
        self.isCompleted = isCompleted
        self.duration = duration
    }
}

/// Types of ritual steps
enum RitualStepType: String, CaseIterable {
    case intention
    case breathing
    case taskPreview
    case gratitude
    case summary
    
    var icon: String {
        switch self {
        case .intention:
            return "target"
        case .breathing:
            return "wind"
        case .taskPreview:
            return "list.bullet"
        case .gratitude:
            return "heart.fill"
        case .summary:
            return "checkmark.circle.fill"
        }
    }
}

/// Configuration for ritual steps based on ritual type
struct RitualStepConfiguration {
    static func steps(for ritualType: FocusRitualType) -> [RitualStep] {
        switch ritualType {
        case .morning:
            return [
                RitualStep(
                    type: .intention,
                    title: "Set your intention",
                    description: "What do you want to focus on today? Take a moment to clarify your primary goal."
                ),
                RitualStep(
                    type: .breathing,
                    title: "Breathing or mindfulness",
                    description: "Take 3 deep breaths to center yourself. Optional: 2-minute breathing exercise.",
                    duration: 120 // 2 minutes
                ),
                RitualStep(
                    type: .taskPreview,
                    title: "Top 3 focus items",
                    description: "Review your top priorities from Focus Gravity. Which one deserves your attention first?"
                ),
                RitualStep(
                    type: .gratitude,
                    title: "Gratitude / reflection prompt",
                    description: "What are you grateful for today? What's one thing that's going well?"
                ),
                RitualStep(
                    type: .summary,
                    title: "End summary",
                    description: "Review your ritual completion and set your intention for the day."
                )
            ]
        case .evening:
            return [
                RitualStep(
                    type: .intention,
                    title: "Reflect on the day",
                    description: "How did today go? What did you accomplish?"
                ),
                RitualStep(
                    type: .breathing,
                    title: "Wind down",
                    description: "Take a moment to breathe and release the day. Optional: 2-minute breathing exercise.",
                    duration: 120
                ),
                RitualStep(
                    type: .taskPreview,
                    title: "Review outcomes",
                    description: "What got done? What was deferred? What can wait until tomorrow?"
                ),
                RitualStep(
                    type: .gratitude,
                    title: "Gratitude / reflection",
                    description: "What went well today? What are you grateful for?"
                ),
                RitualStep(
                    type: .summary,
                    title: "End summary",
                    description: "Complete your evening reflection and prepare for tomorrow."
                )
            ]
        }
    }
}

