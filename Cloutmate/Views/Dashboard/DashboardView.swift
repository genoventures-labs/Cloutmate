//
//  DashboardView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Post.scheduledDate) private var allPosts: [Post]
    @State private var showComposer = false
    
    private var todaysPosts: [Post] {
        allPosts.filter { post in
            guard let scheduledDate = post.scheduledDate else { return false }
            return Calendar.current.isDateInToday(scheduledDate)
        }
    }
    
    private var recentPosts: [Post] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return allPosts.filter { post in
            post.status == PostStatus.published.rawValue &&
            (post.publishedDate ?? Date()) >= cutoffDate
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    Text("Dashboard")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                    Button(action: {
                        showComposer = true
                    }) {
                        Label("Create New Post", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                // Today's Posts
                VStack(alignment: .leading, spacing: 12) {
                    Text("Today's Posts")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if todaysPosts.isEmpty {
                        ContentUnavailableView(
                            "No posts scheduled",
                            systemImage: "calendar.badge.clock",
                            description: Text("Schedule your first post to get started")
                        )
                        .frame(height: 200)
                    } else {
                        ForEach(todaysPosts) { post in
                            PostSummaryCard(post: post)
                        }
                    }
                }
                
                // Quick Stats - Expanded Grid
                VStack(alignment: .leading, spacing: 12) {
                    Text("Last 7 Days Performance")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 160, maximum: 200)),
                        GridItem(.adaptive(minimum: 160, maximum: 200)),
                        GridItem(.adaptive(minimum: 160, maximum: 200))
                    ], spacing: 16) {
                        QuickStatsCard(
                            title: "Posts Published",
                            value: "\(recentPosts.count)",
                            icon: "doc.text.fill",
                            color: .blue
                        )
                        
                        QuickStatsCard(
                            title: "Avg Engagement",
                            value: String(format: "%.1f%%", averageEngagement),
                            icon: "heart.fill",
                            color: .pink
                        )
                        
                        QuickStatsCard(
                            title: "Total Reach",
                            value: "\(totalReach)",
                            icon: "eye.fill",
                            color: .purple
                        )
                        
                        QuickStatsCard(
                            title: "Total Likes",
                            value: "\(totalLikes)",
                            icon: "hand.thumbsup.fill",
                            color: .green
                        )
                        
                        QuickStatsCard(
                            title: "Total Comments",
                            value: "\(totalComments)",
                            icon: "bubble.left.fill",
                            color: .orange
                        )
                        
                        QuickStatsCard(
                            title: "Total Impressions",
                            value: "\(totalImpressions)",
                            icon: "chart.bar.fill",
                            color: .indigo
                        )
                    }
                }
                
                // Upcoming & Activity
                HStack(spacing: 16) {
                    QuickStatsCard(
                        title: "Upcoming Posts",
                        value: "\(upcomingPostsCount)",
                        icon: "calendar.badge.clock",
                        color: .cyan
                    )
                    
                    QuickStatsCard(
                        title: "Failed Posts",
                        value: "\(failedPostsCount)",
                        icon: "exclamationmark.triangle.fill",
                        color: .red
                    )
                }
                
                // Posting Activity Chart
                ActivityChart(posts: allPosts)
            }
            .padding()
        }
        .sheet(isPresented: $showComposer) {
            ComposerWindow()
        }
    }
    
    private var averageEngagement: Double {
        let postsWithMetrics = recentPosts.filter { $0.engagementRate != nil }
        guard !postsWithMetrics.isEmpty else { return 0 }
        return postsWithMetrics.reduce(0) { $0 + ($1.engagementRate ?? 0) } / Double(postsWithMetrics.count)
    }
    
    private var totalReach: Int {
        recentPosts.reduce(0) { $0 + ($1.reach ?? 0) }
    }
    
    private var totalLikes: Int {
        recentPosts.reduce(0) { $0 + ($1.likes ?? 0) }
    }
    
    private var totalComments: Int {
        recentPosts.reduce(0) { $0 + ($1.comments ?? 0) }
    }
    
    private var totalImpressions: Int {
        recentPosts.reduce(0) { $0 + ($1.impressions ?? 0) }
    }
    
    private var upcomingPostsCount: Int {
        let futureDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return allPosts.filter { post in
            guard let scheduledDate = post.scheduledDate else { return false }
            return scheduledDate > Date() && scheduledDate <= futureDate
        }.count
    }
    
    private var failedPostsCount: Int {
        allPosts.filter { $0.status == PostStatus.failed.rawValue }.count
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Post.self])
}

