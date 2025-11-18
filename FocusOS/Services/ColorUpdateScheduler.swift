//
//  ColorUpdateScheduler.swift
//  FocusOS
//
//  Aurora Calendar Cognition Layer - Timer-based color updates
//

import Foundation
import SwiftData
import Combine
import os.log
import EventKit

@MainActor
final class ColorUpdateScheduler: ObservableObject {
    static let shared = ColorUpdateScheduler()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "ColorUpdateScheduler")
    private var updateTimer: Timer?
    private var isRunning = false
    private var cancellables = Set<AnyCancellable>()
    
    private let cognitionService = AuroraCalendarCognitionService.shared
    
    private init() {}
    
    // MARK: - Lifecycle
    
    func start(modelContext: ModelContext) {
        guard !isRunning else {
            logger.debug("ColorUpdateScheduler already running")
            return
        }
        
        guard UserDefaults.standard.bool(forKey: "calendarCognitionEnabled") != false else {
            logger.info("Calendar cognition disabled")
            return
        }
        
        isRunning = true
        logger.info("Starting ColorUpdateScheduler")
        
        scheduleTimer(modelContext: modelContext)
        observeNotifications(modelContext: modelContext)
    }
    
    func stop() {
        updateTimer?.invalidate()
        updateTimer = nil
        cancellables.removeAll()
        isRunning = false
        logger.info("Stopped ColorUpdateScheduler")
    }
    
    // MARK: - Scheduling
    
    private func scheduleTimer(modelContext: ModelContext) {
        updateTimer?.invalidate()
        
        let interval = updateInterval
        logger.debug("Scheduling color updates every \(interval) seconds")
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.triggerUpdate(modelContext: modelContext)
            }
        }
    }
    
    private var updateInterval: TimeInterval {
        let userInterval = UserDefaults.standard.double(forKey: "calendarColorUpdateInterval")
        if userInterval > 0 {
            return userInterval
        }
        
        // Default: 15 minutes, but respect reduce motion preference
        let reduceMotion = UserDefaults.standard.bool(forKey: "reduceMotion")
        return reduceMotion ? 1800 : 900 // 30 min if reduced motion, 15 min otherwise
    }
    
    // MARK: - Update Triggers
    
    private func triggerUpdate(modelContext: ModelContext) async {
        logger.debug("Triggering scheduled color update")
        await cognitionService.analyzeAndColorizeEvents(modelContext: modelContext)
    }
    
    private func observeNotifications(modelContext: ModelContext) {
        // Task completion
        NotificationCenter.default
            .publisher(for: .taskStatusChanged)
            .receive(on: DispatchQueue.main)
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.cognitionService.analyzeAndColorizeEvents(modelContext: modelContext)
                }
            }
            .store(in: &cancellables)
        
        // Focus session status change
        NotificationCenter.default
            .publisher(for: .focusSessionStatusChanged)
            .receive(on: DispatchQueue.main)
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.cognitionService.analyzeAndColorizeEvents(modelContext: modelContext)
                }
            }
            .store(in: &cancellables)
        
        // Project changes
        NotificationCenter.default
            .publisher(for: .projectStatusChanged)
            .receive(on: DispatchQueue.main)
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.cognitionService.analyzeAndColorizeEvents(modelContext: modelContext)
                }
            }
            .store(in: &cancellables)
        
        // Calendar event changes
        NotificationCenter.default
            .publisher(for: .EKEventStoreChanged)
            .receive(on: DispatchQueue.main)
            .debounce(for: .seconds(5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.cognitionService.analyzeAndColorizeEvents(modelContext: modelContext)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Immediate Updates
    
    func triggerImmediateUpdate(modelContext: ModelContext) {
        Task { @MainActor in
            await cognitionService.analyzeAndColorizeEvents(modelContext: modelContext)
        }
    }
}

