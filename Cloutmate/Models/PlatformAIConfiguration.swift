//
//  PlatformAIConfiguration.swift
//  Cloutmate
//
//  Platform-specific AI Configuration
//

import Foundation
import CloutmateShared
import Combine

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
        case Platform.facebook:
            return PlatformAIConfiguration(
                platform: Platform.facebook,
                availableTools: [
                    AITool.brainstorm,
                    AITool.generateCaptions,
                    AITool.suggestHashtags,
                    AITool.improveText,
                    AITool.adjustTone
                ],
                maxCaptionLength: 5000,
                maxHashtags: 30,
                tone: "conversational and engaging",
                captionCount: 5,
                brainstormCount: 8
            )
        case Platform.threads:
            return PlatformAIConfiguration(
                platform: Platform.threads,
                availableTools: [
                    AITool.brainstorm,
                    AITool.generateCaptions,
                    AITool.suggestHashtags,
                    AITool.improveText
                ],
                maxCaptionLength: 500,
                maxHashtags: 10,
                tone: "concise and punchy",
                captionCount: 5,
                brainstormCount: 8
            )
        @unknown default:
            return PlatformAIConfiguration(
                platform: platform,
                availableTools: Array(AITool.allCases),
                maxCaptionLength: 1000,
                maxHashtags: 20,
                tone: "adaptable and engaging",
                captionCount: 5,
                brainstormCount: 8
            )
        }
    }
}
