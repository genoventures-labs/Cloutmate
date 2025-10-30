//
//  FacebookInsightsCards.swift
//  Cloutmate
//
//  Facebook Page Insights Cards
//

import SwiftUI
import SwiftData
import CloutmateShared
import os.log

// MARK: - Facebook Page Insights Overview Card
struct FacebookPageInsightsOverviewCard: View {
    let size: DashboardCardSize
    @Query(filter: #Predicate<PlatformAccount> { $0.platform == "facebook" }) private var facebookPages: [PlatformAccount]
    
    @State private var selectedPageID: String? = nil
    @State private var pageInsights: PageInsightsData? = nil
    @State private var isLoading = false
    @State private var error: String? = nil
    
    var body: some View {
        Group {
            if size == .large {
                largeContent
            } else {
                compactContent
            }
        }
    }

    @ViewBuilder
    private var largeContent: some View {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if let insights = pageInsights {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    MetricCell(title: "Views", value: formatNumber(insights.pageViewsTotal), icon: "eye.fill", color: KosmicPalette.cyan)
                    MetricCell(title: "Fans", value: formatNumber(insights.pageFans), icon: "person.3.fill", color: KosmicPalette.violet)
                    MetricCell(title: "Reach", value: formatNumber(insights.pageReach), icon: "arrow.up.right.circle.fill", color: KosmicPalette.violet)
                    MetricCell(title: "Impressions", value: formatNumber(insights.pageImpressions), icon: "chart.bar.fill", color: KosmicPalette.cyan)
                    MetricCell(title: "Engaged Users", value: formatNumber(insights.pageEngagedUsers), icon: "heart.fill", color: KosmicPalette.violet)
                    MetricCell(title: "Engagements", value: formatNumber(insights.pagePostEngagements), icon: "hand.thumbsup.fill", color: KosmicPalette.cyan)
                    }
            } else if let err = error {
                Text("Error: \(err)")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Awaiting page insights")
                        .metricLabelStyle()
                    Text("Connect a Facebook Page to see metrics here.")
                        .metricLabelStyle()
                }
                }
            }
        .onAppear { fetchInsights() }
            }

    @ViewBuilder
    private var compactContent: some View {
            VStack {
                if isLoading {
                    ProgressView()
                } else if let insights = pageInsights {
                    Text(formatNumber(insights.pageViewsTotal))
                        .font(.system(size: 36, weight: .bold))
                    Text("Page Views")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                Text("Awaiting page insights")
                        .font(.caption)
                        .foregroundColor(.secondary)
            }
        }
        .onAppear { fetchInsights() }
    }
    
    private func fetchInsights() {
        guard let page = facebookPages.first else { return }
        isLoading = true
        
        _Concurrency.Task {
            do {
                let accessToken = try KeychainService.shared.getToken(forAccount: "facebook_page_\(page.accountID)_access_token")
                let response = try await MetaAPIService.shared.getPageInsights(pageID: page.accountID, accessToken: accessToken, period: .lifetime)
                
                await MainActor.run {
                    pageInsights = PageInsightsData(from: response)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
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

struct MetricCell: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            Text(value)
                .font(.system(size: 12, weight: .bold))
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Individual Facebook Metric Cards (Base)
private struct FacebookMetricCardBase: View {
    let size: DashboardCardSize
    let metricName: String
    let title: String
    let icon: String
    let color: Color
    
    @Query(filter: #Predicate<PlatformAccount> { $0.platform == "facebook" }) private var facebookPages: [PlatformAccount]
    @State private var pageInsights: PageInsightsData? = nil
    @State private var isLoading = false
    
    var metricValue: Int {
        guard let insights = pageInsights else { return 0 }
        switch metricName {
        case "page_views_total": return insights.pageViewsTotal
        case "page_fans": return insights.pageFans
        case "page_reach": return insights.pageReach
        case "page_impressions": return insights.pageImpressions
        case "page_engaged_users": return insights.pageEngagedUsers
        case "page_post_engagements": return insights.pagePostEngagements
        case "page_consumptions": return insights.pageConsumptions
        default: return 0
        }
    }
    
    var body: some View {
        if size == .large || size == .medium {
            VStack(alignment: .leading, spacing: 12) {
                if isLoading {
                    ProgressView()
                } else {
                    HStack {
                        Image(systemName: icon)
                            .foregroundColor(color)
                            .font(.title3)
                        Text(title)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    Text(formatNumber(metricValue))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(color)
                }
            }
            .onAppear {
                fetchInsights()
            }
        } else {
            VStack {
                if isLoading {
                    ProgressView()
                } else {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.title2)
                    Text(formatNumber(metricValue))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(color)
                    Text(title)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .onAppear {
                fetchInsights()
            }
        }
    }
    
    private func fetchInsights() {
        guard let page = facebookPages.first else { return }
        isLoading = true
        
        _Concurrency.Task {
            do {
                let accessToken = try KeychainService.shared.getToken(forAccount: "facebook_page_\(page.accountID)_access_token")
                let response = try await MetaAPIService.shared.getPageInsights(pageID: page.accountID, accessToken: accessToken, period: .lifetime)
                
                await MainActor.run {
                    pageInsights = PageInsightsData(from: response)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
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

// MARK: - Individual Metric Cards
struct FacebookPageViewsCard: View {
    let size: DashboardCardSize
    
    var body: some View {
        FacebookMetricCardBase(size: size, metricName: "page_views_total", title: "Page Views", icon: "eye.fill", color: KosmicPalette.cyan)
    }
}

struct FacebookPageFansCard: View {
    let size: DashboardCardSize
    
    var body: some View {
        FacebookMetricCardBase(size: size, metricName: "page_fans", title: "Fans", icon: "person.3.fill", color: KosmicPalette.violet)
    }
}

struct FacebookPageReachCard: View {
    let size: DashboardCardSize
    
    var body: some View {
        FacebookMetricCardBase(size: size, metricName: "page_reach", title: "Reach", icon: "arrow.up.right.circle.fill", color: KosmicPalette.violet)
    }
}

struct FacebookPageImpressionsCard: View {
    let size: DashboardCardSize
    
    var body: some View {
        FacebookMetricCardBase(size: size, metricName: "page_impressions", title: "Impressions", icon: "chart.bar.fill", color: KosmicPalette.cyan)
    }
}

struct FacebookEngagedUsersCard: View {
    let size: DashboardCardSize
    
    var body: some View {
        FacebookMetricCardBase(size: size, metricName: "page_engaged_users", title: "Engaged Users", icon: "heart.fill", color: KosmicPalette.violet)
    }
}

struct FacebookPostEngagementsCard: View {
    let size: DashboardCardSize
    
    var body: some View {
        FacebookMetricCardBase(size: size, metricName: "page_post_engagements", title: "Post Engagements", icon: "hand.thumbsup.fill", color: KosmicPalette.cyan)
    }
}

