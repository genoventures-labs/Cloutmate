//
//  MentionPreviewCard.swift
//  Cloutmate
//
//  Inline preview card for mentioned items - shows badge + expandable popover
//

import SwiftUI
import SwiftData
import CloutmateShared

struct MentionPreviewCard: View {
    let mention: ResolvedMention
    @Environment(\.modelContext) private var modelContext
    @State private var showPopover = false
    @State private var hovered = false
    
    var body: some View {
        HStack(spacing: 4) {
            // Inline badge - always visible
            Button(action: {
                navigateToItem()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: mention.type.icon)
                        .font(.system(size: 10))
                        .foregroundColor(.kosmicBlue)
                    
                    Text(mention.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.kosmicBlue)
                        .lineLimit(1)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.kosmicBlue.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                hovered = hovering
                if hovering {
                    showPopover = true
                }
            }
            .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                MentionDetailPopover(mention: mention)
                    .frame(width: 300)
            }
        }
    }
    
    private func navigateToItem() {
        let tab: TabIdentifier
        
        switch mention.type {
        case .task:
            tab = .tasks
        case .project:
            tab = .projects
        case .note:
            tab = .notes
        case .artifact:
            tab = .posts
        case .area:
            tab = .areas
        case .post:
            tab = .posts
        case .reminder:
            tab = .inbox
        case .inboxItem:
            tab = .inbox
        case .focusSession:
            tab = .focusMode
        case .event:
            tab = .calendar
        }
        
        NotificationCenter.default.post(name: .switchTab, object: tab)
        
        // Post notification to select the specific item
        NotificationCenter.default.post(
            name: .openEntity,
            object: nil,
            userInfo: ["id": mention.id, "type": mention.type.rawValue]
        )
    }
}

struct MentionDetailPopover: View {
    let mention: ResolvedMention
    @Environment(\.modelContext) private var modelContext
    
    private let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: mention.type.icon)
                    .foregroundColor(.kosmicBlue)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(mention.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(mention.type.rawValue.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            // Type-specific content
            typeSpecificContent
            
            // Actions
            HStack {
                Button("Open") {
                    navigateToItem()
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var typeSpecificContent: some View {
        switch mention.type {
        case .task:
            taskContent
        case .project:
            projectContent
        case .note:
            noteContent
        case .artifact:
            artifactContent
        case .area:
            areaContent
        case .post:
            postContent
        case .reminder:
            reminderContent
        case .inboxItem:
            inboxItemContent
        case .focusSession:
            focusSessionContent
        case .event:
            eventContent
        }
    }
    
    private var taskContent: some View {
        Group {
            if let task = fetchTask() {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        StatusBadge(status: task.status.displayName, color: statusColor(task.status))
                        PriorityBadge(priority: task.priority.displayName, color: task.priority.color)
                    }
                    
                    if let dueDate = task.dueDate {
                        Label(dueDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let notes = task.notes, !notes.isEmpty {
                        Text(String(notes.prefix(100)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                }
            }
        }
    }
    
    private var projectContent: some View {
        Group {
            if let project = fetchProject() {
                VStack(alignment: .leading, spacing: 8) {
                    StatusBadge(status: project.status.displayName, color: .kosmicBlue)
                    
                    if let goal = project.goal, !goal.isEmpty {
                        Text(String(goal.prefix(100)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                    
                    HStack(spacing: 16) {
                        Label("\(project.taskIds.count) tasks", systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Label("\(project.noteIds.count) notes", systemImage: "note.text")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var noteContent: some View {
        Group {
            if let note = fetchNote() {
                VStack(alignment: .leading, spacing: 8) {
                    if !note.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(note.tags.prefix(5), id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                    
                    if !note.markdown.isEmpty {
                        Text(cleanPreview(note.markdown))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                    
                    Label(note.createdAt.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func cleanPreview(_ text: String) -> String {
        var cleaned = MentionService.shared.convertToDisplayNames(
            text: text,
            modelContext: modelContext
        )
        cleaned = MentionParser.stripTerminators(from: cleaned)
        let structuredPattern = #"@\{[^}]+\}"#
        cleaned = cleaned.replacingOccurrences(of: structuredPattern, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "No description available" : String(cleaned.prefix(100))
    }
    
    private var postContent: some View {
        Group {
            if let post = fetchPost() {
                VStack(alignment: .leading, spacing: 8) {
                    StatusBadge(status: post.postStatus.displayName, color: .kosmicBlue)
                    
                    if let publishedDate = post.publishedDate {
                        Label(publishedDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var reminderContent: some View {
        Group {
            if let reminder = fetchReminder() {
                VStack(alignment: .leading, spacing: 8) {
                    StatusBadge(
                        status: reminder.isCompleted ? "Completed" : "Pending",
                        color: reminder.isCompleted ? .green : .orange
                    )
                }
            }
        }
    }
    
    private var inboxItemContent: some View {
        Group {
            if let item = fetchInboxItem() {
                VStack(alignment: .leading, spacing: 8) {
                    StatusBadge(
                        status: item.convertedAt == nil ? "Unconverted" : "Converted",
                        color: item.convertedAt == nil ? .orange : .green
                    )
                    
                    Text(String(item.content.prefix(100)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }
        }
    }
    
    private var focusSessionContent: some View {
        Group {
            if let session = fetchFocusSession() {
                VStack(alignment: .leading, spacing: 8) {
                    StatusBadge(status: session.status.rawValue.capitalized, color: .kosmicBlue)
                    Label(session.durationFormatted, systemImage: "timer")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var eventContent: some View {
        Group {
            if let event = fetchEvent() {
                VStack(alignment: .leading, spacing: 8) {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = event.allDay ? .none : .short
                    
                    Label(
                        event.allDay ? "All-day" : "\(formatter.string(from: event.startDate)) – \(formatter.string(from: event.endDate))",
                        systemImage: event.allDay ? "sun.max.fill" : "clock"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    if let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let recurrence = event.recurrence {
                        Label(recurrenceDescription(for: recurrence), systemImage: "arrow.2.squarepath")
                            .font(.caption)
                            .foregroundColor(.cyan)
                    }
                    
                    if let notes = event.notes, !notes.isEmpty {
                        Text(String(notes.prefix(160)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                }
            } else {
                Text("Cannot load event details")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var areaContent: some View {
        Group {
            if let area = fetchArea() {
                VStack(alignment: .leading, spacing: 8) {
                    StatusBadge(status: areaStatusLabel(area.status), color: areaStatusColor(area.status))
                    
                    if let lastReview = area.lastReviewDate {
                        Label("Reviewed \(relativeFormatter.localizedString(for: lastReview, relativeTo: Date()))", systemImage: "clock.arrow.circlepath")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if area.stabilityScore > 0 {
                        Label("\(Int(area.stabilityScore.rounded())) Stability", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let notes = area.notes, !notes.isEmpty {
                        Text(String(notes.prefix(160)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                    
                    if !area.tags.isEmpty {
                        tagWrapLayout(for: area.tags)
                    }
                }
            } else {
                Text("Cannot load area details")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func areaStatusLabel(_ status: AreaStatus) -> String {
        switch status {
        case .active: return "Active"
        case .archived: return "Archived"
        case .reviewNeeded: return "Needs Review"
        }
    }
    
    private func areaStatusColor(_ status: AreaStatus) -> Color {
        switch status {
        case .active: return .kosmicBlue
        case .archived: return .gray
        case .reviewNeeded: return .orange
        }
    }
    
    private func navigateToItem() {
        let tab: TabIdentifier
        
        switch mention.type {
        case .task:
            tab = .tasks
        case .project:
            tab = .projects
        case .note:
            tab = .notes
        case .artifact:
            tab = .posts
        case .area:
            tab = .areas
        case .post:
            tab = .posts
        case .reminder:
            tab = .inbox
        case .inboxItem:
            tab = .inbox
        case .focusSession:
            tab = .focusMode
        }
        
        NotificationCenter.default.post(name: .switchTab, object: tab)
        NotificationCenter.default.post(
            name: .openEntity,
            object: nil,
            userInfo: ["id": mention.id, "type": mention.type.rawValue]
        )
    }
    
    // MARK: - Fetch Helpers
    
    private func fetchTask() -> CloutmateShared.Task? {
        let id = mention.id
        let descriptor = FetchDescriptor<CloutmateShared.Task>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    private func fetchProject() -> CloutmateShared.Project? {
        let id = mention.id
        let descriptor = FetchDescriptor<CloutmateShared.Project>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    private func fetchProject(by id: UUID) -> CloutmateShared.Project? {
        let descriptor = FetchDescriptor<CloutmateShared.Project>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    private func fetchArea() -> Area? {
        let id = mention.id
        let descriptor = FetchDescriptor<Area>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    private func fetchNote() -> CloutmateShared.Note? {
        let id = mention.id
        let descriptor = FetchDescriptor<CloutmateShared.Note>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    private func fetchPost() -> CloutmateShared.Post? {
        let id = mention.id
        let descriptor = FetchDescriptor<CloutmateShared.Post>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    private func fetchReminder() -> CloutmateShared.Reminder? {
        let id = mention.id
        let descriptor = FetchDescriptor<CloutmateShared.Reminder>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    private func fetchInboxItem() -> CloutmateShared.InboxItem? {
        let id = mention.id
        let descriptor = FetchDescriptor<CloutmateShared.InboxItem>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    private func fetchFocusSession() -> FocusSession? {
        let id = mention.id
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    private func fetchEvent() -> CalendarEvent? {
        let id = mention.id
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    private func statusColor(_ status: TaskStatus) -> Color {
        switch status {
        case .todo: return .gray
        case .inProgress: return .kosmicBlue
        case .done: return .green
        case .cancelled: return .red
        }
    }
    
    private var summaryText: String {
        switch mention.type {
        case .task:
            return fetchTask()?.notes ?? ""
        case .project:
            return fetchProject()?.goal ?? ""
        case .note:
            return fetchNote()?.markdown ?? ""
        case .artifact:
            return fetchArtifact()?.content ?? ""
        case .area:
            return fetchArea()?.notes ?? ""
        case .post:
            return fetchPost()?.caption ?? ""
        case .reminder:
            return fetchReminder()?.notes ?? ""
        case .inboxItem:
            return fetchInboxItem()?.content ?? ""
        case .focusSession:
            return fetchFocusSession()?.objective ?? ""
        case .event:
            return fetchEvent()?.notes ?? ""
        }
    }
    
    private func fetchArtifact() -> CloutmateShared.Artifact? {
        let id = mention.id
        let descriptor = FetchDescriptor<CloutmateShared.Artifact>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    private func recurrenceDescription(for recurrence: EventRecurrence) -> String {
        switch recurrence.frequency {
        case .daily:
            return recurrence.interval == 1 ? "Daily" : "Every \(recurrence.interval) days"
        case .weekly:
            let weekdays = recurrence.weekdays?.compactMap { weekdayName(from: $0) } ?? []
            let frequency = recurrence.interval == 1 ? "Weekly" : "Every \(recurrence.interval) weeks"
            if !weekdays.isEmpty {
                return "\(frequency) on \(weekdays.joined(separator: ", "))"
            }
            return frequency
        case .monthly:
            return recurrence.interval == 1 ? "Monthly" : "Every \(recurrence.interval) months"
        case .yearly:
            return recurrence.interval == 1 ? "Yearly" : "Every \(recurrence.interval) years"
        }
    }
    
    private func weekdayName(from value: Int) -> String? {
        guard value >= 1 && value <= 7 else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.weekdaySymbols[value - 1]
    }
    
    @ViewBuilder
    private var artifactContent: some View {
        if let artifact = fetchArtifact() {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    StatusBadge(status: artifact.artifactState.displayName, color: artifactStatusColor(artifact.artifactState))
                    Label(artifact.format.displayName, systemImage: "doc.richtext")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(cleanArtifactDescription(artifact.content))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                if let projectId = artifact.projectId,
                   let project = fetchProject(by: projectId) {
                    Label(project.title, systemImage: "folder.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if !artifact.tags.isEmpty {
                    tagWrapLayout(for: artifact.tags)
                }
            }
        } else {
            Text("Cannot load artifact details")
                .foregroundStyle(.secondary)
        }
    }
    
    private func artifactStatusColor(_ state: ArtifactState) -> Color {
        switch state {
        case .idea: return .orange
        case .draft: return .kosmicBlue
        case .final: return .green
        case .published: return .purple
        case .archived: return .gray
        }
    }
    
    private func cleanArtifactDescription(_ text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .split(separator: " ")
            .map(String.init)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "No description available" }
        return String(cleaned.prefix(200))
    }
    
    private func tagWrapLayout(for tags: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags.prefix(8), id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(4)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct StatusBadge: View {
    let status: String
    let color: Color
    
    var body: some View {
        Text(status)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

struct PriorityBadge: View {
    let priority: String
    let color: Color
    
    var body: some View {
        Text(priority)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}


