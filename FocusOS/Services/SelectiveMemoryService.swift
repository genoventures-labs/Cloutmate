//
//  SelectiveMemoryService.swift
//  FocusOS
//
//  Handles selective memory recall with emotional prioritization and context-dependent access
//

import Foundation
import FocusOSShared

@MainActor
@Observable
final class SelectiveMemoryService {
    static let shared = SelectiveMemoryService()
    
    private init() {}
    
    /// Prioritize emotional memories over routine tasks
    func prioritizeByEmotionalWeight(
        memories: [RecallSnippet],
        emotionalThreshold: Double = 0.5
    ) -> [RecallSnippet] {
        return memories.sorted { memory1, memory2 in
            // High emotional intensity memories first
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
    
    /// Determine if memory should be detailed or summarized
    func shouldSummarizeMemory(
        memory: RecallSnippet,
        contextRelevance: Double
    ) -> Bool {
        // Summarize if:
        // - Low emotional intensity and low relevance
        // - Very old (>30 days)
        // - Very long detail
        
        let daysSinceUpdate = Date().timeIntervalSince(memory.lastUpdated) / 86400
        
        if memory.emotionIntensity < 0.3 && contextRelevance < 0.4 {
            return true
        }
        
        if daysSinceUpdate > 30 {
            return true
        }
        
        if memory.detail.count > 200 {
            return true
        }
        
        return false
    }
    
    /// Simulate memory fading for older information
    func applyMemoryFading(
        memory: RecallSnippet
    ) -> String {
        let daysSinceUpdate = Date().timeIntervalSince(memory.lastUpdated) / 86400
        
        if daysSinceUpdate > 90 {
            // Very faded - just title
            return "I remember something about \(memory.title), but the details are fuzzy."
        } else if daysSinceUpdate > 30 {
            // Somewhat faded - summarized
            let summary = String(memory.detail.prefix(100))
            return "I recall \(memory.title). \(summary)..."
        } else {
            // Fresh - full detail
            return memory.detail
        }
    }
    
    /// Context-dependent memory access
    func filterMemoriesByContext(
        memories: [RecallSnippet],
        currentContext: String
    ) -> [RecallSnippet] {
        let contextLower = currentContext.lowercased()
        
        return memories.filter { memory in
            // Check if memory is relevant to current context
            let titleLower = memory.title.lowercased()
            let detailLower = memory.detail.lowercased()
            
            // Extract keywords from context
            let contextKeywords = extractKeywords(contextLower)
            let memoryKeywords = extractKeywords(titleLower + " " + detailLower)
            
            // Check for keyword overlap
            let overlap = Set(contextKeywords).intersection(Set(memoryKeywords))
            return overlap.count > 0 || memory.emotionIntensity > 0.6
        }
    }
    
    private func extractKeywords(_ text: String) -> [String] {
        let keywords = [
            "task", "project", "note", "reminder", "focus", "deadline",
            "meeting", "schedule", "work", "idea", "goal", "plan"
        ]
        return keywords.filter { text.contains($0) }
    }
}

