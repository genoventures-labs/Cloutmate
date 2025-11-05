//
//  StoryToken.swift
//  Cloutmate
//
//  Phase 5: Narrative Engine - Story Snapshots
//  Represents a narrative snapshot of workspace activity
//

import Foundation
import SwiftData
import Combine

/// A narrative snapshot capturing workspace patterns and themes
@Model
final class StoryToken {
    @Attribute(.unique) var id: UUID
    var title: String
    var markdown: String              // Full narrative content
    var summary: String               // Brief summary for quick reference
    
    // Time range
    var startDate: Date
    var endDate: Date
    
    // Story type
    var storyType: String             // "weekly", "monthly", "milestone", "insight"
    
    // Key metrics captured
    var metrics: [String: Double] = [:]
    
    // Themes and concepts
    var themes: [String] = []
    var topConcepts: [String] = []
    
    // Emotional trajectory
    var emotionalTone: String         // "positive", "challenging", "neutral", "mixed"
    var emotionalIntensity: Double = 0.0
    
    // Metadata
    var createdAt: Date
    var isEdited: Bool = false
    var isArchived: Bool = false
    
    init(
        title: String,
        markdown: String,
        summary: String,
        startDate: Date,
        endDate: Date,
        storyType: String = "weekly",
        themes: [String] = [],
        emotionalTone: String = "neutral"
    ) {
        self.id = UUID()
        self.title = title
        self.markdown = markdown
        self.summary = summary
        self.startDate = startDate
        self.endDate = endDate
        self.storyType = storyType
        self.themes = themes
        self.topConcepts = []
        self.emotionalTone = emotionalTone
        self.emotionalIntensity = 0.0
        self.createdAt = Date()
        self.metrics = [:]
    }
    
    /// Add a metric to this story
    func addMetric(key: String, value: Double) {
        metrics[key] = value
    }
    
    /// Display string for lists
    var displayTitle: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        return "\(title) (\(dateFormatter.string(from: startDate)))"
    }
}

/// Narrative summary for AI context
struct NarrativeSummaryContext: Sendable {
    let period: String              // "This week", "This month", etc.
    let keyThemes: [String]         // Top 3-5 themes
    let liveConcepts: [String]      // "Alive" concepts with high relevance
    let priorityTrends: String      // "Rising: X, Y | Stable: Z"
    let emotionalTone: String       // Overall mood
    let focusPerformance: String?   // Focus session summary (if available)
    let keyInsight: String?         // One-sentence insight
}

