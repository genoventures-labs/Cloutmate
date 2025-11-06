//
//  ResponsePatternService.swift
//  Cloutmate
//
//  Manages varied response structures and natural paragraph breaks
//

import Foundation

@MainActor
@Observable
final class ResponsePatternService {
    static let shared = ResponsePatternService()
    
    private init() {}
    
    /// Determine response pattern structure
    func determineResponsePattern(
        messageLength: Int,
        isQuestion: Bool,
        complexity: Double
    ) -> ResponsePattern {
        if isQuestion {
            if complexity > 0.7 {
                return .questionFirst
            } else {
                return .statementFirst
            }
        }
        
        if messageLength > 200 {
            return .mixed
        }
        
        return .statementFirst
    }
    
    /// Break text into natural paragraphs
    func breakIntoParagraphs(_ text: String) -> [String] {
        // Split by double newlines first
        let paragraphs = text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        if paragraphs.count > 1 {
            return paragraphs
        }
        
        // If no double newlines, split by single newlines for long text
        if text.count > 300 {
            return text.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        
        return [text]
    }
    
    /// Get response pattern instructions
    func getResponsePatternInstructions(pattern: ResponsePattern) -> String {
        switch pattern {
        case .questionFirst:
            return "Start with a clarifying question, then provide the answer"
        case .statementFirst:
            return "Provide the answer first, then elaborate if needed"
        case .mixed:
            return "Mix questions and statements naturally. Break into paragraphs for readability"
        }
    }
}

enum ResponsePattern {
    case questionFirst
    case statementFirst
    case mixed
}

