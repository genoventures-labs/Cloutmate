//
//  CommandPaletteView.swift
//  FocusOS
//
//  Global Command Palette (⌘+K)
//

import SwiftUI
import SwiftData
import FocusOSShared

enum SearchCategory: Hashable {
    case conversations
    case drafts
    case posts
    case projects
    case tasks
    case notes
    case inbox
    case all
    
    var title: String {
        switch self {
        case .conversations: return "Conversations"
        case .drafts: return "Drafts"
        case .posts: return "Posts"
        case .projects: return "Projects"
        case .tasks: return "Tasks"
        case .notes: return "Notes"
        case .inbox: return "Inbox"
        case .all: return "All"
        }
    }
    
    var icon: String {
        switch self {
        case .conversations: return "bubble.left.and.bubble.right"
        case .drafts: return "doc.text"
        case .posts: return "square.and.pencil"
        case .projects: return "folder.fill"
        case .tasks: return "checkmark.circle"
        case .notes: return "doc.text.fill"
        case .inbox: return "tray.fill"
        case .all: return "magnifyingglass"
        }
    }
}

struct CommandPaletteView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \AIConversation.createdAt, order: .reverse) private var conversations: [AIConversation]
    @Query(sort: \Draft.updatedAt, order: .reverse) private var drafts: [Draft]
    @Query(sort: \FocusOSShared.Post.createdAt, order: .reverse) private var posts: [FocusOSShared.Post]
    @Query(sort: \FocusOSShared.Project.updatedAt, order: .reverse) private var projects: [FocusOSShared.Project]
    @Query(sort: \FocusOSShared.Task.createdAt, order: .reverse) private var tasks: [FocusOSShared.Task]
    @Query(sort: \FocusOSShared.Note.updatedAt, order: .reverse) private var notes: [FocusOSShared.Note]
    @Query(sort: \FocusOSShared.InboxItem.createdAt, order: .reverse) private var inboxItems: [FocusOSShared.InboxItem]
    
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var selectedCategory: SearchCategory = .all
    @State private var selectedIndex = 0
    @State private var dateRangeFilter: DateRangeFilter = .all
    @State private var showDateFilter = false
    
    var filteredResults: [SearchResult] {
        let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        
        if query.isEmpty {
            return []
        }
        
        var results: [SearchResult] = []
        
        // Search Conversations
        if selectedCategory == .all || selectedCategory == .conversations {
            let conversationResults = conversations.filter { conversation in
                guard let title = conversation.title else { return false }
                if title.lowercased().contains(query) { return true }
                
                if let summary = conversation.summary, summary.lowercased().contains(query) {
                    return true
                }
                
                if let messages = conversation.messages {
                    return messages.contains { message in
                        guard let content = message.content else { return false }
                        return content.lowercased().contains(query)
                    }
                }
                
                return false
            }.prefix(5).map { conversation in
                SearchResult(
                    id: conversation.id.uuidString,
                    title: conversation.title ?? "Untitled",
                    subtitle: conversation.summary ?? "No summary",
                    category: .conversations,
                    entity: conversation
                )
            }
            results.append(contentsOf: conversationResults)
        }
        
        // Search Drafts
        if selectedCategory == .all || selectedCategory == .drafts {
            let draftResults = drafts.filter { draft in
                draft.caption.lowercased().contains(query) ||
                draft.tags.contains(where: { $0.lowercased().contains(query) })
            }.prefix(5).map { draft in
                SearchResult(
                    id: draft.id.uuidString,
                    title: draft.caption.isEmpty ? "Empty Draft" : String(draft.caption.prefix(50)),
                    subtitle: "Draft · \(draft.tags.joined(separator: ", "))",
                    category: .drafts,
                    entity: draft
                )
            }
            results.append(contentsOf: draftResults)
        }
        
        // Search Posts
        if selectedCategory == .all || selectedCategory == .posts {
            let postResults = posts.filter { post in
                post.caption.lowercased().contains(query) ||
                post.tags.contains(where: { $0.lowercased().contains(query) })
            }.prefix(5).map { post in
                SearchResult(
                    id: post.id.uuidString,
                    title: post.caption.isEmpty ? "Empty Post" : String(post.caption.prefix(50)),
                    subtitle: post.postStatus.displayName,
                    category: .posts,
                    entity: post
                )
            }
            results.append(contentsOf: postResults)
        }
        
        // Search Projects
        if selectedCategory == .all || selectedCategory == .projects {
            let projectResults = projects.filter { project in
                project.title.lowercased().contains(query) ||
                project.goal?.lowercased().contains(query) ?? false ||
                project.tags.contains(where: { $0.lowercased().contains(query) })
            }.prefix(5).map { project in
                SearchResult(
                    id: project.id.uuidString,
                    title: project.title,
                    subtitle: project.status.displayName + (project.goal != nil ? " · \(String(project.goal!.prefix(40)))" : ""),
                    category: .projects,
                    entity: project
                )
            }
            results.append(contentsOf: projectResults)
        }
        
        // Search Tasks
        if selectedCategory == .all || selectedCategory == .tasks {
            let taskResults = tasks.filter { task in
                task.title.lowercased().contains(query) ||
                task.notes?.lowercased().contains(query) ?? false
            }.prefix(5).map { task in
                SearchResult(
                    id: task.id.uuidString,
                    title: task.title,
                    subtitle: task.status.displayName + " · " + task.priority.displayName,
                    category: .tasks,
                    entity: task
                )
            }
            results.append(contentsOf: taskResults)
        }
        
        // Search Notes
        if selectedCategory == .all || selectedCategory == .notes {
            let noteResults = notes.filter { note in
                note.title.lowercased().contains(query) ||
                note.markdown.lowercased().contains(query) ||
                note.tags.contains(where: { $0.lowercased().contains(query) })
            }.prefix(5).map { note in
                let displayMarkdown = MentionParser.stripTerminators(
                    from: MentionService.shared.convertToDisplayNames(
                        text: note.markdown,
                        modelContext: modelContext
                    )
                )
                let subtitleText = displayMarkdown.isEmpty ? "No content" : String(displayMarkdown.prefix(50))
                return SearchResult(
                    id: note.id.uuidString,
                    title: note.title,
                    subtitle: subtitleText,
                    category: .notes,
                    entity: note
                )
            }
            for result in noteResults {
                results.append(result)
            }
        }
        
        // Search Inbox Items
        if selectedCategory == .all || selectedCategory == .inbox {
            let inboxResults = inboxItems.filter { item in
                item.content.lowercased().contains(query)
            }.prefix(5).map { item in
                SearchResult(
                    id: item.id.uuidString,
                    title: String(item.content.prefix(50)),
                    subtitle: item.convertedAt == nil ? "Unconverted" : "Converted to \(item.convertedToType ?? "unknown")",
                    category: .inbox,
                    entity: item
                )
            }
            results.append(contentsOf: inboxResults)
        }
        
        return Array(results.prefix(10))
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            VStack(spacing: 0) {
                // Search Bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.title3)
                    
                    TextField("Search everything...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .focused($isSearchFocused)
                    
                    // Category Filter
                    Menu {
                        ForEach([
                            SearchCategory.all, .conversations, .drafts, .posts,
                            .projects, .tasks, .notes, .inbox
                        ], id: \.self) { category in
                            Button(action: {
                                selectedCategory = category
                            }) {
                                Label(category.title, systemImage: selectedCategory == category ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Image(systemName: selectedCategory.icon)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .menuStyle(.borderlessButton)
                }
                .padding()
                .background(.regularMaterial)
                .overlay(
                    Divider(),
                    alignment: .bottom
                )
                
                // Results
                if !filteredResults.isEmpty {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(filteredResults) { result in
                                SearchResultRow(result: result) {
                                    handleResultSelection(result)
                                }
                                
                                if result != filteredResults.last {
                                    Divider()
                                        .padding(.leading, 52)
                                }
                            }
                        }
                    }
                    .frame(height: 400)
                } else if !searchText.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No results found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 400)
                }
                
                // Footer
                HStack {
                    Text("Press ⌘+K to open")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("ESC to close")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .background(.regularMaterial)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.3), radius: 20)
            .frame(width: 600)
        }
        .onAppear {
            isSearchFocused = true
        }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
    }
    
    private func handleResultSelection(_ result: SearchResult) {
        // Switch to appropriate tab and show result
        switch result.category {
        case .conversations:
            NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.aiAssistant)
        case .drafts:
            NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.drafts)
        case .posts:
            NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.posts)
        case .projects:
            NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.projects)
        case .tasks:
            NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.home)
        case .notes:
            NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.resources)
        case .inbox:
            NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.inbox)
        case .all:
            break
        }
        
        isPresented = false
    }
}

struct SearchResult: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let category: SearchCategory
    let entity: Any
    
    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.id == rhs.id
    }
}

struct SearchResultRow: View {
    let result: SearchResult
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: result.category.icon)
                    .font(.title3)
                    .foregroundColor(.kosmicBlue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(result.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

enum DateRangeFilter: String, CaseIterable {
    case all = "All Time"
    case today = "Today"
    case week = "This Week"
    case month = "This Month"
    case year = "This Year"
    
    var dateRange: (start: Date, end: Date) {
        let now = Date()
        let calendar = Calendar.current
        
        switch self {
        case .all:
            return (start: Date.distantPast, end: now)
        case .today:
            let start = calendar.startOfDay(for: now)
            return (start: start, end: now)
        case .week:
            if let start = calendar.date(byAdding: .day, value: -7, to: now) {
                return (start: start, end: now)
            }
            return (start: Date.distantPast, end: now)
        case .month:
            if let start = calendar.date(byAdding: .month, value: -1, to: now) {
                return (start: start, end: now)
            }
            return (start: Date.distantPast, end: now)
        case .year:
            if let start = calendar.date(byAdding: .year, value: -1, to: now) {
                return (start: start, end: now)
            }
            return (start: Date.distantPast, end: now)
        }
    }
}

#Preview {
    CommandPaletteView(isPresented: .constant(true))
        .modelContainer(for: [AIConversation.self, Draft.self, Post.self])
}
