//
//  IntentParserService.swift
//  FocusOS
//
//  Deterministic parser that converts any creation prompt into a structured,
//  cached ParsedIntent. All workspace actions should run through this service
//  so retries can safely reuse the same intent.
//

import Foundation
import SwiftData
import CryptoKit
import FocusOSShared

struct ParsedIntent: Sendable {
    enum ActionType: String, Sendable {
        case create
        case update
        case delete
        case rename
        case status
        case lookup
        case respond
        case unknown
    }

    enum ObjectType: String, Sendable {
        case project
        case task
        case note
        case post
        case reminder
        case artifact
        case conversation
        case inbox
        case generic
    }

    struct ObjectReference: Hashable, Sendable {
        let objectId: UUID
        let name: String
        let type: ObjectType
    }

    struct Metadata: Sendable {
        var dueDate: Date?
        var tags: [String]
        var priority: TaskPriority?
        var status: TaskStatus?
        var areaId: UUID?
        var projectId: UUID?
        var noteId: UUID?
        var reminderDate: Date?
        var secondaryItemCount: Int
        var resolvedObjects: [ObjectReference]
        var missingObjects: [String]
        var notes: String?
    }

    let id: UUID
    let cacheKey: String
    let sourceText: String
    let action: ActionType
    let object: ObjectType
    var primaryName: String?
    var secondaryItems: [String]
    var metadata: Metadata
    var executionIntent: ExecutionIntent
    var selectedModel: String?

    init(
        cacheKey: String,
        sourceText: String,
        action: ActionType,
        object: ObjectType,
        primaryName: String?,
        secondaryItems: [String],
        metadata: Metadata,
        executionIntent: ExecutionIntent,
        selectedModel: String? = nil
    ) {
        self.id = UUID()
        self.cacheKey = cacheKey
        self.sourceText = sourceText
        self.action = action
        self.object = object
        self.primaryName = primaryName
        self.secondaryItems = secondaryItems
        self.metadata = metadata
        self.executionIntent = executionIntent
        self.selectedModel = selectedModel
    }

    func updatingSelectedModel(_ model: String) -> ParsedIntent {
        var copy = self
        copy.selectedModel = model
        return copy
    }
}

actor IntentParserService {
    static let shared = IntentParserService()

    private let cacheTTL: TimeInterval = 600
    private let lookupService = WorkspaceLookupService.shared

    private struct CacheEntry {
        let intent: ParsedIntent
        let timestamp: Date
    }

    private var intentCache: [String: CacheEntry] = [:]

    private init() {}

    func cachedIntent(for message: String) -> ParsedIntent? {
        let key = Self.cacheKey(for: message)
        guard let entry = intentCache[key] else {
            return nil
        }
        if Date().timeIntervalSince(entry.timestamp) > cacheTTL {
            intentCache.removeValue(forKey: key)
            return nil
        }
        return entry.intent
    }

    func cacheIntent(_ intent: ParsedIntent) {
        intentCache[intent.cacheKey] = CacheEntry(intent: intent, timestamp: Date())
    }

    func clearIntent(for message: String) {
        intentCache.removeValue(forKey: Self.cacheKey(for: message))
    }

    func parseIntent(
        from message: String,
        linkedContext: LinkedContext?,
        modelContext: ModelContext?
    ) async throws -> ParsedIntent? {
        let key = Self.cacheKey(for: message)
        if let cached = cachedIntent(for: message) {
            return cached
        }

        guard let executionIntent = try await CoreResponseService.shared.detectExecutionIntent(
            input: message,
            linkedContext: linkedContext
        ) else {
            return nil
        }

        let parsed = await buildParsedIntent(
            executionIntent: executionIntent,
            message: message,
            cacheKey: key,
            modelContext: modelContext
        )
        cacheIntent(parsed)
        #if DEBUG
        print("[IntentParserService] Parsed intent \(parsed.action.rawValue)→\(parsed.object.rawValue) for key \(key.prefix(6))")
        #endif
        return parsed
    }

    func store(_ intent: ParsedIntent) {
        cacheIntent(intent)
    }

    // MARK: - Parsing

    private func buildParsedIntent(
        executionIntent: ExecutionIntent,
        message: String,
        cacheKey: String,
        modelContext: ModelContext?
    ) async -> ParsedIntent {
        let action = mapActionType(from: executionIntent.operation)
        let object = mapObjectType(from: executionIntent.operation)
        let primaryName = extractPrimaryName(from: executionIntent)
        let secondaryItems = extractSecondaryItems(from: executionIntent)

        let metadata = await resolveMetadata(
            from: executionIntent,
            object: object,
            modelContext: modelContext
        )

        return ParsedIntent(
            cacheKey: cacheKey,
            sourceText: message,
            action: action,
            object: object,
            primaryName: primaryName,
            secondaryItems: secondaryItems,
            metadata: metadata,
            executionIntent: executionIntent
        )
    }

    private func mapActionType(from operation: ExecutionOperation) -> ParsedIntent.ActionType {
        switch operation {
        case .createProject, .createTask, .createNote, .createPost, .createReminder, .createArtifact, .addInboxItem:
            return .create
        case .updateProject, .updateTask, .updateNote, .updateArtifact, .convertInboxItem, .convertTaskToNote:
            return .update
        case .deleteProject, .deleteTask, .deleteNote, .deleteArtifact:
            return .delete
        case .duplicateProject:
            return .create
        case .digestConversation, .digestAllConversations:
            return .respond
        case .searchConversations:
            return .lookup
        case .archiveTasks:
            return .status
        default:
            return .unknown
        }
    }

    private func mapObjectType(from operation: ExecutionOperation) -> ParsedIntent.ObjectType {
        switch operation {
        case .createProject, .updateProject, .deleteProject, .duplicateProject:
            return .project
        case .createTask, .updateTask, .deleteTask, .archiveTasks:
            return .task
        case .createNote, .updateNote, .deleteNote:
            return .note
        case .createPost, .publishPost, .summarizePosts:
            return .post
        case .createReminder:
            return .reminder
        case .createArtifact, .updateArtifact, .deleteArtifact:
            return .artifact
        case .digestConversation, .digestAllConversations, .searchConversations:
            return .conversation
        case .addInboxItem, .convertInboxItem:
            return .inbox
        default:
            return .generic
        }
    }

    private func extractPrimaryName(from intent: ExecutionIntent) -> String? {
        if let projectTitle = intent.projectTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !projectTitle.isEmpty {
            return projectTitle
        }
        if let taskTitle = intent.taskTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !taskTitle.isEmpty {
            return taskTitle
        }
        if let noteTitle = intent.noteTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !noteTitle.isEmpty {
            return noteTitle
        }
        if let postCaption = intent.caption?.trimmingCharacters(in: .whitespacesAndNewlines),
           !postCaption.isEmpty {
            return postCaption
        }
        if let reminderTitle = intent.reminderTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !reminderTitle.isEmpty {
            return reminderTitle
        }
        if let artifactTitle = intent.artifactTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !artifactTitle.isEmpty {
            return artifactTitle
        }
        return nil
    }

    private func extractSecondaryItems(from intent: ExecutionIntent) -> [String] {
        var items: [String] = []
        if let taskTitles = intent.taskTitles {
            items.append(contentsOf: taskTitles)
        }
        if let noteTitles = intent.noteTitles {
            items.append(contentsOf: noteTitles)
        }
        if let postCaptions = intent.postCaptions {
            items.append(contentsOf: postCaptions)
        }
        return items
    }

    private func resolveMetadata(
        from intent: ExecutionIntent,
        object: ParsedIntent.ObjectType,
        modelContext: ModelContext?
    ) async -> ParsedIntent.Metadata {
        var resolvedObjects: [ParsedIntent.ObjectReference] = []
        var missingObjects: [String] = []
        var projectId: UUID?
        var noteId: UUID?
        var areaId: UUID?
        var dueDate = parse(dateString: intent.taskDueDate ?? intent.projectDueDate)
        let reminderDate = parse(dateString: intent.reminderDate)

        if let areaIdentifier = intent.projectAreaId, let uuid = UUID(uuidString: areaIdentifier) {
            areaId = uuid
        } else if let taskAreaIdentifier = intent.taskAreaId, let uuid = UUID(uuidString: taskAreaIdentifier) {
            areaId = uuid
        }

        if let context = modelContext {
            if let projectName = intent.projectTitle,
               let project = await lookupService.lookupProject(name: projectName, modelContext: context) {
                projectId = project.id
                resolvedObjects.append(.init(objectId: project.id, name: project.title, type: .project))
            } else if let projectUUIDString = intent.projectId, let projectUUID = UUID(uuidString: projectUUIDString) {
                projectId = projectUUID
            } else if let projectUUIDString = intent.taskProjectId, let uuid = UUID(uuidString: projectUUIDString) {
                projectId = uuid
            }

            if let noteTitle = intent.noteTitle,
               let note = await lookupService.lookupNote(name: noteTitle, modelContext: context) {
                noteId = note.id
                resolvedObjects.append(.init(objectId: note.id, name: note.title, type: .note))
            }

            if noteId == nil, let existingNoteId = intent.noteId, let uuid = UUID(uuidString: existingNoteId) {
                noteId = uuid
            }

            // Validate referenced tasks
            if let taskTitle = intent.taskTitle, !taskTitle.isEmpty {
                let task = await lookupService.lookupTask(name: taskTitle, projectId: projectId, modelContext: context)
                if let task {
                    resolvedObjects.append(.init(objectId: task.id, name: task.title, type: .task))
                } else {
                    missingObjects.append(taskTitle)
                }
            }
        }

        let tags = intent.tags ?? []
        let priority = mapTaskPriority(intent.taskPriority)
        let status = mapTaskStatus(intent.taskStatus)
        let notes = intent.notes ?? intent.taskNotes ?? intent.noteBody

        if object == .project, dueDate == nil {
            dueDate = parse(dateString: intent.projectDueDate)
        }

        return ParsedIntent.Metadata(
            dueDate: dueDate,
            tags: tags,
            priority: priority,
            status: status,
            areaId: areaId,
            projectId: projectId,
            noteId: noteId,
            reminderDate: reminderDate,
            secondaryItemCount: intent.taskCount ?? intent.noteCount ?? intent.postCount ?? 0,
            resolvedObjects: resolvedObjects,
            missingObjects: missingObjects,
            notes: notes
        )
    }

    private func parse(dateString: String?) -> Date? {
        guard let value = dateString, !value.isEmpty else {
            return nil
        }
        let formatter = ISO8601DateFormatter()
        if let parsed = formatter.date(from: value) {
            return parsed
        }
        let shortFormatter = DateFormatter()
        shortFormatter.dateFormat = "yyyy-MM-dd"
        return shortFormatter.date(from: value)
    }

    private func mapTaskPriority(_ raw: String?) -> TaskPriority? {
        guard let raw else { return nil }
        return TaskPriority(rawValue: raw)
    }

    private func mapTaskStatus(_ raw: String?) -> TaskStatus? {
        guard let raw else { return nil }
        return TaskStatus(rawValue: raw)
    }

    private static func cacheKey(for message: String) -> String {
        let cleaned = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8) else {
            return UUID().uuidString
        }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
