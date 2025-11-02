//
//  PostSummaryCard.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import CloutmateShared

struct PostSummaryCard: View {
    let post: CloutmateShared.Post
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Platform indicator
            VStack(spacing: 4) {
                ForEach(post.postPlatforms, id: \.self) { platform in
                    Circle()
                        .fill(platform == .threads ? Color.kosmicPurple : Color.kosmicBlue)
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
            PostStatusBadge(status: post.postStatus)
        }
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 10)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(GlassMotion.Easing.spring, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct PostStatusBadge: View {
    let status: CloutmateShared.PostStatus
    
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

extension CloutmateShared.PostStatus {
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

#Preview {
    PostSummaryCard(post: CloutmateShared.Post(caption: "Sample post caption", platforms: ["threads"]))
        .padding()
}

