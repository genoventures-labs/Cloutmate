//
//  FlowTriggersService.swift
//  Cloutmate
//
//  Phase 10: Monitors context and fires reflection opportunities
//

import Foundation
import SwiftData
import Combine
import os.log
import AppKit

@MainActor
final class FlowTriggersService: ObservableObject {
    static let shared = FlowTriggersService()
    
    @Published private(set) var shouldTriggerReflection: Bool = false
    @Published private(set) var currentTriggerType: ReflectionTriggerType?
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "FlowTriggers")
    private var cancellables = Set<AnyCancellable>()
    private var idleTimer: Timer?
    private var lastActivityTime: Date = Date()
    private var isRunning = false
    
    private init() {}
    
    func start(modelContext: ModelContext) {
        guard !isRunning else { return }
        isRunning = true
        logger.info("Starting FlowTriggersService")
        
        // Initialize last activity time
        lastActivityTime = Date()
        
        observeDriftEvents()
        observeRitualEvents()
        observeFocusSessions(modelContext: modelContext)
        startIdleMonitoring()
        
        logger.info("FlowTriggersService started - idle monitoring active: \(FlowCompanionSettings.shared.isIdleTriggerEnabled)")
    }
    
    func stop() {
        idleTimer?.invalidate()
        cancellables.removeAll()
        isRunning = false
        logger.info("Stopped FlowTriggersService")
    }
    
    func triggerManual() {
        currentTriggerType = .manual
        shouldTriggerReflection = true
        logger.info("Manual reflection trigger")
    }
    
    // MARK: - Observers
    
    private func observeDriftEvents() {
        DriftMonitor.shared.driftPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard FlowCompanionSettings.shared.isDriftTriggerEnabled else { return }
                self?.currentTriggerType = .drift
                self?.shouldTriggerReflection = true
                self?.logger.info("Drift event detected - triggering reflection")
            }
            .store(in: &cancellables)
    }
    
    private func observeRitualEvents() {
        NotificationCenter.default.publisher(for: NSNotification.Name("EveningRitualOpened"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard FlowCompanionSettings.shared.isEveningTriggerEnabled else { return }
                self?.currentTriggerType = .evening
                self?.shouldTriggerReflection = true
                self?.logger.info("Evening ritual opened - triggering reflection")
            }
            .store(in: &cancellables)
    }
    
    private func observeFocusSessions(modelContext: ModelContext) {
        NotificationCenter.default.publisher(for: NSNotification.Name("FocusSessionStarted"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.lastActivityTime = Date()
                self?.resetIdleTimer()
            }
            .store(in: &cancellables)
        
        // Also track user activity from any tab
        NotificationCenter.default.publisher(for: NSNotification.Name("CurrentTabUpdated"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.lastActivityTime = Date()
            }
            .store(in: &cancellables)
        
        // Track keyboard/mouse activity
        setupActivityTracking()
    }
    
    private func setupActivityTracking() {
        // Track tab switches as activity
        // (Already handled in observeFocusSessions)
        
        // For macOS, we can't easily track global keyboard/mouse without accessibility permissions
        // Instead, we'll rely on:
        // 1. Tab switches (already tracked)
        // 2. Focus session starts (already tracked)
        // 3. Manual activity updates from the app
        
        // Post notification when user interacts with the app
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UserActivity"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.lastActivityTime = Date()
        }
    }
    
    /// Call this method to update activity timestamp (can be called from views)
    func updateActivity() {
        lastActivityTime = Date()
    }
    
    private func startIdleMonitoring() {
        guard FlowCompanionSettings.shared.isIdleTriggerEnabled else { return }
        
        idleTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.checkIdleState()
        }
    }
    
    private func checkIdleState() {
        guard FlowCompanionSettings.shared.isIdleTriggerEnabled else { return }
        guard FlowCompanionSettings.shared.isEnabled else { return }
        
        let idleDuration = Date().timeIntervalSince(lastActivityTime)
        let idleThreshold: TimeInterval = Double(FlowCompanionSettings.shared.idleTimeoutMinutes) * 60
        
        logger.debug("Checking idle state - duration: \(Int(idleDuration / 60)) minutes, threshold: \(FlowCompanionSettings.shared.idleTimeoutMinutes) minutes")
        
        if idleDuration >= idleThreshold {
            // Only trigger once per idle period (cooldown)
            if shouldTriggerReflection {
                logger.debug("Reflection already triggered, skipping")
                return // Already triggered, wait for acknowledgment
            }
            
            // Check if there's an active focus session
            let activeSession = FocusSessionService.shared.getActiveSession(
                modelContext: CloutmateApp.sharedModelContainer.mainContext
            )
            
            // Trigger on any tab when idle (user can disable in settings if they don't want it)
            // This allows the reflection buddy to appear during idle periods
            currentTriggerType = .idle
            shouldTriggerReflection = true
            logger.info("Idle state detected - triggering reflection (duration: \(Int(idleDuration / 60)) minutes, threshold: \(FlowCompanionSettings.shared.idleTimeoutMinutes) minutes, active session: \(activeSession != nil))")
            resetIdleTimer()
        }
    }
    
    private func resetIdleTimer() {
        lastActivityTime = Date()
    }
    
    func acknowledgeTrigger() {
        shouldTriggerReflection = false
        currentTriggerType = nil
    }
}

// MARK: - Settings

@MainActor
final class FlowCompanionSettings: ObservableObject {
    static let shared = FlowCompanionSettings()
    
    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "flowCompanionEnabled") }
    }
    
    @Published var isDriftTriggerEnabled: Bool {
        didSet { UserDefaults.standard.set(isDriftTriggerEnabled, forKey: "flowCompanionDriftTrigger") }
    }
    
    @Published var isEveningTriggerEnabled: Bool {
        didSet { UserDefaults.standard.set(isEveningTriggerEnabled, forKey: "flowCompanionEveningTrigger") }
    }
    
    @Published var isIdleTriggerEnabled: Bool {
        didSet { UserDefaults.standard.set(isIdleTriggerEnabled, forKey: "flowCompanionIdleTrigger") }
    }
    
    @Published var reflectionTone: String {
        didSet { UserDefaults.standard.set(reflectionTone, forKey: "flowCompanionTone") }
    }
    
    @Published var idleTimeoutMinutes: Int {
        didSet { UserDefaults.standard.set(idleTimeoutMinutes, forKey: "flowCompanionIdleTimeoutMinutes") }
    }
    
    private init() {
        // Default to enabled for Flow Companion
        self.isEnabled = UserDefaults.standard.object(forKey: "flowCompanionEnabled") == nil ? true : UserDefaults.standard.bool(forKey: "flowCompanionEnabled")
        self.isDriftTriggerEnabled = UserDefaults.standard.object(forKey: "flowCompanionDriftTrigger") == nil ? true : UserDefaults.standard.bool(forKey: "flowCompanionDriftTrigger")
        self.isEveningTriggerEnabled = UserDefaults.standard.object(forKey: "flowCompanionEveningTrigger") == nil ? true : UserDefaults.standard.bool(forKey: "flowCompanionEveningTrigger")
        self.isIdleTriggerEnabled = UserDefaults.standard.object(forKey: "flowCompanionIdleTrigger") == nil ? true : UserDefaults.standard.bool(forKey: "flowCompanionIdleTrigger")
        self.reflectionTone = UserDefaults.standard.string(forKey: "flowCompanionTone") ?? "gentle"
        self.idleTimeoutMinutes = UserDefaults.standard.object(forKey: "flowCompanionIdleTimeoutMinutes") == nil ? 5 : UserDefaults.standard.integer(forKey: "flowCompanionIdleTimeoutMinutes")
    }
}

