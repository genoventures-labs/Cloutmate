//
//  ModelRoutingEngine.swift
//  Cloutmate
//
//  Routing logic engine with confidence weighting, casual detection, and per-model cooldown/stickiness
//

import Foundation
import SwiftData

struct ModelRoutingDecision {
    let model: String
    let useThinking: Bool
    let isCasual: Bool
}

actor ModelRoutingEngine {
    static let shared = ModelRoutingEngine()
    
    // Cache last-used model per intent cluster
    private var clusterModelCache: [String: String] = [:]
    
    // Per-model cooldown/stickiness tracking
    // Tracks: model name -> remaining turns (2-3 turns of stickiness)
    private var modelCooldown: [String: Int] = [:]
    private let cooldownTurns = 3 // Keep same model for 3 turns after usage
    
    private init() {}
    
    /// Selects the best model for a given input with casual detection and cooldown
    func selectModel(
        input: String,
        intentCluster: String?,
        confidence: Double,
        messageLength: Int,
        userStyle: TypingStyle?,
        conversationId: UUID?
    ) async -> ModelRoutingDecision {
        // Determine if this is casual
        let isCasual = await CasualConversationDetector.shared.isCasual(
            input: input,
            intentCluster: intentCluster,
            messageLength: messageLength,
            userStyle: userStyle
        )
        
        // Check for active cooldown first (model stickiness)
        for (model, remainingTurns) in modelCooldown where remainingTurns > 0 {
            // If a model has active cooldown, use it (maintains continuity)
            let isShortQuery = messageLength < 80
            let useThinking = ModelTierMap.supportsThinking(model) && !isCasual && !isShortQuery
            return ModelRoutingDecision(
                model: model,
                useThinking: useThinking,
                isCasual: isCasual
            )
        }
        
        // No active cooldown - determine model based on conversation type
        let selectedModel: String
        let useThinking: Bool
        
        // Disable thinking for short, casual queries (< 80 chars)
        let isShortQuery = messageLength < 80
        
        if isCasual || isShortQuery {
            selectedModel = ModelTierMap.defaultModel()
            useThinking = false
        } else {
            selectedModel = ModelTierMap.thinkingModel()
            useThinking = true
        }
        
        // Activate cooldown for selected model
        activateCooldown(for: selectedModel)
        
        return ModelRoutingDecision(
            model: selectedModel,
            useThinking: useThinking,
            isCasual: isCasual
        )
    }
    
    /// Activates cooldown/stickiness for a model
    private func activateCooldown(for model: String) {
        modelCooldown[model] = cooldownTurns
        
        // Decrement other models' cooldowns
        for (key, value) in modelCooldown where key != model {
            modelCooldown[key] = max(0, value - 1)
        }
        
        // Clean up expired cooldowns
        modelCooldown = modelCooldown.filter { $0.value > 0 }
    }
    
    /// Records model usage (called after successful response)
    func recordModelUsage(_ model: String) {
        // Ensure cooldown is active
        activateCooldown(for: model)
    }
    
    /// Clears cooldown (called when conversation ends or topic changes significantly)
    func clearCooldown() {
        modelCooldown.removeAll()
    }
    
    /// Clears cache (called on app restart or model availability changes)
    func clearCache() {
        clusterModelCache.removeAll()
        modelCooldown.removeAll()
    }
    
    /// Clears cache for a specific intent cluster
    func clearCache(for intentCluster: String) {
        clusterModelCache.removeValue(forKey: intentCluster)
    }
}
