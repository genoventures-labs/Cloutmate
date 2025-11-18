//
//  CalendarPostListSheet.swift
//  FocusOS
//
//  Post List Sheet for Calendar Dates
//

import SwiftUI
import FocusOSShared

struct CalendarPostListSheet: View {
    let date: Date
    let posts: [FocusOSShared.Post]
    @Binding var selectedPost: FocusOSShared.Post?
    @Binding var isPresented: Bool
    var onPostTap: ((FocusOSShared.Post) -> Void)?
    
    private var groupedPosts: [String: [FocusOSShared.Post]] {
        var result: [String: [FocusOSShared.Post]] = [:]
        
        for post in posts {
            // Group by status instead of platform
            let groupKey = post.postStatus.displayName
            if result[groupKey] == nil {
                result[groupKey] = []
            }
            result[groupKey]?.append(post)
        }
        
        return result
    }
    
    private let calendar = Calendar.current
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    Divider()
                    contentSection
                }
            }
            .padding(.horizontal)
            .padding(.top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .background(.ultraThinMaterial)
        }
        .frame(idealWidth: 500, minHeight: 400, idealHeight: 600, maxHeight: 800)
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Posts for")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(date, format: .dateTime.month(.wide).day().year())
                .font(.largeTitle)
                .fontWeight(.bold)
        }
        .padding(.bottom, 8)
    }
    
    @ViewBuilder
    private var contentSection: some View {
        if posts.isEmpty {
            emptyStateView
        } else {
            postsList
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No posts on this date")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var postsList: some View {
        ForEach(Array(groupedPosts.keys.sorted()), id: \.self) { groupKey in
            if let groupPosts = groupedPosts[groupKey] {
                platformPostsSection(platform: groupKey, posts: groupPosts)
            }
        }
    }
    
    private func platformPostsSection(platform: String, posts: [FocusOSShared.Post]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(platform)
                    .font(.headline)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.kosmicBlue, .kosmicPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Spacer()
                Text("\(posts.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
            
            ForEach(posts.sorted(by: { ($0.scheduledDate ?? Date()) < ($1.scheduledDate ?? Date()) })) { post in
                PostRow(post: post) {
                    selectedPost = post
                    onPostTap?(post)
                }
            }
        }
    }
}

struct PostRow: View {
    let post: FocusOSShared.Post
    let onTap: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Time
                VStack(alignment: .leading, spacing: 2) {
                    if let scheduledDate = post.scheduledDate {
                        Text(scheduledDate, format: .dateTime.hour().minute())
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    } else if let publishedDate = post.publishedDate {
                        Text(publishedDate, format: .dateTime.hour().minute())
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    PostStatusBadge(status: FocusOSShared.PostStatus(rawValue: post.status) ?? .draft)
                }
                .frame(width: 80, alignment: .leading)
                
                // Caption preview
                Text(post.caption)
                    .font(.subheadline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Engagement if available
                if let engagementRate = post.engagementRate {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f%%", engagementRate))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.kosmicGreen)
                        Text("Engagement")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(.thinMaterial)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHovered ? Color.kosmicBlue.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(GlassMotion.Easing.spring, value: isHovered)
    }
}

#Preview {
    CalendarPostListSheet(
        date: Date(),
        posts: [],
        selectedPost: .constant(nil),
        isPresented: .constant(true)
    )
}
