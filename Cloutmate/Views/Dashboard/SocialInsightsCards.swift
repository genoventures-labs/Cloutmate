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
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
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

    private var totalPosts: Int { publishedLast7Days.count }
    private var engagementDisplay: String {
        postsWithEngagement > 0 ? String(format: "%.1f%%", averageEngagement) : "—"
    }
    private var reachDisplay: String { formatNumber(totalReach) }
    private var headerSubtitle: String {
        if totalPosts == 0 {
            return "No posts published in the last 7 days."
        } else if postsWithEngagement == 0 {
            return "Add engagement metrics to unlock deeper performance insights."
        } else {
            return "Engagement measured across \(postsWithEngagement) recent \(postsWithEngagement == 1 ? "post" : "posts")."
        }
    }
    private var platformEntries: [PlatformEntry] {
        [
            PlatformEntry(name: "Threads", count: platformSplit.threads, tint: glassTint(.accent), icon: "bubble.right.fill"),
            PlatformEntry(name: "Facebook", count: platformSplit.facebook, tint: glassTint(.primary), icon: "f.circle.fill")
        ]
    }
    private var bestPlatformHighlight: PlatformEntry? {
        guard totalPosts > 0 else { return nil }
        return platformEntries
            .map { entry in entry.withShare(share(for: entry.count)) }
            .filter { $0.share > 0 }
            .max(by: { $0.share < $1.share })
    }
    
    var body: some View {
        Group {
            if size == .large { largeContent } else if size == .medium { mediumContent } else { smallContent }
        }
    }

    @ViewBuilder
    private var largeContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            headerRow
            statGrid
            Divider()
                .overlay(.white.opacity(0.12))
            if totalPosts == 0 {
                emptyWeekState
            } else {
                platformMixSection
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var mediumContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 20) {
                metricTile(
                    label: "Posts this week",
                    value: "\(totalPosts)",
                    accent: glassTint(.primary)
                )

                metricTile(
                    label: "Avg Engagement",
                    value: engagementDisplay,
                    accent: glassTint(.accent)
                )

                Spacer(minLength: 0)
            }

            platformBar
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

    private func glassTint(_ role: GlassColorSystem.GlassRole) -> Color {
        glassColorSystem.glassTint(for: role)
    }

    private func formatNumber(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }

    private var postsWithEngagement: Int {
        publishedLast7Days.filter { $0.engagementRate != nil }.count
    }

    @ViewBuilder
    private var headerRow: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Weekly Social Snapshot")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(headerSubtitle)
                    .font(.footnote)
                    .dashboardSecondaryText()
            }

            Spacer(minLength: 0)

            if let best = bestPlatformHighlight {
                HStack(spacing: 10) {
                    Circle()
                        .fill(best.tint.opacity(0.20))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: best.icon)
                                .foregroundColor(best.tint)
                                .font(.system(size: 13, weight: .semibold))
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Best platform")
                            .font(.caption2)
                            .textCase(.uppercase)
                            .tracking(0.6)
                            .dashboardSecondaryText()
                        Text(best.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(String(format: "%.0f%% share", best.share * 100))
                            .font(.caption2)
                            .dashboardSecondaryText()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(best.tint.opacity(0.10), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(best.tint.opacity(0.25), lineWidth: 1)
                )
            }
        }
    }

    private var statGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ],
            spacing: 16
        ) {
            statCard(
                title: "Posts (7d)",
                value: "\(totalPosts)",
                caption: totalPosts == 1 ? "Published this week" : "Posts published this week",
                accent: glassTint(.primary),
                icon: "paperplane.fill"
            )

            statCard(
                title: "Avg Engagement",
                value: engagementDisplay,
                caption: postsWithEngagement > 0 ? "Across \(postsWithEngagement) tracked \(postsWithEngagement == 1 ? "post" : "posts")" : "Track engagement to see trends",
                accent: glassTint(.accent),
                icon: "sparkles"
            )

            statCard(
                title: "Total Reach",
                value: reachDisplay,
                caption: totalReach > 0 ? "Combined reach over the last 7 days" : "Reach data not recorded yet",
                accent: glassTint(.primary),
                icon: "antenna.radiowaves.left.and.right"
            )
        }
    }

    private var emptyWeekState: some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(glassTint(.surface).opacity(0.3))
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: "moon.zzz.fill")
                        .foregroundColor(glassTint(.surface).opacity(0.9))
                        .font(.system(size: 13, weight: .semibold))
                )
            VStack(alignment: .leading, spacing: 4) {
                Text("No social activity yet")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Publish a post to unlock engagement and reach insights here.")
                    .font(.caption)
                    .dashboardSecondaryText()
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(glassTint(.surface).opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(glassTint(.surface).opacity(0.25), lineWidth: 1)
        )
    }

    private var platformMixSection: some View {
        let entries = platformEntries.map { $0.withShare(share(for: $0.count)) }
        return VStack(alignment: .leading, spacing: 18) {
            Text("Platform Mix")
                .font(.subheadline)
                .fontWeight(.semibold)
                .dashboardSecondaryText()

            platformBar

            HStack(spacing: 16) {
                ForEach(entries) { entry in
                    platformTile(entry)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func statCard(title: String, value: String, caption: String, accent: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: icon)
                            .foregroundColor(accent)
                            .font(.system(size: 15, weight: .semibold))
                    )
                Spacer()
            }

            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(accent)

            Text(title.uppercased())
                .font(.caption)
                .tracking(0.6)
                .dashboardSecondaryText()

            Text(caption)
                .font(.caption2)
                .dashboardSecondaryText()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(accent.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.20), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func metricTile(label: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(accent)

            Text(label.uppercased())
                .font(.caption)
                .dashboardSecondaryText()
                .tracking(0.6)
        }
    }

    private var platformTotal: Double {
        Double(max(platformSplit.threads + platformSplit.facebook, 1))
    }

    private func share(for value: Int) -> Double {
        guard platformTotal > 0 else { return 0 }
        return Double(value) / platformTotal
    }

    private var platformBar: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let threadsWidth = width * share(for: platformSplit.threads)
            let facebookWidth = width * share(for: platformSplit.facebook)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(glassTint(.surface).opacity(0.25))
                    .frame(height: 14)

                HStack(spacing: 0) {
                    if threadsWidth > 0 {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(glassTint(.accent).opacity(0.85))
                            .frame(width: threadsWidth, height: 14)
                    }

                    if facebookWidth > 0 {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(glassTint(.primary).opacity(0.85))
                            .frame(width: facebookWidth, height: 14)
                    }

                    Spacer(minLength: 0)
                }
                .frame(width: width, alignment: .leading)
            }
        }
        .frame(height: 14)
        .padding(.top, 4)
    }

    private func platformTile(_ entry: PlatformEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(entry.tint.opacity(0.20))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: entry.icon)
                            .foregroundColor(entry.tint)
                            .font(.system(size: 12, weight: .semibold))
                    )
                Text(entry.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Text(entry.count == 0 ? "—" : "\(entry.count) \(entry.count == 1 ? "post" : "posts")")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(entry.tint)

            Text(String(format: "%.0f%% of posts", entry.share * 100))
                .font(.caption2)
                .dashboardSecondaryText()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(entry.tint.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(entry.tint.opacity(0.20), lineWidth: 1)
        )
    }
}

private struct PlatformEntry: Identifiable {
    var id: String { name }
    let name: String
    let count: Int
    let tint: Color
    let icon: String
    var share: Double = 0

    func withShare(_ share: Double) -> PlatformEntry {
        var copy = self
        copy.share = share
        return copy
    }
}

// MARK: - Content Performance Card
struct ContentPerformanceCard: View {
    let size: DashboardCardSize
    @Query(sort: \CloutmateShared.Post.publishedDate, order: .reverse) private var posts: [CloutmateShared.Post]
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
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
        case .small:
            VStack(alignment: .leading, spacing: 8) {
                Text(bestEngagement)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(glassTint(.accent))
                Text("Best engagement post")
                    .font(.caption)
                    .dashboardSecondaryText()
            }
        default:
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 24) {
                    DashboardMetricTile(
                        label: "Top performer",
                        value: bestEngagement,
                        accent: glassTint(.accent),
                        caption: topPost?.publishedDate.map { "Posted on \($0.formatted(date: .abbreviated, time: .omitted))" }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    DashboardMetricTile(
                        label: "Needs love",
                        value: lowestEngagement,
                        accent: glassTint(.surface),
                        caption: worstPost?.publishedDate.map { "Posted on \($0.formatted(date: .abbreviated, time: .omitted))" }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Divider()
                    .overlay(.white.opacity(0.08))
                
                VStack(alignment: .leading, spacing: 14) {
                    if let top = topPost {
                        performanceRow(
                            icon: "trophy.fill",
                            title: "Best performing",
                            post: top,
                            tint: glassTint(.accent)
                        )
                    }
                    
                    if let worst = worstPost, worst.id != topPost?.id {
                        performanceRow(
                            icon: "exclamationmark.triangle.fill",
                            title: "Needs improvement",
                            post: worst,
                            tint: glassTint(.surface)
                        )
                    }
                }
            }
        }
    }
    
    private var bestEngagement: String {
        guard let value = topPost?.engagementRate else { return "—" }
        return String(format: "%.1f%%", value)
    }
    
    private var lowestEngagement: String {
        guard let value = worstPost?.engagementRate else { return "—" }
        return String(format: "%.1f%%", value)
    }
    
    private func glassTint(_ role: GlassColorSystem.GlassRole) -> Color {
        glassColorSystem.glassTint(for: role)
    }
    
    @ViewBuilder
    private func performanceRow(icon: String, title: String, post: CloutmateShared.Post, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(tint)
                Text(title.uppercased())
                    .font(.caption)
                    .dashboardSecondaryText()
                    .tracking(0.6)
            }
            
            Text(post.caption.isEmpty ? "Untitled post" : post.caption)
                .font(.subheadline)
                .lineLimit(2)
            
            if let engagement = post.engagementRate {
                Text(String(format: "%.1f%% engagement", engagement))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(tint)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.08))
        )
    }
}

// MARK: - Platform Comparison Card
struct PlatformComparisonCard: View {
    let size: DashboardCardSize
    @Query(sort: \CloutmateShared.Post.publishedDate, order: .reverse) private var posts: [CloutmateShared.Post]
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
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
        case .small:
            VStack(alignment: .leading, spacing: 8) {
                Text(bestValue)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(bestColor)
                Text("Best platform: \(bestPlatform)")
                    .font(.caption)
                    .dashboardSecondaryText()
            }
        default:
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 24) {
                    DashboardMetricTile(
                        label: "Threads",
                        value: String(format: "%.1f%%", threadsAverageEngagement),
                        accent: glassTint(.accent),
                        caption: "\(threadsCount) posts analysed"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    DashboardMetricTile(
                        label: "Facebook",
                        value: String(format: "%.1f%%", facebookAverageEngagement),
                        accent: glassTint(.primary),
                        caption: "\(facebookCount) posts analysed"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Divider()
                    .overlay(.white.opacity(0.08))
                
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let total = max(threadsAverageEngagement + facebookAverageEngagement, 0.01)
                    let threadsWidth = width * CGFloat(threadsAverageEngagement / total)
                    let facebookWidth = width * CGFloat(facebookAverageEngagement / total)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.primary.opacity(0.06))
                            .frame(height: 12)
                        
                        HStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(glassTint(.accent).opacity(0.9))
                                .frame(width: threadsWidth, height: 12)
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(glassTint(.primary).opacity(0.9))
                                .frame(width: facebookWidth, height: 12)
                            Spacer(minLength: 0)
                        }
                        .frame(width: width, alignment: .leading)
                    }
                }
                .frame(height: 12)
                
                Text(summaryCopy)
                    .font(.footnote)
                    .dashboardSecondaryText()
            }
        }
    }
    
    private var threadsCount: Int {
        publishedPosts.filter { $0.postPlatforms.contains(.threads) }.count
    }
    
    private var facebookCount: Int {
        publishedPosts.filter { $0.postPlatforms.contains(.facebook) }.count
    }
    
    private var bestPlatform: String {
        threadsAverageEngagement >= facebookAverageEngagement ? "Threads" : "Facebook"
    }
    
    private var bestValue: String {
        let value = max(threadsAverageEngagement, facebookAverageEngagement)
        return value == 0 ? "—" : String(format: "%.1f%%", value)
    }
    
    private var bestColor: Color {
        threadsAverageEngagement >= facebookAverageEngagement ? glassTint(.accent) : glassTint(.primary)
    }
    
    private var summaryCopy: String {
        guard threadsAverageEngagement != 0 || facebookAverageEngagement != 0 else {
            return "No engagement data yet. Publish across platforms to compare performance."
        }
        let gap = abs(threadsAverageEngagement - facebookAverageEngagement)
        if gap < 0.5 { return "Platforms are performing similarly. Keep testing creative variants." }
        let leader = bestPlatform
        return "\(leader) is leading by \(String(format: "%.1f", gap)) pts. Consider prioritising this channel this week."
    }
    
    private func glassTint(_ role: GlassColorSystem.GlassRole) -> Color {
        glassColorSystem.glassTint(for: role)
    }
}
