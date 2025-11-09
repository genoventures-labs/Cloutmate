//
//  ModelRoutingEngine.swift
//  Cloutmate
//
//  Routing logic engine with confidence weighting, casual detection, and per-model cooldown/stickiness
//

import Foundation
import SwiftData

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
    ) async -> (model: String, useThinking: Bool) {
        // First, determine if this is casual or needs deep reasoning
        let isCasual = await CasualConversationDetector.shared.isCasual(
            input: input,
            intentCluster: intentCluster,
            messageLength: messageLength,
            userStyle: userStyle
        )
        
        let needsDeepReasoning = await CasualConversationDetector.shared.requiresDeepReasoning(
            input: input,
            intentCluster: intentCluster,
            messageLength: messageLength,
            confidence: confidence
        )
        
        // Check for active cooldown, but ONLY if it's appropriate for the conversation type
        for (model, remainingTurns) in modelCooldown where remainingTurns > 0 {
            // Don't use deepseek cooldown for casual conversations
            if model == ModelTierMap.deepReasoningModel() && (isCasual || messageLength < 80) {
                continue // Skip deepseek cooldown for casual/short queries
            }
            
            // Don't use default model cooldown for deep reasoning tasks
            if model == ModelTierMap.defaultModel() && needsDeepReasoning {
                continue // Skip default model cooldown for deep reasoning
            }
            
            // If cooldown model matches the conversation type, use it
            let isShortQuery = messageLength < 80
            let useThinking = ModelTierMap.supportsThinking(model) && !isCasual && !isShortQuery && !needsDeepReasoning
            return (model, useThinking)
        }
        
        // No active cooldown or cooldown doesn't match conversation type - determine model based on conversation type
        let selectedModel: String
        let useThinking: Bool
        
        // Disable thinking for short, casual queries (< 80 chars)
        let isShortQuery = messageLength < 80
        
        if needsDeepReasoning {
            // Deep reasoning → DeepSeek
            selectedModel = ModelTierMap.deepReasoningModel()
            useThinking = true
        } else if isCasual || isShortQuery {
            // Casual or short → Qwen3, no thinking
            selectedModel = ModelTierMap.defaultModel()
            useThinking = false
        } else {
            // Non-casual → Qwen3 with thinking
            selectedModel = ModelTierMap.defaultModel()
            useThinking = true
        }
        
        // Activate cooldown for selected model
        activateCooldown(for: selectedModel)
        
        return (selectedModel, useThinking)
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
