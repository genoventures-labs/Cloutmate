//
//  EmotionalContextEngine.swift
//  Cloutmate
//
//  Enhanced emotion tracking with mood trends
//

import Foundation
import SwiftData
import os.log

@MainActor
final class EmotionalContextEngine {
    static let shared = EmotionalContextEngine()
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "EmotionalContext")
    
    private init() {}
    
    /// Record mood from various sources
    func recordMood(
        mood: MoodType,
        valence: Double,
        intensity: Double,
        source: String,
        notes: String? = nil,
        modelContext: ModelContext
    ) {
        let entry = MoodEntry(
            mood: mood,
            valence: valence,
            intensity: intensity,
            source: source,
            notes: notes
        )
        
        modelContext.insert(entry)
        
        do {
            try modelContext.save()
            logger.info("Recorded mood: \(mood.rawValue) from \(source)")
        } catch {
            logger.error("Failed to save mood entry: \(error.localizedDescription)")
        }
    }
    
    /// Analyze mood trends over time
    func analyzeMoodTrends(
        days: Int = 30,
        modelContext: ModelContext
    ) -> MoodTrendAnalysis {
        let cutoff = Date().addingTimeInterval(-Double(days) * 24 * 3600)
        let descriptor = FetchDescriptor<MoodEntry>(
            predicate: #Predicate { entry in entry.date >= cutoff },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        
        let entries = (try? modelContext.fetch(descriptor)) ?? []
        
        guard !entries.isEmpty else {
            return MoodTrendAnalysis(
                averageValence: 0.0,
                averageIntensity: 0.0,
                dominantMood: .calm,
                trend: .stable,
                entries: []
            )
        }
        
        let avgValence = entries.map { $0.valence }.reduce(0, +) / Double(entries.count)
        let avgIntensity = entries.map { $0.intensity }.reduce(0, +) / Double(entries.count)
        
        // Find dominant mood
        let moodCounts = Dictionary(grouping: entries, by: { $0.moodType })
        let dominantMood = moodCounts.max { $0.value.count < $1.value.count }?.key ?? .calm
        
        // Determine trend
        let trend = calculateTrend(entries: entries)
        
        return MoodTrendAnalysis(
            averageValence: avgValence,
            averageIntensity: avgIntensity,
            dominantMood: dominantMood,
            trend: trend,
            entries: entries
        )
    }
    
    private func calculateTrend(entries: [MoodEntry]) -> MoodTrend {
        guard entries.count >= 2 else { return .stable }
        
        let firstHalf = entries.prefix(entries.count / 2)
        let secondHalf = entries.suffix(entries.count / 2)
        
        let firstAvg = firstHalf.map { $0.valence }.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.map { $0.valence }.reduce(0, +) / Double(secondHalf.count)
        
        let diff = secondAvg - firstAvg
        
        if diff > 0.2 {
            return .improving
        } else if diff < -0.2 {
            return .declining
        } else {
            return .stable
        }
    }
}

enum MoodTrend {
    case improving
    case stable
    case declining
}

struct MoodTrendAnalysis {
    let averageValence: Double
    let averageIntensity: Double
    let dominantMood: MoodType
    let trend: MoodTrend
    let entries: [MoodEntry]
}

