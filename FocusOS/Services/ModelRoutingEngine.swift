//
//  ModelRoutingEngine.swift
//  FocusOS
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
    
    // Debug mode flag (enable verbose routing logs)
    private var debugMode: Bool {
        #if DEBUG
        return true
        #else
        return UserDefaults.standard.bool(forKey: "com.kosmicapps.focusos.debugMode")
        #endif
    }
    
    private init() {}
    
    /// Selects the best model for a given input with casual detection and cooldown
    /// Priority order: Research mode → Image/document mode → Cluster memory → Cooldown → Casual/task detection → Universal fallback
    func selectModel(
        input: String,
        intentCluster: String?,
        confidence: Double,
        messageLength: Int,
        userStyle: TypingStyle?,
        conversationId: UUID?,
        isResearchMode: Bool = false,
        retryModeActive: Bool = false,
        previousDecision: ModelRoutingDecision? = nil,
        isCreationAction: Bool = false
    ) async -> ModelRoutingDecision {
        if retryModeActive, let previousDecision {
            if debugMode {
                print("[ModelRoutingEngine] [RETRY] Reusing model \(previousDecision.model)")
            }
            return previousDecision
        }

        // 1. Research mode - only use DeepSeek/OpenAI-OSS models (highest priority)
        if isResearchMode {
            let researchModels = ModelTierMap.researchModels()
            let selectedModel = researchModels.first ?? ModelTierMap.defaultModel() // Fallback to gemma3:1b if research models unavailable
            
            if debugMode {
                print("[ModelRoutingEngine] [RESEARCH MODE] Selected: \(selectedModel) for input length: \(messageLength)")
            }
            
            activateCooldown(for: selectedModel)
            
            return ModelRoutingDecision(
                model: selectedModel,
                useThinking: ModelTierMap.supportsThinking(selectedModel),
                isCasual: false
            )
        }

        if isCreationAction {
            let creationModel = "qwen3:1.7b"
            if debugMode {
                print("[ModelRoutingEngine] [CREATION] Forcing \(creationModel) with thinking")
            }
            activateCooldown(for: creationModel)
            return ModelRoutingDecision(
                model: creationModel,
                useThinking: true,
                isCasual: false
            )
        }
        
        // 2. Determine if this is casual (with imperative verb override)
        let isCasual = await CasualConversationDetector.shared.isCasual(
            input: input,
            intentCluster: intentCluster,
            messageLength: messageLength,
            userStyle: userStyle
        )
        
        // Check for imperative verbs (short commands that are NOT casual)
        let hasImperativeVerb = hasImperativeCommand(input: input, messageLength: messageLength)
        let actualIsCasual = isCasual && !hasImperativeVerb
        
        // 3. Cluster memory - remember preferred model for this topic (before cooldown)
        if let cluster = intentCluster, let cachedModel = clusterModelCache[cluster] {
            // Validate cached model still exists
            if ModelTierMap.allLocalModels().contains(cachedModel) {
                // Skip research models for non-research requests
                let isResearchModel = cachedModel.contains("deepseek") || cachedModel.contains("gpt-oss")
                if !isResearchModel {
                    let useThinking = ModelTierMap.supportsThinking(cachedModel) && !actualIsCasual
                    
                    if debugMode {
                        print("[ModelRoutingEngine] [CLUSTER MEMORY] Using cached model: \(cachedModel) for cluster: \(cluster)")
                    }
                    
                    activateCooldown(for: cachedModel)
                    
                    return ModelRoutingDecision(
                        model: cachedModel,
                        useThinking: useThinking,
                        isCasual: actualIsCasual
                    )
                }
            }
        }
        
        // 4. Cooldown/stickiness (model continuity)
        for (model, remainingTurns) in modelCooldown where remainingTurns > 0 {
            // Skip research models (deepseek, gpt-oss) for non-research requests
            let isResearchModel = model.contains("deepseek") || model.contains("gpt-oss")
            if isResearchModel {
                continue // Skip research models when not in research mode
            }
            
            // If a model has active cooldown, use it (maintains continuity)
            let useThinking = ModelTierMap.supportsThinking(model) && !actualIsCasual
            
            if debugMode {
                print("[ModelRoutingEngine] [COOLDOWN] Using: \(model) (remaining: \(remainingTurns)), casual: \(actualIsCasual), thinking: \(useThinking)")
            }
            
            return ModelRoutingDecision(
                model: model,
                useThinking: useThinking,
                isCasual: actualIsCasual
            )
        }
        
        // 5. Casual/task model detection (with reasoning trigger)
        let selectedModel: String
        let useThinking: Bool
        
        if actualIsCasual {
            selectedModel = ModelTierMap.casualModel()
            useThinking = false
        } else {
            // Check for coding/reasoning/analysis tasks (expanded trigger set)
            let isReasoningTask = isReasoningOrAnalysisTask(input: input)
            
            if isReasoningTask {
                selectedModel = ModelTierMap.codingModel() // gwen2.5-coder:1.5b for reasoning
                useThinking = true
            } else {
                selectedModel = ModelTierMap.taskModel() // qwen3:1.7b
                useThinking = true
            }
        }
        
        // 6. Universal fallback: If all else fails, default to gemma3:1b as global safe fallback
        // Validate model exists in our tier map
        let validatedModel = ModelTierMap.allLocalModels().contains(selectedModel) ? selectedModel : ModelTierMap.defaultModel()
        
        // Store in cluster cache for future use (if we have a cluster)
        if let cluster = intentCluster {
            clusterModelCache[cluster] = validatedModel
            if debugMode {
                print("[ModelRoutingEngine] [CLUSTER CACHE] Stored model: \(validatedModel) for cluster: \(cluster)")
            }
        }
        
        if debugMode {
            if validatedModel != selectedModel {
                print("[ModelRoutingEngine] [FALLBACK] Invalid model \(selectedModel), using universal fallback: \(validatedModel)")
            }
            print("[ModelRoutingEngine] [ROUTING] Selected: \(validatedModel), casual: \(actualIsCasual), thinking: \(useThinking), input length: \(messageLength)")
        }
        
        // Activate cooldown for validated model
        activateCooldown(for: validatedModel)
        
        return ModelRoutingDecision(
            model: validatedModel,
            useThinking: useThinking,
            isCasual: actualIsCasual
        )
    }
    
    /// Checks if input contains imperative verbs (short commands that should NOT be treated as casual)
    private func hasImperativeCommand(input: String, messageLength: Int) -> Bool {
        // Only check short messages (longer messages are less likely to be pure commands)
        guard messageLength < 80 else { return false }
        
        let inputLower = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Imperative verb patterns (commands that need task model, not casual)
        let imperativeVerbs = [
            "summarize", "summarise", "plan", "rewrite", "analyze", "analyse",
            "do the", "fix", "break down", "generate", "create", "build",
            "make", "write", "edit", "update", "delete", "remove", "add",
            "find", "search", "show", "display", "list", "get", "fetch",
            "execute", "run", "start", "stop", "restart", "convert", "transform",
            "calculate", "compute", "solve", "explain", "describe", "compare",
            "organize", "organise", "sort", "filter", "group", "merge", "split",
            "test", "verify", "check", "validate", "review", "optimize", "optimise",
            "implement", "refactor", "debug", "parse", "format", "clean"
        ]
        
        // Check if input starts with imperative verb or contains command pattern
        for verb in imperativeVerbs {
            if inputLower.hasPrefix(verb) || inputLower.contains(" \(verb) ") || inputLower.contains(" \(verb) this") || inputLower.contains(" \(verb) the") {
                return true
            }
        }
        
        // Check for "steps" pattern (e.g., "give me steps", "break down steps")
        if inputLower.contains("steps") && (inputLower.contains("give") || inputLower.contains("break") || inputLower.contains("show")) {
            return true
        }
        
        return false
    }
    
    /// Checks if input requires reasoning or analysis (expanded trigger set)
    private func isReasoningOrAnalysisTask(input: String) -> Bool {
        let inputLower = input.lowercased()
        
        // Coding-specific triggers
        let codingTriggers = [
            "code", "function", "script", "algorithm", "implement", "debug",
            "programming", "syntax", "variable", "import", "def ", "func ",
            "const ", "let ", "var ", "class ", "method", "api", "endpoint"
        ]
        
        for trigger in codingTriggers {
            if inputLower.contains(trigger) {
                return true
            }
        }
        
        // Reasoning/analysis triggers (expanded)
        let reasoningTriggers = [
            "think through", "think about", "break this down", "break down",
            "analyze", "analyse", "analysis", "generate logic", "give me steps",
            "steps", "should i do", "should i", "what's the optimal", "optimal approach",
            "optimal", "best approach", "best way", "how should", "what should",
            "reason through", "work through", "walk through", "figure out",
            "determine", "decide", "choose between", "which is better",
            "compare", "compare and", "evaluate", "assess", "strategize",
            "strategy", "plan out", "workflow", "process", "procedure",
            "logic", "reasoning", "rationale", "explain why", "why should",
            "what if", "if then", "decision tree", "consider", "weigh"
        ]
        
        for trigger in reasoningTriggers {
            if inputLower.contains(trigger) {
                return true
            }
        }
        
        return false
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
    
    // Note: Image routing is now handled by ImageAnalysisService
    // This method is deprecated but kept for backward compatibility
    /// Selects image processing model with fallback chain
    /// Safety guard: Forces isResearchMode = false
    @available(*, deprecated, message: "Image routing is now handled by ImageAnalysisService")
    func selectImageModel() -> ModelRoutingDecision {
        // Return default model - ImageAnalysisService handles actual routing
        return ModelRoutingDecision(
            model: ModelTierMap.defaultModel(),
            useThinking: false,
            isCasual: false
        )
    }
    
    /// Selects document analysis model with fallback chain
    /// Safety guard: Forces isResearchMode = false
    func selectDocumentModel() -> ModelRoutingDecision {
        // Safety guard: Force research mode off for documents
        let primaryModel = ModelTierMap.documentModel()
        let fallbackModel = ModelTierMap.documentFallbackModel()
        
        if debugMode {
            print("[ModelRoutingEngine] [DOCUMENT] Primary: \(primaryModel), Fallback: \(fallbackModel)")
        }
        
        // Return primary model - actual fallback happens in OllamaBridgeService
        return ModelRoutingDecision(
            model: primaryModel,
            useThinking: false,
            isCasual: false
        )
    }
}
