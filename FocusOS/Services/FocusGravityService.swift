//
//  FocusGravityService.swift
//  FocusOS
//
//  Focus Gravity V2 - Central service aggregating CPS, sessions, rituals, and predictive data
//

import Foundation
import SwiftData
import os.log
import FocusOSShared

@MainActor
final class FocusGravityService {
    static let shared = FocusGravityService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "FocusGravity")
    private var cache: [String: (entities: [FocusEntity], timestamp: Date)] = [:]
    private let cacheTTL: TimeInterval = 600 // 10 minutes
    
    private init() {}
    
    // MARK: - Public API
    
    /// Fetch focus entities with aggregated metrics
    func fetchFocusEntities(
        timeScope: FocusTimeScope = .week,
        filter: FocusEntityFilter = .all,
        modelContext: ModelContext
    ) -> [FocusEntity] {
        let cacheKey = "\(timeScope.rawValue)_\(filter.rawValue)"
        
        // Check cache
        if let cached = cache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.entities
        }
        
        // Fetch fresh data
        let entities = computeFocusEntities(
            timeScope: timeScope,
            filter: filter,
            modelContext: modelContext
        )
        
        // Cache result
        cache[cacheKey] = (entities: entities, timestamp: Date())
        
        return entities
    }
    
    /// Compute gravity weights for orbit visualization
    func computeGravityWeights(entities: [FocusEntity]) -> [UUID: Double] {
        var weights: [UUID: Double] = [:]
        for entity in entities {
            weights[entity.id] = entity.gravityWeight
        }
        return weights
    }
    
    /// Calculate orbit positions for entities
    func getOrbitPositions(
        entities: [FocusEntity],
        center: CGPoint,
        radius: CGFloat
    ) -> [UUID: CGPoint] {
        var positions: [UUID: CGPoint] = [:]
        let count = entities.count
        guard count > 0 else { return positions }
        
        let angleStep = (2.0 * .pi) / Double(count)
        
        for (index, entity) in entities.enumerated() {
            let angle = angleStep * Double(index)
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            positions[entity.id] = CGPoint(x: x, y: y)
        }
        
        return positions
    }
    
    /// Get latest forecast from CognitionPredictor
    func getLatestForecast(modelContext: ModelContext) -> FocusForecast? {
        var descriptor = FetchDescriptor<FocusForecast>(
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        
        return try? modelContext.fetch(descriptor).first
    }
    
    /// Get overall focus distribution across all entities
    func getFocusDistribution(entities: [FocusEntity]) -> FocusEnergyProfile {
        guard !entities.isEmpty else {
            return FocusEnergyProfile(cognitive: 0.33, creative: 0.33, completion: 0.34)
        }
        
        var totalCognitive: Double = 0
        var totalCreative: Double = 0
        var totalCompletion: Double = 0
        var totalWeight: Double = 0
        
        for entity in entities {
            let weight = entity.gravityWeight
            totalCognitive += entity.energy.cognitive * weight
            totalCreative += entity.energy.creative * weight
            totalCompletion += entity.energy.completion * weight
            totalWeight += weight
        }
        
        guard totalWeight > 0 else {
            return FocusEnergyProfile(cognitive: 0.33, creative: 0.33, completion: 0.34)
        }
        
        return FocusEnergyProfile(
            cognitive: totalCognitive / totalWeight,
            creative: totalCreative / totalWeight,
            completion: totalCompletion / totalWeight
        )
    }
    
    /// Get weekly focus trend data
    func getWeeklyTrend(
        modelContext: ModelContext
    ) -> [(date: Date, cognitive: Double, creative: Double, completion: Double)] {
        let calendar = Calendar.current
        let now = Date()
        var trend: [(Date, Double, Double, Double)] = []
        
        for i in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: now) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }
            
            // Fetch entities for this day
            let dayEntities = computeFocusEntities(
                timeScope: .today,
                filter: .all,
                modelContext: modelContext,
                customRange: (dayStart, dayEnd)
            )
            
            let distribution = getFocusDistribution(entities: dayEntities)
            trend.append((dayStart, distribution.cognitive, distribution.creative, distribution.completion))
        }
        
        return trend.reversed()
    }
    
    /// Invalidate cache (call on CPS updates or session changes)
    func invalidateCache() {
        cache.removeAll()
        logger.debug("Focus Gravity cache invalidated")
    }
    
    // MARK: - Private Implementation
    
    private func computeFocusEntities(
        timeScope: FocusTimeScope,
        filter: FocusEntityFilter,
        modelContext: ModelContext,
        customRange: (Date, Date)? = nil
    ) -> [FocusEntity] {
        let range = customRange ?? timeScope.dateRange
        
        // Get top priority items from PriorityEngine
        let priorityItems: [PriorityItem]
        if let objectType = filter.objectType {
            priorityItems = PriorityEngine.shared.getTopObjects(
                ofType: objectType,
                limit: 50,
                modelContext: modelContext
            )
        } else {
            priorityItems = PriorityEngine.shared.getTopObjects(
                limit: 50,
                modelContext: modelContext
            )
        }
        
        // Get recent sessions
        let recentSessions = getRecentSessions(in: range, modelContext: modelContext)
        
        // Get ritual streaks
        let ritualStreaks = getRitualStreaks(modelContext: modelContext)
        
        // Get latest forecast
        let forecast = getLatestForecast(modelContext: modelContext)
        
        // Build entities
        var entities: [FocusEntity] = []
        
        for item in priorityItems {
            // Filter by time scope if needed
            if !isItemInRange(item, range: range, modelContext: modelContext) {
                continue
            }
            
            // Get sessions for this entity
            let entitySessions = recentSessions.filter { session in
                session.targetObjectId == item.objectId
            }
            
            // Calculate energy profile
            let energy = computeEnergyProfile(
                for: item,
                sessions: entitySessions,
                modelContext: modelContext
            )
            
            // Calculate ritual weight
            let ritualWeight = computeRitualWeight(
                for: item,
                streaks: ritualStreaks,
                modelContext: modelContext
            )
            
            // Get last activity
            let lastActivity = getLastActivity(
                for: item,
                sessions: entitySessions,
                modelContext: modelContext
            )
            
            let entity = FocusEntity(
                id: item.objectId,
                name: item.title,
                type: item.objectType.lowercased(),
                cpsScore: item.score,
                energy: energy,
                forecast: forecast,
                lastActivity: lastActivity,
                sessionCount: entitySessions.count,
                ritualWeight: ritualWeight
            )
            
            entities.append(entity)
        }
        
        // Sort by gravity weight
        return entities.sorted { $0.gravityWeight > $1.gravityWeight }
    }
    
    private func getRecentSessions(
        in range: (Date, Date),
        modelContext: ModelContext
    ) -> [FocusSession] {
        let rangeStart = range.0
        let rangeEnd = range.1
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { session in
                session.startTime >= rangeStart && session.startTime <= rangeEnd
            },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    private func getRitualStreaks(modelContext: ModelContext) -> (morning: Int, evening: Int) {
        let summary = RitualAnalytics.shared.generateSummary(
            for: .thisWeek,
            modelContext: modelContext
        )
        return (summary.morningStreak, summary.eveningStreak)
    }
    
    private func isItemInRange(
        _ item: PriorityItem,
        range: (Date, Date),
        modelContext: ModelContext
    ) -> Bool {
        // Check if item was accessed/updated in range
        let rangeStart = range.0
        let rangeEnd = range.1
        let objectId = item.objectId // Extract UUID before predicate
        let descriptor = FetchDescriptor<PriorityScore>(
            predicate: #Predicate { score in
                score.objectId == objectId
            }
        )
        
        guard let score = try? modelContext.fetch(descriptor).first else {
            return false
        }
        
        return score.lastAccessed >= rangeStart && score.lastAccessed <= rangeEnd
    }
    
    private func computeEnergyProfile(
        for item: PriorityItem,
        sessions: [FocusSession],
        modelContext: ModelContext
    ) -> FocusEnergyProfile {
        // Use ProjectFocusGravityService logic if it's a project
        if item.objectType.lowercased() == "project" {
            if let project = fetchProject(id: item.objectId, modelContext: modelContext) {
                let metrics = ProjectFocusGravityService.shared.focusMetrics(
                    for: project,
                    modelContext: modelContext
                )
                return FocusEnergyProfile(
                    cognitive: metrics.cognitiveFocus,
                    creative: metrics.creativeFlow,
                    completion: metrics.completionEnergy
                )
            }
        }
        
        // Default calculation based on CPS score and sessions
        let sessionCount = Double(sessions.count)
        let completedSessions = Double(sessions.filter { $0.completed }.count)
        
        // Cognitive: high priority + recent activity
        let cognitive = min(1.0, item.score * 0.7 + (sessionCount > 0 ? 0.3 : 0.0))
        
        // Creative: moderate priority + in-progress work
        let creative = min(1.0, item.score * 0.5 + (sessionCount - completedSessions) * 0.2)
        
        // Completion: completed sessions + high completion rate
        let completionRate = sessionCount > 0 ? completedSessions / sessionCount : 0.0
        let completion = min(1.0, item.score * 0.4 + completionRate * 0.6)
        
        return FocusEnergyProfile(
            cognitive: cognitive,
            creative: creative,
            completion: completion
        )
    }
    
    private func computeRitualWeight(
        for item: PriorityItem,
        streaks: (morning: Int, evening: Int),
        modelContext: ModelContext
    ) -> Double {
        // Check if item was mentioned in recent ritual completions
        let totalStreak = Double(streaks.morning + streaks.evening)
        
        // Normalize streak contribution (max streak = 14 days = 1.0)
        return min(1.0, totalStreak / 14.0)
    }
    
    private func getLastActivity(
        for item: PriorityItem,
        sessions: [FocusSession],
        modelContext: ModelContext
    ) -> Date? {
        // Get most recent session
        let latestSession = sessions.max { $0.startTime < $1.startTime }
        
        // Get PriorityScore last accessed
        let objectId = item.objectId // Extract UUID before predicate
        let descriptor = FetchDescriptor<PriorityScore>(
            predicate: #Predicate { score in
                score.objectId == objectId
            }
        )
        let score = try? modelContext.fetch(descriptor).first
        
        let dates = [latestSession?.startTime, score?.lastAccessed].compactMap { $0 }
        return dates.max()
    }
    
    private func fetchProject(id: UUID, modelContext: ModelContext) -> Project? {
        var descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}

