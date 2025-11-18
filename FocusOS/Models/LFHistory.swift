//
//  LFHistory.swift
//  FocusOS
//
//  Luminance Field history for emotional auroras over time
//

import Foundation
import SwiftData

@Model
final class LFHistory: Identifiable {
    @Attribute var id: UUID = UUID()
    @Attribute var timestamp: Date = Date()
    
    // Luminance Field Score (-1.0 to +1.0)
    @Attribute var luminanceField: Double = 0.0 // -1.0 (dim, dense) to +1.0 (radiant, shimmer)
    
    // Component scores (for analysis)
    @Attribute var eriContribution: Double = 0.0
    @Attribute var aecContribution: Double = 0.0
    @Attribute var ersContribution: Double = 0.0
    
    // Visual parameters (derived from LF)
    @Attribute var particleMotionSpeed: Double = 1.0 // 0.5x to 1.5x
    @Attribute var particleDensity: Double = 0.5 // 0.0 (sparse) to 1.0 (dense)
    @Attribute var pulseFrequency: Double = 1.0 // Hz (0.5 to 2.0)
    @Attribute var lightingIntensity: Double = 0.5 // 0.0 (dim) to 1.0 (bright)
    @Attribute var shimmerIntensity: Double = 0.0 // 0.0 to 1.0
    
    // Source indices
    @Attribute var eriIndex: Double = 0.0
    @Attribute var aecIndex: Double = 0.0
    @Attribute var ersIndex: Double = 0.0
    
    // Aurora signature metadata
    @Attribute var auroraType: String? // "radiant", "gentle", "neutral", "dense", "dim"
    @Attribute var colorTemperature: Double = 0.0 // -1.0 (cool) to +1.0 (warm)
    
    init(
        luminanceField: Double,
        eriContribution: Double,
        aecContribution: Double,
        ersContribution: Double,
        eriIndex: Double,
        aecIndex: Double,
        ersIndex: Double
    ) {
        self.luminanceField = luminanceField
        self.eriContribution = eriContribution
        self.aecContribution = aecContribution
        self.ersContribution = ersContribution
        self.eriIndex = eriIndex
        self.aecIndex = aecIndex
        self.ersIndex = ersIndex
        
        // Derive visual parameters
        self.particleMotionSpeed = deriveParticleMotionSpeed(lf: luminanceField)
        self.particleDensity = deriveParticleDensity(lf: luminanceField)
        self.pulseFrequency = derivePulseFrequency(lf: luminanceField)
        self.lightingIntensity = deriveLightingIntensity(lf: luminanceField)
        self.shimmerIntensity = deriveShimmerIntensity(lf: luminanceField)
        self.auroraType = deriveAuroraType(lf: luminanceField)
        self.colorTemperature = deriveColorTemperature(lf: luminanceField, aecIndex: aecIndex)
    }
    
    /// Get LF category for visual interpretation
    var category: LFCategory {
        if luminanceField > 0.3 {
            return .radiant
        } else if luminanceField < -0.3 {
            return .dim
        } else {
            return .neutral
        }
    }
    
    private func deriveParticleMotionSpeed(lf: Double) -> Double {
        // Positive LF → faster motion (up to 1.5x)
        // Negative LF → slower motion (down to 0.5x)
        return 1.0 + (lf * 0.5)
    }
    
    private func deriveParticleDensity(lf: Double) -> Double {
        // Positive LF → lower density (sparse, shimmer)
        // Negative LF → higher density (dense, heavy)
        return 0.5 - (lf * 0.3) // Invert: positive LF = less dense
    }
    
    private func derivePulseFrequency(lf: Double) -> Double {
        // Positive LF → faster pulse (up to 2.0 Hz)
        // Negative LF → slower pulse (down to 0.5 Hz)
        return 1.0 + (lf * 1.0)
    }
    
    private func deriveLightingIntensity(lf: Double) -> Double {
        // Positive LF → brighter lighting
        // Negative LF → dimmer lighting
        return 0.5 + (lf * 0.5)
    }
    
    private func deriveShimmerIntensity(lf: Double) -> Double {
        // Positive LF → more shimmer
        // Negative LF → no shimmer
        return max(0.0, lf * 0.8)
    }
    
    private func deriveAuroraType(lf: Double) -> String {
        if lf > 0.5 {
            return "radiant"
        } else if lf > 0.2 {
            return "gentle"
        } else if lf > -0.2 {
            return "neutral"
        } else if lf > -0.5 {
            return "dense"
        } else {
            return "dim"
        }
    }
    
    private func deriveColorTemperature(lf: Double, aecIndex: Double) -> Double {
        // Blend LF and AECI for color temperature
        // Positive = warm, negative = cool
        return (lf * 0.6) + (aecIndex * 0.4)
    }
}

enum LFCategory: String, Codable {
    case radiant = "radiant"
    case neutral = "neutral"
    case dim = "dim"
}

