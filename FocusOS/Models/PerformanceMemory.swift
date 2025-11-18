//
//  PerformanceMemory.swift
//  FocusOS
//
//  SwiftData model for tracking model performance per intent cluster
//

import Foundation
import SwiftData

@Model
final class PerformanceMemory {
    var intentCluster: String
    var modelName: String
    var successCount: Int
    var failureCount: Int
    var totalLatency: Double // Sum of all latencies in seconds
    var requestCount: Int
    var timeoutCount: Int
    var lastUsed: Date
    var createdAt: Date
    var cachedPerformanceScore: Double? // Cache computed score for sorting
    
    init(
        intentCluster: String,
        modelName: String,
        successCount: Int = 0,
        failureCount: Int = 0,
        totalLatency: Double = 0.0,
        requestCount: Int = 0,
        timeoutCount: Int = 0,
        lastUsed: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.intentCluster = intentCluster
        self.modelName = modelName
        self.successCount = successCount
        self.failureCount = failureCount
        self.totalLatency = totalLatency
        self.requestCount = requestCount
        self.timeoutCount = timeoutCount
        self.lastUsed = lastUsed
        self.createdAt = createdAt
        self.cachedPerformanceScore = nil
    }
    
    /// Success rate (0.0 to 1.0)
    var successRate: Double {
        guard requestCount > 0 else { return 0.5 } // Default to neutral if no data
        return Double(successCount) / Double(requestCount)
    }
    
    /// Average latency in seconds
    var averageLatency: Double {
        guard requestCount > 0 else { return 0.0 }
        return totalLatency / Double(requestCount)
    }
    
    /// Timeout rate (0.0 to 1.0)
    var timeoutRate: Double {
        guard requestCount > 0 else { return 0.0 }
        return Double(timeoutCount) / Double(requestCount)
    }
    
    /// Overall performance score (higher is better, 0.0 to 1.0)
    var performanceScore: Double {
        // Return cached value if available and still valid
        if let cached = cachedPerformanceScore {
            return cached
        }
        
        let successWeight = 0.5
        let latencyWeight = 0.3
        let timeoutPenalty = 0.2
        
        // Normalize latency (assume 10s is "slow", 1s is "fast")
        let normalizedLatency = max(0.0, min(1.0, 1.0 - (averageLatency / 10.0)))
        
        // Calculate score
        let score = (successRate * successWeight) + (normalizedLatency * latencyWeight) - (timeoutRate * timeoutPenalty)
        let finalScore = max(0.0, min(1.0, score))
        
        // Cache the score for sorting
        cachedPerformanceScore = finalScore
        
        return finalScore
    }
    
    /// Record a successful request
    func recordSuccess(latency: TimeInterval) {
        successCount += 1
        requestCount += 1
        totalLatency += latency
        lastUsed = Date()
        // Invalidate cached score
        cachedPerformanceScore = nil
    }
    
    /// Record a failed request
    func recordFailure(isTimeout: Bool = false) {
        failureCount += 1
        requestCount += 1
        if isTimeout {
            timeoutCount += 1
        }
        lastUsed = Date()
        // Invalidate cached score
        cachedPerformanceScore = nil
    }
}

/// Service for managing performance memory
@MainActor
final class PerformanceMemoryService {
    static let shared = PerformanceMemoryService()
    
    private var modelContext: ModelContext?
    
    private init() {}
    
    /// Set the model context for SwiftData operations
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    /// Get or create performance memory for a specific intent cluster + model combination
    func getOrCreateMemory(
        intentCluster: String,
        modelName: String,
        modelContext: ModelContext
    ) -> PerformanceMemory {
        let descriptor = FetchDescriptor<PerformanceMemory>(
            predicate: #Predicate<PerformanceMemory> { memory in
                memory.intentCluster == intentCluster && memory.modelName == modelName
            }
        )
        
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        
        let newMemory = PerformanceMemory(
            intentCluster: intentCluster,
            modelName: modelName
        )
        modelContext.insert(newMemory)
        return newMemory
    }
    
    /// Record a successful request
    func recordSuccess(
        intentCluster: String,
        modelName: String,
        latency: TimeInterval,
        modelContext: ModelContext
    ) {
        let memory = getOrCreateMemory(
            intentCluster: intentCluster,
            modelName: modelName,
            modelContext: modelContext
        )
        memory.recordSuccess(latency: latency)
        
        // Save context to persist changes
        try? modelContext.save()
        
        // Cleanup old records (7-day window or top-100 cap)
        cleanupOldRecords(intentCluster: intentCluster, modelContext: modelContext)
    }
    
    /// Record a failed request
    func recordFailure(
        intentCluster: String,
        modelName: String,
        isTimeout: Bool,
        modelContext: ModelContext
    ) {
        let memory = getOrCreateMemory(
            intentCluster: intentCluster,
            modelName: modelName,
            modelContext: modelContext
        )
        memory.recordFailure(isTimeout: isTimeout)
        
        // Save context to persist changes
        try? modelContext.save()
    }
    
    /// Get best performing model for an intent cluster
    func getBestModel(
        for intentCluster: String,
        modelContext: ModelContext
    ) -> String? {
        // Update cached scores before sorting
        let descriptor = FetchDescriptor<PerformanceMemory>(
            predicate: #Predicate<PerformanceMemory> { memory in
                memory.intentCluster == intentCluster && memory.requestCount >= 3
            }
        )
        
        guard var memories = try? modelContext.fetch(descriptor) else {
            return nil
        }
        
        // Update cached scores for all memories
        for memory in memories {
            _ = memory.performanceScore // This will cache the score
        }
        
        // Save the context to persist cached scores
        try? modelContext.save()
        
        // Now sort by cached score
        memories.sort { ($0.cachedPerformanceScore ?? 0.0) > ($1.cachedPerformanceScore ?? 0.0) }
        
        guard let best = memories.first,
              (best.cachedPerformanceScore ?? 0.0) > 0.5 else {
            return nil
        }
        
        return best.modelName
    }
    
    /// Cleanup old records (7-day window or top-100 cap per intent cluster)
    private func cleanupOldRecords(intentCluster: String, modelContext: ModelContext) {
        // This must be called from MainActor context
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        
        // Delete records older than 7 days
        let oldDescriptor = FetchDescriptor<PerformanceMemory>(
            predicate: #Predicate<PerformanceMemory> { memory in
                memory.intentCluster == intentCluster && memory.createdAt < sevenDaysAgo
            }
        )
        
        if let oldRecords = try? modelContext.fetch(oldDescriptor) {
            for record in oldRecords {
                modelContext.delete(record)
            }
        }
        
        // Keep only top 100 records per intent cluster (sorted by lastUsed)
        let allDescriptor = FetchDescriptor<PerformanceMemory>(
            predicate: #Predicate<PerformanceMemory> { memory in
                memory.intentCluster == intentCluster
            },
            sortBy: [SortDescriptor(\.lastUsed, order: .reverse)]
        )
        
        if let allRecords = try? modelContext.fetch(allDescriptor),
           allRecords.count > 100 {
            for record in allRecords.dropFirst(100) {
                modelContext.delete(record)
            }
        }
    }
}

