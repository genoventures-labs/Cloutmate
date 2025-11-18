//
//  MomentumMetrics.swift
//  FocusOS
//
//  Phase 9B: Behavioral momentum snapshot used across adaptive systems.
//

import Foundation

struct MomentumMetrics: Codable, Sendable {
    enum FlowState: String, Codable, Sendable {
        case highFlow
        case steadyFlow
        case slowingFlow
        case stalled
    }

    let streakDays: Int
    let completionVelocity: Double
    let averageRecoveryTime: TimeInterval
    let flowState: FlowState
    let calculatedAt: Date
}


