//
//  ConversationFlowService.swift
//  Cloutmate
//
//  Manages natural conversation flow with interruptions, follow-ups, and topic transitions
//

import Foundation

@MainActor
@Observable
final class ConversationFlowService {
    static let shared = ConversationFlowService()
    
    private init() {}
    
    /// Determine if Aurora should interrupt (start responding early)
    func shouldInterrupt(
        userMessageLength: Int,
        userTypingSpeed: Double,
        isComplexQuery: Bool
    ) -> Bool {
        // Don't interrupt if user is typing a complex query
        if isComplexQuery {
            return false
        }
        
        // Interrupt if user pauses mid-typing for >3 seconds
        if userTypingSpeed < 0.5 && userMessageLength > 20 {
            return Double.random(in: 0...1) < 0.1 // 10% chance
        }
        
        return false
    }
    
    /// Generate follow-up questions when uncertain
    func generateFollowUpQuestion(
        uncertainty: Double,
        topic: String
    ) -> String? {
        guard uncertainty > 0.4 else { return nil }
        
        let questions = [
            "What specifically are you looking for?",
            "Can you tell me more about that?",
            "Are you thinking about \(topic)?",
            "Want me to help clarify?",
            "What would be most helpful here?"
        ]
        
        return questions.randomElement()
    }
    
    /// Build on previous messages naturally
    func buildOnPreviousMessage(
        currentMessage: String,
        previousMessages: [String]
    ) -> String {
        var enhanced = currentMessage
        
        // Reference previous topics if relevant
        if let lastMessage = previousMessages.last,
           shouldReferencePrevious(currentMessage, lastMessage) {
            enhanced = "Following up on that, \(enhanced.lowercased())"
        }
        
        return enhanced
    }
    
    private func shouldReferencePrevious(_ current: String, _ previous: String) -> Bool {
        // Simple keyword matching - could be enhanced with semantic similarity
        let currentLower = current.lowercased()
        let previousLower = previous.lowercased()
        
        let keywords = ["task", "project", "note", "reminder", "focus"]
        return keywords.contains { keyword in
            currentLower.contains(keyword) && previousLower.contains(keyword)
        }
    }
    
    /// Generate smooth topic transition
    func generateTopicTransition(
        fromTopic: String,
        toTopic: String
    ) -> String {
        let transitions = [
            "Speaking of \(fromTopic), \(toTopic)",
            "On a related note, \(toTopic)",
            "Also, \(toTopic)",
            "While we're at it, \(toTopic)",
            "By the way, \(toTopic)"
        ]
        
        return transitions.randomElement() ?? "Also, \(toTopic)"
    }
    
    /// Detect topic changes
    func detectTopicChange(
        currentMessage: String,
        previousMessage: String
    ) -> Bool {
        // Simple keyword-based detection
        let currentKeywords = extractKeywords(currentMessage)
        let previousKeywords = extractKeywords(previousMessage)
        
        let overlap = Set(currentKeywords).intersection(Set(previousKeywords))
        return overlap.count < currentKeywords.count / 2
    }
    
    private func extractKeywords(_ text: String) -> [String] {
        let keywords = ["task", "project", "note", "reminder", "focus", "schedule", "deadline", "meeting"]
        return keywords.filter { text.lowercased().contains($0) }
    }
}

