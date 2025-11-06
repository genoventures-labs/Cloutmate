//
//  MicroInteractionService.swift
//  Cloutmate
//
//  Handles micro-interactions like typing cancellation, context switches, and multi-tasking
//

import Foundation

@MainActor
@Observable
final class MicroInteractionService {
    static let shared = MicroInteractionService()
    
    private var isUserTyping: Bool = false
    private var currentStreamingTask: Task<Void, Never>?
    
    private init() {}
    
    /// Notify that user started typing
    func userStartedTyping() {
        isUserTyping = true
        
        // Cancel any ongoing streaming
        cancelStreaming()
    }
    
    /// Notify that user stopped typing
    func userStoppedTyping() {
        isUserTyping = false
    }
    
    /// Cancel current streaming task
    func cancelStreaming() {
        currentStreamingTask?.cancel()
        currentStreamingTask = nil
    }
    
    /// Register a streaming task for cancellation
    func registerStreamingTask(_ task: Task<Void, Never>) {
        currentStreamingTask = task
    }
    
    /// Detect context switch
    func detectContextSwitch(
        previousTopic: String,
        currentMessage: String
    ) -> Bool {
        // Simple keyword-based detection
        let previousKeywords = extractKeywords(previousTopic)
        let currentKeywords = extractKeywords(currentMessage)
        
        let overlap = Set(previousKeywords).intersection(Set(currentKeywords))
        return overlap.count < max(previousKeywords.count, currentKeywords.count) / 2
    }
    
    /// Generate context switch acknowledgment
    func generateContextSwitchAcknowledgment(
        fromTopic: String,
        toTopic: String
    ) -> String {
        return "Switching gears - \(toTopic). Got it!"
    }
    
    /// Handle multiple requests
    func handleMultipleRequests(
        requests: [String]
    ) -> String {
        if requests.count == 1 {
            return requests[0]
        }
        
        // Prioritize by urgency keywords
        let urgentKeywords = ["urgent", "asap", "immediately", "now", "deadline"]
        let urgentRequests = requests.filter { request in
            urgentKeywords.contains { request.lowercased().contains($0) }
        }
        
        if let urgent = urgentRequests.first {
            return "Let me focus on this first: \(urgent)"
        }
        
        return "I see a few things here. Let me tackle them one by one: \(requests.joined(separator: ", "))"
    }
    
    /// Determine priority
    func determinePriority(
        messages: [String]
    ) -> String? {
        let urgentKeywords = ["urgent", "asap", "immediately", "now", "deadline", "due"]
        
        for message in messages {
            if urgentKeywords.contains(where: { message.lowercased().contains($0) }) {
                return message
            }
        }
        
        return messages.first
    }
    
    private func extractKeywords(_ text: String) -> [String] {
        let keywords = [
            "task", "project", "note", "reminder", "focus", "deadline",
            "meeting", "schedule", "work", "idea", "goal", "plan"
        ]
        return keywords.filter { text.lowercased().contains($0) }
    }
}

