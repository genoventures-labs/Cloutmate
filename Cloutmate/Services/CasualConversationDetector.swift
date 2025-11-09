//
//  CasualConversationDetector.swift
//  Cloutmate
//
//  Detects casual vs non-casual conversations for model routing
//

import Foundation

actor CasualConversationDetector {
    static let shared = CasualConversationDetector()
    
    private init() {}
    
    /// Determines if a conversation is casual based on various signals
    func isCasual(
        input: String,
        intentCluster: String?,
        messageLength: Int,
        userStyle: TypingStyle?
    ) -> Bool {
        let normalizedInput = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Very short messages are likely casual
        if messageLength < 50 {
            return true
        }
        
        // Check intent cluster
        if let cluster = intentCluster?.lowercased() {
            if cluster.contains("empathy") || cluster.contains("support") {
                return true
            }
        }
        
        // Check for casual indicators
        let casualIndicators = [
            "hi", "hey", "hello", "thanks", "thank you", "ty",
            "how are you", "what's up", "sup", "how's it going",
            "lol", "haha", "omg", "wtf", "nvm", "tbh", "imo",
            "👍", "😊", "😄", "🙂", "👋"
        ]
        
        for indicator in casualIndicators {
            if normalizedInput.contains(indicator) {
                return true
            }
        }
        
        // Check user style - high energy/casual punctuation suggests casual
        if let style = userStyle {
            if style.energyLevel > 0.7 && style.formalityScore < 0.4 {
                return true
            }
        }
        
        // Check for simple questions (single question mark, short)
        let questionCount = normalizedInput.filter { $0 == "?" }.count
        if questionCount == 1 && messageLength < 100 {
            // Simple questions like "what time is it?" are casual
            let simpleQuestionPatterns = [
                "what", "when", "where", "who", "why", "how",
                "is", "are", "can", "will", "do", "does"
            ]
            let firstWords = normalizedInput.components(separatedBy: .whitespaces).prefix(3)
            if firstWords.contains(where: { simpleQuestionPatterns.contains($0) }) {
                return true
            }
        }
        
        // Default to non-casual for complex/long messages
        return false
    }
    
    /// Determines if a message requires deep reasoning
    func requiresDeepReasoning(
        input: String,
        intentCluster: String?,
        messageLength: Int,
        confidence: Double
    ) -> Bool {
        let normalizedInput = input.lowercased()
        
        // Deep reasoning indicators
        let reasoningKeywords = [
            "analyze", "analyze", "reason", "reasoning", "logic", "logical",
            "complex", "complicated", "strategy", "strategic", "plan", "planning",
            "compare", "comparison", "evaluate", "evaluation", "assess", "assessment",
            "explain why", "why does", "how does", "what causes", "what leads to",
            "predict", "forecast", "forecasting", "diagnose", "diagnosis",
            "solve", "solution", "problem", "challenge", "issue"
        ]
        
        for keyword in reasoningKeywords {
            if normalizedInput.contains(keyword) {
                return true
            }
        }
        
        // Check intent cluster
        if let cluster = intentCluster?.lowercased() {
            if cluster.contains("reflection") || cluster.contains("learning") ||
               cluster.contains("orchestration") || cluster.contains("planning") {
                return true
            }
        }
        
        // Long messages with low confidence might need deep reasoning
        if messageLength > 200 && confidence < 0.6 {
            return true
        }
        
        return false
    }
}

