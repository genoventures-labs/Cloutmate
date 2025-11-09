//
//  FlowCompanionState.swift
//  Cloutmate
//
//  AI Flow Companion - State model for tracking companion interactions
//

import Foundation
import SwiftData

/// Personality modes for the AI Flow Companion
enum FlowCompanionPersonality: String, Codable, CaseIterable {
    case clarityCoach = "clarity_coach"
    case momentumGuide = "momentum_guide"
    case reflectionPartner = "reflection_partner"
    
    var displayName: String {
        switch self {
        case .clarityCoach:
            return "Clarity Coach"
        case .momentumGuide:
            return "Momentum Guide"
        case .reflectionPartner:
            return "Reflection Partner"
        }
    }
}

/// SwiftData model tracking Flow Companion state and interactions
@Model
final class FlowCompanionState {
    @Attribute(.unique) var id: UUID
    var lastInteraction: Date
    var personalityMode: String  // FlowCompanionPersonality rawValue
    var interactionHistory: [String]  // Recent interaction summaries
    var totalInteractions: Int
    var createdAt: Date
    var updatedAt: Date
    
    init(
        personalityMode: FlowCompanionPersonality = .clarityCoach,
        lastInteraction: Date = Date(),
        interactionHistory: [String] = [],
        totalInteractions: Int = 0
    ) {
        self.id = UUID()
        self.personalityMode = personalityMode.rawValue
        self.lastInteraction = lastInteraction
        self.interactionHistory = interactionHistory
        self.totalInteractions = totalInteractions
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var personality: FlowCompanionPersonality {
        get {
            FlowCompanionPersonality(rawValue: personalityMode) ?? .clarityCoach
        }
        set {
            personalityMode = newValue.rawValue
            updatedAt = Date()
        }
    }
    
    func recordInteraction(summary: String) {
        interactionHistory.append(summary)
        // Keep only last 20 interactions
        if interactionHistory.count > 20 {
            interactionHistory.removeFirst()
        }
        lastInteraction = Date()
        totalInteractions += 1
        updatedAt = Date()
    }
}

