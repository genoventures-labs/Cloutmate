//
//  MemoryGraphTelemetry.swift
//  Cloutmate
//
//  Phase 6 - Memory Graph Research Build
//  Telemetry and monitoring for memory graph operations
//

import Foundation
import SwiftData
import os.log

struct MemoryGraphMetrics: Sendable {
    let totalNodes: Int
    let totalEdges: Int
    let totalThemes: Int
    let activeThemes: Int
    let avgNodeImportance: Double
    let avgThemeSalience: Double
    let embeddedNodesCount: Int
    let timestamp: Date
}

@MainActor
final class MemoryGraphTelemetry {
    static let shared = MemoryGraphTelemetry()
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "MemoryGraphTelemetry")
    
    private var operationCounts: [String: Int] = [:]
    private var lastMetricsCapture: Date?
    
    private init() {
        _Concurrency.Task {
            await startPeriodicMonitoring()
        }
    }
    
    // MARK: - Metrics Collection
    
    func captureMetrics(modelContext: ModelContext) -> MemoryGraphMetrics {
        let nodesDescriptor = FetchDescriptor<MemoryNode>()
        let edgesDescriptor = FetchDescriptor<MemoryEdge>()
        let themesDescriptor = FetchDescriptor<ThemeNode>()
        
        let nodes = (try? modelContext.fetch(nodesDescriptor)) ?? []
        let edges = (try? modelContext.fetch(edgesDescriptor)) ?? []
        let themes = (try? modelContext.fetch(themesDescriptor)) ?? []
        
        let activeThemes = themes.filter { $0.isActive }.count
        let embeddedNodes = nodes.filter { $0.embeddingData != nil }.count
        
        let avgImportance = nodes.isEmpty ? 0.0 : nodes.reduce(0.0) { $0 + $1.importance } / Double(nodes.count)
        let avgSalience = themes.isEmpty ? 0.0 : themes.reduce(0.0) { $0 + $1.salience } / Double(themes.count)
        
        let metrics = MemoryGraphMetrics(
            totalNodes: nodes.count,
            totalEdges: edges.count,
            totalThemes: themes.count,
            activeThemes: activeThemes,
            avgNodeImportance: avgImportance,
            avgThemeSalience: avgSalience,
            embeddedNodesCount: embeddedNodes,
            timestamp: Date()
        )
        
        lastMetricsCapture = Date()
        logMetrics(metrics)
        
        return metrics
    }
    
    func logMetrics(_ metrics: MemoryGraphMetrics) {
        AIDebug.log("""
        MemoryGraph Metrics:
        - Nodes: \(metrics.totalNodes) (\(metrics.embeddedNodesCount) with embeddings)
        - Edges: \(metrics.totalEdges)
        - Themes: \(metrics.totalThemes) (\(metrics.activeThemes) active)
        - Avg Importance: \(String(format: "%.3f", metrics.avgNodeImportance))
        - Avg Salience: \(String(format: "%.3f", metrics.avgThemeSalience))
        """)
    }
    
    // MARK: - Operation Tracking
    
    func recordOperation(_ operation: String) {
        operationCounts[operation, default: 0] += 1
        AIDebug.log("MemoryGraph Operation: \(operation) (count: \(operationCounts[operation]!))")
    }
    
    func getOperationCounts() -> [String: Int] {
        return operationCounts
    }
    
    func resetOperationCounts() {
        operationCounts.removeAll()
        AIDebug.log("MemoryGraph: Operation counts reset")
    }
    
    // MARK: - Periodic Monitoring
    
    private func startPeriodicMonitoring() async {
        guard AIConfigService.shared.config.featureFlags.memoryGraphEnabled else { return }
        
        // Monitor every 5 minutes
        while true {
            try? await _Concurrency.Task.sleep(for: .seconds(300))
            
            guard AIConfigService.shared.config.featureFlags.memoryGraphEnabled else { continue }
            
            // This would need a model context from main app
            // For now, just log that monitoring is active
            logger.info("Memory graph monitoring tick")
        }
    }
    
    // MARK: - Debug Reports
    
    func generateDebugReport(modelContext: ModelContext) -> String {
        let metrics = captureMetrics(modelContext: modelContext)
        
        var report = """
        === MEMORY GRAPH DEBUG REPORT ===
        Generated: \(metrics.timestamp.formatted())
        
        GRAPH STATISTICS:
        - Total Nodes: \(metrics.totalNodes)
        - Nodes with Embeddings: \(metrics.embeddedNodesCount)
        - Total Edges: \(metrics.totalEdges)
        - Total Themes: \(metrics.totalThemes)
        - Active Themes: \(metrics.activeThemes)
        - Average Node Importance: \(String(format: "%.3f", metrics.avgNodeImportance))
        - Average Theme Salience: \(String(format: "%.3f", metrics.avgThemeSalience))
        
        OPERATION COUNTS:
        """
        
        for (operation, count) in operationCounts.sorted(by: { $0.key < $1.key }) {
            report += "\n- \(operation): \(count)"
        }
        
        // Fetch top themes
        let themesDescriptor = FetchDescriptor<ThemeNode>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\.salience, order: .reverse)]
        )
        
        if let topThemes = try? modelContext.fetch(themesDescriptor).prefix(5) {
            report += "\n\nTOP THEMES (by salience):"
            for (index, theme) in topThemes.enumerated() {
                report += "\n\(index + 1). \(theme.label) (salience: \(String(format: "%.2f", theme.salience)), members: \(theme.memberNodeIds.count))"
                report += "\n   \(theme.themeDescription)"
            }
        }
        
        report += "\n\n=================================\n"
        
        return report
    }
    
    func exportMetricsToJSON(modelContext: ModelContext) -> String? {
        let metrics = captureMetrics(modelContext: modelContext)
        
        let jsonObject: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: metrics.timestamp),
            "totalNodes": metrics.totalNodes,
            "totalEdges": metrics.totalEdges,
            "totalThemes": metrics.totalThemes,
            "activeThemes": metrics.activeThemes,
            "avgNodeImportance": metrics.avgNodeImportance,
            "avgThemeSalience": metrics.avgThemeSalience,
            "embeddedNodesCount": metrics.embeddedNodesCount,
            "operationCounts": operationCounts
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return nil
    }
}

