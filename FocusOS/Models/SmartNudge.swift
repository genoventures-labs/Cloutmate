//
//  SmartNudge.swift
//  FocusOS
//
//  Phase 8: Cognitive Loop Completion
//  Captures contextual nudges issued by the Smart Nudge Engine
//

import Foundation
import SwiftData
import Combine

/// Types of triggers that can generate a smart nudge.
enum SmartNudgeTrigger: String, Codable, CaseIterable {
    case stalePriority
    case captureVelocityDrop
    case fatiguedState
    case expressOverweight
    case reflectionReminder
    case custom
}

/// Tone used for the delivered nudge, aligned with ARTE emotional state.
enum SmartNudgeTone: String, Codable, CaseIterable {
    case calm
    case energized
    case gentle
    case focused
    case reflective
}

/// User response to a delivered nudge.
enum SmartNudgeResponse: String, Codable, CaseIterable {
    case accepted
    case dismissed
    case snoozed
    case ignored
}

/// SwiftData model tracking nudges and user behavior.
@Model
final class SmartNudge {
    @Attribute(.unique) var id: UUID
    var triggerRaw: String
    var toneRaw: String
    var responseRaw: String?

    var message: String
    var detail: String?

    var createdAt: Date
    var deliveredAt: Date?
    var respondedAt: Date?
    var cooldownUntil: Date?

    var isSuppressed: Bool
    var metadata: [String: String]

    // Optional linkage to domain objects (tasks, projects, sessions)
    var relatedObjectId: UUID?
    var relatedObjectType: String?

    init(
        trigger: SmartNudgeTrigger,
        tone: SmartNudgeTone,
        message: String,
        detail: String? = nil,
        createdAt: Date = Date(),
        metadata: [String: String] = [:],
        relatedObjectId: UUID? = nil,
        relatedObjectType: String? = nil
    ) {
        self.id = UUID()
        self.triggerRaw = trigger.rawValue
        self.toneRaw = tone.rawValue
        self.responseRaw = nil
        self.message = message
        self.detail = detail
        self.createdAt = createdAt
        self.deliveredAt = nil
        self.respondedAt = nil
        self.cooldownUntil = nil
        self.isSuppressed = false
        self.metadata = metadata
        self.relatedObjectId = relatedObjectId
        self.relatedObjectType = relatedObjectType
    }

    var trigger: SmartNudgeTrigger {
        get { SmartNudgeTrigger(rawValue: triggerRaw) ?? .custom }
        set { triggerRaw = newValue.rawValue }
    }

    var tone: SmartNudgeTone {
        get { SmartNudgeTone(rawValue: toneRaw) ?? .calm }
        set { toneRaw = newValue.rawValue }
    }

    var response: SmartNudgeResponse? {
        get {
            guard let raw = responseRaw else { return nil }
            return SmartNudgeResponse(rawValue: raw)
        }
        set {
            responseRaw = newValue?.rawValue
        }
    }

    func markDelivered(at date: Date = Date()) {
        deliveredAt = date
    }

    func registerResponse(_ response: SmartNudgeResponse, at date: Date = Date()) {
        responseRaw = response.rawValue
        respondedAt = date
    }

    func suppress(until date: Date) {
        isSuppressed = true
        cooldownUntil = date
    }
}


