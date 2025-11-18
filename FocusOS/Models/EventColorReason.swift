//
//  EventColorReason.swift
//  FocusOS
//
//  Aurora Calendar Cognition Layer - Stores why Aurora assigned each color
//

import Foundation
import SwiftData

@Model
final class EventColorReason {
    var eventId: UUID
    var colorHex: String
    var urgencyScore: Double
    var primaryFactor: String // "deadline", "overdue", "energy", etc.
    var secondaryFactors: [String]
    var explanation: String // Human-readable
    var computedAt: Date
    @Attribute(.externalStorage)
    private var factorsData: Data? // Factor name → weight
    
    var isUserOverride: Bool = false
    
    init(
        eventId: UUID,
        colorHex: String,
        urgencyScore: Double,
        primaryFactor: String,
        secondaryFactors: [String] = [],
        explanation: String,
        factors: [String: Double] = [:],
        isUserOverride: Bool = false
    ) {
        self.eventId = eventId
        self.colorHex = colorHex
        self.urgencyScore = urgencyScore
        self.primaryFactor = primaryFactor
        self.secondaryFactors = secondaryFactors
        self.explanation = explanation
        self.computedAt = Date()
        self.isUserOverride = isUserOverride
        self.factorsData = try? JSONEncoder().encode(factors)
    }
    
    var factors: [String: Double] {
        get {
            guard let data = factorsData else { return [:] }
            return (try? JSONDecoder().decode([String: Double].self, from: data)) ?? [:]
        }
        set {
            factorsData = try? JSONEncoder().encode(newValue)
        }
    }
}

