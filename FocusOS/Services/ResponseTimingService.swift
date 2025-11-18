//
//  ResponseTimingService.swift
//  FocusOS
//
//  Provides context-aware response timing for natural conversation flow
//

import Foundation

@MainActor
@Observable
final class ResponseTimingService {
    static let shared = ResponseTimingService()
    
    private init() {}
    
    /// Estimate processing time based on message complexity
    func estimateProcessingTime(for message: String) -> TimeInterval {
        let wordCount = message.split(separator: " ").count
        let hasQuestions = message.contains("?")
        let hasComplexContent = message.contains("analyze") || message.contains("create") || message.contains("summarize")
        
        // Base processing time (in seconds)
        var baseTime: Double = 0.5
        
        // Add time for complexity
        if wordCount > 100 {
            baseTime += 2.0 // Long messages need more time
        } else if wordCount > 50 {
            baseTime += 1.0
        } else if wordCount > 20 {
            baseTime += 0.5
        }
        
        // Add time for complex operations
        if hasComplexContent {
            baseTime += 1.5
        }
        
        // Add time for questions (needs thinking)
        if hasQuestions {
            baseTime += 0.5
        }
        
        return baseTime
    }
    
    /// Calculate appropriate delay before showing response
    func calculateResponseDelay(
        messageLength: Int,
        isComplex: Bool,
        isAcknowledgment: Bool
    ) -> TimeInterval {
        // Acknowledgments should be instant
        if isAcknowledgment {
            return 0.1
        }
        
        // Short messages get quick response
        if messageLength < 50 {
            return 0.3
        }
        
        // Complex messages get longer delay
        if isComplex {
            return 1.5
        }
        
        // Medium messages get moderate delay
        return 0.8
    }
    
    /// Determine if a message is a simple acknowledgment
    func isAcknowledgment(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        let acknowledgmentPatterns = [
            "ok", "okay", "got it", "thanks", "thank you", "sure", "alright",
            "sounds good", "perfect", "nice", "cool", "yeah", "yep"
        ]
        
        return acknowledgmentPatterns.contains { lowercased.contains($0) }
    }
}

