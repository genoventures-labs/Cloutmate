//
//  ContentAnalyticsView.swift
//  Cloutmate
//
//  Phase 6.1 - Content Analytics & Impact Tracking
//

import SwiftUI
import SwiftData
import CloutmateShared
import Charts

struct ContentAnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    let snapshot: AnalyticsSnapshot?
    let timeRange: AnalyticsTimeRange
    
    @State private var posts: [Post] = []
    @State private var publishingTrend: [(date: Date, count: Int)] = []
    @State private var engagementData: [(platform: String, engagement: Double)] = []
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Publishing Stats
                if let snapshot = snapshot {
                    HStack(spacing: 16) {
                        StatCard(
                            title: "Posts Published",
                            value: "\(snapshot.postsPublished)",
                            icon: "checkmark.circle.fill",
                            color: .kosmicGreen
                        )
                        
                        StatCard(
                            title: "Drafts Created",
                            value: "\(snapshot.draftsCreated)",
                            icon: "doc.text.fill",
                            color: .kosmicBlue
                        )
                        
                        StatCard(
                            title: "Avg Engagement",
                            value: String(format: "%.1f", snapshot.avgEngagement),
                            icon: "heart.fill",
                            color: .red
                        )
                    }
                    .padding(.horizontal)
                }
                
                // Publishing Trend
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Publishing Trend", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.headline)
                        
                        if !publishingTrend.isEmpty {
                            Chart(publishingTrend, id: \.date) { dataPoint in
                                BarMark(
                                    x: .value("Date", dataPoint.date),
                                    y: .value("Posts", dataPoint.count)
                                )
                                .foregroundStyle(Color.kosmicGreen)
                            }
                            .frame(height: 200)
                        } else {
                            ContentUnavailableView(
                                "No Publishing Data",
                                systemImage: "chart.bar",
                                description: Text("Publish posts to see trends")
                            )
                            .frame(height: 200)
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)
                
                // Engagement by Platform
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Engagement by Platform", systemImage: "chart.bar.xaxis")
                            .font(.headline)
                        
                        if !engagementData.isEmpty {
                            Chart(engagementData, id: \.platform) { data in
                                BarMark(
                                    x: .value("Engagement", data.engagement),
                                    y: .value("Platform", data.platform)
                                )
                                .foregroundStyle(by: .value("Platform", data.platform))
                            }
                            .frame(height: 150)
                        } else {
                            ContentUnavailableView(
                                "No Platform Data",
                                systemImage: "chart.bar.xaxis",
                                description: Text("Publish to multiple platforms to compare engagement")
                            )
                            .frame(height: 150)
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)
                
                // Top Performing Posts
                if let snapshot = snapshot, !snapshot.topPerformingPosts.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Top Performing Posts", systemImage: "star.fill")
                                .font(.headline)
                            
                            ForEach(snapshot.topPerformingPosts.indices, id: \.self) { index in
                                let post = snapshot.topPerformingPosts[index]
                                
                                HStack {
                                    Text("#\(index + 1)")
                                        .font(.headline)
                                        .foregroundColor(.yellow)
                                        .frame(width: 30)
                                    
                                    Text(post)
                                        .font(.body)
                                        .lineLimit(2)
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                                
                                if index < snapshot.topPerformingPosts.count - 1 {
                                    Divider()
                                }
                            }
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                }
                
                // Recent Posts
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Recent Posts", systemImage: "doc.text.below.ecg")
                            .font(.headline)
                        
                        if !posts.isEmpty {
                            ForEach(posts.prefix(10), id: \.id) { post in
                                AnalyticsPostRow(post: post)
                                
                                if post.id != posts.prefix(10).last?.id {
                                    Divider()
                                }
                            }
                        } else {
                            ContentUnavailableView(
                                "No Posts Yet",
                                systemImage: "doc.text",
                                description: Text("Create your first post to see analytics")
                            )
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)
                
                // Content Insights
                GroupBox("Content Insights") {
                    ContentInsightsSection(posts: posts)
                        .padding()
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .task {
            loadData()
        }
    }
    
    private func loadData() {
        let (startDate, endDate) = timeRange.dateRange
        
        // Load posts
        let postDescriptor = FetchDescriptor<Post>(
            sortBy: [SortDescriptor(\Post.scheduledDate, order: .reverse)]
        )
        let allPosts = (try? modelContext.fetch(postDescriptor)) ?? []
        
        // Filter by date manually if needed
        posts = allPosts
        
        // Calculate publishing trend
        let days = timeRange == .thisWeek ? 7 : 30
        var trend: [(Date, Int)] = []
        let calendar = Calendar.current
        
        for dayOffset in 0..<days {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            let count = posts.filter { post in
                guard let publishedAt = post.publishedDate else { return false }
                return publishedAt >= startOfDay && publishedAt < endOfDay
            }.count
            
            trend.append((startOfDay, count))
        }
        publishingTrend = trend.reversed()
        
        // Calculate engagement by platform
        let publishedPosts = posts.filter { $0.status == "published" }
        
        // Simplified - single engagement metric per platform
        let platformEngagement = publishedPosts.reduce(into: [String: (total: Int, count: Int)]()) { dict, post in
            let platform = post.platforms.first ?? "unknown"
            let engagement = (post.likes ?? 0) + (post.comments ?? 0)
            if dict[platform] == nil {
                dict[platform] = (engagement, 1)
            } else {
                dict[platform]?.total += engagement
                dict[platform]?.count += 1
            }
        }
        
        engagementData = platformEngagement.map { platform, data in
            let avgEngagement = Double(data.total) / Double(data.count)
            return (platform.capitalized, avgEngagement)
        }.sorted { $0.engagement > $1.engagement }
    }
}

// MARK: - Analytics Post Row

struct AnalyticsPostRow: View {
    let post: Post
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(post.caption)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack {
                    Image(systemName: platformIcon)
                        .foregroundColor(platformColor)
                    Text(post.platforms.first ?? "Unknown")
                    
                    Spacer()
                    
                    if post.status == "published" {
                        HStack(spacing: 8) {
                            Label("\(post.likes ?? 0)", systemImage: "heart.fill")
                            Label("\(post.comments ?? 0)", systemImage: "bubble.left.fill")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                .font(.caption)
                
                Text(post.status.capitalized)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var platformIcon: String {
        let platform = post.platforms.first ?? ""
        switch platform.lowercased() {
        case "facebook": return "f.circle.fill"
        case "threads": return "text.bubble.fill"
        default: return "square.grid.2x2"
        }
    }
    
    private var platformColor: Color {
        let platform = post.platforms.first ?? ""
        switch platform.lowercased() {
        case "facebook": return .kosmicBlue
        case "threads": return .kosmicPurple
        default: return .gray
        }
    }
    
    private var statusColor: Color {
        switch post.status.lowercased() {
        case "draft": return .gray
        case "scheduled": return .kosmicBlue
        case "published": return .kosmicGreen
        case "archived": return .orange
        default: return .gray
        }
    }
}

// MARK: - Content Insights Section

struct ContentInsightsSection: View {
    let posts: [Post]
    
    private var publishedPosts: [Post] {
        posts.filter { post in post.status == "published" }
    }
    
    private var totalEngagement: Int {
        publishedPosts.reduce(0) { result, post in
            result + (post.likes ?? 0) + (post.comments ?? 0)
        }
    }
    
    private var platformEngagement: [String: Int] {
        var engagement: [String: Int] = [:]
        for post in publishedPosts {
            let platform = post.platforms.first ?? "Unknown"
            let postEngagement = (post.likes ?? 0) + (post.comments ?? 0)
            engagement[platform, default: 0] += postEngagement
        }
        return engagement
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !posts.isEmpty {
                if !publishedPosts.isEmpty {
                    InsightRow(
                        icon: "heart.fill",
                        text: "Your content generated \(totalEngagement) total engagements",
                        color: .red
                    )
                    
                    let avgEngagement = Double(totalEngagement) / Double(publishedPosts.count)
                    InsightRow(
                        icon: "chart.line.uptrend.xyaxis",
                        text: String(format: "Average %.1f engagements per post", avgEngagement),
                        color: .kosmicBlue
                    )
                    
                    if let best = platformEngagement.max(by: { $0.value < $1.value }) {
                        InsightRow(
                            icon: "star.fill",
                            text: "\(best.key.capitalized) is your top performing platform with \(best.value) engagements",
                            color: .yellow
                        )
                    }
                }
            } else {
                Text("Publish posts to see personalized insights")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Insight Row

struct InsightRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            Text(text)
                .font(.body)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentAnalyticsView(
        snapshot: nil,
        timeRange: .thisWeek
    )
    .modelContainer(for: [Post.self])
}

