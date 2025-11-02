//
//  PriorityEngine.swift
//  Cloutmate
//
//  Contextual Priority System (CPS) - Phase 3
//  Dynamically ranks workspace objects based on context, usage, and AI interactions
//

import Foundation
import SwiftData
import os.log
import CloutmateShared

@MainActor
final class PriorityEngine {
    static let shared = PriorityEngine()
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "CPS")
    private var cache: [UUID: PriorityScore] = [:]
    private var lastCacheRefresh: Date?
    private let cacheValidity: TimeInterval = 300 // 5 minutes
    
    private init() {}
    
    private var config: AIConfig { AIConfigService.shared.config }
    private var weights: CPSWeights {
        CPSWeights(
            recency: config.cpsWeights?.recency ?? 0.3,
            frequency: config.cpsWeights?.frequency ?? 0.25,
            connections: config.cpsWeights?.connections ?? 0.25,
            aiMentions: config.cpsWeights?.aiMentions ?? 0.15,
            manualBoost: config.cpsWeights?.manualBoost ?? 0.05
        )
    }
    
    // MARK: - Core CPS Operations
    
    /// Update score for an object (called on access/update)
    func updateScore(
        for objectId: UUID,
        objectType: String,
        modelContext: ModelContext,
        incrementAccess: Bool = true
    ) {
        guard config.featureFlags.cpsEnabled else { return }
        
        refreshCacheIfNeeded(modelContext: modelContext)
        
        let score = getOrCreateScore(for: objectId, objectType: objectType, modelContext: modelContext)
        
        if incrementAccess {
            score.accessCount += 1
        }
        score.lastAccessed = Date()
        score.lastUpdated = Date()
        
        // Recalculate with weights
        score.recalculate(using: weights)
        
        cache[objectId] = score
        
        do {
            try modelContext.save()
            logger.debug("CPS updated for \(objectId.uuidString): score=\(score.totalScore, privacy: .public)")
        } catch {
            logger.error("Failed to save CPS update: \(error.localizedDescription)")
        }
    }
    
    /// Boost score manually (user action or importance signal)
    func boostScore(
        for objectIds: [UUID],
        amount: Double = 0.2,
        modelContext: ModelContext
    ) {
        guard config.featureFlags.cpsEnabled, !objectIds.isEmpty else { return }
        
        refreshCacheIfNeeded(modelContext: modelContext)
        
        for objectId in objectIds {
            guard let score = getScore(for: objectId, modelContext: modelContext) else { continue }
            
            score.manualBoost = min(1.0, score.manualBoost + amount)
            score.lastUpdated = Date()
            score.recalculate(using: weights)
            
            cache[objectId] = score
            logger.debug("CPS boost applied to \(objectId.uuidString): boost=\(score.manualBoost, privacy: .public)")
        }
        
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save CPS boosts: \(error.localizedDescription)")
        }
    }
    
    /// Increment AI mention counter (called when AI surfaces object)
    func recordAIMention(
        for objectIds: [UUID],
        modelContext: ModelContext
    ) {
        guard config.featureFlags.cpsEnabled, !objectIds.isEmpty else { return }
        
        refreshCacheIfNeeded(modelContext: modelContext)
        
        for objectId in objectIds {
            guard let score = getScore(for: objectId, modelContext: modelContext) else { continue }
            
            score.aiMentionCount += 1
            score.aiMentionScore = min(1.0, Double(score.aiMentionCount) / 5.0)
            score.lastUpdated = Date()
            score.recalculate(using: weights)
            
            cache[objectId] = score
        }
        
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save AI mention updates: \(error.localizedDescription)")
        }
    }
    
    /// Update connection score (called when relationships change)
    func updateConnections(
        for objectId: UUID,
        connectionCount: Int,
        modelContext: ModelContext
    ) {
        guard config.featureFlags.cpsEnabled else { return }
        
        guard let score = getScore(for: objectId, modelContext: modelContext) else { return }
        
        score.connectionCount = connectionCount
        score.connectionScore = min(1.0, Double(connectionCount) / 5.0)
        score.lastUpdated = Date()
        score.recalculate(using: weights)
        
        cache[objectId] = score
        
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save connection update: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Retrieval
    
    /// Get top N priority objects across all types
    func getTopObjects(
        limit: Int = 10,
        modelContext: ModelContext
    ) -> [PriorityItem] {
        guard config.featureFlags.cpsEnabled else { return [] }
        
        refreshCacheIfNeeded(modelContext: modelContext)
        
        let descriptor = FetchDescriptor<PriorityScore>(
            sortBy: [SortDescriptor(\.totalScore, order: .reverse)]
        )
        
        guard let scores = try? modelContext.fetch(descriptor) else { return [] }
        
        let topScores = Array(scores.prefix(limit))
        
        // Convert to PriorityItems with actual object details
        var items: [PriorityItem] = []
        for score in topScores {
            if let item = fetchObjectDetails(for: score, modelContext: modelContext) {
                items.append(item)
            }
        }
        
        return items
    }
    
    /// Get top priority objects of a specific type
    func getTopObjects(
        ofType objectType: String,
        limit: Int = 5,
        modelContext: ModelContext
    ) -> [PriorityItem] {
        guard config.featureFlags.cpsEnabled else { return [] }
        
        refreshCacheIfNeeded(modelContext: modelContext)
        
        let typeFilter = objectType
        var descriptor = FetchDescriptor<PriorityScore>(
            predicate: #Predicate { $0.objectType == typeFilter },
            sortBy: [SortDescriptor(\.totalScore, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        guard let scores = try? modelContext.fetch(descriptor) else { return [] }
        
        // Convert to PriorityItems with actual object details
        var items: [PriorityItem] = []
        for score in scores {
            if let item = fetchObjectDetails(for: score, modelContext: modelContext) {
                items.append(item)
            }
        }
        
        return items
    }
    
    /// Get score for a specific object
    func getScoreValue(for objectId: UUID, modelContext: ModelContext) -> Double? {
        guard config.featureFlags.cpsEnabled else { return nil }
        return getScore(for: objectId, modelContext: modelContext)?.totalScore
    }
    
    // MARK: - Cleanup
    
    /// Remove scores for deleted objects
    func removeScores(for objectIds: [UUID], modelContext: ModelContext) {
        guard config.featureFlags.cpsEnabled, !objectIds.isEmpty else { return }
        
        let ids = Set(objectIds)
        let descriptor = FetchDescriptor<PriorityScore>(
            predicate: #Predicate { ids.contains($0.objectId) }
        )
        
        if let scores = try? modelContext.fetch(descriptor) {
            for score in scores {
                modelContext.delete(score)
                cache.removeValue(forKey: score.objectId)
            }
            
            do {
                try modelContext.save()
                logger.debug("Removed CPS scores for \(objectIds.count) objects")
            } catch {
                logger.error("Failed to remove CPS scores: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func getOrCreateScore(
        for objectId: UUID,
        objectType: String,
        modelContext: ModelContext
    ) -> PriorityScore {
        if let existing = getScore(for: objectId, modelContext: modelContext) {
            return existing
        }
        
        let newScore = PriorityScore(objectId: objectId, objectType: objectType)
        modelContext.insert(newScore)
        cache[objectId] = newScore
        return newScore
    }
    
    private func getScore(for objectId: UUID, modelContext: ModelContext) -> PriorityScore? {
        // Check cache first
        if let cached = cache[objectId] {
            return cached
        }
        
        // Fetch from database
        var descriptor = FetchDescriptor<PriorityScore>(
            predicate: #Predicate { $0.objectId == objectId }
        )
        descriptor.fetchLimit = 1
        
        if let results = try? modelContext.fetch(descriptor),
           let score = results.first {
            cache[objectId] = score
            return score
        }
        
        return nil
    }
    
    private func refreshCacheIfNeeded(modelContext: ModelContext) {
        guard cache.isEmpty || (lastCacheRefresh == nil || Date().timeIntervalSince(lastCacheRefresh ?? .distantPast) > cacheValidity) else {
            return
        }
        
        let descriptor = FetchDescriptor<PriorityScore>()
        if let scores = try? modelContext.fetch(descriptor) {
            cache = Dictionary(uniqueKeysWithValues: scores.map { ($0.objectId, $0) })
            lastCacheRefresh = Date()
            let cacheCount = cache.count
            if cacheCount == 0 {
                logger.info("CPS cache initialized (empty - scores will be created as you use the app)")
            } else {
                logger.debug("CPS cache refreshed: \(cacheCount) scores loaded")
            }
        }
    }
    
    private func fetchObjectDetails(for score: PriorityScore, modelContext: ModelContext) -> PriorityItem? {
        let objectId = score.objectId
        
        switch score.objectType {
        case "task":
            var descriptor = FetchDescriptor<CloutmateShared.Task>(predicate: #Predicate { $0.id == objectId })
            descriptor.fetchLimit = 1
            guard let task = try? modelContext.fetch(descriptor).first else { return nil }
            return PriorityItem(
                objectId: task.id,
                title: task.title,
                score: score.totalScore,
                objectType: "Task",
                detail: "Due: \(task.dueDate?.formatted(date: .abbreviated, time: .omitted) ?? "None") | \(task.priority.displayName)"
            )
            
        case "project":
            var descriptor = FetchDescriptor<CloutmateShared.Project>(predicate: #Predicate { $0.id == objectId })
            descriptor.fetchLimit = 1
            guard let project = try? modelContext.fetch(descriptor).first else { return nil }
            return PriorityItem(
                objectId: project.id,
                title: project.title,
                score: score.totalScore,
                objectType: "Project",
                detail: project.goal ?? "No goal set"
            )
            
        case "note":
            var descriptor = FetchDescriptor<CloutmateShared.Note>(predicate: #Predicate { $0.id == objectId })
            descriptor.fetchLimit = 1
            guard let note = try? modelContext.fetch(descriptor).first else { return nil }
            return PriorityItem(
                objectId: note.id,
                title: note.title,
                score: score.totalScore,
                objectType: "Note",
                detail: String(note.markdown.prefix(100))
            )
            
        case "draft":
            var descriptor = FetchDescriptor<Draft>(predicate: #Predicate { $0.id == objectId })
            descriptor.fetchLimit = 1
            guard let draft = try? modelContext.fetch(descriptor).first else { return nil }
            return PriorityItem(
                objectId: draft.id,
                title: String(draft.caption.prefix(50)),
                score: score.totalScore,
                objectType: "Draft",
                detail: "Tags: \(draft.tags.joined(separator: ", "))"
            )
            
        case "post":
            var descriptor = FetchDescriptor<CloutmateShared.Post>(predicate: #Predicate { $0.id == objectId })
            descriptor.fetchLimit = 1
            guard let post = try? modelContext.fetch(descriptor).first else { return nil }
            return PriorityItem(
                objectId: post.id,
                title: String(post.caption.prefix(50)),
                score: score.totalScore,
                objectType: "Post",
                detail: "Status: \(post.postStatus.displayName)"
            )
            
        case "inbox":
            var descriptor = FetchDescriptor<CloutmateShared.InboxItem>(predicate: #Predicate { $0.id == objectId })
            descriptor.fetchLimit = 1
            guard let item = try? modelContext.fetch(descriptor).first else { return nil }
            return PriorityItem(
                objectId: item.id,
                title: String(item.content.prefix(50)),
                score: score.totalScore,
                objectType: "Inbox",
                detail: item.itemType
            )
            
        default:
            return nil
        }
    }
}

