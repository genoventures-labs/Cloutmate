//
//  ThemeTelemetryService.swift
//  FocusOS
//
//  Phase 7: ARTE - Aurora Reactive Theme Engine
//  Performance monitoring and optimization telemetry
//

import Foundation
import os.log

@MainActor
final class ThemeTelemetryService {
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "ARTE-Telemetry")
    
    // Performance metrics
    private var updateCycleDurations: [TimeInterval] = []
    private var transitionCounts: [EmotionalState: Int] = [:]
    private var totalTransitions: Int = 0
    private var lastPerformanceReport: Date?
    
    // Targets
    private let targetCPUPercent: Double = 2.0
    private let targetUpdateLatency: TimeInterval = 0.1  // 100ms
    
    // Rolling averages
    private let maxSamples = 100
    
    init() {
        logger.info("ARTE Telemetry: Service initialized")
    }
    
    // MARK: - Recording
    
    /// Record a state detection update cycle
    func recordUpdateCycle(duration: TimeInterval, state: EmotionalState) {
        updateCycleDurations.append(duration)
        
        // Keep only recent samples
        if updateCycleDurations.count > maxSamples {
            updateCycleDurations.removeFirst()
        }
        
        // Log slow cycles
        if duration > targetUpdateLatency {
            logger.warning("ARTE: Slow update cycle (\(String(format: "%.0fms", duration * 1000)))")
        }
    }
    
    /// Record a state transition
    func recordStateTransition(from: EmotionalState, to: EmotionalState, confidence: Double) {
        totalTransitions += 1
        transitionCounts[to, default: 0] += 1
        
        logger.info("ARTE Transition: \(from.rawValue) → \(to.rawValue) (confidence: \(String(format: "%.2f", confidence)))")
    }
    
    /// Record transition progress
    func recordTransitionProgress(_ progress: Double) {
        // Could be used for smoother telemetry in the future
    }
    
    // MARK: - Reporting
    
    /// Get current performance metrics
    func getCurrentMetrics() -> ARTEPerformanceMetrics {
        let avgUpdateDuration = updateCycleDurations.isEmpty ? 0.0 : updateCycleDurations.reduce(0, +) / Double(updateCycleDurations.count)
        let maxUpdateDuration = updateCycleDurations.max() ?? 0.0
        
        return ARTEPerformanceMetrics(
            averageUpdateLatency: avgUpdateDuration,
            maxUpdateLatency: maxUpdateDuration,
            totalTransitions: totalTransitions,
            transitionsByState: transitionCounts,
            sampleCount: updateCycleDurations.count,
            isWithinTargets: avgUpdateDuration < targetUpdateLatency
        )
    }
    
    /// Log periodic performance report
    func logPerformanceReport() {
        let metrics = getCurrentMetrics()
        
        logger.info("""
        ARTE Performance Report:
        - Avg Update: \(String(format: "%.1fms", metrics.averageUpdateLatency * 1000))
        - Max Update: \(String(format: "%.1fms", metrics.maxUpdateLatency * 1000))
        - Total Transitions: \(metrics.totalTransitions)
        - Within Targets: \(metrics.isWithinTargets ? "✅" : "⚠️")
        """)
        
        lastPerformanceReport = Date()
    }
    
    /// Reset all metrics
    func reset() {
        updateCycleDurations.removeAll()
        transitionCounts.removeAll()
        totalTransitions = 0
        logger.info("ARTE Telemetry: Metrics reset")
    }
}

// MARK: - Performance Metrics

struct ARTEPerformanceMetrics: Sendable {
    let averageUpdateLatency: TimeInterval
    let maxUpdateLatency: TimeInterval
    let totalTransitions: Int
    let transitionsByState: [EmotionalState: Int]
    let sampleCount: Int
    let isWithinTargets: Bool
    
    var formattedAverageLatency: String {
        String(format: "%.0fms", averageUpdateLatency * 1000)
    }
    
    var formattedMaxLatency: String {
        String(format: "%.0fms", maxUpdateLatency * 1000)
    }
    
    var estimatedCPUPercent: Double {
        // Rough estimate based on update frequency
        // If updating every 10s with 100ms cycles = ~1% CPU
        let updatesPerSecond = 1.0 / 10.0  // Assuming 10s intervals
        let cpuTimePerSecond = averageUpdateLatency * updatesPerSecond
        return cpuTimePerSecond * 100.0
    }
}

