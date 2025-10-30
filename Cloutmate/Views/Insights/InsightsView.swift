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
import CloutmateShared

struct InsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CloutmateShared.Post.publishedDate, order: .reverse) private var allPosts: [CloutmateShared.Post]
    @Query(filter: #Predicate<PlatformAccount> { $0.platform == "facebook" }) private var facebookPages: [PlatformAccount]
    
    @State private var selectedTimeRange: TimeRange = .week
    @State private var isRefreshing = false
    @State private var autoRefreshTimer: Timer?
    @State private var refreshID = UUID()
    
    // Facebook Page Insights state
    @State private var selectedPageID: String? = nil
    @State private var pageInsightsPeriod: PageInsightsData? = nil
    @State private var pageInsightsLifetime: PageInsightsData? = nil
    @State private var isLoadingPageInsights = false
    @State private var pageInsightsError: String? = nil
    
    private var publishedPosts: [CloutmateShared.Post] {
        allPosts.filter { $0.status == PostStatus.published.rawValue }
    }
    
    var filteredPosts: [CloutmateShared.Post] {
        let cutoffDate = Calendar.current.date(byAdding: selectedTimeRange.dateComponent, value: -selectedTimeRange.rawValue, to: Date()) ?? Date()
        return publishedPosts.filter { ($0.publishedDate ?? Date()) >= cutoffDate }
    }
    
    // Check if banner should be shown - only for published posts without engagement data
    private var shouldShowDataBanner: Bool {
        // Only show banner if there are no posts at all
        guard !filteredPosts.isEmpty else { return true }
        
        // Filter to only published posts
        let publishedPosts = filteredPosts.filter { $0.postStatus == .published }
        
        // If there are no published posts, don't show the banner
        guard !publishedPosts.isEmpty else { return false }
        
        // Check if more than 50% of published posts lack engagement data
        let publishedWithoutData = publishedPosts.filter { $0.engagementRate == nil }.count
        return Double(publishedWithoutData) / Double(publishedPosts.count) > 0.5
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                if shouldShowDataBanner {
                    dataBanner
                }
                
                if !facebookPages.isEmpty {
                    facebookPageInsightsSection
                }
                
                headerView
                
                // Key Metrics Grid - 8 cards in 4 columns
                VStack(alignment: .leading, spacing: 16) {
                    Text("Key Metrics")
                        .font(.system(size: 20, weight: .semibold))
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 20) {
                        // Existing metrics
                        GlassMetricCard(
                            title: "Total Posts",
                            value: "\(filteredPosts.count)",
                            icon: "doc.text.fill",
                            color: .blue
                        )
                        .id("total_posts_\(selectedTimeRange.rawValue)_\(filteredPosts.count)")
                        .transition(.opacity)
                        
                        GlassMetricCard(
                            title: "Avg Engagement",
                            value: String(format: "%.1f%%", averageEngagement),
                            icon: "heart.fill",
                            color: .pink
                        )
                        .id("avg_engagement_\(selectedTimeRange.rawValue)_\(averageEngagement)")
                        .transition(.opacity)
                        
                        GlassMetricCard(
                            title: "Total Reach",
                            value: "\(totalReach)",
                            icon: "eye.fill",
                            color: .purple
                        )
                        .id("total_reach_\(selectedTimeRange.rawValue)_\(totalReach)")
                        .transition(.opacity)
                        
                        GlassMetricCard(
                            title: "Total Likes",
                            value: "\(totalLikes)",
                            icon: "hand.thumbsup.fill",
                            color: .orange
                        )
                        .id("total_likes_\(selectedTimeRange.rawValue)_\(totalLikes)")
                        .transition(.opacity)
                        
                        // New metrics
                        GlassMetricCard(
                            title: "Best Posting Time",
                            value: String(format: "%d:00", bestPostingHour),
                            icon: "clock.fill",
                            color: .orange
                        )
                        .id("best_posting_time_\(selectedTimeRange.rawValue)_\(bestPostingHour)")
                        .transition(.opacity)
                        
                        GlassMetricCard(
                            title: "Top Content Type",
                            value: topContentType,
                            icon: "star.fill",
                            color: .yellow
                        )
                        .id("top_content_\(selectedTimeRange.rawValue)")
                        .transition(.opacity)
                        
                        GlassMetricCard(
                            title: "Growth Rate",
                            value: String(format: "%.1f%%", growthRate),
                            icon: "chart.line.uptrend.xyaxis",
                            color: .green
                        )
                        .id("growth_rate_\(selectedTimeRange.rawValue)_\(growthRate)")
                        .transition(.opacity)
                        
                        GlassMetricCard(
                            title: "Platform Leader",
                            value: leadingPlatform.rawValue.capitalized,
                            icon: "trophy.fill",
                            color: .indigo
                        )
                        .id("platform_leader_\(selectedTimeRange.rawValue)")
                        .transition(.opacity)
                    }
                }
                
                // Interactive Charts Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Performance Analytics")
                        .font(.system(size: 20, weight: .semibold))
                    
                    InteractiveChartsView(posts: filteredPosts)
                        .id("charts_\(selectedTimeRange.rawValue)_\(filteredPosts.count)")
                        .transition(.opacity)
                }
                
                GlassPanel(tier: .contentCard, cornerRadius: 16) {
                    BestTimeOptimizerView()
                }

                GlassPanel(tier: .contentCard, cornerRadius: 16) {
                    ContentGapAnalyzerView()
                }

                GlassPanel(tier: .contentCard, cornerRadius: 16) {
                    HashtagPerformanceView()
                }

                // Detailed Analytics Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Detailed Analytics")
                        .font(.system(size: 20, weight: .semibold))
                    
                    GlassPanel(tier: .contentCard, cornerRadius: 16) {
                        VStack(spacing: 20) {
                            // Platform Performance
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "square.stack.3d.up.fill")
                                        .foregroundColor(.blue)
                                    Text("Platform Performance")
                                        .font(.headline)
                                    Spacer()
                                }
                                PlatformComparisonView(posts: filteredPosts)
                            }
                            
                            Divider()
                            
                            // Reflection Summary
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundColor(.orange)
                                    Text("Insights Summary")
                                        .font(.headline)
                                    Spacer()
                                }
                                ReflectionSummary(posts: filteredPosts)
                            }
                        }
                        .padding(20)
                    }
                    .id("analytics_\(selectedTimeRange.rawValue)_\(filteredPosts.count)")
                    .transition(.opacity)
                }
            }
            .padding(28)
            .animation(.easeInOut(duration: 0.25), value: selectedTimeRange)
        }
        .background(Color(.windowBackgroundColor))
        .navigationTitle("Insights")
        .onAppear {
            startAutoRefresh()
            // Select first page if available and none selected
            if selectedPageID == nil, let firstPage = facebookPages.first {
                selectedPageID = firstPage.accountID
                _Concurrency.Task {
                    await fetchPageInsights(for: firstPage.accountID)
                }
            }
        }
        .onChange(of: selectedTimeRange) { _, _ in
            // Refresh page insights when time range changes
            if let pageID = selectedPageID {
                _Concurrency.Task {
                    await fetchPageInsights(for: pageID)
                }
            }
        }
        .onDisappear {
            stopAutoRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshViewsFromMenuBar"))) { _ in
            // Refresh view when notification received from menu bar
            refreshID = UUID()
        }
        .id(refreshID)
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
    
    // Best posting time - hour with highest avg engagement
    private var bestPostingHour: Int {
        let hourEngagement = Dictionary(grouping: filteredPosts) { post in
            Calendar.current.component(.hour, from: post.publishedDate ?? Date())
        }
        .mapValues { posts in
            let rates = posts.compactMap { $0.engagementRate }
            return rates.isEmpty ? 0 : rates.reduce(0, +) / Double(rates.count)
        }
        return hourEngagement.max(by: { $0.value < $1.value })?.key ?? 12
    }
    
    // Top content type - with or without media
    private var topContentType: String {
        let withMedia = filteredPosts.filter { !$0.mediaURLs.isEmpty }
        let textOnly = filteredPosts.filter { $0.mediaURLs.isEmpty }
        
        let withMediaAvg = averageEngagement(for: withMedia)
        let textOnlyAvg = averageEngagement(for: textOnly)
        
        return withMediaAvg > textOnlyAvg ? "Media" : "Text"
    }
    
    // Growth rate - week over week engagement change
    private var growthRate: Double {
        // Compare current week avg to previous week avg
        let currentWeek = averageEngagement
        
        let previousWeekStart = Calendar.current.date(byAdding: .weekOfYear, value: -2, to: Date()) ?? Date()
        let previousWeekEnd = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        
        let previousWeekPosts = publishedPosts.filter { post in
            guard let publishedDate = post.publishedDate else { return false }
            return publishedDate >= previousWeekStart && publishedDate < previousWeekEnd
        }
        
        let previousWeekAvg = averageEngagement(for: previousWeekPosts)
        
        guard previousWeekAvg > 0 else { return 0 }
        
        let change = ((currentWeek - previousWeekAvg) / previousWeekAvg) * 100
        return change
    }
    
    // Leading platform - platform with best avg engagement
    private var leadingPlatform: Platform {
        let threadsPosts = filteredPosts.filter { $0.postPlatforms.contains(.threads) }
        let facebookPosts = filteredPosts.filter { $0.postPlatforms.contains(.facebook) }
        
        let threadsAvg = averageEngagement(for: threadsPosts)
        let facebookAvg = averageEngagement(for: facebookPosts)
        
        return threadsAvg >= facebookAvg ? .threads : .facebook
    }
    
    // Helper for calculating average engagement for specific posts
    private func averageEngagement(for posts: [CloutmateShared.Post]) -> Double {
        let postsWithMetrics = posts.filter { $0.engagementRate != nil }
        guard !postsWithMetrics.isEmpty else { return 0 }
        return postsWithMetrics.reduce(0) { $0 + ($1.engagementRate ?? 0) } / Double(postsWithMetrics.count)
    }
    
    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Insights")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Track your content performance")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            timeRangePicker
        }
        .padding(.bottom, 8)
    }
    
    private var timeRangePicker: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                GlassButton(
                    "Week",
                    style: .pill,
                    tier: selectedTimeRange == .week ? .overlay : .contentCard,
                    tintColor: .blue,
                    action: { selectedTimeRange = .week }
                )
                GlassButton(
                    "Month",
                    style: .pill,
                    tier: selectedTimeRange == .month ? .overlay : .contentCard,
                    tintColor: .blue,
                    action: { selectedTimeRange = .month }
                )
                GlassButton(
                    "Year",
                    style: .pill,
                    tier: selectedTimeRange == .year ? .overlay : .contentCard,
                    tintColor: .blue,
                    action: { selectedTimeRange = .year }
                )
            }
            
            GlassButton(
                "Refresh",
                icon: "arrow.clockwise",
                style: .standard,
                tier: .contentCard,
                tintColor: .blue,
                action: refreshInsights
            )
            .disabled(isRefreshing)
            .animation(.easeInOut(duration: 0.2), value: isRefreshing)
        }
    }
    
    private var dataBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text("Limited data available")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Connect platforms to see full insights and engagement metrics.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var facebookPageInsightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Facebook Page Insights")
                .font(.system(size: 20, weight: .semibold))
            
            FacebookPageSelector(
                pages: facebookPages,
                selectedPageID: $selectedPageID
            )
            .onChange(of: selectedPageID) { _, newValue in
                if let pageID = newValue {
                    _Concurrency.Task {
                        await fetchPageInsights(for: pageID)
                    }
                } else {
                    pageInsightsPeriod = nil
                    pageInsightsLifetime = nil
                }
            }
            
            if let pageID = selectedPageID {
                FacebookPageInsightsSection(
                    periodInsights: pageInsightsPeriod,
                    lifetimeInsights: pageInsightsLifetime,
                    isLoading: isLoadingPageInsights,
                    error: pageInsightsError
                )
            }
        }
    }
    
    private func refreshInsights() {
        isRefreshing = true
		_Concurrency.Task {
            // Fetch insights from Meta API
            await fetchLatestInsights()
            
            // Also refresh Facebook page insights if a page is selected
            if let pageID = selectedPageID {
                await fetchPageInsights(for: pageID)
            }
            
            isRefreshing = false
        }
    }
    
    private func fetchLatestInsights() async {
        for post in publishedPosts {
            for platform in post.postPlatforms {
            do {
                    // Get appropriate access token
                    let accessToken: String
                    if platform == .threads {
                        accessToken = try KeychainService.shared.getToken(forAccount: "threads_access_token")
                    } else if platform == .facebook {
                        // Get page-specific token from pageIDs
                        guard let pageID = post.getPageID(for: .facebook) else { continue }
                        accessToken = try KeychainService.shared.getToken(forAccount: "facebook_page_\(pageID)_access_token")
                    } else {
                        continue
                    }
                    
                    // Get platform-specific post ID
                    let postID: String?
                    if platform == .threads {
                        postID = post.threadsPostID
                    } else {
                        postID = post.facebookPostID
                    }
                    
                    guard let postID = postID else { continue }
                
                // Fetch insights - convert CloutmateShared.Platform to Cloutmate.Platform
                    let nativePlatform: Cloutmate.Platform
                    switch platform {
                    case .threads:
                        nativePlatform = .threads
                    case .facebook:
                        nativePlatform = .facebook
                    }
                    let insights = try await MetaAPIService.shared.getPostInsights(
                        postID: postID,
                        accessToken: accessToken,
                        platform: nativePlatform
                    )
                    
                    // Update post with insights (accumulate across platforms)
                    for data in insights.data {
                        guard let value = data.values.first?.value,
                              let doubleValue = Double(value) else { continue }
                        
                        switch data.name {
                        case "likes", "reactions", "post_reactions_by_type_total":
                            post.likes = (post.likes ?? 0) + Int(doubleValue)
                        case "comments":
                            post.comments = (post.comments ?? 0) + Int(doubleValue)
                        case "impressions", "post_impressions":
                            post.impressions = (post.impressions ?? 0) + Int(doubleValue)
                        case "reach", "post_engaged_users":
                            post.reach = (post.reach ?? 0) + Int(doubleValue)
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
                    
                    try? modelContext.save()
                    // Skip ContentIntelligenceService call since it expects Cloutmate.Post
                    
            } catch {
                    Logger.insights.error("Failed to fetch insights for \(platform.displayName) post \(post.id): \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func startAutoRefresh() {
        // Refresh immediately on appear
        refreshInsights()
        
        // Then refresh every 5 minutes
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            refreshInsights()
        }
    }
    
    private func stopAutoRefresh() {
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
    }
    
    // MARK: - Facebook Page Insights
    
    private func fetchPageInsights(for pageID: String) async {
        isLoadingPageInsights = true
        pageInsightsError = nil
        
        do {
            // Get page access token
            let accessToken = try KeychainService.shared.getToken(forAccount: "facebook_page_\(pageID)_access_token")
            
            // Calculate date range based on selectedTimeRange
            let until = Int(Date().timeIntervalSince1970)
            let daysAgo = selectedTimeRange.rawValue
            let since = until - (daysAgo * 86400) // Convert days to seconds
            
            // Fetch both period and lifetime insights
            // Use day period with custom date range for accurate time range matching
            async let periodResponse = MetaAPIService.shared.getPageInsights(
                pageID: pageID,
                accessToken: accessToken,
                period: .day,
                since: since,
                until: until
            )
            
            async let lifetimeResponse = MetaAPIService.shared.getPageInsights(
                pageID: pageID,
                accessToken: accessToken,
                period: .lifetime
            )
            
            let (periodData, lifetimeData) = try await (periodResponse, lifetimeResponse)
            
            await MainActor.run {
                pageInsightsPeriod = PageInsightsData(from: periodData)
                pageInsightsLifetime = PageInsightsData(from: lifetimeData)
                isLoadingPageInsights = false
            }
        } catch {
            Logger.insights.error("Failed to fetch page insights for page \(pageID): \(error.localizedDescription)")
            await MainActor.run {
                pageInsightsError = error.localizedDescription
                isLoadingPageInsights = false
            }
        }
    }
}

// MARK: - Helper Structures

struct PageInsightsData {
    let pageViewsTotal: Int
    let pageFans: Int
    let pageReach: Int
    let pageImpressions: Int
    let pageEngagedUsers: Int
    let pagePostEngagements: Int
    let pageConsumptions: Int
    
    init(from response: PageInsightsResponse) {
        // Extract values from response data
        var views = 0, fans = 0, reach = 0, impressions = 0
        var engagedUsers = 0, postEngagements = 0, consumptions = 0
        
        for insight in response.data {
            guard let valueString = insight.values.last?.value,
                  let value = Double(valueString) else { continue }
            
            switch insight.name {
            case "page_views_total":
                views = Int(value)
            case "page_fans":
                fans = Int(value)
            case "page_reach":
                reach = Int(value)
            case "page_impressions":
                impressions = Int(value)
            case "page_engaged_users":
                engagedUsers = Int(value)
            case "page_post_engagements":
                postEngagements = Int(value)
            case "page_consumptions":
                consumptions = Int(value)
            default:
                break
            }
        }
        
        self.pageViewsTotal = views
        self.pageFans = fans
        self.pageReach = reach
        self.pageImpressions = impressions
        self.pageEngagedUsers = engagedUsers
        self.pagePostEngagements = postEngagements
        self.pageConsumptions = consumptions
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
    var gradientColor: Color? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(color.opacity(0.8))
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(color.opacity(0.08))
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
            ZStack {
                if let gradientColor = gradientColor {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    gradientColor.opacity(0.05),
                                    gradientColor.opacity(0.02)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
            }
        )
    }
}

// MARK: - Facebook Page Selector

struct FacebookPageSelector: View {
    let pages: [PlatformAccount]
    @Binding var selectedPageID: String?
    
    var body: some View {
        Menu {
            ForEach(pages, id: \.id) { page in
                Button {
                    selectedPageID = page.accountID
                } label: {
                    HStack {
                        Text(page.displayName ?? page.username)
                        if selectedPageID == page.accountID {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundColor(.blue)
                Text(selectedPageName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .glassPanel(tier: .contentCard, cornerRadius: 12, tintColor: .blue.opacity(0.1))
        }
        .buttonStyle(.plain)
    }
    
    private var selectedPageName: String {
        guard let pageID = selectedPageID,
              let page = pages.first(where: { $0.accountID == pageID }) else {
            return pages.first?.displayName ?? pages.first?.username ?? "Select Page"
        }
        return page.displayName ?? page.username
    }
}

// MARK: - Facebook Page Insights Section

struct FacebookPageInsightsSection: View {
    let periodInsights: PageInsightsData?
    let lifetimeInsights: PageInsightsData?
    let isLoading: Bool
    let error: String?
    
    var body: some View {
        if isLoading {
            HStack {
                Spacer()
                ProgressView()
                    .padding(40)
                Spacer()
            }
            .glassPanel(tier: .contentCard, cornerRadius: 16)
        } else if let error = error {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Failed to load insights")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(16)
            .glassPanel(tier: .contentCard, cornerRadius: 16)
        } else if periodInsights == nil && lifetimeInsights == nil {
            HStack {
                Spacer()
                Text("No insights data available")
                    .foregroundColor(.secondary)
                    .padding(40)
                Spacer()
            }
            .glassPanel(tier: .contentCard, cornerRadius: 16)
        } else {
            VStack(spacing: 24) {
                // Current Period Section
                if let period = periodInsights {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.blue)
                            Text("Current Period")
                                .font(.headline)
                            Spacer()
                        }
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            GlassMetricCard(
                                title: "Page Views",
                                value: formatNumber(period.pageViewsTotal),
                                icon: "eye.fill",
                                color: .blue
                            )
                            
                            GlassMetricCard(
                                title: "Page Fans",
                                value: formatNumber(period.pageFans),
                                icon: "person.3.fill",
                                color: .purple
                            )
                            
                            GlassMetricCard(
                                title: "Page Reach",
                                value: formatNumber(period.pageReach),
                                icon: "arrow.up.right.circle.fill",
                                color: .orange
                            )
                            
                            GlassMetricCard(
                                title: "Impressions",
                                value: formatNumber(period.pageImpressions),
                                icon: "chart.bar.fill",
                                color: .green
                            )
                            
                            GlassMetricCard(
                                title: "Engaged Users",
                                value: formatNumber(period.pageEngagedUsers),
                                icon: "heart.fill",
                                color: .pink
                            )
                            
                            GlassMetricCard(
                                title: "Post Engagements",
                                value: formatNumber(period.pagePostEngagements),
                                icon: "hand.thumbsup.fill",
                                color: .yellow
                            )
                            
                            GlassMetricCard(
                                title: "Consumptions",
                                value: formatNumber(period.pageConsumptions),
                                icon: "play.circle.fill",
                                color: .indigo
                            )
                        }
                    }
                }
                
                // Lifetime Section
                if let lifetime = lifetimeInsights {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "infinity.circle.fill")
                                .foregroundColor(.orange)
                            Text("Lifetime")
                                .font(.headline)
                            Spacer()
                        }
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            GlassMetricCard(
                                title: "Total Page Views",
                                value: formatNumber(lifetime.pageViewsTotal),
                                icon: "eye.fill",
                                color: .blue
                            )
                            
                            GlassMetricCard(
                                title: "Total Fans",
                                value: formatNumber(lifetime.pageFans),
                                icon: "person.3.fill",
                                color: .purple
                            )
                            
                            GlassMetricCard(
                                title: "Total Reach",
                                value: formatNumber(lifetime.pageReach),
                                icon: "arrow.up.right.circle.fill",
                                color: .orange
                            )
                            
                            GlassMetricCard(
                                title: "Total Impressions",
                                value: formatNumber(lifetime.pageImpressions),
                                icon: "chart.bar.fill",
                                color: .green
                            )
                            
                            GlassMetricCard(
                                title: "Total Engaged Users",
                                value: formatNumber(lifetime.pageEngagedUsers),
                                icon: "heart.fill",
                                color: .pink
                            )
                            
                            GlassMetricCard(
                                title: "Total Post Engagements",
                                value: formatNumber(lifetime.pagePostEngagements),
                                icon: "hand.thumbsup.fill",
                                color: .yellow
                            )
                            
                            GlassMetricCard(
                                title: "Total Consumptions",
                                value: formatNumber(lifetime.pageConsumptions),
                                icon: "play.circle.fill",
                                color: .indigo
                            )
                        }
                    }
                }
            }
            .padding(20)
            .glassPanel(tier: .contentCard, cornerRadius: 16)
        }
    }
    
    private func formatNumber(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        } else {
            return "\(value)"
        }
    }
}

#Preview {
    InsightsView()
        .modelContainer(for: [Post.self])
}

