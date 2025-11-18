//
//  AICreativeService.swift
//  FocusOS
//
//  AI Creative Assistant Service
//

import Foundation
import FocusOSShared
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
    private let coreResponseService = CoreResponseService.shared
    
    private init() {}
    
    // MARK: - AI Tools
    
    func executeTool(_ tool: AITool, input: String, context: String = "") async -> AIToolResult {
        do {
            let result = try await coreResponseService.executeTool(tool, input: input, context: context)
            return result
        } catch {
            // Fallback to simple error message if Ollama fails
            return AIToolResult(
                tool: tool,
                result: "Unable to generate content at this time. Please check that Ollama is running and the `llama3.1` model is available.",
                suggestedImprovements: nil
            )
        }
    }
}
