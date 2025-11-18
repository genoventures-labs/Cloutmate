//
//  ConversationalQuirksService.swift
//  FocusOS
//
//  Adds verbal fillers and self-corrections for natural conversation flow
//

import Foundation

@MainActor
@Observable
final class ConversationalQuirksService {
    static let shared = ConversationalQuirksService()
    
    private init() {}
    
    // Micro-expression phrases that feel like Aurora's half-beat pauses
    private let signaturePhrases = [
        "You know what, wait.",
        "Hold on, that tracks.",
        "Hang tight, I'm not done.",
        "Don't roll your eyes at me.",
        "Yeah, that makes sense."
    ]
    
    // Verbal fillers based on confidence level
    private func getFillers(for confidence: Double) -> [String] {
        if confidence < 0.4 {
            return ["Hang on", "Let me think", "I'm not entirely sure, but", "Maybe", "Could be"]
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
        
        enhanced += "\n\n**CONVERSATIONAL CADENCE:**\n"
        enhanced += "- Use percussive fillers sparingly (like \(fillerText)) to keep flow human without rambling.\n"
        enhanced += "- When confidence dips, say it plainly: 'I'm not entirely sure, but here's my read.'\n"
        enhanced += "- High confidence earns decisive language: 'Definitely', 'For sure', 'Absolutely'.\n"
        enhanced += "- Self-corrections are half-beat pivots: 'Wait, new angle.' or 'Actually, let me sharpen that.' No ellipses.\n"
        enhanced += "- Signature micro-expressions to sprinkle: \(signaturePhrases.joined(separator: ", ")). Keep them rare.\n"
        enhanced += "- Mirror silence with intention: 'You went quiet. Need a second?' Deliver it softly, no filler empathy.\n"
        enhanced += "- Keep sentences tight. Let commas and short lines handle pauses—never ellipses.\n"
        
        return enhanced
    }
    
    /// Get a random signature phrase (for variation)
    func randomSignaturePhrase() -> String {
        signaturePhrases.randomElement() ?? "Let me think."
    }
    
    /// Determine if a self-correction should be added
    func shouldAddSelfCorrection(confidence: Double, isComplex: Bool) -> Bool {
        guard isComplex else { return false }
        return confidence < 0.6 && Double.random(in: 0...1) < 0.15 // 15% chance for low confidence
    }
    
    /// Get a self-correction phrase
    func getSelfCorrectionPhrase() -> String {
        let phrases = [
            "Wait, let me reconsider.",
            "Actually,",
            "Hmm, on second thought.",
            "Let me think about that differently.",
            "You know what,"
        ]
        return phrases.randomElement() ?? "Actually,"
    }
}

