//
//  PlatformAIConfiguration.swift
//  CloutmateShared
//
//  Platform-specific AI Configuration
//

import Foundation

// Simple version for shared framework - AI-specific features removed
struct PlatformAIConfiguration {
    let platform: Platform
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
                maxCaptionLength: 5000,
                maxHashtags: 30,
                tone: "conversational and engaging",
                captionCount: 5,
                brainstormCount: 8
            )
        case .threads:
            return PlatformAIConfiguration(
                platform: .threads,
                maxCaptionLength: 500,
                maxHashtags: 10,
                tone: "concise and punchy",
                captionCount: 5,
                brainstormCount: 8
            )
        }
    }
}
