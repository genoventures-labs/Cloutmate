//
//  MigrationService.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData
import os.log


actor MigrationService {
    static let shared = MigrationService()
    
    private init() {}
    
    func migrateExistingData(context: ModelContext) async throws {
        // Log counts BEFORE migration
        let draftsCountBefore = try context.fetch(FetchDescriptor<Draft>()).count
        let postsCountBefore = try context.fetch(FetchDescriptor<Post>()).count
        
        os_log("Starting Phase 3 migration: %d drafts, %d posts", log: .default, type: .info, draftsCountBefore, postsCountBefore)
        
        // Transaction wrapper
        try context.transaction {
        // 1. Create default "Social Publishing" Area
        let defaultArea = Area(
            title: "Social Publishing",
            notes: "Content creation and distribution",
            tags: []
        )
            context.insert(defaultArea)
            
            // 2. Migrate Drafts → Inbox Items (keep originals for fallback)
            let drafts = try context.fetch(FetchDescriptor<Draft>())
            for draft in drafts {
                let inboxItem = InboxItem(
                    content: draft.caption,
                    itemType: "text",
                    fileURL: draft.mediaURLs.first
                )
                inboxItem.createdAt = draft.createdAt
                context.insert(inboxItem)
                
                // Mark draft as migrated (archived)
                draft.isArchived = true
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
        
        // Store migration metadata
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "phase3_migrated_date")
        UserDefaults.standard.set(draftsCountBefore, forKey: "phase3_drafts_count")
        UserDefaults.standard.set(inboxCountAfter, forKey: "phase3_inbox_count")
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

