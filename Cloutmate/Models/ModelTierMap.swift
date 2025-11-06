//
//  ModelTierMap.swift
//  Cloutmate
//
//  Model tier definitions and intent cluster mappings for Aurora's hybrid routing
//

import Foundation

/// Represents a cloud model tier with its capabilities
struct ModelTier: Sendable {
    let name: String
    let displayName: String
    let capabilities: [String]
    let primaryUseCases: [String]
    let tier: Int // Lower = more capable/heavier, higher = lighter/faster
}

/// Maps intent clusters to preferred model routes
enum ModelTierMap {
    // Cloud model definitions
    static let cloudModels: [ModelTier] = [
        ModelTier(
            name: "deepseek-v3.1:671b-cloud",
            displayName: "DeepSeek v3.1 (671B)",
            capabilities: ["analytical", "reasoning", "deep-reflection", "forecasting", "diagnostics"],
            primaryUseCases: ["Reflection", "Execution"],
            tier: 1
        ),
        ModelTier(
            name: "gpt-oss:20b-cloud",
            displayName: "GPT-OSS (20B)",
            capabilities: ["lightweight", "general-chat", "quick-responses", "short-reasoning"],
            primaryUseCases: ["Execution", "quick-tasks"],
            tier: 3
        ),
        ModelTier(
            name: "gpt-oss:120b-cloud",
            displayName: "GPT-OSS (120B)",
            capabilities: ["long-context", "creative-planning", "emotional-tone", "system-orchestration"],
            primaryUseCases: ["Orchestration"],
            tier: 2
        ),
        ModelTier(
            name: "kimi-k2:1t-cloud",
            displayName: "Kimi K2 (1T)",
            capabilities: ["heavy-creative", "summarization", "multi-document", "long-form"],
            primaryUseCases: ["Creative"],
            tier: 1
        ),
        ModelTier(
            name: "qwen3-coder:480b-cloud",
            displayName: "Qwen3 Coder (480B)",
            capabilities: ["code-generation", "automation", "cursor-adjacent"],
            primaryUseCases: ["Coding"],
            tier: 2
        ),
        ModelTier(
            name: "glm-4.6:cloud",
            displayName: "GLM-4.6",
            capabilities: ["structured-reasoning", "logic-validation", "math-heavy"],
            primaryUseCases: ["Reflection"],
            tier: 2
        ),
        ModelTier(
            name: "minimax-m2:cloud",
            displayName: "MiniMax M2",
            capabilities: ["fallback", "conversational", "low-latency", "background-nudges"],
            primaryUseCases: ["lightweight-chats", "rituals"],
            tier: 4
        )
    ]
    
    /// Maps intent cluster name to preferred cloud model(s)
    /// Returns array of models in order of preference (first is primary)
    static func modelsForIntentCluster(_ clusterName: String?) -> [String] {
        guard let clusterName = clusterName else {
            return ["gpt-oss:20b-cloud"] // Default fallback
        }
        
        let normalized = clusterName.lowercased()
        
        switch normalized {
        case let name where name.contains("creative") || name.contains("brainstorming"):
            return ["kimi-k2:1t-cloud", "gpt-oss:120b-cloud"]
            
        case let name where name.contains("execution") || name.contains("action"):
            return ["deepseek-v3.1:671b-cloud", "gpt-oss:20b-cloud"]
            
        case let name where name.contains("reflection") || name.contains("learning"):
            return ["deepseek-v3.1:671b-cloud", "glm-4.6:cloud"]
            
        case let name where name.contains("orchestration") || name.contains("planning"):
            return ["gpt-oss:120b-cloud", "deepseek-v3.1:671b-cloud"]
            
        case let name where name.contains("coding") || name.contains("code"):
            return ["qwen3-coder:480b-cloud", "deepseek-v3.1:671b-cloud"]
            
        case let name where name.contains("empathy") || name.contains("support"):
            return ["gpt-oss:20b-cloud", "minimax-m2:cloud"]
            
        default:
            return ["gpt-oss:20b-cloud", "minimax-m2:cloud"]
        }
    }
    
    /// Gets the next higher tier model for escalation
    static func escalateModel(_ currentModel: String) -> String? {
        guard let currentTier = cloudModels.first(where: { $0.name == currentModel })?.tier else {
            return nil
        }
        
        // Find models with lower tier number (more capable)
        let betterModels = cloudModels.filter { $0.tier < currentTier }
            .sorted { $0.tier < $1.tier }
        
        return betterModels.first?.name
    }
    
    /// Gets a faster/lighter model for resource optimization
    static func optimizeModel(_ currentModel: String) -> String? {
        guard let currentTier = cloudModels.first(where: { $0.name == currentModel })?.tier else {
            return nil
        }
        
        // Find models with higher tier number (lighter/faster)
        let lighterModels = cloudModels.filter { $0.tier > currentTier }
            .sorted { $0.tier < $1.tier }
        
        return lighterModels.first?.name
    }
    
    /// Gets model display name for UI
    static func displayName(for model: String) -> String {
        return cloudModels.first(where: { $0.name == model })?.displayName ?? model
    }
    
    /// Checks if a model is a cloud model
    static func isCloudModel(_ model: String) -> Bool {
        return cloudModels.contains(where: { $0.name == model })
    }
    
    /// Gets all available cloud model names
    static func allCloudModels() -> [String] {
        return cloudModels.map { $0.name }
    }
    
    /// Gets all cloud models with display names for picker
    static func allCloudModelsWithDisplayNames() -> [(name: String, displayName: String)] {
        return cloudModels.map { (name: $0.name, displayName: $0.displayName) }
    }
}

