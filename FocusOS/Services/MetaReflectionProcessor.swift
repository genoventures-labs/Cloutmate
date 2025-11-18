//
//  MetaReflectionProcessor.swift
//  FocusOS
//
//  Phase 10: Analyzes responses → sentiment + themes → updates CPS & ARTE
//

import Foundation
import SwiftData
import os.log
import FocusOSShared

@MainActor
final class MetaReflectionProcessor {
    static let shared = MetaReflectionProcessor()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "MetaReflection")
    
    private init() {}
    
    /// Analyze reflection note and return metrics
    func analyze(_ note: ReflectionNote, modelContext: ModelContext) -> ReflectionMetrics {
        // Extract keywords
        let keywords = extractKeywords(from: note.response)
        note.keywords = keywords
        
        // Calculate sentiment
        let sentiment = calculateSentiment(from: note.response)
        note.sentimentScore = sentiment
        
        // Generate summary
        _Concurrency.Task {
            if let summary = await generateSummary(for: note.response) {
                note.summary = summary
                try? modelContext.save()
            }
        }
        
        // Calculate insight weight based on sentiment and length
        let weight = calculateInsightWeight(sentiment: sentiment, length: note.length)
        note.insightWeight = weight
        
        return ReflectionMetrics(
            sentimentScore: sentiment,
            keywords: keywords,
            insightWeight: weight,
            emotionalTone: note.emotionTone,
            contextTag: note.contextTag
        )
    }
    
    /// Update CPS weights based on reflection insights
    func updateCPSWeights(from note: ReflectionNote, modelContext: ModelContext) {
        guard note.insightWeight > 0.3 else { return } // Only update for meaningful reflections
        
        // Extract mentioned objects from keywords
        let mentionedObjects = findMentionedObjects(keywords: note.keywords, modelContext: modelContext)
        
        for objectId in mentionedObjects {
            PriorityEngine.shared.boostScore(
                for: [objectId],
                amount: note.insightWeight * 0.1, // Scale down to avoid over-boosting
                modelContext: modelContext
            )
        }
        
        logger.info("Updated CPS weights for \(mentionedObjects.count) objects from reflection")
    }
    
    /// Feed reflection into momentum tracker
    func feedIntoMomentumTracker(_ note: ReflectionNote, modelContext: ModelContext) {
        // Reflection notes contribute to flow stability metric
        // Positive sentiment → higher stability
        // Negative sentiment → lower stability
        
        let stabilityDelta = note.sentimentScore * 0.1
        
        // This would integrate with MomentumTracker if it had a method for this
        // For now, we'll log it
        logger.info("Reflection note contributes \(stabilityDelta) to flow stability")
    }
    
    /// Sync ARTE state if reflection indicates emotional shift
    func syncARTEStateIfNeeded(_ note: ReflectionNote) {
        // If sentiment is strongly negative and ARTE is in energized state, consider shifting
        if note.sentimentScore < -0.5 && ReactiveThemeManager.shared.currentEmotion() == .energized {
            // Could trigger ARTE state review
            logger.info("Reflection suggests emotional shift - ARTE state may need adjustment")
        }
    }
    
    // MARK: - Private Helpers
    
    private func extractKeywords(from text: String) -> [String] {
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 }
        
        let stopWords = Set(["this", "that", "with", "from", "have", "been", "will", "would", "could", "should", "what", "when", "where", "why", "how"])
        return Array(Set(words.filter { !stopWords.contains($0) }).prefix(10))
    }
    
    private func calculateSentiment(from text: String) -> Double {
        // Simple sentiment analysis using EmotionAnalyzer
        let snapshot = EmotionAnalyzer.analyzeTone(text: text)
        return snapshot.valence
    }
    
    private func calculateInsightWeight(sentiment: Double, length: Int) -> Double {
        // Longer responses with strong sentiment get higher weight
        let lengthFactor = min(1.0, Double(length) / 500.0) // Normalize to 500 chars
        let sentimentFactor = abs(sentiment) // Absolute value - strong emotions matter more
        return (lengthFactor * 0.6) + (sentimentFactor * 0.4)
    }
    
    private func findMentionedObjects(keywords: [String], modelContext: ModelContext) -> [UUID] {
        var objectIds: [UUID] = []
        
        // Search tasks
        let taskDescriptor = FetchDescriptor<FocusOSShared.Task>()
        if let tasks = try? modelContext.fetch(taskDescriptor) {
            for task in tasks {
                let taskText = "\(task.title) \(task.notes ?? "")".lowercased()
                if keywords.contains(where: { taskText.contains($0) }) {
                    objectIds.append(task.id)
                }
            }
        }
        
        // Search projects
        let projectDescriptor = FetchDescriptor<FocusOSShared.Project>()
        if let projects = try? modelContext.fetch(projectDescriptor) {
            for project in projects {
                let projectText = "\(project.title) \(project.goal ?? "")".lowercased()
                if keywords.contains(where: { projectText.contains($0) }) {
                    objectIds.append(project.id)
                }
            }
        }
        
        return objectIds
    }
    
    private func generateSummary(for text: String) async -> String? {
        // Use Ollama to generate a short summary
        let prompt = "Summarize this reflection in one sentence: \(text)"
        
        do {
            let response = try await OllamaBridgeService.shared.generateResponse(for: prompt, context: "")
            return String(response.prefix(200)) // Limit to 200 chars
        } catch {
            logger.error("Failed to generate summary: \(error.localizedDescription)")
            return nil
        }
    }
}

struct ReflectionMetrics {
    let sentimentScore: Double
    let keywords: [String]
    let insightWeight: Double
    let emotionalTone: String
    let contextTag: String
}

