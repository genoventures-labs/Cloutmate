//
//  ListTableView.swift
//  FocusOS
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers
import FocusOSShared

@available(*, deprecated, message: "Legacy list composer retained for archival access. Prefer V2 dashboards.")
struct ListTableView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Post.createdAt, order: .reverse) private var posts: [Post]
    @Query(sort: \Artifact.createdAt, order: .reverse) private var artifacts: [Artifact]
    
    @State private var searchText = ""
    @State private var selectedStatus: PostStatus?
    @State private var selectedFormat: OutputFormat?
    @State private var selectedPosts = Set<UUID>()
    @State private var selectedArtifacts = Set<UUID>()
    @State private var showComposer = false
    @State private var showArtifactComposer = false
    @State private var showDeleteAllConfirmation = false
    @State private var refreshID = UUID()
    @State private var selectedViewType: ViewType = .table
    @State private var showPropertyEditor = false
    @State private var postToEdit: Post?
    @State private var artifactToEdit: Artifact?
    
    enum ListItem: Identifiable {
        case post(Post)
        case artifact(Artifact)
        
        var id: UUID {
            switch self {
            case .post(let post): return post.id
            case .artifact(let artifact): return artifact.id
            }
        }
        
        var createdAt: Date {
            switch self {
            case .post(let post): return post.createdAt
            case .artifact(let artifact): return artifact.createdAt
            }
        }
    }
    
    var allItems: [ListItem] {
        var items: [ListItem] = []
        items.append(contentsOf: posts.map { .post($0) })
        items.append(contentsOf: artifacts.map { .artifact($0) })
        // Prioritize artifacts - show them first regardless of date
        return items.sorted { item1, item2 in
            switch (item1, item2) {
            case (.artifact, .post):
                return true // Artifacts first
            case (.post, .artifact):
                return false // Posts after artifacts
            default:
                // Within same type, sort by date (newest first)
                return item1.createdAt > item2.createdAt
            }
        }
    }
    
    var filteredItems: [ListItem] {
        var filtered = allItems
        
        if !searchText.isEmpty {
            filtered = filtered.filter { item in
                switch item {
                case .post(let post):
                    return post.caption.localizedCaseInsensitiveContains(searchText)
                case .artifact(let artifact):
                    return artifact.title.localizedCaseInsensitiveContains(searchText) ||
                           artifact.content.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
        
        if let status = selectedStatus {
            filtered = filtered.filter { item in
                if case .post(let post) = item {
                    return post.postStatus == status
                }
                return false
            }
        }
        
        if let format = selectedFormat {
            filtered = filtered.filter { item in
                if case .artifact(let artifact) = item {
                    return artifact.format == format
                }
                return false
            }
        }
        
        return filtered
    }
    
    private var searchAndFiltersSection: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search posts & artifacts...", text: $searchText)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "All",
                        isSelected: selectedStatus == nil && selectedFormat == nil,
                        action: { selectedStatus = nil; selectedFormat = nil }
                    )
                    
                    // Post Status filters
                    ForEach(PostStatus.allCases, id: \.self) { status in
                        FilterChip(
                            title: status.displayName,
                            isSelected: selectedStatus == status,
                            action: { 
                                selectedStatus = status
                                selectedFormat = nil
                            }
                        )
                    }
                    
                    // Output Format filters
                    ForEach(OutputFormat.allCases, id: \.self) { format in
                        FilterChip(
                            title: format.displayName,
                            isSelected: selectedFormat == format,
                            action: { 
                                selectedFormat = format
                                selectedStatus = nil
                            }
                        )
                    }
                }
            }
        }
        .padding()
    }
    
    private var tableSection: some View {
        Table(filteredItems, selection: Binding(
            get: { 
                var ids = Set<UUID>()
                ids.formUnion(selectedPosts)
                ids.formUnion(selectedArtifacts)
                return ids
            },
            set: { newSelection in
                selectedPosts.removeAll()
                selectedArtifacts.removeAll()
                for id in newSelection {
                    if posts.contains(where: { $0.id == id }) {
                        selectedPosts.insert(id)
                    } else if artifacts.contains(where: { $0.id == id }) {
                        selectedArtifacts.insert(id)
                    }
                }
            }
        )) {
            TableColumn("Content") { listItem in
                switch listItem {
                case .post(let post):
                    Text(post.caption)
                        .lineLimit(2)
                        .contextMenu {
                            Button("Edit") {
                                postToEdit = post
                            }
                            Button("Duplicate") {
                                duplicatePost(post)
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                deleteSinglePost(post)
                            }
                        }
                case .artifact(let artifact):
                    Text(artifact.title.isEmpty ? artifact.content.prefix(50).description : artifact.title)
                        .lineLimit(2)
                        .contextMenu {
                            Button("Edit") {
                                artifactToEdit = artifact
                            }
                            Button("Duplicate") {
                                duplicateArtifact(artifact)
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                deleteSingleArtifact(artifact)
                            }
                        }
                }
            }
            .width(min: 200, ideal: 300)
            
            TableColumn("Type") { listItem in
                switch listItem {
                case .post:
                    Text("Post")
                        .font(.caption)
                        .foregroundColor(.kosmicBlue)
                case .artifact(let artifact):
                    HStack(spacing: 4) {
                        Image(systemName: formatIcon(for: artifact.format))
                            .font(.caption2)
                        Text(artifact.format.displayName)
                            .font(.caption)
                    }
                    .foregroundColor(formatColor(for: artifact.format))
                }
            }
            .width(min: 120)
            
            TableColumn("Status") { listItem in
                switch listItem {
                case .post(let post):
                    PostStatusBadge(status: FocusOSShared.PostStatus(rawValue: post.status) ?? .draft)
                case .artifact(let artifact):
                    ArtifactStateBadge(state: artifact.artifactState)
                }
            }
            .width(min: 100)
            
            TableColumn("Date") { listItem in
                switch listItem {
                case .post(let post):
                    if let scheduledDate = post.scheduledDate {
                        Text(scheduledDate, format: .dateTime.month().day().hour().minute())
                    } else if let publishedDate = post.publishedDate {
                        Text(publishedDate, format: .dateTime.month().day().hour().minute())
                    } else {
                        Text("—")
                            .foregroundColor(.secondary)
                    }
                case .artifact(let artifact):
                    if let publishedAt = artifact.publishedAt {
                        Text(publishedAt, format: .dateTime.month().day().hour().minute())
                    } else {
                        Text(artifact.createdAt, format: .dateTime.month().day().hour().minute())
                            .foregroundColor(.secondary)
                    }
                }
            }
            .width(min: 150)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            DatabaseViewPicker(
                selectedView: $selectedViewType,
                onManageProperties: { showPropertyEditor = true }
            )
            .padding(.top)
            
            searchAndFiltersSection
            
            Group {
                switch selectedViewType {
                case .table:
                    if filteredItems.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: artifacts.isEmpty ? "sparkles" : "doc.text")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text(artifacts.isEmpty && posts.isEmpty ? "No Artifacts Yet" : "No matches")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text(artifacts.isEmpty && posts.isEmpty 
                                ? "Create your first artifact to get started with Aurora's cognitive workspace"
                                : "Try a different search or filter")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Create Artifact") {
                                showArtifactComposer = true
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else {
                        tableSection
                    }
                case .kanban:
                    // Kanban view only supports posts for now (backward compatibility)
                    KanbanBoardView(posts: filteredItems.compactMap { if case .post(let p) = $0 { return p }; return nil })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .gallery:
                    // Gallery view only supports posts for now (backward compatibility)
                    PostGalleryView(posts: filteredItems.compactMap { if case .post(let p) = $0 { return p }; return nil })
                case .timeline:
                    // Timeline view only supports posts for now (backward compatibility)
                    PostTimelineView(posts: filteredItems.compactMap { if case .post(let p) = $0 { return p }; return nil })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                @unknown default:
                    EmptyView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .background(Color(.windowBackgroundColor))
        .navigationTitle("List")
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshViewsFromMenuBar"))) { _ in
            // Refresh view when notification received from menu bar
            refreshID = UUID()
        }
        .id(refreshID)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !selectedPosts.isEmpty || !selectedArtifacts.isEmpty {
                    Menu("Actions") {
                        Button("Export", systemImage: "square.and.arrow.up") {
                            exportSelectedItems()
                        }
                        
                        Button("Delete Selected", systemImage: "trash") {
                            deleteSelectedItems()
                        }
                        
                        Button("Archive", systemImage: "archivebox") {
                            archiveSelectedItems()
                        }
                    }
                }
                
                Menu("New") {
                    Button("New Post") {
                        showComposer = true
                    }
                    Button("New Artifact") {
                        showArtifactComposer = true
                    }
                }
                
                if !filteredItems.isEmpty && (selectedPosts.count + selectedArtifacts.count) == filteredItems.count && filteredItems.count > 1 {
                    Button("Delete All", systemImage: "trash.fill") {
                        showDeleteAllConfirmation = true
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .alert("Delete All Items?", isPresented: $showDeleteAllConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive) {
                deleteAllItems()
            }
        } message: {
            Text("This will permanently delete all \(filteredItems.count) items shown in the list. This action cannot be undone.")
        }
        .sheet(isPresented: $showComposer) {
            ComposerWindow()
        }
        .sheet(isPresented: $showArtifactComposer) {
            ArtifactComposerView()
        }
        .sheet(item: $postToEdit) { post in
            ComposerWindow(existingPost: post)
        }
        .sheet(item: $artifactToEdit) { artifact in
            ArtifactComposerView(existingArtifact: artifact)
        }
        .sheet(isPresented: $showPropertyEditor) {
            CustomPropertyEditor()
        }
    }
    
    private func exportSelectedItems() {
        let selectedPostsList = posts.filter { selectedPosts.contains($0.id) }
        let selectedArtifactsList = artifacts.filter { selectedArtifacts.contains($0.id) }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "focusos-items-\(Date().formatted(date: .numeric, time: .omitted)).csv"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            
            var csvString = "Type,Title/Caption,Format/Platform,Status,Date,Published Date\n"
            
            for post in selectedPostsList {
                let scheduledDate = post.scheduledDate?.formatted() ?? ""
                let publishedDate = post.publishedDate?.formatted() ?? ""
                let escapedCaption = post.caption.replacingOccurrences(of: "\"", with: "\"\"")
                csvString += "Post,\"\(escapedCaption)\",\(post.postStatus.displayName),\(scheduledDate),\(publishedDate)\n"
            }
            
            for artifact in selectedArtifactsList {
                let title = (artifact.title.isEmpty ? artifact.content.prefix(50).description : artifact.title).replacingOccurrences(of: "\"", with: "\"\"")
                let publishedDate = artifact.publishedAt?.formatted() ?? ""
                csvString += "Artifact,\"\(title)\",\(artifact.format.displayName),\(artifact.artifactState.displayName),\(artifact.createdAt.formatted()),\(publishedDate)\n"
            }
            
            do {
                try csvString.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("Export error: \(error)")
            }
        }
    }
    
    private func deleteSelectedItems() {
        let postsToDelete = posts.filter { selectedPosts.contains($0.id) }
        let artifactsToDelete = artifacts.filter { selectedArtifacts.contains($0.id) }
        withAnimation {
            for post in postsToDelete {
                modelContext.delete(post)
            }
            for artifact in artifactsToDelete {
                modelContext.delete(artifact)
            }
            selectedPosts.removeAll()
            selectedArtifacts.removeAll()
        }
    }
    
    private func deleteAllItems() {
        withAnimation {
            for item in filteredItems {
                switch item {
                case .post(let post):
                    modelContext.delete(post)
                case .artifact(let artifact):
                    modelContext.delete(artifact)
                }
            }
            selectedPosts.removeAll()
            selectedArtifacts.removeAll()
        }
    }
    
    private func archiveSelectedItems() {
        let postsToArchive = posts.filter { selectedPosts.contains($0.id) }
        let artifactsToArchive = artifacts.filter { selectedArtifacts.contains($0.id) }
        withAnimation {
            for post in postsToArchive {
                post.postStatus = .published
                if !post.tags.contains("archived") {
                    post.tags.append("archived")
                }
            }
            for artifact in artifactsToArchive {
                artifact.artifactState = .archived
            }
            selectedPosts.removeAll()
            selectedArtifacts.removeAll()
        }
    }
    
    private func deleteSinglePost(_ post: Post) {
        withAnimation {
            modelContext.delete(post)
            selectedPosts.remove(post.id)
        }
    }
    
    private func deleteSingleArtifact(_ artifact: Artifact) {
        withAnimation {
            modelContext.delete(artifact)
            selectedArtifacts.remove(artifact.id)
        }
    }
    
    private func duplicatePost(_ post: Post) {
        let duplicatedPost = Post(
            caption: post.caption,
            mediaURLs: post.mediaURLs,
            scheduledDate: nil,
            status: PostStatus.draft.rawValue
        )
        modelContext.insert(duplicatedPost)
    }
    
    private func duplicateArtifact(_ artifact: Artifact) {
        let duplicatedArtifact = Artifact(
            title: artifact.title,
            content: artifact.content,
            mediaURLs: artifact.mediaURLs,
            outputFormat: artifact.format,
            state: .draft,
            tags: artifact.tags
        )
        modelContext.insert(duplicatedArtifact)
    }
    
    private func formatIcon(for format: OutputFormat) -> String {
        switch format {
        case .brief: return "doc.text"
        case .summary: return "doc.text.below.ecg"
        case .reflection: return "brain.head.profile"
        case .report: return "doc.text.magnifyingglass"
        case .releaseNote: return "megaphone"
        case .lessonLearned: return "lightbulb"
        }
    }
    
    private func formatColor(for format: OutputFormat) -> Color {
        switch format {
        case .brief: return .kosmicCyan
        case .summary: return .kosmicBlue
        case .reflection: return .kosmicPurple
        case .report: return .kosmicPurple
        case .releaseNote: return .kosmicGreen
        case .lessonLearned: return .orange
        }
    }
}

struct PostStatusBadge: View {
    let status: FocusOSShared.PostStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.2))
            .foregroundColor(status.color)
            .cornerRadius(6)
    }
}

extension FocusOSShared.PostStatus {
    var color: Color {
        switch self {
        case .draft: return .gray
        case .scheduled: return .kosmicBlue
        case .publishing: return .orange
        case .published: return .kosmicGreen
        case .failed: return .red
        @unknown default: return .gray
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ListTableView()
        .modelContainer(for: [Post.self, Artifact.self])
}

