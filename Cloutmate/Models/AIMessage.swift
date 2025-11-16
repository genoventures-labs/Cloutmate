//
//  AIMessage.swift
//  Cloutmate
//
//  AI Chat Message Model
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class AIMessage: Identifiable {
    @Attribute var id: UUID = UUID()
    @Attribute var role: String? = "user" // "user" or "assistant"
    @Attribute var content: String? = ""
    @Attribute var timestamp: Date? = Date()
    @Attribute var toolUsed: String?
    @Attribute var isSystemMessage: Bool = false
    
    // Emotional continuity tracking
    @Attribute var emotion: String?
    @Attribute var emotionScore: Double = 0.0
    @Attribute var emotionIntensity: Double = 0.0
    
    // Chart visualization data (for reflection responses)
    @Attribute var chartDataEncoded: Data?

    // Image attachment support
    @Attribute var imageData: Data?
    @Attribute var imageMimeType: String?
    @Attribute var imageAnalysis: String?
    @Attribute var imageFileName: String?

    // Confidence tracking for assistant responses
    @Attribute var confidenceScore: Double?

    // Document attachment support
    @Attribute var documentData: Data?
    @Attribute var documentMimeType: String?
    @Attribute var documentSummary: String?
    @Attribute var documentFileName: String?
    @Attribute var documentTextPreview: String?
    @Attribute var documentSourceURL: String?
    @Attribute var documentSourceModel: String? // "Ollama", "AppleLLM", or "Offline"
    
    // Web search results support
    @Attribute var webSearchResultsData: Data? // Encoded WebSearchResults
    @Attribute var webSearchConfidence: Double? // Confidence score for web search results
    
    // Thinking and model tracking
    @Attribute var thinkingContent: String? // Thinking/reasoning content from model
    @Attribute var modelUsed: String? // Display name of model used (e.g., "Qwen3", "Granite3")
    @Attribute var wasThinking: Bool = false // Whether model was in thinking mode
    
    // Tone metadata (AuroraToneKit integration)
    @Attribute var tone: String? // AuroraTone rawValue for this response
    
    // Research sources (from research mode)
    @Attribute var researchSourcesData: Data? // Encoded [ResearchSource]
    
    // Research mode flag for user messages
    @Attribute var wasSentInResearchMode: Bool = false
    
    // Inverse relationship
    var conversation: AIConversation?
    
    init(
        role: String,
        content: String,
        toolUsed: String? = nil,
        isSystemMessage: Bool = false,
        emotion: String? = nil,
        emotionScore: Double = 0.0,
        emotionIntensity: Double = 0.0,
        chartData: ChartData? = nil,
        imageData: Data? = nil,
        imageMimeType: String? = nil,
        imageAnalysis: String? = nil,
        imageFileName: String? = nil,
        confidenceScore: Double? = nil,
        documentData: Data? = nil,
        documentMimeType: String? = nil,
        documentSummary: String? = nil,
        documentFileName: String? = nil,
        documentTextPreview: String? = nil,
        documentSourceURL: String? = nil,
        documentSourceModel: String? = nil,
        webSearchResults: WebSearchResults? = nil,
        webSearchConfidence: Double? = nil,
        thinkingContent: String? = nil,
        modelUsed: String? = nil,
        wasThinking: Bool = false,
        tone: String? = nil,
        researchSources: [ResearchSource]? = nil,
        wasSentInResearchMode: Bool = false
    ) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.toolUsed = toolUsed
        self.isSystemMessage = isSystemMessage
        self.emotion = emotion
        self.emotionScore = emotionScore
        self.emotionIntensity = emotionIntensity
        self.imageData = imageData
        self.imageMimeType = imageMimeType
        self.imageAnalysis = imageAnalysis
        self.imageFileName = imageFileName
        self.confidenceScore = confidenceScore
        self.documentData = documentData
        self.documentMimeType = documentMimeType
        self.documentSummary = documentSummary
        self.documentFileName = documentFileName
        self.documentTextPreview = documentTextPreview
        self.documentSourceURL = documentSourceURL
        self.documentSourceModel = documentSourceModel
        self.webSearchConfidence = webSearchConfidence
        self.thinkingContent = thinkingContent
        self.modelUsed = modelUsed
        self.wasThinking = wasThinking
        self.tone = tone
        
        // Encode web search results if provided
        if let webSearchResults = webSearchResults {
            self.webSearchResultsData = try? JSONEncoder().encode(webSearchResults)
        }
        
        // Encode chart data if provided
        if let chartData = chartData {
            self.chartDataEncoded = try? JSONEncoder().encode(chartData)
        }
        
        // Encode research sources if provided
        if let researchSources = researchSources {
            self.researchSourcesData = try? JSONEncoder().encode(researchSources)
        }
        
        self.wasSentInResearchMode = wasSentInResearchMode
    }
    
    // Helper computed properties for tone metadata (reconstructed from AuroraToneKit)
    var toneValue: AuroraTone? {
        get {
            guard let toneString = tone else { return nil }
            return AuroraTone(rawValue: toneString)
        }
        set {
            tone = newValue?.rawValue
        }
    }
    
    var accentColor: Color? {
        guard let tone = toneValue else { return nil }
        return AuroraToneKit.accentColor(for: tone)
    }
    
    var accentGradient: LinearGradient? {
        guard let tone = toneValue else { return nil }
        return AuroraToneKit.accentGradient(for: tone)
    }
    
    // Helper for web search results access
    var webSearchResults: WebSearchResults? {
        get {
            guard let data = webSearchResultsData else { return nil }
            return try? JSONDecoder().decode(WebSearchResults.self, from: data)
        }
        set {
            webSearchResultsData = newValue.flatMap { try? JSONEncoder().encode($0) }
        }
    }
    
    // Helper for chart data access (encoded as Data for SwiftData compatibility)
    var chartData: ChartData? {
        get {
            guard let encoded = chartDataEncoded else { return nil }
            return try? JSONDecoder().decode(ChartData.self, from: encoded)
        }
        set {
            chartDataEncoded = newValue.flatMap { try? JSONEncoder().encode($0) }
        }
    }
    
    var chartCollection: ChartCollection? {
        get {
            guard let encoded = chartDataEncoded else { return nil }
            return try? JSONDecoder().decode(ChartCollection.self, from: encoded)
        }
        set {
            chartDataEncoded = newValue.flatMap { try? JSONEncoder().encode($0) }
        }
    }
    
    // Helper for research sources access
    var researchSources: [ResearchSource]? {
        get {
            guard let data = researchSourcesData else { return nil }
            return try? JSONDecoder().decode([ResearchSource].self, from: data)
        }
        set {
            researchSourcesData = newValue.flatMap { try? JSONEncoder().encode($0) }
        }
    }
}

@Model
final class AIConversation: Identifiable {
    @Attribute var id: UUID = UUID()
    @Attribute var title: String? = ""
    @Attribute var createdAt: Date? = Date()
    @Attribute var isPinned: Bool = false
    @Attribute var pinnedAt: Date?
    @Attribute var summary: String?
    @Attribute var lastSummaryGeneratedAt: Date?
    @Attribute var tagsData: Data?
    @Attribute var pendingSuggestionPatternId: UUID?
    
    // Tone transition state tracking (for gradual memory weighting)
    @Attribute var toneTransitionData: Data? // Encoded ToneTransitionState
    
    // Make relationship optional for CloudKit compatibility
    @Relationship(deleteRule: .cascade, inverse: \AIMessage.conversation)
    var messages: [AIMessage]? = []
    
    init(title: String = "New Conversation") {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.isPinned = false
    }
    
    // Helper for tags storage (encoded as Data for SwiftData compatibility)
    var tags: [String] {
        get {
            guard let tagsData = tagsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: tagsData)) ?? []
        }
        set {
            tagsData = try? JSONEncoder().encode(newValue)
        }
    }
    
    // Helper for tone transition state storage
    var toneTransitionState: ToneTransitionState? {
        get {
            guard let data = toneTransitionData else { return nil }
            return try? JSONDecoder().decode(ToneTransitionState.self, from: data)
        }
        set {
            toneTransitionData = newValue.flatMap { try? JSONEncoder().encode($0) }
        }
    }
}

// MARK: - Tone Transition State

struct ToneTransitionState: Codable, Sendable {
    let fromTone: String // AuroraTone rawValue
    let toTone: String // AuroraTone rawValue
    let transitionTone: String // AuroraTone rawValue
    let transitionTurn: Int // 0, 1, or 2 (3-turn gradual shift)
    let transitionIntensity: Double // 0.0-1.0, how "strong" the transition is
    let startedAt: Date
    
    init(fromTone: AuroraTone, toTone: AuroraTone, transitionTone: AuroraTone, transitionTurn: Int, transitionIntensity: Double) {
        self.fromTone = fromTone.rawValue
        self.toTone = toTone.rawValue
        self.transitionTone = transitionTone.rawValue
        self.transitionTurn = transitionTurn
        self.transitionIntensity = transitionIntensity
        self.startedAt = Date()
    }
    
    var fromToneValue: AuroraTone? {
        AuroraTone(rawValue: fromTone)
    }
    
    var toToneValue: AuroraTone? {
        AuroraTone(rawValue: toTone)
    }
    
    var transitionToneValue: AuroraTone? {
        AuroraTone(rawValue: transitionTone)
    }
    
    var isActive: Bool {
        transitionTurn < 3
    }
    
    var progress: Double {
        // Progress from 0.0 to 1.0 over 3 turns
        // Turn 0 = 33%, Turn 1 = 66%, Turn 2 = 100%
        return Double(transitionTurn + 1) / 3.0
    }
}
