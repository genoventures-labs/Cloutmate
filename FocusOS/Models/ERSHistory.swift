//
//  ERSHistory.swift
//  FocusOS
//
//  Emotional Resonance Score history for Symphonic Timeline
//

import Foundation
import SwiftData

@Model
final class ERSHistory: Identifiable {
    @Attribute var id: UUID = UUID()
    @Attribute var timestamp: Date = Date()
    
    // ERS Score (-1.0 to +1.0)
    @Attribute var ersIndex: Double = 0.0 // -1.0 (minor/dissonant) to +1.0 (major/harmonious)
    
    // Component scores (for analysis)
    @Attribute var cognitiveIntentAlignment: Double = 0.5 // 0.0 to 1.0
    @Attribute var emotionalToneHarmony: Double = 0.5 // 0.0 to 1.0
    @Attribute var environmentalRhythm: Double = 0.5 // 0.0 to 1.0
    
    // Musical parameters (derived from ERS)
    @Attribute var musicalKey: String = "C" // Major or minor key
    @Attribute var isMajorKey: Bool = true
    @Attribute var tempoBPM: Double = 60.0 // Beats per minute
    @Attribute var tonalCenter: Double = 0.0 // -1.0 (low) to +1.0 (high)
    
    // Source indices
    @Attribute var eriIndex: Double = 0.0
    @Attribute var aecIndex: Double = 0.0
    @Attribute var arteIntensity: Double = 0.7
    
    // Movement metadata
    @Attribute var movementType: String? // "overture", "development", "recapitulation", "coda"
    @Attribute var movementDuration: Double = 0.0 // Seconds
    
    init(
        ersIndex: Double,
        cognitiveIntentAlignment: Double,
        emotionalToneHarmony: Double,
        environmentalRhythm: Double,
        eriIndex: Double,
        aecIndex: Double,
        arteIntensity: Double
    ) {
        self.ersIndex = ersIndex
        self.cognitiveIntentAlignment = cognitiveIntentAlignment
        self.emotionalToneHarmony = emotionalToneHarmony
        self.environmentalRhythm = environmentalRhythm
        self.eriIndex = eriIndex
        self.aecIndex = aecIndex
        self.arteIntensity = arteIntensity
        
        // Derive musical parameters
        self.isMajorKey = ersIndex > 0
        self.musicalKey = deriveMusicalKey(ersIndex: ersIndex)
        self.tempoBPM = deriveTempo(ersIndex: ersIndex)
        self.tonalCenter = deriveTonalCenter(ersIndex: ersIndex, aecIndex: aecIndex)
    }
    
    /// Get ERS category for musical interpretation
    var category: ERSCategory {
        if ersIndex > 0.3 {
            return .major
        } else if ersIndex < -0.3 {
            return .minor
        } else {
            return .neutral
        }
    }
    
    /// Get tempo multiplier (0.7x to 1.3x)
    var tempoMultiplier: Double {
        return 1.0 + (ersIndex * 0.3) // Maps -1.0→0.7x, +1.0→1.3x
    }
    
    private func deriveMusicalKey(ersIndex: Double) -> String {
        // Map ERS to musical keys
        // Positive ERS → major keys (brighter)
        // Negative ERS → minor keys (darker)
        let keys: [String] = ersIndex > 0 ? 
            ["C", "G", "D", "A", "E", "B", "F#"] : // Major keys
            ["Am", "Em", "Bm", "F#m", "C#m", "G#m", "D#m"] // Minor keys
        
        let index = Int((abs(ersIndex) * Double(keys.count - 1)).rounded())
        return keys[min(index, keys.count - 1)]
    }
    
    private func deriveTempo(ersIndex: Double) -> Double {
        // Base tempo: 60 BPM
        // Positive ERS → faster (up to 90 BPM)
        // Negative ERS → slower (down to 45 BPM)
        return 60.0 + (ersIndex * 30.0)
    }
    
    private func deriveTonalCenter(ersIndex: Double, aecIndex: Double) -> Double {
        // Blend ERS and AECI for tonal center
        // Higher values = brighter/higher pitch
        return (ersIndex * 0.6) + (aecIndex * 0.4)
    }
}

enum ERSCategory: String, Codable {
    case major = "major"
    case minor = "minor"
    case neutral = "neutral"
}

