//
//  DashboardGroups.swift
//  Cloutmate
//
//  Group shells for Pipeline, Social, Performance, Inbox.
//

import SwiftUI
import SwiftData

struct GroupHeader: View {
    let title: String
    let icon: String
    let accent: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(accent)
            Text(title).sectionTitleStyle()
            Spacer()
        }
    }
}

struct PipelineGroup: View {
    @Query private var cards: [DashboardCard]
    let defaultSize: DashboardCardSize = .medium
    
    private func isVisible(_ type: DashboardCardType) -> Bool {
        cards.first(where: { $0.type == type })?.isVisible ?? false
    }
    private func size(for type: DashboardCardType, fallback: DashboardCardSize) -> DashboardCardSize {
        cards.first(where: { $0.type == type })?.cardSize ?? fallback
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupHeader(title: "Pipeline", icon: "tray.full.fill", accent: KosmicPalette.cyan)
            VStack(spacing: 12) {
                if isVisible(.projectsOverview) { ProjectsOverviewCard(size: size(for: .projectsOverview, fallback: defaultSize)) }
                if isVisible(.tasksOverview) { TasksOverviewCard(size: size(for: .tasksOverview, fallback: defaultSize)) }
            }
        }
        .supportingCard()
    }
}

struct SocialGroup: View {
    @Query private var cards: [DashboardCard]
    let defaultSize: DashboardCardSize = .medium
    
    private func isVisible(_ type: DashboardCardType) -> Bool {
        cards.first(where: { $0.type == type })?.isVisible ?? false
    }
    private func size(for type: DashboardCardType, fallback: DashboardCardSize) -> DashboardCardSize {
        cards.first(where: { $0.type == type })?.cardSize ?? fallback
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupHeader(title: "Content & Artifacts", icon: "doc.text.fill", accent: KosmicPalette.violet)
            VStack(spacing: 12) {
                Text("Content insights and artifact analytics are available in the Insights tab.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }
        }
        .supportingCard()
    }
}

struct PerformanceGroup: View {
    @Query private var cards: [DashboardCard]
    let defaultSize: DashboardCardSize = .small
    
    private func isVisible(_ type: DashboardCardType) -> Bool {
        cards.first(where: { $0.type == type })?.isVisible ?? false
    }
    private func size(for type: DashboardCardType, fallback: DashboardCardSize) -> DashboardCardSize {
        cards.first(where: { $0.type == type })?.cardSize ?? fallback
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupHeader(title: "Performance", icon: "gauge.medium", accent: KosmicPalette.violet)
            VStack(spacing: 12) {
                if isVisible(.completionRate) { CompletionRateCard(size: size(for: .completionRate, fallback: defaultSize)) }
                // Posting Streak not implemented → friendly copy
                VStack(spacing: 6) {
                    Text("We’ll track your posting streaks here")
                        .metricLabelStyle()
                    Text("Stay consistent to keep momentum.")
                        .metricLabelStyle()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .supportingCard()
    }
}

struct InboxGroup: View {
    @Query private var cards: [DashboardCard]
    let defaultSize: DashboardCardSize = .small
    
    private func isVisible(_ type: DashboardCardType) -> Bool {
        cards.first(where: { $0.type == type })?.isVisible ?? false
    }
    private func size(for type: DashboardCardType, fallback: DashboardCardSize) -> DashboardCardSize {
        cards.first(where: { $0.type == type })?.cardSize ?? fallback
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupHeader(title: "Inbox", icon: "bell.badge.fill", accent: KosmicPalette.cyan)
            VStack(spacing: 12) {
                if isVisible(.inboxCount) { InboxCountCard(size: size(for: .inboxCount, fallback: defaultSize)) }
                if isVisible(.upcomingDeadlines) { UpcomingDeadlinesCard(size: size(for: .upcomingDeadlines, fallback: .medium)) }
            }
        }
        .supportingCard()
    }
}


