//
//  ThemeInterpolator.swift
//  Cloutmate
//
//  Phase 7: ARTE - Aurora Reactive Theme Engine
//  Handles smooth state transitions with instant trigger and gradual completion
//

import SwiftUI
import Combine
import os.log

@MainActor
final class ThemeInterpolator: ObservableObject {
    @Published private(set) var currentProgress: Double = 1.0  // 0.0 = starting, 1.0 = complete
    @Published private(set) var isTransitioning: Bool = false
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "ARTE")
    
    private var fromState: EmotionalState = .calm
    private var toState: EmotionalState = .calm
    private var transitionStartTime: Date?
    private var timer: Timer?
    
    // Transition timing
    private let instantPhase: TimeInterval = 0.3      // Quick initial shift
    private let gradualPhase: TimeInterval = 90.0     // 90 seconds full morph (60-120s range)
    
    /// Start a transition from one state to another
    func beginTransition(from: EmotionalState, to: EmotionalState) {
        guard from != to else {
            logger.debug("ARTE: Skipping transition (states are identical)")
            return
        }
        
        // Cancel any existing transition
        cancelTransition()
        
        self.fromState = from
        self.toState = to
        self.currentProgress = 0.0
        self.transitionStartTime = Date()
        self.isTransitioning = true
        
        logger.info("ARTE: Beginning transition \(from.rawValue) → \(to.rawValue)")
        
        // Start animation loop
        startAnimationLoop()
    }
    
    /// Cancel current transition
    func cancelTransition() {
        timer?.invalidate()
        timer = nil
        isTransitioning = false
    }
    
    /// Complete transition instantly (for manual overrides)
    func completeInstantly() {
        currentProgress = 1.0
        isTransitioning = false
        cancelTransition()
    }
    
    // MARK: - Animation Loop
    
    private func startAnimationLoop() {
        // Use a timer to update progress smoothly
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updateProgress()
            }
        }
    }
    
    private func updateProgress() {
        guard let startTime = transitionStartTime else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let totalDuration = instantPhase + gradualPhase
        
        // Calculate progress with easing
        let rawProgress = min(1.0, elapsed / totalDuration)
        
        // Apply easing curve (ease-in-out cubic)
        let easedProgress = easeInOutCubic(rawProgress)
        
        currentProgress = easedProgress
        
        // Complete transition when done
        if rawProgress >= 1.0 {
            completeTransition()
        }
    }
    
    private func completeTransition() {
        currentProgress = 1.0
        isTransitioning = false
        cancelTransition()
        
        logger.info("ARTE: Transition complete (\(self.fromState.rawValue) → \(self.toState.rawValue))")
    }
    
    // MARK: - Easing Functions
    
    /// Ease-in-out cubic for smooth transitions
    private func easeInOutCubic(_ t: Double) -> Double {
        if t < 0.5 {
            return 4 * t * t * t
        } else {
            let f = (2 * t) - 2
            return 0.5 * f * f * f + 1
        }
    }
    
    // MARK: - Interpolation Helpers
    
    /// Interpolate between two palettes based on current progress
    func interpolatedPalette(from: EmotionalPalette, to: EmotionalPalette) -> EmotionalPalette {
        let t = currentProgress
        
        return EmotionalPalette(
            accentHue: lerp(from.accentHue, to.accentHue, t: t),
            accentSaturation: lerp(from.accentSaturation, to.accentSaturation, t: t),
            shadowWarmth: lerp(from.shadowWarmth, to.shadowWarmth, t: t),
            contrastModifier: lerp(from.contrastModifier, to.contrastModifier, t: t),
            backgroundTint: interpolateColor(from: from.backgroundTint, to: to.backgroundTint, t: t),
            animationSpeed: lerp(from.animationSpeed, to.animationSpeed, t: t)
        )
    }
    
    /// Linear interpolation
    private func lerp(_ a: Double, _ b: Double, t: Double) -> Double {
        return a + (b - a) * t
    }
    
    /// Color interpolation
    private func interpolateColor(from: Color, to: Color, t: Double) -> Color {
        // Convert to RGB components and interpolate
        // This is a simplified version - production would use proper color space conversion
        return Color(
            red: lerp(from.red, to.red, t: t),
            green: lerp(from.green, to.green, t: t),
            blue: lerp(from.blue, to.blue, t: t),
            opacity: lerp(from.opacity, to.opacity, t: t)
        )
    }
}

// MARK: - Color Component Extensions

extension Color {
    var red: Double {
        guard let components = cgColor?.components, components.count >= 3 else { return 0 }
        return Double(components[0])
    }
    
    var green: Double {
        guard let components = cgColor?.components, components.count >= 3 else { return 0 }
        return Double(components[1])
    }
    
    var blue: Double {
        guard let components = cgColor?.components, components.count >= 3 else { return 0 }
        return Double(components[2])
    }
    
    var opacity: Double {
        guard let components = cgColor?.components, components.count >= 4 else { return 1 }
        return Double(components[3])
    }
}

