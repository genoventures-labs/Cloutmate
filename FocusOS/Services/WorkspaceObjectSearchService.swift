//
//  WorkspaceObjectSearchService.swift
//  FocusOS
//
//  Service for searching workspace objects by name/title
//

import Foundation
import SwiftData
import FocusOSShared

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
    
    private let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
    
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
        let projectDescriptor = FetchDescriptor<FocusOSShared.Project>()
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
        let taskDescriptor = FetchDescriptor<FocusOSShared.Task>()
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
        
        // Search Areas
        let areaDescriptor = FetchDescriptor<Area>()
        if let areas = try? modelContext.fetch(areaDescriptor) {
            for area in areas {
                let score = calculateMatchScore(text: area.title.lowercased(), query: lowerQuery)
                var bestScore = score
                
                if let notes = area.notes, !notes.isEmpty {
                    let cleanedNotes = cleanDescription(notes.lowercased())
                    let notesScore = calculateMatchScore(text: cleanedNotes, query: lowerQuery)
                    let weightedNotesScore = notesScore * 0.6
                    if weightedNotesScore > bestScore {
                        bestScore = weightedNotesScore
                    }
                }
                
                if bestScore > 0 {
                    results.append(
                        WorkspaceObjectResult(
                            id: area.id,
                            type: .area,
                            title: area.title,
                            subtitle: areaSubtitle(for: area),
                            matchScore: bestScore
                        )
                    )
                }
            }
        }
        
        // Search Notes
        let noteDescriptor = FetchDescriptor<FocusOSShared.Note>()
        if let notes = try? modelContext.fetch(noteDescriptor) {
            for note in notes {
                var score = calculateMatchScore(text: note.title.lowercased(), query: lowerQuery)
                score = max(score, calculateMatchScore(text: note.markdown.lowercased(), query: lowerQuery) * 0.6)
                if score > 0 {
                    var subtitle = String(note.markdown.prefix(50))
                    subtitle = cleanDescription(subtitle)
                    if subtitle.isEmpty {
                        subtitle = "No description available"
                    }
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
        let postDescriptor = FetchDescriptor<FocusOSShared.Post>()
        if let posts = try? modelContext.fetch(postDescriptor) {
            for post in posts {
                let score = calculateMatchScore(text: post.caption.lowercased(), query: lowerQuery)
                if score > 0 {
                    let subtitle = post.postStatus.displayName
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
        let reminderDescriptor = FetchDescriptor<FocusOSShared.Reminder>()
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
        let inboxDescriptor = FetchDescriptor<FocusOSShared.InboxItem>()
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
        
        // Search Calendar Events
        let eventDescriptor = FetchDescriptor<CalendarEvent>()
        if let calendarEvents = try? modelContext.fetch(eventDescriptor) {
            for event in calendarEvents {
                var score = calculateMatchScore(text: event.title.lowercased(), query: lowerQuery)
                if let notes = event.notes, !notes.isEmpty {
                    score = max(score, calculateMatchScore(text: notes.lowercased(), query: lowerQuery) * 0.6)
                }
                if score > 0 {
                    results.append(
                        WorkspaceObjectResult(
                            id: event.id,
                            type: .event,
                            title: event.title.isEmpty ? "Untitled Event" : event.title,
                            subtitle: eventSubtitle(for: event),
                            matchScore: score
                        )
                    )
                }
            }
        }
        
        // Sort by match score (highest first) and limit results
        return results
            .sorted { $0.matchScore > $1.matchScore }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Get tab name for ObjectType
    func tabName(for type: ObjectType) -> String {
        switch type {
        case .task: return "Tasks"
        case .project: return "Projects"
        case .note: return "Notes"
        case .post: return "Posts"
        case .artifact: return "Artifacts"
        case .area: return "Areas"
        case .event: return "Calendar Events"
        case .reminder: return "Reminders"
        case .inboxItem: return "Inbox"
        case .focusSession: return "Focus Sessions"
        }
    }
    
    /// Parse query for tab filter (e.g., "@tasks" -> .task, "@tasks my" -> .task with query "my")
    func parseTabFilter(from query: String) -> ObjectType? {
        let lowerQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check exact matches first
        switch lowerQuery {
        case "tasks", "task": return .task
        case "projects", "project": return .project
        case "notes", "note": return .note
        case "posts", "post": return .post
        case "artifacts", "artifact": return .artifact
        case "areas", "area": return .area
        case "events", "event": return .event
        case "reminders", "reminder": return .reminder
        case "inbox", "inboxitems", "inboxitem": return .inboxItem
        case "focus", "focussessions", "focussession": return .focusSession
        default: break
        }
        
        // Check if query starts with a tab filter (e.g., "tasks my task" -> .task with query "my task")
        let components = lowerQuery.components(separatedBy: .whitespaces)
        if let firstComponent = components.first {
            switch firstComponent {
            case "tasks", "task": return .task
            case "projects", "project": return .project
            case "notes", "note": return .note
            case "posts", "post": return .post
            case "artifacts", "artifact": return .artifact
            case "areas", "area": return .area
            case "events", "event": return .event
            case "reminders", "reminder": return .reminder
            case "inbox", "inboxitems", "inboxitem": return .inboxItem
            case "focus", "focussessions", "focussession": return .focusSession
            default: return nil
            }
        }
        
        return nil
    }
    
    /// Extract search query after tab filter (e.g., "tasks my task" -> "my task")
    func extractSearchQuery(from query: String, tabFilter: ObjectType) -> String {
        let lowerQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let components = lowerQuery.components(separatedBy: .whitespaces)
        
        // If first component matches the tab filter, return the rest
        if let firstComponent = components.first,
           (tabFilter == .task && (firstComponent == "tasks" || firstComponent == "task")) ||
           (tabFilter == .project && (firstComponent == "projects" || firstComponent == "project")) ||
           (tabFilter == .note && (firstComponent == "notes" || firstComponent == "note")) ||
           (tabFilter == .post && (firstComponent == "posts" || firstComponent == "post")) ||
           (tabFilter == .artifact && (firstComponent == "artifacts" || firstComponent == "artifact")) ||
           (tabFilter == .area && (firstComponent == "areas" || firstComponent == "area")) ||
           (tabFilter == .event && (firstComponent == "events" || firstComponent == "event")) ||
           (tabFilter == .reminder && (firstComponent == "reminders" || firstComponent == "reminder")) ||
           (tabFilter == .inboxItem && (firstComponent == "inbox" || firstComponent == "inboxitems" || firstComponent == "inboxitem")) ||
           (tabFilter == .focusSession && (firstComponent == "focus" || firstComponent == "focussessions" || firstComponent == "focussession")) {
            return components.dropFirst().joined(separator: " ")
        }
        
        // If exact match, return empty (show all of that type)
        return ""
    }
    
    /// Get all workspace objects (used when "@" is typed with no query)
    /// Optionally filter by tab type
    func searchAll(
        modelContext: ModelContext,
        limit: Int = 20,
        filterByTab: ObjectType? = nil
    ) -> [WorkspaceObjectResult] {
        var results: [WorkspaceObjectResult] = []
        
        // Get all Projects
        let projectDescriptor = FetchDescriptor<FocusOSShared.Project>()
        if let projects = try? modelContext.fetch(projectDescriptor) {
            for project in projects {
                let subtitle = project.status.displayName + (project.goal != nil ? " · \(String(project.goal!.prefix(40)))" : "")
                results.append(WorkspaceObjectResult(
                    id: project.id,
                    type: .project,
                    title: project.title,
                    subtitle: subtitle,
                    matchScore: 1.0
                ))
            }
        }
        
        // Get all Tasks
        let taskDescriptor = FetchDescriptor<FocusOSShared.Task>()
        if let tasks = try? modelContext.fetch(taskDescriptor) {
            for task in tasks {
                let subtitle = task.status.displayName + " · " + task.priority.displayName
                results.append(WorkspaceObjectResult(
                    id: task.id,
                    type: .task,
                    title: task.title,
                    subtitle: subtitle,
                    matchScore: 1.0
                ))
            }
        }
        
        // Get all Areas
        let areaDescriptor = FetchDescriptor<Area>()
        if let areas = try? modelContext.fetch(areaDescriptor) {
            for area in areas {
                results.append(
                    WorkspaceObjectResult(
                        id: area.id,
                        type: .area,
                        title: area.title,
                        subtitle: areaSubtitle(for: area),
                        matchScore: 1.0
                    )
                )
            }
        }
        
        // Get all Notes
        let noteDescriptor = FetchDescriptor<FocusOSShared.Note>()
        if let notes = try? modelContext.fetch(noteDescriptor) {
            for note in notes {
                var subtitle = String(note.markdown.prefix(50))
                subtitle = cleanDescription(subtitle)
                if subtitle.isEmpty {
                    subtitle = "No description available"
                }
                results.append(WorkspaceObjectResult(
                    id: note.id,
                    type: .note,
                    title: note.title,
                    subtitle: subtitle,
                    matchScore: 1.0
                ))
            }
        }
        
        // Get all Posts
        let postDescriptor = FetchDescriptor<FocusOSShared.Post>()
        if let posts = try? modelContext.fetch(postDescriptor) {
            for post in posts {
                let subtitle = post.postStatus.displayName
                results.append(WorkspaceObjectResult(
                    id: post.id,
                    type: .post,
                    title: post.caption.isEmpty ? "Empty Post" : String(post.caption.prefix(50)),
                    subtitle: subtitle,
                    matchScore: 1.0
                ))
            }
        }
        
        // Get all Reminders
        let reminderDescriptor = FetchDescriptor<FocusOSShared.Reminder>()
        if let reminders = try? modelContext.fetch(reminderDescriptor) {
            for reminder in reminders {
                let subtitle = reminder.isCompleted ? "Completed" : "Pending"
                results.append(WorkspaceObjectResult(
                    id: reminder.id,
                    type: .reminder,
                    title: reminder.title,
                    subtitle: subtitle,
                    matchScore: 1.0
                ))
            }
        }
        
        // Get all Inbox Items
        let inboxDescriptor = FetchDescriptor<FocusOSShared.InboxItem>()
        if let inboxItems = try? modelContext.fetch(inboxDescriptor) {
            for item in inboxItems {
                let subtitle = item.convertedAt == nil ? "Unconverted" : "Converted"
                results.append(WorkspaceObjectResult(
                    id: item.id,
                    type: .inboxItem,
                    title: String(item.content.prefix(50)),
                    subtitle: subtitle,
                    matchScore: 1.0
                ))
            }
        }
        
        // Get all Focus Sessions
        let focusSessionDescriptor = FetchDescriptor<FocusSession>()
        if let sessions = try? modelContext.fetch(focusSessionDescriptor) {
            for session in sessions {
                let subtitle = session.status.rawValue.capitalized + " · \(session.durationFormatted)"
                results.append(WorkspaceObjectResult(
                    id: session.id,
                    type: .focusSession,
                    title: session.objective,
                    subtitle: subtitle,
                    matchScore: 1.0
                ))
            }
        }
        
        // Get all Calendar Events
        let eventDescriptor = FetchDescriptor<CalendarEvent>()
        if let calendarEvents = try? modelContext.fetch(eventDescriptor) {
            for event in calendarEvents {
                results.append(
                    WorkspaceObjectResult(
                        id: event.id,
                        type: .event,
                        title: event.title.isEmpty ? "Untitled Event" : event.title,
                        subtitle: eventSubtitle(for: event),
                        matchScore: 1.0
                    )
                )
            }
        }
        
        // Filter by tab if specified
        var filteredResults = results
        if let filterTab = filterByTab {
            filteredResults = results.filter { $0.type == filterTab }
        }
        
        // Sort by type, then by title, and limit results
        return filteredResults
            .sorted { first, second in
                // Sort by type first (alphabetically)
                if first.type.rawValue != second.type.rawValue {
                    return first.type.rawValue < second.type.rawValue
                }
                // Then by title
                return first.title < second.title
            }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Search with tab filtering support
    func searchWithTabFilter(
        query: String,
        modelContext: ModelContext,
        limit: Int = 20
    ) -> (results: [WorkspaceObjectResult], tabFilter: ObjectType?) {
        let tabFilter = parseTabFilter(from: query)
        
        if let filter = tabFilter {
            // Extract search query after tab filter
            let searchQuery = extractSearchQuery(from: query, tabFilter: filter)
            
            if searchQuery.isEmpty {
                // Return all items of this type
                return (searchAll(modelContext: modelContext, limit: limit, filterByTab: filter), filter)
            } else {
                // Search within this tab type
                let allOfType = searchAll(modelContext: modelContext, limit: 1000, filterByTab: filter)
                // Filter by search query
                let filtered = allOfType.filter { result in
                    result.title.lowercased().contains(searchQuery.lowercased()) ||
                    result.subtitle.lowercased().contains(searchQuery.lowercased())
                }
                return (Array(filtered.prefix(limit)), filter)
            }
        } else if query.isEmpty {
            // No filter, no query - show all
            return (searchAll(modelContext: modelContext, limit: limit), nil)
        } else {
            // Regular search
            return (search(query: query, modelContext: modelContext, limit: limit), nil)
        }
    }
    
    private func fetchProject(by id: UUID, context: ModelContext) -> FocusOSShared.Project? {
        let descriptor = FetchDescriptor<FocusOSShared.Project>(
            predicate: #Predicate { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }
    
    /// Clean description text by removing JSON blobs, taskID patterns, etc.
    private func cleanDescription(_ text: String) -> String {
        var cleaned = text
        
        // Remove JSON-like patterns: { "key": "value" } or {"key":"value"}
        let jsonPattern = #"\{[^{}]*\}"#
        cleaned = cleaned.replacingOccurrences(of: jsonPattern, with: "", options: .regularExpression)
        
        // Remove taskID patterns: taskID{...} or taskID {...}
        let taskIdPattern = #"taskID\s*\{[^}]*\}"#
        cleaned = cleaned.replacingOccurrences(of: taskIdPattern, with: "", options: .regularExpression)
        
        // Remove UUID patterns
        let uuidPattern = #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#
        cleaned = cleaned.replacingOccurrences(of: uuidPattern, with: "", options: .regularExpression)
        
        // Remove structured mention patterns: @{type:id}
        let mentionPattern = #"@\{[^}]+\}"#
        cleaned = cleaned.replacingOccurrences(of: mentionPattern, with: "", options: .regularExpression)
        
        // Remove mention terminators
        cleaned = MentionParser.stripTerminators(from: cleaned)
        
        // Clean up extra spaces
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
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
            let descriptor = FetchDescriptor<FocusOSShared.Project>(
                predicate: #Predicate { $0.id == id }
            )
            if let project = try? modelContext.fetch(descriptor).first {
                let subtitle = project.status.displayName + (project.goal != nil ? " · \(String(project.goal!.prefix(40)))" : "")
                return (title: project.title, subtitle: subtitle)
            }
        case .task:
            let descriptor = FetchDescriptor<FocusOSShared.Task>(
                predicate: #Predicate { $0.id == id }
            )
            if let task = try? modelContext.fetch(descriptor).first {
                let subtitle = task.status.displayName + " · " + task.priority.displayName
                return (title: task.title, subtitle: subtitle)
            }
        case .note:
            let descriptor = FetchDescriptor<FocusOSShared.Note>(
                predicate: #Predicate { $0.id == id }
            )
            if let note = try? modelContext.fetch(descriptor).first {
                var subtitle = String(note.markdown.prefix(50))
                // Clean JSON/taskID blobs
                subtitle = cleanDescription(subtitle)
                return (title: note.title, subtitle: subtitle.isEmpty ? "No description available" : subtitle)
            }
        case .post:
            let descriptor = FetchDescriptor<FocusOSShared.Post>(
                predicate: #Predicate { $0.id == id }
            )
            if let post = try? modelContext.fetch(descriptor).first {
                let subtitle = post.postStatus.displayName
                return (title: post.caption.isEmpty ? "Empty Post" : String(post.caption.prefix(50)), subtitle: subtitle)
            }
        case .artifact:
            let descriptor = FetchDescriptor<FocusOSShared.Artifact>(
                predicate: #Predicate { $0.id == id }
            )
            if let artifact = try? modelContext.fetch(descriptor).first {
                var subtitle = artifact.format.displayName
                if let projectId = artifact.projectId {
                    subtitle += " · Linked to project"
                    if let project = fetchProject(by: projectId, context: modelContext) {
                        subtitle += " \(project.title)"
                    }
                }
                return (title: artifact.title.isEmpty ? artifact.format.displayName : artifact.title, subtitle: subtitle)
            }
        case .area:
            let descriptor = FetchDescriptor<Area>(
                predicate: #Predicate { $0.id == id }
            )
            if let area = try? modelContext.fetch(descriptor).first {
                return (title: area.title, subtitle: areaSubtitle(for: area))
            }
        case .event:
            let descriptor = FetchDescriptor<CalendarEvent>(
                predicate: #Predicate { $0.id == id }
            )
            if let event = try? modelContext.fetch(descriptor).first {
                return (title: event.title.isEmpty ? "Untitled Event" : event.title, subtitle: eventSubtitle(for: event))
            }
        case .reminder:
            let descriptor = FetchDescriptor<FocusOSShared.Reminder>(
                predicate: #Predicate { $0.id == id }
            )
            if let reminder = try? modelContext.fetch(descriptor).first {
                let subtitle = reminder.isCompleted ? "Completed" : "Pending"
                return (title: reminder.title, subtitle: subtitle)
            }
        case .inboxItem:
            let descriptor = FetchDescriptor<FocusOSShared.InboxItem>(
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
    
    private func areaSubtitle(for area: Area) -> String {
        var parts: [String] = []
        
        switch area.status {
        case .active:
            parts.append("Active")
        case .archived:
            parts.append("Archived")
        case .reviewNeeded:
            parts.append("Needs Review")
        }
        
        if let lastReview = area.lastReviewDate {
            let relative = relativeDateFormatter.localizedString(for: lastReview, relativeTo: Date())
            parts.append("Reviewed \(relative)")
        }
        
        if !area.tags.isEmpty {
            let tagCount = area.tags.count
            parts.append("\(tagCount) tag\(tagCount == 1 ? "" : "s")")
        }
        
        if parts.isEmpty {
            return "Area"
        }
        
        return parts.joined(separator: " · ")
    }
    
    private func eventSubtitle(for event: CalendarEvent) -> String {
        var parts: [String] = []
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = event.allDay ? .none : .short
        
        parts.append(event.allDay ? "All-day" : formatter.string(from: event.startDate))
        
        if let recurrence = event.recurrence {
            parts.append(recurrenceSummary(recurrence))
        }
        
        if let location = event.location, !location.isEmpty {
            parts.append(location)
        }
        
        return parts.joined(separator: " · ")
    }
    
    private func recurrenceSummary(_ recurrence: EventRecurrence) -> String {
        switch recurrence.frequency {
        case .daily:
            return recurrence.interval == 1 ? "Daily" : "Every \(recurrence.interval) days"
        case .weekly:
            let frequency = recurrence.interval == 1 ? "Weekly" : "Every \(recurrence.interval) weeks"
            if let weekdays = recurrence.weekdays, !weekdays.isEmpty {
                let formatter = DateFormatter()
                formatter.locale = Locale.current
                let names = weekdays.compactMap { index -> String? in
                    guard index >= 1 && index <= 7 else { return nil }
                    return formatter.weekdaySymbols[index - 1]
                }
                if !names.isEmpty {
                    return "\(frequency) on \(names.joined(separator: ", "))"
                }
            }
            return frequency
        case .monthly:
            return recurrence.interval == 1 ? "Monthly" : "Every \(recurrence.interval) months"
        case .yearly:
            return recurrence.interval == 1 ? "Yearly" : "Every \(recurrence.interval) years"
        }
    }
    
    /// Search workspace objects by hashtag/tag
    /// Searches Posts, Notes, Projects, and Artifacts by their tags arrays
    /// If query is empty or "*", returns all items with tags
    func searchByHashtag(
        query: String,
        modelContext: ModelContext,
        limit: Int = 20
    ) -> [WorkspaceObjectResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let showAll = trimmedQuery.isEmpty || trimmedQuery == "*"
        let lowerQuery = showAll ? "" : trimmedQuery.lowercased()
        var results: [WorkspaceObjectResult] = []
        
        // Search Projects by tags
        let projectDescriptor = FetchDescriptor<FocusOSShared.Project>()
        if let projects = try? modelContext.fetch(projectDescriptor) {
            for project in projects {
                // If showAll, include all projects with tags; otherwise match query
                let shouldInclude = showAll ? !project.tags.isEmpty : calculateTagMatchScore(tags: project.tags, query: lowerQuery) > 0
                if shouldInclude {
                    let tagMatchScore = showAll ? 1.0 : calculateTagMatchScore(tags: project.tags, query: lowerQuery)
                    let subtitle = project.status.displayName + (project.goal != nil ? " · \(String(project.goal!.prefix(40)))" : "")
                    results.append(WorkspaceObjectResult(
                        id: project.id,
                        type: .project,
                        title: project.title,
                        subtitle: subtitle,
                        matchScore: tagMatchScore
                    ))
                }
            }
        }
        
        // Search Notes by tags
        let noteDescriptor = FetchDescriptor<FocusOSShared.Note>()
        if let notes = try? modelContext.fetch(noteDescriptor) {
            for note in notes {
                // If showAll, include all notes with tags; otherwise match query
                let shouldInclude = showAll ? !note.tags.isEmpty : calculateTagMatchScore(tags: note.tags, query: lowerQuery) > 0
                if shouldInclude {
                    let tagMatchScore = showAll ? 1.0 : calculateTagMatchScore(tags: note.tags, query: lowerQuery)
                    var subtitle = String(note.markdown.prefix(50))
                    subtitle = cleanDescription(subtitle)
                    if subtitle.isEmpty {
                        subtitle = "No description available"
                    }
                    results.append(WorkspaceObjectResult(
                        id: note.id,
                        type: .note,
                        title: note.title,
                        subtitle: subtitle,
                        matchScore: tagMatchScore
                    ))
                }
            }
        }
        
        // Search Posts by tags
        let postDescriptor = FetchDescriptor<FocusOSShared.Post>()
        if let posts = try? modelContext.fetch(postDescriptor) {
            for post in posts {
                // If showAll, include all posts with tags; otherwise match query
                let shouldInclude = showAll ? !post.tags.isEmpty : calculateTagMatchScore(tags: post.tags, query: lowerQuery) > 0
                if shouldInclude {
                    let tagMatchScore = showAll ? 1.0 : calculateTagMatchScore(tags: post.tags, query: lowerQuery)
                    let subtitle = post.postStatus.displayName
                    results.append(WorkspaceObjectResult(
                        id: post.id,
                        type: .post,
                        title: post.caption.isEmpty ? "Empty Post" : String(post.caption.prefix(50)),
                        subtitle: subtitle,
                        matchScore: tagMatchScore
                    ))
                }
            }
        }
        
        // Search Artifacts by tags
        let artifactDescriptor = FetchDescriptor<FocusOSShared.Artifact>()
        if let artifacts = try? modelContext.fetch(artifactDescriptor) {
            for artifact in artifacts {
                // If showAll, include all artifacts with tags; otherwise match query
                let shouldInclude = showAll ? !artifact.tags.isEmpty : calculateTagMatchScore(tags: artifact.tags, query: lowerQuery) > 0
                if shouldInclude {
                    let tagMatchScore = showAll ? 1.0 : calculateTagMatchScore(tags: artifact.tags, query: lowerQuery)
                    var subtitle = artifact.format.displayName
                    if let projectId = artifact.projectId {
                        subtitle += " · Linked to project"
                        if let project = fetchProject(by: projectId, context: modelContext) {
                            subtitle += " \(project.title)"
                        }
                    }
                    results.append(WorkspaceObjectResult(
                        id: artifact.id,
                        type: .artifact,
                        title: artifact.title.isEmpty ? artifact.format.displayName : artifact.title,
                        subtitle: subtitle,
                        matchScore: tagMatchScore
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
    
    /// Calculate match score for tags array against query
    /// Returns 0.0 - 1.0, where 1.0 is exact tag match
    private func calculateTagMatchScore(tags: [String], query: String) -> Double {
        guard !tags.isEmpty else { return 0.0 }
        
        let lowerQuery = query.lowercased()
        var bestScore: Double = 0.0
        
        for tag in tags {
            let lowerTag = tag.lowercased()
            
            // Exact tag match
            if lowerTag == lowerQuery {
                bestScore = max(bestScore, 1.0)
            }
            // Tag starts with query
            else if lowerTag.hasPrefix(lowerQuery) {
                bestScore = max(bestScore, 0.9)
            }
            // Tag contains query
            else if lowerTag.contains(lowerQuery) {
                bestScore = max(bestScore, 0.7)
            }
            // Query contains tag (partial match)
            else if lowerQuery.contains(lowerTag) {
                bestScore = max(bestScore, 0.5)
            }
        }
        
        return bestScore
    }
}

