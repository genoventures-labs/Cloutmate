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
        case .post:
            postContent
        case .reminder:
            reminderContent
        case .inboxItem:
            inboxItemContent
        case .focusSession:
            focusSessionContent
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
                        Text(String(note.markdown.prefix(100)))
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
    
    private func navigateToItem() {
        let tab: TabIdentifier
        
        switch mention.type {
        case .task:
            tab = .tasks
        case .project:
            tab = .projects
        case .note:
            tab = .notes
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
    
    private func statusColor(_ status: TaskStatus) -> Color {
        switch status {
        case .todo: return .gray
        case .inProgress: return .kosmicBlue
        case .done: return .green
        case .cancelled: return .red
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


