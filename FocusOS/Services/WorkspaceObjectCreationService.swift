//
//  WorkspaceObjectCreationService.swift
//  FocusOS
//
//  Centralized workspace creation executor. Handles multi-object flows,
//  verifies persistence, and ensures MemoryGraph stays in sync.
//

import Foundation
import SwiftData
import FocusOSShared

@MainActor
final class WorkspaceObjectCreationService {
    static let shared = WorkspaceObjectCreationService()

    struct CreationResult {
        let createdObjectIDs: [UUID]
        let primaryObjectID: UUID?
        let objectType: ParsedIntent.ObjectType
    }

    enum CreationError: LocalizedError {
        case missingTitle(ParsedIntent.ObjectType)
        case verificationFailed(ParsedIntent.ObjectType)
        case unsupportedOperation

        var errorDescription: String? {
            switch self {
            case .missingTitle(let type):
                return "I need a \(type.rawValue) name to continue."
            case .verificationFailed(let type):
                return "I couldn't verify the new \(type.rawValue). Try again."
            case .unsupportedOperation:
                return "That action isn't supported yet."
            }
        }
    }

    private let actionRouter = AIActionRouter.shared
    private let coreResponseService = CoreResponseService.shared
    private let memoryGraphService = MemoryGraphService.shared
    private let recallService = AIRecallService.shared

    private init() {}

    func executeCreation(
        intent: ParsedIntent,
        modelContext: ModelContext
    ) async throws -> CreationResult {
        switch intent.object {
        case .project:
            return try await createProject(intent: intent, modelContext: modelContext)
        case .note:
            return try await createNote(intent: intent, modelContext: modelContext)
        case .post:
            return try await createPost(intent: intent, modelContext: modelContext)
        case .reminder:
            return try await createReminder(intent: intent, modelContext: modelContext)
        case .artifact:
            return try await createArtifact(intent: intent, modelContext: modelContext)
        case .task:
            return try await createTask(intent: intent, modelContext: modelContext)
        default:
            throw CreationError.unsupportedOperation
        }
    }

    // MARK: - Project Flow

    private func createProject(
        intent: ParsedIntent,
        modelContext: ModelContext
    ) async throws -> CreationResult {
        let executionIntent = intent.executionIntent
        guard let rawTitle = executionIntent.projectTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawTitle.isEmpty else {
            throw CreationError.missingTitle(.project)
        }

        let status = mapProjectStatus(executionIntent.projectStatus) ?? .active
        let dueDate = DateParsing.parse(executionIntent.projectDueDate)
        let areaId = executionIntent.projectAreaId.flatMap(UUID.init(uuidString:))
        let tags = executionIntent.tags ?? []
        let projectRequest = ProjectCreationRequest(
            title: rawTitle,
            goal: executionIntent.projectGoal,
            status: status,
            dueDate: dueDate,
            areaId: areaId,
            tags: tags
        )

        let projectAction = AIIntentAction.createProject(projectRequest)
        let projectResult = try await actionRouter.route(projectAction, modelContext: modelContext)
        guard let projectId = projectResult.affectedObjectIDs.first,
              let project = fetchProject(projectId, modelContext: modelContext) else {
            throw CreationError.verificationFailed(.project)
        }

        recallService.registerCreated(project, modelContext: modelContext)
        await memoryGraphService.syncOnCreate(object: project, modelContext: modelContext)

        var createdIDs: [UUID] = [projectId]

        if executionIntent.createTasksWithProject == true
            || executionIntent.taskTitles != nil
            || executionIntent.taskCount != nil {
            let taskIDs = try await createTasks(
                baseTitle: rawTitle,
                requestNotes: executionIntent.taskNotes,
                executionIntent: executionIntent,
                projectId: projectId,
                modelContext: modelContext
            )
            createdIDs.append(contentsOf: taskIDs)
        }

        if executionIntent.createNotesWithProject == true
            || executionIntent.noteTitles != nil
            || executionIntent.noteCount != nil {
            let noteIDs = try await createNotes(
                baseTitle: rawTitle,
                body: executionIntent.noteBody,
                tags: executionIntent.noteTags ?? [],
                executionIntent: executionIntent,
                projectId: projectId,
                modelContext: modelContext
            )
            createdIDs.append(contentsOf: noteIDs)
        }

        if executionIntent.createPostsWithProject == true
            || executionIntent.postCaptions != nil
            || executionIntent.postCount != nil {
            let postIDs = try await createPosts(
                baseTitle: rawTitle,
                executionIntent: executionIntent,
                projectId: projectId,
                modelContext: modelContext
            )
            createdIDs.append(contentsOf: postIDs)
        }

        try modelContext.save()
        return CreationResult(createdObjectIDs: createdIDs, primaryObjectID: projectId, objectType: .project)
    }

    // MARK: - Note Flow

    private func createNote(
        intent: ParsedIntent,
        modelContext: ModelContext
    ) async throws -> CreationResult {
        let executionIntent = intent.executionIntent
        guard let noteTitle = executionIntent.noteTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
              !noteTitle.isEmpty else {
            throw CreationError.missingTitle(.note)
        }

        typealias WorkspaceNote = FocusOSShared.Note
        let note = WorkspaceNote(
            title: noteTitle,
            markdown: executionIntent.noteBody ?? "",
            tags: executionIntent.noteTags ?? []
        )
        note.author = .aurora
        modelContext.insert(note)
        try modelContext.save()
        recallService.registerCreated(note, modelContext: modelContext)
        await memoryGraphService.syncOnCreate(object: note, modelContext: modelContext)

        var createdIDs: [UUID] = [note.id]

        if executionIntent.createTasksWithNote == true
            || executionIntent.taskTitles != nil
            || executionIntent.taskCount != nil {
            let taskIDs = try await createTasks(
                baseTitle: noteTitle,
                requestNotes: "From note: \(noteTitle)",
                executionIntent: executionIntent,
                projectId: executionIntent.taskProjectId.flatMap(UUID.init(uuidString:)),
                modelContext: modelContext
            )
            createdIDs.append(contentsOf: taskIDs)
            note.backlinks.append(contentsOf: taskIDs)
        }

        if executionIntent.createPostsWithNote == true
            || executionIntent.postCaptions != nil
            || executionIntent.postCount != nil {
            let postIDs = try await createPosts(
                baseTitle: noteTitle,
                executionIntent: executionIntent,
                projectId: executionIntent.taskProjectId.flatMap(UUID.init(uuidString:)),
                modelContext: modelContext
            )
            createdIDs.append(contentsOf: postIDs)
        }

        try modelContext.save()
        return CreationResult(createdObjectIDs: createdIDs, primaryObjectID: note.id, objectType: .note)
    }

    // MARK: - Post Flow

    private func createPost(
        intent: ParsedIntent,
        modelContext: ModelContext
    ) async throws -> CreationResult {
        let executionIntent = intent.executionIntent
        let caption = executionIntent.caption ?? executionIntent.postCaptions?.first
        guard let caption = caption?.trimmingCharacters(in: .whitespacesAndNewlines),
              !caption.isEmpty else {
            throw CreationError.missingTitle(.post)
        }

        let scheduledDate = executionIntent.scheduledDate.flatMap(DateParsing.parse)
        let request = PostCreationRequest(
            caption: caption,
            scheduledDate: scheduledDate,
            tags: executionIntent.tags ?? [],
            notes: executionIntent.notes,
            createDraft: executionIntent.createDraft ?? false,
            draftId: nil
        )
        let postAction = AIIntentAction.createPost(request)
        let postResult = try await actionRouter.route(postAction, modelContext: modelContext)
        guard let postId = postResult.affectedObjectIDs.first,
              let post = fetchPost(postId, modelContext: modelContext) else {
            throw CreationError.verificationFailed(.post)
        }

        recallService.registerCreated(post, modelContext: modelContext)
        await memoryGraphService.syncOnCreate(object: post, modelContext: modelContext)

        var createdIDs: [UUID] = [postId]

        if executionIntent.createTasksWithPost == true
            || executionIntent.taskTitles != nil
            || executionIntent.taskCount != nil {
            let taskIDs = try await createTasks(
                baseTitle: caption,
                requestNotes: executionIntent.taskNotes,
                executionIntent: executionIntent,
                projectId: executionIntent.taskProjectId.flatMap(UUID.init(uuidString:)),
                modelContext: modelContext
            )
            createdIDs.append(contentsOf: taskIDs)
        }

        if executionIntent.createNotesWithPost == true
            || executionIntent.noteTitles != nil
            || executionIntent.noteCount != nil {
            let noteIDs = try await createNotes(
                baseTitle: caption,
                body: executionIntent.noteBody,
                tags: executionIntent.noteTags ?? [],
                executionIntent: executionIntent,
                projectId: executionIntent.taskProjectId.flatMap(UUID.init(uuidString:)),
                modelContext: modelContext
            )
            createdIDs.append(contentsOf: noteIDs)
        }

        return CreationResult(createdObjectIDs: createdIDs, primaryObjectID: postId, objectType: .post)
    }

    // MARK: - Reminder Flow

    private func createReminder(
        intent: ParsedIntent,
        modelContext: ModelContext
    ) async throws -> CreationResult {
        let executionIntent = intent.executionIntent
        guard let reminderTitle = executionIntent.reminderTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
              !reminderTitle.isEmpty else {
            throw CreationError.missingTitle(.reminder)
        }

        let reminderDate = resolveReminderDate(from: executionIntent)
        let request = ReminderCreationRequest(
            title: reminderTitle,
            notes: executionIntent.reminderNotes ?? executionIntent.notes,
            reminderDate: reminderDate,
            taskId: executionIntent.reminderTaskId.flatMap(UUID.init(uuidString:)),
            projectId: executionIntent.reminderProjectId.flatMap(UUID.init(uuidString:))
        )
        let reminderAction = AIIntentAction.createReminder(request)
        let reminderResult = try await actionRouter.route(reminderAction, modelContext: modelContext)
        guard let reminderId = reminderResult.affectedObjectIDs.first,
              let reminder = fetchReminder(reminderId, modelContext: modelContext) else {
            throw CreationError.verificationFailed(.reminder)
        }

        recallService.registerCreated(reminder, modelContext: modelContext)
        await memoryGraphService.syncOnCreate(object: reminder, modelContext: modelContext)

        return CreationResult(createdObjectIDs: [reminderId], primaryObjectID: reminderId, objectType: .reminder)
    }

    // MARK: - Artifact Flow

    private func createArtifact(
        intent: ParsedIntent,
        modelContext: ModelContext
    ) async throws -> CreationResult {
        let executionIntent = intent.executionIntent
        guard let rawTitle = executionIntent.artifactTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawTitle.isEmpty else {
            throw CreationError.missingTitle(.artifact)
        }

        let artifactFormat = mapOutputFormat(executionIntent.artifactFormat)
        let artifactState = mapArtifactState(executionIntent.artifactState)
        let projectId = executionIntent.artifactProjectId.flatMap(UUID.init(uuidString:))
        let areaId = executionIntent.artifactAreaId.flatMap(UUID.init(uuidString:))
        let creationRequest = ArtifactCreationRequest(
            title: rawTitle,
            content: executionIntent.artifactContent ?? executionIntent.notes,
            format: artifactFormat,
            state: artifactState,
            tags: executionIntent.artifactTags ?? [],
            projectId: projectId,
            areaId: areaId,
            auroraNotes: executionIntent.artifactNotes ?? executionIntent.notes
        )
        let artifactAction = AIIntentAction.createArtifact(creationRequest)
        let artifactResult = try await actionRouter.route(artifactAction, modelContext: modelContext)
        guard let artifactId = artifactResult.affectedObjectIDs.first,
              let artifact = fetchArtifact(artifactId, modelContext: modelContext) else {
            throw CreationError.verificationFailed(.artifact)
        }

        recallService.registerCreated(artifact, modelContext: modelContext)
        await memoryGraphService.syncOnCreate(object: artifact, modelContext: modelContext)

        return CreationResult(createdObjectIDs: [artifactId], primaryObjectID: artifactId, objectType: .artifact)
    }

    // MARK: - Task Flow

    private func createTask(
        intent: ParsedIntent,
        modelContext: ModelContext
    ) async throws -> CreationResult {
        let executionIntent = intent.executionIntent
        guard let taskTitle = executionIntent.taskTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
              !taskTitle.isEmpty else {
            throw CreationError.missingTitle(.task)
        }

        let taskRequest = TaskCreationRequest(
            title: taskTitle,
            notes: executionIntent.taskNotes ?? executionIntent.notes,
            dueDate: DateParsing.parse(executionIntent.taskDueDate),
            status: mapTaskStatus(executionIntent.taskStatus) ?? .todo,
            priority: mapTaskPriority(executionIntent.taskPriority) ?? .medium,
            projectId: executionIntent.taskProjectId.flatMap(UUID.init(uuidString:)),
            areaId: executionIntent.taskAreaId.flatMap(UUID.init(uuidString:))
        )
        let taskAction = AIIntentAction.createTask(taskRequest)
        let taskResult = try await actionRouter.route(taskAction, modelContext: modelContext)
        guard let taskId = taskResult.affectedObjectIDs.first,
              let task = fetchTask(taskId, modelContext: modelContext) else {
            throw CreationError.verificationFailed(.task)
        }

        recallService.registerCreated(task, modelContext: modelContext)
        await memoryGraphService.syncOnCreate(object: task, modelContext: modelContext)

        return CreationResult(createdObjectIDs: [taskId], primaryObjectID: taskId, objectType: .task)
    }

    // MARK: - Helpers

    private func createTasks(
        baseTitle: String,
        requestNotes: String?,
        executionIntent: ExecutionIntent,
        projectId: UUID?,
        modelContext: ModelContext
    ) async throws -> [UUID] {
        var titles = executionIntent.taskTitles ?? []
        if titles.isEmpty, let taskCount = executionIntent.taskCount, taskCount > 0 {
            let prompt = """
            Generate \(taskCount) specific, actionable task titles for "\(baseTitle)".
            Return ONLY a JSON array of task titles.
            """
            titles = await generateList(from: prompt, fallbackPrefix: "Task", count: taskCount, subject: baseTitle)
        }

        let status = mapTaskStatus(executionIntent.taskStatus) ?? .todo
        let priority = mapTaskPriority(executionIntent.taskPriority) ?? .medium
        let dueDate = DateParsing.parse(executionIntent.taskDueDate)
        let areaId = executionIntent.taskAreaId.flatMap(UUID.init(uuidString:))

        var created: [UUID] = []
        for title in titles {
            let request = TaskCreationRequest(
                title: title,
                notes: requestNotes,
                dueDate: dueDate,
                status: status,
                priority: priority,
                projectId: projectId,
                areaId: areaId
            )
            do {
                let action = AIIntentAction.createTask(request)
                let result = try await actionRouter.route(action, modelContext: modelContext)
                if let id = result.affectedObjectIDs.first,
                   let task = fetchTask(id, modelContext: modelContext) {
                    created.append(id)
                    recallService.registerCreated(task, modelContext: modelContext)
                    await memoryGraphService.syncOnCreate(object: task, modelContext: modelContext)
                }
            } catch {
                print("Failed to create task \(title): \(error)")
            }
        }
        return created
    }

    private func createNotes(
        baseTitle: String,
        body: String?,
        tags: [String],
        executionIntent: ExecutionIntent,
        projectId: UUID?,
        modelContext: ModelContext
    ) async throws -> [UUID] {
        var titles = executionIntent.noteTitles ?? []
        if titles.isEmpty, let noteCount = executionIntent.noteCount, noteCount > 0 {
            let prompt = """
            Generate \(noteCount) specific note titles for "\(baseTitle)".
            Return ONLY a JSON array of note titles.
            """
            titles = await generateList(from: prompt, fallbackPrefix: "Note", count: noteCount, subject: baseTitle)
        }

        var created: [UUID] = []
        for title in titles {
            typealias WorkspaceNote = FocusOSShared.Note
            let note = WorkspaceNote(title: title, markdown: body ?? "", tags: tags)
            note.author = .aurora
            note.projectId = projectId
            modelContext.insert(note)
            do {
                try modelContext.save()
                recallService.registerCreated(note, modelContext: modelContext)
                await memoryGraphService.syncOnCreate(object: note, modelContext: modelContext)
                created.append(note.id)
            } catch {
                print("Failed to save generated note: \(error)")
            }
        }
        return created
    }

    private func createPosts(
        baseTitle: String,
        executionIntent: ExecutionIntent,
        projectId: UUID?,
        modelContext: ModelContext
    ) async throws -> [UUID] {
        var captions = executionIntent.postCaptions ?? []
        if captions.isEmpty, let postCount = executionIntent.postCount, postCount > 0 {
            let prompt = """
            Generate \(postCount) short social captions inspired by "\(baseTitle)".
            Return ONLY a JSON array of captions.
            """
            captions = await generateList(from: prompt, fallbackPrefix: baseTitle, count: postCount, subject: baseTitle)
        }

        var created: [UUID] = []
        for caption in captions {
            let request = PostCreationRequest(
                caption: caption,
                scheduledDate: executionIntent.scheduledDate.flatMap(DateParsing.parse),
                tags: executionIntent.tags ?? [],
                notes: executionIntent.notes,
                createDraft: executionIntent.createDraft ?? false,
                draftId: nil
            )
            do {
                let action = AIIntentAction.createPost(request)
                let result = try await actionRouter.route(action, modelContext: modelContext)
                if let id = result.affectedObjectIDs.first,
                   let post = fetchPost(id, modelContext: modelContext) {
                    created.append(id)
                    recallService.registerCreated(post, modelContext: modelContext)
                    await memoryGraphService.syncOnCreate(object: post, modelContext: modelContext)
                }
            } catch {
                print("Failed to create generated post: \(error)")
            }
        }
        return created
    }

    private func generateList(
        from prompt: String,
        fallbackPrefix: String,
        count: Int,
        subject: String
    ) async -> [String] {
        do {
            let response = try await coreResponseService.generateResponse(for: prompt)
            let cleaned = response
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let data = cleaned.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String],
               !json.isEmpty {
                return json
            }
        } catch {
            print("Generation failed: \(error)")
        }
        return (1...count).map { "\(fallbackPrefix) \($0) for \(subject)" }
    }

    private func resolveReminderDate(from intent: ExecutionIntent) -> Date {
        if let reminderDate = intent.reminderDate, let parsed = DateParsing.parse(reminderDate) {
            if let reminderTime = intent.reminderTime {
                return combine(date: parsed, withTimeString: reminderTime) ?? parsed
            }
            return parsed
        }
        if let reminderTime = intent.reminderTime {
            return combine(date: Date(), withTimeString: reminderTime) ?? Date()
        }
        return Date()
    }

    private func combine(date: Date, withTimeString timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        if let time = formatter.date(from: timeString.lowercased()) {
            let components = Calendar.current.dateComponents([.hour, .minute], from: time)
            return Calendar.current.date(
                bySettingHour: components.hour ?? 9,
                minute: components.minute ?? 0,
                second: 0,
                of: date
            )
        }
        formatter.dateFormat = "HH:mm"
        if let time = formatter.date(from: timeString) {
            let components = Calendar.current.dateComponents([.hour, .minute], from: time)
            return Calendar.current.date(
                bySettingHour: components.hour ?? 9,
                minute: components.minute ?? 0,
                second: 0,
                of: date
            )
        }
        return nil
    }

    private func fetchProject(_ id: UUID, modelContext: ModelContext) -> Project? {
        var descriptor = FetchDescriptor<Project>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchTask(_ id: UUID, modelContext: ModelContext) -> FocusOSShared.Task? {
        var descriptor = FetchDescriptor<FocusOSShared.Task>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchPost(_ id: UUID, modelContext: ModelContext) -> Post? {
        var descriptor = FetchDescriptor<Post>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchReminder(_ id: UUID, modelContext: ModelContext) -> Reminder? {
        var descriptor = FetchDescriptor<Reminder>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchArtifact(_ id: UUID, modelContext: ModelContext) -> Artifact? {
        var descriptor = FetchDescriptor<Artifact>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func mapTaskStatus(_ raw: String?) -> TaskStatus? {
        guard let raw = raw?.lowercased() else { return nil }
        switch raw {
        case "todo": return .todo
        case "inprogress", "in_progress", "doing": return .inProgress
        case "done", "completed": return .done
        case "cancelled", "canceled": return .cancelled
        default: return nil
        }
    }

    private func mapTaskPriority(_ raw: String?) -> TaskPriority? {
        guard let raw = raw?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        switch raw {
        case "low": return .low
        case "medium", "normal", "med": return .medium
        case "high", "urgent", "hi": return .high
        default: return nil
        }
    }

    private func mapProjectStatus(_ raw: String?) -> ProjectStatus? {
        guard let raw = raw?.lowercased() else { return nil }
        switch raw {
        case "active": return .active
        case "paused": return .paused
        case "completed", "complete": return .completed
        default: return nil
        }
    }

    private func mapOutputFormat(_ raw: String?) -> OutputFormat {
        guard let raw = raw, !raw.isEmpty else { return .brief }
        switch raw.lowercased() {
        case "brief": return .brief
        case "summary": return .summary
        case "reflection": return .reflection
        case "report": return .report
        case "releasenote", "release_note", "release note": return .releaseNote
        case "lessonlearned", "lesson_learned", "lesson learned", "lessonslearned", "lessons learned": return .lessonLearned
        default:
            return .brief
        }
    }

    private func mapArtifactState(_ raw: String?) -> ArtifactState {
        guard let raw = raw?.lowercased() else { return .draft }
        return ArtifactState(rawValue: raw) ?? .draft
    }
}
