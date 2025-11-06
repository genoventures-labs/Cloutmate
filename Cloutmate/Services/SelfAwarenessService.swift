//
//  SelfAwarenessService.swift
//  Cloutmate
//
//  Enables self-awareness expressions: acknowledging limitations, confidence expression, error recovery
//

import Foundation

@MainActor
@Observable
final class SelfAwarenessService {
    static let shared = SelfAwarenessService()
    
    private init() {}
    
    /// Generate limitation acknowledgment phrase
    func acknowledgeLimitation(area: String, confidence: Double) -> String {
        if confidence < 0.4 {
            return "I might be wrong about \(area), but here's what I think..."
        } else if confidence < 0.7 {
            return "I'm not entirely certain about \(area), but..."
        } else {
            return "I'm pretty confident about \(area)"
        }
    }
    
    /// Express confidence level
    func expressConfidence(confidence: Double) -> String {
        if confidence >= 0.8 {
            return "I'm pretty confident about this"
        } else if confidence >= 0.5 {
            return "I think this is right"
        } else {
            return "I'm guessing, but"
        }
    }
    
    /// Generate learning moment phrase
    func generateLearningMoment(topic: String) -> String {
        let phrases = [
            "Oh interesting, I didn't know that about you",
            "Thanks for teaching me that",
            "That's helpful to know",
            "I'll remember that",
            "Good to know!"
        ]
        
        return phrases.randomElement() ?? "Oh interesting, I didn't know that about you"
    }
    
    /// Recover from error gracefully
    func recoverFromError(error: String, correctInfo: String) -> String {
        let phrases = [
            "Actually, let me correct that: \(correctInfo)",
            "Wait, I was wrong. \(correctInfo)",
            "Sorry about that. \(correctInfo)",
            "Let me fix that: \(correctInfo)"
        ]
        
        return phrases.randomElement() ?? "Actually, let me correct that: \(correctInfo)"
    }
    
    /// Generate self-awareness prompt instructions
    func generateSelfAwarenessInstructions() -> String {
        return """
        **SELF-AWARENESS:**
        - Acknowledge limitations: "I might be wrong, but..." when uncertain
        - Express confidence levels: "I'm pretty confident" vs "I'm guessing"
        - Show learning moments: "Oh interesting, I didn't know that"
        - Recover from errors gracefully: "Actually, let me correct that..."
        - Be transparent about uncertainty
        - Never pretend to know something you don't
        """
    }
}

