//
//  AIFlowCompanion.swift
//  Cloutmate
//
//  AI Flow Companion - "Clarity Coach" personality mode
//  Provides structured nudges, clarifying questions, and insight summaries
//

import Foundation
import SwiftData
import Combine
import os.log

@MainActor
final class AIFlowCompanion: ObservableObject {
    static let shared = AIFlowCompanion()
    
    @Published private(set) var latestInsight: String?
    @Published private(set) var isActive: Bool = false
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "AIFlowCompanion")
    private var cancellables = Set<AnyCancellable>()
    private var latestMomentum: MomentumMetrics?
    private var currentEmotionalState: EmotionalState = .calm
    private var companionState: FlowCompanionState?
    private var isRunning = false
    private weak var currentModelContext: ModelContext?
    
    private init() {}
    
    // MARK: - Lifecycle
    
    func start(modelContext: ModelContext) {
        guard !isRunning else { return }
        isRunning = true
        logger.info("Starting AI Flow Companion")
        
        currentModelContext = modelContext
        loadCompanionState(modelContext: modelContext)
        observeMomentum()
        observeEmotionalState()
        observeRitualCompletions(modelContext: modelContext)
        observeFocusSessions(modelContext: modelContext)
    }
    
    func stop() {
        cancellables.removeAll()
        isRunning = false
        isActive = false
        currentModelContext = nil
        logger.info("Stopped AI Flow Companion")
    }
    
    // MARK: - Observation
    
    private func observeMomentum() {
        DriftMonitor.shared.momentumPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] metrics in
                self?.latestMomentum = metrics
                self?.evaluateMomentumInsights()
            }
            .store(in: &cancellables)
    }
    
    private func observeEmotionalState() {
        ReactiveThemeManager.shared.emotionalStatePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.currentEmotionalState = state
            }
            .store(in: &cancellables)
    }
    
    private func observeRitualCompletions(modelContext: ModelContext) {
        // Observe ritual completion events
        NotificationCenter.default.publisher(for: NSNotification.Name("RitualCompleted"))
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                if let completion = notification.object as? RitualCompletion {
                    self?.handleRitualCompletion(completion, modelContext: modelContext)
                }
            }
            .store(in: &cancellables)
    }
    
    private func observeFocusSessions(modelContext: ModelContext) {
        NotificationCenter.default.publisher(for: NSNotification.Name("FocusSessionCompleted"))
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                if let session = notification.object as? FocusSession {
                    self?.handleFocusSessionCompletion(session, modelContext: modelContext)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Insight Generation
    
    func generateInsight(
        context: FlowCompanionContext,
        modelContext: ModelContext
    ) async -> String? {
        guard let state = companionState else { return nil }
        
        let prompt = buildInsightPrompt(context: context, personality: state.personality)
        
        do {
            let systemPrompt = buildSystemPrompt(personality: state.personality)
            let fullPrompt = "\(systemPrompt)\n\n\(prompt)"
            let response = try await OllamaBridgeService.shared.generateResponse(
                for: fullPrompt,
                context: ""
            )
            
            let insight = parseInsight(from: response)
            latestInsight = insight
            state.recordInteraction(summary: insight)
            saveContext(modelContext)
            
            return insight
        } catch {
            logger.error("Failed to generate insight: \(error.localizedDescription)")
            return nil
        }
    }
    
    func deliverNudge(
        trigger: FlowCompanionTrigger,
        modelContext: ModelContext
    ) {
        guard let state = companionState else { return }
        
        let message = generateNudgeMessage(trigger: trigger, context: buildCurrentContext())
        let detail = generateNudgeDetail(trigger: trigger)
        
        SmartNudgeService.shared.deliverFlowCompanionNudge(
            trigger: trigger,
            message: message,
            detail: detail,
            personality: state.personality,
            modelContext: modelContext
        )
        
        state.recordInteraction(summary: "Nudge delivered: \(trigger.rawValue)")
        saveContext(modelContext)
    }
    
    // MARK: - Evaluation
    
    private func evaluateMomentumInsights() {
        guard let momentum = latestMomentum else { return }
        
        // Generate insights based on momentum changes
        if momentum.flowState == .highFlow && momentum.streakDays >= 3 {
            let context = FlowCompanionContext(
                momentum: momentum,
                emotionalState: currentEmotionalState,
                activeFocusSession: nil,
                recentRitualCompletion: nil
            )
            
            // Generate insights when momentum changes significantly
            if momentum.flowState == .highFlow && momentum.streakDays >= 3 {
                let context = FlowCompanionContext(
                    momentum: momentum,
                    emotionalState: currentEmotionalState,
                    activeFocusSession: nil,
                    recentRitualCompletion: nil
                )
                
                // Only generate if we have modelContext
                if let modelContext = currentModelContext {
                    Task {
                        if let insight = await generateInsight(context: context, modelContext: modelContext) {
                            logger.info("Generated momentum insight: \(insight)")
                        }
                    }
                }
            }
        }
    }
    
    private func handleRitualCompletion(_ completion: RitualCompletion, modelContext: ModelContext) {
        let context = FlowCompanionContext(
            momentum: latestMomentum,
            emotionalState: currentEmotionalState,
            activeFocusSession: nil,
            recentRitualCompletion: completion
        )
        
        Task {
            if let insight = await generateInsight(context: context, modelContext: modelContext) {
                logger.info("Generated ritual completion insight: \(insight)")
            }
        }
    }
    
    private func handleFocusSessionCompletion(_ session: FocusSession, modelContext: ModelContext) {
        let context = FlowCompanionContext(
            momentum: latestMomentum,
            emotionalState: currentEmotionalState,
            activeFocusSession: session,
            recentRitualCompletion: nil
        )
        
        Task {
            if let insight = await generateInsight(context: context, modelContext: modelContext) {
                logger.info("Generated focus session insight: \(insight)")
            }
        }
    }
    
    // MARK: - Message Generation
    
    private func generateNudgeMessage(
        trigger: FlowCompanionTrigger,
        context: FlowCompanionContext
    ) -> String {
        switch trigger {
        case .deferredHighImpactItems:
            return "You've been deferring high-impact items lately. Want to revisit your Focus Rituals?"
        case .strongMomentum:
            if let momentum = context.momentum, momentum.streakDays >= 3 {
                return "You're \(momentum.streakDays)-for-\(momentum.streakDays) this week on Deep Work sessions. Momentum looks strong—let's add one Creative block tomorrow."
            }
            return "Your momentum is building. Consider adding a creative focus block to maintain variety."
        case .focusDrift:
            return "I notice you're switching contexts frequently. Want to lock in a focus session?"
        case .fatigueRisk:
            return "Your energy patterns suggest a break might help. Consider a short recovery ritual."
        case .reflectionOpportunity:
            return "You've completed several focus sessions. Want to reflect on what's working?"
        }
    }
    
    private func generateNudgeDetail(trigger: FlowCompanionTrigger) -> String? {
        switch trigger {
        case .deferredHighImpactItems:
            return "Review your top priorities and commit to tackling one today."
        case .strongMomentum:
            return "Adding variety prevents burnout while maintaining flow."
        case .focusDrift:
            return "A focused session can help you regain momentum."
        case .fatigueRisk:
            return "Recovery rituals help maintain long-term productivity."
        case .reflectionOpportunity:
            return "Reflection helps identify patterns and optimize your approach."
        }
    }
    
    // MARK: - Prompt Building
    
    private func buildSystemPrompt(personality: FlowCompanionPersonality) -> String {
        switch personality {
        case .clarityCoach:
            return """
            You are a Clarity Coach—a structured, thoughtful guide who helps users maintain focus and clarity.
            You provide:
            - Structured nudges (not motivational fluff)
            - Clarifying questions during focus sessions
            - Insight summaries based on momentum and emotional state
            
            Your tone is:
            - Direct but supportive
            - Action-oriented
            - Evidence-based
            - Never preachy or overly motivational
            
            Keep responses concise (1-2 sentences max for nudges, 2-3 sentences for insights).
            """
        case .momentumGuide:
            return """
            You are a Momentum Guide—focused on helping users maintain and build productive momentum.
            You identify patterns, celebrate progress, and suggest optimizations.
            """
        case .reflectionPartner:
            return """
            You are a Reflection Partner—helping users understand their patterns and make meaning from their work.
            You ask thoughtful questions and help synthesize insights.
            """
        }
    }
    
    private func buildInsightPrompt(
        context: FlowCompanionContext,
        personality: FlowCompanionPersonality
    ) -> String {
        var prompt = "Generate a brief insight based on the following context:\n\n"
        
        if let momentum = context.momentum {
            prompt += "Momentum: \(momentum.streakDays) day streak, \(String(format: "%.1f", momentum.completionVelocity)) completion velocity, \(momentum.flowState.rawValue) flow state\n"
        }
        
        prompt += "Emotional State: \(context.emotionalState.rawValue)\n"
        
        if let session = context.activeFocusSession {
            prompt += "Active Focus Session: \(session.objective)\n"
        }
        
        if let ritual = context.recentRitualCompletion {
            prompt += "Recent Ritual: \(ritual.ritualType.rawValue) completed\n"
        }
        
        prompt += "\nGenerate a concise, actionable insight (2-3 sentences max) that helps the user understand their current state and suggests a next step."
        
        return prompt
    }
    
    private func parseInsight(from response: String) -> String {
        // Clean up the response, remove any markdown formatting
        let cleaned = response
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Take first 2-3 sentences
        let sentences = cleaned.components(separatedBy: ". ")
        if sentences.count >= 2 {
            return sentences.prefix(3).joined(separator: ". ") + "."
        }
        
        return cleaned
    }
    
    // MARK: - Context Building
    
    private func buildCurrentContext() -> FlowCompanionContext {
        return FlowCompanionContext(
            momentum: latestMomentum,
            emotionalState: currentEmotionalState,
            activeFocusSession: nil,
            recentRitualCompletion: nil
        )
    }
    
    // MARK: - State Management
    
    private func loadCompanionState(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<FlowCompanionState>()
        if let state = try? modelContext.fetch(descriptor).first {
            companionState = state
        } else {
            // Create new state
            let newState = FlowCompanionState()
            modelContext.insert(newState)
            companionState = newState
            saveContext(modelContext)
        }
    }
    
    private func saveContext(_ modelContext: ModelContext) {
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save companion state: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types

enum FlowCompanionTrigger: String, Codable {
    case deferredHighImpactItems
    case strongMomentum
    case focusDrift
    case fatigueRisk
    case reflectionOpportunity
}

struct FlowCompanionContext {
    let momentum: MomentumMetrics?
    let emotionalState: EmotionalState
    let activeFocusSession: FocusSession?
    let recentRitualCompletion: RitualCompletion?
}

