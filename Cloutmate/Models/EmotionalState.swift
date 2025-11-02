//
//  EmotionalState.swift
//  Cloutmate
//
//  Phase 7: ARTE - Aurora Reactive Theme Engine
//  Defines the five core emotional states and their visual characteristics
//

import SwiftUI

/// The five core emotional-cognitive states that ARTE detects and responds to
enum EmotionalState: String, Codable, CaseIterable, Sendable {
    case focused = "focused"
    case reflective = "reflective"
    case calm = "calm"
    case energized = "energized"
    case fatigued = "fatigued"
    
    /// Human-readable display name
    var displayName: String {
        switch self {
        case .focused: return "Focused"
        case .reflective: return "Reflective"
        case .calm: return "Calm"
        case .energized: return "Energized"
        case .fatigued: return "Fatigued"
        }
    }
    
    /// Description of the emotional state
    var description: String {
        switch self {
        case .focused:
            return "Deep work mode — concentrated attention on a single objective"
        case .reflective:
            return "Analytical thinking — exploring concepts and connections"
        case .calm:
            return "Balanced baseline — steady, neutral cognitive rhythm"
        case .energized:
            return "High flow state — rapid execution and positive momentum"
        case .fatigued:
            return "Low energy — rest and recovery needed"
        }
    }
    
    /// Icon for visual representation
    var iconName: String {
        switch self {
        case .focused: return "scope"
        case .reflective: return "brain.head.profile"
        case .calm: return "leaf"
        case .energized: return "bolt.fill"
        case .fatigued: return "moon.fill"
        }
    }
}

/// Color palette definition for each emotional state
struct EmotionalPalette: Sendable {
    let accentHue: Double           // Primary accent hue shift (0-360)
    let accentSaturation: Double    // Accent saturation multiplier (0-1)
    let shadowWarmth: Double        // Shadow color temperature (-1 cool, +1 warm)
    let contrastModifier: Double    // Overall contrast adjustment (0.8-1.2)
    let backgroundTint: Color       // Subtle background color overlay
    let animationSpeed: Double      // Animation timing multiplier (0.5-1.5)
    
    /// Get palette for a given emotional state
    static func palette(for state: EmotionalState) -> EmotionalPalette {
        switch state {
        case .focused:
            // Deep blues, cooler shadows, slower animations
            return EmotionalPalette(
                accentHue: 210,          // Deep blue
                accentSaturation: 0.9,
                shadowWarmth: -0.3,      // Cool shadows
                contrastModifier: 1.1,   // Slightly higher contrast
                backgroundTint: Color(red: 0.02, green: 0.05, blue: 0.12).opacity(0.1),
                animationSpeed: 0.75     // Slower, more deliberate
            )
            
        case .reflective:
            // Muted purples, soft contrasts, measured timing
            return EmotionalPalette(
                accentHue: 260,          // Purple
                accentSaturation: 0.7,
                shadowWarmth: -0.1,
                contrastModifier: 0.95,  // Softer contrast
                backgroundTint: Color(red: 0.08, green: 0.04, blue: 0.12).opacity(0.08),
                animationSpeed: 0.85
            )
            
        case .calm:
            // Balanced neutrals, default baseline
            return EmotionalPalette(
                accentHue: 220,          // Kosmic blue baseline
                accentSaturation: 0.8,
                shadowWarmth: 0.0,       // Neutral
                contrastModifier: 1.0,   // Baseline contrast
                backgroundTint: Color.clear,
                animationSpeed: 1.0      // Normal speed
            )
            
        case .energized:
            // Brighter blues/cyans, warm shadows, faster animations
            return EmotionalPalette(
                accentHue: 195,          // Cyan-blue
                accentSaturation: 1.0,
                shadowWarmth: 0.2,       // Slightly warm
                contrastModifier: 1.15,  // Higher contrast
                backgroundTint: Color(red: 0.05, green: 0.12, blue: 0.15).opacity(0.12),
                animationSpeed: 1.3      // Faster, snappier
            )
            
        case .fatigued:
            // Warmer tones, reduced contrast, gentler motion
            return EmotionalPalette(
                accentHue: 240,          // Warmer blue-purple
                accentSaturation: 0.6,
                shadowWarmth: 0.4,       // Warm shadows
                contrastModifier: 0.85,  // Reduced contrast (easier on eyes)
                backgroundTint: Color(red: 0.08, green: 0.06, blue: 0.08).opacity(0.1),
                animationSpeed: 0.65     // Much slower, gentler
            )
        }
    }
}

/// State detection result with confidence
struct EmotionalStateDetection: Sendable {
    let state: EmotionalState
    let confidence: Double      // 0.0 - 1.0
    let secondaryState: EmotionalState?
    let timestamp: Date
    
    init(state: EmotionalState, confidence: Double, secondaryState: EmotionalState? = nil) {
        self.state = state
        self.confidence = min(1.0, max(0.0, confidence))
        self.secondaryState = secondaryState
        self.timestamp = Date()
    }
}

