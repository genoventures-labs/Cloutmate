//
//  FocusRitual.swift
//  Cloutmate
//
//  Phase 8: Cognitive Loop Completion
//  Represents an individual focus ritual configuration (morning/evening)
//

import Foundation
import SwiftData

/// Represents the type of focus ritual that can be scheduled.
enum FocusRitualType: String, Codable, CaseIterable, Identifiable {
    case morning
    case evening

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .morning:
            return "Morning Ritual"
        case .evening:
            return "Evening Ritual"
        }
    }
}

/// Lifecycle status for a focus ritual.
enum FocusRitualStatus: String, Codable, CaseIterable {
    case upcoming      // Scheduled and waiting to trigger
    case inProgress    // Ritual flow currently active
    case completed     // Successfully completed
    case missed        // User did not complete in allotted window
    case snoozed       // User postponed to a later time
}

/// Primary model representing a focus ritual instance.
@Model
final class FocusRitual {
    @Attribute(.unique) var id: UUID
    var typeRaw: String
    var statusRaw: String
    var scheduledFor: Date
    var windowEnd: Date

    // Tracking & metrics
    var createdAt: Date
    var updatedAt: Date
    var lastTriggeredAt: Date?
    var lastCompletedAt: Date?
    var streakCount: Int
    var bestStreak: Int
    var totalCompletions: Int

    // Flexible metadata container (e.g., AI recap IDs, CPS context)
    var metadata: [String: String]

    init(
        type: FocusRitualType,
        scheduledFor: Date,
        windowEnd: Date,
        status: FocusRitualStatus = .upcoming,
        createdAt: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.statusRaw = status.rawValue
        self.scheduledFor = scheduledFor
        self.windowEnd = windowEnd
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.lastTriggeredAt = nil
        self.lastCompletedAt = nil
        self.streakCount = 0
        self.bestStreak = 0
        self.totalCompletions = 0
        self.metadata = metadata
    }

    var type: FocusRitualType {
        get { FocusRitualType(rawValue: typeRaw) ?? .morning }
        set { typeRaw = newValue.rawValue }
    }

    var status: FocusRitualStatus {
        get { FocusRitualStatus(rawValue: statusRaw) ?? .upcoming }
        set { statusRaw = newValue.rawValue }
    }

    /// Marks the ritual as triggered and updates bookkeeping timestamps.
    func markTriggered(at date: Date = Date()) {
        lastTriggeredAt = date
        status = .inProgress
        updatedAt = date
    }

    /// Marks the ritual as completed and updates streak metrics.
    func markCompleted(at date: Date = Date()) {
        lastCompletedAt = date
        status = .completed
        updatedAt = date
        totalCompletions += 1
        streakCount += 1
        bestStreak = max(bestStreak, streakCount)
    }

    /// Marks the ritual as missed and resets streak.
    func markMissed(at date: Date = Date()) {
        status = .missed
        updatedAt = date
        streakCount = 0
    }

    /// Marks the ritual as snoozed to a new schedule.
    func snooze(until newDate: Date, windowEnd: Date, at date: Date = Date()) {
        self.scheduledFor = newDate
        self.windowEnd = windowEnd
        self.status = .snoozed
        self.updatedAt = date
    }

    /// Resets the ritual to an upcoming state with a new schedule.
    func reschedule(to newDate: Date, windowEnd: Date, at date: Date = Date()) {
        self.scheduledFor = newDate
        self.windowEnd = windowEnd
        self.status = .upcoming
        self.updatedAt = date
    }
}


