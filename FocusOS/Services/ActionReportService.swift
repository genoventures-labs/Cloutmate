//
//  ActionReportService.swift
//  FocusOS
//
//  Generates conversational follow-up summaries that replace rigid markdown
//  lists. All workspace mutations should acknowledge the action via this
//  service so tone stays consistent.
//

import Foundation
import SwiftData
import FocusOSShared

@MainActor
final class ActionReportService {
    static let shared = ActionReportService()

    private let personalityService = LanguagePersonalityService.shared

    private init() {}

    func generateActionReport(
        intent: ParsedIntent,
        createdObjects: [UUID],
        modelContext: ModelContext,
        tone: AuroraTone? = nil
    ) async -> String {
        let resolvedNames = fetchTitles(for: createdObjects, modelContext: modelContext)
        let headline = buildHeadline(for: intent, createdNames: resolvedNames)
        return personalityService.conversationalAcknowledgement(
            base: headline,
            tone: tone
        )
    }

    private func buildHeadline(
        for intent: ParsedIntent,
        createdNames: [String]
    ) -> String {
        let primaryName = intent.primaryName ?? createdNames.first
        let secondary = Array(createdNames.dropFirst())
        let joinedSecondary = secondary.isEmpty ? nil : secondary.joined(separator: ", ")

        switch intent.object {
        case .project:
            var base = "All good — I created the project"
            if let primaryName {
                base += " \"\(primaryName)\""
            }
            if !intent.secondaryItems.isEmpty {
                base += " and lined up \(intent.secondaryItems.count) follow-up items"
            } else if let joinedSecondary {
                base += " with \(joinedSecondary)"
            }
            return base + "."
        case .task:
            var base = "Done. \(primaryName ?? "The task") is ready to track."
            if let dueDate = intent.metadata.dueDate {
                let formatted = DateFormatter.shortFriendly.string(from: dueDate)
                base += " Due \(formatted)."
                return base
            }
            return base
        case .note:
            var base = "I saved"
            if let primaryName {
                base += " \"\(primaryName)\""
            } else {
                base += " that note"
            }
            if let tag = intent.metadata.tags.first {
                base += " under \(tag)."
            } else {
                base += "."
            }
            return base
        case .post:
            return "Post queued — \(primaryName ?? "the caption") is ready whenever you are."
        case .reminder:
            return "Reminder set. \(primaryName ?? "That nudge") will ping you at the right time."
        case .artifact:
            return "Artifact locked in. \(primaryName ?? "The piece") is synced with your workspace."
        default:
            if let primaryName {
                return "Wrapped that up — \(primaryName) is taken care of."
            }
            return "Everything's squared away."
        }
    }

    private func fetchTitles(
        for ids: [UUID],
        modelContext: ModelContext
    ) -> [String] {
        guard !ids.isEmpty else { return [] }
        var names: [String] = []
        for id in ids {
            if let title = fetchProjectTitle(id: id, modelContext: modelContext)
                ?? fetchTaskTitle(id: id, modelContext: modelContext)
                ?? fetchNoteTitle(id: id, modelContext: modelContext)
                ?? fetchPostTitle(id: id, modelContext: modelContext)
                ?? fetchReminderTitle(id: id, modelContext: modelContext)
                ?? fetchArtifactTitle(id: id, modelContext: modelContext) {
                names.append(title)
            }
        }
        return names
    }

    private func fetchProjectTitle(id: UUID, modelContext: ModelContext) -> String? {
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate<Project> { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first?.title
    }

    private func fetchTaskTitle(id: UUID, modelContext: ModelContext) -> String? {
        let descriptor = FetchDescriptor<FocusOSShared.Task>(
            predicate: #Predicate<FocusOSShared.Task> { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first?.title
    }

    private func fetchNoteTitle(id: UUID, modelContext: ModelContext) -> String? {
        let descriptor = FetchDescriptor<FocusOSShared.Note>(
            predicate: #Predicate<FocusOSShared.Note> { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first?.title
    }

    private func fetchPostTitle(id: UUID, modelContext: ModelContext) -> String? {
        let descriptor = FetchDescriptor<Post>(
            predicate: #Predicate<Post> { $0.id == id }
        )
        if let post = try? modelContext.fetch(descriptor).first {
            return post.caption
        }
        return nil
    }

    private func fetchReminderTitle(id: UUID, modelContext: ModelContext) -> String? {
        let descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first?.title
    }

    private func fetchArtifactTitle(id: UUID, modelContext: ModelContext) -> String? {
        let descriptor = FetchDescriptor<Artifact>(
            predicate: #Predicate<Artifact> { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first?.title
    }
}

private extension DateFormatter {
    static let shortFriendly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
