//
//  DashboardView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import CloutmateShared

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showSettings = false
    @State private var refreshID = UUID()
    @Query private var dashboardCards: [DashboardCard]
    @AppStorage("dashboard.section.workflow.collapsed") private var workflowCollapsed = false
    @AppStorage("dashboard.section.projects.collapsed") private var projectsCollapsed = false
    @AppStorage("dashboard.section.areas.collapsed") private var areasCollapsed = false
    @AppStorage("dashboard.section.resources.collapsed") private var resourcesCollapsed = false
    @AppStorage("dashboard.section.social.collapsed") private var socialCollapsed = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 28) {
                // Header
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Dashboard")
                            .font(.system(size: 28, weight: .bold))
                        Text("Plan your pipeline and publishing at a glance")
                            .metricLabelStyle()
                    }
                    Spacer()
                    Button(action: { showSettings = true }) {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .help("Dashboard Settings")
                }
                
                // Hero: Social Overview
                if isVisible(.socialOverview) {
                    SocialOverviewCard(size: .large)
                        .heroCard()
                        .frame(minWidth: 420, maxWidth: 520)
                        .padding(.top, 8)
                }
                
                // Sections grid
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                    DashboardSectionPanel(
                        title: "Workflow Focus",
                        icon: "bolt.fill",
                        accent: KosmicPalette.cyan,
                        isCollapsed: $workflowCollapsed
                    ) {
                        if anyVisible([.todayOverview, .inboxCount, .upcomingTasks, .upcomingDeadlines]) {
                            VStack(spacing: 12) {
                                if isVisible(.todayOverview) {
                                    TodayOverviewCard(size: size(for: .todayOverview, fallback: .medium))
                                }
                                if isVisible(.inboxCount) {
                                    InboxCountCard(size: size(for: .inboxCount, fallback: .small))
                                }
                                if isVisible(.upcomingTasks) {
                                    UpcomingTasksCard(size: size(for: .upcomingTasks, fallback: .medium))
                                }
                                if isVisible(.upcomingDeadlines) {
                                    UpcomingDeadlinesCard(size: size(for: .upcomingDeadlines, fallback: .medium))
                                }
                            }
                        } else {
                            sectionEmptyBanner(
                                primary: "No workflow cards enabled",
                                secondary: "Toggle on PARA essentials in Dashboard Settings.",
                                accent: KosmicPalette.cyan
                            )
                        }
                    }

                    DashboardSectionPanel(
                        title: "Projects",
                        icon: "folder.fill",
                        accent: KosmicPalette.violet,
                        isCollapsed: $projectsCollapsed
                    ) {
                        if anyVisible([.projectsOverview, .activeProjects, .tasksOverview, .completionRate]) {
                            VStack(spacing: 12) {
                                if isVisible(.projectsOverview) {
                                    ProjectsOverviewCard(size: size(for: .projectsOverview, fallback: .medium))
                                }
                                if isVisible(.activeProjects) {
                                    ActiveProjectsCard(size: size(for: .activeProjects, fallback: .small))
                                }
                                if isVisible(.tasksOverview) {
                                    TasksOverviewCard(size: size(for: .tasksOverview, fallback: .medium))
                                }
                                if isVisible(.completionRate) {
                                    CompletionRateCard(size: size(for: .completionRate, fallback: .small))
                                }
                            }
                        } else {
                            sectionEmptyBanner(
                                primary: "No project cards enabled",
                                secondary: "Surface your active initiatives from Settings.",
                                accent: KosmicPalette.violet
                            )
                        }
                    }

                    DashboardSectionPanel(
                        title: "Areas",
                        icon: "square.grid.2x2.fill",
                        accent: KosmicPalette.cyan,
                        isCollapsed: $areasCollapsed
                    ) {
                        if anyVisible([.areasHealth]) {
                            if isVisible(.areasHealth) {
                                AreasHealthCard(size: size(for: .areasHealth, fallback: .medium))
                            }
                        } else {
                            sectionEmptyBanner(
                                primary: "No area cards enabled",
                                secondary: "Keep track of your pillars by enabling area insights.",
                                accent: KosmicPalette.cyan
                            )
                        }
                    }

                    DashboardSectionPanel(
                        title: "Resources",
                        icon: "book.closed.fill",
                        accent: KosmicPalette.violet,
                        isCollapsed: $resourcesCollapsed
                    ) {
                        if anyVisible([.notesActivity, .recentNotes]) {
                            VStack(spacing: 12) {
                                if isVisible(.notesActivity) {
                                    NotesActivityCard(size: size(for: .notesActivity, fallback: .medium))
                                }
                                if isVisible(.recentNotes) {
                                    RecentNotesCard(size: size(for: .recentNotes, fallback: .medium))
                                }
                            }
                        } else {
                            sectionEmptyBanner(
                                primary: "No resource cards enabled",
                                secondary: "Enable note activity to illuminate your knowledge base.",
                                accent: KosmicPalette.violet
                            )
                        }
                    }

                    DashboardSectionPanel(
                        title: "Social",
                        icon: "chart.bar.fill",
                        accent: KosmicPalette.cyan,
                        isCollapsed: $socialCollapsed
                    ) {
                        if anyVisible([.contentPerformance, .platformComparison]) {
                            VStack(spacing: 12) {
                                if isVisible(.contentPerformance) {
                                    ContentPerformanceCard(size: size(for: .contentPerformance, fallback: .medium))
                                }
                                if isVisible(.platformComparison) {
                                    PlatformComparisonCard(size: size(for: .platformComparison, fallback: .medium))
                                }
                            }
                        } else {
                            sectionEmptyBanner(
                                primary: "No social cards enabled",
                                secondary: "Add publishing insights from Dashboard Settings when needed.",
                                accent: KosmicPalette.cyan
                            )
                        }
                    }
                }
                .padding(.top, 4)
            }
            .padding(28)
            .animation(.easeOut(duration: 0.2), value: refreshID)
        }
        .scrollContentBackground(.hidden)
        .background(.background)
        .sheet(isPresented: $showSettings) {
            DashboardSettingsView()
        }
        .onAppear {
            ensureDefaultCards()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshViewsFromMenuBar"))) { _ in
            // Refresh view when notification received from menu bar
            refreshID = UUID()
        }
        .id(refreshID)
    }
    
    // MARK: - Helpers
    private func isVisible(_ type: DashboardCardType) -> Bool {
        dashboardCards.first(where: { $0.type == type })?.isVisible ?? false
    }
    private func size(for type: DashboardCardType, fallback: DashboardCardSize) -> DashboardCardSize {
        dashboardCards.first(where: { $0.type == type })?.cardSize ?? fallback
    }
    private func anyVisible(_ types: [DashboardCardType]) -> Bool {
        types.contains { isVisible($0) }
    }
    @ViewBuilder
    private func sectionEmptyBanner(primary: String, secondary: String?, accent: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(primary)
                    .sectionTitleStyle()
                if let secondary {
                    Text(secondary)
                        .metricLabelStyle()
                }
            }
            Spacer()
        }
        .padding(12)
        .background(accent.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accent.opacity(0.2), lineWidth: 1)
        )
    }

    private func ensureDefaultCards() {
        let existingTypes = Set(dashboardCards.map { $0.type })
        var position = dashboardCards.map { $0.position }.max() ?? -1
        
        let defaultCards: [(DashboardCardType, DashboardCardSize)] = [
            (.socialOverview, .large),
            (.todayOverview, .medium),
            (.inboxCount, .small),
            (.upcomingTasks, .medium),
            (.upcomingDeadlines, .medium),
            (.projectsOverview, .medium),
            (.activeProjects, .small),
            (.tasksOverview, .medium),
            (.completionRate, .small),
            (.areasHealth, .medium),
            (.notesActivity, .medium),
            (.recentNotes, .medium)
        ]
        
        var inserted = false
        for (type, size) in defaultCards where !existingTypes.contains(type) {
            position += 1
            let card = DashboardCard(cardType: type, position: position, size: size)
            if type == .socialOverview {
                card.isVisible = true
            }
            modelContext.insert(card)
            inserted = true
        }
        
        if inserted {
            try? modelContext.save()
        }
    }
}

#Preview {
    DashboardView()
}
