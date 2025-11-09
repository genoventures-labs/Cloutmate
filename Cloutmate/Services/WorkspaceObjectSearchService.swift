//
//  WorkspaceObjectSearchService.swift
//  Cloutmate
//
//  Service for searching workspace objects by name/title
//

import Foundation
import SwiftData
import CloutmateShared

struct WorkspaceObjectResult: Identifiable, Hashable {
    let id: UUID
    let type: ObjectType
    let title: String
    let subtitle: String
    let matchScore: Double // Higher = better match
    
    var displayName: String {
        title
    }
}

@MainActor
class WorkspaceObjectSearchService {
    static let shared = WorkspaceObjectSearchService()
    
    private init() {}
    
    /// Search all workspace objects by query string
    func search(
        query: String,
        modelContext: ModelContext,
        limit: Int = 8
    ) -> [WorkspaceObjectResult] {
        guard !query.isEmpty else { return [] }
        
        let lowerQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var results: [WorkspaceObjectResult] = []
        
        // Search Projects
        let projectDescriptor = FetchDescriptor<CloutmateShared.Project>()
        if let projects = try? modelContext.fetch(projectDescriptor) {
            for project in projects {
                let score = calculateMatchScore(text: project.title.lowercased(), query: lowerQuery)
                if score > 0 {
                    let subtitle = project.status.displayName + (project.goal != nil ? " · \(String(project.goal!.prefix(40)))" : "")
                    results.append(WorkspaceObjectResult(
                        id: project.id,
                        type: .project,
                        title: project.title,
                        subtitle: subtitle,
                        matchScore: score
                    ))
                }
            }
        }
        
        // Search Tasks
        let taskDescriptor = FetchDescriptor<CloutmateShared.Task>()
        if let tasks = try? modelContext.fetch(taskDescriptor) {
            for task in tasks {
                var score = calculateMatchScore(text: task.title.lowercased(), query: lowerQuery)
                if let notes = task.notes, !notes.isEmpty {
                    score = max(score, calculateMatchScore(text: notes.lowercased(), query: lowerQuery) * 0.7)
                }
                if score > 0 {
                    let subtitle = task.status.displayName + " · " + task.priority.displayName
                    results.append(WorkspaceObjectResult(
                        id: task.id,
                        type: .task,
                        title: task.title,
                        subtitle: subtitle,
                        matchScore: score
                    ))
                }
            }
        }
        
        // Search Notes
        let noteDescriptor = FetchDescriptor<CloutmateShared.Note>()
        if let notes = try? modelContext.fetch(noteDescriptor) {
            for note in notes {
                var score = calculateMatchScore(text: note.title.lowercased(), query: lowerQuery)
                score = max(score, calculateMatchScore(text: note.markdown.lowercased(), query: lowerQuery) * 0.6)
                if score > 0 {
                    let subtitle = String(note.markdown.prefix(50))
                    results.append(WorkspaceObjectResult(
                        id: note.id,
                        type: .note,
                        title: note.title,
                        subtitle: subtitle,
                        matchScore: score
                    ))
                }
            }
        }
        
        // Search Posts
        let postDescriptor = FetchDescriptor<CloutmateShared.Post>()
        if let posts = try? modelContext.fetch(postDescriptor) {
            for post in posts {
                let score = calculateMatchScore(text: post.caption.lowercased(), query: lowerQuery)
                if score > 0 {
                    let subtitle = post.postStatus.displayName + " · " + post.postPlatforms.map { $0.displayName }.joined(separator: ", ")
                    results.append(WorkspaceObjectResult(
                        id: post.id,
                        type: .post,
                        title: post.caption.isEmpty ? "Empty Post" : String(post.caption.prefix(50)),
                        subtitle: subtitle,
                        matchScore: score
                    ))
                }
            }
        }
        
        // Search Reminders
        let reminderDescriptor = FetchDescriptor<CloutmateShared.Reminder>()
        if let reminders = try? modelContext.fetch(reminderDescriptor) {
            for reminder in reminders {
                var score = calculateMatchScore(text: reminder.title.lowercased(), query: lowerQuery)
                if let notes = reminder.notes, !notes.isEmpty {
                    score = max(score, calculateMatchScore(text: notes.lowercased(), query: lowerQuery) * 0.7)
                }
                if score > 0 {
                    let subtitle = reminder.isCompleted ? "Completed" : "Pending"
                    results.append(WorkspaceObjectResult(
                        id: reminder.id,
                        type: .reminder,
                        title: reminder.title,
                        subtitle: subtitle,
                        matchScore: score
                    ))
                }
            }
        }
        
        // Search Inbox Items
        let inboxDescriptor = FetchDescriptor<CloutmateShared.InboxItem>()
        if let inboxItems = try? modelContext.fetch(inboxDescriptor) {
            for item in inboxItems {
                let score = calculateMatchScore(text: item.content.lowercased(), query: lowerQuery)
                if score > 0 {
                    let subtitle = item.convertedAt == nil ? "Unconverted" : "Converted"
                    results.append(WorkspaceObjectResult(
                        id: item.id,
                        type: .inboxItem,
                        title: String(item.content.prefix(50)),
                        subtitle: subtitle,
                        matchScore: score
                    ))
                }
            }
        }
        
        // Search Focus Sessions
        let focusSessionDescriptor = FetchDescriptor<FocusSession>()
        if let sessions = try? modelContext.fetch(focusSessionDescriptor) {
            for session in sessions {
                let score = calculateMatchScore(text: session.objective.lowercased(), query: lowerQuery)
                if score > 0 {
                    let subtitle = session.status.rawValue.capitalized + " · \(session.durationFormatted)"
                    results.append(WorkspaceObjectResult(
                        id: session.id,
                        type: .focusSession,
                        title: session.objective,
                        subtitle: subtitle,
                        matchScore: score
                    ))
                }
            }
        }
        
        // Sort by match score (highest first) and limit results
        return results
            .sorted { $0.matchScore > $1.matchScore }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Calculate match score for text against query
    /// Returns 0.0 - 1.0, where 1.0 is exact match
    private func calculateMatchScore(text: String, query: String) -> Double {
        let lowerText = text.lowercased()
        let lowerQuery = query.lowercased()
        
        // Exact match
        if lowerText == lowerQuery {
            return 1.0
        }
        
        // Starts with query
        if lowerText.hasPrefix(lowerQuery) {
            return 0.9
        }
        
        // Contains query
        if lowerText.contains(lowerQuery) {
            return 0.7
        }
        
        // Fuzzy match (words in query appear in text)
        let queryWords = lowerQuery.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if !queryWords.isEmpty {
            let matchingWords = queryWords.filter { lowerText.contains($0) }.count
            if matchingWords > 0 {
                return Double(matchingWords) / Double(queryWords.count) * 0.5
            }
        }
        
        return 0.0
    }
    
    /// Get object details by ID and type
    func getObjectDetails(
        id: UUID,
        type: ObjectType,
        modelContext: ModelContext
    ) -> (title: String, subtitle: String)? {
        switch type {
        case .project:
            let descriptor = FetchDescriptor<CloutmateShared.Project>(
                predicate: #Predicate { $0.id == id }
            )
            if let project = try? modelContext.fetch(descriptor).first {
                let subtitle = project.status.displayName + (project.goal != nil ? " · \(String(project.goal!.prefix(40)))" : "")
                return (title: project.title, subtitle: subtitle)
            }
        case .task:
            let descriptor = FetchDescriptor<CloutmateShared.Task>(
                predicate: #Predicate { $0.id == id }
            )
            if let task = try? modelContext.fetch(descriptor).first {
                let subtitle = task.status.displayName + " · " + task.priority.displayName
                return (title: task.title, subtitle: subtitle)
            }
        case .note:
            let descriptor = FetchDescriptor<CloutmateShared.Note>(
                predicate: #Predicate { $0.id == id }
            )
            if let note = try? modelContext.fetch(descriptor).first {
                let subtitle = String(note.markdown.prefix(50))
                return (title: note.title, subtitle: subtitle)
            }
        case .post:
            let descriptor = FetchDescriptor<CloutmateShared.Post>(
                predicate: #Predicate { $0.id == id }
            )
            if let post = try? modelContext.fetch(descriptor).first {
                let subtitle = post.postStatus.displayName + " · " + post.postPlatforms.map { $0.displayName }.joined(separator: ", ")
                return (title: post.caption.isEmpty ? "Empty Post" : String(post.caption.prefix(50)), subtitle: subtitle)
            }
        case .reminder:
            let descriptor = FetchDescriptor<CloutmateShared.Reminder>(
                predicate: #Predicate { $0.id == id }
            )
            if let reminder = try? modelContext.fetch(descriptor).first {
                let subtitle = reminder.isCompleted ? "Completed" : "Pending"
                return (title: reminder.title, subtitle: subtitle)
            }
        case .inboxItem:
            let descriptor = FetchDescriptor<CloutmateShared.InboxItem>(
                predicate: #Predicate { $0.id == id }
            )
            if let item = try? modelContext.fetch(descriptor).first {
                let subtitle = item.convertedAt == nil ? "Unconverted" : "Converted"
                return (title: String(item.content.prefix(50)), subtitle: subtitle)
            }
        case .focusSession:
            let descriptor = FetchDescriptor<FocusSession>(
                predicate: #Predicate { $0.id == id }
            )
            if let session = try? modelContext.fetch(descriptor).first {
                let subtitle = session.status.rawValue.capitalized + " · \(session.durationFormatted)"
                return (title: session.objective, subtitle: subtitle)
            }
        }
        
        return nil
    }
}

