//
//  ListTableView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct ListTableView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Post.createdAt, order: .reverse) private var posts: [Post]
    
    @State private var searchText = ""
    @State private var selectedStatus: PostStatus?
    @State private var selectedPlatform: Platform?
    @State private var selectedPosts = Set<UUID>()
    @State private var showComposer = false
    
    var filteredPosts: [Post] {
        var filtered = posts
        
        if !searchText.isEmpty {
            filtered = filtered.filter { $0.caption.localizedCaseInsensitiveContains(searchText) }
        }
        
        if let status = selectedStatus {
            filtered = filtered.filter { $0.postStatus == status }
        }
        
        if let platform = selectedPlatform {
            filtered = filtered.filter { $0.postPlatforms.contains(platform) }
        }
        
        return filtered
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search and filters
            VStack(spacing: 12) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search posts...", text: $searchText)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            title: "All",
                            isSelected: selectedStatus == nil && selectedPlatform == nil,
                            action: { selectedStatus = nil; selectedPlatform = nil }
                        )
                        
                        ForEach(PostStatus.allCases, id: \.self) { status in
                            FilterChip(
                                title: status.displayName,
                                isSelected: selectedStatus == status,
                                action: { selectedStatus = status }
                            )
                        }
                        
                        ForEach(Platform.allCases, id: \.self) { platform in
                            FilterChip(
                                title: platform.displayName,
                                isSelected: selectedPlatform == platform,
                                action: { selectedPlatform = platform }
                            )
                        }
                    }
                }
            }
            .padding()
            
            // Table
            Table(filteredPosts, selection: $selectedPosts) {
                TableColumn("Caption") { post in
                    Text(post.caption)
                        .lineLimit(2)
                }
                
                TableColumn("Platform") { post in
                    HStack(spacing: 4) {
                        ForEach(post.postPlatforms, id: \.self) { platform in
                            Text(platform.displayName)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(platform == .threads ? Color.purple.opacity(0.2) : Color.blue.opacity(0.2))
                                .foregroundColor(platform == .threads ? .purple : .blue)
                                .cornerRadius(4)
                        }
                    }
                }
                
                TableColumn("Status") { post in
                    StatusBadge(status: post.postStatus)
                }
                
                TableColumn("Scheduled") { post in
                    if let scheduledDate = post.scheduledDate {
                        Text(scheduledDate, format: .dateTime.month().day().hour().minute())
                    } else {
                        Text("—")
                            .foregroundColor(.secondary)
                    }
                }
                
                TableColumn("Engagement") { post in
                    if let engagementRate = post.engagementRate {
                        Text(String(format: "%.1f%%", engagementRate))
                    } else {
                        Text("—")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("List")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !selectedPosts.isEmpty {
                    Menu("Actions") {
                        Button("Export", systemImage: "square.and.arrow.up") {
                            exportSelectedPosts()
                        }
                        
                        Button("Delete", systemImage: "trash") {
                            deleteSelectedPosts()
                        }
                        
                        Button("Archive", systemImage: "archivebox") {
                            archiveSelectedPosts()
                        }
                    }
                }
                
                Button("New Post") {
                    showComposer = true
                }
            }
        }
        .sheet(isPresented: $showComposer) {
            ComposerWindow()
        }
    }
    
    private func exportSelectedPosts() {
        let selectedPostsList = posts.filter { selectedPosts.contains($0.id) }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "cloutmate-posts-\(Date().formatted(date: .numeric, time: .omitted)).csv"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            
            var csvString = "Caption,Platform,Status,Scheduled Date,Published Date,Engagement Rate,Likes,Comments,Reach\n"
            
            for post in selectedPostsList {
                let platforms = post.postPlatforms.map { $0.displayName }.joined(separator: "|")
                let scheduledDate = post.scheduledDate?.formatted() ?? ""
                let publishedDate = post.publishedDate?.formatted() ?? ""
                let engagementRate = post.engagementRate.map { String(format: "%.2f", $0) } ?? ""
                let likes = post.likes.map { String($0) } ?? ""
                let comments = post.comments.map { String($0) } ?? ""
                let reach = post.reach.map { String($0) } ?? ""
                
                let escapedCaption = post.caption.replacingOccurrences(of: "\"", with: "\"\"")
                csvString += "\"\(escapedCaption)\",\(platforms),\(post.postStatus.displayName),\(scheduledDate),\(publishedDate),\(engagementRate),\(likes),\(comments),\(reach)\n"
            }
            
            do {
                try csvString.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("Export error: \(error)")
            }
        }
    }
    
    private func deleteSelectedPosts() {
        let postsToDelete = posts.filter { selectedPosts.contains($0.id) }
        withAnimation {
            for post in postsToDelete {
                modelContext.delete(post)
            }
            selectedPosts.removeAll()
        }
    }
    
    private func archiveSelectedPosts() {
        let postsToArchive = posts.filter { selectedPosts.contains($0.id) }
        withAnimation {
            for post in postsToArchive {
                post.postStatus = .published
                // Add tag to indicate archived
                if !post.tags.contains("archived") {
                    post.tags.append("archived")
                }
            }
            selectedPosts.removeAll()
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
        .modelContainer(for: [Post.self])
}

