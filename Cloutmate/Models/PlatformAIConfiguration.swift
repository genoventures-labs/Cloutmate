//
//  PlatformAIConfiguration.swift
//  Cloutmate
//
//  Platform-specific AI Configuration
//

import Foundation

struct PlatformAIConfiguration {
    let platform: Platform
    let availableTools: [AITool]
    let maxCaptionLength: Int
    let maxHashtags: Int
    let tone: String
    let captionCount: Int
    let brainstormCount: Int
    
    static func configuration(for platform: Platform) -> PlatformAIConfiguration {
        switch platform {
        case .facebook:
            return PlatformAIConfiguration(
                platform: .facebook,
                availableTools: [.brainstorm, .generateCaptions, .suggestHashtags, .improveText, .adjustTone],
                maxCaptionLength: 5000,
                maxHashtags: 30,
                tone: "conversational and engaging",
                captionCount: 5,
                brainstormCount: 8
            )
        case .threads:
            return PlatformAIConfiguration(
                platform: .threads,
                availableTools: [.brainstorm, .generateCaptions, .suggestHashtags, .improveText],
                maxCaptionLength: 500,
                maxHashtags: 10,
                tone: "concise and punchy",
                captionCount: 5,
                brainstormCount: 8
            )
        }
    }
}
