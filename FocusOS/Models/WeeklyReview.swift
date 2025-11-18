//
//  WeeklyReview.swift
//  FocusOS
//
//  Phase 8: Cognitive Loop Completion
//  Tracks guided weekly review ritual outcomes and insights
//

import Foundation
import SwiftData
import Combine

/// Represents the lifecycle state of a weekly review ritual.
enum WeeklyReviewStatus: String, Codable, CaseIterable {
    case scheduled
    case inProgress
    case completed
    case skipped
}

/// SwiftData model for weekly review sessions.
@Model
final class WeeklyReview {
    @Attribute(.unique) var id: UUID
    var statusRaw: String
    var scheduledFor: Date
    var startedAt: Date?
    var completedAt: Date?

    // Summary content
    var summary: String?
    var insights: String?
    var recommendations: String?
    var nextFocuses: [String]

    // Metrics captured during review
    var focusGravityScore: Double
    var captureVelocity: Double
    var outputVelocity: Double
    var clarityIndex: Double
    var cpsShiftIds: [UUID]
    var inboxItemsCleared: Int

    // Metadata for extensibility (e.g., AI versions, prompt IDs)
    var metadata: [String: String]

    init(
        scheduledFor: Date,
        status: WeeklyReviewStatus = .scheduled,
        summary: String? = nil,
        insights: String? = nil,
        recommendations: String? = nil,
        nextFocuses: [String] = [],
        focusGravityScore: Double = 0,
        captureVelocity: Double = 0,
        outputVelocity: Double = 0,
        clarityIndex: Double = 0,
        cpsShiftIds: [UUID] = [],
        inboxItemsCleared: Int = 0,
        metadata: [String: String] = [:]
    ) {
        self.id = UUID()
        self.statusRaw = status.rawValue
        self.scheduledFor = scheduledFor
        self.startedAt = nil
        self.completedAt = nil
        self.summary = summary
        self.insights = insights
        self.recommendations = recommendations
        self.nextFocuses = nextFocuses
        self.focusGravityScore = focusGravityScore
        self.captureVelocity = captureVelocity
        self.outputVelocity = outputVelocity
        self.clarityIndex = clarityIndex
        self.cpsShiftIds = cpsShiftIds
        self.inboxItemsCleared = inboxItemsCleared
        self.metadata = metadata
    }

    var status: WeeklyReviewStatus {
        get { WeeklyReviewStatus(rawValue: statusRaw) ?? .scheduled }
        set { statusRaw = newValue.rawValue }
    }

    func markStarted(at date: Date = Date()) {
        startedAt = date
        status = .inProgress
    }

    func markCompleted(at date: Date = Date()) {
        completedAt = date
        status = .completed
    }

    func markSkipped(at date: Date = Date()) {
        completedAt = date
        status = .skipped
    }
}


