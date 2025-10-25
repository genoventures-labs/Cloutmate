//
//  InsightsView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import Charts
import os.log

struct InsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Post.publishedDate, order: .reverse) private var allPosts: [Post]
    
    @State private var selectedTimeRange: TimeRange = .week
    @State private var isRefreshing = false
    
    private var publishedPosts: [Post] {
        allPosts.filter { $0.status == PostStatus.published.rawValue }
    }
    
    var filteredPosts: [Post] {
        let cutoffDate = Calendar.current.date(byAdding: selectedTimeRange.dateComponent, value: -selectedTimeRange.rawValue, to: Date()) ?? Date()
        return publishedPosts.filter { ($0.publishedDate ?? Date()) >= cutoffDate }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Insights")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.primary, .primary.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("Track your content performance")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 12) {
                        // Time range picker
                        HStack(spacing: 8) {
                            TimeRangeButton(
                                title: "Week",
                                isSelected: selectedTimeRange == .week,
                                action: { selectedTimeRange = .week }
                            )
                            TimeRangeButton(
                                title: "Month",
                                isSelected: selectedTimeRange == .month,
                                action: { selectedTimeRange = .month }
                            )
                            TimeRangeButton(
                                title: "Year",
                                isSelected: selectedTimeRange == .year,
                                action: { selectedTimeRange = .year }
                            )
                        }
                        
                        Button(action: refreshInsights) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Refresh")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                        }
                        .disabled(isRefreshing)
                        .animation(.easeInOut(duration: 0.2), value: isRefreshing)
                    }
                }
                .padding(.bottom, 8)
                
                // Metrics cards
                HStack(spacing: 20) {
                    MetricCard(
                        title: "Total Posts",
                        value: "\(filteredPosts.count)",
                        icon: "doc.text.fill",
                        color: .blue
                    )
                    
                    MetricCard(
                        title: "Avg Engagement",
                        value: String(format: "%.1f%%", averageEngagement),
                        icon: "heart.fill",
                        color: .pink
                    )
                    
                    MetricCard(
                        title: "Total Reach",
                        value: "\(totalReach)",
                        icon: "eye.fill",
                        color: .purple
                    )
                    
                    MetricCard(
                        title: "Total Likes",
                        value: "\(totalLikes)",
                        icon: "hand.thumbsup.fill",
                        color: .orange
                    )
                }
                
                // Performance chart
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Performance Over Time")
                            .font(.system(size: 20, weight: .semibold))
                        
                        Spacer()
                        
                        Text("Engagement Rate")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    PerformanceChart(posts: filteredPosts)
                        .frame(height: 240)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
                        )
                }
                
                // Platform comparison
                VStack(alignment: .leading, spacing: 16) {
                    Text("Platform Comparison")
                        .font(.system(size: 20, weight: .semibold))
                    
                    PlatformComparisonView(posts: filteredPosts)
                }
                
                // Reflection summary
                VStack(alignment: .leading, spacing: 16) {
                    Text("Reflection")
                        .font(.system(size: 20, weight: .semibold))
                    
                    ReflectionSummary(posts: filteredPosts)
                }
            }
            .padding(28)
        }
        .background(Color(.windowBackgroundColor))
        .navigationTitle("Insights")
    }
    
    private var averageEngagement: Double {
        let postsWithMetrics = filteredPosts.filter { $0.engagementRate != nil }
        guard !postsWithMetrics.isEmpty else { return 0 }
        return postsWithMetrics.reduce(0) { $0 + ($1.engagementRate ?? 0) } / Double(postsWithMetrics.count)
    }
    
    private var totalReach: Int {
        filteredPosts.reduce(0) { $0 + ($1.reach ?? 0) }
    }
    
    private var totalLikes: Int {
        filteredPosts.reduce(0) { $0 + ($1.likes ?? 0) }
    }
    
    private func refreshInsights() {
        isRefreshing = true
        Task {
            // Fetch insights from Meta API
            await fetchLatestInsights()
            isRefreshing = false
        }
    }
    
    private func fetchLatestInsights() async {
        for post in publishedPosts {
            do {
                // Get access token
                let platform = post.postPlatforms.first ?? .threads
                let accountKey = "\(platform.rawValue)_access_token"
                let accessToken = try KeychainService.shared.getToken(forAccount: accountKey)
                
                // Fetch insights
                if let postID = post.threadsPostID {
                    let insights = try await MetaAPIService.shared.getPostInsights(
                        postID: postID,
                        accessToken: accessToken
                    )
                    
                    // Update post with insights
                    for data in insights.data {
                        guard let value = data.values.first?.value,
                              let doubleValue = Double(value) else { continue }
                        
                        switch data.name {
                        case "likes":
                            post.likes = Int(doubleValue)
                        case "comments":
                            post.comments = Int(doubleValue)
                        case "impressions":
                            post.impressions = Int(doubleValue)
                        case "reach":
                            post.reach = Int(doubleValue)
                        default:
                            break
                        }
                    }
                    
                    // Calculate engagement rate
                    if let impressions = post.impressions, impressions > 0 {
                        let likes = post.likes ?? 0
                        let comments = post.comments ?? 0
                        post.engagementRate = Double(likes + comments) / Double(impressions) * 100
                    }
                }
            } catch {
                Logger.insights.error("Failed to fetch insights for post \(post.id): \(error.localizedDescription)")
            }
        }
    }
}

enum TimeRange: Int, CaseIterable {
    case week = 7
    case month = 30
    case year = 365
    
    var dateComponent: Calendar.Component {
        .day
    }
}

struct TimeRangeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(color.opacity(0.15))
                    )
                
                Spacer()
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .tracking(0.2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: color.opacity(0.2), radius: isHovered ? 12 : 6, y: isHovered ? 6 : 3)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    InsightsView()
        .modelContainer(for: [Post.self])
}

