//
//  ContextSwitchGuard.swift
//  Cloutmate
//
//  Phase 9B: Adaptive temporal intelligence – protects against reactive context switching.
//

import Foundation
import SwiftData
import Combine
import os.log

@MainActor
final class ContextSwitchGuard: ObservableObject {
    static let shared = ContextSwitchGuard()

    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "ContextSwitchGuard")
    private var cancellables = Set<AnyCancellable>()
    private var latestMomentum: MomentumMetrics?
    private var currentEmotion: EmotionalState = .calm
    private var lastPromptAt: Date?
    private var isRunning = false

    private init() {}

    func start(modelContext: ModelContext) {
        guard !isRunning else { return }
        isRunning = true
        logger.info("Starting ContextSwitchGuard")

        observeArteState()
        DriftMonitor.shared.momentumPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] metrics in
                self?.latestMomentum = metrics
            }
            .store(in: &cancellables)
    }

    func stop() {
        cancellables.removeAll()
        isRunning = false
    }

    func shouldInterceptSwitch(
        from currentTab: TabIdentifier,
        to destinationTab: TabIdentifier,
        modelContext: ModelContext
    ) -> InterceptDecision {
        guard ContextGuardSettings.shared.isGuardEnabled else { return .allow }
        guard currentTab != destinationTab else { return .allow }

        let activeSession = FocusSessionService.shared.getActiveSession(modelContext: modelContext)
        let context = SwitchContext(
            from: currentTab,
            to: destinationTab,
            activeSession: activeSession,
            momentum: latestMomentum,
            emotionalState: currentEmotion
        )

        let severity = computeSeverityScore(context: context)
        let baseDelay = ContextGuardSettings.shared.sensitivityDelay

        switch severity {
        case ..<0.35:
            return .allow
        case 0.35..<0.65:
            let delay = baseDelay.clamped(to: 1.0...2.0)
            let message = generatePromptMessage(context: context, severity: severity)
            lastPromptAt = Date()
            return .softPrompt(delay: delay, message: message)
        default:
            let delay = max(baseDelay * 1.5, 2.5)
            let message = generatePromptMessage(context: context, severity: severity)
            lastPromptAt = Date()
            return .strongPrompt(delay: delay, message: message)
        }
    }

    func recordOverride(decision: InterceptDecision) {
        guard let lastPrompt = lastPromptAt else { return }
        let seconds = Date().timeIntervalSince(lastPrompt)
        logger.info("Context switch override after \(seconds, privacy: .public)s for decision \(decision.description, privacy: .public)")
    }

    // MARK: - Helpers

    private func observeArteState() {
        ReactiveThemeManager.shared.emotionalStatePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.currentEmotion = state
            }
            .store(in: &cancellables)
    }

    private func computeSeverityScore(context: SwitchContext) -> Double {
        var score: Double = 0.0

        if let session = context.activeSession, session.isActive {
            score += 0.45
            // If user attempts to leave focus-related tabs, escalate further
            if [.focusMode, .focusGravity, .tasks].contains(context.from) {
                score += 0.1
            }
        }

        if let momentum = context.momentum {
            switch momentum.flowState {
            case .highFlow:
                score -= 0.05
            case .steadyFlow:
                score += 0.05
            case .slowingFlow:
                score += 0.18
            case .stalled:
                score += 0.28
            }
        } else {
            // Without momentum data assume neutral flow
            score += 0.08
        }

        switch context.emotionalState {
        case .energized:
            score -= 0.05
        case .focused:
            score += 0.1
        case .reflective:
            score += 0.08
        case .calm:
            score += 0.05
        case .fatigued:
            score += 0.2
        }

        score += ContextGuardSettings.shared.sensitivityBias

        return max(0.0, score)
    }

    private func generatePromptMessage(context: SwitchContext, severity: Double) -> String {
        if let session = context.activeSession, session.isActive {
            let objective = session.objective
            if severity >= 0.65 {
                return "You're mid-focus on \(objective). Want to protect this block before hopping to \(context.to.rawValue)?"
            } else {
                return "Quick check — stay with \(objective) or switch to \(context.to.rawValue)?"
            }
        }

        if context.emotionalState == .fatigued {
            return "You're in a low-energy groove. Pause a sec before switching to \(context.to.rawValue)."
        }

        if let momentum = context.momentum, momentum.flowState == .highFlow {
            return "Momentum is strong right now. Make sure switching to \(context.to.rawValue) keeps you in flow."
        }

        return "Take a breath — do you really need to jump to \(context.to.rawValue) right now?"
    }
}

// MARK: - Support Types

struct SwitchContext {
    let from: TabIdentifier
    let to: TabIdentifier
    let activeSession: FocusSession?
    let momentum: MomentumMetrics?
    let emotionalState: EmotionalState
}

enum InterceptDecision: Equatable {
    case allow
    case softPrompt(delay: TimeInterval, message: String)
    case strongPrompt(delay: TimeInterval, message: String)

    var description: String {
        switch self {
        case .allow:
            return "allow"
        case .softPrompt:
            return "softPrompt"
        case .strongPrompt:
            return "strongPrompt"
        }
    }
}

// MARK: - Settings

@MainActor
final class ContextGuardSettings: ObservableObject {
    static let shared = ContextGuardSettings()

    private struct Keys {
        static let guardEnabled = "contextGuard.enabled"
        static let sensitivity = "contextGuard.sensitivity"
        static let baseDelay = "contextGuard.baseDelay"
    }

    var isGuardEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Keys.guardEnabled) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.guardEnabled) }
    }

    /// 0.0 - 1.0 slider representing guard aggressiveness.
    var sensitivity: Double {
        get { UserDefaults.standard.object(forKey: Keys.sensitivity) as? Double ?? 0.6 }
        set { UserDefaults.standard.set(newValue, forKey: Keys.sensitivity) }
    }

    /// Base pause before allowing switch (seconds).
    var baseDelay: Double {
        get { UserDefaults.standard.object(forKey: Keys.baseDelay) as? Double ?? 1.5 }
        set { UserDefaults.standard.set(newValue, forKey: Keys.baseDelay) }
    }

    var sensitivityBias: Double {
        (sensitivity - 0.5) * 0.3
    }

    var sensitivityDelay: Double {
        max(1.0, min(3.0, baseDelay + (sensitivity - 0.5)))
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        return max(range.lowerBound, min(range.upperBound, self))
    }
}


