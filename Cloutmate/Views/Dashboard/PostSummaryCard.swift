//
//  PostSummaryCard.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI

struct PostSummaryCard: View {
    let post: Post
    
    var body: some View {
        HStack(spacing: 12) {
            // Platform indicator
            VStack(spacing: 4) {
                ForEach(post.postPlatforms, id: \.self) { platform in
                    Circle()
                        .fill(platform == .threads ? Color.purple : Color.blue)
                        .frame(width: 8, height: 8)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(post.caption)
                    .lineLimit(2)
                    .font(.body)
                
                if let scheduledDate = post.scheduledDate {
                    Text(scheduledDate, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Status badge
            StatusBadge(status: post.postStatus)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

struct StatusBadge: View {
    let status: PostStatus
    
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

extension PostStatus {
    var color: Color {
        switch self {
        case .draft: return .gray
        case .scheduled: return .blue
        case .publishing: return .orange
        case .published: return .green
        case .failed: return .red
        }
    }
}

#Preview {
    PostSummaryCard(post: Post(caption: "Sample post caption", platforms: ["threads"]))
        .padding()
}

