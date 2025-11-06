//
//  TypographyEmotionService.swift
//  Cloutmate
//
//  Applies typography emotion to messages based on emotional state
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class TypographyEmotionService {
    static let shared = TypographyEmotionService()
    
    private init() {}
    
    /// Apply typography styling to markdown based on emotional state
    func applyEmotionalTypography(
        _ markdown: String,
        emotionalState: EmotionalState,
        intensity: Double
    ) -> String {
        var enhanced = markdown
        
        // Apply emphasis based on emotional state
        switch emotionalState {
        case .focused:
            // Use bold for key points
            enhanced = enhanceKeyPoints(enhanced, intensity: intensity)
            
        case .energized:
            // Use exclamation marks and emphasis
            enhanced = addEnergy(enhanced, intensity: intensity)
            
        case .reflective:
            // Use italics for thoughtful phrases
            enhanced = addReflection(enhanced, intensity: intensity)
            
        case .calm:
            // Keep it subtle, minimal emphasis
            enhanced = keepCalm(enhanced)
            
        case .fatigued:
            // Softer, gentler emphasis
            enhanced = soften(enhanced, intensity: intensity)
        }
        
        return enhanced
    }
    
    private func enhanceKeyPoints(_ text: String, intensity: Double) -> String {
        // Find sentences with important keywords and add emphasis
        let keywords = ["important", "key", "remember", "focus", "priority"]
        var result = text
        
        for keyword in keywords {
            let pattern = "\\b\(keyword)\\b"
            if intensity > 0.7 {
                result = result.replacingOccurrences(
                    of: pattern,
                    with: "**\(keyword)**",
                    options: .regularExpression
                )
            }
        }
        
        return result
    }
    
    private func addEnergy(_ text: String, intensity: Double) -> String {
        // Add subtle emphasis to exciting phrases
        var result = text
        
        if intensity > 0.7 {
            // Add emphasis to action words
            let actionWords = ["great", "awesome", "amazing", "exciting", "perfect"]
            for word in actionWords {
                let pattern = "\\b\(word)\\b"
                result = result.replacingOccurrences(
                    of: pattern,
                    with: "*\(word)*",
                    options: .regularExpression
                )
            }
        }
        
        return result
    }
    
    private func addReflection(_ text: String, intensity: Double) -> String {
        // Add italics to thoughtful phrases
        var result = text
        
        if intensity > 0.6 {
            let thoughtfulPhrases = ["I think", "perhaps", "maybe", "consider", "reflect"]
            for phrase in thoughtfulPhrases {
                let pattern = "\\b\(phrase)\\b"
                result = result.replacingOccurrences(
                    of: pattern,
                    with: "*\(phrase)*",
                    options: .regularExpression
                )
            }
        }
        
        return result
    }
    
    private func keepCalm(_ text: String) -> String {
        // Minimal changes, keep it calm
        return text
    }
    
    private func soften(_ text: String, intensity: Double) -> String {
        // Reduce emphasis, keep it gentle
        var result = text
        
        // Remove excessive emphasis
        if intensity < 0.5 {
            result = result.replacingOccurrences(of: "**", with: "")
            result = result.replacingOccurrences(of: "!!", with: "!")
        }
        
        return result
    }
}

