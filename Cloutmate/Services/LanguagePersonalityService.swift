//
//  LanguagePersonalityService.swift
//  Cloutmate
//
//  Enhances natural language personality with contractions and casual language
//

import Foundation

@MainActor
@Observable
final class LanguagePersonalityService {
    static let shared = LanguagePersonalityService()
    
    private init() {}
    
    /// Enhance system prompt with natural language instructions
    func enhanceSystemPrompt(_ basePrompt: String, formalityLevel: Double) -> String {
        var enhanced = basePrompt
        
        // Add natural language instructions based on formality
        let languageInstructions = generateLanguageInstructions(formalityLevel: formalityLevel)
        enhanced += "\n\n**NATURAL LANGUAGE STYLE:**\n\(languageInstructions)"
        
        return enhanced
    }
    
    private func generateLanguageInstructions(formalityLevel: Double) -> String {
        var instructions: [String] = []
        
        if formalityLevel < 0.4 {
            // Very casual
            instructions.append("Use contractions liberally: I'm, you're, can't, won't, don't, it's, that's, we're, they're, I've, you've, we've, they've")
            instructions.append("Lean on casual connectors: 'so', 'anyway', 'also', 'plus', 'btw'")
            instructions.append("Keep playful phrases on hand: 'yeah', 'yep', 'totally', 'for sure', 'sounds good'")
            instructions.append("Short fragments are fair game when you need a punchy landing")
        } else if formalityLevel < 0.65 {
            // Moderate casual
            instructions.append("Use natural contractions: I'm, you're, can't, won't, don't, it's, that's")
            instructions.append("Blend conversational warmth with clarity")
            instructions.append("Use 'I think', 'I believe', 'maybe', 'perhaps' when you soften certainty")
        } else {
            // Formal
            instructions.append("Use contractions sparingly, only when they feel natural")
            instructions.append("Maintain professional tone while staying personable")
            instructions.append("Prefer complete sentences over fragments")
        }
        
        // Universal guidelines
        instructions.append("Never force contractions if they don't sound natural")
        instructions.append("Match punctuation and cadence to the user's energy")
        instructions.append("Rotate sentence length every few lines: short, then medium, then short")
        instructions.append("Keep emotion inside the words—no 'I understand that you feel' framing")
        instructions.append("No ellipses. Use commas, periods, or standalone lines for pauses")
        instructions.append("Rhetorical questions are spice, not default. Deploy them intentionally")
        instructions.append("Let the language feel like a late-night conversation: smooth, smart, unbothered")
        
        return instructions
            .map { "- \($0)" }
            .joined(separator: "\n")
    }
}

