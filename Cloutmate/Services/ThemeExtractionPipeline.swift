//
//  ThemeExtractionPipeline.swift
//  Cloutmate
//
//  Phase 6 - Memory Graph Research Build
//  Extracts emergent themes from memory graph using clustering
//

import Foundation
import SwiftData
import os.log

@MainActor
final class ThemeExtractionPipeline {
    static let shared = ThemeExtractionPipeline()
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "ThemeExtraction")
    private let memoryGraph = MemoryGraphService.shared
    
    private var config: AIConfig {
        AIConfigService.shared.config
    }
    
    private init() {}
    
    // MARK: - Pipeline Entry Points
    
    /// Extract themes triggered by save events
    func extractThemesOnSave(
        for object: any RecallTrackable,
        modelContext: ModelContext
    ) async {
        guard config.featureFlags.memoryGraphEnabled else { return }
        
        AIDebug.log("ThemeExtraction: Triggered on save for \(object.recallTitle)")
        
        // Create/update node for this object
        guard let node = try? await memoryGraph.findOrCreateNode(for: object, modelContext: modelContext) else {
            return
        }
        
        // Find similar nodes and create edges
        await createSimilarityEdges(for: node, modelContext: modelContext)
        
        // Check if this triggers new theme formation
        await checkForThemeEmergence(around: node, modelContext: modelContext)
    }
    
    /// Extract themes triggered by narrative events
    func extractThemesOnNarrative(modelContext: ModelContext) async {
        guard config.featureFlags.memoryGraphEnabled else { return }
        
        AIDebug.log("ThemeExtraction: Triggered on narrative event")
        
        // Perform full graph clustering
        await performFullClustering(modelContext: modelContext)
        
        // Update existing themes
        await updateExistingThemes(modelContext: modelContext)
        
        // Check for theme decay
        await decayInactiveThemes(modelContext: modelContext)
    }
    
    // MARK: - Similarity Edge Creation
    
    private func createSimilarityEdges(
        for node: MemoryNode,
        modelContext: ModelContext
    ) async {
        let similarNodes = memoryGraph.findSimilarNodes(
            to: node.id,
            threshold: 0.75, // High similarity threshold
            limit: 5,
            modelContext: modelContext
        )
        
        for similarNode in similarNodes {
            do {
                _ = try memoryGraph.createEdge(
                    from: node.id,
                    to: similarNode.id,
                    type: .similarTo,
                    weight: node.cosineSimilarity(with: similarNode),
                    reason: "Vector similarity above threshold",
                    modelContext: modelContext
                )
                AIDebug.log("ThemeExtraction: Created similarity edge to \(similarNode.label)")
            } catch {
                logger.warning("Failed to create similarity edge: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Theme Emergence Detection
    
    private func checkForThemeEmergence(
        around node: MemoryNode,
        modelContext: ModelContext
    ) async {
        // Get neighbors of this node
        let neighbors = memoryGraph.getNeighbors(of: node.id, modelContext: modelContext)
        
        // If node has 3+ high-similarity neighbors, might be a theme cluster
        if neighbors.count >= 3 {
            await formNewTheme(from: [node] + neighbors, modelContext: modelContext)
        }
    }
    
    private func formNewTheme(
        from nodes: [MemoryNode],
        modelContext: ModelContext
    ) async {
        guard nodes.count >= 3 else { return }
        
        // Calculate centroid embedding
        let embeddings = nodes.compactMap { $0.getEmbedding() }
        guard embeddings.count == nodes.count else { return }
        
        let centroid = calculateCentroid(embeddings)
        
        // Generate theme label and description using AI
        let content = nodes.map { $0.content }.joined(separator: "\n")
        guard let (label, description) = await generateThemeLabel(for: content) else {
            return
        }
        
        // Create theme node
        let theme = ThemeNode(label: label, themeDescription: description)
        theme.setCentroid(centroid)
        theme.memberNodeIds = nodes.map { $0.id }
        theme.coherence = calculateCoherence(for: nodes)
        theme.salience = Double(nodes.count) / 10.0 // Initial estimate
        theme.momentum = 1.0 // New theme has positive momentum
        
        // Extract keywords from nodes
        theme.keywords = extractKeywords(from: nodes)
        
        modelContext.insert(theme)
        try? modelContext.save()
        
        AIDebug.log("ThemeExtraction: Formed new theme '\(label)' with \(nodes.count) members")
        logger.info("New theme emerged: \(label)")
    }
    
    // MARK: - Full Clustering (DBSCAN)
    
    private func performFullClustering(modelContext: ModelContext) async {
        // Fetch all nodes with embeddings
        let descriptor = FetchDescriptor<MemoryNode>()
        guard let allNodes = try? modelContext.fetch(descriptor) else { return }
        
        let nodesWithEmbeddings = allNodes.filter { $0.getEmbedding() != nil }
        
        // Perform DBSCAN clustering
        let clusters = performDBSCANClustering(
            nodes: nodesWithEmbeddings,
            epsilon: 0.3,      // Distance threshold (1 - cosine similarity)
            minPoints: 3       // Minimum cluster size
        )
        
        AIDebug.log("ThemeExtraction: DBSCAN found \(clusters.count) clusters in full graph")
        
        // Create or update themes for each cluster
        for cluster in clusters {
            await formNewTheme(from: cluster, modelContext: modelContext)
        }
    }
    
    /// DBSCAN (Density-Based Spatial Clustering of Applications with Noise)
    /// Discovers clusters of arbitrary shape and identifies outliers
    private func performDBSCANClustering(
        nodes: [MemoryNode],
        epsilon: Double,
        minPoints: Int
    ) -> [[MemoryNode]] {
        guard !nodes.isEmpty else { return [] }
        
        // Track node states
        enum NodeState {
            case unvisited
            case visited
            case noise
        }
        
        var nodeStates = [UUID: NodeState]()
        var clusters: [[MemoryNode]] = []
        
        // Initialize all nodes as unvisited
        for node in nodes {
            nodeStates[node.id] = .unvisited
        }
        
        // Process each unvisited node
        for node in nodes {
            guard nodeStates[node.id] == .unvisited else { continue }
            nodeStates[node.id] = .visited
            
            // Find neighbors within epsilon distance
            let neighbors = findNeighbors(of: node, in: nodes, epsilon: epsilon)
            
            if neighbors.count < minPoints {
                // Not enough neighbors - mark as noise (for now)
                nodeStates[node.id] = .noise
            } else {
                // Start a new cluster with this core point
                var cluster = [node]
                var neighborQueue = neighbors
                
                // Expand cluster by processing neighbors
                while !neighborQueue.isEmpty {
                    let currentNeighbor = neighborQueue.removeFirst()
                    
                    // If this neighbor was noise, it might be a border point
                    if nodeStates[currentNeighbor.id] == .noise {
                        nodeStates[currentNeighbor.id] = .visited
                        cluster.append(currentNeighbor)
                        continue
                    }
                    
                    // Skip if already processed
                    guard nodeStates[currentNeighbor.id] == .unvisited else { continue }
                    nodeStates[currentNeighbor.id] = .visited
                    cluster.append(currentNeighbor)
                    
                    // If this neighbor is also a core point, add its neighbors to queue
                    let secondaryNeighbors = findNeighbors(of: currentNeighbor, in: nodes, epsilon: epsilon)
                    if secondaryNeighbors.count >= minPoints {
                        neighborQueue.append(contentsOf: secondaryNeighbors.filter { 
                            nodeStates[$0.id] == .unvisited || nodeStates[$0.id] == .noise
                        })
                    }
                }
                
                clusters.append(cluster)
            }
        }
        
        // Log noise points (outliers that don't belong to any theme)
        let noiseCount = nodeStates.values.filter { $0 == .noise }.count
        if noiseCount > 0 {
            AIDebug.log("ThemeExtraction: DBSCAN identified \(noiseCount) noise points (outliers)")
        }
        
        return clusters
    }
    
    /// Find all nodes within epsilon distance (using cosine similarity)
    private func findNeighbors(
        of node: MemoryNode,
        in nodes: [MemoryNode],
        epsilon: Double
    ) -> [MemoryNode] {
        var neighbors: [MemoryNode] = []
        
        for candidateNode in nodes {
            // Skip self
            guard candidateNode.id != node.id else { continue }
            
            // Calculate distance (1 - cosine similarity)
            let similarity = node.cosineSimilarity(with: candidateNode)
            let distance = 1.0 - similarity
            
            // Add to neighbors if within epsilon distance
            if distance <= epsilon {
                neighbors.append(candidateNode)
            }
        }
        
        return neighbors
    }
    
    // MARK: - Theme Updates
    
    private func updateExistingThemes(modelContext: ModelContext) async {
        let themes = memoryGraph.getActiveThemes(modelContext: modelContext)
        
        for theme in themes {
            // Fetch member nodes
            let members = theme.memberNodeIds.compactMap { nodeId in
                memoryGraph.findSimilarNodes(to: nodeId, threshold: 0.0, limit: 1, modelContext: modelContext).first
            }
            
            // Recalculate coherence
            theme.coherence = calculateCoherence(for: members)
            
            // Calculate momentum (change in membership)
            let previousCount = theme.memberNodeIds.count
            let currentCount = members.count
            theme.momentum = Double(currentCount - previousCount) / Double(max(previousCount, 1))
            
            // Update salience
            theme.recalculateSalience()
            theme.lastUpdateAt = Date()
            
            AIDebug.log("ThemeExtraction: Updated theme '\(theme.label)' - salience: \(String(format: "%.2f", theme.salience))")
        }
        
        try? modelContext.save()
    }
    
    // MARK: - Theme Decay
    
    private func decayInactiveThemes(modelContext: ModelContext) async {
        let allThemes = memoryGraph.getActiveThemes(modelContext: modelContext)
        
        for theme in allThemes {
            if theme.shouldDecay() {
                theme.beginDecay()
                AIDebug.log("ThemeExtraction: Theme '\(theme.label)' marked for decay")
                logger.info("Theme decaying: \(theme.label)")
            }
        }
        
        try? modelContext.save()
    }
    
    // MARK: - Helper Methods
    
    private func calculateCentroid(_ embeddings: [[Float]]) -> [Float] {
        guard !embeddings.isEmpty else { return [] }
        
        let dimensions = embeddings[0].count
        var centroid = [Float](repeating: 0.0, count: dimensions)
        
        for embedding in embeddings {
            for i in 0..<dimensions {
                centroid[i] += embedding[i]
            }
        }
        
        let count = Float(embeddings.count)
        for i in 0..<dimensions {
            centroid[i] /= count
        }
        
        return centroid
    }
    
    private func calculateCoherence(for nodes: [MemoryNode]) -> Double {
        guard nodes.count >= 2 else { return 0.0 }
        
        var totalSimilarity = 0.0
        var pairCount = 0
        
        for i in 0..<nodes.count {
            for j in (i+1)..<nodes.count {
                totalSimilarity += nodes[i].cosineSimilarity(with: nodes[j])
                pairCount += 1
            }
        }
        
        return pairCount > 0 ? totalSimilarity / Double(pairCount) : 0.0
    }
    
    private func extractKeywords(from nodes: [MemoryNode]) -> [String] {
        // Simple keyword extraction: most common words across node labels
        let allWords = nodes.flatMap { node in
            node.label.lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { $0.count > 3 }
        }
        
        let wordCounts = Dictionary(grouping: allWords, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        return Array(wordCounts.prefix(5).map { $0.key })
    }
    
    private func generateThemeLabel(for content: String) async -> (String, String)? {
        // Use Gemini to generate a theme label and description
        let prompt = """
        Based on this collection of related content, generate a concise theme label (2-4 words) and a one-sentence description.
        
        Content:
        \(content.prefix(1000))
        
        Return ONLY JSON: {"label": "Theme Name", "description": "One sentence description."}
        """
        
        do {
            let response = try await GeminiService.shared.generateResponse(for: prompt)
            
            // Parse JSON response
            if let data = response.data(using: .utf8),
               let json = try? JSONDecoder().decode([String: String].self, from: data),
               let label = json["label"],
               let description = json["description"] {
                return (label, description)
            }
        } catch {
            logger.warning("Failed to generate theme label: \(error.localizedDescription)")
        }
        
        return nil
    }
}

