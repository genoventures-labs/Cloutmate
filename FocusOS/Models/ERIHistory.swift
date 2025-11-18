//
//  ERIHistory.swift
//  FocusOS
//
//  Ecospheric Resonance Index history for diagnostics and self-balancing
//

import Foundation
import SwiftData

@Model
final class ERIHistory: Identifiable {
    @Attribute var id: UUID = UUID()
    @Attribute var timestamp: Date = Date()
    
    // ERI Score (-1.0 to +1.0)
    @Attribute var eriIndex: Double = 0.0 // -1.0 (discord) to +1.0 (harmony)
    
    // Component scores (for diagnostics)
    @Attribute var toneCoherence: Double = 0.5 // 0.0 to 1.0
    @Attribute var volatilitySync: Double = 0.5 // 0.0 to 1.0
    @Attribute var pacingStability: Double = 0.5 // 0.0 to 1.0
    
    // Subsystem node states (snapshot)
    @Attribute var toneKitState: String? // Encoded tone state
    @Attribute var temporalMemoryState: String? // Encoded memory state
    @Attribute var continuityEngineState: String? // Encoded AECI state
    @Attribute var arteState: String? // Encoded ARTE state
    
    // Delta tracking (for self-adjustment)
    @Attribute var eriDelta: Double = 0.0 // Change from previous ERI
    @Attribute var previousERI: Double = 0.0
    
    // Self-balancing feedback
    @Attribute var adjustmentApplied: Bool = false
    @Attribute var adjustmentType: String? // "tone_weighting", "pacing", "volatility"
    
    init(
        eriIndex: Double,
        toneCoherence: Double,
        volatilitySync: Double,
        pacingStability: Double,
        eriDelta: Double = 0.0,
        previousERI: Double = 0.0
    ) {
        self.eriIndex = eriIndex
        self.toneCoherence = toneCoherence
        self.volatilitySync = volatilitySync
        self.pacingStability = pacingStability
        self.eriDelta = eriDelta
        self.previousERI = previousERI
    }
    
    /// Get ERI category for diagnostics
    var category: ERICategory {
        if eriIndex > 0.3 {
            return .harmony
        } else if eriIndex < -0.3 {
            return .discord
        } else {
            return .neutral
        }
    }
    
    /// Get visual discord intensity (0.0 to 1.0)
    var discordIntensity: Double {
        guard eriIndex < 0 else { return 0.0 }
        return abs(eriIndex) // Negative ERI = discord intensity
    }
}

enum ERICategory: String, Codable {
    case harmony = "harmony"
    case neutral = "neutral"
    case discord = "discord"
}

