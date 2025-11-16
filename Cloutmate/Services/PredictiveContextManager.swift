//
//  PredictiveContextManager.swift
//  Cloutmate
//
//  Phase 9: Predictive Reflection Engine
//  Aurora's anticipatory brainstem - predicting derailments and preparing tone + actions before drift happens
//

import Foundation
import SwiftData
import Combine
import os.log
import CloutmateShared

/// Predictive posture modes for flow adaptation
enum PredictivePosture: String, Codable, CaseIterable, Sendable {
    case supportive = "supportive"   // Low energy, low momentum → provide support
    case assertive = "assertive"     // High clarity + high energy → assertive guidance
    case calm = "calm"               // High fatigue but low drift → calm presence
    case strategic = "strategic"     // Task/cluster future risk → strategic planning
    case reflective = "reflective"   // Emotional variance detected → reflective exploration
    
    var displayName: String {
        switch self {
        case .supportive: return "Supportive"
        case .assertive: return "Assertive"
        case .calm: return "Calm"
        case .strategic: return "Strategic"
        case .reflective: return "Reflective"
        }
    }
}

/// Cluster risk profile for predictive adaptation
struct ClusterRiskProfile {
    let clusterName: String
    var driftHistory: [Double] = []        // Historical drift values
    var fatigueHistory: [Double] = []      // Historical fatigue values
    var procrastinationHistory: [Double] = [] // Historical procrastination signals
    var emotionalSpikeHistory: [Double] = []  // Historical emotional variance
    
    var averageDrift: Double {
        guard !driftHistory.isEmpty else { return 0.0 }
        return driftHistory.reduce(0, +) / Double(driftHistory.count)
    }
    
    var averageFatigue: Double {
        guard !fatigueHistory.isEmpty else { return 0.0 }
        return fatigueHistory.reduce(0, +) / Double(fatigueHistory.count)
    }
    
    var riskScore: Double {
        // Combined risk: 0.0 (low) to 1.0 (high)
        let driftRisk = min(averageDrift * 0.4, 0.4)
        let fatigueRisk = min(averageFatigue * 0.3, 0.3)
        let procRisk = (averageProcrastination * 0.2)
        let emotionRisk = (averageEmotionalSpikes * 0.1)
        
        return min(1.0, driftRisk + fatigueRisk + procRisk + emotionRisk)
    }
    
    var averageProcrastination: Double {
        guard !procrastinationHistory.isEmpty else { return 0.0 }
        return procrastinationHistory.reduce(0, +) / Double(procrastinationHistory.count)
    }
    
    var averageEmotionalSpikes: Double {
        guard !emotionalSpikeHistory.isEmpty else { return 0.0 }
        return emotionalSpikeHistory.reduce(0, +) / Double(emotionalSpikeHistory.count)
    }
}

/// Cognitive trajectory from rolling forecast window
struct CognitiveTrajectory {
    var fatigueSlope: Double = 0.0        // Positive = accelerating, negative = recovering
    var focusSlope: Double = 0.0          // Positive = improving, negative = declining
    var momentumSlope: Double = 0.0       // Positive = gaining, negative = losing
    var arteOscillation: Double = 0.0     // 0.0 = monotonic, 1.0 = highly oscillating
    
    var isAccelerating: Bool { fatigueSlope > 0.05 }
    var isRecovering: Bool { fatigueSlope < -0.05 && focusSlope > 0.05 }
    var isCollapsing: Bool { focusSlope < -0.1 && momentumSlope < -0.1 }
    var isTrendingPositive: Bool { momentumSlope > 0.05 && focusSlope > 0.05 }
}

/// Fused predictive state combining multiple signals
struct FusedPredictiveState {
    let fatigueRisk: Double
    let focusStability: Double
    let energyTrend: FocusEnergyTrend
    let recommendedTone: EmotionalState
    let confidence: Double
    let clusterRisk: Double
    let trajectory: CognitiveTrajectory
    let posture: PredictivePosture
    let memoryRelevance: Double
    let shouldTriggerAnticipatoryReply: Bool
}

@MainActor
final class PredictiveContextManager: ObservableObject {
    static let shared = PredictiveContextManager()

    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "PredictiveContextManager")
    private var cancellables = Set<AnyCancellable>()
    private weak var modelContext: ModelContext?
    
    // Trajectory tracking
    private var forecastHistory: [FocusForecast] = []
    private let maxHistorySize = 5
    
    // Cluster awareness
    private var clusterRiskProfiles: [String: ClusterRiskProfile] = [:]
    private var clusterHistory: [String: [Date]] = [:]
    
    // Latest fused state
    @Published private(set) var latestFusedState: FusedPredictiveState?

    private init() {}

    func start(modelContext: ModelContext) async {
        self.modelContext = modelContext
        cancellables.removeAll()

        CognitionPredictor.shared.forecastPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] forecast in
                guard let self else { return }
                Task { @MainActor in
                    await self.handleForecast(forecast)
                }
            }
            .store(in: &cancellables)

        DriftMonitor.shared.driftPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                self?.handleDriftEvent(event)
            }
            .store(in: &cancellables)

        // Subscribe to ARTE state changes for trajectory tracking
        ReactiveThemeManager.shared.emotionalStatePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                // Update trajectory with ARTE state changes
                self?.updateTrajectory()
            }
            .store(in: &cancellables)

        logger.info("Predictive context manager active")
    }

    func stop() {
        cancellables.removeAll()
    }
    
    // MARK: - Enhanced Forecast Handling

    private func handleForecast(_ forecast: FocusForecast) async {
        // Add to history for trajectory tracking
        forecastHistory.append(forecast)
        if forecastHistory.count > maxHistorySize {
            forecastHistory.removeFirst()
        }
        
        // Update trajectory
        updateTrajectory()
        
        // Fuse all predictive signals
        let fusedState = await fusePredictiveSignals(forecast: forecast)
        latestFusedState = fusedState
        
        // Apply cluster-aware predictions
        await applyClusterAwarePredictions(fusedState: fusedState)
        
        // Update tone profile with full context
        updateToneProfile(for: fusedState)
        
        // Update suppression flags
        updateSuppressionFlags(for: fusedState)
        
        // Update posture
        updatePredictivePosture(for: fusedState)
        
        // Check for anticipatory reply trigger
        if fusedState.shouldTriggerAnticipatoryReply {
            await triggerAnticipatoryReply(for: fusedState)
        }
    }
    
    // MARK: - Cluster-Aware Predictions
    
    private func applyClusterAwarePredictions(fusedState: FusedPredictiveState) async {
        guard let context = modelContext else { return }
        
        // Get current intent cluster from ConversationArchive
        let clusterSummary = await ConversationArchive.shared.extractIntentClusters(
            limit: 10,
            modelContext: context
        )
        
        guard let primaryCluster = clusterSummary?.primaryCluster else {
            return
        }
        
        // Update cluster history
        if clusterHistory[primaryCluster] == nil {
            clusterHistory[primaryCluster] = []
        }
        clusterHistory[primaryCluster]?.append(Date())
        // Keep only last 20 entries per cluster
        if let history = clusterHistory[primaryCluster], history.count > 20 {
            clusterHistory[primaryCluster] = Array(history.suffix(20))
        }
        
        // Get or create risk profile
        var profile = clusterRiskProfiles[primaryCluster] ?? ClusterRiskProfile(clusterName: primaryCluster)
        
        // Update risk profile with current drift/fatigue
        profile.driftHistory.append(fusedState.focusStability < 0.5 ? 1.0 - fusedState.focusStability : 0.0)
        profile.fatigueHistory.append(fusedState.fatigueRisk)
        
        // Keep history to last 10 entries
        if profile.driftHistory.count > 10 {
            profile.driftHistory.removeFirst()
        }
        if profile.fatigueHistory.count > 10 {
            profile.fatigueHistory.removeFirst()
        }
        
        clusterRiskProfiles[primaryCluster] = profile
        
        // Apply cluster-based tone weights if risk is high
        if profile.riskScore > 0.6 {
            let recommendedTone = mapClusterRiskToTone(risk: profile.riskScore, cluster: primaryCluster)
            
            var weights = ToneProfileCache.shared.load().toneWeights
            if let currentWeight = weights[recommendedTone] {
                weights[recommendedTone] = min(currentWeight + 0.2, 1.8)
            } else {
                weights[recommendedTone] = 1.3
            }
            
            ToneProfileCache.shared.setToneWeights(weights)
            logger.info("Applied cluster-aware tone adjustment for \(primaryCluster): \(recommendedTone.rawValue)")
        }
        
        // Set nudge preferences based on cluster risk
        if profile.riskScore > 0.7 {
            ToneProfileCache.shared.setSuppressionFlag(false, for: "nudge_suppression_\(primaryCluster)")
        } else {
            ToneProfileCache.shared.setSuppressionFlag(true, for: "nudge_suppression_\(primaryCluster)")
        }
    }
    
    private func mapClusterRiskToTone(risk: Double, cluster: String) -> EmotionalState {
        if risk > 0.8 {
            return .fatigued  // Very high risk → supportive, gentle tone
        } else if risk > 0.6 {
            return .calm      // High risk → calm, stabilizing tone
        } else {
            // Map based on cluster type
            if cluster.contains("Execution") || cluster.contains("Action") {
                return .focused
            } else if cluster.contains("Reflection") || cluster.contains("Learning") {
                return .reflective
            } else {
                return .energized
            }
        }
    }
    
    // MARK: - Cognitive Trajectory Tracking
    
    private func updateTrajectory() {
        guard forecastHistory.count >= 2 else { return }
        
        // Calculate slopes from recent forecasts
        let recent = Array(forecastHistory.suffix(3))
        
        if recent.count >= 2 {
            let fatigueDiff = recent.last!.fatigueRisk - recent.first!.fatigueRisk
            let focusDiff = recent.last!.focusStability - recent.first!.focusStability
            
            // Estimate momentum from focus stability changes
            let momentumDiff = focusDiff * 0.7  // Approximate momentum from focus
            
            // Update trajectory
            // (This would be stored, but for now we calculate on-demand)
        }
    }
    
    private func calculateTrajectory() -> CognitiveTrajectory {
        guard forecastHistory.count >= 2 else {
            return CognitiveTrajectory()
        }
        
        let recent = Array(forecastHistory.suffix(min(5, forecastHistory.count)))
        
        var fatigueSlope = 0.0
        var focusSlope = 0.0
        var momentumSlope = 0.0
        
        if recent.count >= 2 {
            // Simple linear regression slope
            let n = Double(recent.count)
            let xValues = (0..<recent.count).map { Double($0) }
            
            let fatigueValues = recent.map { $0.fatigueRisk }
            let focusValues = recent.map { $0.focusStability }
            
            let avgX = xValues.reduce(0, +) / n
            let avgFatigue = fatigueValues.reduce(0, +) / n
            let avgFocus = focusValues.reduce(0, +) / n
            
            var numeratorFatigue = 0.0
            var numeratorFocus = 0.0
            var denominator = 0.0
            
            for i in 0..<recent.count {
                let xDiff = xValues[i] - avgX
                numeratorFatigue += xDiff * (fatigueValues[i] - avgFatigue)
                numeratorFocus += xDiff * (focusValues[i] - avgFocus)
                denominator += xDiff * xDiff
            }
            
            if denominator > 0 {
                fatigueSlope = numeratorFatigue / denominator
                focusSlope = numeratorFocus / denominator
                momentumSlope = focusSlope * 0.7  // Approximate momentum from focus
            }
        }
        
        // Calculate ARTE oscillation (would need ARTE state history)
        let arteOscillation = 0.0  // Placeholder - would track ARTE state transitions
        
        return CognitiveTrajectory(
            fatigueSlope: fatigueSlope,
            focusSlope: focusSlope,
            momentumSlope: momentumSlope,
            arteOscillation: arteOscillation
        )
    }
    
    // MARK: - MemoryGraph Predictive Relevance
    
    private func getMemoryGraphRelevance(for forecast: FocusForecast) async -> Double {
        guard let context = modelContext,
              AIConfigService.shared.config.featureFlags.memoryGraphEnabled else {
            return 0.5  // Neutral if not available
        }
        
        // Get active themes
        let themeDescriptor = FetchDescriptor<ThemeNode>(
            predicate: #Predicate { theme in
                theme.isActive == true
            }
        )
        let themes = (try? context.fetch(themeDescriptor)) ?? []
        
        // Check if themes indicate predictive relevance
        // Higher salience themes = more predictive relevance
        let avgSalience = themes.isEmpty ? 0.0 : themes.map { $0.salience }.reduce(0, +) / Double(themes.count)
        
        // Map to relevance score
        return min(1.0, avgSalience * 1.2)
    }
    
    // MARK: - Forecast Fusion
    
    private func fusePredictiveSignals(forecast: FocusForecast) async -> FusedPredictiveState {
        // Get trajectory
        let trajectory = calculateTrajectory()
        
        // Get MemoryGraph relevance
        let memoryRelevance = await getMemoryGraphRelevance(for: forecast)
        
        // Get current ARTE state
        let currentArteState = ReactiveThemeManager.shared.currentEmotion()
        
        // Get cluster risk
        let clusterRisk = await getCurrentClusterRisk()
        
        // Determine posture based on all signals
        let posture = determinePosture(
            forecast: forecast,
            trajectory: trajectory,
            clusterRisk: clusterRisk,
            arteState: currentArteState
        )
        
        // Adjust fatigue risk based on trajectory
        let adjustedFatigueRisk = forecast.fatigueRisk + (trajectory.fatigueSlope * 0.3)
        
        // Adjust focus stability based on trajectory
        let adjustedFocusStability = forecast.focusStability + (trajectory.focusSlope * 0.2)
        
        // Determine if anticipatory reply is needed
        let shouldTrigger = shouldTriggerAnticipatoryReply(
            fatigueRisk: adjustedFatigueRisk,
            clusterRisk: clusterRisk,
            trajectory: trajectory
        )
        
        return FusedPredictiveState(
            fatigueRisk: min(max(adjustedFatigueRisk, 0.0), 1.0),
            focusStability: min(max(adjustedFocusStability, 0.0), 1.0),
            energyTrend: forecast.energyTrend,
            recommendedTone: forecast.toneRecommendation,
            confidence: forecast.confidence,
            clusterRisk: clusterRisk,
            trajectory: trajectory,
            posture: posture,
            memoryRelevance: memoryRelevance,
            shouldTriggerAnticipatoryReply: shouldTrigger
        )
    }
    
    private func getCurrentClusterRisk() async -> Double {
        // Get current cluster from ConversationArchive
        guard let context = modelContext else { return 0.0 }
        
        let clusterSummary = await ConversationArchive.shared.extractIntentClusters(
            limit: 5,
            modelContext: context
        )
        
        guard let primaryCluster = clusterSummary?.primaryCluster else {
            return 0.0
        }
        
        return clusterRiskProfiles[primaryCluster]?.riskScore ?? 0.0
    }
    
    private func determinePosture(
        forecast: FocusForecast,
        trajectory: CognitiveTrajectory,
        clusterRisk: Double,
        arteState: EmotionalState
    ) -> PredictivePosture {
        // Supportive: Low energy, low momentum
        if forecast.energyTrend == .declining && trajectory.momentumSlope < -0.05 {
            return .supportive
        }
        
        // Assertive: High clarity + high energy
        if forecast.focusStability > 0.7 && forecast.energyTrend == .rising {
            return .assertive
        }
        
        // Calm: High fatigue but low drift
        if forecast.fatigueRisk > 0.6 && forecast.focusStability > 0.6 {
            return .calm
        }
        
        // Strategic: Task/cluster future risk
        if clusterRisk > 0.6 || trajectory.isAccelerating {
            return .strategic
        }
        
        // Reflective: Emotional variance detected
        if trajectory.arteOscillation > 0.5 || arteState == .reflective {
            return .reflective
        }
        
        // Default based on recommended tone
        switch forecast.toneRecommendation {
        case .focused: return .assertive
        case .reflective: return .reflective
        case .fatigued: return .supportive
        case .calm: return .calm
        case .energized: return .strategic
        }
    }
    
    private func shouldTriggerAnticipatoryReply(
        fatigueRisk: Double,
        clusterRisk: Double,
        trajectory: CognitiveTrajectory
    ) -> Bool {
        // Trigger if risk exceeds thresholds
        if fatigueRisk > 0.75 {
            return true
        }
        
        if clusterRisk > 0.8 {
            return true
        }
        
        if trajectory.isCollapsing {
            return true
        }
        
        return false
    }
    
    // MARK: - Tone Profile Updates
    
    private func updateToneProfile(for fusedState: FusedPredictiveState) {
        guard UserDefaults.standard.bool(forKey: "toneAdaptationEnabled") else {
            logger.debug("Tone adaptation disabled by user settings")
            return
        }
        
        guard fusedState.confidence >= ToneProfileCache.shared.confidenceThreshold else {
            logger.debug("Fused confidence below threshold (\(fusedState.confidence)). Skipping tone adaptation")
            return
        }

        var profile = ToneProfileCache.shared.load()
        var weights = profile.toneWeights

        // Apply tone weights based on fused state
        for state in EmotionalState.allCases {
            let current = weights[state] ?? 1.0
            if state == fusedState.recommendedTone {
                // Boost recommended tone more aggressively if trajectory is positive
                let baseBoost = 0.15 + 0.35 * fusedState.confidence
                let trajectoryBonus = fusedState.trajectory.isTrendingPositive ? 0.1 : 0.0
                let boost = baseBoost + trajectoryBonus
                weights[state] = min(current + boost, 1.8)
            } else {
                weights[state] = max(current * 0.92, 0.6)
            }
        }
        
        // Apply posture-specific adjustments
        applyPostureAdjustments(to: &weights, posture: fusedState.posture)

        ToneProfileCache.shared.setToneWeights(weights)
        logger.info("Tone profile adjusted for \(fusedState.recommendedTone.rawValue) with posture \(fusedState.posture.rawValue)")
    }
    
    private func applyPostureAdjustments(to weights: inout [EmotionalState: Double], posture: PredictivePosture) {
        switch posture {
        case .supportive:
            // Boost calm and reduce energized
            weights[.calm, default: 1.0] = min(weights[.calm, default: 1.0] + 0.15, 1.8)
            weights[.energized, default: 1.0] = max(weights[.energized, default: 1.0] * 0.9, 0.6)
            
        case .assertive:
            // Boost focused and energized
            weights[.focused, default: 1.0] = min(weights[.focused, default: 1.0] + 0.2, 1.8)
            weights[.energized, default: 1.0] = min(weights[.energized, default: 1.0] + 0.1, 1.8)
            
        case .calm:
            // Boost calm, reduce all others slightly
            weights[.calm, default: 1.0] = min(weights[.calm, default: 1.0] + 0.2, 1.8)
            
        case .strategic:
            // Boost focused and reflective
            weights[.focused, default: 1.0] = min(weights[.focused, default: 1.0] + 0.15, 1.8)
            weights[.reflective, default: 1.0] = min(weights[.reflective, default: 1.0] + 0.1, 1.8)
            
        case .reflective:
            // Boost reflective
            weights[.reflective, default: 1.0] = min(weights[.reflective, default: 1.0] + 0.2, 1.8)
        }
    }
    
    private func updatePredictivePosture(for fusedState: FusedPredictiveState) {
        // Store posture in ToneProfileCache (would need to extend it)
        // For now, store in UserDefaults
        UserDefaults.standard.set(fusedState.posture.rawValue, forKey: "PredictivePosture")
    }

    private func updateSuppressionFlags(for fusedState: FusedPredictiveState) {
        // Fatigue suppression
        if fusedState.fatigueRisk > 0.65 {
            ToneProfileCache.shared.setSuppressionFlag(true, for: "fatigue_suppression")
        } else {
            ToneProfileCache.shared.setSuppressionFlag(false, for: "fatigue_suppression")
        }
        
        // Energy conservation
        if fusedState.energyTrend == .declining && fusedState.fatigueRisk > 0.5 {
            ToneProfileCache.shared.setSuppressionFlag(true, for: "energy_conservation")
        } else {
            ToneProfileCache.shared.setSuppressionFlag(false, for: "energy_conservation")
        }
        
        // Posture-based suppressions
        switch fusedState.posture {
        case .supportive:
            ToneProfileCache.shared.setSuppressionFlag(false, for: "nudge_suppression")  // Allow nudges
        case .calm:
            ToneProfileCache.shared.setSuppressionFlag(true, for: "aggressive_nudges")   // Suppress aggressive
        default:
            break
        }
    }
    
    // MARK: - Predictive Flow Gravity
    
    func getFlowGravityAdjustments(for fusedState: FusedPredictiveState) -> FlowGravityAdjustments {
        var adjustments = FlowGravityAdjustments()
        
        // Adjust based on predicted emotional dip
        if fusedState.fatigueRisk > 0.7 {
            adjustments.replyLength = .short
            adjustments.toneSoftness = 0.8
        }
        
        // Adjust based on predicted focus boost
        if fusedState.focusStability > 0.7 && fusedState.energyTrend == .rising {
            adjustments.replyLength = .medium
            adjustments.assertiveness = 0.7
        }
        
        // Adjust based on predicted procrastination
        if fusedState.clusterRisk > 0.7 {
            adjustments.shouldTriggerMicroCommit = true
        }
        
        // Adjust based on predicted cognitive lock
        if fusedState.focusStability < 0.4 && fusedState.fatigueRisk > 0.6 {
            adjustments.shouldTriggerClarifyingQuestion = true
        }
        
        return adjustments
    }
    
    struct FlowGravityAdjustments {
        var replyLength: ReplyLength = .medium
        var toneSoftness: Double = 0.5
        var assertiveness: Double = 0.5
        var shouldTriggerMicroCommit: Bool = false
        var shouldTriggerClarifyingQuestion: Bool = false
        
        enum ReplyLength {
            case short
            case medium
            case long
        }
    }

    // MARK: - Drift Handling with Priming

    private func handleDriftEvent(_ event: DriftEvent) {
        guard let context = modelContext else { return }

        // Prime nudge before delivery
        primeNudge(for: event)
        
        if event.severity > 0.2 {
            triggerProactiveNudge(for: event, modelContext: context)
        }

        if event.driftType == .energy && event.severity > 0.3 {
            ToneProfileCache.shared.setSuppressionFlag(true, for: "energy_conservation")
        }
    }
    
    // MARK: - Pre-Nudge Priming
    
    private func primeNudge(for event: DriftEvent) {
        // Prepare theme transition
        let arteState = ReactiveThemeManager.shared.currentEmotion()
        
        // Adjust gradient tempo based on drift severity
        // (This would integrate with ReactiveThemeManager.prepareTransition if available)
        
        // Set micro-animation tempo
        // Lower severity = slower, gentler animations
        // Higher severity = slightly faster but still gentle
        
        logger.debug("Primed nudge for \(event.driftType.rawValue) drift with severity \(event.severity)")
    }

    private func triggerProactiveNudge(for event: DriftEvent, modelContext: ModelContext) {
        let tone = NudgeToneAdapter.shared.tone(for: .fatiguedState)
        let message: String
        let detail: String

        switch event.driftType {
        case .focus:
            message = "Focus is dipping. Want to reset with a quick ritual?"
            detail = "Progress fell below expectations during your current session."
        case .momentum:
            message = "Momentum is slipping. Ready for a micro-break?"
            detail = "Momentum drift detected—taking a pause could help you recover."
        case .energy:
            message = "Energy trending low. Schedule a recharge?"
            detail = "Energy levels are declining faster than expected."
        }

        SmartNudgeService.shared.deliverPredictiveNudge(
            trigger: .fatiguedState,
            tone: tone,
            message: message,
            detail: detail,
            metadata: [
                "driftSeverity": String(format: "%.2f", event.severity),
                "expected": String(format: "%.2f", event.expectedValue),
                "actual": String(format: "%.2f", event.actualValue)
            ],
            modelContext: modelContext
        )
    }
    
    // MARK: - Anticipatory Replies
    
    private func triggerAnticipatoryReply(for fusedState: FusedPredictiveState) async {
        guard let context = modelContext else { return }
        
        logger.info("Triggering anticipatory reply due to high risk thresholds")
        
        // Determine message based on risk type
        var message: String
        var detail: String
        
        if fusedState.fatigueRisk > 0.75 {
            message = "I'm noticing your energy might dip soon. Want to take a proactive break?"
            detail = "Based on your patterns, a short break now could prevent fatigue later."
        } else if fusedState.clusterRisk > 0.8 {
            message = "This type of work has been challenging for you before. Want some support?"
            detail = "I can help break this down or adjust the approach."
        } else if fusedState.trajectory.isCollapsing {
            message = "Things seem to be getting harder. Let's reset."
            detail = "A quick reset might help you regain momentum."
        } else {
            return  // Don't trigger for other cases
        }
        
        // Insert anticipatory message
        // This would need to integrate with AIAssistantViewModel.insertAnticipatoryMessage()
        // For now, log it
        logger.info("Would insert anticipatory message: \(message)")
        
        // Could also deliver as a nudge if preferred
        let tone = NudgeToneAdapter.shared.tone(for: .fatiguedState)
        SmartNudgeService.shared.deliverPredictiveNudge(
            trigger: .fatiguedState,
            tone: tone,
            message: message,
            detail: detail,
            metadata: [
                "type": "anticipatory",
                "fatigueRisk": String(format: "%.2f", fusedState.fatigueRisk),
                "clusterRisk": String(format: "%.2f", fusedState.clusterRisk)
            ],
            modelContext: context
        )
    }
    
    // MARK: - Public API
    
    /// Get current predictive posture
    func getCurrentPosture() -> PredictivePosture {
        if let raw = UserDefaults.standard.string(forKey: "PredictivePosture"),
           let posture = PredictivePosture(rawValue: raw) {
            return posture
        }
        return .calm  // Default
    }
    
    /// Get flow gravity adjustments for current state
    func getCurrentFlowGravityAdjustments() -> FlowGravityAdjustments {
        guard let fusedState = latestFusedState else {
            return FlowGravityAdjustments()
        }
        return getFlowGravityAdjustments(for: fusedState)
    }
    
    /// Get cluster risk for a specific cluster
    func getClusterRisk(for clusterName: String) -> Double {
        return clusterRiskProfiles[clusterName]?.riskScore ?? 0.0
    }
}
