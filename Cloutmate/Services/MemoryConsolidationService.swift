//
//  MemoryConsolidationService.swift
//  Cloutmate
//
//  Nightly memory consolidation - brain slow-wave sleep for Aurora's memory graph
//

import Foundation
import SwiftData
import CloutmateShared
import os.log

@MainActor
final class MemoryConsolidationService {
    static let shared = MemoryConsolidationService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "MemoryConsolidation")
    
    private var config: AIConfig {
        AIConfigService.shared.config
    }
    
    private var consolidationTimer: Timer?
    private let consolidationInterval: TimeInterval = 86400  // 24 hours
    
    private init() {}
    
    // MARK: - Consolidation Lifecycle
    
    /// Start nightly consolidation schedule
    func start(modelContext: ModelContext) {
        guard config.featureFlags.memoryGraphEnabled else {
            logger.debug("Memory graph disabled - skipping consolidation")
            return
        }
        
        // Schedule first consolidation for tonight
        scheduleNextConsolidation(modelContext: modelContext)
        
        logger.info("Memory consolidation service started")
    }
    
    /// Stop consolidation schedule
    func stop() {
        consolidationTimer?.invalidate()
        consolidationTimer = nil
        logger.info("Memory consolidation service stopped")
    }
    
    /// Schedule next consolidation
    private func scheduleNextConsolidation(modelContext: ModelContext) {
        // Calculate time until next midnight
        let calendar = Calendar.current
        let now = Date()
        guard let nextMidnight = calendar.date(bySettingHour: 2, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: 1, to: now) ?? now) else {
            return
        }
        
        let timeUntilMidnight = nextMidnight.timeIntervalSince(now)
        
        consolidationTimer?.invalidate()
        consolidationTimer = Timer.scheduledTimer(withTimeInterval: timeUntilMidnight, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.performConsolidation(modelContext: modelContext)
                // Schedule next consolidation
                self.scheduleNextConsolidation(modelContext: modelContext)
            }
        }
        
        logger.info("Next consolidation scheduled for \(nextMidnight)")
    }
    
    /// Perform full consolidation pass
    func performConsolidation(modelContext: ModelContext) async {
        guard config.featureFlags.memoryGraphEnabled else {
            logger.debug("Memory graph disabled - skipping consolidation")
            return
        }
        
        logger.info("Starting nightly memory consolidation...")
        
        do {
            // 1. Merge near-duplicate nodes
            let mergedCount = await MemoryGraphService.shared.mergeRedundantNodes(
                similarityThreshold: 0.8,
                modelContext: modelContext
            )
            logger.info("Merged \(mergedCount) redundant nodes")
            
            // 2. Recompute theme centroids
            await MemoryGraphService.shared.updateThemeCentroids(modelContext: modelContext)
            logger.info("Updated theme centroids")
            
            // 3. Apply edge decay
            MemoryGraphService.shared.applyEdgeDecay(modelContext: modelContext)
            logger.info("Applied edge decay")
            
            // 4. Detect new clusters and create subgraphs
            let subgraphs = await MemoryGraphService.shared.detectAndCreateSubgraphs(
                similarityThreshold: 0.75,
                minClusterSize: 3,
                modelContext: modelContext
            )
            logger.info("Detected \(subgraphs.count) new subgraphs")
            
            // 5. Rebuild all indices
            MemoryGraphService.shared.rebuildIndices(modelContext: modelContext)
            logger.info("Rebuilt graph indices")
            
            // 6. Move short-term graph into stable graph
            // (This would involve archiving very old, low-importance nodes)
            await archiveOldNodes(modelContext: modelContext)
            
            // Trigger consolidation hooks
            MemoryGraphService.shared.onConsolidation { }
            
            logger.info("Nightly memory consolidation complete")
        } catch {
            logger.error("Consolidation failed: \(error.localizedDescription)")
        }
    }
    
    /// Archive very old, low-importance nodes
    private func archiveOldNodes(modelContext: ModelContext) async {
        let descriptor = FetchDescriptor<MemoryNode>(
            predicate: #Predicate { node in
                // Archive nodes older than 90 days with low importance
                let daysSinceCreation = Date().timeIntervalSince(node.createdAt) / 86400.0
                return daysSinceCreation > 90 && node.importance < 0.2
            }
        )
        
        guard let oldNodes = try? modelContext.fetch(descriptor) else { return }
        
        var archivedCount = 0
        for node in oldNodes {
            if !node.tags.contains("archived") {
                node.tags.append("archived")
                archivedCount += 1
            }
        }
        
        try? modelContext.save()
        
        if archivedCount > 0 {
            logger.info("Archived \(archivedCount) old, low-importance nodes")
        }
    }
    
    /// Manual consolidation trigger (for testing)
    func triggerConsolidation(modelContext: ModelContext) async {
        await performConsolidation(modelContext: modelContext)
    }
}

