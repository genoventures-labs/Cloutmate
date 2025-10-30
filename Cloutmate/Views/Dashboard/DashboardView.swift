//
//  DashboardView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import Charts
import CloutmateShared

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CloutmateShared.Post.scheduledDate) private var allPosts: [CloutmateShared.Post]
    @State private var showComposer = false
    @State private var refreshID = UUID()
    
    private var todaysPosts: [CloutmateShared.Post] {
        allPosts.filter { post in
            guard let scheduledDate = post.scheduledDate else { return false }
            return Calendar.current.isDateInToday(scheduledDate)
        }
    }
    
    private var recentPosts: [CloutmateShared.Post] {
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
                
                // Today's Posts with Glass Panel
                VStack(alignment: .leading, spacing: 12) {
                    Text("Today's Posts")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    GlassPanel(tier: .contentCard) {
                        if todaysPosts.isEmpty {
                            ContentUnavailableView(
                                "No posts scheduled",
                                systemImage: "calendar.badge.clock",
                                description: Text("Schedule your first post to get started")
                            )
                            .frame(height: 200)
                            .padding()
                        } else {
                            VStack(spacing: 8) {
                                ForEach(todaysPosts) { post in
                                    PostSummaryCard(post: post)
                                }
                            }
                            .padding()
                        }
                    }
                }
                
                // Quick Stats - Expanded Grid with GlassMetricCard
                VStack(alignment: .leading, spacing: 12) {
                    Text("Last 7 Days Performance")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 160, maximum: 200)),
                        GridItem(.adaptive(minimum: 160, maximum: 200)),
                        GridItem(.adaptive(minimum: 160, maximum: 200))
                    ], spacing: 16) {
                        GlassMetricCard(
                            title: "Posts Published",
                            value: "\(recentPosts.count)",
                            icon: "doc.text.fill",
                            color: .blue
                        )
                        
                        GlassMetricCard(
                            title: "Avg Engagement",
                            value: String(format: "%.1f%%", averageEngagement),
                            icon: "heart.fill",
                            color: .pink
                        )
                        
                        GlassMetricCard(
                            title: "Total Reach",
                            value: "\(totalReach)",
                            icon: "eye.fill",
                            color: .purple
                        )
                        
                        GlassMetricCard(
                            title: "Total Likes",
                            value: "\(totalLikes)",
                            icon: "hand.thumbsup.fill",
                            color: .orange
                        )
                        
                        GlassMetricCard(
                            title: "Total Comments",
                            value: "\(totalComments)",
                            icon: "bubble.left.fill",
                            color: .green
                        )
                        
                        GlassMetricCard(
                            title: "Total Impressions",
                            value: "\(totalImpressions)",
                            icon: "chart.bar.fill",
                            color: .indigo
                        )
                    }
                }
                
                // Content Recycling Suggestions
                ContentRecyclingCard()
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)

                // Upcoming & Activity
                HStack(spacing: 16) {
                    GlassMetricCard(
                        title: "Upcoming Posts",
                        value: "\(upcomingPostsCount)",
                        icon: "calendar.badge.clock",
                        color: .cyan
                    )
                    
                    GlassMetricCard(
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
        .background(Color(.windowBackgroundColor))
        .sheet(isPresented: $showComposer) {
            ComposerWindow()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshViewsFromMenuBar"))) { _ in
            // Refresh view when notification received from menu bar
            refreshID = UUID()
        }
        .id(refreshID)
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

