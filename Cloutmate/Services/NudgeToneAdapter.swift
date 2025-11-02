//
//  NudgeToneAdapter.swift
//  Cloutmate
//
//  Phase 8: Cognitive Loop Completion
//  Bridges ARTE emotional state to smart nudge tone and suppression rules
//

import Foundation
import Combine
import os.log

@MainActor
final class NudgeToneAdapter: ObservableObject {
    static let shared = NudgeToneAdapter()

    @Published private(set) var currentEmotion: EmotionalState = .calm
    @Published private(set) var currentConfidence: Double = 1.0

    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "NudgeToneAdapter")
    private var cancellables = Set<AnyCancellable>()

    private init() {
        observeReactiveTheme()
    }

    // MARK: - Tone Resolution

    func tone(for trigger: SmartNudgeTrigger) -> SmartNudgeTone {
        switch currentEmotion {
        case .calm:
            return .calm
        case .focused:
            return trigger == .stalePriority ? .focused : .gentle
        case .energized:
            return .energized
        case .reflective:
            return .reflective
        case .fatigued:
            return .gentle
        }
    }

    var shouldSuppressDueToFatigue: Bool {
        guard currentEmotion == .fatigued else { return false }
        return RitualSettings.shared.delayPromptsWhenFatigued
    }

    // MARK: - Observers

    private func observeReactiveTheme() {
        let manager = ReactiveThemeManager.shared

        manager.$currentState
            .receive(on: RunLoop.main)
            .sink { [weak self] newState in
                guard let self else { return }
                self.logger.debug("Nudge tone emotion updated: \(newState.rawValue, privacy: .public)")
                self.currentEmotion = newState
            }
            .store(in: &cancellables)

        manager.$confidence
            .receive(on: RunLoop.main)
            .sink { [weak self] confidence in
                self?.currentConfidence = confidence
            }
            .store(in: &cancellables)
    }
}


