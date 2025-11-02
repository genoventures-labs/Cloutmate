//
//  RitualCompletion.swift
//  Cloutmate
//
//  Phase 8: Cognitive Loop Completion
//  Historical log entries for ritual completions and outcomes
//

import Foundation
import SwiftData

/// Represents the outcome of a ritual completion.
enum RitualCompletionOutcome: String, Codable, CaseIterable {
    case completed
    case deferred
    case dropped
    case skipped
}

/// Stores aggregate information for a single ritual completion.
@Model
final class RitualCompletion {
    @Attribute(.unique) var id: UUID
    var ritualTypeRaw: String
    var outcomeRaw: String
    var scheduledFor: Date
    var completedAt: Date
    var duration: TimeInterval

    // Reflection content
    var userNotes: String?
    var aiRecap: String?
    var highlights: [String]

    // Task-level metadata
    var focusItemIds: [UUID]
    var taskStatusCounts: [String: Int]

    // Metrics
    var cpsBoostApplied: Bool
    var momentumDelta: Double

    // Extensible metadata for future insights
    var metadata: [String: String]

    init(
        ritualType: FocusRitualType,
        outcome: RitualCompletionOutcome,
        scheduledFor: Date,
        completedAt: Date = Date(),
        duration: TimeInterval = 0,
        userNotes: String? = nil,
        aiRecap: String? = nil,
        highlights: [String] = [],
        focusItemIds: [UUID] = [],
        taskStatusCounts: [String: Int] = [:],
        cpsBoostApplied: Bool = false,
        momentumDelta: Double = 0,
        metadata: [String: String] = [:]
    ) {
        self.id = UUID()
        self.ritualTypeRaw = ritualType.rawValue
        self.outcomeRaw = outcome.rawValue
        self.scheduledFor = scheduledFor
        self.completedAt = completedAt
        self.duration = duration
        self.userNotes = userNotes
        self.aiRecap = aiRecap
        self.highlights = highlights
        self.focusItemIds = focusItemIds
        self.taskStatusCounts = taskStatusCounts
        self.cpsBoostApplied = cpsBoostApplied
        self.momentumDelta = momentumDelta
        self.metadata = metadata
    }

    var ritualType: FocusRitualType {
        get { FocusRitualType(rawValue: ritualTypeRaw) ?? .morning }
        set { ritualTypeRaw = newValue.rawValue }
    }

    var outcome: RitualCompletionOutcome {
        get { RitualCompletionOutcome(rawValue: outcomeRaw) ?? .completed }
        set { outcomeRaw = newValue.rawValue }
    }
}


