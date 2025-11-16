//
//  AuroraEcosphericLayer.swift
//  Cloutmate
//
//  Global affect network treating all Aurora subsystems as nodes in an emotional ecosystem
//

import Foundation
import SwiftData
import SwiftUI
import os.log
import Combine
import Combine
import Combine

@MainActor
final class AuroraEcosphericLayer {
    static let shared = AuroraEcosphericLayer()
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "AuroraEcosphericLayer")
    
    // Current ERI cache
    @Published private(set) var currentERI: Double = 0.0
    @Published private(set) var currentCategory: ERICategory = .neutral
    @Published private(set) var lastCalculated: Date?
    
    // Subsystem node references
    private var toneKitNode: ToneKitNode?
    private var temporalMemoryNode: TemporalMemoryNode?
    private var continuityEngineNode: ContinuityEngineNode?
    private var arteNode: ARTENode?
    
    private init() {}
    
    // MARK: - Node State Structures
    
    struct ToneKitNode {
        let dominantTone: AuroraTone?
        let toneDistribution: [AuroraTone: Double] // Normalized weights
        let averageAccuracy: Double
        let volatility: Double
    }
    
    struct TemporalMemoryNode {
        let rollingBaseline: Double
        let historicalBaseline: Double
        let momentum: Double
        let volatility: Double
    }
    
    struct ContinuityEngineNode {
        let aecIndex: Double
        let stabilityScore: Double
        let sentimentMomentum: Double
        let volatilityScore: Double
    }
    
    struct ARTENode {
        let emotionalState: EmotionalState
        let intensity: Double
        let stability: Double
    }
    
    // MARK: - ERI Calculation
    
    /// Calculate Ecospheric Resonance Index from all subsystem nodes
    func calculateERI(
        modelContext: ModelContext
    ) async -> ERIHistory? {
        logger.info("Calculating ERI from subsystem nodes")
        
        // Collect node states from all subsystems
        let nodes = await collectSubsystemNodes(modelContext: modelContext)
        
        // Calculate component scores
        let toneCoherence = calculateToneCoherence(nodes: nodes)
        let volatilitySync = calculateVolatilitySync(nodes: nodes)
        let pacingStability = calculatePacingStability(nodes: nodes)
        
        // Calculate ERI: weighted average of components
        // Formula: (toneCoherence * 0.4) + (volatilitySync * 0.3) + (pacingStability * 0.3)
        let eriIndex = (toneCoherence * 0.4) + (volatilitySync * 0.3) + (pacingStability * 0.3)
        
        // Clamp to -1.0 to +1.0
        let clampedERI = min(1.0, max(-1.0, eriIndex))
        
        // Get previous ERI for delta calculation
        let previousERI = currentERI
        let eriDelta = clampedERI - previousERI
        
        // Create ERI history entry
        let history = ERIHistory(
            eriIndex: clampedERI,
            toneCoherence: toneCoherence,
            volatilitySync: volatilitySync,
            pacingStability: pacingStability,
            eriDelta: eriDelta,
            previousERI: previousERI
        )
        
        // Store subsystem states
        history.toneKitState = encodeToneKitState(nodes.toneKit)
        history.temporalMemoryState = encodeTemporalMemoryState(nodes.temporalMemory)
        history.continuityEngineState = encodeContinuityEngineState(nodes.continuityEngine)
        history.arteState = encodeARTEState(nodes.arte)
        
        modelContext.insert(history)
        
        // Update cache
        currentERI = clampedERI
        currentCategory = history.category
        lastCalculated = Date()
        
        // Apply self-balancing feedback
        await applySelfBalancingFeedback(history: history, nodes: nodes, modelContext: modelContext)
        
        do {
            try modelContext.save()
            logger.info("Calculated ERI: \(String(format: "%.2f", clampedERI)) (category: \(history.category.rawValue))")
        } catch {
            logger.error("Failed to save ERI history: \(error.localizedDescription)")
        }
        
        return history
    }
    
    // MARK: - Node Collection
    
    private func collectSubsystemNodes(
        modelContext: ModelContext
    ) async -> (toneKit: ToneKitNode, temporalMemory: TemporalMemoryNode, continuityEngine: ContinuityEngineNode, arte: ARTENode) {
        // ToneKit Node
        let toneKitNode = await collectToneKitNode(modelContext: modelContext)
        
        // TemporalMemory Node
        let temporalMemoryNode = await collectTemporalMemoryNode(modelContext: modelContext)
        
        // ContinuityEngine Node
        let continuityEngineNode = await collectContinuityEngineNode(modelContext: modelContext)
        
        // ARTE Node
        let arteNode = await collectARTENode()
        
        // Cache nodes
        self.toneKitNode = toneKitNode
        self.temporalMemoryNode = temporalMemoryNode
        self.continuityEngineNode = continuityEngineNode
        self.arteNode = arteNode
        
        return (toneKitNode, temporalMemoryNode, continuityEngineNode, arteNode)
    }
    
    private func collectToneKitNode(modelContext: ModelContext) async -> ToneKitNode {
        // Get recent tone predictions and actual tones
        let descriptor = FetchDescriptor<ToneForecastMetrics>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        let recentMetrics = Array((try? modelContext.fetch(descriptor))?.prefix(20) ?? [])
        
        // Calculate tone distribution
        var toneCounts: [AuroraTone: Int] = [:]
        var accurateCount = 0
        for metric in recentMetrics {
            if let tone = metric.predictedToneValue {
                toneCounts[tone, default: 0] += 1
            }
            if metric.wasAccurate {
                accurateCount += 1
            }
        }
        
        let totalCount = recentMetrics.isEmpty ? 1 : recentMetrics.count
        let dominantTone = toneCounts.max(by: { $0.value < $1.value })?.key
        let averageAccuracy = Double(accurateCount) / Double(totalCount)
        
        // Calculate tone distribution weights (normalized)
        var toneDistribution: [AuroraTone: Double] = [:]
        for (tone, count) in toneCounts {
            toneDistribution[tone] = Double(count) / Double(totalCount)
        }
        
        // Calculate volatility (variance in tone distribution)
        let volatility: Double = {
            guard !toneDistribution.isEmpty else { return 0.5 }
            let mean = 1.0 / Double(toneDistribution.count)
            let variance = toneDistribution.values.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(toneDistribution.count)
            return min(1.0, variance * Double(toneDistribution.count))
        }()
        
        return ToneKitNode(
            dominantTone: dominantTone,
            toneDistribution: toneDistribution,
            averageAccuracy: averageAccuracy,
            volatility: volatility
        )
    }
    
    private func collectTemporalMemoryNode(modelContext: ModelContext) async -> TemporalMemoryNode {
        let rollingBaseline = await TemporalEmotionalMemory.shared.rollingAverageBaseline(days: 7, modelContext: modelContext)
        let historicalBaseline = await TemporalEmotionalMemory.shared.historicalBaselineForSimilarPeriod(
            currentDate: Date(),
            lookbackDays: 30,
            modelContext: modelContext
        )
        let momentum = await TemporalEmotionalMemory.shared.forecastEmotionalMomentum(modelContext: modelContext)
        let volatility = await TemporalEmotionalMemory.shared.rollingAverageVolatility(days: 7, modelContext: modelContext)
        
        return TemporalMemoryNode(
            rollingBaseline: rollingBaseline,
            historicalBaseline: historicalBaseline,
            momentum: momentum.momentum,
            volatility: volatility
        )
    }
    
    private func collectContinuityEngineNode(modelContext: ModelContext) async -> ContinuityEngineNode {
        let aecIndex = await EmotionalContinuityEngine.shared.getCurrentAECI(modelContext: modelContext)
        let history = await EmotionalContinuityEngine.shared.calculateWeeklyAECI(modelContext: modelContext)
        
        return ContinuityEngineNode(
            aecIndex: aecIndex,
            stabilityScore: history?.stabilityScore ?? 0.5,
            sentimentMomentum: history?.sentimentMomentum ?? 0.0,
            volatilityScore: history?.volatilityScore ?? 0.5
        )
    }
    
    private func collectARTENode() async -> ARTENode {
        guard let glassSystem = GlassColorSystem.active else {
            return ARTENode(
                emotionalState: .calm,
                intensity: 0.7,
                stability: 0.5
            )
        }
        
        // Estimate ARTE stability from recent state consistency
        // For now, use a simple heuristic based on intensity
        let stability = 1.0 - abs(glassSystem.emotionalIntensity - 0.7) * 0.5
        
        return ARTENode(
            emotionalState: glassSystem.emotionalState,
            intensity: glassSystem.emotionalIntensity,
            stability: stability
        )
    }
    
    // MARK: - Component Score Calculations
    
    /// Calculate tone coherence across subsystems
    private func calculateToneCoherence(nodes: (toneKit: ToneKitNode, temporalMemory: TemporalMemoryNode, continuityEngine: ContinuityEngineNode, arte: ARTENode)) -> Double {
        // Check if tones align across ToneKit, TemporalMemory, and ARTE
        
        // 1. ToneKit dominant tone vs ARTE emotional state
        let toneKitARTECoherence: Double = {
            guard let dominantTone = nodes.toneKit.dominantTone else { return 0.5 }
            let arteTone = AuroraToneKit.tone(for: nodes.arte.emotionalState)
            
            if dominantTone == arteTone {
                return 1.0
            } else if AuroraToneKit.category(for: dominantTone) == AuroraToneKit.category(for: arteTone) {
                return 0.7
            } else {
                return 0.3
            }
        }()
        
        // 2. TemporalMemory baseline vs ContinuityEngine AECI alignment
        let memoryAECICoherence: Double = {
            let baseline = nodes.temporalMemory.rollingBaseline
            let aecIndex = nodes.continuityEngine.aecIndex
            
            // Both positive or both negative = coherent
            if (baseline > 0 && aecIndex > 0) || (baseline < 0 && aecIndex < 0) {
                return 1.0 - abs(baseline - aecIndex) * 0.5
            } else {
                return 0.3
            }
        }()
        
        // 3. ToneKit accuracy (higher = more coherent)
        let accuracyCoherence = nodes.toneKit.averageAccuracy
        
        // Weighted average
        return (toneKitARTECoherence * 0.4) + (memoryAECICoherence * 0.3) + (accuracyCoherence * 0.3)
    }
    
    /// Calculate volatility synchronization across subsystems
    private func calculateVolatilitySync(nodes: (toneKit: ToneKitNode, temporalMemory: TemporalMemoryNode, continuityEngine: ContinuityEngineNode, arte: ARTENode)) -> Double {
        // Check if volatility levels are synchronized
        
        let volatilities = [
            nodes.toneKit.volatility,
            nodes.temporalMemory.volatility,
            nodes.continuityEngine.volatilityScore,
            1.0 - nodes.arte.stability // Invert stability to get volatility
        ]
        
        // Calculate variance in volatilities (lower variance = more synchronized)
        let mean = volatilities.reduce(0.0, +) / Double(volatilities.count)
        let variance = volatilities.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(volatilities.count)
        
        // Convert variance to sync score (lower variance = higher sync)
        return 1.0 - min(1.0, variance * 4.0) // Scale variance to 0-1 range
    }
    
    /// Calculate pacing stability across subsystems
    private func calculatePacingStability(nodes: (toneKit: ToneKitNode, temporalMemory: TemporalMemoryNode, continuityEngine: ContinuityEngineNode, arte: ARTENode)) -> Double {
        // Pacing stability = consistency in emotional expression density
        
        // 1. ARTE intensity stability (more stable = better pacing)
        let arteStability = nodes.arte.stability
        
        // 2. TemporalMemory momentum consistency (lower absolute momentum = more stable)
        let momentumStability = 1.0 - min(1.0, abs(nodes.temporalMemory.momentum))
        
        // 3. ContinuityEngine stability score
        let aecStability = nodes.continuityEngine.stabilityScore
        
        // Weighted average
        return (arteStability * 0.4) + (momentumStability * 0.3) + (aecStability * 0.3)
    }
    
    // MARK: - Self-Balancing Feedback
    
    private func applySelfBalancingFeedback(
        history: ERIHistory,
        nodes: (toneKit: ToneKitNode, temporalMemory: TemporalMemoryNode, continuityEngine: ContinuityEngineNode, arte: ARTENode),
        modelContext: ModelContext
    ) async {
        // If ERI is negative (discord), apply adjustments to resynchronize
        
        guard history.eriIndex < -0.2 else {
            // Positive or neutral ERI - no adjustment needed
            return
        }
        
        logger.info("Applying self-balancing feedback for ERI: \(String(format: "%.2f", history.eriIndex))")
        
        // Determine which component needs adjustment
        let components = [
            ("tone_coherence", history.toneCoherence),
            ("volatility_sync", history.volatilitySync),
            ("pacing_stability", history.pacingStability)
        ]
        
        let weakestComponent = components.min(by: { $0.1 < $1.1 })!
        
        // Apply adjustment based on weakest component
        switch weakestComponent.0 {
        case "tone_coherence":
            // Adjust tone weighting to improve coherence
            history.adjustmentType = "tone_weighting"
            await adjustToneWeightingForCoherence(nodes: nodes, modelContext: modelContext)
            
        case "volatility_sync":
            // Adjust volatility smoothing
            history.adjustmentType = "volatility"
            await adjustVolatilitySmoothing(nodes: nodes, modelContext: modelContext)
            
        case "pacing_stability":
            // Adjust pacing consistency
            history.adjustmentType = "pacing"
            await adjustPacingConsistency(nodes: nodes, modelContext: modelContext)
            
        default:
            break
        }
        
        history.adjustmentApplied = true
    }
    
    private func adjustToneWeightingForCoherence(
        nodes: (toneKit: ToneKitNode, temporalMemory: TemporalMemoryNode, continuityEngine: ContinuityEngineNode, arte: ARTENode),
        modelContext: ModelContext
    ) async {
        // If ToneKit and ARTE are misaligned, bias tone selection toward ARTE's emotional state
        // This is handled implicitly through tone prediction - we can log the adjustment
        logger.info("Tone weighting adjustment: Biasing toward ARTE emotional state (\(nodes.arte.emotionalState.rawValue))")
    }
    
    private func adjustVolatilitySmoothing(
        nodes: (toneKit: ToneKitNode, temporalMemory: TemporalMemoryNode, continuityEngine: ContinuityEngineNode, arte: ARTENode),
        modelContext: ModelContext
    ) async {
        // Volatility smoothing is handled by the subsystems themselves
        // We can log the adjustment for diagnostics
        logger.info("Volatility smoothing adjustment: Target volatility = \(String(format: "%.2f", (nodes.toneKit.volatility + nodes.temporalMemory.volatility + nodes.continuityEngine.volatilityScore) / 3.0))")
    }
    
    private func adjustPacingConsistency(
        nodes: (toneKit: ToneKitNode, temporalMemory: TemporalMemoryNode, continuityEngine: ContinuityEngineNode, arte: ARTENode),
        modelContext: ModelContext
    ) async {
        // Pacing consistency is handled by AECI pacing adjustments
        // We can log the adjustment for diagnostics
        logger.info("Pacing consistency adjustment: Target stability = \(String(format: "%.2f", nodes.arte.stability))")
    }
    
    // MARK: - ERI History
    
    /// Get ERI history (last N entries)
    func getERIHistory(
        limit: Int = 100,
        modelContext: ModelContext
    ) async -> [ERIHistory] {
        var descriptor = FetchDescriptor<ERIHistory>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    /// Get current ERI (from cache or calculate)
    func getCurrentERI(modelContext: ModelContext) async -> Double {
        // Check if cache is fresh (within last 5 minutes)
        if let lastCalc = lastCalculated,
           Date().timeIntervalSince(lastCalc) < 300 {
            return currentERI
        }
        
        // Recalculate
        if let history = await calculateERI(modelContext: modelContext) {
            return history.eriIndex
        }
        
        return 0.0
    }
    
    // MARK: - Encoding/Decoding Node States
    
    private func encodeToneKitState(_ node: ToneKitNode) -> String? {
        let data: [String: Any] = [
            "dominantTone": node.dominantTone?.rawValue ?? "none",
            "averageAccuracy": node.averageAccuracy,
            "volatility": node.volatility
        ]
        return try? JSONSerialization.data(withJSONObject: data).base64EncodedString()
    }
    
    private func encodeTemporalMemoryState(_ node: TemporalMemoryNode) -> String? {
        let data: [String: Any] = [
            "rollingBaseline": node.rollingBaseline,
            "historicalBaseline": node.historicalBaseline,
            "momentum": node.momentum,
            "volatility": node.volatility
        ]
        return try? JSONSerialization.data(withJSONObject: data).base64EncodedString()
    }
    
    private func encodeContinuityEngineState(_ node: ContinuityEngineNode) -> String? {
        let data: [String: Any] = [
            "aecIndex": node.aecIndex,
            "stabilityScore": node.stabilityScore,
            "sentimentMomentum": node.sentimentMomentum,
            "volatilityScore": node.volatilityScore
        ]
        return try? JSONSerialization.data(withJSONObject: data).base64EncodedString()
    }
    
    private func encodeARTEState(_ node: ARTENode) -> String? {
        let data: [String: Any] = [
            "emotionalState": node.emotionalState.rawValue,
            "intensity": node.intensity,
            "stability": node.stability
        ]
        return try? JSONSerialization.data(withJSONObject: data).base64EncodedString()
    }
}

