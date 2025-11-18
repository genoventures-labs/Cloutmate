//
//  PostPreviewSheet.swift
//  FocusOS
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import FocusOSShared

struct PostPreviewSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Binding var post: FocusOSShared.Post?
    @State private var showingComposer = false
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        if let post = post {
            postContent(post)
        }
    }
    
    private func postContent(_ post: FocusOSShared.Post) -> some View {
        NavigationStack {
            Form {
                captionSection(post)
                scheduleSection(post)
                publishedSection(post)
                statusSection(post)
                engagementSection(post)
                mediaSection(post)
                tagsSection(post)
            }
            .formStyle(.grouped)
            .navigationTitle("Post Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Edit") {
                        showingComposer = true
                    }
                }
                
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .sheet(isPresented: $showingComposer) {
                ComposerWindow(existingPost: post)
            }
            .alert("Delete Post?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deletePost()
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }
    
    private func captionSection(_ post: FocusOSShared.Post) -> some View {
        Section("Caption") {
            Text(post.caption)
                .textSelection(.enabled)
            
            Text("\(post.caption.count) characters")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private func scheduleSection(_ post: FocusOSShared.Post) -> some View {
        if let scheduledDate = post.scheduledDate {
            Section("Scheduled") {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.accentColor)
                    
                    Text(scheduledDate, style: .date)
                        .font(.body)
                    
                    Spacer()
                    
                    Text(scheduledDate, style: .time)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                if scheduledDate < Date() {
                    Label("Past due", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
    }
    
    @ViewBuilder
    private func publishedSection(_ post: FocusOSShared.Post) -> some View {
        if let publishedDate = post.publishedDate {
            Section("Published") {
                Text(publishedDate, style: .date)
                
                Text(publishedDate, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func statusSection(_ post: FocusOSShared.Post) -> some View {
        Section("Status") {
            PostStatusBadge(status: post.postStatus)
        }
    }
    
    @ViewBuilder
    private func engagementSection(_ post: FocusOSShared.Post) -> some View {
        if post.engagementRate != nil || post.likes != nil {
            Section("Engagement Metrics") {
                if let engagementRate = post.engagementRate {
                    MetricRow(icon: "chart.line.uptrend.xyaxis", title: "Engagement Rate", value: String(format: "%.2f%%", engagementRate))
                }
                
                if let impressions = post.impressions {
                    MetricRow(icon: "eye", title: "Impressions", value: "\(impressions)")
                }
                
                if let likes = post.likes {
                    MetricRow(icon: "heart.fill", title: "Likes", value: "\(likes)")
                }
                
                if let comments = post.comments {
                    MetricRow(icon: "bubble.left", title: "Comments", value: "\(comments)")
                }
                
                if let reach = post.reach {
                    MetricRow(icon: "person.3", title: "Reach", value: "\(reach)")
                }
            }
        }
    }
    
    @ViewBuilder
    private func mediaSection(_ post: FocusOSShared.Post) -> some View {
        if !post.mediaURLs.isEmpty {
            Section("Media Attachments") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(post.mediaURLs, id: \.self) { urlString in
                            MediaPreviewView(url: URL(fileURLWithPath: urlString), onRemove: {})
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    @ViewBuilder
    private func tagsSection(_ post: FocusOSShared.Post) -> some View {
        if !post.tags.isEmpty {
            Section("Tags") {
                HStack {
                    ForEach(post.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundColor(.accentColor)
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    private func deletePost() {
        if let post = post {
            modelContext.delete(post)
            dismiss()
        }
    }
}

struct PostStatusRow: View {
    let status: FocusOSShared.PostStatus
    
    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(status.displayName)
                .font(.body)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var statusColor: Color {
        switch status {
        case .draft:
            return .gray
        case .scheduled:
            return .kosmicBlue
        case .publishing:
            return .orange
        case .published:
            return .kosmicGreen
        case .failed:
            return .red
        @unknown default:
            return .gray
        }
    }
}

struct MetricRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            Text(title)
            
            Spacer()
            
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    PostPreviewSheet(post: .constant(FocusOSShared.Post(caption: "Test caption")))
        .modelContainer(for: [FocusOSShared.Post.self])
}

