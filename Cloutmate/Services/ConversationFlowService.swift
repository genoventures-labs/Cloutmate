//
//  ConversationFlowService.swift
//  Cloutmate
//
//  Manages natural conversation flow with interruptions, follow-ups, and topic transitions
//  Upgraded with semantic similarity, ARTE integration, emotional awareness, and predictive flow
//

import Foundation
import SwiftData
import os.log
import CloutmateShared

/// Tracks conversation flow arc state
struct FlowArc {
    var topic: String
    var startTime: Date
    var interactionCount: Int
    var lastInteraction: Date
    var isComplete: Bool
    
    init(topic: String) {
        self.topic = topic
        self.startTime = Date()
        self.interactionCount = 1
        self.lastInteraction = Date()
        self.isComplete = false
    }
    
    mutating func increment() {
        interactionCount += 1
        lastInteraction = Date()
    }
    
    var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
}

@MainActor
@Observable
final class ConversationFlowService {
    static let shared = ConversationFlowService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "ConversationFlow")
    
    // Flow arc tracking
    private var currentArc: FlowArc?
    private var previousArcs: [FlowArc] = []
    
    // Context cache
    private var lastSimilarityCache: [String: Double] = [:]
    private var lastIntentCluster: IntentClusterSummary?
    private var lastArteState: EmotionalState?
    private var lastEmotionalTone: EmotionalSnapshot?
    
    private init() {}
    
    // MARK: - Semantic Similarity
    
    /// Calculate semantic similarity between two texts using embeddings
    func semanticSimilarity(_ textA: String, _ textB: String, modelContext: ModelContext) async -> Double {
        // Check cache first
        let cacheKey = "\(textA.hashValue)_\(textB.hashValue)"
        if let cached = lastSimilarityCache[cacheKey] {
            return cached
        }
        
        guard AIConfigService.shared.config.featureFlags.memoryGraphEnabled else {
            // Fallback to simple keyword overlap if memory graph disabled
            return keywordOverlapSimilarity(textA, textB)
        }
        
        do {
            // Generate embeddings for both texts
            let embeddingA = try await MemoryGraphService.shared.generateEmbedding(for: textA)
            let embeddingB = try await MemoryGraphService.shared.generateEmbedding(for: textB)
            
            // Calculate cosine similarity
            let similarity = cosineSimilarity(embeddingA, embeddingB)
            
            // Cache result
            lastSimilarityCache[cacheKey] = similarity
            
            return similarity
        } catch {
            logger.error("Failed to calculate semantic similarity: \(error.localizedDescription)")
            return keywordOverlapSimilarity(textA, textB)
        }
    }
    
    private func cosineSimilarity(_ vecA: [Float], _ vecB: [Float]) -> Double {
        guard vecA.count == vecB.count else { return 0.0 }
        
        var dotProduct: Float = 0.0
        var normA: Float = 0.0
        var normB: Float = 0.0
        
        for i in 0..<vecA.count {
            dotProduct += vecA[i] * vecB[i]
            normA += vecA[i] * vecA[i]
            normB += vecB[i] * vecB[i]
        }
        
        let denominator = sqrt(normA) * sqrt(normB)
        return denominator > 0 ? Double(dotProduct / denominator) : 0.0
    }
    
    private func keywordOverlapSimilarity(_ textA: String, _ textB: String) -> Double {
        let wordsA = Set(textA.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 3 })
        let wordsB = Set(textB.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 3 })
        
        let intersection = wordsA.intersection(wordsB)
        let union = wordsA.union(wordsB)
        
        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }
    
    // MARK: - Intent Cluster Integration
    
    /// Evaluate which intent cluster the current message maps to
    func evaluateIntentCluster(
        message: String,
        context: AIPayloadContext?,
        modelContext: ModelContext
    ) async -> String? {
        guard let clusters = context?.intentClusters else {
            return nil
        }
        
        lastIntentCluster = clusters
        
        // If message semantically matches primary cluster topics, return primary
        if let primary = clusters.primaryCluster {
            let cluster = clusters.clusters.first { $0.name == primary }
            if let topics = cluster?.topics {
                for topic in topics {
                    let similarity = await semanticSimilarity(message, topic, modelContext: modelContext)
                    if similarity > 0.6 {
                        return primary
                    }
                }
            }
        }
        
        // Check secondary cluster
        if let secondary = clusters.secondaryCluster {
            let cluster = clusters.clusters.first { $0.name == secondary }
            if let topics = cluster?.topics {
                for topic in topics {
                    let similarity = await semanticSimilarity(message, topic, modelContext: modelContext)
                    if similarity > 0.6 {
                        return secondary
                    }
                }
            }
        }
        
        return clusters.primaryCluster
    }
    
    // MARK: - ARTE State Integration
    
    /// Get current ARTE emotional state
    func getArteState() -> EmotionalState {
        let state = ReactiveThemeManager.shared.currentEmotion()
        lastArteState = state
        return state
    }
    
    // MARK: - Emotional Tone Integration
    
    /// Get current user emotional tone
    func getUserEmotion(from message: String) -> EmotionalSnapshot {
        let snapshot = EmotionAnalyzer.analyzeTone(text: message)
        lastEmotionalTone = snapshot
        return snapshot
    }
    
    // MARK: - Deterministic Interrupt Logic
    
    /// Determine if Aurora should interrupt (deterministic, no randomness)
    func shouldInterruptDeterministic(
        userMessageLength: Int,
        userTypingSpeed: Double,
        isComplexQuery: Bool,
        previousReplyRequiredContinuation: Bool = false,
        modelContext: ModelContext
    ) -> Bool {
        // Don't interrupt complex queries
        if isComplexQuery {
            return false
        }
        
        // Must meet minimum length
        guard userMessageLength > 25 else {
            return false
        }
        
        // Must have paused typing (>1.2 seconds = typing speed < 0.83)
        guard userTypingSpeed < 0.83 else {
            return false
        }
        
        // Check ARTE state
        let arteState = getArteState()
        guard arteState == .energized || arteState == .reflective else {
            return false
        }
        
        // Don't interrupt if overwhelmed or fatigued
        // (We check this via ARTE state, but also check if last emotion was overwhelmed)
        if let lastTone = lastEmotionalTone,
           lastTone.primaryEmotion == .overwhelmed {
            return false
        }
        
        // Don't interrupt if ARTE state is fatigued
        if arteState == .fatigued {
            return false
        }
        
        // Bonus: interrupt if previous reply required continuation
        if previousReplyRequiredContinuation {
            return true
        }
        
        // Default: don't interrupt (conservative approach)
        return false
    }
    
    // MARK: - Topic Detection with Semantic Similarity
    
    /// Detect if topic changed using semantic similarity
    func detectTopicChange(
        currentMessage: String,
        previousMessage: String,
        modelContext: ModelContext
    ) async -> TopicChangeResult {
        let similarity = await semanticSimilarity(currentMessage, previousMessage, modelContext: modelContext)
        
        if similarity > 0.65 {
            return .sameTopic(similarity)
        } else if similarity < 0.35 {
            return .topicShift(similarity)
        } else {
            return .ambiguous(similarity)
        }
    }
    
    enum TopicChangeResult {
        case sameTopic(Double)      // similarity score
        case topicShift(Double)      // similarity score
        case ambiguous(Double)       // similarity score
    }
    
    /// Check if should reference previous message using semantic similarity
    func shouldReferencePrevious(
        current: String,
        previous: String,
        modelContext: ModelContext
    ) async -> Bool {
        let similarity = await semanticSimilarity(current, previous, modelContext: modelContext)
        return similarity > 0.5
    }
    
    // MARK: - Tone-Aligned Transition Generation
    
    /// Generate tone-aligned topic transition
    func generateToneAlignedTransition(
        fromTopic: String,
        toTopic: String,
        arteState: EmotionalState,
        emotionalTone: EmotionalSnapshot,
        modelContext: ModelContext
    ) -> String {
        let personalityContext = PersonalityQuirksService.PersonalityToneContext(
            energyBand: emotionalTone.intensity > 0.7 ? .high : (emotionalTone.intensity < 0.4 ? .low : .moderate),
            conversationTempo: arteState == .focused ? .punchy : (arteState == .fatigued ? .slow : .balanced),
            emotionalFriction: emotionalTone.valence < -0.3 ? .heavy : (emotionalTone.valence > 0.3 ? .steady : .charged),
            dominantCue: mapEmotionToCue(emotionalTone.primary),
            sassFactor: calculateSassFactor(arteState, emotionalTone),
            isCasualChat: false,
            emotionalKeywords: emotionalTone.keywords,
            userEnergy: emotionalTone.intensity
        )
        
        // Generate transition based on ARTE state and tone
        switch arteState {
        case .focused:
            return "\(toTopic)."
        case .reflective:
            return "On a related note, \(toTopic)"
        case .calm:
            return "Also, \(toTopic)"
        case .energized:
            return "Speaking of \(fromTopic), \(toTopic)"
        case .fatigued:
            return "While we're at it, \(toTopic)"
        }
    }
    
    private func mapEmotionToCue(_ emotion: EmotionTone) -> PersonalityQuirksService.PersonalityToneContext.DominantCue {
        switch emotion {
        case .excited, .determined:
            return .assertive
        case .frustrated, .overwhelmed:
            return .protective
        case .calm, .grateful:
            return .warm
        case .confused:
            return .neutral
        default:
            return .neutral
        }
    }
    
    private func calculateSassFactor(_ arteState: EmotionalState, _ tone: EmotionalSnapshot) -> Double {
        var factor: Double = 0.5
        
        if arteState == .energized {
            factor += 0.2
        }
        if tone.valence > 0.3 {
            factor += 0.1
        }
        if tone.primary == .frustrated {
            factor += 0.15 // Protective sass
        }
        
        return min(1.0, max(0.0, factor))
    }
    
    // MARK: - MemoryGraph Integration
    
    /// Find related memory nodes for context enrichment
    func findRelatedMemoryNodes(
        for message: String,
        modelContext: ModelContext
    ) async -> [MemoryNode] {
        guard AIConfigService.shared.config.featureFlags.memoryGraphEnabled else {
            return []
        }
        
        do {
            // Create temporary embedding for message
            let embedding = try await MemoryGraphService.shared.generateEmbedding(for: message)
            
            // Find similar nodes (this would need a method in MemoryGraphService)
            // For now, return empty - this would require adding a method to search by embedding
            return []
        } catch {
            logger.error("Failed to find related memory nodes: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Check for unresolved threads or incomplete tasks
    func checkForUnresolvedThreads(
        currentMessage: String,
        modelContext: ModelContext
    ) async -> [String] {
        // Use MemoryWeavingService to find connections
        let connections = await MemoryWeavingService.shared.findConnections(
            currentText: currentMessage,
            modelContext: modelContext
        )
        
        return connections.filter { $0.relevanceScore > 0.6 }
            .map { $0.title }
    }
    
    // MARK: - Predictive Flow Integration
    
    /// Get prediction context for flow modulation
    func getPredictionContext() -> (confidence: Double, nextAction: String?)? {
        // PredictiveContextManager doesn't expose a direct method for this
        // We'd need to check latest forecast if available
        // For now, return nil - this would require extending PredictiveContextManager
        return nil
    }
    
    // MARK: - Enhanced Follow-Up Question Logic
    
    /// Generate dynamic follow-up question with full context
    func generateDynamicFollowUp(
        uncertainty: Double,
        topic: String,
        arteState: EmotionalState,
        emotionalTone: EmotionalSnapshot,
        intentCluster: String?,
        modelContext: ModelContext
    ) -> String? {
        // Only ask when conditions are met
        guard uncertainty < 0.45 else { return nil }
        guard arteState != .fatigued else { return nil }
        guard emotionalTone.primaryEmotion != .frustrated else { return nil }
        guard emotionalTone.primaryEmotion != .overwhelmed else { return nil }
        
        // Don't ask if user is in a rush (high energy + focused)
        if arteState == .focused && emotionalTone.intensity > 0.7 {
            return nil
        }
        
        // Generate context-aware follow-up
        var questions: [String] = []
        
        if let cluster = intentCluster {
            questions.append("Are you thinking about \(cluster)?")
        }
        
        switch arteState {
        case .focused:
            questions.append("What specifically do you need?")
        case .reflective:
            questions.append("Want to explore that further?")
        case .calm:
            questions.append("Can you tell me more about that?")
        case .energized:
            questions.append("What's the next step?")
        case .fatigued:
            questions.append("Want me to help clarify?")
        }
        
        // Add tone-specific questions
        switch emotionalTone.primaryEmotion {
        case .confused:
            questions.append("What would help clarify this?")
        case .excited:
            questions.append("What are you most excited about here?")
        default:
            questions.append("What would be most helpful here?")
        }
        
        return questions.first
    }
    
    // MARK: - Flow Arc Tracking
    
    /// Evaluate current flow arc state
    func evaluateFlowArc(
        currentMessage: String,
        previousMessage: String?,
        modelContext: ModelContext
    ) async -> FlowArcEvaluation {
        // Check if topic changed
        if let previous = previousMessage {
            let changeResult = await detectTopicChange(
                currentMessage: currentMessage,
                previousMessage: previous,
                modelContext: modelContext
            )
            
            switch changeResult {
            case .topicShift:
                // End current arc, start new one
                if var arc = currentArc {
                    arc.isComplete = true
                    previousArcs.append(arc)
                }
                currentArc = FlowArc(topic: extractTopic(from: currentMessage))
                return .newArc(currentArc!.topic)
                
            case .sameTopic:
                // Continue current arc
                if var arc = currentArc {
                    arc.increment()
                    currentArc = arc
                    return .continuingArc(arc.topic, arc.interactionCount)
                } else {
                    currentArc = FlowArc(topic: extractTopic(from: currentMessage))
                    return .newArc(currentArc!.topic)
                }
                
            case .ambiguous:
                // Continue but mark as potentially shifting
                if var arc = currentArc {
                    arc.increment()
                    currentArc = arc
                    return .ambiguousArc(arc.topic, arc.interactionCount)
                } else {
                    currentArc = FlowArc(topic: extractTopic(from: currentMessage))
                    return .newArc(currentArc!.topic)
                }
            }
        } else {
            // First message - start new arc
            currentArc = FlowArc(topic: extractTopic(from: currentMessage))
            return .newArc(currentArc!.topic)
        }
    }
    
    enum FlowArcEvaluation {
        case newArc(String)
        case continuingArc(String, Int)
        case ambiguousArc(String, Int)
    }
    
    private func extractTopic(from message: String) -> String {
        // Simple extraction - could be enhanced with NLP
        let words = message.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 4 }
            .prefix(3)
        return words.joined(separator: " ")
    }
    
    // MARK: - Enhanced Conversation Builder
    
    /// Build on previous messages with dynamic enhancement
    func buildOnPreviousMessage(
        currentMessage: String,
        previousMessages: [String],
        arteState: EmotionalState,
        emotionalTone: EmotionalSnapshot,
        intentCluster: String?,
        modelContext: ModelContext
    ) async -> String {
        guard let lastMessage = previousMessages.last else {
            return currentMessage
        }
        
        let shouldReference = await shouldReferencePrevious(
            current: currentMessage,
            previous: lastMessage,
            modelContext: modelContext
        )
        
        guard shouldReference else {
            return currentMessage
        }
        
        // Generate context-aware enhancement
        var enhanced = currentMessage
        
        // Check for task/project references
        let hasTaskContext = currentMessage.lowercased().contains("task") || 
                            lastMessage.lowercased().contains("task")
        
        if hasTaskContext && arteState == .focused {
            enhanced = "Next action: \(enhanced.lowercased())"
        } else if intentCluster == "Execution/Action" {
            enhanced = "Continuing from your tasks earlier, \(enhanced.lowercased())"
        } else if arteState == .reflective {
            enhanced = "Picking up from where we left off, \(enhanced.lowercased())"
        } else if emotionalTone.primaryEmotion == .excited {
            enhanced = "Building on that energy, \(enhanced.lowercased())"
        } else {
            enhanced = "Following up on that, \(enhanced.lowercased())"
        }
        
        return enhanced
    }
    
    // MARK: - Personality/Style Modifiers
    
    /// Apply personality and style modifiers to response
    func applyPersonalityModifiers(
        baseResponse: String,
        formalityLevel: Double,
        arteState: EmotionalState
    ) -> String {
        var modified = baseResponse
        
        // Get personality context
        let personalityContext = PersonalityQuirksService.PersonalityToneContext(
            energyBand: arteState == .energized ? .high : (arteState == .fatigued ? .low : .moderate),
            conversationTempo: arteState == .focused ? .punchy : .balanced,
            emotionalFriction: .steady,
            dominantCue: .neutral,
            sassFactor: 0.5,
            isCasualChat: false,
            emotionalKeywords: [],
            userEnergy: 0.5
        )
        
        // Note: Language personality modifications are applied via prompt enhancement
        // in the system prompt builder, not directly to the response text
        // This method returns the base response - personality is handled upstream
        return modified
    }
    
    // MARK: - Legacy Compatibility (Deprecated)
    
    /// Legacy method - use shouldInterruptDeterministic instead
    @available(*, deprecated, message: "Use shouldInterruptDeterministic instead")
    func shouldInterrupt(
        userMessageLength: Int,
        userTypingSpeed: Double,
        isComplexQuery: Bool
    ) -> Bool {
        // Fallback to old logic for compatibility
        if isComplexQuery {
            return false
        }
        if userTypingSpeed < 0.5 && userMessageLength > 20 {
            return false // Removed randomness
        }
        return false
    }
    
    /// Legacy method - use generateDynamicFollowUp instead
    @available(*, deprecated, message: "Use generateDynamicFollowUp instead")
    func generateFollowUpQuestion(
        uncertainty: Double,
        topic: String
    ) -> String? {
        guard uncertainty > 0.4 else { return nil }
        return "What specifically are you looking for?"
    }
    
    /// Legacy method - use buildOnPreviousMessage with full context instead
    @available(*, deprecated, message: "Use buildOnPreviousMessage with full context instead")
    func buildOnPreviousMessage(
        currentMessage: String,
        previousMessages: [String]
    ) -> String {
        var enhanced = currentMessage
        if let lastMessage = previousMessages.last {
            let currentLower = currentMessage.lowercased()
            let previousLower = lastMessage.lowercased()
            let keywords = ["task", "project", "note", "reminder", "focus"]
            if keywords.contains(where: { currentLower.contains($0) && previousLower.contains($0) }) {
                enhanced = "Following up on that, \(enhanced.lowercased())"
            }
        }
        return enhanced
    }
    
    /// Legacy method - use generateToneAlignedTransition instead
    @available(*, deprecated, message: "Use generateToneAlignedTransition instead")
    func generateTopicTransition(
        fromTopic: String,
        toTopic: String
    ) -> String {
        return "Also, \(toTopic)"
    }
    
    /// Legacy method - use detectTopicChange with semantic similarity instead
    @available(*, deprecated, message: "Use detectTopicChange with semantic similarity instead")
    func detectTopicChange(
        currentMessage: String,
        previousMessage: String
    ) -> Bool {
        let currentKeywords = extractKeywords(currentMessage)
        let previousKeywords = extractKeywords(previousMessage)
        let overlap = Set(currentKeywords).intersection(Set(previousKeywords))
        return overlap.count < currentKeywords.count / 2
    }
    
    private func extractKeywords(_ text: String) -> [String] {
        let keywords = ["task", "project", "note", "reminder", "focus", "schedule", "deadline", "meeting"]
        return keywords.filter { text.lowercased().contains($0) }
    }
}
