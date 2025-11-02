//
//  ReactiveThemeManager.swift
//  Cloutmate
//
//  Phase 7: ARTE - Aurora Reactive Theme Engine
//  Central orchestrator for real-time emotional theme adaptation
//

import SwiftUI
import SwiftData
import Combine
import os.log

@MainActor
final class ReactiveThemeManager: ObservableObject {
    static let shared = ReactiveThemeManager()
    
    @Published private(set) var currentState: EmotionalState = .calm
    @Published private(set) var previousState: EmotionalState = .calm
    @Published private(set) var confidence: Double = 1.0
    @Published var isEnabled: Bool = true
    @Published var mode: ARTEMode = .auto
    @Published var intensity: Double = 0.7
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "ARTE")
    private let detector = EmotionalStateDetector()
    private let interpolator = ThemeInterpolator()
    private let telemetry = ThemeTelemetryService()
    
    private var pollingTimer: Timer?
    private var lastSnapshot: AnalyticsSnapshot?
    private var lastSnapshotTime: Date?
    private let snapshotCacheValidity: TimeInterval = 15.0  // Cache for 15 seconds
    
    // Adaptive polling intervals
    private var currentPollingInterval: TimeInterval = 10.0
    private let minPollingInterval: TimeInterval = 10.0
    private let maxPollingInterval: TimeInterval = 60.0
    
    // Debouncing
    private var lastStateChangeTime: Date?
    private let minTimeBetweenTransitions: TimeInterval = 120.0  // 2 minutes minimum
    
    var cancellables = Set<AnyCancellable>()
    private var configuration: ARTEConfiguration?
    
    private init() {
        logger.info("ARTE: ReactiveThemeManager initialized")
    }
    
    // MARK: - Lifecycle
    
    /// Start ARTE with model context
    func start(modelContext: ModelContext) {
        logger.info("ARTE: Starting reactive theme system")
        
        // Load configuration
        loadConfiguration(modelContext: modelContext)
        
        // Start polling if enabled
        if isEnabled {
            startPolling(modelContext: modelContext)
        }
        
        // Subscribe to interpolator progress
        interpolator.$currentProgress
            .sink { [weak self] progress in
                self?.telemetry.recordTransitionProgress(progress)
            }
            .store(in: &cancellables)
    }
    
    /// Stop ARTE
    func stop() {
        logger.info("ARTE: Stopping reactive theme system")
        stopPolling()
        cancellables.removeAll()
    }
    
    /// Restart with new configuration
    func restart(modelContext: ModelContext) {
        stop()
        start(modelContext: modelContext)
    }
    
    // MARK: - Configuration
    
    private func loadConfiguration(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<ARTEConfiguration>()
        
        if let existing = try? modelContext.fetch(descriptor).first {
            configuration = existing
            isEnabled = existing.isEnabled
            mode = existing.mode
            intensity = existing.intensity
            
            // If locked state exists, apply it
            if let locked = existing.lockedState {
                currentState = locked
            }
        } else {
            // Create default configuration
            let config = ARTEConfiguration()
            modelContext.insert(config)
            try? modelContext.save()
            configuration = config
        }
        
        logger.info("ARTE: Configuration loaded (enabled: \(self.isEnabled), mode: \(self.mode.rawValue))")
    }
    
    func saveConfiguration(modelContext: ModelContext) {
        guard let config = configuration else { return }
        
        config.isEnabled = isEnabled
        config.mode = mode
        config.intensity = intensity
        config.lastUpdated = Date()
        
        try? modelContext.save()
    }
    
    // MARK: - State Detection & Polling
    
    private func startPolling(modelContext: ModelContext) {
        // Immediate first check
        updateState(modelContext: modelContext)
        
        // Schedule timer
        pollingTimer = Timer.scheduledTimer(withTimeInterval: currentPollingInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updateState(modelContext: modelContext)
            }
        }
        
        logger.info("ARTE: Polling started (interval: \(self.currentPollingInterval)s)")
    }
    
    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    private func updateState(modelContext: ModelContext) {
        // Skip if disabled or in manual mode
        guard isEnabled else { return }
        guard mode == .auto || mode == .blend else { return }
        
        let startTime = Date()
        
        // Get analytics snapshot (cached)
        let snapshot = getCachedSnapshot(modelContext: modelContext)
        
        // Detect emotional state
        let detection = detector.detectState(
            from: snapshot,
            calibration: loadCalibration(),
            modelContext: modelContext
        )
        
        // Check if state changed and debounce
        if detection.state != currentState {
            if shouldTransition(to: detection.state) {
                transitionToState(detection.state, confidence: detection.confidence, modelContext: modelContext)
            }
        }
        
        // Adapt polling interval based on activity
        adaptPollingInterval(snapshot: snapshot)
        
        // Record telemetry
        let elapsed = Date().timeIntervalSince(startTime)
        telemetry.recordUpdateCycle(duration: elapsed, state: currentState)
    }
    
    private func getCachedSnapshot(modelContext: ModelContext) -> AnalyticsSnapshot {
        // Return cached snapshot if still valid
        if let cached = lastSnapshot,
           let cacheTime = lastSnapshotTime,
           Date().timeIntervalSince(cacheTime) < snapshotCacheValidity {
            return cached
        }
        
        // Generate fresh snapshot
        let snapshot = AnalyticsEngine.shared.generateSnapshot(
            for: .today,
            modelContext: modelContext
        )
        
        lastSnapshot = snapshot
        lastSnapshotTime = Date()
        
        return snapshot
    }
    
    private func shouldTransition(to newState: EmotionalState) -> Bool {
        // Debounce: require minimum time between transitions
        if let lastChange = lastStateChangeTime {
            let timeSinceLastChange = Date().timeIntervalSince(lastChange)
            if timeSinceLastChange < minTimeBetweenTransitions {
                logger.debug("ARTE: Transition debounced (too soon)")
                return false
            }
        }
        
        return true
    }
    
    private func transitionToState(_ newState: EmotionalState, confidence: Double, modelContext: ModelContext) {
        logger.info("ARTE: Transitioning \(self.currentState.rawValue) → \(newState.rawValue) (confidence: \(String(format: "%.2f", confidence)))")
        
        // Record transition history
        let history = StateTransitionHistory(
            fromState: currentState,
            toState: newState,
            confidence: confidence,
            wasManualOverride: false,
            completionRate: lastSnapshot?.completionRate ?? 0.0,
            focusSessionActive: (lastSnapshot?.focusSessionsCount ?? 0) > 0,
            emotionalValence: lastSnapshot?.emotionalSnapshot.valence ?? 0.0,
            activeThemes: lastSnapshot?.activeThemes ?? 0
        )
        modelContext.insert(history)
        try? modelContext.save()
        
        // Update state
        previousState = currentState
        currentState = newState
        self.confidence = confidence
        lastStateChangeTime = Date()
        
        // Start visual transition
        interpolator.beginTransition(from: previousState, to: currentState)
        
        // Record telemetry
        telemetry.recordStateTransition(from: previousState, to: currentState, confidence: confidence)
        
        // Complete history entry when transition finishes
        DispatchQueue.main.asyncAfter(deadline: .now() + 90.0) {
            history.complete()
            try? modelContext.save()
        }
    }
    
    // MARK: - Manual Control
    
    /// Manually set state (user override)
    func setManualState(_ state: EmotionalState, modelContext: ModelContext) {
        logger.info("ARTE: Manual override to \(state.rawValue)")
        
        // Record as manual override
        if let config = configuration {
            config.recordManualOverride()
            config.lockedState = mode == .manual ? state : nil
            try? modelContext.save()
        }
        
        // Record transition
        let history = StateTransitionHistory(
            fromState: currentState,
            toState: state,
            confidence: 1.0,
            wasManualOverride: true,
            completionRate: lastSnapshot?.completionRate ?? 0.0,
            focusSessionActive: (lastSnapshot?.focusSessionsCount ?? 0) > 0,
            emotionalValence: lastSnapshot?.emotionalSnapshot.valence ?? 0.0,
            activeThemes: lastSnapshot?.activeThemes ?? 0
        )
        modelContext.insert(history)
        try? modelContext.save()
        
        // Transition
        previousState = currentState
        currentState = state
        confidence = 1.0
        
        interpolator.completeInstantly()  // Manual overrides are instant
        
        // Adapt detector based on override
        let allHistory = (try? modelContext.fetch(FetchDescriptor<StateTransitionHistory>())) ?? []
        detector.adaptThresholds(from: allHistory)
    }
    
    /// Clear manual lock
    func clearManualLock(modelContext: ModelContext) {
        if let config = configuration {
            config.lockedState = nil
            try? modelContext.save()
        }
        
        // Resume auto detection
        if mode == .auto || mode == .blend {
            updateState(modelContext: modelContext)
        }
    }
    
    // MARK: - Adaptive Polling
    
    private func adaptPollingInterval(snapshot: AnalyticsSnapshot) {
        // High activity = faster polling
        let activityScore = calculateActivityScore(snapshot: snapshot)
        
        if activityScore > 0.7 {
            currentPollingInterval = minPollingInterval
        } else if activityScore > 0.4 {
            currentPollingInterval = 30.0
        } else {
            currentPollingInterval = maxPollingInterval
        }
        
        // Restart timer if interval changed significantly
        if let timer = pollingTimer, abs(timer.timeInterval - currentPollingInterval) > 5.0 {
            stopPolling()
            // Will restart on next cycle
        }
    }
    
    private func calculateActivityScore(snapshot: AnalyticsSnapshot) -> Double {
        var score: Double = 0.0
        
        // Recent task activity
        if snapshot.tasksCompleted > 0 {
            score += 0.3
        }
        
        // Active focus session
        if snapshot.focusSessionsCount > 0 {
            score += 0.4
        }
        
        // High CPS activity
        if snapshot.avgPriorityScore > 0.5 {
            score += 0.3
        }
        
        return min(1.0, score)
    }
    
    // MARK: - Calibration
    
    private func loadCalibration() -> ARTECalibration? {
        guard let config = configuration,
              let data = config.calibrationData else {
            return nil
        }
        
        return try? JSONDecoder().decode(ARTECalibration.self, from: data)
    }
    
    func saveCalibration(_ calibration: ARTECalibration, modelContext: ModelContext) {
        guard let config = configuration,
              let data = try? JSONEncoder().encode(calibration) else {
            return
        }
        
        config.calibrationData = data
        try? modelContext.save()
    }
    
    // MARK: - Public Accessors
    
    var currentPalette: EmotionalPalette {
        EmotionalPalette.palette(for: currentState)
    }
    
    var transitionProgress: Double {
        interpolator.currentProgress
    }
    
    var isTransitioning: Bool {
        interpolator.isTransitioning
    }
}

