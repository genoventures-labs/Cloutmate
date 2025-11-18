//
//  ModelTierMap.swift
//  FocusOS
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
            name: "gemma3:1b",
            displayName: "Gemma3",
            capabilities: ["casual", "foreground", "chat"],
            primaryUseCases: ["Casual"],
            tier: 1,
            supportsThinking: false
        ),
        ModelTier(
            name: "qwen3:1.7b",
            displayName: "Qwen3",
            capabilities: ["casual", "tasks", "thinking"],
            primaryUseCases: ["Casual Fallback", "Tasks"],
            tier: 1,
            supportsThinking: true
        ),
        ModelTier(
            name: "qwen3-vl:2b",
            displayName: "Qwen3-VL",
            capabilities: ["vision", "image-processing", "multimodal"],
            primaryUseCases: ["Vision Primary"],
            tier: 2,
            supportsThinking: false
        ),
        ModelTier(
            name: "granite3.2-vision",
            displayName: "Granite3-Vision",
            capabilities: ["vision", "image-processing", "multimodal"],
            primaryUseCases: ["Images"],
            tier: 2,
            supportsThinking: false
        ),
        ModelTier(
            name: "gemma3:4b",
            displayName: "Gemma3",
            capabilities: ["document-analysis", "multimodal", "images"],
            primaryUseCases: ["Documents", "Image Fallback"],
            tier: 2,
            supportsThinking: false
        ),
        ModelTier(
            name: "gwen2.5-coder:1.5b",
            displayName: "Gwen2.5-Coder",
            capabilities: ["coding", "reasoning", "structured-reasoning"],
            primaryUseCases: ["Coding", "Reasoning"],
            tier: 2,
            supportsThinking: true
        ),
        ModelTier(
            name: "deepseek-r1:1.5b",
            displayName: "DeepSeek-R1",
            capabilities: ["research", "document-fallback", "deep-reasoning"],
            primaryUseCases: ["Research", "Document Fallback"],
            tier: 3,
            supportsThinking: true
        ),
        ModelTier(
            name: "granite3.2:2b",
            displayName: "Granite3",
            capabilities: ["background", "summaries", "memory"],
            primaryUseCases: ["Background", "Cognition"],
            tier: 4,
            supportsThinking: false
        )
    ]
    
    private static let backgroundModelName = "granite3.2:2b"
    private static let thinkingModelName = "qwen3:1.7b"
    
    /// Gets model display name for UI (simplified, no version numbers)
    static func displayName(for model: String) -> String {
        if let localModel = localModels.first(where: { $0.name == model }) {
            return localModel.displayName
        }
        if model.lowercased().contains("gemma3") {
            return "Gemma3"
        }
        if model.lowercased().contains("qwen3") || model.lowercased().contains("qwen") {
            return "Qwen3"
        }
        if model.lowercased().contains("gwen2.5") || model.lowercased().contains("gwen2") {
            return "Gwen2.5"
        }
        if model.lowercased().contains("deepseek") {
            return "DeepSeek"
        }
        if model.lowercased().contains("granite") {
            return "Granite3"
        }
        // Handle Gemini for image analysis
        if model.lowercased().contains("gemini") {
            return "Gemini"
        }
        // Handle OpenAI-OSS cloud model
        if model.lowercased().contains("gpt-oss") || model.lowercased().contains("openai") {
            return "OpenAI-OSS"
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
    
    /// Gets default model (casual primary)
    static func defaultModel() -> String {
        return "gemma3:1b"
    }
    
    /// Gets fallback model (casual fallback)
    static func fallbackModel() -> String {
        return "qwen3:1.7b"
    }
    
    /// Gets background inference model (silent reasoning + prep)
    static func backgroundModel() -> String {
        return backgroundModelName
    }
    
    /// Gets casual conversation model (primary)
    static func casualModel() -> String {
        return "gemma3:1b"
    }
    
    /// Gets casual fallback model
    static func casualFallbackModel() -> String {
        return "qwen3:1.7b"
    }
    
    /// Gets task model (with thinking enabled)
    static func taskModel() -> String {
        return "qwen3:1.7b"
    }
    
    /// Gets image processing model (primary)
    /// Note: Image processing is now handled by VisionPipelineService
    static func imageModel() -> String {
        return "qwen3-vl:2b" // Primary vision model
    }
    
    /// Gets image secondary model
    /// Note: Deprecated - ImageAnalysisService handles routing
    static func imageSecondaryModel() -> String {
        return "gemma3:4b"
    }
    
    /// Gets image fallback model
    /// Note: Deprecated - ImageAnalysisService handles routing
    static func imageFallbackModel() -> String {
        return "gemma3:4b"
    }
    
    /// Gets document analysis model (primary)
    static func documentModel() -> String {
        return "gemma3:4b"
    }
    
    /// Gets document fallback model
    static func documentFallbackModel() -> String {
        return "deepseek-r1:1.5b"
    }
    
    /// Gets coding model
    static func codingModel() -> String {
        return "gwen2.5-coder:1.5b"
    }
    
    /// Gets reasoning model (secondary)
    static func reasoningModel() -> String {
        return "gwen2.5-coder:1.5b"
    }
    
    /// Gets research mode models (cloud models)
    static func researchModels() -> [String] {
        return ["deepseek-r1:1.5b", "gpt-oss:20b"]
    }
    
    /// Checks if a model is a local model
    static func isLocalModel(_ model: String) -> Bool {
        return localModels.contains(where: { $0.name == model })
    }
    
    /// Gets all local models with display names for picker
    static func allLocalModelsWithDisplayNames() -> [(name: String, displayName: String)] {
        return localModels.map { (name: $0.name, displayName: $0.displayName) }
    }
    
    /// Gets thinking model (tasks with thinking)
    static func thinkingModel() -> String {
        return thinkingModelName
    }
}

