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
            instructions.append("Feel free to use casual phrases like 'yeah', 'yep', 'totally', 'for sure', 'sounds good'")
            instructions.append("Use casual connectors: 'so', 'anyway', 'also', 'plus', 'btw'")
            instructions.append("It's okay to have fragmentary sentences for emphasis")
        } else if formalityLevel < 0.65 {
            // Moderate casual
            instructions.append("Use natural contractions: I'm, you're, can't, won't, don't, it's, that's")
            instructions.append("Keep it conversational but clear")
            instructions.append("Use 'I think', 'I believe', 'maybe', 'perhaps' when appropriate")
        } else {
            // Formal
            instructions.append("Use contractions sparingly, only when they feel natural")
            instructions.append("Maintain professional tone while staying personable")
            instructions.append("Prefer complete sentences over fragments")
        }
        
        // Universal guidelines
        instructions.append("Never force contractions if they don't sound natural")
        instructions.append("Let the language flow naturally - don't overthink it")
        instructions.append("Match punctuation patterns to the energy level")
        
        return instructions.joined(separator: "\n- ")
    }
}

