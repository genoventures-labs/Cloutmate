//
//  PerformanceMemory.swift
//  Cloutmate
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
        let successWeight = 0.5
        let latencyWeight = 0.3
        let timeoutPenalty = 0.2
        
        // Normalize latency (assume 10s is "slow", 1s is "fast")
        let normalizedLatency = max(0.0, min(1.0, 1.0 - (averageLatency / 10.0)))
        
        // Calculate score
        let score = (successRate * successWeight) + (normalizedLatency * latencyWeight) - (timeoutRate * timeoutPenalty)
        return max(0.0, min(1.0, score))
    }
    
    /// Record a successful request
    func recordSuccess(latency: TimeInterval) {
        successCount += 1
        requestCount += 1
        totalLatency += latency
        lastUsed = Date()
    }
    
    /// Record a failed request
    func recordFailure(isTimeout: Bool = false) {
        failureCount += 1
        requestCount += 1
        if isTimeout {
            timeoutCount += 1
        }
        lastUsed = Date()
    }
}

/// Service for managing performance memory
actor PerformanceMemoryService {
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
    }
    
    /// Get best performing model for an intent cluster
    func getBestModel(
        for intentCluster: String,
        modelContext: ModelContext
    ) -> String? {
        let descriptor = FetchDescriptor<PerformanceMemory>(
            predicate: #Predicate<PerformanceMemory> { memory in
                memory.intentCluster == intentCluster && memory.requestCount >= 3
            },
            sortBy: [SortDescriptor(\.performanceScore, order: .reverse)]
        )
        
        guard let memories = try? modelContext.fetch(descriptor),
              let best = memories.first,
              best.performanceScore > 0.5 else {
            return nil
        }
        
        return best.modelName
    }
    
    /// Cleanup old records (7-day window or top-100 cap per intent cluster)
    private func cleanupOldRecords(intentCluster: String, modelContext: ModelContext) {
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
        
        // Keep only top 100 records per intent cluster
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

