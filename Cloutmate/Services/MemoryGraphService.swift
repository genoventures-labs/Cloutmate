//
//  MemoryGraphService.swift
//  Cloutmate
//
//  Phase 6 - Memory Graph Research Build
//  Manages the memory graph with vector embeddings and theme extraction
//

import Foundation
import SwiftData
import GoogleGenerativeAI
import os.log

@MainActor
final class MemoryGraphService {
    static let shared = MemoryGraphService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "MemoryGraph")
    private var embeddingModel: GenerativeModel?
    
    private var config: AIConfig {
        AIConfigService.shared.config
    }
    
    // In-memory caches for performance
    private var nodeCache: [UUID: MemoryNode] = [:]
    private var edgeCache: [UUID: [MemoryEdge]] = [:] // nodeId -> edges
    private var lastCacheRefresh: Date?
    private let cacheValidity: TimeInterval = 300 // 5 minutes
    
    private init() {
        _Concurrency.Task {
            await initializeEmbeddingModel()
        }
    }
    
    // MARK: - Initialization
    
    private func initializeEmbeddingModel() async {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let apiKey = plist["GeminiAPIKey"] as? String,
              !apiKey.isEmpty else {
            logger.error("Gemini API key not found for embedding model")
            return
        }
        
        embeddingModel = GenerativeModel(
            name: "models/text-embedding-004",
            apiKey: apiKey
        )
        
        logger.info("Memory graph embedding model initialized")
        AIDebug.log("MemoryGraphService: Embedding model ready")
    }
    
    // MARK: - Node Operations
    
    /// Create a node for a workspace object
    func createNode(
        for object: any RecallTrackable,
        modelContext: ModelContext
    ) async throws -> MemoryNode {
        guard config.featureFlags.memoryGraphEnabled else {
            throw MemoryGraphError.featureDisabled
        }
        
        let content = buildContent(for: object)
        let node = MemoryNode(
            nodeType: mapToNodeType(object.recallObjectType),
            objectId: object.recallObjectId,
            label: object.recallTitle,
            content: content
        )
        
        // Generate embedding
        if let embedding = try? await generateEmbedding(for: content) {
            node.setEmbedding(embedding)
            AIDebug.log("MemoryGraph: Generated embedding for node \(node.label)")
        }
        
        modelContext.insert(node)
        try modelContext.save()
        
        // Update cache
        nodeCache[node.id] = node
        
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
        
        let node = MemoryNode(
            nodeType: .concept,
            label: concept,
            content: content
        )
        
        // Generate embedding
        if let embedding = try? await generateEmbedding(for: content) {
            node.setEmbedding(embedding)
        }
        
        modelContext.insert(node)
        try modelContext.save()
        
        nodeCache[node.id] = node
        return node
    }
    
    /// Find or create node for an object
    func findOrCreateNode(
        for object: any RecallTrackable,
        modelContext: ModelContext
    ) async throws -> MemoryNode {
        // Check if node exists
        let objectId = object.recallObjectId
        let descriptor = FetchDescriptor<MemoryNode>(
            predicate: #Predicate { $0.objectId == objectId }
        )
        
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.boost() // Update access stats
            try? modelContext.save()
            return existing
        }
        
        // Create new node
        return try await createNode(for: object, modelContext: modelContext)
    }
    
    // MARK: - Edge Operations
    
    /// Create an edge between two nodes
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
            // Strengthen existing edge
            existing.strengthen()
            try? modelContext.save()
            return existing
        }
        
        // Create new edge
        let edge = MemoryEdge(
            sourceNodeId: sourceId,
            targetNodeId: targetId,
            edgeType: type,
            weight: weight,
            reason: reason
        )
        
        modelContext.insert(edge)
        try modelContext.save()
        
        // Update edge counts
        updateEdgeCount(for: sourceId, modelContext: modelContext)
        updateEdgeCount(for: targetId, modelContext: modelContext)
        
        // Invalidate cache
        edgeCache.removeValue(forKey: sourceId)
        edgeCache.removeValue(forKey: targetId)
        
        AIDebug.log("MemoryGraph: Created edge \(type.rawValue) from \(sourceId) to \(targetId)")
        return edge
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
              targetNode.getEmbedding() != nil else {
            return []
        }
        
        // Fetch all nodes with embeddings
        let descriptor = FetchDescriptor<MemoryNode>()
        guard let allNodes = try? modelContext.fetch(descriptor) else { return [] }
        
        // Calculate similarities
        var similarities: [(node: MemoryNode, similarity: Double)] = []
        for node in allNodes {
            guard node.id != nodeId, node.getEmbedding() != nil else { continue }
            let similarity = targetNode.cosineSimilarity(with: node)
            if similarity >= threshold {
                similarities.append((node, similarity))
            }
        }
        
        // Sort by similarity and return top N
        return similarities
            .sorted { $0.similarity > $1.similarity }
            .prefix(limit)
            .map { $0.node }
    }
    
    // MARK: - Embedding Generation
    
    func generateEmbedding(for text: String) async throws -> [Float] {
        guard embeddingModel != nil else {
            throw MemoryGraphError.embeddingModelNotInitialized
        }
        
        // TODO: Fix embedding API - GoogleGenerativeAI SDK may not support embedContent yet
        // For now, generate synthetic embeddings using simple hashing
        // This allows the system to build and run while proper embeddings are researched
        logger.warning("Using synthetic embeddings - proper Gemini embedding API needs implementation")
        return generateSyntheticEmbedding(for: text)
    }
    
    /// Temporary: Generate synthetic embedding vector for text (768 dimensions)
    private func generateSyntheticEmbedding(for text: String) -> [Float] {
        let dimensions = 768
        var embedding = [Float](repeating: 0.0, count: dimensions)
        
        // Simple hash-based embedding (not semantically meaningful, just for testing)
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
        try? modelContext.save()
    }
    
    // MARK: - Graph Queries
    
    /// Get neighbors of a node
    func getNeighbors(of nodeId: UUID, modelContext: ModelContext) -> [MemoryNode] {
        let edgeDescriptor = FetchDescriptor<MemoryEdge>(
            predicate: #Predicate { edge in
                edge.sourceNodeId == nodeId || edge.targetNodeId == nodeId
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

