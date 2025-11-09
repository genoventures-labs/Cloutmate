//
//  AreaStabilityService.swift
//  Cloutmate
//
//  Calculate stability scores and status signals for areas
//

import Foundation
import SwiftData
import CloutmateShared
import os.log

enum StabilitySignal {
    case calm      // Green - stable, consistent
    case steady    // Blue - moderate activity
    case chaotic   // Red - high variance, unstable
}

@MainActor
final class AreaStabilityService {
    static let shared = AreaStabilityService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "AreaStability")
    private var cache: [UUID: (score: Double, signal: StabilitySignal, timestamp: Date)] = [:]
    private let cacheTTL: TimeInterval = 300 // 5 minutes
    
    private init() {}
    
    /// Calculate stability score for an area (0-100)
    func stabilityScore(for area: Area, modelContext: ModelContext) -> Double {
        // Capture ID first to avoid accessing deallocated object
        let areaId = area.id
        
        // Check cache first
        if let cached = cache[areaId],
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.score
        }
        
        // Verify area still exists in context and refetch
        do {
            let descriptor = FetchDescriptor<Area>(predicate: #Predicate<Area> { $0.id == areaId })
            guard let validArea = try? modelContext.fetch(descriptor).first else {
                logger.warning("Area \(areaId) not found in context, returning default score")
                return 50.0
            }
            
            // Calculate fresh score using the refetched area
            let score = calculateStabilityScore(for: validArea, modelContext: modelContext)
            
            // Cache result
            let signal = statusSignalInternal(for: validArea, score: score, modelContext: modelContext)
            cache[areaId] = (score: score, signal: signal, timestamp: Date())
            
            return score
        } catch {
            logger.error("Failed to verify area: \(error.localizedDescription)")
            return 50.0
        }
    }
    
    /// Determine status signal for an area
    func statusSignal(for area: Area, modelContext: ModelContext) -> StabilitySignal {
        // Capture ID first to avoid accessing deallocated object
        let areaId = area.id
        
        // Check cache first
        if let cached = cache[areaId],
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.signal
        }
        
        // Get score first (which will verify and refetch area)
        let score = stabilityScore(for: area, modelContext: modelContext)
        
        // Verify area still exists in context
        do {
            let descriptor = FetchDescriptor<Area>(predicate: #Predicate<Area> { $0.id == areaId })
            guard let validArea = try? modelContext.fetch(descriptor).first else {
                return .steady
            }
            
            let signal = calculateStatusSignal(score: score, area: validArea, modelContext: modelContext)
            
            // Update cache
            cache[areaId] = (score: score, signal: signal, timestamp: Date())
            
            return signal
        } catch {
            logger.error("Failed to verify area: \(error.localizedDescription)")
            return .steady
        }
    }
    
    /// Internal helper to calculate status signal when we already have the score
    private func statusSignalInternal(for area: Area, score: Double, modelContext: ModelContext) -> StabilitySignal {
        let linkedProjects = getLinkedProjects(for: area, modelContext: modelContext)
        let variance = calculateVariance(for: area, projects: linkedProjects, modelContext: modelContext)
        
        if score >= 70 && variance < 0.15 {
            return .calm
        } else if score < 40 || variance > 0.3 {
            return .chaotic
        } else {
            return .steady
        }
    }
    
    /// Get Focus Gravity trend for an area over specified days
    func focusGravityTrend(for area: Area, days: Int, modelContext: ModelContext) -> [(Date, Double)] {
        // Capture ID first to avoid accessing deallocated object
        let areaId = area.id
        
        // Verify area still exists in context and refetch
        do {
            let descriptor = FetchDescriptor<Area>(predicate: #Predicate<Area> { $0.id == areaId })
            guard let validArea = try? modelContext.fetch(descriptor).first else {
                logger.warning("Area \(areaId) not found in context, returning empty trend")
                return []
            }
            
            let linkedProjects = getLinkedProjects(for: validArea, modelContext: modelContext)
            
            guard !linkedProjects.isEmpty else {
                return []
            }
            
            // Aggregate trends from all linked projects
            var aggregatedTrend: [Date: [Double]] = [:]
            
            for project in linkedProjects {
                let trend = ProjectFocusGravityService.shared.weeklyFocusTrend(for: project, days: days, modelContext: modelContext)
                
                for (date, value) in trend {
                    if aggregatedTrend[date] == nil {
                        aggregatedTrend[date] = []
                    }
                    aggregatedTrend[date]?.append(value)
                }
            }
            
            // Average values per date
            let calendar = Calendar.current
            let now = Date()
            var result: [(Date, Double)] = []
            
            for i in 0..<days {
                guard let date = calendar.date(byAdding: .day, value: -i, to: now) else { continue }
                let dayStart = calendar.startOfDay(for: date)
                
                if let values = aggregatedTrend[dayStart], !values.isEmpty {
                    let average = values.reduce(0.0, +) / Double(values.count)
                    result.append((dayStart, average))
                } else {
                    result.append((dayStart, 0.0))
                }
            }
            
            return result.reversed()
        } catch {
            logger.error("Failed to get focus gravity trend: \(error.localizedDescription)")
            return []
        }
    }
    
    func invalidateCache(for areaId: UUID) {
        cache.removeValue(forKey: areaId)
    }
    
    func invalidateAllCache() {
        cache.removeAll()
    }
    
    // MARK: - Private Calculation Methods
    
    private func calculateStabilityScore(for area: Area, modelContext: ModelContext) -> Double {
        let linkedProjects = getLinkedProjects(for: area, modelContext: modelContext)
        
        // Base score from project CPS scores
        var projectScores: [Double] = []
        for project in linkedProjects {
            // Safely access ProjectFocusGravityService
            let metrics = ProjectFocusGravityService.shared.focusMetrics(for: project, modelContext: modelContext)
            // Average of cognitive focus, creative flow, and completion energy
            let avgFocus = (metrics.cognitiveFocus + metrics.creativeFlow + metrics.completionEnergy) / 3.0
            projectScores.append(avgFocus)
        }
        
        let avgProjectScore = projectScores.isEmpty ? 0.5 : projectScores.reduce(0.0, +) / Double(projectScores.count)
        
        // ARTE emotional tone adjustment
        let arteAdjustment = getARTEAdjustment()
        
        // Recency factor (areas reviewed recently are more stable)
        let recencyFactor = getRecencyFactor(for: area)
        
        // Activity consistency (variance in project activity)
        let consistencyFactor = calculateConsistencyFactor(projectScores: projectScores)
        
        // Weighted combination
        let stability = (avgProjectScore * 0.4) + 
                       (arteAdjustment * 0.3) + 
                       (recencyFactor * 0.2) + 
                       (consistencyFactor * 0.1)
        
        // Convert to 0-100 scale
        return min(100.0, max(0.0, stability * 100.0))
    }
    
    private func calculateStatusSignal(score: Double, area: Area, modelContext: ModelContext) -> StabilitySignal {
        // Calm: score > 70, low variance
        // Steady: score 40-70, moderate variance
        // Chaotic: score < 40, high variance
        
        let linkedProjects = getLinkedProjects(for: area, modelContext: modelContext)
        let variance = calculateVariance(for: area, projects: linkedProjects, modelContext: modelContext)
        
        if score >= 70 && variance < 0.15 {
            return .calm
        } else if score < 40 || variance > 0.3 {
            return .chaotic
        } else {
            return .steady
        }
    }
    
    private func getARTEAdjustment() -> Double {
        // Safely access ReactiveThemeManager
        guard ReactiveThemeManager.shared.isEnabled else {
            return 0.5 // Neutral if ARTE is disabled
        }
        
        let state = ReactiveThemeManager.shared.currentState
        
        switch state {
        case .calm, .reflective:
            return 0.8 // Positive for stability
        case .focused:
            return 0.7 // Good but slightly lower
        case .energized:
            return 0.6 // Active but less stable
        case .fatigued:
            return 0.4 // Lower stability
        }
    }
    
    private func getRecencyFactor(for area: Area) -> Double {
        guard let lastReview = area.lastReviewDate else {
            return 0.5 // Neutral if never reviewed
        }
        
        let daysSinceReview = Calendar.current.dateComponents([.day], from: lastReview, to: Date()).day ?? 0
        
        if daysSinceReview <= 7 {
            return 1.0 // Recently reviewed = high stability
        } else if daysSinceReview <= 30 {
            return 0.7 // Moderately recent
        } else {
            return 0.4 // Stale review = lower stability
        }
    }
    
    private func calculateConsistencyFactor(projectScores: [Double]) -> Double {
        guard projectScores.count > 1 else {
            return 0.5 // Neutral for single project
        }
        
        let mean = projectScores.reduce(0.0, +) / Double(projectScores.count)
        let variance = projectScores.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(projectScores.count)
        let stdDev = sqrt(variance)
        
        // Lower variance = higher consistency = higher stability
        return max(0.0, 1.0 - stdDev)
    }
    
    private func calculateVariance(for area: Area, projects: [CloutmateShared.Project], modelContext: ModelContext) -> Double {
        guard projects.count > 1 else {
            return 0.0
        }
        
        var scores: [Double] = []
        for project in projects {
            // Safely access ProjectFocusGravityService
            let metrics = ProjectFocusGravityService.shared.focusMetrics(for: project, modelContext: modelContext)
            let avgFocus = (metrics.cognitiveFocus + metrics.creativeFlow + metrics.completionEnergy) / 3.0
            scores.append(avgFocus)
        }
        
        let mean = scores.reduce(0.0, +) / Double(scores.count)
        let variance = scores.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(scores.count)
        
        return variance
    }
    
    private func getLinkedProjects(for area: Area, modelContext: ModelContext) -> [CloutmateShared.Project] {
        do {
            let descriptor = FetchDescriptor<CloutmateShared.Project>()
            let allProjects = try modelContext.fetch(descriptor)
            return allProjects.filter { $0.areaId == area.id }
        } catch {
            logger.error("Failed to fetch linked projects: \(error.localizedDescription)")
            return []
        }
    }
}

