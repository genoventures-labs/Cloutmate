//
//  MigrationService.swift
//  FocusOS
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData
import os.log
import FocusOSShared

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
        let notes = try context.fetch(FetchDescriptor<FocusOSShared.Note>())
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
    
    func migrateProjectExternalFields(context: ModelContext) async throws {
        // Check if migration already ran
        if UserDefaults.standard.bool(forKey: "project_external_fields_migrated") {
            os_log("Project external fields migration already completed, skipping", log: .default, type: .info)
            return
        }
        
        os_log("Starting project external fields migration", log: .default, type: .info)
        
        // Fetch all existing projects
        let projects = try context.fetch(FetchDescriptor<FocusOSShared.Project>())
        os_log("Found %d projects to migrate", log: .default, type: .info, projects.count)
        
        var migratedCount = 0
        for project in projects {
            // Ensure new optional fields are recognized by SwiftData
            // Accessing and explicitly setting them (even to nil) ensures
            // SwiftData recognizes the new schema fields for existing records
            project.externalProjectId = project.externalProjectId
            project.externalSource = project.externalSource
            project.lastSyncedAt = project.lastSyncedAt
            
            // Touch the project to ensure SwiftData recognizes it with the new schema
            // This preserves all existing project data while adding the new fields
            let currentUpdatedAt = project.updatedAt
            project.updatedAt = currentUpdatedAt
            
            migratedCount += 1
        }
        
        // Save all projects with the new schema
        try context.save()
        os_log("Project external fields migration complete. Migrated %d projects.", log: .default, type: .info, migratedCount)
        
        // Mark migration as complete
        UserDefaults.standard.set(true, forKey: "project_external_fields_migrated")
        UserDefaults.standard.synchronize()
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
    
    // MARK: - Cloutmate to FocusOS Migration
    
    /// Migrates data from old Cloutmate containers to new FocusOS containers
    func migrateFromCloutmate(context: ModelContext) async throws {
        // Check if migration already ran
        if UserDefaults.standard.bool(forKey: "cloutmate_to_focusos_migrated") {
            os_log("Cloutmate to FocusOS migration already completed, skipping", log: .default, type: .info)
            return
        }
        
        os_log("Starting Cloutmate to FocusOS data migration", log: .default, type: .info)
        
        // Try to find the old Cloutmate database
        // First, try app group access
        let oldAppGroupID = "group.kosmicapps.cloutmate"
        var oldAppGroupURL: URL?
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: oldAppGroupID) {
            oldAppGroupURL = url
        } else {
            // Fallback: try direct path (might work if app group still exists but not accessible)
            let directPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Group Containers/\(oldAppGroupID)")
            if FileManager.default.fileExists(atPath: directPath.path) {
                oldAppGroupURL = directPath
            }
        }
        
        guard let baseURL = oldAppGroupURL else {
            os_log("Old Cloutmate app group not found, migration skipped", log: .default, type: .info)
            // Mark as migrated even if old data doesn't exist (first time setup)
            UserDefaults.standard.set(true, forKey: "cloutmate_to_focusos_migrated")
            return
        }
        
        // Try to find the most recent database file
        let possibleDBFiles = [
            "Cloutmate_v3.sqlite",
            "Cloutmate_v2.sqlite",
            "Cloutmate.sqlite"
        ]
        
        var sourceDBURL: URL?
        for dbFile in possibleDBFiles {
            let url = baseURL.appendingPathComponent(dbFile)
            if FileManager.default.fileExists(atPath: url.path) {
                sourceDBURL = url
                os_log("Found old Cloutmate database: %@", log: .default, type: .info, dbFile)
                break
            }
        }
        
        guard let sourceDBURL = sourceDBURL else {
            os_log("No Cloutmate database files found, migration skipped", log: .default, type: .info)
            UserDefaults.standard.set(true, forKey: "cloutmate_to_focusos_migrated")
            return
        }
        
        // Copy database to a temporary location we can access
        // This avoids sandbox restrictions
        let tempDir = FileManager.default.temporaryDirectory
        let tempDBURL = tempDir.appendingPathComponent("Cloutmate_Migration_\(UUID().uuidString).sqlite")
        
        // Also copy WAL and SHM files if they exist
        let walURL = sourceDBURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
        let shmURL = sourceDBURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
        let tempWalURL = tempDBURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
        let tempShmURL = tempDBURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
        
        // Check if we can access the source file
        os_log("Attempting to access source database at: %@", log: .default, type: .info, sourceDBURL.path)
        
        // Check file permissions
        var isReadable = false
        if FileManager.default.isReadableFile(atPath: sourceDBURL.path) {
            isReadable = true
            os_log("Source database is readable", log: .default, type: .info)
        } else {
            os_log("Source database is NOT readable - sandbox restriction", log: .default, type: .error)
        }
        
        do {
            // Remove any existing temp file
            if FileManager.default.fileExists(atPath: tempDBURL.path) {
                try FileManager.default.removeItem(at: tempDBURL)
            }
            
            // Copy main database file
            os_log("Attempting to copy database from %@ to %@", log: .default, type: .info, sourceDBURL.path, tempDBURL.path)
            try FileManager.default.copyItem(at: sourceDBURL, to: tempDBURL)
            os_log("Successfully copied database to temp location: %@", log: .default, type: .info, tempDBURL.path)
            
            // Verify the copy worked
            if FileManager.default.fileExists(atPath: tempDBURL.path) {
                let attributes = try FileManager.default.attributesOfItem(atPath: tempDBURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                os_log("Temp database file exists, size: %lld bytes", log: .default, type: .info, fileSize)
            } else {
                os_log("ERROR: Temp database file was not created", log: .default, type: .error)
                throw NSError(domain: "MigrationError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create temp database file"])
            }
            
            // Copy WAL file if it exists
            if FileManager.default.fileExists(atPath: walURL.path) {
                if FileManager.default.fileExists(atPath: tempWalURL.path) {
                    try FileManager.default.removeItem(at: tempWalURL)
                }
                try FileManager.default.copyItem(at: walURL, to: tempWalURL)
                os_log("Copied WAL file", log: .default, type: .info)
            }
            
            // Copy SHM file if it exists
            if FileManager.default.fileExists(atPath: shmURL.path) {
                if FileManager.default.fileExists(atPath: tempShmURL.path) {
                    try FileManager.default.removeItem(at: tempShmURL)
                }
                try FileManager.default.copyItem(at: shmURL, to: tempShmURL)
                os_log("Copied SHM file", log: .default, type: .info)
            }
        } catch {
            os_log("Failed to copy database file: %{public}@", log: .default, type: .error, error.localizedDescription)
            os_log("Error details: %@", log: .default, type: .error, String(describing: error))
            
            // Try to provide helpful error message
            if let nsError = error as NSError? {
                os_log("NSError domain: %@, code: %ld", log: .default, type: .error, nsError.domain, nsError.code)
                if nsError.domain == NSCocoaErrorDomain && nsError.code == 257 {
                    os_log("Permission denied - sandbox is blocking file access", log: .default, type: .error)
                }
            }
            
            // Don't mark as migrated if copy failed - user might fix permissions
            // UserDefaults.standard.set(true, forKey: "cloutmate_to_focusos_migrated")
            throw error
        }
        
        // Use the temporary database file
        let oldDBURL = tempDBURL
        
        // Cleanup function to remove temp files after migration
        defer {
            try? FileManager.default.removeItem(at: tempDBURL)
            try? FileManager.default.removeItem(at: tempWalURL)
            try? FileManager.default.removeItem(at: tempShmURL)
        }
        
        // Create schema matching the old Cloutmate structure
        // Note: We use the same model types since they should be compatible
        let oldSchema = Schema([
            FocusOSShared.Post.self,
            Draft.self,
            FocusOSShared.Template.self,
            FocusOSShared.Note.self,
            FocusOSShared.Task.self,
            FocusOSShared.Project.self,
            FocusOSShared.InboxItem.self,
            FocusOSShared.PerformancePrediction.self,
            FocusOSShared.RecyclablePost.self,
            FocusOSShared.ContentTopic.self,
            FocusOSShared.ContentBalance.self,
            FocusOSShared.PostingTimeTest.self,
            FocusOSShared.OptimalPostingTime.self,
            FocusOSShared.CustomPostProperty.self,
            FocusOSShared.PostView.self,
            FocusOSShared.HashtagPerformance.self,
            FocusOSShared.HashtagSet.self
        ])
        
        let oldConfig = ModelConfiguration(
            schema: oldSchema,
            url: oldDBURL,
            cloudKitDatabase: .none
        )
        
        // Try to open the old container
        os_log("Attempting to open old Cloutmate container at: %@", log: .default, type: .info, oldDBURL.path)
        
        let oldContainer: ModelContainer
        do {
            oldContainer = try ModelContainer(for: oldSchema, configurations: [oldConfig])
            os_log("Successfully opened old Cloutmate container", log: .default, type: .info)
        } catch {
            os_log("Failed to open old Cloutmate container: %{public}@", log: .default, type: .error, error.localizedDescription)
            os_log("Error details: %@", log: .default, type: .error, String(describing: error))
            
            // Don't mark as migrated if we can't open the database
            // This allows the user to try again after fixing permissions
            throw error
        }
        
        let oldContext = oldContainer.mainContext
        
        // Track migration statistics
        var migratedCounts: [String: Int] = [:]
        
        // Migrate Posts
        do {
            let oldPosts = try oldContext.fetch(FetchDescriptor<FocusOSShared.Post>())
            os_log("Found %d posts in old Cloutmate database", log: .default, type: .info, oldPosts.count)
            let existingPosts = try context.fetch(FetchDescriptor<FocusOSShared.Post>())
            os_log("Found %d existing posts in FocusOS database", log: .default, type: .info, existingPosts.count)
            let existingPostIDs = Set(existingPosts.map { $0.id })
            
            var migrated = 0
            for oldPost in oldPosts {
                // Skip if already exists (by ID)
                if existingPostIDs.contains(oldPost.id) {
                    continue
                }
                
                let newPost = FocusOSShared.Post(
                    caption: oldPost.caption,
                    mediaURLs: oldPost.mediaURLs,
                    scheduledDate: oldPost.scheduledDate,
                    status: oldPost.status,
                    tags: oldPost.tags,
                    projectId: oldPost.projectId,
                    areaId: oldPost.areaId
                )
                // Preserve original ID and timestamps
                newPost.id = oldPost.id
                newPost.createdAt = oldPost.createdAt
                newPost.updatedAt = oldPost.updatedAt
                newPost.publishedDate = oldPost.publishedDate
                newPost.engagementRate = oldPost.engagementRate
                newPost.impressions = oldPost.impressions
                newPost.likes = oldPost.likes
                newPost.comments = oldPost.comments
                newPost.saves = oldPost.saves
                newPost.reach = oldPost.reach
                newPost.customProperties = oldPost.customProperties
                newPost.contentPillar = oldPost.contentPillar
                newPost.funnelStage = oldPost.funnelStage
                newPost.campaignId = oldPost.campaignId
                newPost.retryCount = oldPost.retryCount
                newPost.lastError = oldPost.lastError
                
                context.insert(newPost)
                migrated += 1
            }
            migratedCounts["Posts"] = migrated
            os_log("Migrated %d posts from Cloutmate", log: .default, type: .info, migrated)
        } catch {
            os_log("Error migrating posts: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
        
        // Migrate Drafts
        do {
            let oldDrafts = try oldContext.fetch(FetchDescriptor<Draft>())
            os_log("Found %d drafts in old Cloutmate database", log: .default, type: .info, oldDrafts.count)
            let existingDrafts = try context.fetch(FetchDescriptor<Draft>())
            os_log("Found %d existing drafts in FocusOS database", log: .default, type: .info, existingDrafts.count)
            let existingDraftIDs = Set(existingDrafts.map { $0.id })
            
            var migrated = 0
            for oldDraft in oldDrafts {
                if existingDraftIDs.contains(oldDraft.id) {
                    continue
                }
                
                let newDraft = Draft(
                    title: oldDraft.title,
                    caption: oldDraft.caption,
                    mediaURLs: oldDraft.mediaURLs,
                    tags: oldDraft.tags,
                    notes: oldDraft.notes
                )
                newDraft.id = oldDraft.id
                newDraft.createdAt = oldDraft.createdAt
                newDraft.updatedAt = oldDraft.updatedAt
                newDraft.archivedAt = oldDraft.archivedAt
                newDraft.source = oldDraft.source
                newDraft.isPublished = oldDraft.isPublished
                newDraft.lastEditedAt = oldDraft.lastEditedAt
                newDraft.wordCount = oldDraft.wordCount
                newDraft.associatedPostID = oldDraft.associatedPostID
                newDraft.convertedAt = oldDraft.convertedAt
                newDraft.scheduledOrPublishedDate = oldDraft.scheduledOrPublishedDate
                newDraft.isArchived = oldDraft.isArchived
                
                context.insert(newDraft)
                migrated += 1
            }
            migratedCounts["Drafts"] = migrated
            os_log("Migrated %d drafts from Cloutmate", log: .default, type: .info, migrated)
        } catch {
            os_log("Error migrating drafts: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
        
        // Migrate Notes
        do {
            let oldNotes = try oldContext.fetch(FetchDescriptor<FocusOSShared.Note>())
            os_log("Found %d notes in old Cloutmate database", log: .default, type: .info, oldNotes.count)
            let existingNotes = try context.fetch(FetchDescriptor<FocusOSShared.Note>())
            os_log("Found %d existing notes in FocusOS database", log: .default, type: .info, existingNotes.count)
            let existingNoteIDs = Set(existingNotes.map { $0.id })
            
            var migrated = 0
            for oldNote in oldNotes {
                if existingNoteIDs.contains(oldNote.id) {
                    continue
                }
                
                let newNote = FocusOSShared.Note(
                    title: oldNote.title,
                    markdown: oldNote.markdown,
                    tags: oldNote.tags,
                    projectId: oldNote.projectId,
                    areaId: oldNote.areaId,
                    source: oldNote.source,
                    type: oldNote.type
                )
                newNote.id = oldNote.id
                newNote.createdAt = oldNote.createdAt
                newNote.updatedAt = oldNote.updatedAt
                newNote.archivedAt = oldNote.archivedAt
                newNote.isArchived = oldNote.isArchived
                newNote.isPinned = oldNote.isPinned
                newNote.pinnedAt = oldNote.pinnedAt
                newNote.author = oldNote.author
                newNote.backlinks = oldNote.backlinks
                newNote.highlights = oldNote.highlights
                
                context.insert(newNote)
                migrated += 1
            }
            migratedCounts["Notes"] = migrated
            os_log("Migrated %d notes from Cloutmate", log: .default, type: .info, migrated)
        } catch {
            os_log("Error migrating notes: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
        
        // Migrate Tasks
        do {
            let oldTasks = try oldContext.fetch(FetchDescriptor<FocusOSShared.Task>())
            os_log("Found %d tasks in old Cloutmate database", log: .default, type: .info, oldTasks.count)
            let existingTasks = try context.fetch(FetchDescriptor<FocusOSShared.Task>())
            os_log("Found %d existing tasks in FocusOS database", log: .default, type: .info, existingTasks.count)
            let existingTaskIDs = Set(existingTasks.map { $0.id })
            
            var migrated = 0
            for oldTask in oldTasks {
                if existingTaskIDs.contains(oldTask.id) {
                    continue
                }
                
                let newTask = FocusOSShared.Task(
                    title: oldTask.title,
                    notes: oldTask.notes,
                    status: oldTask.status,
                    priority: oldTask.priority,
                    dueDate: oldTask.dueDate,
                    projectId: oldTask.projectId,
                    areaId: oldTask.areaId,
                    effort: oldTask.effort
                )
                newTask.id = oldTask.id
                newTask.createdAt = oldTask.createdAt
                newTask.updatedAt = oldTask.updatedAt
                newTask.completedAt = oldTask.completedAt
                newTask.dependsOnIds = oldTask.dependsOnIds
                newTask.linkedEntityIds = oldTask.linkedEntityIds
                newTask.linkedEntityTypes = oldTask.linkedEntityTypes
                
                context.insert(newTask)
                migrated += 1
            }
            migratedCounts["Tasks"] = migrated
            os_log("Migrated %d tasks from Cloutmate", log: .default, type: .info, migrated)
        } catch {
            os_log("Error migrating tasks: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
        
        // Migrate Projects
        do {
            let oldProjects = try oldContext.fetch(FetchDescriptor<FocusOSShared.Project>())
            os_log("Found %d projects in old Cloutmate database", log: .default, type: .info, oldProjects.count)
            let existingProjects = try context.fetch(FetchDescriptor<FocusOSShared.Project>())
            os_log("Found %d existing projects in FocusOS database", log: .default, type: .info, existingProjects.count)
            let existingProjectIDs = Set(existingProjects.map { $0.id })
            
            var migrated = 0
            for oldProject in oldProjects {
                if existingProjectIDs.contains(oldProject.id) {
                    continue
                }
                
                let newProject = FocusOSShared.Project(
                    title: oldProject.title,
                    goal: oldProject.goal,
                    status: oldProject.status,
                    dueDate: oldProject.dueDate,
                    areaId: oldProject.areaId,
                    tags: oldProject.tags
                )
                newProject.id = oldProject.id
                newProject.createdAt = oldProject.createdAt
                newProject.updatedAt = oldProject.updatedAt
                newProject.archivedAt = oldProject.archivedAt
                newProject.taskIds = oldProject.taskIds
                newProject.noteIds = oldProject.noteIds
                newProject.postIds = oldProject.postIds
                newProject.linkedEntityIds = oldProject.linkedEntityIds
                newProject.linkedEntityTypes = oldProject.linkedEntityTypes
                
                context.insert(newProject)
                migrated += 1
            }
            migratedCounts["Projects"] = migrated
            os_log("Migrated %d projects from Cloutmate", log: .default, type: .info, migrated)
        } catch {
            os_log("Error migrating projects: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
        
        // Migrate InboxItems
        do {
            let oldInboxItems = try oldContext.fetch(FetchDescriptor<FocusOSShared.InboxItem>())
            let existingInboxItems = try context.fetch(FetchDescriptor<FocusOSShared.InboxItem>())
            let existingInboxIDs = Set(existingInboxItems.map { $0.id })
            
            var migrated = 0
            for oldItem in oldInboxItems {
                if existingInboxIDs.contains(oldItem.id) {
                    continue
                }
                
                let newItem = FocusOSShared.InboxItem(
                    content: oldItem.content,
                    itemType: oldItem.itemType,
                    fileURL: oldItem.fileURL
                )
                newItem.id = oldItem.id
                newItem.createdAt = oldItem.createdAt
                newItem.convertedToType = oldItem.convertedToType
                newItem.convertedToId = oldItem.convertedToId
                newItem.convertedAt = oldItem.convertedAt
                newItem.isFlagged = oldItem.isFlagged
                newItem.isArchived = oldItem.isArchived
                newItem.aiImported = oldItem.aiImported
                
                context.insert(newItem)
                migrated += 1
            }
            migratedCounts["InboxItems"] = migrated
            os_log("Migrated %d inbox items from Cloutmate", log: .default, type: .info, migrated)
        } catch {
            os_log("Error migrating inbox items: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
        
        // Migrate Templates
        do {
            let oldTemplates = try oldContext.fetch(FetchDescriptor<FocusOSShared.Template>())
            let existingTemplates = try context.fetch(FetchDescriptor<FocusOSShared.Template>())
            let existingTemplateIDs = Set(existingTemplates.map { $0.id })
            
            var migrated = 0
            for oldTemplate in oldTemplates {
                if existingTemplateIDs.contains(oldTemplate.id) {
                    continue
                }
                
                let newTemplate = FocusOSShared.Template(
                    name: oldTemplate.name,
                    caption: oldTemplate.caption,
                    tags: oldTemplate.tags
                )
                newTemplate.id = oldTemplate.id
                newTemplate.createdAt = oldTemplate.createdAt
                newTemplate.updatedAt = oldTemplate.updatedAt
                
                context.insert(newTemplate)
                migrated += 1
            }
            migratedCounts["Templates"] = migrated
            os_log("Migrated %d templates from Cloutmate", log: .default, type: .info, migrated)
        } catch {
            os_log("Error migrating templates: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
        
        // Save all migrated data
        try context.save()
        os_log("Saved all migrated data to context", log: .default, type: .info)
        
        // Log summary
        let summary = migratedCounts.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        os_log("Cloutmate to FocusOS migration complete. Migrated: %@", log: .default, type: .info, summary)
        
        // Verify data was actually imported
        let totalMigrated = migratedCounts.values.reduce(0, +)
        if totalMigrated == 0 {
            os_log("WARNING: Migration completed but no data was imported!", log: .default, type: .error)
            // Don't mark as migrated if nothing was imported - allow retry
            throw NSError(domain: "MigrationError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Migration completed but no data was imported"])
        }
        
        os_log("Successfully migrated %d total items from Cloutmate", log: .default, type: .info, totalMigrated)
        
        // Mark migration as complete only if data was actually imported
        UserDefaults.standard.set(true, forKey: "cloutmate_to_focusos_migrated")
        UserDefaults.standard.synchronize()
        os_log("Migration flag set to complete", log: .default, type: .info)
    }
}

