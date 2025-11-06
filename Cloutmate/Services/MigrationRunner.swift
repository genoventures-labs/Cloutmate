//
//  MigrationRunner.swift
//  Cloutmate
//
//  Runs migration from Posts/Drafts to Artifacts
//

import Foundation
import SwiftData
import CloutmateShared
import os.log

@MainActor
final class MigrationRunner {
    static let shared = MigrationRunner()
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "Migration")
    
    private init() {}
    
    /// Run full migration: Posts → Artifacts, Drafts → Artifacts
    func runMigration(context: ModelContext) async throws -> MigrationResult {
        logger.info("Starting migration from Posts/Drafts to Artifacts")
        
        var postsMigrated = 0
        var draftsMigrated = 0
        var errors: [String] = []
        
        // Migrate Posts
        do {
            let descriptor = FetchDescriptor<Post>()
            let posts = try context.fetch(descriptor)
            
            for post in posts {
                do {
                    let artifact = ArtifactMigrationService.shared.migratePostToArtifact(post, context: context)
                    context.insert(artifact)
                    postsMigrated += 1
                } catch {
                    let errorMsg = "Failed to migrate post \(post.id.uuidString): \(error.localizedDescription)"
                    logger.error("\(errorMsg)")
                    errors.append(errorMsg)
                }
            }
            
            try context.save()
            logger.info("Migrated \(postsMigrated) posts to artifacts")
        } catch {
            let errorMsg = "Failed to migrate posts: \(error.localizedDescription)"
            logger.error("\(errorMsg)")
            errors.append(errorMsg)
        }
        
        // Migrate Drafts
        do {
            let descriptor = FetchDescriptor<Draft>()
            let drafts = try context.fetch(descriptor)
            
            for draft in drafts {
                do {
                    let artifact = ArtifactMigrationService.shared.migrateDraftToArtifact(draft, context: context)
                    context.insert(artifact)
                    draftsMigrated += 1
                } catch {
                    let errorMsg = "Failed to migrate draft \(draft.id.uuidString): \(error.localizedDescription)"
                    logger.error("\(errorMsg)")
                    errors.append(errorMsg)
                }
            }
            
            try context.save()
            logger.info("Migrated \(draftsMigrated) drafts to artifacts")
        } catch {
            let errorMsg = "Failed to migrate drafts: \(error.localizedDescription)"
            logger.error("\(errorMsg)")
            errors.append(errorMsg)
        }
        
        let result = MigrationResult(
            postsMigrated: postsMigrated,
            draftsMigrated: draftsMigrated,
            totalMigrated: postsMigrated + draftsMigrated,
            errors: errors
        )
        
        logger.info("Migration completed: \(result.totalMigrated) items migrated, \(errors.count) errors")
        
        return result
    }
    
    /// Check if migration is needed
    func checkMigrationNeeded(context: ModelContext) -> Bool {
        do {
            let postDescriptor = FetchDescriptor<Post>()
            let posts = try context.fetch(postDescriptor)
            
            let draftDescriptor = FetchDescriptor<Draft>()
            let drafts = try context.fetch(draftDescriptor)
            
            return !posts.isEmpty || !drafts.isEmpty
        } catch {
            logger.error("Failed to check migration status: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Get migration statistics
    func getMigrationStats(context: ModelContext) -> MigrationStats {
        do {
            let postDescriptor = FetchDescriptor<Post>()
            let posts = try context.fetch(postDescriptor)
            
            let draftDescriptor = FetchDescriptor<Draft>()
            let drafts = try context.fetch(draftDescriptor)
            
            let artifactDescriptor = FetchDescriptor<Artifact>()
            let artifacts = try context.fetch(artifactDescriptor)
            
            return MigrationStats(
                postCount: posts.count,
                draftCount: drafts.count,
                artifactCount: artifacts.count
            )
        } catch {
            logger.error("Failed to get migration stats: \(error.localizedDescription)")
            return MigrationStats(postCount: 0, draftCount: 0, artifactCount: 0)
        }
    }
}

struct MigrationResult {
    let postsMigrated: Int
    let draftsMigrated: Int
    let totalMigrated: Int
    let errors: [String]
    
    var success: Bool {
        errors.isEmpty && totalMigrated > 0
    }
}

struct MigrationStats {
    let postCount: Int
    let draftCount: Int
    let artifactCount: Int
    
    var needsMigration: Bool {
        postCount > 0 || draftCount > 0
    }
}

