//
//  ArtifactMentionService.swift
//  Cloutmate
//
//  Artifacts V2 - Manages @mention parsing and CPS updates
//

import Foundation
import SwiftData
import os.log
import CloutmateShared

@MainActor
final class ArtifactMentionService {
    static let shared = ArtifactMentionService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "ArtifactMention")
    
    private init() {}
    
    // MARK: - Mention Parsing
    
    /// Parse @mentions from artifact content
    func parseMentions(in artifact: Artifact) -> [MentionMatch] {
        let fullText = artifact.fullContent
        return MentionParser.parseMentions(from: fullText)
    }
    
    /// Update linked entities for an artifact based on @mentions
    func updateLinkedEntities(for artifact: Artifact, modelContext: ModelContext) {
        let mentions = parseMentions(in: artifact)
        
        var linkedIds: [UUID] = []
        var linkedTypes: [String] = []
        
        // Search for each mention in workspace
        for mention in mentions {
            let results = WorkspaceObjectSearchService.shared.search(
                query: mention.mentionText,
                modelContext: modelContext,
                limit: 1
            )
            
            if let firstResult = results.first {
                linkedIds.append(firstResult.id)
                linkedTypes.append(firstResult.type.rawValue)
                
                // Create ArtifactMention record
                let artifactMention = ArtifactMention(
                    artifactId: artifact.id,
                    mentionedEntityId: firstResult.id,
                    mentionedEntityType: firstResult.type.rawValue,
                    mentionText: mention.fullText,
                    position: mention.range.location
                )
                modelContext.insert(artifactMention)
            }
        }
        
        // Update artifact
        artifact.linkedEntityIds = linkedIds
        artifact.linkedEntityTypes = linkedTypes
        
        // Extract concepts for Narrative Engine when artifact is finalized
        if artifact.artifactState == .final || artifact.artifactState == .published {
            ConceptTracker.shared.trackConcepts(
                in: artifact.fullContent,
                fromObjectId: artifact.id,
                contextType: "artifact",
                modelContext: modelContext
            )
        }
        
        try? modelContext.save()
        logger.debug("Updated linked entities for artifact \(artifact.id.uuidString): \(linkedIds.count) mentions")
    }
    
    /// Boost CPS scores for mentioned entities
    func boostCPSForMentions(in artifact: Artifact, modelContext: ModelContext) {
        guard !artifact.linkedEntityIds.isEmpty else { return }
        
        // Boost CPS scores for all mentioned entities
        PriorityEngine.shared.boostScore(
            for: artifact.linkedEntityIds,
            amount: 0.15, // Moderate boost for mentions
            modelContext: modelContext
        )
        
        logger.debug("Boosted CPS for \(artifact.linkedEntityIds.count) mentioned entities")
    }
    
    /// Get full entity objects for mentioned entities
    func getMentionedEntities(for artifact: Artifact, modelContext: ModelContext) -> [(id: UUID, type: String, title: String, subtitle: String)] {
        var results: [(id: UUID, type: String, title: String, subtitle: String)] = []
        
        for (index, entityId) in artifact.linkedEntityIds.enumerated() {
            guard index < artifact.linkedEntityTypes.count else { continue }
            
            let entityType = artifact.linkedEntityTypes[index]
            
            // Fetch entity based on type
            switch entityType {
            case "project":
                let descriptor = FetchDescriptor<CloutmateShared.Project>(
                    predicate: #Predicate { $0.id == entityId }
                )
                if let project = try? modelContext.fetch(descriptor).first {
                    results.append((
                        id: project.id,
                        type: "project",
                        title: project.title,
                        subtitle: project.goal ?? ""
                    ))
                }
            case "area":
                let descriptor = FetchDescriptor<Area>(
                    predicate: #Predicate { $0.id == entityId }
                )
                if let area = try? modelContext.fetch(descriptor).first {
                    results.append((
                        id: area.id,
                        type: "area",
                        title: area.title,
                        subtitle: area.notes ?? ""
                    ))
                }
            case "task":
                let descriptor = FetchDescriptor<CloutmateShared.Task>(
                    predicate: #Predicate { $0.id == entityId }
                )
                if let task = try? modelContext.fetch(descriptor).first {
                    results.append((
                        id: task.id,
                        type: "task",
                        title: task.title,
                        subtitle: task.notes ?? ""
                    ))
                }
            case "focusSession":
                let descriptor = FetchDescriptor<FocusSession>(
                    predicate: #Predicate { $0.id == entityId }
                )
                if let session = try? modelContext.fetch(descriptor).first {
                    results.append((
                        id: session.id,
                        type: "focusSession",
                        title: session.objective,
                        subtitle: session.durationFormatted
                    ))
                }
            default:
                break
            }
        }
        
        return results
    }
}

