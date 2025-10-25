//
//  PlatformComparisonView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import Charts

struct PlatformComparisonView: View {
    let posts: [Post]
    
    var body: some View {
        HStack(spacing: 20) {
            // Threads stats
            PlatformStatsCard(
                platform: .threads,
                posts: threadPosts,
                color: .purple
            )
            
            // Facebook stats
            PlatformStatsCard(
                platform: .facebook,
                posts: facebookPosts,
                color: .blue
            )
        }
    }
    
    private var threadPosts: [Post] {
        posts.filter { $0.postPlatforms.contains(.threads) }
    }
    
    private var facebookPosts: [Post] {
        posts.filter { $0.postPlatforms.contains(.facebook) }
    }
}

struct PlatformStatsCard: View {
    let platform: Platform
    let posts: [Post]
    let color: Color
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                HStack(spacing: 10) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 10, height: 10)
                    
                    Text(platform.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 16) {
                StatRow(label: "Posts", value: "\(posts.count)", icon: "doc.text.fill")
                StatRow(label: "Avg Engagement", value: String(format: "%.1f%%", averageEngagement), icon: "heart.fill")
                StatRow(label: "Total Reach", value: "\(totalReach)", icon: "eye.fill")
                StatRow(label: "Total Likes", value: "\(totalLikes)", icon: "hand.thumbsup.fill")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: color.opacity(0.2), radius: isHovered ? 12 : 6, y: isHovered ? 6 : 3)
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var averageEngagement: Double {
        let postsWithMetrics = posts.filter { $0.engagementRate != nil }
        guard !postsWithMetrics.isEmpty else { return 0 }
        return postsWithMetrics.reduce(0) { $0 + ($1.engagementRate ?? 0) } / Double(postsWithMetrics.count)
    }
    
    private var totalReach: Int {
        posts.reduce(0) { $0 + ($1.reach ?? 0) }
    }
    
    private var totalLikes: Int {
        posts.reduce(0) { $0 + ($1.likes ?? 0) }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    PlatformComparisonView(posts: [])
        .padding()
}

