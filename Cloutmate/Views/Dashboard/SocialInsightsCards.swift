//
//  SocialInsightsCards.swift
//  Cloutmate
//
//  Social Media Insight Cards
//

import SwiftUI
import SwiftData
import CloutmateShared

// MARK: - Social Overview Card
struct SocialOverviewCard: View {
    let size: DashboardCardSize
    @Query(sort: \CloutmateShared.Post.publishedDate, order: .reverse) private var posts: [CloutmateShared.Post]
    
    var publishedLast7Days: [CloutmateShared.Post] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return posts.filter { post in
            post.status == PostStatus.published.rawValue &&
            (post.publishedDate ?? Date()) >= weekAgo
        }
    }
    
    var averageEngagement: Double {
        let postsWithMetrics = publishedLast7Days.filter { $0.engagementRate != nil }
        guard !postsWithMetrics.isEmpty else { return 0 }
        return postsWithMetrics.reduce(0) { $0 + ($1.engagementRate ?? 0) } / Double(postsWithMetrics.count)
    }
    
    var totalReach: Int {
        publishedLast7Days.reduce(0) { $0 + ($1.reach ?? 0) }
    }
    
    var platformSplit: (threads: Int, facebook: Int) {
        let threads = publishedLast7Days.filter { $0.postPlatforms.contains(.threads) }.count
        let facebook = publishedLast7Days.filter { $0.postPlatforms.contains(.facebook) }.count
        return (threads, facebook)
    }
    
    var body: some View {
        Group {
            if size == .large { largeContent } else if size == .medium { mediumContent } else { smallContent }
        }
    }

    @ViewBuilder
    private var largeContent: some View {
            VStack(alignment: .leading, spacing: 16) {
                // Main stats
                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("\(publishedLast7Days.count)")
                            .metricValueStyle()
                        Text("Posts (7d)")
                            .metricLabelStyle()
                    }
                    VStack(alignment: .leading) {
                        Text(String(format: "%.1f%%", averageEngagement))
                            .metricValueStyle()
                            .foregroundColor(KosmicPalette.violet)
                        Text("Avg Engagement")
                            .metricLabelStyle()
                    }
                    VStack(alignment: .leading) {
                        Text("\(formatNumber(totalReach))")
                            .metricValueStyle()
                            .foregroundColor(KosmicPalette.cyan)
                        Text("Total Reach")
                            .metricLabelStyle()
                    }
                    Spacer()
                }
                
                Divider()
                
                // Platform split
                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(KosmicPalette.violet)
                                .frame(width: 8, height: 8)
                            Text("Threads")
                                .metricLabelStyle()
                        }
                        Text("\(platformSplit.threads)")
                            .font(.system(size: 20, weight: .semibold))
                    }
                    VStack(alignment: .leading) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(KosmicPalette.cyan)
                                .frame(width: 8, height: 8)
                            Text("Facebook")
                                .metricLabelStyle()
                        }
                        Text("\(platformSplit.facebook)")
                            .font(.system(size: 20, weight: .semibold))
                    }
                    Spacer()
                }
            }
    }

    @ViewBuilder
    private var mediumContent: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Text("\(publishedLast7Days.count)")
                            .metricValueStyle()
                        Text("Posts this week")
                            .metricLabelStyle()
                    }
                    VStack(alignment: .leading) {
                        Text(String(format: "%.1f%%", averageEngagement))
                            .metricValueStyle()
                            .foregroundColor(KosmicPalette.violet)
                        Text("Engagement")
                            .metricLabelStyle()
                    }
                    Spacer()
                }
            }
    }

    @ViewBuilder
    private var smallContent: some View {
            VStack {
                Text("\(publishedLast7Days.count)")
                    .metricValueStyle()
                Text("Posts (7d)")
                    .metricLabelStyle()
        }
    }
    
    private func formatNumber(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }
}

// MARK: - Content Performance Card
struct ContentPerformanceCard: View {
    let size: DashboardCardSize
    @Query(sort: \CloutmateShared.Post.publishedDate, order: .reverse) private var posts: [CloutmateShared.Post]
    
    var topPost: CloutmateShared.Post? {
        posts.filter { $0.status == PostStatus.published.rawValue && $0.engagementRate != nil }
            .max(by: { ($0.engagementRate ?? 0) < ($1.engagementRate ?? 0) })
    }
    
    var worstPost: CloutmateShared.Post? {
        posts.filter { $0.status == PostStatus.published.rawValue && $0.engagementRate != nil }
            .min(by: { ($0.engagementRate ?? 0) < ($1.engagementRate ?? 0) })
    }
    
    var body: some View {
        switch size {
        case .large:
            VStack(alignment: .leading, spacing: 16) {
                if let top = topPost {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "trophy.fill")
                                .foregroundColor(KosmicPalette.violet)
                            Text("Best Performing")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(top.caption)
                            .font(.caption)
                            .lineLimit(2)
                        if let engagement = top.engagementRate {
                            Text("\(String(format: "%.1f", engagement))% engagement")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(KosmicPalette.violet)
                        }
                    }
                }
                
                if let worst = worstPost, worst.id != topPost?.id {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(KosmicPalette.neutral600)
                            Text("Needs Improvement")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(worst.caption)
                            .font(.caption)
                            .lineLimit(2)
                        if let engagement = worst.engagementRate {
                            Text("\(String(format: "%.1f", engagement))% engagement")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(KosmicPalette.neutral600)
                        }
                    }
                }
            }
        case .medium, .small:
            VStack {
                if let top = topPost, let engagement = top.engagementRate {
                    Text(String(format: "%.1f%%", engagement))
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(KosmicPalette.violet)
                    Text("Best Engagement")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Awaiting your first post")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Platform Comparison Card
struct PlatformComparisonCard: View {
    let size: DashboardCardSize
    @Query(sort: \CloutmateShared.Post.publishedDate, order: .reverse) private var posts: [CloutmateShared.Post]
    
    var publishedPosts: [CloutmateShared.Post] {
        posts.filter { $0.status == PostStatus.published.rawValue }
    }
    
    var threadsAverageEngagement: Double {
        let threadsPosts = publishedPosts.filter { $0.postPlatforms.contains(.threads) && $0.engagementRate != nil }
        guard !threadsPosts.isEmpty else { return 0 }
        return threadsPosts.reduce(0) { $0 + ($1.engagementRate ?? 0) } / Double(threadsPosts.count)
    }
    
    var facebookAverageEngagement: Double {
        let fbPosts = publishedPosts.filter { $0.postPlatforms.contains(.facebook) && $0.engagementRate != nil }
        guard !fbPosts.isEmpty else { return 0 }
        return fbPosts.reduce(0) { $0 + ($1.engagementRate ?? 0) } / Double(fbPosts.count)
    }
    
    var body: some View {
        switch size {
        case .large, .medium:
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        HStack {
                            Circle()
                                .fill(KosmicPalette.violet)
                                .frame(width: 8, height: 8)
                            Text("Threads")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(String(format: "%.1f%%", threadsAverageEngagement))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(KosmicPalette.violet)
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Circle()
                                .fill(KosmicPalette.cyan)
                                .frame(width: 8, height: 8)
                            Text("Facebook")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(String(format: "%.1f%%", facebookAverageEngagement))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(KosmicPalette.cyan)
                    }
                    
                    Spacer()
                }
                
                // Visual comparison
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(KosmicPalette.violet.opacity(0.3))
                            .frame(width: geometry.size.width * CGFloat(threadsAverageEngagement / max(threadsAverageEngagement + facebookAverageEngagement, 1)))
                        Rectangle()
                            .fill(KosmicPalette.cyan.opacity(0.3))
                            .frame(width: geometry.size.width * CGFloat(facebookAverageEngagement / max(threadsAverageEngagement + facebookAverageEngagement, 1)))
                    }
                    .cornerRadius(4)
                }
                .frame(height: 12)
            }
        case .small:
            VStack {
                Text(String(format: "%.1f%%", max(threadsAverageEngagement, facebookAverageEngagement)))
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(threadsAverageEngagement > facebookAverageEngagement ? KosmicPalette.violet : KosmicPalette.cyan)
                Text("Best Platform")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

