//
//  AICreativeService.swift
//  Cloutmate
//
//  AI Creative Assistant Service
//

import Foundation
import CloutmateShared
import Combine

enum AITool: String, CaseIterable {
    case brainstorm = "Brainstorm Ideas"
    case generateCaptions = "Generate Captions"
    case improveText = "Improve Text"
    case suggestHashtags = "Suggest Hashtags"
    case adjustTone = "Adjust Tone"
    
    var icon: String {
        switch self {
        case .brainstorm: return "lightbulb.fill"
        case .generateCaptions: return "text.bubble.fill"
        case .improveText: return "wand.and.stars"
        case .suggestHashtags: return "number"
        case .adjustTone: return "slider.horizontal.3"
        }
    }
    
    var returnsActionableList: Bool {
        switch self {
        case .brainstorm, .generateCaptions:
            return true
        case .suggestHashtags, .improveText, .adjustTone:
            return false
        }
    }
}

struct AIToolResult {
    let tool: AITool
    let result: String
    let suggestedImprovements: [String]?
}

actor AICreativeService {
    static let shared = AICreativeService()
    private let geminiService = GeminiService.shared
    
    private init() {}
    
    // MARK: - AI Tools
    
    func executeTool(_ tool: AITool, input: String, context: String = "") async -> AIToolResult {
        do {
            let result = try await geminiService.executeTool(tool, input: input, context: context)
            return result
        } catch {
            // Fallback to simple error message if Gemini fails
            return AIToolResult(
                tool: tool,
                result: "Unable to generate content at this time. Please check your API key and try again.",
                suggestedImprovements: nil
            )
        }
    }
    
    // MARK: - Platform Context
    
    func getCharacterLimit(for platform: Platform) -> Int {
        switch platform {
        case .facebook:
            return 5000
        case .threads:
            return 500
        @unknown default:
            return 500
        }
    }
    
    func getPlatformGuidance(for platform: Platform) -> String {
        switch platform {
        case .facebook:
            return "Facebook posts perform well with storytelling, asking questions, and sharing personal experiences. Keep it conversational and authentic."
        case .threads:
            return "Threads favors concise, engaging content with emojis. Make it punchy and conversation-starting."
        @unknown default:
            return "Focus on clear, engaging copy tailored to the platform's audience."
        }
    }
}
