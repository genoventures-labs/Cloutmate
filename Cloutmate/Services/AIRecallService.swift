//
//  AIRecallService.swift
//  Cloutmate
//
//  Phase 1 recall layer with shared AI config + telemetry.
//

import Foundation
import SwiftData
import os
import Combine
import CloutmateShared

// MARK: - Conversation Modes

enum ConversationMode: String, CaseIterable {
    case reflective = "Reflective"
    case operational = "Operational"
    case creative = "Creative"
    
    var description: String {
        switch self {
        case .reflective:
            return "Pulls related personal insights and reflections"
        case .operational:
            return "Pulls relevant data objects and actionable items"
        case .creative:
            return "Cross-pollinates themes for idea generation"
        }
    }
}

struct RecallSnippetWithTemporalContext: Identifiable, Hashable, Sendable {
    let snippet: RecallSnippet
    let temporalContext: String
    
    var id: UUID { snippet.id }
}

// MARK: - Adaptive Context Contract

struct AIPayloadContext: Sendable {
    var recall: [RecallSnippet]
    var priorities: [PriorityItem]
    var feedback: [FeedbackSummary]
    var focusSession: FocusSessionContext?
    var liveThemes: [ConceptSummary]?
    var pastConversations: [ConversationSummaryContext]?
    var memoryThemes: [ThemeSummary]?
    var narrativeSummary: String?
    var intentClusters: IntentClusterSummary?
    var conversationBreadcrumbs: ConversationBreadcrumbs?
    var cognitiveHealth: CognitiveHealthSnapshot?
    var metadata: [String: String]
    
    init(
        recall: [RecallSnippet] = [],
        priorities: [PriorityItem] = [],
        feedback: [FeedbackSummary] = [],
        focusSession: FocusSessionContext? = nil,
        liveThemes: [ConceptSummary]? = nil,
        pastConversations: [ConversationSummaryContext]? = nil,
        memoryThemes: [ThemeSummary]? = nil,
        narrativeSummary: String? = nil,
        intentClusters: IntentClusterSummary? = nil,
        conversationBreadcrumbs: ConversationBreadcrumbs? = nil,
        cognitiveHealth: CognitiveHealthSnapshot? = nil,
        metadata: [String: String] = [:]
    ) {
        self.recall = recall
        self.priorities = priorities
        self.feedback = feedback
        self.focusSession = focusSession
        self.liveThemes = liveThemes
        self.pastConversations = pastConversations
        self.memoryThemes = memoryThemes
        self.narrativeSummary = narrativeSummary
        self.intentClusters = intentClusters
        self.conversationBreadcrumbs = conversationBreadcrumbs
        self.cognitiveHealth = cognitiveHealth
        self.metadata = metadata
    }
    
    static let empty = AIPayloadContext()
}

struct ConversationBreadcrumbs: Sendable {
    let lastEmotion: String?
    let lastTopic: String?
    let lastUpdated: Date?
}

/// Focus session context for AI payload
struct FocusSessionContext: Sendable {
    let isActive: Bool
    let objective: String?
    let elapsedMinutes: Int?
    let remainingMinutes: Int?
    let recentSessionCount: Int
    let completionRate: Double
    let totalFocusHoursThisWeek: Int
}

struct RecallSnippet: Identifiable, Hashable, Sendable {
    let id: UUID
    let objectId: UUID
    let objectType: RecallObjectType
    let title: String
    let detail: String
    let score: Double
    let lastUpdated: Date
    let lastViewedAt: Date
    let emotion: String
    let emotionScore: Double
    let emotionIntensity: Double
    let emotionKeywords: [String]
    
    init(entry: RecallIndexEntry, score: Double) {
        self.id = entry.objectId
        self.objectId = entry.objectId
        self.objectType = RecallObjectType(rawValue: entry.objectType) ?? .unknown
        self.title = entry.title
        self.detail = entry.detail
        self.score = score
        self.lastUpdated = entry.lastUpdatedAt
        self.lastViewedAt = entry.lastViewedAt
        self.emotion = entry.emotion ?? ""
        self.emotionScore = entry.emotionScore
        self.emotionIntensity = entry.emotionIntensity
        self.emotionKeywords = entry.emotionKeywords
    }
}

struct PriorityItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let objectId: UUID  // Added for CPS system
    let title: String
    let score: Double
    let objectType: String
    let detail: String
    
    init(id: UUID = UUID(), objectId: UUID, title: String, score: Double, objectType: String, detail: String) {
        self.id = id
        self.objectId = objectId
        self.title = title
        self.score = score
        self.objectType = objectType
        self.detail = detail
    }
}

struct FeedbackSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let detail: String
    let timestamp: Date
    
    init(id: UUID = UUID(), title: String, detail: String, timestamp: Date = Date()) {
        self.id = id
        self.title = title
        self.detail = detail
        self.timestamp = timestamp
    }
}

// MARK: - Recall Core

enum RecallInteraction {
    case created
    case viewed
    case updated
}

enum RecallObjectType: String, Codable, Sendable {
    case task
    case project
    case post
    case note
    case artifact
    case draft
    case inbox
    case image
    case document
    case reminder
    case unknown
    
    var displayName: String {
        switch self {
        case .task: return "Task"
        case .project: return "Project"
        case .post: return "Post"
        case .note: return "Note"
        case .artifact: return "Artifact"
        case .draft: return "Draft"
        case .inbox: return "Inbox"
        case .image: return "Image"
        case .document: return "Document"
        case .reminder: return "Reminder"
        case .unknown: return "Item"
        }
    }
}

protocol RecallTrackable {
    var recallObjectId: UUID { get }
    var recallObjectType: RecallObjectType { get }
    var recallTitle: String { get }
    var recallDetail: String { get }
    var recallUpdatedAt: Date { get }
    var recallImportance: Double { get }
    var recallKeywords: [String] { get }
}

@Model
final class RecallIndexEntry {
    var id: UUID = UUID()
    @Attribute(.unique) var objectId: UUID
    var objectType: String
    var title: String
    var detail: String
    var keywords: [String]
    var accessCount: Int
    var lastViewedAt: Date
    var lastUpdatedAt: Date
    var importance: Double
    var emotion: String?
    var emotionScore: Double
    var emotionIntensity: Double
    var emotionKeywords: [String]
    var engagementScore: Double = 0.0
    var lastEngagementAt: Date?
    
    init(
        objectId: UUID,
        objectType: RecallObjectType,
        title: String,
        detail: String,
        keywords: [String],
        accessCount: Int = 1,
        lastViewedAt: Date = Date(),
        lastUpdatedAt: Date,
        importance: Double,
        emotion: String? = nil,
        emotionScore: Double = 0.0,
        emotionIntensity: Double = 0.0,
        emotionKeywords: [String] = [],
        engagementScore: Double = 0.0,
        lastEngagementAt: Date? = nil
    ) {
        self.objectId = objectId
        self.objectType = objectType.rawValue
        self.title = title
        self.detail = detail
        self.keywords = keywords
        self.accessCount = accessCount
        self.lastViewedAt = lastViewedAt
        self.lastUpdatedAt = lastUpdatedAt
        self.importance = importance
        self.emotion = emotion
        self.emotionScore = emotionScore
        self.emotionIntensity = emotionIntensity
        self.emotionKeywords = emotionKeywords
        self.engagementScore = engagementScore
        self.lastEngagementAt = lastEngagementAt
    }
    
    func score(using weights: AIConfig.RecallWeights, referenceDate: Date = Date()) -> Double {
        let elapsed = referenceDate.timeIntervalSince(lastViewedAt)
        let decayWindow = max(1.0, weights.recencyHalfLifeHours * 3600.0)
        let recencyScore = clamp(1.0 - (elapsed / decayWindow))
        let frequencyScore = clamp(Double(accessCount) / max(1.0, weights.frequencyNormalizationFactor))
        let clampedImportance = clamp(importance)

        let baseScore = (weights.recencyWeight * recencyScore)
        + (weights.frequencyWeight * frequencyScore)
        + (weights.importanceWeight * clampedImportance)

        let ageDays = max(0.0, referenceDate.timeIntervalSince(lastUpdatedAt) / (60 * 60 * 24))
        let decayedImportance = clampedImportance * exp(-ageDays / 90.0)
        let importanceMultiplier = max(0.25, decayedImportance)

        let engagementMultiplier = self.engagementMultiplier(referenceDate: referenceDate)
        let emotionalMultiplier = self.emotionalMultiplier

        let finalScore = baseScore * importanceMultiplier * engagementMultiplier * emotionalMultiplier
        return clamp(finalScore)
    }
    
    func matches(query: String) -> Bool {
        guard !query.isEmpty else { return true }
        let haystack = (title + " " + detail + " " + keywords.joined(separator: " ")).lowercased()
        let normalizedQuery = query.lowercased()
        if haystack.contains(normalizedQuery) {
            return true
        }
        let tokens = normalizedQuery.split(separator: " ")
        return tokens.isEmpty || tokens.allSatisfy { haystack.contains($0) }
    }

    func registerEngagement(increment: Double, timestamp: Date) {
        guard increment > 0 else { return }
        let decayed = decayedEngagement(at: timestamp)
        engagementScore = min(1.0, decayed + increment)
        lastEngagementAt = timestamp
    }

    private func decayedEngagement(at referenceDate: Date) -> Double {
        guard engagementScore > 0 else { return 0 }
        let last = lastEngagementAt ?? lastViewedAt
        let elapsed = max(0.0, referenceDate.timeIntervalSince(last))
        if elapsed == 0 { return engagementScore }
        let halfLife: TimeInterval = 14 * 24 * 60 * 60
        let decayFactor = pow(0.5, elapsed / halfLife)
        return engagementScore * decayFactor
    }

    private func engagementMultiplier(referenceDate: Date) -> Double {
        let effective = decayedEngagement(at: referenceDate)
        guard effective > 0 else { return 1.0 }
        return 1.0 + min(0.5, effective)
    }

    private var emotionalMultiplier: Double {
        if abs(emotionScore) > 0.6 || emotionIntensity > 0.6 {
            return 1.2
        }
        if abs(emotionScore) > 0.3 || emotionIntensity > 0.3 {
            return 1.1
        }
        return 1.0
    }

    private func clamp(_ value: Double) -> Double {
        max(0.0, min(1.0, value))
    }
}

// MARK: - AI Config Layer

struct AIConfig {
    struct RecallWeights {
        let recencyWeight: Double
        let frequencyWeight: Double
        let importanceWeight: Double
        let recencyHalfLifeHours: Double
        let frequencyNormalizationFactor: Double
    }
    
    struct CPSWeights {
        let recency: Double
        let frequency: Double
        let connections: Double
        let aiMentions: Double
        let manualBoost: Double
    }
    
    struct FeatureFlags {
        let recallEnabled: Bool
        let actionRouterEnabled: Bool
        let cpsEnabled: Bool
        let focusModeEnabled: Bool
        let narrativeEnabled: Bool
        let memoryGraphEnabled: Bool
        let feedbackLoggingEnabled: Bool
    }
    
    let recallWeights: RecallWeights
    let cpsWeights: CPSWeights?
    let featureFlags: FeatureFlags
    
    static let `default` = AIConfig(
        recallWeights: RecallWeights(
            recencyWeight: 0.5,
            frequencyWeight: 0.3,
            importanceWeight: 0.2,
            recencyHalfLifeHours: 36,
            frequencyNormalizationFactor: 8
        ),
        cpsWeights: CPSWeights(
            recency: 0.3,
            frequency: 0.25,
            connections: 0.25,
            aiMentions: 0.15,
            manualBoost: 0.05
        ),
        featureFlags: FeatureFlags(
            recallEnabled: true,
            actionRouterEnabled: true,
            cpsEnabled: true,
            focusModeEnabled: false,
            narrativeEnabled: false,
            memoryGraphEnabled: false,
            feedbackLoggingEnabled: true
        )
    )
}

@MainActor
final class AIConfigService {
    static let shared = AIConfigService()
    
    private(set) var config: AIConfig = .default
    
    private init() {
        config = loadConfig()
    }
    
    func reload() {
        config = loadConfig()
    }
    
    private func loadConfig() -> AIConfig {
        guard let url = Bundle.main.url(forResource: "AIConfig", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let rawPlist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = rawPlist as? [String: Any] else {
            return .default
        }
        
        let recallDict = dict["RecallWeights"] as? [String: Any] ?? [:]
        let cpsDict = dict["CPSWeights"] as? [String: Any] ?? [:]
        let featureDict = dict["FeatureFlags"] as? [String: Any] ?? [:]
        
        let recallWeights = AIConfig.RecallWeights(
            recencyWeight: recallDict["recencyWeight"] as? Double ?? AIConfig.default.recallWeights.recencyWeight,
            frequencyWeight: recallDict["frequencyWeight"] as? Double ?? AIConfig.default.recallWeights.frequencyWeight,
            importanceWeight: recallDict["importanceWeight"] as? Double ?? AIConfig.default.recallWeights.importanceWeight,
            recencyHalfLifeHours: recallDict["recencyHalfLifeHours"] as? Double ?? AIConfig.default.recallWeights.recencyHalfLifeHours,
            frequencyNormalizationFactor: recallDict["frequencyNormalizationFactor"] as? Double ?? AIConfig.default.recallWeights.frequencyNormalizationFactor
        )
        
        let cpsWeights: AIConfig.CPSWeights?
        if !cpsDict.isEmpty {
            cpsWeights = AIConfig.CPSWeights(
                recency: cpsDict["recency"] as? Double ?? AIConfig.default.cpsWeights!.recency,
                frequency: cpsDict["frequency"] as? Double ?? AIConfig.default.cpsWeights!.frequency,
                connections: cpsDict["connections"] as? Double ?? AIConfig.default.cpsWeights!.connections,
                aiMentions: cpsDict["aiMentions"] as? Double ?? AIConfig.default.cpsWeights!.aiMentions,
                manualBoost: cpsDict["manualBoost"] as? Double ?? AIConfig.default.cpsWeights!.manualBoost
            )
        } else {
            cpsWeights = AIConfig.default.cpsWeights
        }
        
        let featureFlags = AIConfig.FeatureFlags(
            recallEnabled: featureDict["AIRecallEnabled"] as? Bool ?? AIConfig.default.featureFlags.recallEnabled,
            actionRouterEnabled: featureDict["AIActionRouterEnabled"] as? Bool ?? AIConfig.default.featureFlags.actionRouterEnabled,
            cpsEnabled: featureDict["AICPSEnabled"] as? Bool ?? AIConfig.default.featureFlags.cpsEnabled,
            focusModeEnabled: featureDict["AIFocusModeEnabled"] as? Bool ?? AIConfig.default.featureFlags.focusModeEnabled,
            narrativeEnabled: featureDict["AINarrativeEnabled"] as? Bool ?? AIConfig.default.featureFlags.narrativeEnabled,
            memoryGraphEnabled: featureDict["AIMemoryGraphEnabled"] as? Bool ?? AIConfig.default.featureFlags.memoryGraphEnabled,
            feedbackLoggingEnabled: featureDict["AIFeedbackLoggingEnabled"] as? Bool ?? AIConfig.default.featureFlags.feedbackLoggingEnabled
        )
        
        return AIConfig(recallWeights: recallWeights, cpsWeights: cpsWeights, featureFlags: featureFlags)
    }
}

// MARK: - Telemetry

enum AIDebug {
    private static let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "AI")
    
    static func log(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }
}

// MARK: - Recall Service

@MainActor
final class AIRecallService {
    static let shared = AIRecallService()
    
    private var cache: [UUID: RecallIndexEntry] = [:]
    private var lastCacheRefresh: Date?
    private let cacheValidity: TimeInterval = 15 * 60
    private var lastDecayRun: Date?
    private var lastPruneRun: Date?
    
    private init() {}
    
    private var config: AIConfig { AIConfigService.shared.config }
    
    func recordSnapshot(
        tasks: [Task],
        projects: [Project],
        posts: [Post],
        notes: [Note],
        drafts: [Draft] = [],
        modelContext: ModelContext
    ) {
        guard config.featureFlags.recallEnabled else { return }
        
        var items: [any RecallTrackable] = []
        items.append(contentsOf: tasks.map { $0 as any RecallTrackable })
        items.append(contentsOf: projects.map { $0 as any RecallTrackable })
        items.append(contentsOf: posts.map { $0 as any RecallTrackable })
        items.append(contentsOf: notes.map { $0 as any RecallTrackable })
        items.append(contentsOf: drafts.map { $0 as any RecallTrackable })
        
        register(objects: items, interaction: .viewed, modelContext: modelContext)
    }
    
    func registerCreated(_ object: any RecallTrackable, modelContext: ModelContext) {
        guard config.featureFlags.recallEnabled else { return }
        register(objects: [object], interaction: .created, modelContext: modelContext)
        
        // Update CPS for created object
        PriorityEngine.shared.updateScore(
            for: object.recallObjectId,
            objectType: object.recallObjectType.rawValue,
            modelContext: modelContext,
            incrementAccess: true
        )
        
        // Automatically create memory graph node if feature is enabled
        if config.featureFlags.memoryGraphEnabled {
            _Concurrency.Task { @MainActor in
                do {
                    _ = try await MemoryGraphService.shared.findOrCreateNode(for: object, modelContext: modelContext)
                    AIDebug.log("MemoryGraph: Auto-created node for \(object.recallObjectType.rawValue) '\(object.recallTitle)'")
                } catch {
                    AIDebug.log("MemoryGraph: Failed to auto-create node: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func registerUpdated(_ object: any RecallTrackable, modelContext: ModelContext) {
        guard config.featureFlags.recallEnabled else { return }
        register(objects: [object], interaction: .updated, modelContext: modelContext)
        
        // Update CPS for updated object
        PriorityEngine.shared.updateScore(
            for: object.recallObjectId,
            objectType: object.recallObjectType.rawValue,
            modelContext: modelContext,
            incrementAccess: false
        )
    }
    
    func fetchRelevantSnippets(
        for query: String,
        limit: Int = 5,
        modelContext: ModelContext,
        shouldRegisterView: Bool = true,
        mode: ConversationMode = .operational
    ) -> [RecallSnippet] {
        guard config.featureFlags.recallEnabled else { return [] }
        
        refreshCacheIfNeeded(modelContext: modelContext)
        
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = Date()
        let weights = config.recallWeights
        
        let entries: [RecallIndexEntry]
        if cache.isEmpty {
            let descriptor = FetchDescriptor<RecallIndexEntry>()
            entries = (try? modelContext.fetch(descriptor)) ?? []
            for entry in entries {
                cache[entry.objectId] = entry
            }
        } else {
            entries = Array(cache.values)
        }
        
        // Filter and score based on conversation mode
        let filteredEntries = filterEntriesByMode(entries, mode: mode, modelContext: modelContext)
        
        let scored = filteredEntries
            .filter { $0.matches(query: normalizedQuery) }
            .map { entry -> (score: Double, entry: RecallIndexEntry) in
                let base = entry.score(using: weights, referenceDate: now)
                var queryBoost = 0.0
                if !normalizedQuery.isEmpty {
                    let tokens = normalizedQuery.lowercased().split(separator: " ")
                    if tokens.allSatisfy({ entry.title.lowercased().contains($0) }) {
                        queryBoost = 0.1
                    }
                }
                
                // Mode-specific boosting
                let modeBoost = calculateModeBoost(entry: entry, mode: mode, modelContext: modelContext)
                
                return (min(1.0, base + queryBoost + modeBoost), entry)
            }
            .sorted { $0.score > $1.score }
        
        let top = scored.prefix(limit)
        var didChange = false
        var objectIdsForCPS: [UUID] = []
        
        if shouldRegisterView {
            for item in top {
                item.entry.accessCount += 1
                item.entry.lastViewedAt = now
                cache[item.entry.objectId] = item.entry
                objectIdsForCPS.append(item.entry.objectId)
                didChange = true
                AIDebug.log("Recall updated for object \(item.entry.objectId.uuidString)")
            }
        }
        
        if didChange {
            do {
                try modelContext.save()
            } catch {
                AIDebug.log("Failed to persist recall updates: \(error.localizedDescription)")
            }
        }
        
        // Update CPS for AI-surfaced objects
        if !objectIdsForCPS.isEmpty {
            PriorityEngine.shared.recordAIMention(for: objectIdsForCPS, modelContext: modelContext)
        }
        
        return top.map { RecallSnippet(entry: $0.entry, score: $0.score) }
    }
    
    /// Filter entries based on conversation mode
    private func filterEntriesByMode(
        _ entries: [RecallIndexEntry],
        mode: ConversationMode,
        modelContext: ModelContext
    ) -> [RecallIndexEntry] {
        switch mode {
        case .reflective:
            // Prefer journal entries, notes, and reflections
            return entries.filter { entry in
                entry.objectType == "document" || entry.objectType == "note" || entry.objectType == "artifact"
            }
        case .operational:
            // Prefer tasks, projects, and actionable items
            return entries.filter { entry in
                entry.objectType == "task" || entry.objectType == "project" || entry.objectType == "reminder"
            }
        case .creative:
            // Prefer notes, drafts, and posts for cross-pollination
            return entries.filter { entry in
                entry.objectType == "note" || entry.objectType == "draft" || entry.objectType == "post" || entry.objectType == "artifact"
            }
        }
    }
    
    /// Calculate mode-specific boost for entries
    private func calculateModeBoost(
        entry: RecallIndexEntry,
        mode: ConversationMode,
        modelContext: ModelContext
    ) -> Double {
        switch mode {
        case .reflective:
            // Boost entries with emotional content
            if abs(entry.emotionScore) > 0.3 || entry.emotionIntensity > 0.3 {
                return 0.15
            }
            return 0.0
        case .operational:
            // Boost high-importance items
            if entry.importance > 0.7 {
                return 0.1
            }
            return 0.0
        case .creative:
            // Boost entries with many keywords (rich content)
            if entry.keywords.count > 5 {
                return 0.12
            }
            return 0.0
        }
    }
    
    /// Fetch relevant snippets with temporal context
    func fetchRelevantSnippetsWithTemporalContext(
        for query: String,
        limit: Int = 5,
        modelContext: ModelContext,
        mode: ConversationMode = .operational
    ) -> [RecallSnippetWithTemporalContext] {
        let snippets = fetchRelevantSnippets(
            for: query,
            limit: limit,
            modelContext: modelContext,
            mode: mode
        )
        
        return snippets.map { snippet in
            let temporalContext = generateTemporalContext(for: snippet, modelContext: modelContext)
            return RecallSnippetWithTemporalContext(
                snippet: snippet,
                temporalContext: temporalContext
            )
        }
    }
    
    /// Generate temporal context for a snippet
    private func generateTemporalContext(
        for snippet: RecallSnippet,
        modelContext: ModelContext
    ) -> String {
        let daysSinceUpdate = Calendar.current.dateComponents([.day], from: snippet.lastUpdated, to: Date()).day ?? 0
        
        if daysSinceUpdate == 0 {
            return "Updated today"
        } else if daysSinceUpdate == 1 {
            return "Updated yesterday"
        } else if daysSinceUpdate < 7 {
            return "Updated \(daysSinceUpdate) days ago"
        } else if daysSinceUpdate < 30 {
            let weeks = daysSinceUpdate / 7
            return "Updated \(weeks) week\(weeks == 1 ? "" : "s") ago"
        } else if daysSinceUpdate < 365 {
            let months = daysSinceUpdate / 30
            return "Last mentioned \(months) month\(months == 1 ? "" : "s") ago"
        } else {
            return "From your archive"
        }
    }
    
    func allEntries(modelContext: ModelContext) -> [RecallIndexEntry] {
        guard config.featureFlags.recallEnabled else { return [] }
        refreshCacheIfNeeded(modelContext: modelContext)
        if cache.isEmpty {
            let descriptor = FetchDescriptor<RecallIndexEntry>()
            let entries = (try? modelContext.fetch(descriptor)) ?? []
            for entry in entries {
                cache[entry.objectId] = entry
            }
            return entries
        }
        return Array(cache.values)
    }
    
    func boostImportance(
        for objectIDs: [UUID],
        amount: Double = 0.05,
        engagementIncrement: Double = 0.0,
        modelContext: ModelContext
    ) {
        guard config.featureFlags.recallEnabled, !objectIDs.isEmpty else { return }
        refreshCacheIfNeeded(modelContext: modelContext)
        
        var didChange = false
        let now = Date()
        
        for objectID in objectIDs {
            guard let entry = entry(for: objectID, modelContext: modelContext) else { continue }
            let newImportance = min(1.0, entry.importance + amount)
            if newImportance != entry.importance {
                entry.importance = newImportance
                didChange = true
            }
            entry.lastViewedAt = now
            if engagementIncrement > 0 {
                entry.registerEngagement(increment: engagementIncrement, timestamp: now)
            }
            cache[objectID] = entry
            AIDebug.log("Recall importance boosted for \(objectID.uuidString)")
        }
        
        if didChange {
            do {
                try modelContext.save()
            } catch {
                AIDebug.log("Failed to persist recall boost: \(error.localizedDescription)")
            }
        }
    }
    
    func removeObjects(withIDs objectIDs: [UUID], modelContext: ModelContext) {
        guard config.featureFlags.recallEnabled, !objectIDs.isEmpty else { return }
        let ids = Set(objectIDs)
        let descriptor = FetchDescriptor<RecallIndexEntry>(
            predicate: #Predicate { ids.contains($0.objectId) }
        )
        if let entries = try? modelContext.fetch(descriptor) {
            for entry in entries {
                modelContext.delete(entry)
                cache.removeValue(forKey: entry.objectId)
            }
            do {
                try modelContext.save()
            } catch {
                AIDebug.log("Failed to remove recall entries: \(error.localizedDescription)")
            }
        }
        
        // Remove CPS scores for deleted objects
        PriorityEngine.shared.removeScores(for: Array(objectIDs), modelContext: modelContext)
    }
    
    func indexImageAnalysis(
        userMessage: AIMessage,
        analysis: String,
        modelContext: ModelContext
    ) {
        guard config.featureFlags.recallEnabled else { return }
        refreshCacheIfNeeded(modelContext: modelContext)
        let trimmedAnalysis = analysis.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAnalysis.isEmpty else { return }
        let timestamp = userMessage.timestamp ?? Date()
        let objectId = userMessage.id
        let emotionalSnapshot = EmotionAnalyzer.analyzeTone(text: trimmedAnalysis)
        let title = makeImageTitle(from: userMessage, analysis: trimmedAnalysis)
        let detail = truncatedText(trimmedAnalysis, limit: 240)
        let keywords = extractImageKeywords(from: trimmedAnalysis)
        let importanceBaseline = 0.35
        let existingEntry = entry(for: objectId, modelContext: modelContext)
        let entry = existingEntry ?? RecallIndexEntry(
            objectId: objectId,
            objectType: .image,
            title: title,
            detail: detail,
            keywords: keywords,
            accessCount: 0,
            lastViewedAt: timestamp,
            lastUpdatedAt: timestamp,
            importance: importanceBaseline,
            emotion: emotionalSnapshot.primaryEmotion.rawValue,
            emotionScore: emotionalSnapshot.valence,
            emotionIntensity: emotionalSnapshot.intensity,
            emotionKeywords: emotionalSnapshot.keywords
        )
        entry.title = title
        entry.detail = detail
        entry.keywords = keywords
        entry.lastViewedAt = timestamp
        entry.lastUpdatedAt = timestamp
        entry.importance = max(entry.importance, importanceBaseline)
        entry.emotion = emotionalSnapshot.primaryEmotion.rawValue
        entry.emotionScore = emotionalSnapshot.valence
        entry.emotionIntensity = emotionalSnapshot.intensity
        entry.emotionKeywords = emotionalSnapshot.keywords
        if existingEntry == nil {
            modelContext.insert(entry)
        }
        cache[objectId] = entry
        ConceptTracker.shared.trackConcepts(
            in: trimmedAnalysis,
            fromObjectId: objectId,
            contextType: RecallObjectType.image.rawValue,
            modelContext: modelContext
        )
        do {
            try modelContext.save()
        } catch {
            AIDebug.log("Failed to index image analysis: \(error.localizedDescription)")
        }
    }

    func indexDocumentSummary(
        userMessage: AIMessage,
        summary: String,
        modelContext: ModelContext
    ) {
        guard config.featureFlags.recallEnabled else { return }
        refreshCacheIfNeeded(modelContext: modelContext)
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSummary.isEmpty else { return }
        let timestamp = userMessage.timestamp ?? Date()
        let objectId = userMessage.id
        let emotionalSnapshot = EmotionAnalyzer.analyzeTone(text: trimmedSummary)
        let title = makeDocumentTitle(from: userMessage, summary: trimmedSummary)
        let detail = truncatedText(trimmedSummary, limit: 240)
        let keywords = extractDocumentKeywords(from: trimmedSummary, fileName: userMessage.documentFileName)
        let importanceBaseline = 0.4
        let existingEntry = entry(for: objectId, modelContext: modelContext)
        let entry = existingEntry ?? RecallIndexEntry(
            objectId: objectId,
            objectType: .document,
            title: title,
            detail: detail,
            keywords: keywords,
            accessCount: 0,
            lastViewedAt: timestamp,
            lastUpdatedAt: timestamp,
            importance: importanceBaseline,
            emotion: emotionalSnapshot.primaryEmotion.rawValue,
            emotionScore: emotionalSnapshot.valence,
            emotionIntensity: emotionalSnapshot.intensity,
            emotionKeywords: emotionalSnapshot.keywords
        )
        entry.title = title
        entry.detail = detail
        entry.keywords = keywords
        entry.lastViewedAt = timestamp
        entry.lastUpdatedAt = timestamp
        entry.importance = max(entry.importance, importanceBaseline)
        entry.emotion = emotionalSnapshot.primaryEmotion.rawValue
        entry.emotionScore = emotionalSnapshot.valence
        entry.emotionIntensity = emotionalSnapshot.intensity
        entry.emotionKeywords = emotionalSnapshot.keywords
        if existingEntry == nil {
            modelContext.insert(entry)
        }
        cache[objectId] = entry
        ConceptTracker.shared.trackConcepts(
            in: trimmedSummary,
            fromObjectId: objectId,
            contextType: RecallObjectType.document.rawValue,
            modelContext: modelContext
        )
        do {
            try modelContext.save()
        } catch {
            AIDebug.log("Failed to index document summary: \(error.localizedDescription)")
        }
    }
    
    private func register(
        objects: [any RecallTrackable],
        interaction: RecallInteraction,
        modelContext: ModelContext
    ) {
        guard !objects.isEmpty else { return }
        refreshCacheIfNeeded(modelContext: modelContext)
        
        let now = Date()
        var didChange = false
        
        for object in objects {
            didChange = upsert(object: object, interaction: interaction, timestamp: now, modelContext: modelContext) || didChange
        }
        
        if didChange {
            do {
                try modelContext.save()
            } catch {
                AIDebug.log("Failed to save recall index: \(error.localizedDescription)")
            }
        }
    }
    
    private func upsert(
        object: any RecallTrackable,
        interaction: RecallInteraction,
        timestamp: Date,
        modelContext: ModelContext
    ) -> Bool {
        // Analyze emotional tone of the content
        let contentForAnalysis = "\(object.recallTitle) \(object.recallDetail)"
        let emotionalSnapshot = EmotionAnalyzer.analyzeTone(text: contentForAnalysis)
        
        let existingEntry = entry(for: object.recallObjectId, modelContext: modelContext)
        let isNew = existingEntry == nil
        let entry = existingEntry ?? RecallIndexEntry(
            objectId: object.recallObjectId,
            objectType: object.recallObjectType,
            title: object.recallTitle,
            detail: truncatedText(object.recallDetail),
            keywords: object.recallKeywords,
            accessCount: 0,
            lastViewedAt: timestamp,
            lastUpdatedAt: object.recallUpdatedAt,
            importance: object.recallImportance,
            emotion: emotionalSnapshot.primaryEmotion.rawValue,
            emotionScore: emotionalSnapshot.valence,
            emotionIntensity: emotionalSnapshot.intensity,
            emotionKeywords: emotionalSnapshot.keywords
        )
        
        switch interaction {
        case .created:
            entry.accessCount = max(1, entry.accessCount + 1)
            entry.registerEngagement(increment: 0.12, timestamp: timestamp)
            // Track concepts on creation
            ConceptTracker.shared.trackConcepts(
                in: contentForAnalysis,
                fromObjectId: object.recallObjectId,
                contextType: object.recallObjectType.rawValue,
                modelContext: modelContext
            )
        case .viewed:
            entry.accessCount += 1
        case .updated:
            entry.lastUpdatedAt = object.recallUpdatedAt
            // Re-analyze emotion on update
            entry.emotion = emotionalSnapshot.primaryEmotion.rawValue
            entry.emotionScore = emotionalSnapshot.valence
            entry.emotionIntensity = emotionalSnapshot.intensity
            entry.emotionKeywords = emotionalSnapshot.keywords
            entry.registerEngagement(increment: 0.08, timestamp: timestamp)
            // Re-track concepts on update
            ConceptTracker.shared.trackConcepts(
                in: contentForAnalysis,
                fromObjectId: object.recallObjectId,
                contextType: object.recallObjectType.rawValue,
                modelContext: modelContext
            )
        }
        
        entry.title = object.recallTitle
        entry.detail = truncatedText(object.recallDetail)
        entry.keywords = object.recallKeywords
        entry.importance = object.recallImportance
        entry.lastViewedAt = timestamp
        
        if isNew {
            modelContext.insert(entry)
        }
        
        cache[entry.objectId] = entry
        AIDebug.log("Recall updated for object \(entry.objectId.uuidString) with emotion \(emotionalSnapshot.primaryEmotion.rawValue)")
        return true
    }
    
    private func entry(for objectId: UUID, modelContext: ModelContext) -> RecallIndexEntry? {
        if let cached = cache[objectId] {
            return cached
        }
        
        var descriptor = FetchDescriptor<RecallIndexEntry>(
            predicate: #Predicate { $0.objectId == objectId }
        )
        descriptor.fetchLimit = 1
        
        if let results = try? modelContext.fetch(descriptor),
           let entry = results.first {
            cache[objectId] = entry
            return entry
        }
        return nil
    }
    
    private func refreshCacheIfNeeded(modelContext: ModelContext) {
        guard cache.isEmpty || (lastCacheRefresh == nil || Date().timeIntervalSince(lastCacheRefresh ?? .distantPast) > cacheValidity) else {
            return
        }
        
        let descriptor = FetchDescriptor<RecallIndexEntry>()
        if let entries = try? modelContext.fetch(descriptor) {
            cache = Dictionary(uniqueKeysWithValues: entries.map { ($0.objectId, $0) })
            lastCacheRefresh = Date()
        }
        applyAmbientDecayIfNeeded(modelContext: modelContext)
    }
}

// MARK: - Recall Helpers

private enum RecallFormatters {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
}

private func truncatedText(_ text: String, limit: Int = 120) -> String {
    guard text.count > limit else { return text }
    let index = text.index(text.startIndex, offsetBy: limit)
    let prefix = text[text.startIndex..<index]
    return String(prefix) + "…"
}

private func makeImageTitle(from message: AIMessage, analysis: String) -> String {
    if let fileName = message.imageFileName?.trimmingCharacters(in: .whitespacesAndNewlines), !fileName.isEmpty {
        return "Image: \(fileName)"
    }
    let summary = analysis.split(whereSeparator: { ".!?".contains($0) }).first.map(String.init) ?? analysis
    let cleaned = summary.trimmingCharacters(in: .whitespacesAndNewlines)
    let snippet = cleaned.isEmpty ? "Attachment" : truncatedText(cleaned, limit: 60)
    return "Image: \(snippet)"
}

private func makeDocumentTitle(from message: AIMessage, summary: String) -> String {
    if let fileName = message.documentFileName?.trimmingCharacters(in: .whitespacesAndNewlines), !fileName.isEmpty {
        return "Document: \(fileName)"
    }
    let leadSentence = summary.split(whereSeparator: { ".!?".contains($0) }).first.map(String.init) ?? summary
    let cleaned = leadSentence.trimmingCharacters(in: .whitespacesAndNewlines)
    let snippet = cleaned.isEmpty ? "Attachment" : truncatedText(cleaned, limit: 60)
    return "Document: \(snippet)"
}

private func extractImageKeywords(from text: String, limit: Int = 8) -> [String] {
    let stopWords: Set<String> = [
        "this", "that", "with", "from", "have", "about", "there", "their", "which", "while",
        "where", "what", "when", "your", "into", "over", "under", "through", "many", "some",
        "really", "looks", "looking", "thing", "things", "it's", "its", "just", "like", "them",
        "they", "you're", "you", "here", "there's"
    ]
    let separators = CharacterSet.alphanumerics.inverted
    let tokens = text
        .lowercased()
        .components(separatedBy: separators)
        .filter { $0.count > 3 && !stopWords.contains($0) }
    var seen: Set<String> = []
    var keywords: [String] = []
    for token in tokens {
        if !seen.contains(token) {
            seen.insert(token)
            keywords.append(token)
        }
        if keywords.count >= limit { break }
    }
    return keywords
}

private func extractDocumentKeywords(from text: String, fileName: String?, limit: Int = 10) -> [String] {
    var stopWords: Set<String> = [
        "this", "that", "with", "from", "have", "about", "there", "their", "which", "while",
        "where", "what", "when", "your", "into", "over", "under", "through", "many", "some",
        "really", "just", "like", "them", "they", "you're", "you", "here", "there's", "document",
        "summary", "section", "chapter", "pages", "page", "report", "notes", "file"
    ]
    let separators = CharacterSet.alphanumerics.inverted
    var tokens: [String] = []
    if let fileName = fileName?.lowercased(), !fileName.isEmpty {
        let normalized = fileName.replacingOccurrences(of: ".", with: " ")
        tokens.append(contentsOf: normalized.components(separatedBy: separators))
    }
    tokens.append(contentsOf: text.lowercased().components(separatedBy: separators))
    let filtered = tokens.filter { token in
        let cleaned = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.count > 3 && !stopWords.contains(cleaned)
    }
    var seen: Set<String> = []
    var keywords: [String] = []
    for token in filtered {
        if !seen.contains(token) {
            seen.insert(token)
            keywords.append(token)
        }
        if keywords.count >= limit { break }
    }
    return keywords
}

// MARK: - Model Conformances

extension Task: RecallTrackable {
    var recallObjectId: UUID { id }
    var recallObjectType: RecallObjectType { .task }
    var recallTitle: String { title }
    var recallDetail: String {
        if let notes, !notes.isEmpty {
            return notes
        }
        if let dueDate {
            return "Due \(RecallFormatters.shortDate.string(from: dueDate))"
        }
        return "Task status: \(status.displayName)"
    }
    var recallUpdatedAt: Date { updatedAt }
    var recallImportance: Double {
        switch priority {
        case .high: return 1.0
        case .medium: return 0.6
        case .low: return 0.3
        }
    }
    var recallKeywords: [String] {
        var values: [String] = [status.displayName.lowercased(), priority.displayName.lowercased()]
        if let dueDate {
            values.append(RecallFormatters.shortDate.string(from: dueDate))
        }
        return values
    }
}

extension Project: RecallTrackable {
    var recallObjectId: UUID { id }
    var recallObjectType: RecallObjectType { .project }
    var recallTitle: String { title }
    var recallDetail: String {
        if let goal, !goal.isEmpty {
            return goal
        }
        if let dueDate {
            return "Due \(RecallFormatters.shortDate.string(from: dueDate))"
        }
        return "Project status: \(status.displayName)"
    }
    var recallUpdatedAt: Date { updatedAt }
    var recallImportance: Double { status == .active ? 0.8 : 0.4 }
    var recallKeywords: [String] {
        var values = tags.map { $0.lowercased() }
        values.append(status.displayName.lowercased())
        if let dueDate {
            values.append(RecallFormatters.shortDate.string(from: dueDate))
        }
        return values
    }
}

extension Note: RecallTrackable {
    var recallObjectId: UUID { id }
    var recallObjectType: RecallObjectType { .note }
    var recallTitle: String { title }
    var recallDetail: String {
        if !markdown.isEmpty {
            return markdown
        }
        if !highlights.isEmpty {
            return highlights.joined(separator: " • ")
        }
        return "Note (\(type.rawValue))"
    }
    var recallUpdatedAt: Date { updatedAt }
    var recallImportance: Double { isArchived ? 0.2 : 0.6 }
    var recallKeywords: [String] {
        var values = tags.map { $0.lowercased() }
        if let source {
            values.append(source.lowercased())
        }
        values.append(type.rawValue.lowercased())
        return values
    }
}

extension Artifact: RecallTrackable {
    var recallObjectId: UUID { id }
    var recallObjectType: RecallObjectType { .artifact }
    var recallTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return format.displayName
    }
    var recallDetail: String {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedContent.isEmpty {
            return String(trimmedContent.prefix(400))
        }
        return "Artifact (\(format.displayName))"
    }
    var recallUpdatedAt: Date { updatedAt }
    var recallImportance: Double {
        switch artifactState {
        case .idea: return 0.3
        case .draft: return 0.5
        case .final: return 0.7
        case .published: return 0.8
        case .archived: return 0.2
        }
    }
    var recallKeywords: [String] {
        var values = tags.map { $0.lowercased() }
        values.append(format.rawValue.lowercased())
        values.append(artifactState.rawValue.lowercased())
        if let projectId {
            values.append(projectId.uuidString)
        }
        return values
    }
}

extension Journal: RecallTrackable {
    var recallObjectId: UUID { id }
    var recallObjectType: RecallObjectType { .document }
    var recallTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Journal Entry" : trimmed
    }
    var recallDetail: String {
        if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return content
        }
        if let summary = aiGeneratedContent, !summary.isEmpty {
            return summary
        }
        return "Journal entry (\(journalEntryType.rawValue))"
    }
    var recallUpdatedAt: Date { updatedAt }
    var recallImportance: Double {
        journalMood == .none ? 0.4 : 0.7
    }
    var recallKeywords: [String] {
        var values = tags.map { $0.lowercased() }
        values.append(journalMood.rawValue.lowercased())
        values.append(journalEntryType.rawValue.lowercased())
        return values
    }
}

extension Draft: RecallTrackable {
    var recallObjectId: UUID { id }
    var recallObjectType: RecallObjectType { .draft }
    var recallTitle: String {
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Draft" : String(trimmed.prefix(60))
    }
    var recallDetail: String {
        if let notes, !notes.isEmpty {
            return notes
        }
        return caption
    }
    var recallUpdatedAt: Date { updatedAt }
    var recallImportance: Double { isArchived ? 0.2 : 0.5 }
    var recallKeywords: [String] {
        var values = tags.map { $0.lowercased() }
        if associatedPostID != nil {
            values.append("post")
        }
        return values
    }
}

extension Post: RecallTrackable {
    var recallObjectId: UUID { id }
    var recallObjectType: RecallObjectType { .post }
    var recallTitle: String {
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Post" : String(trimmed.prefix(60))
    }
    var recallDetail: String {
        if let publishedDate {
            return "Published \(RecallFormatters.shortDate.string(from: publishedDate))"
        }
        if let scheduledDate {
            return "Scheduled \(RecallFormatters.shortDate.string(from: scheduledDate))"
        }
        return caption
    }
    var recallUpdatedAt: Date { updatedAt }
    var recallImportance: Double {
        switch PostStatus(rawValue: status) ?? .draft {
        case .scheduled: return 0.9
        case .publishing: return 0.85
        case .published: return 0.7
        case .draft: return 0.4
        case .failed: return 0.2
        }
    }
    var recallKeywords: [String] {
        var values = tags.map { $0.lowercased() }
        if let campaignId {
            values.append(campaignId.uuidString)
        }
        return values
    }
}

extension Reminder: RecallTrackable {
    var recallObjectId: UUID { id }
    var recallObjectType: RecallObjectType { .reminder }
    var recallTitle: String { title }
    var recallDetail: String {
        if let notes, !notes.isEmpty {
            return notes
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        return "Reminder: \(dateFormatter.string(from: reminderDate))"
    }
    var recallUpdatedAt: Date { updatedAt }
    var recallImportance: Double {
        if isCompleted {
            return 0.2
        }
        // Higher importance for reminders coming up soon
        let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: reminderDate).day ?? 0
        if daysUntil <= 1 {
            return 0.9
        } else if daysUntil <= 7 {
            return 0.7
        }
        return 0.5
    }
    var recallKeywords: [String] {
        var values: [String] = ["reminder"]
        if let notes, !notes.isEmpty {
            // Extract keywords from notes
            let words = notes.lowercased().components(separatedBy: .whitespacesAndNewlines)
            values.append(contentsOf: words.filter { $0.count > 3 }.prefix(5))
        }
        return values
    }
}

@MainActor
private extension AIRecallService {
    func applyAmbientDecayIfNeeded(modelContext: ModelContext) {
        let now = Date()
        if let lastRun = lastDecayRun {
            let interval = now.timeIntervalSince(lastRun)
            guard interval >= 6 * 3600 else { return }
            let deltaDays = interval / (60 * 60 * 24)
            guard deltaDays > 0 else { return }
            var didChange = false
            for entry in cache.values where entry.lastViewedAt <= lastRun {
                let factor = exp(-deltaDays / 90.0)
                let newImportance = max(0.0, entry.importance * factor)
                if abs(newImportance - entry.importance) > 0.0001 {
                    entry.importance = newImportance
                    didChange = true
                }
            }
            if didChange {
                do {
                    try modelContext.save()
                } catch {
                    AIDebug.log("Failed to apply ambient decay: \(error.localizedDescription)")
                }
            }
        }
        lastDecayRun = now
        applyPruningIfNeeded(referenceDate: now, modelContext: modelContext)
    }

    func applyPruningIfNeeded(referenceDate: Date, modelContext: ModelContext) {
        if let lastPruneRun, referenceDate.timeIntervalSince(lastPruneRun) < 7 * 24 * 3600 {
            return
        }
        let staleThreshold = referenceDate.addingTimeInterval(-90 * 24 * 3600)
        let candidates = cache.values.filter { $0.importance < 0.1 && $0.lastViewedAt < staleThreshold }
        guard !candidates.isEmpty else {
            lastPruneRun = referenceDate
            return
        }
        for entry in candidates {
            modelContext.delete(entry)
            cache.removeValue(forKey: entry.objectId)
        }
        do {
            try modelContext.save()
        } catch {
            AIDebug.log("Failed to prune stale recall entries: \(error.localizedDescription)")
        }
        lastPruneRun = referenceDate
    }
    
    // MARK: - Conversation Memory Layer
    
    /// Generate a context snapshot for a conversation
    /// Auto-summarizes after 5+ messages and stores sentiment, tags, and ARTE tone
    internal func generateContextSnapshot(conversationId: UUID, modelContext: ModelContext) async -> ConversationContextSnapshot? {
        guard config.featureFlags.recallEnabled else { return nil }
        
        // Fetch conversation
        var descriptor = FetchDescriptor<AIConversation>(
            predicate: #Predicate { $0.id == conversationId }
        )
        guard let conversation = try? modelContext.fetch(descriptor).first,
              let messages = conversation.messages,
              messages.count >= 5 else {
            return nil
        }
        
        // Generate summary using OllamaBridgeService
        do {
            let summary = try await OllamaBridgeService.shared.generateConversationSummary(messages: messages)
            
            // Analyze emotional tone from messages
            let emotionalTone = analyzeConversationTone(messages: messages)
            
            // Extract tags from conversation content using AI
            let tags = await extractConversationTags(messages: messages)
            
            // Get ARTE emotional state
            let arteState = ReactiveThemeManager.shared.currentState.rawValue
            
            // Update conversation with summary
            conversation.summary = summary
            if conversation.tags.isEmpty {
                conversation.tags = tags
            }
            
            try modelContext.save()
            
            return ConversationContextSnapshot(
                conversationId: conversationId,
                summary: summary,
                emotionalTone: emotionalTone,
                tags: tags,
                arteState: arteState,
                messageCount: messages.count
            )
        } catch {
            AIDebug.log("Failed to generate context snapshot: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func analyzeConversationTone(messages: [AIMessage]) -> String {
        let allContent = messages.compactMap { $0.content }.joined(separator: " ")
        let emotion = EmotionAnalyzer.analyzeTone(text: allContent)
        
        if emotion.valence > 0.3 {
            return "positive"
        } else if emotion.valence < -0.3 {
            return "challenging"
        } else {
            return "neutral"
        }
    }
    
    internal func extractConversationTags(messages: [AIMessage]) async -> [String] {
        // Use AI to generate relevant tags based on conversation content
        // This replaces simple keyword matching with intelligent analysis
        let allContent = messages.compactMap { $0.content }.joined(separator: "\n")
        
        // If conversation is too short, return empty tags
        guard allContent.count > 50 else {
            return []
        }
        
        // Use Aurora to analyze and tag the conversation
        return await generateTagsWithAI(messages: messages, content: allContent)
    }
    
    private func generateTagsWithAI(messages: [AIMessage], content: String) async -> [String] {
        do {
            // Create a prompt for Aurora to analyze and tag the conversation naturally
            let conversationText = messages.prefix(10).compactMap { message -> String? in
                guard let content = message.content else { return nil }
                let role = message.role == "user" ? "User" : "Aurora"
                return "\(role): \(content)"
            }.joined(separator: "\n\n")
            
            let prompt = """
            You are Aurora. Tag this conversation naturally - think about what it's really about, not formal categories.
            
            Conversation:
            \(conversationText)
            
            Generate 1-3 natural, conversational tags. Use simple, human words that capture the essence:
            - Single words work best: Helping, Planning, Creating, Learning, Organizing, Brainstorming
            - Or short phrases (max 2 words): Task Management, Content Ideas
            - Think like you're describing it to a friend, not categorizing it formally
            
            Return ONLY a comma-separated list of tags (e.g., Helping, Planning or Creating). 
            - NO quotes around tags
            - NO periods at the end
            - NO punctuation except spaces for 2-word phrases
            - Keep them natural and conversational
            """
            
            // Use CoreResponseService to generate tags
            let response = try await CoreResponseService.shared.generateResponse(
                for: prompt,
                context: "",
                modelContext: nil
            )
            
            // Parse tags from response
            let tags = response
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: ",")
                .compactMap { tag -> String? in
                    var trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if trimmed.isEmpty {
                        return nil
                    }
                    
                    // Strip quotes if present
                    trimmed = trimmed.replacingOccurrences(of: "\"", with: "")
                    trimmed = trimmed.replacingOccurrences(of: "'", with: "")
                    
                    // Remove periods at the end
                    trimmed = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "."))
                    
                    // Remove trailing punctuation except spaces (for 2-word phrases)
                    trimmed = trimmed.trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
                    
                    // Validate: must be single word or max 2 words, no punctuation except spaces
                    let words = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if words.count > 2 {
                        return nil // Too many words
                    }
                    
                    // Check for invalid punctuation (except spaces between words)
                    let cleaned = words.joined(separator: " ")
                    if cleaned.range(of: #"[^\w\s]"#, options: .regularExpression) != nil {
                        return nil // Contains invalid punctuation
                    }
                    
                    // Filter out tags that are too long (>20 chars)
                    if cleaned.count > 20 {
                        return nil
                    }
                    
                    // Capitalize first letter only for natural look
                    let capitalized = cleaned.prefix(1).uppercased() + cleaned.dropFirst().lowercased()
                    return capitalized.isEmpty ? nil : capitalized
                }
                .prefix(3) // Limit to 3 tags
            
            return Array(tags)
        } catch {
            AIDebug.log("Failed to generate tags with AI: \(error.localizedDescription)")
            // Fallback to empty tags if AI fails
            return []
        }
    }
}

struct ConversationContextSnapshot: Sendable {
    let conversationId: UUID
    let summary: String
    let emotionalTone: String
    let tags: [String]
    let arteState: String
    let messageCount: Int
}

extension Area: RecallTrackable {
    var recallObjectId: UUID { id }
    var recallObjectType: RecallObjectType { .project } // Using project type as closest match
    var recallTitle: String { title }
    var recallDetail: String {
        if let notes = notes, !notes.isEmpty {
            return notes
        }
        return "Area with \(tags.count) tag\(tags.count == 1 ? "" : "s")"
    }
    var recallUpdatedAt: Date { updatedAt }
    var recallImportance: Double {
        switch status {
        case .active: return 0.7
        case .reviewNeeded: return 0.8
        case .archived: return 0.2
        }
    }
    var recallKeywords: [String] {
        var values = tags.map { $0.lowercased() }
        if let categoryIcon = categoryIcon {
            values.append(categoryIcon.lowercased())
        }
        return values
    }
}
