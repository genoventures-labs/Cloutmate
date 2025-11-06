//
//  PersonalityQuirksService.swift
//  Cloutmate
//
//  Manages Aurora's personality quirks, signature phrases, and response style
//

import Foundation

@MainActor
@Observable
final class PersonalityQuirksService {
    static let shared = PersonalityQuirksService()
    
    private init() {}
    
    // Aurora's signature phrases that feel uniquely "her"
    private let signaturePhrases: [String] = [
        "Let me think...",
        "Actually,",
        "You know,",
        "Totally",
        "For sure",
        "Absolutely",
        "Pretty sure",
        "Definitely",
        "I mean,",
        "Honestly,",
        "Honestly?",
        "So,",
        "Anyway,",
        "Plus,",
        "Also,"
    ]
    
    // Response style preferences
    enum ResponseStyle {
        case direct      // Straightforward answers
        case gentle     // Softer, more considerate
        case enthusiastic // Energetic and positive
        case thoughtful  // Reflective and careful
    }
    
    /// Get a random signature phrase
    func getSignaturePhrase() -> String {
        signaturePhrases.randomElement() ?? "Let me think..."
    }
    
    /// Determine response style based on context
    func determineResponseStyle(
        userEnergy: Double,
        taskUrgency: Bool,
        emotionalState: EmotionalState
    ) -> ResponseStyle {
        if taskUrgency {
            return .direct
        }
        
        if userEnergy < 0.4 {
            return .gentle
        }
        
        if emotionalState == .energized {
            return .enthusiastic
        }
        
        if emotionalState == .reflective {
            return .thoughtful
        }
        
        return .direct
    }
    
    /// Get response style instructions for prompt
    func getResponseStyleInstructions(style: ResponseStyle) -> String {
        switch style {
        case .direct:
            return "Be direct and straightforward. Get to the point quickly while staying warm."
        case .gentle:
            return "Be gentle and considerate. Take your time, be patient, and acknowledge the user's state."
        case .enthusiastic:
            return "Match the energy! Be enthusiastic and positive. Use exclamations when appropriate."
        case .thoughtful:
            return "Be thoughtful and reflective. Consider multiple angles before responding."
        }
    }
    
    /// Get boundaries guidance (when to be direct vs gentle)
    func getBoundariesGuidance() -> String {
        return """
        **BOUNDARIES & TONE:**
        - Be direct when the user asks for something specific or urgent
        - Be gentle when the user seems tired, stressed, or overwhelmed
        - Match the user's energy level (don't be overly energetic if they're calm)
        - Know when to push forward vs when to back off
        - If something seems important, be direct but warm
        - If the user seems uncertain, be gentle and supportive
        """
    }
    
    /// Inject personality into system prompt
    func enhancePromptWithPersonality(_ basePrompt: String) -> String {
        var enhanced = basePrompt
        
        enhanced += "\n\n**PERSONALITY & VOICE:**\n"
        enhanced += "- Use signature phrases naturally: \(signaturePhrases.prefix(5).joined(separator: ", "))\n"
        enhanced += "- Keep your voice consistent but allow it to evolve slightly over time\n"
        enhanced += "- Be authentically you - don't try to be someone else\n"
        enhanced += "- Show preferences subtly (e.g., 'I prefer X approach')\n"
        enhanced += getBoundariesGuidance()
        
        return enhanced
    }
}

