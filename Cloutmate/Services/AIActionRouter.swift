//
//  AIActionRouter.swift
//  Cloutmate
//
//  Routes high-level AI intents to app services for execution.
//

import Foundation
import SwiftData
import CloutmateShared
import Combine

// Type aliases to disambiguate from Swift.Concurrency.Task and resolve moved models
fileprivate typealias PARATask = CloutmateShared.Task
fileprivate typealias PARANote = CloutmateShared.Note
fileprivate typealias PARAProject = CloutmateShared.Project
fileprivate typealias PARAInboxItem = CloutmateShared.InboxItem

enum AIIntentAction {
    case archiveTasks(criteria: AIExecutionService.ArchiveCriteria, daysAgo: Int?, projectId: UUID?)
    case summarizePosts(filter: AIExecutionService.PostFilter, filterValue: String?)
    case generateReport(type: AIExecutionService.ReportType)
    case predictScheduling(daysAhead: Int?)
    case createPost(PostCreationRequest)
    case publishPost(PostPublishRequest)
    case createTask(TaskCreationRequest)
    case updateTask(TaskUpdateRequest)
    case deleteTask(UUID)
    case createNote(NoteMutationRequest)
    case updateNote(NoteUpdateRequest)
    case deleteNote(UUID)
    case addInboxItem(InboxAdditionRequest)
    case convertInboxItem(InboxConversionRequest)
    case createProject(ProjectCreationRequest)
    case updateProject(ProjectUpdateRequest)
    case deleteProject(UUID)
    case digestConversation(UUID)
    case digestAllConversations
    case searchConversations(query: String)
    case createReminder(ReminderCreationRequest)
    
    var displayName: String {
        switch self {
        case .archiveTasks: return "Archive Tasks"
        case .summarizePosts: return "Summarize Posts"
        case .generateReport: return "Generate Report"
        case .predictScheduling: return "Predict Scheduling Needs"
        case .createPost(let request):
            return request.scheduledDate != nil ? "Create & Schedule Post" : "Create Post"
        case .publishPost: return "Publish Post"
        case .createTask: return "Create Task"
        case .updateTask: return "Update Task"
        case .deleteTask: return "Delete Task"
        case .createNote: return "Create Note"
        case .updateNote: return "Update Note"
        case .deleteNote: return "Delete Note"
        case .addInboxItem: return "Add Inbox Item"
        case .convertInboxItem(let request):
            switch request.target {
            case .task: return "Convert Inbox to Task"
            case .note: return "Convert Inbox to Note"
            case .draft: return "Convert Inbox to Draft"
            }
        case .createProject: return "Create Project"
        case .updateProject: return "Update Project"
        case .deleteProject: return "Delete Project"
        case .digestConversation: return "Digest Conversation"
        case .digestAllConversations: return "Digest All Conversations"
        case .searchConversations: return "Search Conversations"
        case .createReminder: return "Create Reminder"
        }
    }
    
    var metadata: [String: String] {
        switch self {
        case .archiveTasks(let criteria, let daysAgo, let projectId):
            var data: [String: String] = ["criteria": criteria.rawValue]
            if let daysAgo {
                data["daysAgo"] = String(daysAgo)
            }
            if let projectId {
                data["projectId"] = projectId.uuidString
            }
            return data
        case .summarizePosts(let filter, let filterValue):
            var data: [String: String] = ["filter": filter.rawValue]
            if let filterValue {
                data["filterValue"] = filterValue
            }
            return data
        case .generateReport(let type):
            return ["reportType": type.rawValue]
        case .predictScheduling(let daysAhead):
            if let daysAhead {
                return ["daysAhead": String(daysAhead)]
            }
            return [:]
        case .createPost(let request):
            var data: [String: String] = [
                "createDraft": request.createDraft ? "true" : "false",
                "platforms": request.platforms.map(\.rawValue).joined(separator: ",")
            ]
            if let scheduledDate = request.scheduledDate {
                data["scheduledDate"] = isoString(from: scheduledDate)
            }
            if !request.tags.isEmpty {
                data["tags"] = request.tags.joined(separator: ",")
            }
            return data
        case .publishPost(let request):
            var data: [String: String] = ["postId": request.postId.uuidString]
            if let notes = request.notes, !notes.isEmpty {
                data["notes"] = notes
            }
            return data
        case .createTask(let request):
            var data: [String: String] = ["status": request.status.rawValue, "priority": request.priority.rawValue]
            data["title"] = request.title
            if let due = request.dueDate {
                data["dueDate"] = isoString(from: due)
            }
            if let projectId = request.projectId {
                data["projectId"] = projectId.uuidString
            }
            if let areaId = request.areaId {
                data["areaId"] = areaId.uuidString
            }
            return data
        case .updateTask(let request):
            var data: [String: String] = ["taskId": request.taskId.uuidString]
            if let status = request.status { data["status"] = status.rawValue }
            if let priority = request.priority { data["priority"] = priority.rawValue }
            if let due = request.dueDate { data["dueDate"] = isoString(from: due) }
            if let projectId = request.projectId { data["projectId"] = projectId.uuidString }
            if let areaId = request.areaId { data["areaId"] = areaId.uuidString }
            return data
        case .deleteTask(let taskId):
            return ["taskId": taskId.uuidString]
        case .createNote(let request):
            var data: [String: String] = ["title": request.title]
            if !request.tags.isEmpty { data["tags"] = request.tags.joined(separator: ",") }
            return data
        case .updateNote(let request):
            var data: [String: String] = ["noteId": request.noteId.uuidString]
            if let tags = request.tags, !tags.isEmpty { data["tags"] = tags.joined(separator: ",") }
            return data
        case .deleteNote(let noteId):
            return ["noteId": noteId.uuidString]
        case .addInboxItem(let request):
            return ["itemType": request.itemType]
        case .convertInboxItem(let request):
            switch request.target {
            case .task:
                return ["conversion": "task", "itemId": request.itemId.uuidString]
            case .note:
                return ["conversion": "note", "itemId": request.itemId.uuidString]
            case .draft:
                return ["conversion": "draft", "itemId": request.itemId.uuidString]
            }
        case .createProject(let request):
            var data: [String: String] = ["title": request.title, "status": request.status.rawValue]
            if let due = request.dueDate { data["dueDate"] = isoString(from: due) }
            if let areaId = request.areaId { data["areaId"] = areaId.uuidString }
            if !request.tags.isEmpty { data["tags"] = request.tags.joined(separator: ",") }
            return data
        case .updateProject(let request):
            var data: [String: String] = ["projectId": request.projectId.uuidString]
            if let status = request.status { data["status"] = status.rawValue }
            if let due = request.dueDate { data["dueDate"] = isoString(from: due) }
            if let areaId = request.areaId { data["areaId"] = areaId.uuidString }
            if let tags = request.tags, !tags.isEmpty { data["tags"] = tags.joined(separator: ",") }
            return data
        case .deleteProject(let projectId):
            return ["projectId": projectId.uuidString]
        case .digestConversation(let conversationId):
            return ["conversationId": conversationId.uuidString]
        case .digestAllConversations:
            return [:]
        case .searchConversations(let query):
            return ["query": query]
        case .createReminder(let request):
            var data: [String: String] = ["title": request.title]
            if let notes = request.notes, !notes.isEmpty {
                data["notes"] = notes
            }
            data["reminderDate"] = isoString(from: request.reminderDate)
            if let taskId = request.taskId {
                data["taskId"] = taskId.uuidString
            }
            if let projectId = request.projectId {
                data["projectId"] = projectId.uuidString
            }
            return data
        }
    }
}

struct PostCreationRequest {
    let caption: String
    let platforms: [Platform]
    let scheduledDate: Date?
    let tags: [String]
    let notes: String?
    let createDraft: Bool
    let draftId: UUID?
}

struct TaskCreationRequest {
    let title: String
    let notes: String?
    let dueDate: Date?
    let status: CloutmateShared.TaskStatus
    let priority: CloutmateShared.TaskPriority
    let projectId: UUID?
    let areaId: UUID?
}

struct TaskUpdateRequest {
    let taskId: UUID
    let title: String?
    let notes: String?
    let dueDate: Date?
    let status: CloutmateShared.TaskStatus?
    let priority: CloutmateShared.TaskPriority?
    let projectId: UUID?
    let areaId: UUID?
}

struct NoteMutationRequest {
    let noteId: UUID?
    let title: String
    let body: String
    let tags: [String]
}

struct NoteUpdateRequest {
    let noteId: UUID
    let title: String?
    let body: String?
    let tags: [String]?
}

struct InboxAdditionRequest {
    let content: String
    let itemType: String
}

enum InboxConversionTarget {
    case task(TaskCreationRequest)
    case note(NoteMutationRequest)
    case draft(PostCreationRequest)
}

struct InboxConversionRequest {
    let itemId: UUID
    let target: InboxConversionTarget
}

struct ProjectCreationRequest {
    let title: String
    let goal: String?
    let status: CloutmateShared.ProjectStatus
    let dueDate: Date?
    let areaId: UUID?
    let tags: [String]
}

struct ProjectUpdateRequest {
    let projectId: UUID
    let title: String?
    let goal: String?
    let status: CloutmateShared.ProjectStatus?
    let dueDate: Date?
    let areaId: UUID?
    let tags: [String]?
}

struct PostPublishRequest {
    let postId: UUID
    let notes: String?
}

struct ReminderCreationRequest {
    let title: String
    let notes: String?
    let reminderDate: Date
    let taskId: UUID?
    let projectId: UUID?
}

struct AIActionResult {
    let title: String
    let message: String
    let markdown: String
    let details: [String]
    let itemsAffected: Int
    let affectedObjectIDs: [UUID]
    let metadata: [String: String]
    
    init(
        title: String,
        message: String,
        markdown: String,
        details: [String],
        itemsAffected: Int,
        affectedObjectIDs: [UUID] = [],
        metadata: [String: String] = [:]
    ) {
        self.title = title
        self.message = message
        self.markdown = markdown
        self.details = details
        self.itemsAffected = itemsAffected
        self.affectedObjectIDs = affectedObjectIDs
        self.metadata = metadata
    }
    
    init(
        title: String,
        executionResult: AIExecutionService.ExecutionResult,
        affectedObjectIDs: [UUID] = [],
        metadata: [String: String] = [:]
    ) {
        self.init(
            title: title,
            message: executionResult.message,
            markdown: executionResult.asMarkdown(),
            details: executionResult.details,
            itemsAffected: executionResult.itemsAffected,
            affectedObjectIDs: affectedObjectIDs,
            metadata: metadata
        )
    }
    
    func toFeedbackSummary() -> FeedbackSummary {
        let detail: String
        if itemsAffected > 0 {
            detail = "\(message) (\(itemsAffected) item\(itemsAffected == 1 ? "" : "s"))"
        } else {
            detail = message
        }
        return FeedbackSummary(title: title, detail: detail, timestamp: Date())
    }
}

@MainActor
final class AIActionRouter {
    static let shared = AIActionRouter()
    
    private let executionService = AIExecutionService.shared
    
    private init() {}
    
    private var config: AIConfig {
        AIConfigService.shared.config
    }
    
    func route(_ action: AIIntentAction, modelContext: ModelContext) async throws -> AIActionResult {
        // Route regardless of feature flag but log when disabled to ease debugging.
        if !config.featureFlags.actionRouterEnabled {
            AIDebug.log("AIActionRouter invoked while disabled for action \(action.displayName)")
        }
        
        switch action {
        case let .archiveTasks(criteria, daysAgo, projectId):
            let result = try await executionService.archiveTasks(
                criteria: criteria,
                daysAgo: daysAgo,
                projectId: projectId,
                context: modelContext
            )
            AIDebug.log("AIActionRouter executed \(action.displayName) [criteria=\(criteria.rawValue)]")
            return AIActionResult(
                title: action.displayName,
                executionResult: result,
                metadata: action.metadata
            )
            
        case let .summarizePosts(filter, filterValue):
            let result = try await executionService.summarizePosts(
                filter: filter,
                filterValue: filterValue,
                context: modelContext
            )
            AIDebug.log("AIActionRouter executed \(action.displayName) [filter=\(filter.rawValue)]")
            return AIActionResult(
                title: action.displayName,
                executionResult: result,
                metadata: action.metadata
            )
            
        case let .generateReport(type):
            let result = try await executionService.generateProgressReport(
                type: type,
                context: modelContext
            )
            AIDebug.log("AIActionRouter executed \(action.displayName) [type=\(type.rawValue)]")
            return AIActionResult(
                title: action.displayName,
                executionResult: result,
                metadata: action.metadata
            )
            
        case let .predictScheduling(daysAhead):
            let result = try await executionService.predictSchedulingNeeds(
                daysAhead: daysAhead ?? 7,
                context: modelContext
            )
            AIDebug.log("AIActionRouter executed \(action.displayName) [daysAhead=\(daysAhead ?? 7)]")
            return AIActionResult(
                title: action.displayName,
                executionResult: result,
                metadata: action.metadata
            )
            
        case let .createPost(request):
            let now = Date()
            var affectedIDs: [UUID] = []
            var details: [String] = []

            var createdDraft: Draft?
            if request.createDraft {
                let draft = Draft(
                    caption: request.caption,
                    mediaURLs: [],
                    tags: request.tags,
                    notes: request.notes
                )
                if let scheduled = request.scheduledDate {
                    draft.scheduledOrPublishedDate = scheduled
                }
                modelContext.insert(draft)
                createdDraft = draft
                affectedIDs.append(draft.id)
                details.append("Draft created (\(draft.id.uuidString.prefix(8)))")
                AIRecallService.shared.registerCreated(draft, modelContext: modelContext)
            }

            let post: Post
            if let draft = createdDraft {
                post = draft.toPost(platforms: request.platforms, scheduledDate: request.scheduledDate)
                draft.associatedPostID = post.id
                draft.convertedAt = now
            } else if let draftId = request.draftId,
                      let existingDraft = fetchDraft(by: draftId, context: modelContext) {
                post = existingDraft.toPost(platforms: request.platforms, scheduledDate: request.scheduledDate)
                existingDraft.associatedPostID = post.id
                existingDraft.convertedAt = now
                createdDraft = existingDraft
                details.append("Draft \(draftId.uuidString.prefix(8)) scheduled")
            } else {
                post = Post(
                    caption: request.caption,
                    mediaURLs: [],
                    scheduledDate: request.scheduledDate,
                    platforms: request.platforms.map { $0.rawValue },
                    status: request.scheduledDate != nil ? PostStatus.scheduled.rawValue : PostStatus.draft.rawValue,
                    tags: request.tags
                )
            }

            if let scheduled = request.scheduledDate {
                post.scheduledDate = scheduled
                post.postStatus = .scheduled
                details.append("Scheduled for \(formattedDateTime(scheduled))")
                createdDraft?.scheduledOrPublishedDate = scheduled
            } else {
                post.postStatus = .draft
                details.append("Saved as draft")
            }
            post.updatedAt = now

            modelContext.insert(post)
            affectedIDs.append(post.id)
            if request.draftId != nil, !request.createDraft, let existingDraft = createdDraft {
                AIRecallService.shared.registerUpdated(existingDraft, modelContext: modelContext)
            }
            AIRecallService.shared.registerCreated(post, modelContext: modelContext)

            do {
                try modelContext.save()
            } catch {
                AIDebug.log("Failed to save created post: \(error.localizedDescription)")
                throw error
            }

            let platformList = request.platforms.map(\.displayName).joined(separator: ", ")
            let summaryMessage = request.scheduledDate != nil
                ? "Post scheduled for \(formattedDateTime(request.scheduledDate!)) on \(platformList)"
                : "Post created for \(platformList)"

            var markdown = "✅ **Post ready**\n\n"
            markdown += "**Platforms:** \(platformList)\n"
            if let scheduled = request.scheduledDate {
                markdown += "**Scheduled:** \(formattedDateTime(scheduled))\n"
            }
            if request.createDraft, let draft = createdDraft {
                markdown += "**Draft ID:** \(draft.id.uuidString)\n"
            }
            markdown += "\n\(request.caption)"

            AIDebug.log("AIActionRouter executed \(action.displayName) [postID=\(post.id.uuidString.prefix(8))]")
            return AIActionResult(
                title: action.displayName,
                message: summaryMessage,
                markdown: markdown,
                details: details,
                itemsAffected: affectedIDs.count,
                affectedObjectIDs: affectedIDs,
                metadata: action.metadata
            )
        
        case let .publishPost(request):
            guard let post = fetchPost(by: request.postId, context: modelContext) else {
                throw ExecutionError.notFound("Post not found")
            }
            // Note: PublishingService was removed as part of social media posting removal
            // For now, just update the post status locally
            // TODO: Re-implement publishing when needed for artifact-based content
            post.postStatus = .published
            post.publishedDate = Date()
            AIRecallService.shared.registerUpdated(post, modelContext: modelContext)
            try? modelContext.save()
            let summary = "Post marked as published"
            var markdown = "✅ **Post published (status updated)**\n\n"
            markdown += "Caption: \(post.caption.prefix(140))\n"
            if let notes = request.notes, !notes.isEmpty {
                markdown += "Notes: \(notes)\n"
            }
            markdown += "\nExternal channel publishing runs separately until the integrations ship."
            return AIActionResult(
                title: action.displayName,
                message: summary,
                markdown: markdown,
                details: [summary],
                itemsAffected: 1,
                affectedObjectIDs: [post.id],
                metadata: action.metadata
            )
        
        case let .createTask(request):
            let task = PARATask(
                title: request.title,
                notes: request.notes,
                status: request.status,
                priority: request.priority,
                dueDate: request.dueDate,
                projectId: request.projectId,
                areaId: request.areaId
            )
            modelContext.insert(task)
            try? modelContext.save()
            AIRecallService.shared.registerCreated(task, modelContext: modelContext)
            let detail = summaryForTask(task)
            return AIActionResult(
                title: action.displayName,
                message: "Task created",
                markdown: "✅ **Task created**\n\n\(detail)",
                details: [detail],
                itemsAffected: 1,
                affectedObjectIDs: [task.id],
                metadata: action.metadata
            )
        
        case let .updateTask(request):
            guard let task = fetchTask(by: request.taskId, context: modelContext) else {
                throw ExecutionError.notFound("Task not found")
            }
            var changes: [String] = []
            if let title = request.title, !title.isEmpty, title != task.title {
                task.title = title
                changes.append("title")
            }
            if let notes = request.notes, notes != task.notes {
                task.notes = notes
                changes.append("notes")
            }
            if let due = request.dueDate {
                task.dueDate = due
                changes.append("dueDate")
            }
            if let status = request.status, status != task.status {
                task.status = status
                changes.append("status")
            }
            if let priority = request.priority, priority != task.priority {
                task.priority = priority
                changes.append("priority")
            }
            if let projectId = request.projectId {
                task.projectId = projectId
                changes.append("project")
            }
            if let areaId = request.areaId {
                task.areaId = areaId
                changes.append("area")
            }
            task.updatedAt = Date()
            try? modelContext.save()
            AIRecallService.shared.registerUpdated(task, modelContext: modelContext)
            let detail = summaryForTask(task)
            let changeSummary = changes.isEmpty ? "No fields changed" : "Updated: \(changes.joined(separator: ", "))"
            return AIActionResult(
                title: action.displayName,
                message: "Task updated",
                markdown: "✅ **Task updated**\n\n\(detail)\n\n\(changeSummary)",
                details: [detail, changeSummary],
                itemsAffected: 1,
                affectedObjectIDs: [task.id],
                metadata: action.metadata
            )
        
        case let .deleteTask(taskId):
            guard let task = fetchTask(by: taskId, context: modelContext) else {
                throw ExecutionError.notFound("Task not found")
            }
            let detail = summaryForTask(task)
            modelContext.delete(task)
            try? modelContext.save()
            AIRecallService.shared.removeObjects(withIDs: [taskId], modelContext: modelContext)
            return AIActionResult(
                title: action.displayName,
                message: "Task deleted",
                markdown: "🗑️ **Task deleted**\n\n\(detail)",
                details: [detail],
                itemsAffected: 1,
                affectedObjectIDs: [taskId],
                metadata: action.metadata
            )
        
        case let .createNote(request):
            let note = PARANote(
                title: request.title,
                markdown: request.body,
                tags: request.tags
            )
            note.author = .aurora
            modelContext.insert(note)
            try? modelContext.save()
            AIRecallService.shared.registerCreated(note, modelContext: modelContext)
            let detail = "Title: \(note.title)"
            return AIActionResult(
                title: action.displayName,
                message: "Note created",
                markdown: "✅ **Note created**\n\n\(detail)",
                details: [detail],
                itemsAffected: 1,
                affectedObjectIDs: [note.id],
                metadata: action.metadata
            )
        
        case let .updateNote(request):
            guard let note = fetchNote(by: request.noteId, context: modelContext) else {
                throw ExecutionError.notFound("Note not found")
            }
            var changes: [String] = []
            if let title = request.title, !title.isEmpty, title != note.title {
                note.title = title
                changes.append("title")
            }
            if let body = request.body, body != note.markdown {
                note.markdown = body
                changes.append("content")
            }
            if let tags = request.tags {
                note.tags = tags
                changes.append("tags")
            }
            note.updatedAt = Date()
            try? modelContext.save()
            AIRecallService.shared.registerUpdated(note, modelContext: modelContext)
            let changeSummary = changes.isEmpty ? "No fields changed" : "Updated: \(changes.joined(separator: ", "))"
            return AIActionResult(
                title: action.displayName,
                message: "Note updated",
                markdown: "✅ **Note updated**\n\nTitle: \(note.title)\n\n\(changeSummary)",
                details: [changeSummary],
                itemsAffected: 1,
                affectedObjectIDs: [note.id],
                metadata: action.metadata
            )
        
        case let .deleteNote(noteId):
            guard let note = fetchNote(by: noteId, context: modelContext) else {
                throw ExecutionError.notFound("Note not found")
            }
            let detail = "Title: \(note.title)"
            modelContext.delete(note)
            try? modelContext.save()
            AIRecallService.shared.removeObjects(withIDs: [noteId], modelContext: modelContext)
            return AIActionResult(
                title: action.displayName,
                message: "Note deleted",
                markdown: "🗑️ **Note deleted**\n\n\(detail)",
                details: [detail],
                itemsAffected: 1,
                affectedObjectIDs: [noteId],
                metadata: action.metadata
            )
        
        case let .addInboxItem(request):
            let item = PARAInboxItem(content: request.content, itemType: request.itemType)
            modelContext.insert(item)
            try? modelContext.save()
            return AIActionResult(
                title: action.displayName,
                message: "Inbox item added",
                markdown: "✅ **Inbox item added**\n\n\(request.content.prefix(200))",
                details: [request.content.prefix(80).description],
                itemsAffected: 1,
                affectedObjectIDs: [item.id],
                metadata: action.metadata
            )
        
        case let .convertInboxItem(request):
            guard let item = fetchInboxItem(by: request.itemId, context: modelContext) else {
                throw ExecutionError.notFound("Inbox item not found")
            }
            var affected: [UUID] = []
            var details: [String] = []
            switch request.target {
            case .task(let taskRequest):
                let task = PARATask(
                    title: taskRequest.title,
                    notes: taskRequest.notes ?? item.content,
                    status: taskRequest.status,
                    priority: taskRequest.priority,
                    dueDate: taskRequest.dueDate,
                    projectId: taskRequest.projectId,
                    areaId: taskRequest.areaId
                )
                modelContext.insert(task)
                affected.append(task.id)
                details.append("Converted to task \(task.title)")
                AIRecallService.shared.registerCreated(task, modelContext: modelContext)
                item.convertedToType = "task"
                item.convertedToId = task.id
            case .note(let noteRequest):
                let note = PARANote(
                    title: noteRequest.title,
                    markdown: noteRequest.body,
                    tags: noteRequest.tags
                )
                note.author = .user
                modelContext.insert(note)
                affected.append(note.id)
                details.append("Converted to note \(note.title)")
                AIRecallService.shared.registerCreated(note, modelContext: modelContext)
                item.convertedToType = "note"
                item.convertedToId = note.id
            case .draft(let postRequest):
                let draft = Draft(
                    caption: postRequest.caption,
                    mediaURLs: [],
                    tags: postRequest.tags,
                    notes: postRequest.notes
                )
                modelContext.insert(draft)
                affected.append(draft.id)
                details.append("Converted to draft \(draft.id.uuidString.prefix(8))")
                AIRecallService.shared.registerCreated(draft, modelContext: modelContext)
                item.convertedToType = "draft"
                item.convertedToId = draft.id
            }
            item.convertedAt = Date()
            try? modelContext.save()
            details.append("Inbox item marked as converted")
            return AIActionResult(
                title: action.displayName,
                message: "Inbox item converted",
                markdown: "✅ **Inbox item converted**\n\n\(details.joined(separator: "\n"))",
                details: details,
                itemsAffected: affected.count,
                affectedObjectIDs: affected,
                metadata: action.metadata
            )
        
        case let .createProject(request):
            let project = PARAProject(
                title: request.title,
                goal: request.goal,
                status: request.status,
                dueDate: request.dueDate,
                areaId: request.areaId,
                tags: request.tags
            )
            modelContext.insert(project)
            try? modelContext.save()
            AIRecallService.shared.registerCreated(project, modelContext: modelContext)
            let detail = summaryForProject(project)
            return AIActionResult(
                title: action.displayName,
                message: "Project created",
                markdown: "✅ **Project created**\n\n\(detail)",
                details: [detail],
                itemsAffected: 1,
                affectedObjectIDs: [project.id],
                metadata: action.metadata
            )
        
        case let .updateProject(request):
            guard let project = fetchProject(by: request.projectId, context: modelContext) else {
                throw ExecutionError.notFound("Project not found")
            }
            var changes: [String] = []
            if let title = request.title, !title.isEmpty, title != project.title {
                project.title = title
                changes.append("title")
            }
            if let goal = request.goal, goal != project.goal {
                project.goal = goal
                changes.append("goal")
            }
            if let status = request.status, status != project.status {
                project.status = status
                changes.append("status")
            }
            if let dueDate = request.dueDate {
                project.dueDate = dueDate
                changes.append("dueDate")
            }
            if let areaId = request.areaId {
                project.areaId = areaId
                changes.append("area")
            }
            if let tags = request.tags {
                project.tags = tags
                changes.append("tags")
            }
            project.updatedAt = Date()
            try? modelContext.save()
            AIRecallService.shared.registerUpdated(project, modelContext: modelContext)
            let detail = summaryForProject(project)
            let changeSummary = changes.isEmpty ? "No fields changed" : "Updated: \(changes.joined(separator: ", "))"
            return AIActionResult(
                title: action.displayName,
                message: "Project updated",
                markdown: "✅ **Project updated**\n\n\(detail)\n\n\(changeSummary)",
                details: [detail, changeSummary],
                itemsAffected: 1,
                affectedObjectIDs: [project.id],
                metadata: action.metadata
            )
        
        case let .deleteProject(projectId):
            guard let project = fetchProject(by: projectId, context: modelContext) else {
                throw ExecutionError.notFound("Project not found")
            }
            let detail = summaryForProject(project)
            detachProjectReferences(projectId: projectId, context: modelContext)
            modelContext.delete(project)
            try? modelContext.save()
            AIRecallService.shared.removeObjects(withIDs: [projectId], modelContext: modelContext)
            return AIActionResult(
                title: action.displayName,
                message: "Project deleted",
                markdown: "🗑️ **Project deleted**\n\n\(detail)",
                details: [detail],
                itemsAffected: 1,
                affectedObjectIDs: [projectId],
                metadata: action.metadata
            )
        
        case let .digestConversation(conversationId):
            guard let conversation = fetchConversation(by: conversationId, context: modelContext) else {
                throw ExecutionError.notFound("Conversation not found")
            }
            
            let digest = try await ConversationArchive.shared.digestConversation(conversation, modelContext: modelContext)
            
            return AIActionResult(
                title: action.displayName,
                message: "Conversation digested",
                markdown: "🧠 **Conversation Digested**\n\n**\(digest.title)**\n\nSummary: \(digest.summary)\n\nTopics: \(digest.keyTopics.joined(separator: ", "))",
                details: ["Conversation '\(digest.title)' has been analyzed and added to cross-conversation memory."],
                itemsAffected: 1,
                affectedObjectIDs: [conversationId],
                metadata: action.metadata
            )
        
        case .digestAllConversations:
            await ConversationArchive.shared.digestAllConversations(modelContext: modelContext)
            
            return AIActionResult(
                title: action.displayName,
                message: "All conversations digested",
                markdown: "🧠 **All Conversations Digested**\n\nAll past conversations have been analyzed and added to cross-conversation memory. I can now reference them when relevant.",
                details: ["Batch digestion of all conversations completed."],
                itemsAffected: 0,
                affectedObjectIDs: [],
                metadata: action.metadata
            )
        
        case let .searchConversations(query):
            let results = ConversationArchive.shared.searchConversations(query: query, limit: 5, modelContext: modelContext)
            
            if results.isEmpty {
                return AIActionResult(
                    title: action.displayName,
                    message: "No conversations found",
                    markdown: "🔍 **No conversations found** matching '\(query)'",
                    details: [],
                    itemsAffected: 0,
                    affectedObjectIDs: [],
                    metadata: action.metadata
                )
            }
            
            let resultLines = results.map { digest in
                "- **\(digest.title)** (\(digest.lastMessageDate.formatted(date: .abbreviated, time: .omitted)))\n  \(digest.summary)"
            }.joined(separator: "\n\n")
            
            return AIActionResult(
                title: action.displayName,
                message: "Found \(results.count) conversation\(results.count == 1 ? "" : "s")",
                markdown: "🔍 **Found \(results.count) conversation\(results.count == 1 ? "" : "s")** matching '\(query)':\n\n\(resultLines)",
                details: results.map { $0.displaySummary },
                itemsAffected: results.count,
                affectedObjectIDs: results.map { $0.conversationId },
                metadata: action.metadata
            )
        
        case let .createReminder(request):
            let reminder = CloutmateShared.Reminder(
                title: request.title,
                notes: request.notes,
                reminderDate: request.reminderDate,
                taskId: request.taskId,
                projectId: request.projectId
            )
            modelContext.insert(reminder)
            try? modelContext.save()
            
            // Schedule notification
            ReminderService.shared.scheduleReminder(reminder)
            
            // Register in recall system
            AIRecallService.shared.registerCreated(reminder, modelContext: modelContext)
            
            let detail = "Title: \(reminder.title)\nDate: \(reminder.reminderDate.formatted(date: .abbreviated, time: .shortened))"
            return AIActionResult(
                title: action.displayName,
                message: "Reminder created",
                markdown: "⏰ **Reminder created**\n\n\(detail)",
                details: [detail],
                itemsAffected: 1,
                affectedObjectIDs: [reminder.id],
                metadata: action.metadata
            )
        }
    }
}

// MARK: - Intent Conversion Helpers

extension AIIntentAction {
    init?(from executionIntent: ExecutionIntent) {
        switch executionIntent.operation {
        case .archiveTasks:
            let criteria = AIExecutionService.ArchiveCriteria(rawValue: executionIntent.criteria ?? "completed") ?? .completed
            self = .archiveTasks(
                criteria: criteria,
                daysAgo: executionIntent.daysAgo,
                projectId: nil
            )
        case .summarizePosts:
            let filter = AIExecutionService.PostFilter(rawValue: executionIntent.postFilter ?? "all") ?? .all
            self = .summarizePosts(
                filter: filter,
                filterValue: executionIntent.filterValue
            )
        case .generateReport:
            let type = AIExecutionService.ReportType(rawValue: executionIntent.reportType ?? "weekly") ?? .weekly
            self = .generateReport(type: type)
        case .predictScheduling:
            self = .predictScheduling(daysAhead: executionIntent.daysAhead)
        case .createPost:
            guard let caption = executionIntent.caption?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !caption.isEmpty else {
                return nil
            }
            let platformStrings = executionIntent.platforms ?? ["facebook"]
            let platforms = platformStrings.compactMap { Platform(rawValue: $0.lowercased()) }
            guard !platforms.isEmpty else { return nil }
            
            let scheduledDate = executionIntent.scheduledDate.flatMap { parseISODate($0) }
            let tags = executionIntent.tags ?? []
            let notes = executionIntent.notes
            let createDraft = executionIntent.createDraft ?? (executionIntent.draftId == nil)
            let draftId = executionIntent.draftId.flatMap(UUID.init(uuidString:))
            
            let request = PostCreationRequest(
                caption: caption,
                platforms: platforms,
                scheduledDate: scheduledDate,
                tags: tags,
                notes: notes,
                createDraft: createDraft,
                draftId: draftId
            )
            self = .createPost(request)
        case .publishPost:
            guard let postIdString = executionIntent.postId,
                  let postId = UUID(uuidString: postIdString) else {
                return nil
            }
            let publishRequest = PostPublishRequest(postId: postId, notes: executionIntent.publishNotes)
            self = .publishPost(publishRequest)
        case .createTask:
            guard let title = executionIntent.taskTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !title.isEmpty else {
                return nil
            }
            let status = mapTaskStatus(executionIntent.taskStatus) ?? .todo
            let priority = mapTaskPriority(executionIntent.taskPriority) ?? .medium
            let projectId = executionIntent.taskProjectId.flatMap(UUID.init(uuidString:))
            let areaId = executionIntent.taskAreaId.flatMap(UUID.init(uuidString:))
            let dueDate = executionIntent.taskDueDate.flatMap { parseISODate($0) }
            let request = TaskCreationRequest(
                title: title,
                notes: executionIntent.taskNotes,
                dueDate: dueDate,
                status: status,
                priority: priority,
                projectId: projectId,
                areaId: areaId
            )
            self = .createTask(request)
        case .updateTask:
            guard let taskIdString = executionIntent.taskId,
                  let taskId = UUID(uuidString: taskIdString) else {
                return nil
            }
            let request = TaskUpdateRequest(
                taskId: taskId,
                title: executionIntent.taskTitle,
                notes: executionIntent.taskNotes,
                dueDate: executionIntent.taskDueDate.flatMap { parseISODate($0) },
                status: mapTaskStatus(executionIntent.taskStatus),
                priority: mapTaskPriority(executionIntent.taskPriority),
                projectId: executionIntent.taskProjectId.flatMap(UUID.init(uuidString:)),
                areaId: executionIntent.taskAreaId.flatMap(UUID.init(uuidString:))
            )
            self = .updateTask(request)
        case .deleteTask:
            guard let taskIdString = executionIntent.taskId,
                  let taskId = UUID(uuidString: taskIdString) else {
                return nil
            }
            self = .deleteTask(taskId)
        case .createNote:
            guard let title = executionIntent.noteTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !title.isEmpty else { return nil }
            let body = executionIntent.noteBody ?? ""
            let tags = executionIntent.noteTags ?? []
            let request = NoteMutationRequest(noteId: nil, title: title, body: body, tags: tags)
            self = .createNote(request)
        case .updateNote:
            guard let noteIdString = executionIntent.noteId,
                  let noteId = UUID(uuidString: noteIdString) else { return nil }
            let request = NoteUpdateRequest(
                noteId: noteId,
                title: executionIntent.noteTitle,
                body: executionIntent.noteBody,
                tags: executionIntent.noteTags
            )
            self = .updateNote(request)
        case .deleteNote:
            guard let noteIdString = executionIntent.noteId,
                  let noteId = UUID(uuidString: noteIdString) else { return nil }
            self = .deleteNote(noteId)
        case .addInboxItem:
            guard let content = executionIntent.inboxContent,
                  !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            let itemType = executionIntent.inboxType ?? "text"
            let request = InboxAdditionRequest(content: content, itemType: itemType)
            self = .addInboxItem(request)
        case .convertInboxItem:
            guard let itemIdString = executionIntent.inboxItemId,
                  let itemId = UUID(uuidString: itemIdString),
                  let targetString = executionIntent.conversionTarget?.lowercased() else {
                return nil
            }
            let taskRequest = TaskCreationRequest(
                title: executionIntent.taskTitle ?? (executionIntent.inboxContent ?? "New Task"),
                notes: executionIntent.taskNotes ?? executionIntent.inboxContent,
                dueDate: executionIntent.taskDueDate.flatMap { parseISODate($0) },
                status: mapTaskStatus(executionIntent.taskStatus) ?? .todo,
                priority: mapTaskPriority(executionIntent.taskPriority) ?? .medium,
                projectId: executionIntent.taskProjectId.flatMap(UUID.init(uuidString:)),
                areaId: executionIntent.taskAreaId.flatMap(UUID.init(uuidString:))
            )
            let noteRequest = NoteMutationRequest(
                noteId: nil,
                title: executionIntent.noteTitle ?? "Captured Note",
                body: executionIntent.noteBody ?? (executionIntent.inboxContent ?? ""),
                tags: executionIntent.noteTags ?? []
            )
            let postRequest = PostCreationRequest(
                caption: executionIntent.caption ?? (executionIntent.inboxContent ?? ""),
                platforms: (executionIntent.platforms ?? ["facebook"]).compactMap { Platform(rawValue: $0.lowercased()) },
                scheduledDate: executionIntent.scheduledDate.flatMap { parseISODate($0) },
                tags: executionIntent.tags ?? [],
                notes: executionIntent.notes,
                createDraft: true,
                draftId: nil
            )
            let target: InboxConversionTarget
            switch targetString {
            case "task":
                target = .task(taskRequest)
            case "note":
                target = .note(noteRequest)
            case "draft", "post":
                let platforms = postRequest.platforms.isEmpty ? [Platform.facebook] : postRequest.platforms
                let adjusted = PostCreationRequest(
                    caption: postRequest.caption,
                    platforms: platforms,
                    scheduledDate: postRequest.scheduledDate,
                    tags: postRequest.tags,
                    notes: postRequest.notes,
                    createDraft: true,
                    draftId: nil
                )
                target = .draft(adjusted)
            default:
                return nil
            }
            let request = InboxConversionRequest(itemId: itemId, target: target)
            self = .convertInboxItem(request)
        case .createProject:
            guard let title = executionIntent.projectTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !title.isEmpty else { return nil }
            let status = mapProjectStatus(executionIntent.projectStatus) ?? .active
            let request = ProjectCreationRequest(
                title: title,
                goal: executionIntent.projectGoal,
                status: status,
                dueDate: executionIntent.projectDueDate.flatMap { parseISODate($0) },
                areaId: executionIntent.projectAreaId.flatMap(UUID.init(uuidString:)),
                tags: executionIntent.tags ?? []
            )
            self = .createProject(request)
        case .updateProject:
            guard let projectIdString = executionIntent.projectId,
                  let projectId = UUID(uuidString: projectIdString) else { return nil }
            let request = ProjectUpdateRequest(
                projectId: projectId,
                title: executionIntent.projectTitle,
                goal: executionIntent.projectGoal,
                status: mapProjectStatus(executionIntent.projectStatus),
                dueDate: executionIntent.projectDueDate.flatMap { parseISODate($0) },
                areaId: executionIntent.projectAreaId.flatMap(UUID.init(uuidString:)),
                tags: executionIntent.tags
            )
            self = .updateProject(request)
        case .deleteProject:
            guard let projectIdString = executionIntent.projectId,
                  let projectId = UUID(uuidString: projectIdString) else { return nil }
            self = .deleteProject(projectId)
        case .digestConversation:
            guard let conversationIdString = executionIntent.conversationId,
                  let conversationId = UUID(uuidString: conversationIdString) else { return nil }
            self = .digestConversation(conversationId)
        case .digestAllConversations:
            self = .digestAllConversations
        case .searchConversations:
            guard let query = executionIntent.searchQuery,
                  !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            self = .searchConversations(query: query)
        case .createReminder:
            guard let title = executionIntent.reminderTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !title.isEmpty,
                  let dateString = executionIntent.reminderDate ?? executionIntent.reminderTime else {
                return nil
            }
            // Parse date/time - simplified for now, assume ISO8601 or relative date
            let reminderDate: Date
            if let parsedDate = parseISODate(dateString) {
                reminderDate = parsedDate
            } else {
                // Fallback to current date + 1 hour if parsing fails
                reminderDate = Date().addingTimeInterval(3600)
            }
            let taskId = executionIntent.reminderTaskId.flatMap(UUID.init(uuidString:))
            let projectId = executionIntent.reminderProjectId.flatMap(UUID.init(uuidString:))
            let request = ReminderCreationRequest(
                title: title,
                notes: executionIntent.reminderNotes,
                reminderDate: reminderDate,
                taskId: taskId,
                projectId: projectId
            )
            self = .createReminder(request)
        }
    }
    
    // MARK: - Entity Resolution
    
    /// Resolve a mention text to an entity (type, ID, display name)
    /// Used for @mention linking and deep linking
    func resolveEntity(mentionText: String, modelContext: ModelContext) -> (type: ObjectType, id: UUID, displayName: String)? {
        let searchResults = WorkspaceObjectSearchService.shared.search(
            query: mentionText,
            modelContext: modelContext,
            limit: 1
        )
        
        guard let firstResult = searchResults.first else {
            return nil
        }
        
        return (
            type: firstResult.type,
            id: firstResult.id,
            displayName: firstResult.title
        )
    }
}

// MARK: - Helpers

private func fetchTask(by id: UUID, context: ModelContext) -> PARATask? {
    var descriptor = FetchDescriptor<PARATask>(
        predicate: #Predicate { $0.id == id }
    )
    descriptor.fetchLimit = 1
    return try? context.fetch(descriptor).first
}

private func fetchNote(by id: UUID, context: ModelContext) -> PARANote? {
    var descriptor = FetchDescriptor<PARANote>(
        predicate: #Predicate { $0.id == id }
    )
    descriptor.fetchLimit = 1
    return try? context.fetch(descriptor).first
}

private func fetchPost(by id: UUID, context: ModelContext) -> Post? {
    var descriptor = FetchDescriptor<Post>(
        predicate: #Predicate { $0.id == id }
    )
    descriptor.fetchLimit = 1
    return try? context.fetch(descriptor).first
}

private func fetchInboxItem(by id: UUID, context: ModelContext) -> PARAInboxItem? {
    var descriptor = FetchDescriptor<PARAInboxItem>(
        predicate: #Predicate { $0.id == id }
    )
    descriptor.fetchLimit = 1
    return try? context.fetch(descriptor).first
}

private func fetchProject(by id: UUID, context: ModelContext) -> PARAProject? {
    var descriptor = FetchDescriptor<PARAProject>(
        predicate: #Predicate { $0.id == id }
    )
    descriptor.fetchLimit = 1
    return try? context.fetch(descriptor).first
}

private func fetchConversation(by id: UUID, context: ModelContext) -> AIConversation? {
    var descriptor = FetchDescriptor<AIConversation>(
        predicate: #Predicate { $0.id == id }
    )
    descriptor.fetchLimit = 1
    return try? context.fetch(descriptor).first
}

private func summaryForTask(_ task: PARATask) -> String {
    var parts: [String] = ["Title: \(task.title)"]
    parts.append("Status: \(task.status.displayName)")
    parts.append("Priority: \(task.priority.displayName)")
    if let due = task.dueDate {
        parts.append("Due: \(formattedDateTime(due))")
    }
    return parts.joined(separator: " | ")
}

private func summaryForProject(_ project: PARAProject) -> String {
    var parts: [String] = ["Title: \(project.title)"]
    parts.append("Status: \(project.status.displayName)")
    if let goal = project.goal, !goal.isEmpty {
        parts.append("Goal: \(goal)")
    }
    if let due = project.dueDate {
        parts.append("Due: \(formattedDateTime(due))")
    }
    return parts.joined(separator: " | ")
}

private func detachProjectReferences(projectId: UUID, context: ModelContext) {
    let projectIdCopy = projectId
    let taskDescriptor = FetchDescriptor<PARATask>(
        predicate: #Predicate { $0.projectId == projectIdCopy }
    )
    if let tasks = try? context.fetch(taskDescriptor) {
        for task in tasks {
            task.projectId = nil
            task.updatedAt = Date()
        }
    }
    let postDescriptor = FetchDescriptor<Post>(
        predicate: #Predicate { $0.projectId == projectIdCopy }
    )
    if let posts = try? context.fetch(postDescriptor) {
        for post in posts {
            post.projectId = nil
            post.updatedAt = Date()
        }
    }
    let noteDescriptor = FetchDescriptor<PARANote>(
        predicate: #Predicate { $0.projectId == projectIdCopy }
    )
    if let notes = try? context.fetch(noteDescriptor) {
        for note in notes {
            note.projectId = nil
            note.updatedAt = Date()
        }
    }
}

private func mapTaskStatus(_ raw: String?) -> CloutmateShared.TaskStatus? {
    guard let raw = raw?.lowercased() else { return nil }
    switch raw {
    case "todo": return .todo
    case "inprogress", "in_progress", "doing": return .inProgress
    case "done", "completed": return .done
    case "cancelled", "canceled": return .cancelled
    default: return nil
    }
}

private func mapTaskPriority(_ raw: String?) -> CloutmateShared.TaskPriority? {
    guard let raw = raw?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
    
    // Handle variations like "high priority", "set to high", "with a high priority"
    let cleaned = raw
        .replacingOccurrences(of: "priority", with: "")
        .replacingOccurrences(of: "priroty", with: "") // Handle typo
        .replacingOccurrences(of: "set to", with: "")
        .replacingOccurrences(of: "to", with: "")
        .replacingOccurrences(of: "with a", with: "")
        .replacingOccurrences(of: "with", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    
    switch cleaned {
    case "low": return .low
    case "medium", "normal", "med": return .medium
    case "high", "hi": return .high
    default: return nil
    }
}

private func mapProjectStatus(_ raw: String?) -> CloutmateShared.ProjectStatus? {
    guard let raw = raw?.lowercased() else { return nil }
    switch raw {
    case "active": return .active
    case "paused", "on_hold": return .paused
    case "completed", "done": return .completed
    default: return nil
    }
}

private func parseISODate(_ raw: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: raw) {
        return date
    }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: raw)
}

private func formattedDateTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

private func isoString(from date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.string(from: date)
}

private func fetchDraft(by id: UUID, context: ModelContext) -> Draft? {
    var descriptor = FetchDescriptor<Draft>(
        predicate: #Predicate { $0.id == id }
    )
    descriptor.fetchLimit = 1
    return try? context.fetch(descriptor).first
}
