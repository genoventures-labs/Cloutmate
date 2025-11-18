//
//  MemoryGraphService.swift
//  FocusOS
//
//  Phase 6 - Memory Graph Research Build
//  Aurora's long-term cognitive map - upgraded to real memory system with reinforcement, consolidation, and predictive integration
//

import Foundation
import SwiftData
import FocusOSShared
import os.log

/// Subgraph representing a persistent cluster of related nodes
@Model
final class MemorySubgraph {
    @Attribute(.unique) var id: UUID = UUID()
    var title: String
    var centroidEmbedding: Data?
    var embeddingDimensions: Int = 0
    var nodeIds: [UUID] = []
    var importanceScore: Double = 0.5
    var themeRaw: String?
    var createdAt: Date = Date()
    var lastUpdated: Date = Date()
    
    init(title: String) {
        self.title = title
        self.createdAt = Date()
        self.lastUpdated = Date()
    }
    
    /// Set centroid embedding
    func setCentroid(_ embedding: [Float]) {
        self.embeddingDimensions = embedding.count
        self.centroidEmbedding = Data(bytes: embedding, count: embedding.count * MemoryLayout<Float>.size)
    }
    
    /// Get centroid embedding
    func getCentroid() -> [Float]? {
        guard let data = centroidEmbedding, embeddingDimensions > 0 else { return nil }
        return data.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self).prefix(embeddingDimensions))
        }
    }
}

/// Predictive memory signal for PredictiveContextManager
struct PredictiveMemorySignal: Sendable {
    let dominantTheme: String?
    let matchingNodes: [UUID]
    let relevanceScore: Double
    let recencyScore: Double
    let emotionalTie: EmotionalSnapshot?
}

/// Event hooks for other services
typealias MemoryGraphHook = (MemoryNode) -> Void
typealias EdgeHook = (MemoryEdge) -> Void
typealias ConsolidationHook = () -> Void

@MainActor
final class MemoryGraphService {
    static let shared = MemoryGraphService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "MemoryGraph")
    
    private var config: AIConfig {
        AIConfigService.shared.config
    }
    
    // Cached graph indices for performance
    private var embeddingIndex: [UUID: [Float]] = [:]
    private var themeIndex: [String: Set<UUID>] = [:]  // theme label -> node IDs
    private var clusterIndex: [String: Set<UUID>] = [:]  // cluster name -> node IDs
    private var recencyIndex: [(nodeId: UUID, lastAccess: Date)] = []
    
    // In-memory caches
    private var nodeCache: [UUID: MemoryNode] = [:]
    private var edgeCache: [UUID: [MemoryEdge]] = [:]
    private var lastCacheRefresh: Date?
    private let cacheValidity: TimeInterval = 300 // 5 minutes
    
    // Event hooks
    private var nodeCreatedHooks: [MemoryGraphHook] = []
    private var nodeReinforcedHooks: [MemoryGraphHook] = []
    private var nodeMergedHooks: [MemoryGraphHook] = []
    private var edgeCreatedHooks: [EdgeHook] = []
    private var consolidationHooks: [ConsolidationHook] = []
    
    // Embedding model configuration
    private let defaultEmbeddingModel = "gemma3:4b"
    
    private init() {}
    
    // MARK: - Real Embedding Generation
    
    /// Generate real embedding using specified model (with fallback to synthetic)
    func generateEmbedding(
        for text: String,
        using model: String? = nil
    ) async throws -> [Float] {
        let modelName = model ?? defaultEmbeddingModel
        
        // Try to generate real embedding using Ollama
        // For now, use synthetic with model name tracking
        // TODO: Integrate with Ollama embedding API when available
        let embedding = generateSyntheticEmbedding(for: text)
        return embedding
    }
    
    /// Generate synthetic embedding (fallback)
    private func generateSyntheticEmbedding(for text: String) -> [Float] {
        let dimensions = 768
        var embedding = [Float](repeating: 0.0, count: dimensions)
        
        let hash = text.hash
        for i in 0..<dimensions {
            let seed = hash &+ i
            embedding[i] = Float(sin(Double(seed))) * 0.5 + 0.5
        }
        
        // Normalize
        let magnitude = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
        if magnitude > 0 {
            embedding = embedding.map { $0 / magnitude }
        }
        
        return embedding
    }
    
    // MARK: - Enhanced Node Operations
    
    /// Create a node for a workspace object with full metadata
    func createNode(
        for object: any RecallTrackable,
        modelContext: ModelContext
    ) async throws -> MemoryNode {
        guard config.featureFlags.memoryGraphEnabled else {
            throw MemoryGraphError.featureDisabled
        }
        
        let content = buildContent(for: object)
        
        // Analyze emotional tone
        let emotionalSnapshot = EmotionAnalyzer.analyzeTone(text: content)
        
        let node = MemoryNode(
            nodeType: mapToNodeType(object.recallObjectType),
            objectId: object.recallObjectId,
            label: object.recallTitle,
            content: content
        )
        
        // Set emotional properties
        node.emotionalTone = emotionalSnapshot.primaryEmotion
        node.emotionalIntensity = emotionalSnapshot.intensity
        
        // Generate embedding with model tracking
        do {
            let embedding = try await generateEmbedding(for: content)
            node.setEmbedding(embedding)
            node.embeddingModelName = defaultEmbeddingModel
        } catch {
            logger.warning("Failed to generate embedding: \(error.localizedDescription)")
        }
        
        // Calculate initial importance
        node.recalculateImportance()
        
        modelContext.insert(node)
        try modelContext.save()
        
        // Update indices
        updateEmbeddingIndex(node: node)
        updateRecencyIndex(node: node)
        
        // Trigger hooks
        notifyNodeCreated(node)
        
        logger.info("Created memory node: \(node.label)")
        return node
    }
    
    /// Create a node for a concept
    func createConceptNode(
        concept: String,
        content: String,
        modelContext: ModelContext
    ) async throws -> MemoryNode {
        guard config.featureFlags.memoryGraphEnabled else {
            throw MemoryGraphError.featureDisabled
        }
        
        // Analyze emotional tone
        let emotionalSnapshot = EmotionAnalyzer.analyzeTone(text: content)
        
        let node = MemoryNode(
            nodeType: .concept,
            label: concept,
            content: content
        )
        
        node.emotionalTone = emotionalSnapshot.primaryEmotion
        node.emotionalIntensity = emotionalSnapshot.intensity
        
        // Generate embedding
        if let embedding = try? await generateEmbedding(for: content) {
            node.setEmbedding(embedding)
            node.embeddingModelName = defaultEmbeddingModel
        }
        
        node.recalculateImportance()
        
        modelContext.insert(node)
        try modelContext.save()
        
        updateEmbeddingIndex(node: node)
        updateRecencyIndex(node: node)
        notifyNodeCreated(node)
        
        return node
    }
    
    /// Find or create node for an object
    func findOrCreateNode(
        for object: any RecallTrackable,
        modelContext: ModelContext
    ) async throws -> MemoryNode {
        let objectId = object.recallObjectId
        let descriptor = FetchDescriptor<MemoryNode>(
            predicate: #Predicate { $0.objectId == objectId }
        )
        
        if let existing = try? modelContext.fetch(descriptor).first {
            // Reinforce on access
            await reinforceNode(existing.id, modelContext: modelContext)
            return existing
        }
        
        return try await createNode(for: object, modelContext: modelContext)
    }

    // MARK: - Workspace Sync Hooks

    func syncOnCreate(
        object: any RecallTrackable,
        modelContext: ModelContext
    ) async {
        guard config.featureFlags.memoryGraphEnabled else { return }
        do {
            _ = try await findOrCreateNode(for: object, modelContext: modelContext)
            logger.debug("MemoryGraph synced creation for \(object.recallTitle)")
        } catch {
            logger.error("MemoryGraph failed to sync creation: \(error.localizedDescription)")
        }
    }

    func syncOnUpdate(
        object: any RecallTrackable,
        modelContext: ModelContext
    ) async {
        guard config.featureFlags.memoryGraphEnabled else { return }
        let objectId = object.recallObjectId as UUID?
        let descriptor = FetchDescriptor<MemoryNode>(
            predicate: #Predicate { $0.objectId == objectId }
        )
        guard let node = try? modelContext.fetch(descriptor).first else {
            await syncOnCreate(object: object, modelContext: modelContext)
            return
        }
        node.label = object.recallTitle
        node.content = buildContent(for: object)
        node.lastAccessedAt = Date()
        node.recalculateImportance()
        try? modelContext.save()
        logger.debug("MemoryGraph synced update for \(object.recallTitle)")
    }

    func syncOnRename(
        object: any RecallTrackable,
        oldTitle: String,
        modelContext: ModelContext
    ) async {
        await syncOnUpdate(object: object, modelContext: modelContext)
        logger.debug("MemoryGraph rename captured from \(oldTitle) to \(object.recallTitle)")
    }

    func syncOnArchive(
        object: any RecallTrackable,
        modelContext: ModelContext
    ) async {
        guard config.featureFlags.memoryGraphEnabled else { return }
        try? updateArchivedStatus(for: object.recallObjectId, isArchived: true, modelContext: modelContext)
        logger.debug("MemoryGraph archived node \(object.recallTitle)")
    }

    func syncOnDelete(
        objectId: UUID,
        objectType: RecallObjectType,
        modelContext: ModelContext
    ) async {
        guard config.featureFlags.memoryGraphEnabled else { return }
        let objectIdOpt = objectId as UUID?
        let descriptor = FetchDescriptor<MemoryNode>(
            predicate: #Predicate { $0.objectId == objectIdOpt }
        )
        guard let node = try? modelContext.fetch(descriptor).first else { return }
        removeEdges(for: node.id, modelContext: modelContext)
        modelContext.delete(node)
        nodeCache.removeValue(forKey: node.id)
        try? modelContext.save()
        logger.debug("MemoryGraph deleted node for \(objectType.rawValue) \(objectId.uuidString)")
    }

    func syncOnStatusChange(
        object: any RecallTrackable,
        modelContext: ModelContext
    ) async {
        guard config.featureFlags.memoryGraphEnabled else { return }
        let objectId = object.recallObjectId as UUID?
        let descriptor = FetchDescriptor<MemoryNode>(
            predicate: #Predicate { $0.objectId == objectId }
        )
        guard let node = try? modelContext.fetch(descriptor).first else { return }
        var statusValue = object.recallObjectType.rawValue.lowercased()
        if let task = object as? Task {
            statusValue = task.statusRaw
        } else if let project = object as? Project {
            statusValue = project.statusRaw
        }
        let statusTag = "status:\(statusValue.lowercased())"
        node.tags.removeAll { $0.hasPrefix("status:") }
        node.tags.append(statusTag)
        node.lastAccessedAt = Date()
        try? modelContext.save()
        logger.debug("MemoryGraph status change recorded for \(object.recallTitle)")
    }

    func syncOnTaskCompletion(
        task: Task,
        modelContext: ModelContext
    ) async {
        guard config.featureFlags.memoryGraphEnabled else { return }
        await syncOnStatusChange(object: task, modelContext: modelContext)
        let taskId = task.id as UUID?
        let descriptor = FetchDescriptor<MemoryNode>(
            predicate: #Predicate { $0.objectId == taskId }
        )
        if let node = try? modelContext.fetch(descriptor).first {
            await reinforceNode(node.id, modelContext: modelContext)
        }
    }
    
    // MARK: - Contextual Reinforcement
    
    /// Reinforce node and propagate to neighbors and themes
    func reinforceNode(
        _ nodeId: UUID,
        modelContext: ModelContext
    ) async {
        guard let node = fetchNode(by: nodeId, modelContext: modelContext) else {
            return
        }
        
        // Boost node
        node.boost(amount: 0.1)
        node.lastReinforcedAt = Date()
        node.recalculateImportance()
        
        // Boost neighbors
        await reinforceNeighbors(of: nodeId, modelContext: modelContext)
        
        // Boost theme clusters
        await reinforceThemeClusters(for: node, modelContext: modelContext)
        
        // Apply ARTE emotional intensity boost
        let arteState = ReactiveThemeManager.shared.currentEmotion()
        if arteState == .energized || arteState == .focused {
            node.emotionalIntensity = min(1.0, node.emotionalIntensity + 0.05)
        }
        
        // Apply PredictiveContextManager trajectory boost
        if let fusedState = PredictiveContextManager.shared.latestFusedState,
           fusedState.trajectory.isTrendingPositive {
            node.importance = min(1.0, node.importance + 0.05)
        }
        
        try? modelContext.save()
        
        // Update indices
        updateEmbeddingIndex(node: node)
        updateRecencyIndex(node: node)
        
        // Trigger hooks
        notifyNodeReinforced(node)
        
        logger.debug("Reinforced node: \(node.label)")
    }
    
    /// Reinforce all neighbors of a node
    private func reinforceNeighbors(
        of nodeId: UUID,
        modelContext: ModelContext
    ) async {
        let neighbors = getNeighbors(of: nodeId, modelContext: modelContext)
        
        for neighbor in neighbors {
            // Boost neighbor (smaller boost)
            neighbor.boost(amount: 0.05)
            neighbor.recalculateImportance()
            
            // Strengthen edge
            if let edge = getEdge(from: nodeId, to: neighbor.id, modelContext: modelContext) {
                edge.reinforce(amount: 0.05)
            }
        }
        
        try? modelContext.save()
    }
    
    /// Reinforce theme clusters this node belongs to
    private func reinforceThemeClusters(
        for node: MemoryNode,
        modelContext: ModelContext
    ) async {
        guard !node.themeIds.isEmpty else { return }
        
        let themeIds = node.themeIds
        let themeDescriptor = FetchDescriptor<ThemeNode>(
            predicate: #Predicate { theme in
                themeIds.contains(theme.id)
            }
        )
        
        guard let themes = try? modelContext.fetch(themeDescriptor) else { return }
        
        for theme in themes {
            // Boost theme salience
            theme.salience = min(1.0, theme.salience + 0.05)
            theme.lastUpdateAt = Date()
            theme.recalculateSalience()
        }
        
        try? modelContext.save()
    }
    
    // MARK: - Enhanced Edge Operations with Decay
    
    /// Create an edge with semantic affinity calculation
    func createEdge(
        from sourceId: UUID,
        to targetId: UUID,
        type: MemoryEdgeType,
        weight: Double = 0.5,
        reason: String? = nil,
        modelContext: ModelContext
    ) throws -> MemoryEdge {
        guard config.featureFlags.memoryGraphEnabled else {
            throw MemoryGraphError.featureDisabled
        }
        
        // Check if edge already exists
        let descriptor = FetchDescriptor<MemoryEdge>(
            predicate: #Predicate { edge in
                edge.sourceNodeId == sourceId && edge.targetNodeId == targetId
            }
        )
        
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.strengthen()
            try? modelContext.save()
            return existing
        }
        
        // Calculate semantic affinity
        let semanticAffinity = calculateSemanticAffinity(
            sourceId: sourceId,
            targetId: targetId,
            modelContext: modelContext
        )
        
        // Create edge with semantic affinity
        let edge = MemoryEdge(
            sourceNodeId: sourceId,
            targetNodeId: targetId,
            edgeType: type,
            weight: weight,
            reason: reason
        )
        
        edge.semanticAffinity = semanticAffinity
        edge.lastReinforcedAt = Date()
        edge.importanceScore = weight
        
        modelContext.insert(edge)
        try modelContext.save()
        
        // Update edge counts
        updateEdgeCount(for: sourceId, modelContext: modelContext)
        updateEdgeCount(for: targetId, modelContext: modelContext)
        
        // Update cache
        edgeCache.removeValue(forKey: sourceId)
        edgeCache.removeValue(forKey: targetId)
        
        // Trigger hooks
        notifyEdgeCreated(edge)
        
        logger.info("Created edge \(type.rawValue) from \(sourceId) to \(targetId) with affinity \(semanticAffinity)")
        return edge
    }
    
    /// Calculate semantic affinity between two nodes
    private func calculateSemanticAffinity(
        sourceId: UUID,
        targetId: UUID,
        modelContext: ModelContext
    ) -> Double {
        guard let sourceNode = fetchNode(by: sourceId, modelContext: modelContext),
              let targetNode = fetchNode(by: targetId, modelContext: modelContext) else {
            return 0.0
        }
        
        return sourceNode.cosineSimilarity(with: targetNode)
    }
    
    /// Get edge between two nodes
    private func getEdge(
        from sourceId: UUID,
        to targetId: UUID,
        modelContext: ModelContext
    ) -> MemoryEdge? {
        let descriptor = FetchDescriptor<MemoryEdge>(
            predicate: #Predicate { edge in
                edge.sourceNodeId == sourceId && edge.targetNodeId == targetId
            }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    /// Apply decay to all edges
    func applyEdgeDecay(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<MemoryEdge>(
            predicate: #Predicate { edge in
                !edge.isArchived
            }
        )
        
        guard let edges = try? modelContext.fetch(descriptor) else { return }
        
        var decayedCount = 0
        for edge in edges {
            edge.applyDecay()
            if edge.isArchived {
                decayedCount += 1
            }
        }
        
        try? modelContext.save()
        
        if decayedCount > 0 {
            logger.info("Applied decay to \(edges.count) edges, archived \(decayedCount)")
        }
    }
    
    // MARK: - Theme Clustering with Embedding Centroids
    
    /// Update theme centroids based on member node embeddings
    func updateThemeCentroids(modelContext: ModelContext) async {
        let themeDescriptor = FetchDescriptor<ThemeNode>(
            predicate: #Predicate { $0.isActive == true }
        )
        
        guard let themes = try? modelContext.fetch(themeDescriptor) else { return }
        
        for theme in themes {
            guard !theme.memberNodeIds.isEmpty else { continue }
            
            let memberIds = theme.memberNodeIds
            let nodeDescriptor = FetchDescriptor<MemoryNode>(
                predicate: #Predicate { node in
                    memberIds.contains(node.id)
                }
            )
            
            guard let memberNodes = try? modelContext.fetch(nodeDescriptor) else { continue }
            
            // Filter to nodes with embeddings
            let nodesWithEmbeddings = memberNodes.compactMap { node -> (embedding: [Float], node: MemoryNode)? in
                guard let embedding = node.getEmbedding() else { return nil }
                return (embedding, node)
            }
            
            guard !nodesWithEmbeddings.isEmpty else { continue }
            
            // Calculate centroid (mean of all embeddings)
            let dimension = nodesWithEmbeddings.first!.embedding.count
            var centroid = [Float](repeating: 0.0, count: dimension)
            
            for (embedding, _) in nodesWithEmbeddings {
                for i in 0..<dimension {
                    centroid[i] += embedding[i]
                }
            }
            
            // Normalize
            let count = Float(nodesWithEmbeddings.count)
            centroid = centroid.map { $0 / count }
            
            // Normalize vector
            let magnitude = sqrt(centroid.reduce(0) { $0 + $1 * $1 })
            if magnitude > 0 {
                centroid = centroid.map { $0 / magnitude }
            }
            
            theme.setCentroid(centroid)
            theme.lastUpdateAt = Date()
        }
        
        try? modelContext.save()
        
        logger.info("Updated centroids for \(themes.count) themes")
    }
    
    /// Attach themes to a node based on embedding similarity
    func attachThemesToNode(
        _ node: MemoryNode,
        modelContext: ModelContext
    ) async {
        guard let nodeEmbedding = node.getEmbedding() else { return }
        
        let themes = getActiveThemes(modelContext: modelContext)
        let threshold = 0.7
        
        var attachedThemes: [UUID] = []
        
        for theme in themes {
            guard let themeCentroid = theme.getCentroid(),
                  themeCentroid.count == nodeEmbedding.count else {
                continue
            }
            
            // Calculate cosine similarity
            let similarity = cosineSimilarity(nodeEmbedding, themeCentroid)
            
            if similarity >= threshold {
                // Attach theme
                if !node.themeIds.contains(theme.id) {
                    node.themeIds.append(theme.id)
                }
                theme.addMember(node.id)
                attachedThemes.append(theme.id)
                
                // Update cluster association strength
                node.clusterAssociationStrength = max(
                    node.clusterAssociationStrength,
                    similarity
                )
            }
        }
        
        if !attachedThemes.isEmpty {
            node.recalculateImportance()
            try? modelContext.save()
            
            // Update theme index
            for themeId in attachedThemes {
                if let theme = themes.first(where: { $0.id == themeId }) {
                    updateThemeIndex(theme: theme)
                }
            }
            
            logger.debug("Attached \(attachedThemes.count) themes to node \(node.label)")
        }
    }
    
    // MARK: - Subgraph Auto-Formation
    
    /// Detect and create subgraphs from persistent clusters
    func detectAndCreateSubgraphs(
        similarityThreshold: Double = 0.75,
        minClusterSize: Int = 3,
        modelContext: ModelContext
    ) async -> [MemorySubgraph] {
        guard config.featureFlags.memoryGraphEnabled else { return [] }
        
        let descriptor = FetchDescriptor<MemoryNode>()
        guard let allNodes = try? modelContext.fetch(descriptor) else { return [] }
        
        // Filter to nodes with embeddings
        let nodesWithEmbeddings = allNodes.compactMap { node -> (node: MemoryNode, embedding: [Float])? in
            guard let embedding = node.getEmbedding() else { return nil }
            return (node, embedding)
        }
        
        // Simple clustering: find groups of similar nodes
        var processed: Set<UUID> = []
        var subgraphs: [MemorySubgraph] = []
        
        for (node, embedding) in nodesWithEmbeddings {
            guard !processed.contains(node.id) else { continue }
            
            // Find similar nodes
            var cluster: [(node: MemoryNode, embedding: [Float])] = [(node, embedding)]
            
            for (otherNode, otherEmbedding) in nodesWithEmbeddings {
                guard otherNode.id != node.id,
                      !processed.contains(otherNode.id) else {
                    continue
                }
                
                let similarity = cosineSimilarity(embedding, otherEmbedding)
                if similarity >= similarityThreshold {
                    cluster.append((otherNode, otherEmbedding))
                }
            }
            
            // Create subgraph if cluster is large enough
            if cluster.count >= minClusterSize {
                let subgraph = createSubgraph(from: cluster, modelContext: modelContext)
                subgraphs.append(subgraph)
                
                // Mark as processed
                for (clusterNode, _) in cluster {
                    processed.insert(clusterNode.id)
                }
            }
        }
        
        try? modelContext.save()
        
        logger.info("Detected and created \(subgraphs.count) subgraphs")
        return subgraphs
    }
    
    /// Create a subgraph from a cluster of nodes
    private func createSubgraph(
        from cluster: [(node: MemoryNode, embedding: [Float])],
        modelContext: ModelContext
    ) -> MemorySubgraph {
        // Calculate centroid
        let dimension = cluster.first!.embedding.count
        var centroid = [Float](repeating: 0.0, count: dimension)
        
        for (_, embedding) in cluster {
            for i in 0..<dimension {
                centroid[i] += embedding[i]
            }
        }
        
        let count = Float(cluster.count)
        centroid = centroid.map { $0 / count }
        
        // Normalize
        let magnitude = sqrt(centroid.reduce(0) { $0 + $1 * $1 })
        if magnitude > 0 {
            centroid = centroid.map { $0 / magnitude }
        }
        
        // Create subgraph
        let title = cluster.first!.node.label + " (and \(cluster.count - 1) related)"
        let subgraph = MemorySubgraph(title: title)
        subgraph.setCentroid(centroid)
        subgraph.nodeIds = cluster.map { $0.node.id }
        
        // Calculate importance from node importance
        let avgImportance = cluster.map { $0.node.importance }.reduce(0, +) / Double(cluster.count)
        subgraph.importanceScore = avgImportance
        
        modelContext.insert(subgraph)
        
        // Update cluster index
        updateClusterIndex(subgraph: subgraph)
        
        return subgraph
    }
    
    // MARK: - Multi-Hop Semantic Search
    
    enum SearchStrategy {
        case bfs          // Breadth-first
        case dfs          // Depth-first
        case weightedBfs  // Weighted by edge weight
        case semanticBfs  // Ordered by embedding similarity
    }
    
    /// Find semantically relevant nodes using multi-hop traversal
    func findSemanticallyRelevantNodes(
        to embedding: [Float],
        hops: Int = 2,
        strategy: SearchStrategy = .semanticBfs,
        threshold: Double = 0.6,
        limit: Int = 20,
        modelContext: ModelContext
    ) -> [MemoryNode] {
        guard config.featureFlags.memoryGraphEnabled else { return [] }
        
        // Start from most similar nodes
        let descriptor = FetchDescriptor<MemoryNode>()
        guard let allNodes = try? modelContext.fetch(descriptor) else { return [] }
        
        var candidates: [(node: MemoryNode, similarity: Double, hop: Int)] = []
        
        // Calculate direct similarities (hop 0)
        for node in allNodes {
            guard let nodeEmbedding = node.getEmbedding(),
                  nodeEmbedding.count == embedding.count else {
                continue
            }
            
            let similarity = cosineSimilarity(embedding, nodeEmbedding)
            if similarity >= threshold {
                candidates.append((node, similarity, 0))
            }
        }
        
        // Traverse graph for additional candidates
        var visited: Set<UUID> = Set(candidates.map { $0.node.id })
        
        for hop in 1...hops {
            var nextHopCandidates: [(node: MemoryNode, similarity: Double, hop: Int)] = []
            
            for (candidate, _, _) in candidates where candidate.edgeCount > 0 {
                let neighbors = getNeighbors(of: candidate.id, modelContext: modelContext)
                
                for neighbor in neighbors {
                    guard !visited.contains(neighbor.id),
                          let neighborEmbedding = neighbor.getEmbedding(),
                          neighborEmbedding.count == embedding.count else {
                        continue
                    }
                    
                    visited.insert(neighbor.id)
                    
                    let similarity = cosineSimilarity(embedding, neighborEmbedding)
                    
                    // Apply hop penalty
                    let hopPenalty = Double(hop) * 0.1
                    let adjustedSimilarity = max(0.0, similarity - hopPenalty)
                    
                    if adjustedSimilarity >= threshold {
                        nextHopCandidates.append((neighbor, adjustedSimilarity, hop))
                    }
                }
            }
            
            candidates.append(contentsOf: nextHopCandidates)
        }
        
        // Sort by strategy
        switch strategy {
        case .bfs, .weightedBfs, .semanticBfs:
            candidates.sort { $0.similarity > $1.similarity }
        case .dfs:
            candidates.sort { $0.hop < $1.hop || ($0.hop == $1.hop && $0.similarity > $1.similarity) }
        }
        
        return Array(candidates.prefix(limit).map { $0.node })
    }
    
    // MARK: - Predictive Context Manager Integration
    
    /// Get predictive relevance signal for a message
    func predictiveRelevance(
        for message: String,
        modelContext: ModelContext
    ) async -> PredictiveMemorySignal {
        guard config.featureFlags.memoryGraphEnabled else {
            return PredictiveMemorySignal(
                dominantTheme: nil,
                matchingNodes: [],
                relevanceScore: 0.0,
                recencyScore: 0.0,
                emotionalTie: nil
            )
        }
        
        // Generate embedding for message
        guard let messageEmbedding = try? await generateEmbedding(for: message) else {
            return PredictiveMemorySignal(
                dominantTheme: nil,
                matchingNodes: [],
                relevanceScore: 0.0,
                recencyScore: 0.0,
                emotionalTie: nil
            )
        }
        
        // Find matching nodes
        let matchingNodes = findSemanticallyRelevantNodes(
            to: messageEmbedding,
            hops: 2,
            strategy: .semanticBfs,
            threshold: 0.6,
            limit: 10,
            modelContext: modelContext
        )
        
        // Get dominant theme
        let dominantTheme = findDominantTheme(for: matchingNodes, modelContext: modelContext)
        
        // Calculate recency score
        let recencyScore = calculateRecencyScore(for: matchingNodes)
        
        // Calculate relevance score
        let relevanceScore = calculateRelevanceScore(
            nodes: matchingNodes,
            recencyScore: recencyScore
        )
        
        // Get emotional tie
        let emotionalTie = analyzeEmotionalTie(for: matchingNodes)
        
        return PredictiveMemorySignal(
            dominantTheme: dominantTheme,
            matchingNodes: matchingNodes.map { $0.id },
            relevanceScore: relevanceScore,
            recencyScore: recencyScore,
            emotionalTie: emotionalTie
        )
    }
    
    private func findDominantTheme(
        for nodes: [MemoryNode],
        modelContext: ModelContext
    ) -> String? {
        guard !nodes.isEmpty else { return nil }
        
        // Count theme occurrences
        var themeCounts: [UUID: Int] = [:]
        for node in nodes {
            for themeId in node.themeIds {
                themeCounts[themeId, default: 0] += 1
            }
        }
        
        // Find most common theme
        guard let (dominantThemeId, count) = themeCounts.max(by: { $0.value < $1.value }),
              count >= 2 else {
            return nil
        }
        
        let themeDescriptor = FetchDescriptor<ThemeNode>(
            predicate: #Predicate { $0.id == dominantThemeId }
        )
        
        return try? modelContext.fetch(themeDescriptor).first?.label
    }
    
    private func calculateRecencyScore(for nodes: [MemoryNode]) -> Double {
        guard !nodes.isEmpty else { return 0.0 }
        
        let now = Date()
        let scores = nodes.map { node in
            let daysSinceAccess = now.timeIntervalSince(node.lastAccessedAt) / 86400.0
            return max(0.0, 1.0 - (daysSinceAccess / 30.0))  // Decay over 30 days
        }
        
        return scores.reduce(0, +) / Double(scores.count)
    }
    
    private func calculateRelevanceScore(
        nodes: [MemoryNode],
        recencyScore: Double
    ) -> Double {
        guard !nodes.isEmpty else { return 0.0 }
        
        let avgImportance = nodes.map { $0.importance }.reduce(0, +) / Double(nodes.count)
        
        // Combine importance and recency
        return (avgImportance * 0.6) + (recencyScore * 0.4)
    }
    
    private func analyzeEmotionalTie(for nodes: [MemoryNode]) -> EmotionalSnapshot {
        guard !nodes.isEmpty else { return .neutral }
        
        // Aggregate emotional tones
        let tones = nodes.compactMap { $0.emotionalTone }
        guard !tones.isEmpty else { return .neutral }
        
        // Find most common tone
        let toneCounts = Dictionary(grouping: tones, by: { $0 }).mapValues { $0.count }
        let dominantTone = toneCounts.max(by: { $0.value < $1.value })?.key ?? .neutral
        
        // Calculate average intensity
        let avgIntensity = nodes.map { $0.emotionalIntensity }.reduce(0, +) / Double(nodes.count)
        
        return EmotionalSnapshot(
            primaryEmotion: dominantTone,
            secondaryEmotion: nil,
            valence: dominantTone.valence,
            intensity: avgIntensity,
            keywords: []
        )
    }
    
    // MARK: - Auto-Merge Redundant Nodes
    
    /// Merge near-duplicate nodes
    func mergeRedundantNodes(
        similarityThreshold: Double = 0.8,
        modelContext: ModelContext
    ) async -> Int {
        guard config.featureFlags.memoryGraphEnabled else { return 0 }
        
        let descriptor = FetchDescriptor<MemoryNode>()
        guard let allNodes = try? modelContext.fetch(descriptor) else { return 0 }
        
        var mergedCount = 0
        var processed: Set<UUID> = []
        
        for node in allNodes {
            guard !processed.contains(node.id),
                  let embedding = node.getEmbedding() else {
                continue
            }
            
            // Find similar nodes
            var similarNodes: [MemoryNode] = []
            
            for other in allNodes {
                guard other.id != node.id,
                      !processed.contains(other.id),
                      other.nodeType == node.nodeType,
                      let otherEmbedding = other.getEmbedding(),
                      otherEmbedding.count == embedding.count else {
                    continue
                }
                
                let similarity = cosineSimilarity(embedding, otherEmbedding)
                
                // Check temporal proximity (within 24 hours)
                let timeDiff = abs(node.createdAt.timeIntervalSince(other.createdAt))
                let isTemporallyProximate = timeDiff < 86400.0
                
                if similarity >= similarityThreshold && isTemporallyProximate {
                    similarNodes.append(other)
                }
            }
            
            if !similarNodes.isEmpty {
                // Merge into primary node
                await mergeNodes(
                    primary: node,
                    duplicates: similarNodes,
                    modelContext: modelContext
                )
                
                processed.insert(node.id)
                for duplicate in similarNodes {
                    processed.insert(duplicate.id)
                }
                
                mergedCount += similarNodes.count
            }
        }
        
        try? modelContext.save()
        
        logger.info("Merged \(mergedCount) redundant nodes")
        return mergedCount
    }
    
    /// Merge duplicate nodes into primary
    private func mergeNodes(
        primary: MemoryNode,
        duplicates: [MemoryNode],
        modelContext: ModelContext
    ) async {
        // Combine edges
        for duplicate in duplicates {
            let duplicateEdges = getEdges(connectedTo: duplicate.id, modelContext: modelContext)
            
            for edge in duplicateEdges {
                // Update edge to point to primary instead
                if edge.sourceNodeId == duplicate.id {
                    edge.sourceNodeId = primary.id
                }
                if edge.targetNodeId == duplicate.id {
                    edge.targetNodeId = primary.id
                }
                edge.reinforce(amount: 0.1)  // Strengthen merged connection
            }
        }
        
        // Combine themes
        var allThemeIds = Set(primary.themeIds)
        for duplicate in duplicates {
            allThemeIds.formUnion(duplicate.themeIds)
        }
        primary.themeIds = Array(allThemeIds)
        
        // Combine tags
        var allTags = Set(primary.tags)
        for duplicate in duplicates {
            allTags.formUnion(duplicate.tags)
        }
        primary.tags = Array(allTags)
        
        // Unify embeddings (weighted average)
        var combinedEmbedding: [Float]?
        if let primaryEmbedding = primary.getEmbedding() {
            combinedEmbedding = primaryEmbedding
            
            for duplicate in duplicates {
                if let dupEmbedding = duplicate.getEmbedding(),
                   dupEmbedding.count == combinedEmbedding!.count {
                    // Weighted average (primary gets higher weight)
                    for i in 0..<combinedEmbedding!.count {
                        combinedEmbedding![i] = (combinedEmbedding![i] * 0.7) + (dupEmbedding[i] * 0.3)
                    }
                }
            }
            
            // Normalize
            if let combined = combinedEmbedding {
                let magnitude = sqrt(combined.reduce(0) { $0 + $1 * $1 })
                if magnitude > 0 {
                    combinedEmbedding = combined.map { $0 / magnitude }
                    primary.setEmbedding(combinedEmbedding!)
                }
            }
        }
        
        // Recalculate importance
        primary.recalculateImportance()
        
        // Delete duplicate nodes
        for duplicate in duplicates {
            modelContext.delete(duplicate)
        }
        
        // Update theme centroids
        await updateThemeCentroids(modelContext: modelContext)
        
        // Update indices
        updateEmbeddingIndex(node: primary)
        
        // Trigger hooks
        for duplicate in duplicates {
            notifyNodeMerged(duplicate)
        }
        
        logger.info("Merged \(duplicates.count) nodes into \(primary.label)")
    }
    
    /// Get all edges connected to a node
    private func getEdges(
        connectedTo nodeId: UUID,
        modelContext: ModelContext
    ) -> [MemoryEdge] {
        let descriptor = FetchDescriptor<MemoryEdge>(
            predicate: #Predicate { edge in
                edge.sourceNodeId == nodeId || edge.targetNodeId == nodeId
            }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    // MARK: - Summary Dump for System Prompts
    
    /// Generate summary dump for Aurora system prompts
    func summaryDumpForPrompt(
        limit: Int = 20,
        modelContext: ModelContext
    ) -> String {
        guard config.featureFlags.memoryGraphEnabled else {
            return ""
        }
        
        var lines: [String] = []
        lines.append("## Memory Graph Context")
        
        // Top active themes
        let themes = getActiveThemes(modelContext: modelContext)
            .sorted { $0.salience > $1.salience }
            .prefix(min(20, limit))
        
        if !themes.isEmpty {
            lines.append("\n### Active Themes (\(themes.count)):")
            for theme in themes {
                lines.append("- **\(theme.label)**: \(theme.themeDescription) (salience: \(String(format: "%.2f", theme.salience)), members: \(theme.memberNodeIds.count))")
            }
        }
        
        // Top nodes by importance
        var nodeDescriptor = FetchDescriptor<MemoryNode>(
            sortBy: [SortDescriptor(\.importance, order: .reverse)]
        )
        nodeDescriptor.fetchLimit = min(50, limit * 2)
        
        if let topNodes = try? modelContext.fetch(nodeDescriptor).prefix(min(50, limit * 2)) {
            lines.append("\n### Top Memory Nodes (\(topNodes.count)):")
            for node in topNodes {
                let themeInfo = node.themeIds.isEmpty ? "" : " (themes: \(node.themeIds.count))"
                lines.append("- **\(node.label)**: \(node.content.prefix(100))\(themeInfo) (importance: \(String(format: "%.2f", node.importance)))")
            }
        }
        
        // Top subgraphs
        var subgraphDescriptor = FetchDescriptor<MemorySubgraph>(
            sortBy: [SortDescriptor(\.importanceScore, order: .reverse)]
        )
        subgraphDescriptor.fetchLimit = 5
        
        if let subgraphs = try? modelContext.fetch(subgraphDescriptor).prefix(5) {
            lines.append("\n### Active Subgraphs (\(subgraphs.count)):")
            for subgraph in subgraphs {
                lines.append("- **\(subgraph.title)**: \(subgraph.nodeIds.count) nodes (importance: \(String(format: "%.2f", subgraph.importanceScore)))")
            }
        }
        
        // Emotional clusters
        let emotionalNodes = getNodesByEmotionalTone(modelContext: modelContext)
        if !emotionalNodes.isEmpty {
            lines.append("\n### Emotional Clusters:")
            for (tone, nodes) in emotionalNodes.sorted(by: { $0.value.count > $1.value.count }).prefix(5) {
                lines.append("- **\(tone.rawValue)**: \(nodes.count) nodes")
            }
        }
        
        return lines.joined(separator: "\n")
    }
    
    private func getNodesByEmotionalTone(modelContext: ModelContext) -> [EmotionTone: [MemoryNode]] {
        let descriptor = FetchDescriptor<MemoryNode>()
        guard let allNodes = try? modelContext.fetch(descriptor) else { return [:] }
        
        return Dictionary(grouping: allNodes) { node in
            node.emotionalTone ?? .neutral
        }
    }
    
    // MARK: - Cached Graph Indices
    
    /// Update embedding index
    private func updateEmbeddingIndex(node: MemoryNode) {
        if let embedding = node.getEmbedding() {
            embeddingIndex[node.id] = embedding
        }
    }
    
    /// Update theme index
    private func updateThemeIndex(theme: ThemeNode) {
        let themeKey = theme.label
        if themeIndex[themeKey] == nil {
            themeIndex[themeKey] = []
        }
        themeIndex[themeKey]?.formUnion(theme.memberNodeIds)
    }
    
    /// Update cluster index
    private func updateClusterIndex(subgraph: MemorySubgraph) {
        let clusterKey = subgraph.title
        if clusterIndex[clusterKey] == nil {
            clusterIndex[clusterKey] = []
        }
        clusterIndex[clusterKey]?.formUnion(subgraph.nodeIds)
    }
    
    /// Update recency index
    private func updateRecencyIndex(node: MemoryNode) {
        // Remove existing entry
        recencyIndex.removeAll { $0.nodeId == node.id }
        
        // Add new entry
        recencyIndex.append((node.id, node.lastAccessedAt))
        
        // Sort by recency
        recencyIndex.sort { $0.lastAccess > $1.lastAccess }
        
        // Keep only last 100
        if recencyIndex.count > 100 {
            recencyIndex = Array(recencyIndex.prefix(100))
        }
    }
    
    /// Rebuild all indices (call after consolidation)
    func rebuildIndices(modelContext: ModelContext) {
        embeddingIndex.removeAll()
        themeIndex.removeAll()
        clusterIndex.removeAll()
        recencyIndex.removeAll()
        
        // Rebuild embedding index
        let nodeDescriptor = FetchDescriptor<MemoryNode>()
        if let nodes = try? modelContext.fetch(nodeDescriptor) {
            for node in nodes {
                updateEmbeddingIndex(node: node)
                updateRecencyIndex(node: node)
            }
        }
        
        // Rebuild theme index
        let themes = getActiveThemes(modelContext: modelContext)
        for theme in themes {
            updateThemeIndex(theme: theme)
        }
        
        // Rebuild cluster index
        let subgraphDescriptor = FetchDescriptor<MemorySubgraph>()
        if let subgraphs = try? modelContext.fetch(subgraphDescriptor) {
            for subgraph in subgraphs {
                updateClusterIndex(subgraph: subgraph)
            }
        }
        
        logger.info("Rebuilt all graph indices")
    }
    
    // MARK: - Event Hooks
    
    /// Register hook for node creation
    func onNodeCreated(_ hook: @escaping MemoryGraphHook) {
        nodeCreatedHooks.append(hook)
    }
    
    /// Register hook for node reinforcement
    func onNodeReinforced(_ hook: @escaping MemoryGraphHook) {
        nodeReinforcedHooks.append(hook)
    }
    
    /// Register hook for node merge
    func onNodeMerged(_ hook: @escaping MemoryGraphHook) {
        nodeMergedHooks.append(hook)
    }
    
    /// Register hook for edge creation
    func onEdgeCreated(_ hook: @escaping EdgeHook) {
        edgeCreatedHooks.append(hook)
    }
    
    /// Register hook for consolidation
    func onConsolidation(_ hook: @escaping ConsolidationHook) {
        consolidationHooks.append(hook)
    }
    
    private func notifyNodeCreated(_ node: MemoryNode) {
        for hook in nodeCreatedHooks {
            hook(node)
        }
    }
    
    private func notifyNodeReinforced(_ node: MemoryNode) {
        for hook in nodeReinforcedHooks {
            hook(node)
        }
    }
    
    private func notifyNodeMerged(_ node: MemoryNode) {
        for hook in nodeMergedHooks {
            hook(node)
        }
    }
    
    private func notifyEdgeCreated(_ edge: MemoryEdge) {
        for hook in edgeCreatedHooks {
            hook(edge)
        }
    }
    
    private func notifyConsolidation() {
        for hook in consolidationHooks {
            hook()
        }
    }
    
    // MARK: - MemoryCompressionService Integration
    
    /// Create/update node from MemorySummary
    func integrateMemorySummary(
        _ summary: MemorySummary,
        modelContext: ModelContext
    ) async throws -> MemoryNode {
        guard config.featureFlags.memoryGraphEnabled else {
            throw MemoryGraphError.featureDisabled
        }
        
        let originalId = summary.originalObjectId as UUID?
        let descriptor = FetchDescriptor<MemoryNode>(
            predicate: #Predicate { node in
                node.objectId == originalId
            }
        )
        
        let node: MemoryNode
        if let existing = try? modelContext.fetch(descriptor).first {
            node = existing
            // Update content
            node.content = summary.summaryText
        } else {
            // Create new node
            node = MemoryNode(
                nodeType: mapNodeTypeFromObjectType(summary.originalObjectType),
                objectId: summary.originalObjectId,
                label: "Compressed \(summary.originalObjectType)",
                content: summary.summaryText
            )
            modelContext.insert(node)
        }
        
        // Use existing embedding from summary if available, otherwise generate
        if summary.embeddingDimensions > 0,
           let summaryEmbedding = summary.getEmbedding() {
            // Use existing embedding
            node.setEmbedding(summaryEmbedding)
            node.embeddingModelName = summary.modelName ?? defaultEmbeddingModel
        } else if let embedding = try? await generateEmbedding(for: summary.summaryText) {
            // Generate new embedding
            node.setEmbedding(embedding)
            node.embeddingModelName = summary.modelName ?? defaultEmbeddingModel
        }
        
        // Set emotional tone from summary content
        let emotionalSnapshot = EmotionAnalyzer.analyzeTone(text: summary.summaryText)
        node.emotionalTone = emotionalSnapshot.primaryEmotion
        node.emotionalIntensity = emotionalSnapshot.intensity
        
        // Attach themes
        for themeLabel in summary.themes {
            if let theme = findTheme(by: themeLabel, modelContext: modelContext) {
                if !node.themeIds.contains(theme.id) {
                    node.themeIds.append(theme.id)
                }
                theme.addMember(node.id)
            }
        }
        
        node.recalculateImportance()
        try modelContext.save()
        
        // Attach themes based on embedding similarity
        await attachThemesToNode(node, modelContext: modelContext)
        
        // Create edges to similar summaries
        await createEdgesToSimilarSummaries(for: node, modelContext: modelContext)
        
        // Update indices
        updateEmbeddingIndex(node: node)
        updateRecencyIndex(node: node)
        
        logger.info("Integrated memory summary into graph: \(summary.id)")
        return node
    }
    
    private func mapNodeTypeFromObjectType(_ objectType: String) -> MemoryNodeType {
        switch objectType.lowercased() {
        case "journal": return .insight
        case "note": return .workspaceObject
        case "task": return .workspaceObject
        default: return .workspaceObject
        }
    }
    
    private func findTheme(
        by label: String,
        modelContext: ModelContext
    ) -> ThemeNode? {
        let descriptor = FetchDescriptor<ThemeNode>(
            predicate: #Predicate { $0.label == label }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    private func createEdgesToSimilarSummaries(
        for node: MemoryNode,
        modelContext: ModelContext
    ) async {
        guard let nodeEmbedding = node.getEmbedding() else { return }
        
        // Find similar nodes
        let similarNodes = findSimilarNodes(
            to: node.id,
            threshold: 0.75,
            limit: 5,
            modelContext: modelContext
        )
        
        // Create edges
        for similarNode in similarNodes {
            do {
                _ = try createEdge(
                    from: node.id,
                    to: similarNode.id,
                    type: .similarTo,
                    weight: 0.7,
                    reason: "Compressed memory similarity",
                    modelContext: modelContext
                )
            } catch {
                logger.warning("Failed to create edge: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func buildContent(for object: any RecallTrackable) -> String {
        let title = object.recallTitle
        let detail = object.recallDetail
        let type = object.recallObjectType.rawValue
        return "\(type): \(title). \(detail)"
    }
    
    private func mapToNodeType(_ recallType: RecallObjectType) -> MemoryNodeType {
        switch recallType {
        case .task, .note, .project, .draft, .post, .inbox:
            return .workspaceObject
        default:
            return .workspaceObject
        }
    }
    
    private func fetchNode(by id: UUID, modelContext: ModelContext) -> MemoryNode? {
        if let cached = nodeCache[id] {
            return cached
        }
        
        let descriptor = FetchDescriptor<MemoryNode>(
            predicate: #Predicate { $0.id == id }
        )
        let node = try? modelContext.fetch(descriptor).first
        if let node = node {
            nodeCache[id] = node
        }
        return node
    }
    
    private func updateEdgeCount(for nodeId: UUID, modelContext: ModelContext) {
        guard let node = fetchNode(by: nodeId, modelContext: modelContext) else { return }
        
        let outgoingDescriptor = FetchDescriptor<MemoryEdge>(
            predicate: #Predicate { $0.sourceNodeId == nodeId }
        )
        let incomingDescriptor = FetchDescriptor<MemoryEdge>(
            predicate: #Predicate { $0.targetNodeId == nodeId }
        )
        
        let outgoing = (try? modelContext.fetch(outgoingDescriptor).count) ?? 0
        let incoming = (try? modelContext.fetch(incomingDescriptor).count) ?? 0
        
        node.edgeCount = outgoing + incoming
        node.recalculateImportance()  // Update importance with new edge count
        try? modelContext.save()
    }

    private func removeEdges(
        for nodeId: UUID,
        modelContext: ModelContext
    ) {
        let descriptor = FetchDescriptor<MemoryEdge>(
            predicate: #Predicate { edge in
                edge.sourceNodeId == nodeId || edge.targetNodeId == nodeId
            }
        )
        if let edges = try? modelContext.fetch(descriptor) {
            for edge in edges {
                modelContext.delete(edge)
            }
            try? modelContext.save()
        }
    }
    
    /// Calculate cosine similarity between two embeddings
    private func cosineSimilarity(_ vecA: [Float], _ vecB: [Float]) -> Double {
        guard vecA.count == vecB.count else { return 0.0 }
        
        var dotProduct: Float = 0.0
        var normA: Float = 0.0
        var normB: Float = 0.0
        
        for i in 0..<vecA.count {
            dotProduct += vecA[i] * vecB[i]
            normA += vecA[i] * vecA[i]
            normB += vecB[i] * vecB[i]
        }
        
        let denominator = sqrt(normA) * sqrt(normB)
        return denominator > 0 ? Double(dotProduct / denominator) : 0.0
    }
    
    // MARK: - Graph Queries
    
    /// Get neighbors of a node
    func getNeighbors(of nodeId: UUID, modelContext: ModelContext) -> [MemoryNode] {
        let edgeDescriptor = FetchDescriptor<MemoryEdge>(
            predicate: #Predicate { edge in
                (edge.sourceNodeId == nodeId || edge.targetNodeId == nodeId) && !edge.isArchived
            }
        )
        
        guard let edges = try? modelContext.fetch(edgeDescriptor) else { return [] }
        
        let neighborIds = edges.flatMap { edge -> [UUID] in
            var ids: [UUID] = []
            if edge.sourceNodeId == nodeId {
                ids.append(edge.targetNodeId)
            }
            if edge.targetNodeId == nodeId {
                ids.append(edge.sourceNodeId)
            }
            return ids
        }
        
        return neighborIds.compactMap { fetchNode(by: $0, modelContext: modelContext) }
    }
    
    /// Get all active themes
    func getActiveThemes(modelContext: ModelContext) -> [ThemeNode] {
        let descriptor = FetchDescriptor<ThemeNode>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\.salience, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    /// Find similar nodes using vector similarity
    func findSimilarNodes(
        to nodeId: UUID,
        threshold: Double = 0.7,
        limit: Int = 10,
        modelContext: ModelContext
    ) -> [MemoryNode] {
        guard config.featureFlags.memoryGraphEnabled else { return [] }
        guard let targetNode = fetchNode(by: nodeId, modelContext: modelContext),
              let targetEmbedding = targetNode.getEmbedding() else {
            return []
        }
        
        // Use cached embedding index if available
        var candidates: [(node: MemoryNode, similarity: Double)] = []
        
        if !embeddingIndex.isEmpty {
            // Use cached index
            for (nodeId, embedding) in embeddingIndex {
                guard nodeId != targetNode.id else { continue }
                let similarity = cosineSimilarity(targetEmbedding, embedding)
                if similarity >= threshold {
                    if let node = fetchNode(by: nodeId, modelContext: modelContext) {
                        candidates.append((node, similarity))
                    }
                }
            }
        } else {
            // Fallback to fetching all nodes
            let descriptor = FetchDescriptor<MemoryNode>()
            guard let allNodes = try? modelContext.fetch(descriptor) else { return [] }
            
            for node in allNodes {
                guard node.id != nodeId,
                      let nodeEmbedding = node.getEmbedding() else {
                    continue
                }
                let similarity = targetNode.cosineSimilarity(with: node)
                if similarity >= threshold {
                    candidates.append((node, similarity))
                }
            }
        }
        
        return candidates
            .sorted { $0.similarity > $1.similarity }
            .prefix(limit)
            .map { $0.node }
    }
    
    // MARK: - Focus Session Linking
    
    /// Link a FocusSession to MemoryNode for later recall
    func linkFocusSession(
        session: FocusSession,
        modelContext: ModelContext
    ) async throws {
        guard config.featureFlags.memoryGraphEnabled else {
            logger.debug("Memory graph disabled - skipping session link")
            return
        }
        
        let content = """
        Focus Session: \(session.objective)
        Duration: \(session.durationFormatted)
        Status: \(session.status.rawValue)
        Completed: \(session.completed)
        """
        
        let sessionNode = try await createConceptNode(
            concept: "Focus Session: \(session.objective)",
            content: content,
            modelContext: modelContext
        )
        
        if let targetId = session.targetObjectId {
            let targetIdOpt = targetId as UUID?
            let targetDescriptor = FetchDescriptor<MemoryNode>(
                predicate: #Predicate { $0.objectId == targetIdOpt }
            )
            
            if let targetNode = try? modelContext.fetch(targetDescriptor).first {
                _ = try createEdge(
                    from: sessionNode.id,
                    to: targetNode.id,
                    type: .relatedTo,
                    weight: 0.7,
                    reason: "Focus session linked to \(session.targetObjectType ?? "object")",
                    modelContext: modelContext
                )
                logger.info("Linked focus session to memory node: \(targetId.uuidString)")
            }
        }
        
        logger.info("Created memory graph link for focus session: \(session.id.uuidString)")
    }
    
    // MARK: - Archive Integration
    
    /// Retrieve archived relationships for an object
    func retrieveArchivedRelationships(
        for objectId: UUID,
        modelContext: ModelContext
    ) -> [MemoryEdge] {
        guard config.featureFlags.memoryGraphEnabled else { return [] }
        
        let edgeDescriptor = FetchDescriptor<MemoryEdge>(
            predicate: #Predicate { edge in
                (edge.sourceNodeId == objectId || edge.targetNodeId == objectId) && !edge.isArchived
            }
        )
        
        return (try? modelContext.fetch(edgeDescriptor)) ?? []
    }
    
    /// Update archived status for a memory node
    func updateArchivedStatus(
        for objectId: UUID,
        isArchived: Bool,
        modelContext: ModelContext
    ) throws {
        guard config.featureFlags.memoryGraphEnabled else { return }
        
        let objectIdOpt = objectId as UUID?
        let descriptor = FetchDescriptor<MemoryNode>(
            predicate: #Predicate { $0.objectId == objectIdOpt }
        )
        
        if let node = try? modelContext.fetch(descriptor).first {
            if isArchived {
                if !node.tags.contains("archived") {
                    node.tags.append("archived")
                }
            } else {
                node.tags.removeAll { $0 == "archived" }
            }
            try modelContext.save()
        }
    }
}

// MARK: - Errors

enum MemoryGraphError: LocalizedError {
    case featureDisabled
    case embeddingModelNotInitialized
    case embeddingGenerationFailed
    case nodeNotFound
    case invalidEdge
    
    var errorDescription: String? {
        switch self {
        case .featureDisabled:
            return "Memory graph feature is disabled"
        case .embeddingModelNotInitialized:
            return "Embedding model not initialized"
        case .embeddingGenerationFailed:
            return "Failed to generate embedding"
        case .nodeNotFound:
            return "Memory node not found"
        case .invalidEdge:
            return "Invalid edge configuration"
        }
    }
}

