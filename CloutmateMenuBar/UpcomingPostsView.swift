//
//  UpcomingPostsView.swift
//  CloutmateMenuBar
//
//  Shows upcoming artifacts and scheduled items
//

import SwiftUI
import SwiftData
import CloutmateShared

struct UpcomingPostsView: View {
    @Query(filter: #Predicate<CloutmateShared.Artifact> { artifact in
        artifact.artifactState == .published || artifact.artifactState == .final
    }, sort: \.publishedAt) var publishedArtifacts: [CloutmateShared.Artifact]
    
    @Query(filter: #Predicate<CloutmateShared.Post> { post in
        post.status == "scheduled"
    }, sort: \.scheduledDate) var scheduledPosts: [CloutmateShared.Post]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Show scheduled posts (backward compatibility)
                if !scheduledPosts.isEmpty {
                    ForEach(scheduledPosts.prefix(3), id: \.id) { post in
                        PostCard(post: post)
                    }
                }
                
                // Show recent artifacts
                if !publishedArtifacts.isEmpty {
                    ForEach(publishedArtifacts.prefix(5), id: \.id) { artifact in
                        ArtifactCard(artifact: artifact)
                    }
                }
                
                if scheduledPosts.isEmpty && publishedArtifacts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No upcoming items")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("Create an artifact to see it here")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                }
            }
            .padding()
        }
    }
}

struct ArtifactCard: View {
    let artifact: CloutmateShared.Artifact
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Time and format
            HStack {
                if let publishedAt = artifact.publishedAt {
                    Text(publishedAt, style: .time)
                        .font(.system(size: 14, weight: .semibold))
                }
                Spacer()
                ArtifactStateBadge(state: artifact.artifactState)
            }
            
            // Title/content preview
            Text(artifact.title.isEmpty ? artifact.content.prefix(50).description : artifact.title)
                .font(.system(size: 13))
                .lineLimit(2)
                .foregroundColor(.primary)
            
            // Format badge
            HStack(spacing: 4) {
                Image(systemName: formatIcon)
                    .font(.system(size: 10))
                Text(artifact.format.displayName)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(formatColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(formatColor.opacity(0.15))
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var formatIcon: String {
        switch artifact.format {
        case .brief: return "doc.text"
        case .summary: return "doc.text.below.ecg"
        case .reflection: return "brain.head.profile"
        case .report: return "doc.text.magnifyingglass"
        case .releaseNote: return "megaphone"
        case .lessonLearned: return "lightbulb"
        }
    }
    
    private var formatColor: Color {
        switch artifact.format {
        case .brief: return .cyan
        case .summary: return .blue
        case .reflection: return .purple
        case .report: return .indigo
        case .releaseNote: return .green
        case .lessonLearned: return .orange
        }
    }
}

struct ArtifactStateBadge: View {
    let state: ArtifactState
    
    var body: some View {
        Text(state.displayName)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(state == .published ? Color.green.opacity(0.2) : Color.clear)
            )
            .foregroundColor(state == .published ? .green : .secondary)
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
        .modelContainer(for: [CloutmateShared.Post.self, CloutmateShared.Artifact.self])
}
