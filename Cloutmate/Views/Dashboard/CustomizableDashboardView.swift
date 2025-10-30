//
//  CustomizableDashboardView.swift
//  Cloutmate
//
//  Customizable Dashboard with Drag-and-Drop Layout
//

import SwiftUI
import SwiftData

struct CustomizableDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userCards: [DashboardCard]
    @Query private var dashboardCards: [DashboardCard]
    
    @State private var showSettings = false
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
                
                // Hero: Social Overview (centered, elevated)
                if isVisible(.socialOverview) {
                    SocialOverviewCard(size: .large)
                        .heroCard()
                        .frame(minWidth: 420, maxWidth: 520)
                        .padding(.top, 8)
                }
                
                // Structured Sections (two-column adaptive)
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
        }
        .background(Color.clear)
        .navigationTitle("Dashboard")
        .sheet(isPresented: $showSettings) {
            DashboardSettingsView()
        }
        .onAppear {
            ensureDefaultCards()
        }
    }
    
    private func ensureDefaultCards() {
        if userCards.isEmpty {
            let defaults: [(DashboardCardType, DashboardCardSize)] = [
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
            
            for (index, entry) in defaults.enumerated() {
                let card = DashboardCard(cardType: entry.0, position: index, size: entry.1)
                if entry.0 == .socialOverview {
                    card.isVisible = true
                }
                modelContext.insert(card)
            }
            
            try? modelContext.save()
        }
    }
    
    // MARK: - Section helpers
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
}

struct DashboardCardView: View {
    let card: DashboardCard
    let cardSize: DashboardCardSize
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Card Header
            HStack {
                Image(systemName: card.type.icon)
                    .foregroundColor(KosmicPalette.violet)
                
                Text(card.type.rawValue)
                    .font(.system(size: 20, weight: .semibold))
                
                Spacer()
                
                if card.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundColor(KosmicPalette.neutral600)
                        .font(.caption)
                }
            }
            
            // Card Content based on type
            Group {
                switch card.type {
                // Existing cards
                case .todayOverview:
                    TodayOverviewCard(size: cardSize)
                case .inboxCount:
                    InboxCountCard(size: cardSize)
                case .activeProjects:
                    ActiveProjectsCard(size: cardSize)
                case .upcomingTasks:
                    UpcomingTasksCard(size: cardSize)
                case .scheduledPosts:
                    ScheduledPostsCard(size: cardSize)
                case .draftCount:
                    DraftCountCard(size: cardSize)
                case .recentNotes:
                    RecentNotesCard(size: cardSize)
                
                // PARA Workflow Insights
                case .projectsOverview:
                    ProjectsOverviewCard(size: cardSize)
                case .tasksOverview:
                    TasksOverviewCard(size: cardSize)
                case .areasHealth:
                    AreasHealthCard(size: cardSize)
                case .notesActivity:
                    NotesActivityCard(size: cardSize)
                
                // Social Media Insights
                case .socialOverview:
                    SocialOverviewCard(size: cardSize)
                case .contentPerformance:
                    ContentPerformanceCard(size: cardSize)
                case .platformComparison:
                    PlatformComparisonCard(size: cardSize)
                
                // Facebook Page Insights
                case .facebookPageInsightsOverview:
                    FacebookPageInsightsOverviewCard(size: cardSize)
                case .facebookPageViews:
                    FacebookPageViewsCard(size: cardSize)
                case .facebookPageFans:
                    FacebookPageFansCard(size: cardSize)
                case .facebookPageReach:
                    FacebookPageReachCard(size: cardSize)
                case .facebookPageImpressions:
                    FacebookPageImpressionsCard(size: cardSize)
                case .facebookEngagedUsers:
                    FacebookEngagedUsersCard(size: cardSize)
                case .facebookPostEngagements:
                    FacebookPostEngagementsCard(size: cardSize)
                
                // Productivity Insights
                case .upcomingDeadlines:
                    UpcomingDeadlinesCard(size: cardSize)
                case .completionRate:
                    CompletionRateCard(size: cardSize)
                
                // Quick Actions
                case .quickCapture, .aiSuggestions:
                    VStack(alignment: .leading, spacing: 6) {
                        Text("This card arrives soon")
                            .metricLabelStyle()
                        Text("We’re polishing it for the next update.")
                            .metricLabelStyle()
                    }
                
                // Legacy cards
                case .postingStreak, .topPerformingPost, .recentInsights, .areasOverview, .workloadBalance, .inboxTrend:
                    VStack(alignment: .leading, spacing: 6) {
                        Text("This card arrives soon")
                            .metricLabelStyle()
                        Text("We’re polishing it for the next update.")
                            .metricLabelStyle()
                    }
                }
            }
        }
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? KosmicPalette.violet.opacity(0.4) : Color.clear, lineWidth: 2)
        )
    }
}

// Card Views
struct TodayOverviewCard: View {
    let size: DashboardCardSize
    @Query private var tasks: [Task]
    @Query private var inbox: [InboxItem]
    
    var body: some View {
        if size == .large {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(inbox.filter { $0.convertedAt == nil }.count) inbox items")
                    .font(.body)
                Divider()
                Text("\(tasks.filter { $0.status != .done }.count) active tasks")
                    .font(.body)
            }
        } else {
            VStack {
                Text("\(inbox.filter { $0.convertedAt == nil }.count)")
                    .font(.system(size: 36, weight: .bold))
                Text("inbox items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct InboxCountCard: View {
    let size: DashboardCardSize
    @Query private var inboxItems: [InboxItem]
    
    var unconvertedCount: Int {
        inboxItems.filter { $0.convertedAt == nil }.count
    }
    
    var body: some View {
        VStack {
            Text("\(unconvertedCount)")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.orange)
            Text(unconvertedCount == 1 ? "item waiting" : "items waiting")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct ActiveProjectsCard: View {
    let size: DashboardCardSize
    @Query(filter: #Predicate<Project> { $0.statusRaw == "active" }) private var projects: [Project]
    
    var body: some View {
        if size == .large {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(projects.prefix(5)) { project in
                    HStack {
                        Circle()
                            .fill(.blue)
                            .frame(width: 8, height: 8)
                        Text(project.title)
                            .font(.body)
                        Spacer()
                    }
                }
                if projects.isEmpty {
                    Text("No active projects")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } else {
            VStack {
                Text("\(projects.count)")
                    .font(.system(size: 36, weight: .bold))
                Text(projects.count == 1 ? "project" : "projects")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct UpcomingTasksCard: View {
    let size: DashboardCardSize
    @Query private var tasks: [Task]
    
    var upcoming: [Task] {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return tasks.filter { task in
            guard let due = task.dueDate else { return false }
            return due <= tomorrow && task.status != .done
        }
    }
    
    var body: some View {
        if size == .large {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(upcoming.prefix(8)) { task in
                    HStack {
                        Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(task.status == .done ? .green : .secondary)
                        Text(task.title)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                    }
                }
                if upcoming.isEmpty {
                    Text("No tasks due")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } else {
            VStack {
                Text("\(upcoming.count)")
                    .font(.system(size: 36, weight: .bold))
                Text(upcoming.count == 1 ? "task due" : "tasks due")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ScheduledPostsCard: View {
    let size: DashboardCardSize
    @Query private var posts: [Post]
    
    var scheduledToday: Int {
        posts.filter { post in
            guard let scheduled = post.scheduledDate else { return false }
            return Calendar.current.isDateInToday(scheduled)
        }.count
    }
    
    var body: some View {
        VStack {
            Text("\(scheduledToday)")
                .font(.system(size: 36, weight: .bold))
            Text(scheduledToday == 1 ? "post today" : "posts today")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct DraftCountCard: View {
    let size: DashboardCardSize
    @Query private var drafts: [Draft]
    
    var activeCount: Int {
        drafts.filter { !$0.isArchived }.count
    }
    
    var body: some View {
        VStack {
            Text("\(activeCount)")
                .font(.system(size: 36, weight: .bold))
            Text(activeCount == 1 ? "draft" : "drafts")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct RecentNotesCard: View {
    let size: DashboardCardSize
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    
    var body: some View {
        if size == .large {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(notes.prefix(8)) { note in
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text(note.title)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                    }
                }
                if notes.isEmpty {
                    Text("No notes yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } else {
            VStack {
                Text("\(notes.count)")
                    .font(.system(size: 36, weight: .bold))
                Text(notes.count == 1 ? "note" : "notes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    CustomizableDashboardView()
        .modelContainer(for: [DashboardCard.self, Task.self, InboxItem.self])
}
