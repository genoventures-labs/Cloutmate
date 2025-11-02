//
//  MemoryGraphDebug.swift
//  Cloutmate
//
//  Phase 6 - Memory Graph Research Build
//  Debug visualization and CLI tools for memory graph
//

import Foundation
import SwiftData
import os.log

@MainActor
final class MemoryGraphDebug {
    static let shared = MemoryGraphDebug()
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "MemoryGraphDebug")
    
    private init() {}
    
    // MARK: - ASCII Graph Visualization
    
    /// Generate ASCII art visualization of graph structure
    func visualizeGraph(modelContext: ModelContext, centerNodeId: UUID? = nil, depth: Int = 2) -> String {
        guard let centerNode = centerNodeId != nil ? fetchNode(centerNodeId!, modelContext) : getMostImportantNode(modelContext) else {
            return "No nodes found in graph"
        }
        
        var output = """
        === MEMORY GRAPH VISUALIZATION ===
        Center: \(centerNode.label) (importance: \(String(format: "%.2f", centerNode.importance)))
        
        """
        
        output += visualizeNodeRecursive(centerNode, modelContext: modelContext, depth: depth, visited: Set(), prefix: "")
        
        return output
    }
    
    private func visualizeNodeRecursive(
        _ node: MemoryNode,
        modelContext: ModelContext,
        depth: Int,
        visited: Set<UUID>,
        prefix: String
    ) -> String {
        if depth == 0 || visited.contains(node.id) {
            return ""
        }
        
        var visited = visited
        visited.insert(node.id)
        
        var output = "\(prefix)├─ [\(node.type.rawValue)] \(node.label)\n"
        output += "\(prefix)│  importance: \(String(format: "%.2f", node.importance)), edges: \(node.edgeCount)\n"
        
        // Get neighbors
        let neighbors = MemoryGraphService.shared.getNeighbors(of: node.id, modelContext: modelContext)
        for (index, neighbor) in neighbors.prefix(3).enumerated() {
            let isLast = index == min(neighbors.count, 3) - 1
            let newPrefix = prefix + (isLast ? "   " : "│  ")
            output += visualizeNodeRecursive(neighbor, modelContext: modelContext, depth: depth - 1, visited: visited, prefix: newPrefix)
        }
        
        if neighbors.count > 3 {
            output += "\(prefix)│  ... and \(neighbors.count - 3) more neighbors\n"
        }
        
        return output
    }
    
    // MARK: - DOT Format Export
    
    /// Export graph in DOT format for Graphviz visualization
    func exportToDOT(modelContext: ModelContext, limit: Int = 50) -> String {
        let nodesDescriptor = FetchDescriptor<MemoryNode>(
            sortBy: [SortDescriptor(\.importance, order: .reverse)]
        )
        let edgesDescriptor = FetchDescriptor<MemoryEdge>()
        
        guard let nodes = try? modelContext.fetch(nodesDescriptor).prefix(limit),
              let edges = try? modelContext.fetch(edgesDescriptor) else {
            return "digraph MemoryGraph {}"
        }
        
        var dot = """
        digraph MemoryGraph {
            rankdir=LR;
            node [shape=box, style=rounded];
            
        """
        
        // Add nodes
        let nodeIds = Set(nodes.map { $0.id })
        for node in nodes {
            let importance = String(format: "%.2f", node.importance)
            let color = node.importance > 0.7 ? "red" : (node.importance > 0.4 ? "orange" : "lightblue")
            dot += "    \"\(node.id.uuidString)\" [label=\"\(node.label)\\n\(importance)\", fillcolor=\(color), style=\"rounded,filled\"];\n"
        }
        
        // Add edges (only between nodes we're showing)
        for edge in edges {
            if nodeIds.contains(edge.sourceNodeId) && nodeIds.contains(edge.targetNodeId) {
                let weight = String(format: "%.2f", edge.weight)
                dot += "    \"\(edge.sourceNodeId.uuidString)\" -> \"\(edge.targetNodeId.uuidString)\" [label=\"\(edge.type.rawValue)\\n\(weight)\"];\n"
            }
        }
        
        dot += "}\n"
        
        return dot
    }
    
    // MARK: - Node Inspector
    
    /// Get detailed information about a specific node
    func inspectNode(_ nodeId: UUID, modelContext: ModelContext) -> String {
        guard let node = fetchNode(nodeId, modelContext) else {
            return "Node not found: \(nodeId.uuidString)"
        }
        
        var output = """
        === NODE INSPECTION ===
        ID: \(node.id.uuidString)
        Type: \(node.type.rawValue)
        Label: \(node.label)
        Object ID: \(node.objectId?.uuidString ?? "N/A")
        
        METRICS:
        - Importance: \(String(format: "%.3f", node.importance))
        - Decay: \(String(format: "%.3f", node.decay))
        - Access Count: \(node.accessCount)
        - Edge Count: \(node.edgeCount)
        - Created: \(node.createdAt.formatted())
        - Last Accessed: \(node.lastAccessedAt.formatted())
        
        CONTENT:
        \(node.content)
        
        EMBEDDING:
        """
        
        if let embedding = node.getEmbedding() {
            output += "Present (\(embedding.count) dimensions)\n"
            output += "First 10 values: \(embedding.prefix(10).map { String(format: "%.4f", $0) }.joined(separator: ", "))\n"
        } else {
            output += "Not generated\n"
        }
        
        // Get connected edges
        let edgesDescriptor = FetchDescriptor<MemoryEdge>(
            predicate: #Predicate { edge in
                edge.sourceNodeId == nodeId || edge.targetNodeId == nodeId
            }
        )
        
        if let edges = try? modelContext.fetch(edgesDescriptor) {
            output += "\nCONNECTIONS (\(edges.count)):\n"
            for edge in edges.prefix(10) {
                let direction = edge.sourceNodeId == nodeId ? "→" : "←"
                let otherId = edge.sourceNodeId == nodeId ? edge.targetNodeId : edge.sourceNodeId
                if let otherNode = fetchNode(otherId, modelContext) {
                    output += "  \(direction) \(edge.type.rawValue) (weight: \(String(format: "%.2f", edge.weight))): \(otherNode.label)\n"
                }
            }
        }
        
        output += "\n======================\n"
        
        return output
    }
    
    // MARK: - Theme Inspector
    
    /// Get detailed information about a theme
    func inspectTheme(_ themeId: UUID, modelContext: ModelContext) -> String {
        let descriptor = FetchDescriptor<ThemeNode>(
            predicate: #Predicate { $0.id == themeId }
        )
        
        guard let theme = try? modelContext.fetch(descriptor).first else {
            return "Theme not found: \(themeId.uuidString)"
        }
        
        var output = """
        === THEME INSPECTION ===
        ID: \(theme.id.uuidString)
        Label: \(theme.label)
        Description: \(theme.themeDescription)
        
        METRICS:
        - Salience: \(String(format: "%.3f", theme.salience))
        - Coherence: \(String(format: "%.3f", theme.coherence))
        - Momentum: \(String(format: "%.3f", theme.momentum))
        - Active: \(theme.isActive ? "Yes" : "No")
        - Decay Started: \(theme.decayStarted ? "Yes" : "No")
        
        TEMPORAL:
        - Emerged: \(theme.emergedAt.formatted())
        - Last Update: \(theme.lastUpdateAt.formatted())
        - Peak Salience: \(String(format: "%.3f", theme.peakSalienceValue)) at \(theme.peakSalienceAt?.formatted() ?? "N/A")
        
        KEYWORDS:
        \(theme.keywords.joined(separator: ", "))
        
        MEMBER NODES (\(theme.memberNodeIds.count)):
        """
        
        for (index, memberId) in theme.memberNodeIds.prefix(10).enumerated() {
            if let member = fetchNode(memberId, modelContext) {
                output += "\n  \(index + 1). \(member.label) (importance: \(String(format: "%.2f", member.importance)))"
            }
        }
        
        if theme.memberNodeIds.count > 10 {
            output += "\n  ... and \(theme.memberNodeIds.count - 10) more"
        }
        
        output += "\n\n======================\n"
        
        return output
    }
    
    // MARK: - Statistics
    
    func printStatistics(modelContext: ModelContext) -> String {
        let metrics = MemoryGraphTelemetry.shared.captureMetrics(modelContext: modelContext)
        
        return """
        === MEMORY GRAPH STATISTICS ===
        
        Nodes: \(metrics.totalNodes) (\(metrics.embeddedNodesCount) with embeddings)
        Edges: \(metrics.totalEdges)
        Themes: \(metrics.totalThemes) (\(metrics.activeThemes) active)
        
        Average Node Importance: \(String(format: "%.3f", metrics.avgNodeImportance))
        Average Theme Salience: \(String(format: "%.3f", metrics.avgThemeSalience))
        
        Timestamp: \(metrics.timestamp.formatted())
        
        ================================
        """
    }
    
    // MARK: - Helper Methods
    
    private func fetchNode(_ nodeId: UUID, _ modelContext: ModelContext) -> MemoryNode? {
        let descriptor = FetchDescriptor<MemoryNode>(
            predicate: #Predicate { $0.id == nodeId }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    private func getMostImportantNode(_ modelContext: ModelContext) -> MemoryNode? {
        let descriptor = FetchDescriptor<MemoryNode>(
            sortBy: [SortDescriptor(\.importance, order: .reverse)]
        )
        return try? modelContext.fetch(descriptor).first
    }
}

