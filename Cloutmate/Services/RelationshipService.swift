//
//  RelationshipService.swift
//  Cloutmate
//
//  Builds relationships through preference tracking, rapport building, and growth acknowledgment
//

import Foundation
import SwiftData
import CloutmateShared

@MainActor
@Observable
final class RelationshipService {
    static let shared = RelationshipService()
    
    private var trackedPreferences: [String: PreferenceRecord] = [:]
    
    private init() {}
    
    struct PreferenceRecord {
        let key: String
        let value: String
        let firstObserved: Date
        let frequency: Int
        let lastObserved: Date
    }
    
    /// Track a user preference
    func trackPreference(key: String, value: String) {
        if var existing = trackedPreferences[key] {
            trackedPreferences[key] = PreferenceRecord(
                key: key,
                value: value,
                firstObserved: existing.firstObserved,
                frequency: existing.frequency + 1,
                lastObserved: Date()
            )
        } else {
            trackedPreferences[key] = PreferenceRecord(
                key: key,
                value: value,
                firstObserved: Date(),
                frequency: 1,
                lastObserved: Date()
            )
        }
    }
    
    /// Get preference recall phrase
    func getPreferenceRecall(key: String) -> String? {
        guard let preference = trackedPreferences[key], preference.frequency >= 3 else {
            return nil
        }
        
        return "I know you prefer \(preference.value)"
    }
    
    /// Build rapport by referencing shared history
    func buildRapportPhrase(sharedHistory: [String]) -> String? {
        guard !sharedHistory.isEmpty else { return nil }
        
        let recentHistory = sharedHistory.prefix(3)
        let topics = recentHistory.joined(separator: ", ")
        
        return "Remember when we worked on \(topics)?"
    }
    
    /// Remember personal touches (small details)
    func rememberPersonalTouch(detail: String, context: String) {
        trackPreference(key: "personal_\(context)", value: detail)
    }
    
    /// Acknowledge growth
    func acknowledgeGrowth(area: String, improvement: String) -> String {
        return "You've gotten really good at \(area). \(improvement)"
    }
    
    /// Generate relationship-building prompt instructions
    func generateRelationshipInstructions() -> String {
        var instructions: [String] = []
        
        // Add preference recalls
        let strongPreferences = trackedPreferences.values.filter { $0.frequency >= 3 }
        if !strongPreferences.isEmpty {
            let preferenceTexts = strongPreferences.map { "I know you prefer \($0.value)" }
            instructions.append("Remember preferences: \(preferenceTexts.joined(separator: ", "))")
        }
        
        instructions.append("Build rapport by referencing shared history naturally")
        instructions.append("Remember small personal details and mention them occasionally")
        instructions.append("Acknowledge growth and improvement when you notice it")
        instructions.append("Be warm and personable - you're building a relationship")
        
        return instructions.joined(separator: "\n- ")
    }
}

