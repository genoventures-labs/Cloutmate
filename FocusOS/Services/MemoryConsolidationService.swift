//
//  MemoryConsolidationService.swift
//  FocusOS
//
//  Nightly memory consolidation - brain slow-wave sleep for Aurora's memory graph
//

import Foundation
import SwiftData
import FocusOSShared
import os.log

@MainActor
final class MemoryConsolidationService {
    static let shared = MemoryConsolidationService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "MemoryConsolidation")
    
    private var config: AIConfig {
        AIConfigService.shared.config
    }
    
    private var consolidationTimer: Timer?
    private let consolidationInterval: TimeInterval = 86400  // 24 hours
    
    private struct ConsolidationUserInfo {
        let modelContext: ModelContext
    }
    
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
        consolidationTimer = Timer.scheduledTimer(timeInterval: timeUntilMidnight,
                                                  target: self,
                                                  selector: #selector(handleConsolidationTimerFired(_:)),
                                                  userInfo: ConsolidationUserInfo(modelContext: modelContext),
                                                  repeats: false)
        
        logger.info("Next consolidation scheduled for \(nextMidnight)")
    }
    
    @objc private func handleConsolidationTimerFired(_ timer: Timer) {
        guard let info = timer.userInfo as? ConsolidationUserInfo else { return }
        let modelContext = info.modelContext
        _Concurrency.Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performConsolidation(modelContext: modelContext)
            self.scheduleNextConsolidation(modelContext: modelContext)
        }
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
        let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date.distantPast
        let descriptor = FetchDescriptor<MemoryNode>(
            predicate: #Predicate { node in
                node.createdAt < ninetyDaysAgo && node.importance < 0.2 && !node.tags.contains("archived")
            }
        )
        
        guard let oldNodes = try? modelContext.fetch(descriptor) else { return }
        
        var archivedCount = 0
        for node in oldNodes {
            node.tags.append("archived")
            archivedCount += 1
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

