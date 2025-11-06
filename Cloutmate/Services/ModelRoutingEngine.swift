//
//  ModelRoutingEngine.swift
//  Cloutmate
//
//  Routing logic engine with confidence weighting and performance-based selection
//

import Foundation
import SwiftData

actor ModelRoutingEngine {
    static let shared = ModelRoutingEngine()
    
    // Cache last-used model per intent cluster
    private var clusterModelCache: [String: String] = [:]
    
    private init() {}
    
    /// Selects the best model for a given intent cluster and confidence
    func selectModel(
        intentCluster: String?,
        confidence: Double,
        preferredModel: String?,
        modelContext: ModelContext,
        latencyThreshold: TimeInterval = 6.0
    ) async -> String {
        let clusterName = intentCluster ?? "default"
        
        // Check cache first
        if let cachedModel = clusterModelCache[clusterName] {
            return cachedModel
        }
        
        // Check performance memory for best model
        if let bestModel = await PerformanceMemoryService.shared.getBestModel(
            for: clusterName,
            modelContext: modelContext
        ) {
            clusterModelCache[clusterName] = bestModel
            return bestModel
        }
        
        // Use preferred model if provided and valid
        if let preferred = preferredModel,
           ModelTierMap.isCloudModel(preferred) {
            clusterModelCache[clusterName] = preferred
            return preferred
        }
        
        // Dynamic routing based on intent cluster
        let models = ModelTierMap.modelsForIntentCluster(intentCluster)
        
        // Apply confidence-based selection
        var selectedModel: String
        
        if confidence < 0.6 {
            // Low confidence: use more capable model (first in list)
            selectedModel = models.first ?? "gpt-oss:20b-cloud"
        } else if confidence > 0.85 {
            // High confidence: can use faster model (second in list if available)
            selectedModel = models.count > 1 ? models[1] : models.first ?? "gpt-oss:20b-cloud"
        } else {
            // Medium confidence: use primary model
            selectedModel = models.first ?? "gpt-oss:20b-cloud"
        }
        
        clusterModelCache[clusterName] = selectedModel
        return selectedModel
    }
    
    /// Escalates to a higher tier model
    func escalateModel(_ currentModel: String, intentCluster: String?) -> String? {
        // Clear cache for this cluster to force re-evaluation
        if let cluster = intentCluster {
            clusterModelCache.removeValue(forKey: cluster)
        }
        
        return ModelTierMap.escalateModel(currentModel)
    }
    
    /// Optimizes to a faster/lighter model
    func optimizeModel(_ currentModel: String, intentCluster: String?) -> String? {
        // Clear cache for this cluster to force re-evaluation
        if let cluster = intentCluster {
            clusterModelCache.removeValue(forKey: cluster)
        }
        
        return ModelTierMap.optimizeModel(currentModel)
    }
    
    /// Clears the cache (called on app restart or model availability changes)
    func clearCache() {
        clusterModelCache.removeAll()
    }
    
    /// Clears cache for a specific intent cluster
    func clearCache(for intentCluster: String) {
        clusterModelCache.removeValue(forKey: intentCluster)
    }
}
