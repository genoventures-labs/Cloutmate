//
//  MemoryBehaviorService.swift
//  FocusOS
//
//  Enhances memory recall with confidence levels, selective recall, and graceful forgetting
//

import Foundation
import SwiftData
import FocusOSShared

@MainActor
@Observable
final class MemoryBehaviorService {
    static let shared = MemoryBehaviorService()
    
    private init() {}
    
    /// Calculate memory confidence based on recency, frequency, and emotional weight
    func calculateMemoryConfidence(
        lastUpdated: Date,
        lastViewedAt: Date,
        emotionScore: Double,
        emotionIntensity: Double,
        accessCount: Int
    ) -> MemoryConfidence {
        let daysSinceUpdate = Date().timeIntervalSince(lastUpdated) / 86400
        let daysSinceView = Date().timeIntervalSince(lastViewedAt) / 86400
        
        var score: Double = 0.0
        
        // Recency factor (0-0.4)
        if daysSinceUpdate < 1 {
            score += 0.4 // Very recent
        } else if daysSinceUpdate < 7 {
            score += 0.3 // Recent
        } else if daysSinceUpdate < 30 {
            score += 0.2 // Somewhat recent
        } else {
            score += 0.1 // Not recent
        }
        
        // Frequency factor (0-0.3)
        if accessCount > 10 {
            score += 0.3 // Frequently accessed
        } else if accessCount > 5 {
            score += 0.2
        } else if accessCount > 2 {
            score += 0.1
        }
        
        // Emotional weight factor (0-0.3)
        if emotionIntensity > 0.7 {
            score += 0.3 // High emotional intensity
        } else if emotionIntensity > 0.4 {
            score += 0.2
        } else {
            score += 0.1
        }
        
        // Determine confidence level
        if score >= 0.7 {
            return .high
        } else if score >= 0.4 {
            return .medium
        } else {
            return .low
        }
    }
    
    /// Format memory recall with confidence expression
    func formatMemoryRecall(
        title: String,
        detail: String,
        confidence: MemoryConfidence
    ) -> String {
        switch confidence {
        case .high:
            return "You definitely mentioned \(title). \(detail)"
        case .medium:
            return "I think you mentioned \(title). \(detail)"
        case .low:
            return "I'm not entirely sure, but I believe you mentioned \(title). \(detail.isEmpty ? "Can you remind me?" : detail)"
        }
    }
    
    /// Determine if a memory should be summarized vs detailed
    func shouldSummarizeMemory(
        detail: String,
        confidence: MemoryConfidence,
        daysSinceUpdate: Double
    ) -> Bool {
        // Summarize if:
        // - Low confidence
        // - Very old (>30 days)
        // - Very long detail (>200 chars)
        if confidence == .low {
            return true
        }
        
        if daysSinceUpdate > 30 {
            return true
        }
        
        if detail.count > 200 {
            return true
        }
        
        return false
    }
    
    /// Generate graceful forgetting message
    func generateForgotMessage(item: String) -> String {
        let phrases = [
            "I'm drawing a blank on \(item). Can you remind me?",
            "I'm having trouble recalling \(item). Could you help refresh my memory?",
            "I'm not entirely sure about \(item). Mind sharing a bit more?",
            "I think I might have forgotten some details about \(item). What did you have in mind?"
        ]
        
        return phrases.randomElement() ?? "I'm drawing a blank on \(item). Can you remind me?"
    }
    
    /// Prioritize emotional memories over routine tasks
    func prioritizeMemories(
        memories: [RecallSnippet],
        emotionalThreshold: Double = 0.5
    ) -> [RecallSnippet] {
        return memories.sorted { memory1, memory2 in
            // Prioritize high emotional intensity
            if memory1.emotionIntensity > emotionalThreshold && memory2.emotionIntensity <= emotionalThreshold {
                return true
            }
            if memory1.emotionIntensity <= emotionalThreshold && memory2.emotionIntensity > emotionalThreshold {
                return false
            }
            
            // Then by recency
            return memory1.lastUpdated > memory2.lastUpdated
        }
    }
}

enum MemoryConfidence {
    case high
    case medium
    case low
    
    var displayPhrase: String {
        switch self {
        case .high:
            return "You definitely"
        case .medium:
            return "I think you"
        case .low:
            return "I'm not entirely sure, but I believe you"
        }
    }
}

