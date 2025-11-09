//
//  AIMessage.swift
//  Cloutmate
//
//  AI Chat Message Model
//

import Foundation
import SwiftData

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
    @Attribute var modelUsed: String? // Display name of model used (e.g., "Qwen3", "DeepSeek")
    @Attribute var wasThinking: Bool = false // Whether model was in thinking mode
    
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
        wasThinking: Bool = false
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
        
        // Encode web search results if provided
        if let webSearchResults = webSearchResults {
            self.webSearchResultsData = try? JSONEncoder().encode(webSearchResults)
        }
        
        // Encode chart data if provided
        if let chartData = chartData {
            self.chartDataEncoded = try? JSONEncoder().encode(chartData)
        }
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
}
