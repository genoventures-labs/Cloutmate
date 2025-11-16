//
//  SidebarToneSyncService.swift
//  Cloutmate
//
//  Sidebar V2: ARTE Tone Synchronization Service
//  Syncs sidebar background gradients with ARTE emotional states
//

import SwiftUI
import Combine

@MainActor
@Observable
final class SidebarToneSyncService {
    static let shared = SidebarToneSyncService()
    
    private(set) var currentGradient: LinearGradient
    private(set) var gradientOpacity: Double = 0.4
    
    private var cancellables = Set<AnyCancellable>()
    private var bindingCancellable: AnyCancellable?
    private var toneStabilizationTimer: Timer?
    
    private init() {
        // Initialize with calm state gradient
        currentGradient = Self.gradientForState(.calm)
        
        // Observe ReactiveThemeManager
        observeARTEState()
    }
    
    // MARK: - ARTE Observation
    
    private func observeARTEState() {
        bindToThemeManager()
    }
    
    // MARK: - Gradient Updates
    
    private func updateGradient(for state: EmotionalState) {
        let newGradient = Self.gradientForState(state)
        
        // Crossfade transition (300-350ms)
        withAnimation(.easeInOut(duration: 0.325)) {
            currentGradient = newGradient
            gradientOpacity = 1.0
        }
        
        // Reset stabilization timer
        resetStabilizationTimer()
    }
    
    private func resetStabilizationTimer() {
        toneStabilizationTimer?.invalidate()
        
        // Fade to 40% opacity when tone stabilizes (after 5 seconds)
        toneStabilizationTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                self.gradientOpacity = 0.4
            }
        }
    }
    
    // MARK: - Priming
    
    func prime(with state: EmotionalState, intensity: Double) {
        toneStabilizationTimer?.invalidate()
        currentGradient = Self.gradientForState(state)
        withAnimation(.easeInOut(duration: 0.25)) {
            gradientOpacity = 0.4 + (0.2 * min(1.0, intensity))
        }
        resetStabilizationTimer()
    }
    
    @MainActor
    func bindToThemeManager() {
        ReactiveThemeManager.shared.$currentState
            .combineLatest(ReactiveThemeManager.shared.$intensity)
            .receive(on: RunLoop.main)
            .sink { [weak self] state, intensity in
                self?.prime(with: state, intensity: intensity)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Gradient Mapping
    
    static func gradientForState(_ state: EmotionalState) -> LinearGradient {
        let colors: [Color]
        
        switch state {
        case .calm:
            colors = [
                Color.kosmicBlue,
                Color.kosmicPurple
            ]
        case .reflective:
            colors = [
                Color.kosmicPurple,
                Color(red: 0.44, green: 0.31, blue: 0.92) // kosmicViolet
            ]
        case .energized:
            colors = [
                Color.kosmicGreen,
                Color.kosmicBlue
            ]
        case .fatigued:
            // Desaturated kosmicBlue → gray fade
            colors = [
                Color.kosmicBlue.opacity(0.6),
                Color.gray.opacity(0.4)
            ]
        case .focused:
            // Deep blue for focused state
            colors = [
                Color.kosmicBlue,
                Color(red: 0.2, green: 0.4, blue: 0.8) // Deeper blue
            ]
        }
        
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

