//
//  ArtifactMigrationService.swift
//  Cloutmate
//
//  Created by Migration
//

import Foundation
import SwiftData
import CloutmateShared
import os.log

@MainActor
final class ArtifactMigrationService {
    static let shared = ArtifactMigrationService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "Migration")
    
    private init() {}
    
    // MARK: - Non-context Migration (for backward compatibility)
    
    func migratePostToArtifact(_ post: Post) -> Artifact {
        // Extract title from caption (first line or first 50 chars)
        let captionLines = post.caption.components(separatedBy: .newlines)
        let title = captionLines.first?.trimmingCharacters(in: .whitespaces) ?? ""
        let content = captionLines.count > 1 
            ? captionLines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespaces)
            : (captionLines.first?.count ?? 0) > 50 
                ? String(captionLines.first!.dropFirst(50))
                : ""
        
        // Map PostStatus to ArtifactState
        let artifactState: ArtifactState
        switch post.postStatus {
        case .draft:
            artifactState = .draft
        case .scheduled, .publishing:
            artifactState = .draft // Keep scheduled as draft, no more scheduling
        case .published:
            artifactState = .published
        case .failed:
            artifactState = .draft // Failed posts become drafts
        }
        
        // Map Platform to OutputFormat (best guess)
        let outputFormat: OutputFormat
        if post.platforms.isEmpty {
            outputFormat = .brief
        } else {
            // Use first platform as format hint
            let platform = post.postPlatforms.first ?? .threads
            outputFormat = mapPlatformToFormat(platform)
        }
        
        // Create artifact
        let artifact = Artifact(
            title: title.isEmpty ? content.prefix(50).description : title,
            content: content.isEmpty ? post.caption : content,
            mediaURLs: post.mediaURLs,
            outputFormat: outputFormat,
            state: artifactState,
            publishedAt: post.publishedDate ?? post.scheduledDate,
            tags: post.tags,
            projectId: post.projectId,
            areaId: post.areaId
        )
        
        // Preserve custom properties
        artifact.customProperties = post.customProperties
        
        // Copy custom properties from Post fields that might be useful
        if let contentPillar = post.contentPillar {
            artifact.customProperties["contentPillar"] = contentPillar
        }
        if let funnelStage = post.funnelStage {
            artifact.customProperties["funnelStage"] = funnelStage
        }
        if let campaignId = post.campaignId {
            artifact.customProperties["campaignId"] = campaignId.uuidString
        }
        
        logger.info("Migrated Post \(post.id.uuidString) to Artifact \(artifact.id.uuidString)")
        
        return artifact
    }
    
    func migrateDraftToArtifact(_ draft: Draft) -> Artifact {
        // Extract title from caption
        let captionLines = draft.caption.components(separatedBy: .newlines)
        let title = captionLines.first?.trimmingCharacters(in: .whitespaces) ?? ""
        let content = captionLines.count > 1 
            ? captionLines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespaces)
            : ""
        
        // Combine caption and notes if both exist
        var fullContent = content
        if let notes = draft.notes, !notes.isEmpty {
            if !fullContent.isEmpty {
                fullContent += "\n\n---\n\n\(notes)"
            } else {
                fullContent = notes
            }
        }
        
        let artifact = Artifact(
            title: title.isEmpty ? (fullContent.prefix(50).description) : title,
            content: fullContent.isEmpty ? draft.caption : fullContent,
            mediaURLs: draft.mediaURLs,
            outputFormat: .brief, // Default for drafts
            state: draft.convertedAt != nil ? .published : .draft,
            publishedAt: draft.convertedAt ?? draft.scheduledOrPublishedDate,
            tags: draft.tags
        )
        
        // If draft was converted to a post, mark as published
        if draft.convertedAt != nil {
            artifact.artifactState = .published
        }
        
        logger.info("Migrated Draft \(draft.id.uuidString) to Artifact \(artifact.id.uuidString)")
        
        return artifact
    }
    
    // MARK: - Context-based Migration (for database operations)
    
    func migratePostToArtifact(_ post: Post, context: ModelContext) -> Artifact {
        let artifact = migratePostToArtifact(post)
        return artifact
    }
    
    func migrateDraftToArtifact(_ draft: Draft, context: ModelContext) -> Artifact {
        let artifact = migrateDraftToArtifact(draft)
        return artifact
    }
    
    // MARK: - Bulk Migration
    
    func migrateAllPosts(context: ModelContext) throws -> Int {
        let descriptor = FetchDescriptor<Post>()
        let posts = try context.fetch(descriptor)
        
        var count = 0
        for post in posts {
            let artifact = migratePostToArtifact(post, context: context)
            context.insert(artifact)
            count += 1
        }
        
        try context.save()
        logger.info("Migrated \(count) posts to artifacts")
        
        return count
    }
    
    func migrateAllDrafts(context: ModelContext) throws -> Int {
        let descriptor = FetchDescriptor<Draft>()
        let drafts = try context.fetch(descriptor)
        
        var count = 0
        for draft in drafts {
            let artifact = migrateDraftToArtifact(draft, context: context)
            context.insert(artifact)
            count += 1
        }
        
        try context.save()
        logger.info("Migrated \(count) drafts to artifacts")
        
        return count
    }
    
    // MARK: - Helper Methods
    
    private func mapPlatformToFormat(_ platform: Platform) -> OutputFormat {
        // Map social platforms to narrative formats
        // This is a best-guess mapping - user can adjust later
        switch platform {
        case .threads:
            return .brief // Threads are typically brief
        case .facebook:
            return .summary // Facebook posts can be longer summaries
        }
    }
}

