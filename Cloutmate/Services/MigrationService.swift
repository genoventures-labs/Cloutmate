//
//  MigrationService.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData
import os.log
import CloutmateShared

@MainActor
final class MigrationService {
    static let shared = MigrationService()
    
    private init() {}
    
    func migrateExistingData(context: ModelContext) async throws {
        // Check if migration already ran
        if UserDefaults.standard.object(forKey: "phase3_migrated_date") != nil {
            os_log("Phase 3 migration already completed, skipping", log: .default, type: .info)
            return
        }
        
        // Log counts BEFORE migration
        let draftsCountBefore = try context.fetch(FetchDescriptor<Draft>()).count
        let postsCountBefore = try context.fetch(FetchDescriptor<Post>()).count
        
        os_log("Starting Phase 3 migration: %d drafts, %d posts", log: .default, type: .info, draftsCountBefore, postsCountBefore)
        
        // Capture timestamp BEFORE migration starts - any drafts created after this are new
        let migrationStartTime = Date()
        
        // Transaction wrapper
        try context.transaction {
        // 1. Create default "Social Publishing" Area
        let defaultArea = Area(
            title: "Social Publishing",
            notes: "Content creation and distribution",
            tags: []
        )
            context.insert(defaultArea)
            
            // 2. Migrate ONLY pre-existing Drafts → Inbox Items
            // Only archive drafts created BEFORE migration starts
            let descriptor = FetchDescriptor<Draft>(
                predicate: #Predicate { $0.createdAt < migrationStartTime }
            )
            let drafts = try context.fetch(descriptor)
            os_log("Found %d pre-existing drafts to migrate", log: .default, type: .info, drafts.count)
            
            for draft in drafts {
                let inboxItem = InboxItem(
                    content: draft.caption,
                    itemType: "text",
                    fileURL: draft.mediaURLs.first
                )
                inboxItem.createdAt = draft.createdAt
                context.insert(inboxItem)
                
                // Mark draft as migrated (archived) - only old drafts
                draft.isArchived = true
                draft.notes = (draft.notes ?? "") + "\n[Migrated to Inbox on \(migrationStartTime.formatted())]"
            }
            
            // 3. Link all existing Posts to default Area
            let posts = try context.fetch(FetchDescriptor<Post>())
            for post in posts {
                post.areaId = defaultArea.id
            }
            
            try context.save()
        }
        
        // Log counts AFTER migration
        let inboxCountAfter = try context.fetch(FetchDescriptor<InboxItem>()).count
        os_log("Migration complete: %d inbox items created", log: .default, type: .info, inboxCountAfter)
        
        // Store migration metadata - THIS PREVENTS RE-RUNNING
        UserDefaults.standard.set(migrationStartTime.timeIntervalSince1970, forKey: "phase3_migrated_date")
        UserDefaults.standard.set(draftsCountBefore, forKey: "phase3_drafts_count")
        UserDefaults.standard.set(inboxCountAfter, forKey: "phase3_inbox_count")
        UserDefaults.standard.synchronize()
        
        os_log("Migration timestamp stored: %f", log: .default, type: .info, migrationStartTime.timeIntervalSince1970)
    }
    
    func applyAuthorMetadataAndCleanup(context: ModelContext) async throws {
        let cutoff = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
        let notes = try context.fetch(FetchDescriptor<CloutmateShared.Note>())
        var deletedNotes = 0
        
        for note in notes {
            let hasAISummaryTag = note.tags.contains { $0.compare("AI summary", options: .caseInsensitive) == .orderedSame }
            
            if hasAISummaryTag {
                note.author = .aurora
                continue
            }

            if note.author == .aurora {
                continue
            }
            
            let mostRecent = max(note.createdAt, note.updatedAt)
            if mostRecent >= cutoff {
                note.author = .user
                continue
            }
            
            context.delete(note)
            deletedNotes += 1
        }
        
        let journals = try context.fetch(FetchDescriptor<Journal>())
        for journal in journals {
            if let aiContent = journal.aiGeneratedContent,
               !aiContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                journal.author = .aurora
            } else if journal.author == .unknown {
                journal.author = .user
            }
        }
        
        try context.save()
        os_log("Author metadata migration complete. Deleted %d legacy notes.", log: .default, type: .info, deletedNotes)
    }
    
    // Rollback helper (for Settings → Advanced)
    func restoreDraftsFromInbox(context: ModelContext) async throws {
        let migrationDate = Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: "phase3_migrated_date"))
        let inboxItems = try context.fetch(FetchDescriptor<InboxItem>(
            predicate: #Predicate { $0.createdAt >= migrationDate && $0.convertedAt == nil }
        ))
        
        for item in inboxItems {
            let draft = Draft(
                caption: item.content,
                tags: []
            )
            draft.createdAt = item.createdAt
            if let fileURL = item.fileURL {
                draft.mediaURLs = [fileURL]
            }
            context.insert(draft)
        }
        
        try context.save()
        os_log("Restored %d drafts from inbox", log: .default, type: .info, inboxItems.count)
    }
}

