//
//  AIRecallService.swift
//  Cloutmate
//
//  Phase 1 recall layer with shared AI config + telemetry.
//

import Foundation
import SwiftData
import os
import CloutmateShared

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
        self.metadata = metadata
    }
    
    static let empty = AIPayloadContext()
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
    case draft
    case inbox
    case unknown
    
    var displayName: String {
        switch self {
        case .task: return "Task"
        case .project: return "Project"
        case .post: return "Post"
        case .note: return "Note"
        case .draft: return "Draft"
        case .inbox: return "Inbox"
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
        emotionKeywords: [String] = []
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
    }
    
    func score(using weights: AIConfig.RecallWeights, referenceDate: Date = Date()) -> Double {
        let elapsed = referenceDate.timeIntervalSince(lastViewedAt)
        let decayWindow = max(1.0, weights.recencyHalfLifeHours * 3600.0)
        let recencyScore = max(0.0, min(1.0, 1.0 - (elapsed / decayWindow)))
        let frequencyScore = max(0.0, min(1.0, Double(accessCount) / max(1.0, weights.frequencyNormalizationFactor)))
        let clampedImportance = max(0.0, min(1.0, importance))
        
        return (weights.recencyWeight * recencyScore)
        + (weights.frequencyWeight * frequencyScore)
        + (weights.importanceWeight * clampedImportance)
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
    private let cacheValidity: TimeInterval = 300 // 5 minutes
    
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
        shouldRegisterView: Bool = true
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
        
        let scored = entries
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
                return (min(1.0, base + queryBoost), entry)
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
    
    func boostImportance(
        for objectIDs: [UUID],
        amount: Double = 0.05,
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
        values.append(contentsOf: platforms.map { $0.lowercased() })
        if let campaignId {
            values.append(campaignId.uuidString)
        }
        return values
    }
}
