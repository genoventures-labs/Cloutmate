//
//  ModelTierMap.swift
//  Cloutmate
//
//  Model tier definitions and intent cluster mappings for Aurora's local routing
//

import Foundation

/// Represents a local model tier with its capabilities
struct ModelTier: Sendable {
    let name: String
    let displayName: String
    let capabilities: [String]
    let primaryUseCases: [String]
    let tier: Int // Lower = more capable/heavier, higher = lighter/faster
    let supportsThinking: Bool // Whether model supports thinking mode
}

/// Maps intent clusters to preferred model routes
enum ModelTierMap {
    // Local model definitions
    static let localModels: [ModelTier] = [
        ModelTier(
            name: "gemma3:4b",
            displayName: "Gemma3",
            capabilities: ["multimodal", "foreground", "chat"],
            primaryUseCases: ["Casual", "General", "Images"],
            tier: 1,
            supportsThinking: false
        ),
        ModelTier(
            name: "gwen3:8b",
            displayName: "Gwen3",
            capabilities: ["structured-reasoning", "chain-of-thought", "deep-analysis"],
            primaryUseCases: ["Planning", "Reasoning"],
            tier: 2,
            supportsThinking: true
        ),
        ModelTier(
            name: "granite3.2:2b",
            displayName: "Granite3",
            capabilities: ["background", "summaries", "memory"],
            primaryUseCases: ["Background", "Cognition"],
            tier: 3,
            supportsThinking: false
        )
    ]
    
    private static let backgroundModelName = "granite3.2:2b"
    private static let thinkingModelName = "gwen3:8b"
    
    /// Gets model display name for UI (simplified, no version numbers)
    static func displayName(for model: String) -> String {
        if let localModel = localModels.first(where: { $0.name == model }) {
            return localModel.displayName
        }
        if model.lowercased().contains("gemma3") {
            return "Gemma3"
        }
        if model.lowercased().contains("gwen3") {
            return "Gwen3"
        }
        // Handle Gemini for image analysis
        if model.lowercased().contains("gemini") {
            return "Gemini"
        }
        // Fallback: extract base name
        let components = model.components(separatedBy: ":")
        if let baseName = components.first {
            return baseName.capitalized
        }
        return model
    }
    
    /// Checks if a model supports thinking mode
    static func supportsThinking(_ model: String) -> Bool {
        return localModels.first(where: { $0.name == model })?.supportsThinking ?? false
    }
    
    /// Gets all local model names
    static func allLocalModels() -> [String] {
        return localModels.map { $0.name }
    }
    
    /// Gets default model (qwen3:1.7b)
    static func defaultModel() -> String {
        return "gemma3:4b"
    }
    
    /// Gets fallback model
    static func fallbackModel() -> String {
        return "granite3.2:2b"
    }
    
    /// Gets background inference model (silent reasoning + prep)
    static func backgroundModel() -> String {
        return backgroundModelName
    }
    
    /// Checks if a model is a local model
    static func isLocalModel(_ model: String) -> Bool {
        return localModels.contains(where: { $0.name == model })
    }
    
    /// Gets all local models with display names for picker
    static func allLocalModelsWithDisplayNames() -> [(name: String, displayName: String)] {
        return localModels.map { (name: $0.name, displayName: $0.displayName) }
    }
    
    static func thinkingModel() -> String {
        return thinkingModelName
    }
}

