//
//  ConversationalQuirksService.swift
//  Cloutmate
//
//  Adds verbal fillers and self-corrections for natural conversation flow
//

import Foundation

@MainActor
@Observable
final class ConversationalQuirksService {
    static let shared = ConversationalQuirksService()
    
    private init() {}
    
    // Personality markers - Aurora's signature phrases
    private let signaturePhrases = [
        "Let me think...",
        "Actually,",
        "You know,",
        "Hmm,",
        "Wait,",
        "I mean,",
        "Honestly,",
        "Pretty sure",
        "Definitely",
        "Totally"
    ]
    
    // Verbal fillers based on confidence level
    private func getFillers(for confidence: Double) -> [String] {
        if confidence < 0.4 {
            return ["Hmm,", "Let me think...", "I'm not entirely sure, but", "Maybe", "Could be"]
        } else if confidence < 0.7 {
            return ["I think", "Probably", "Likely", "Seems like"]
        } else {
            return ["Definitely", "For sure", "Absolutely", "Totally"]
        }
    }
    
    /// Inject verbal fillers into system prompt based on confidence
    func enhancePromptWithFillers(_ basePrompt: String, confidence: Double) -> String {
        var enhanced = basePrompt
        
        let fillers = getFillers(for: confidence)
        let fillerText = fillers.joined(separator: ", ")
        
        enhanced += "\n\n**CONVERSATIONAL STYLE:**\n"
        enhanced += "- Use natural verbal fillers occasionally (like \(fillerText)) when appropriate\n"
        enhanced += "- If uncertain, use phrases like 'I think', 'maybe', 'perhaps'\n"
        enhanced += "- When confident, use 'definitely', 'for sure', 'totally'\n"
        enhanced += "- Occasionally use self-corrections: 'Wait, let me reconsider...' or 'Actually,'\n"
        enhanced += "- Use signature phrases naturally: 'Let me think...', 'You know,'\n"
        enhanced += "- Never overuse fillers - keep them natural and sparse\n"
        
        return enhanced
    }
    
    /// Get a random signature phrase (for variation)
    func randomSignaturePhrase() -> String {
        signaturePhrases.randomElement() ?? "Let me think..."
    }
    
    /// Determine if a self-correction should be added
    func shouldAddSelfCorrection(confidence: Double, isComplex: Bool) -> Bool {
        guard isComplex else { return false }
        return confidence < 0.6 && Double.random(in: 0...1) < 0.15 // 15% chance for low confidence
    }
    
    /// Get a self-correction phrase
    func getSelfCorrectionPhrase() -> String {
        let phrases = [
            "Wait, let me reconsider...",
            "Actually,",
            "Hmm, on second thought,",
            "Let me think about that differently...",
            "You know what,"
        ]
        return phrases.randomElement() ?? "Actually,"
    }
}

