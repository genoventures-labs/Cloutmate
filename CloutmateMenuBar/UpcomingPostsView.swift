//
//  UpcomingPostsView.swift
//  CloutmateMenuBar
//

import SwiftUI
import SwiftData
import CloutmateShared

struct UpcomingPostsView: View {
    @Query(filter: #Predicate<CloutmateShared.Post> { post in
        post.status == "scheduled"
    }, sort: \.scheduledDate) var scheduledPosts: [CloutmateShared.Post]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if scheduledPosts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No scheduled posts")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("Schedule a post to see it here")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                } else {
                    ForEach(scheduledPosts.prefix(5), id: \.id) { post in
                        PostCard(post: post)
                    }
                }
            }
            .padding()
        }
    }
}

struct PostCard: View {
    let post: CloutmateShared.Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Time and status
            HStack {
                if let scheduledDate = post.scheduledDate {
                    Text(scheduledDate, style: .time)
                        .font(.system(size: 14, weight: .semibold))
                }
                Spacer()
                StatusBadge(status: post.postStatus)
            }
            
            // Caption preview
            Text(post.caption)
                .font(.system(size: 13))
                .lineLimit(2)
                .foregroundColor(.primary)
            
            // Platforms
            HStack(spacing: 4) {
                ForEach(post.postPlatforms, id: \.self) { platform in
                    Text(platform == .threads ? "T" : "F")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(platform == .threads ? Color.purple : Color.blue)
                        )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

struct StatusBadge: View {
    let status: CloutmateShared.PostStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(status == .scheduled ? Color.blue.opacity(0.2) : Color.clear)
            )
            .foregroundColor(status == .scheduled ? .blue : .secondary)
    }
}

#Preview {
    UpcomingPostsView()
        .modelContainer(for: [CloutmateShared.Post.self, CloutmateShared.Draft.self])
}

