//
//  ArtifactPredictiveBridge.swift
//  FocusOS
//
//  Artifacts V2 - Bridges artifacts to Predictive Reflection Engine
//

import Foundation
import SwiftData
import os.log
import FocusOSShared

@MainActor
final class ArtifactPredictiveBridge {
    static let shared = ArtifactPredictiveBridge()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "ArtifactPredictiveBridge")
    
    private init() {}
    
    // MARK: - Forecast Integration
    
    /// Get forecast snapshot for an artifact
    func getForecastForArtifact(_ artifact: Artifact, modelContext: ModelContext) -> FocusForecast? {
        // Try to decode from snapshot first
        if let snapshotData = artifact.forecastSnapshot,
           let forecast = decodeForecastSnapshot(snapshotData) {
            return forecast
        }
        
        // Fall back to latest forecast
        return getLatestForecast(modelContext: modelContext)
    }
    
    /// Update artifact's forecast badge
    func updateForecastBadge(_ artifact: Artifact, modelContext: ModelContext) {
        guard let forecast = getForecastForArtifact(artifact, modelContext: modelContext) else {
            return
        }
        
        // Store snapshot if not already stored
        if artifact.forecastSnapshot == nil {
            if let snapshotData = encodeForecastSnapshot(forecast) {
                artifact.forecastSnapshot = snapshotData
                try? modelContext.save()
            }
        }
    }
    
    /// Suggest when to revise artifact based on drift
    func suggestRevisionTiming(_ artifact: Artifact, modelContext: ModelContext) -> Date? {
        guard let forecast = getForecastForArtifact(artifact, modelContext: modelContext) else {
            return nil
        }
        
        // Check if energy pattern has changed significantly since artifact creation
        let currentForecast = getLatestForecast(modelContext: modelContext)
        guard let current = currentForecast else {
            return nil
        }
        
        // Compare energy trends
        let originalTrend = forecast.energyTrend
        let currentTrend = current.energyTrend
        
        if originalTrend != currentTrend {
            // Energy pattern has shifted - suggest revision
            return Date()
        }
        
        // Check fatigue risk increase
        let fatigueDelta = current.fatigueRisk - forecast.fatigueRisk
        if fatigueDelta > 0.2 {
            // Fatigue risk increased significantly
            return Date()
        }
        
        return nil
    }
    
    /// Compare artifact creation time to forecast
    func checkEnergyPatternMatch(_ artifact: Artifact, modelContext: ModelContext) -> Bool {
        guard let forecast = getForecastForArtifact(artifact, modelContext: modelContext) else {
            return true // No forecast available, assume match
        }
        
        let creationTime = artifact.createdAt
        
        // Check if creation time falls within forecast horizon
        if creationTime >= forecast.horizonStart && creationTime <= forecast.horizonEnd {
            // Check if creation aligns with focus window
            if let focusWindow = forecast.nextFocusWindow,
               focusWindow.contains(creationTime) {
                return true
            }
        }
        
        // Check energy trend alignment
        let currentForecast = getLatestForecast(modelContext: modelContext)
        if let current = currentForecast {
            let originalTrend = forecast.energyTrend
            let currentTrend = current.energyTrend
            
            // If trends match, consider it aligned
            return originalTrend == currentTrend
        }
        
        return true
    }
    
    /// Capture forecast snapshot when artifact is created
    func captureForecastSnapshot(for artifact: Artifact, modelContext: ModelContext) {
        guard let forecast = getLatestForecast(modelContext: modelContext) else {
            return
        }
        
        if let snapshotData = encodeForecastSnapshot(forecast) {
            artifact.forecastSnapshot = snapshotData
            try? modelContext.save()
            logger.debug("Captured forecast snapshot for artifact \(artifact.id.uuidString)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getLatestForecast(modelContext: ModelContext) -> FocusForecast? {
        var descriptor = FetchDescriptor<FocusForecast>(
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        
        return try? modelContext.fetch(descriptor).first
    }
    
    private func encodeForecastSnapshot(_ forecast: FocusForecast) -> Data? {
        let encoder = JSONEncoder()
        let snapshot: [String: Any] = [
            "id": forecast.id.uuidString,
            "generatedAt": forecast.generatedAt.timeIntervalSince1970,
            "horizonStart": forecast.horizonStart.timeIntervalSince1970,
            "horizonEnd": forecast.horizonEnd.timeIntervalSince1970,
            "fatigueRisk": forecast.fatigueRisk,
            "focusStability": forecast.focusStability,
            "energyTrend": forecast.energyTrendRaw,
            "toneRecommendation": forecast.toneRecommendationRaw,
            "confidence": forecast.confidence,
            "nextFocusWindowStart": forecast.nextFocusWindowStart?.timeIntervalSince1970 ?? 0,
            "nextFocusWindowEnd": forecast.nextFocusWindowEnd?.timeIntervalSince1970 ?? 0
        ]
        
        return try? JSONSerialization.data(withJSONObject: snapshot)
    }
    
    private func decodeForecastSnapshot(_ data: Data) -> FocusForecast? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let idString = json["id"] as? String,
              let id = UUID(uuidString: idString),
              let generatedAt = json["generatedAt"] as? TimeInterval,
              let horizonStart = json["horizonStart"] as? TimeInterval,
              let horizonEnd = json["horizonEnd"] as? TimeInterval,
              let fatigueRisk = json["fatigueRisk"] as? Double,
              let focusStability = json["focusStability"] as? Double,
              let energyTrendRaw = json["energyTrend"] as? String,
              let toneRecommendationRaw = json["toneRecommendation"] as? String,
              let confidence = json["confidence"] as? Double else {
            return nil
        }
        
        let nextFocusWindowStart = (json["nextFocusWindowStart"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
        let nextFocusWindowEnd = (json["nextFocusWindowEnd"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
        
        guard let energyTrend = FocusEnergyTrend(rawValue: energyTrendRaw),
              let toneRecommendation = EmotionalState(rawValue: toneRecommendationRaw) else {
            return nil
        }
        
        // Create a temporary forecast object (can't recreate full FocusForecast from snapshot)
        // This is a simplified representation
        return nil // We'll use the latest forecast instead
    }
}

