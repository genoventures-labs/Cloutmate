//
//  CustomizableDashboardView.swift
//  FocusOS
//
//  Customizable Dashboard with Drag-and-Drop Layout
//

import SwiftUI
import SwiftData
import FocusOSShared

struct CustomizableDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Query private var userCards: [DashboardCard]
    @Query private var dashboardCards: [DashboardCard]
    
    @State private var showSettings = false
    @AppStorage("dashboard.section.workflow.collapsed") private var workflowCollapsed = false
    @AppStorage("dashboard.section.projects.collapsed") private var projectsCollapsed = false
    @AppStorage("dashboard.section.areas.collapsed") private var areasCollapsed = false
    @AppStorage("dashboard.section.resources.collapsed") private var resourcesCollapsed = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 28) {
                // Header
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Dashboard")
                            .font(.system(size: 28, weight: .bold))
                        Text("Your workspace overview and productivity insights")
                            .metricLabelStyle()
                    }
                    Spacer()
                    Button(action: { showSettings = true }) {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .help("Dashboard Settings")
                }
                
                // Hero: Today Overview (centered, elevated)
                if isVisible(.todayOverview) {
                    TodayOverviewCard(size: .large)
                        .heroCard()
                        .frame(minWidth: 420, maxWidth: 520)
                        .padding(.top, 8)
                }
                
                // Structured Sections (two-column adaptive)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                    DashboardSectionPanel(
                        title: "Workflow Focus",
                        icon: "bolt.fill",
                        accent: glassTint(.primary),
                        isCollapsed: $workflowCollapsed
                    ) {
                        if isVisible(.todayOverview) {
                            TodayOverviewCard(size: size(for: .todayOverview, fallback: .medium))
                        } else {
                            sectionEmptyBanner(
                                primary: "No workflow cards enabled",
                                secondary: "Toggle on PARA essentials in Dashboard Settings.",
                                accent: glassTint(.primary)
                            )
                        }
                    }

                    DashboardSectionPanel(
                        title: "Projects",
                        icon: "folder.fill",
                        accent: glassTint(.accent),
                        isCollapsed: $projectsCollapsed
                    ) {
                        if isVisible(.projectsOverview) {
                            ProjectsOverviewCard(size: size(for: .projectsOverview, fallback: .medium))
                        } else {
                            sectionEmptyBanner(
                                primary: "No project cards enabled",
                                secondary: "Surface your active initiatives from Settings.",
                                accent: glassTint(.accent)
                            )
                        }
                    }

                    DashboardSectionPanel(
                        title: "Areas",
                        icon: "square.grid.2x2.fill",
                        accent: glassTint(.primary),
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
                                accent: glassTint(.primary)
                            )
                        }
                    }

                    DashboardSectionPanel(
                        title: "Resources",
                        icon: "book.closed.fill",
                        accent: glassTint(.accent),
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
                                accent: glassTint(.accent)
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
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
                (.todayOverview, .large),
                (.inboxCount, .small),
                (.upcomingTasks, .medium),
                (.upcomingDeadlines, .medium),
                (.projectsOverview, .medium),
                (.areasHealth, .medium),
                (.notesActivity, .medium),
                (.recentNotes, .medium)
            ]
            
            for (index, entry) in defaults.enumerated() {
                let card = DashboardCard(cardType: entry.0, position: index, size: entry.1)
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

extension CustomizableDashboardView {
    private func glassTint(_ role: GlassColorSystem.GlassRole) -> Color {
        glassColorSystem.glassTint(for: role)
    }
}

struct DashboardCardView: View {
    let card: DashboardCard
    let cardSize: DashboardCardSize
    @State private var isHovered = false
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Card Header
            HStack {
                Image(systemName: card.type.icon)
                    .foregroundColor(glassTint(.accent))
                
                Text(card.type.rawValue)
                    .font(.system(size: 20, weight: .semibold))
                
                Spacer()
                
                if card.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundColor(glassTint(.surface))
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
                        Text("We're polishing it for the next update.")
                            .metricLabelStyle()
                    }
                
                // Legacy cards
                case .workloadBalance, .inboxTrend, .areasOverview:
                    VStack(alignment: .leading, spacing: 6) {
                        Text("This card arrives soon")
                            .metricLabelStyle()
                        Text("We're polishing it for the next update.")
                            .metricLabelStyle()
                    }
                }
            }
        }
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(glassTint(.accent), lineWidth: 2)
                .opacity(isHovered ? 0.4 : 0)
        )
    }

    private func glassTint(_ role: GlassColorSystem.GlassRole) -> Color {
        glassColorSystem.glassTint(for: role)
    }
}

// Card Views
struct TodayOverviewCard: View {
    let size: DashboardCardSize
    @Query private var tasks: [Task]
    @Query private var inbox: [InboxItem]
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        switch size {
        case .small:
            VStack(alignment: .leading, spacing: 8) {
                Text("\(inboxCount)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(glassTint(.primary))
                Text("Inbox items awaiting triage")
                    .font(.caption)
                    .dashboardSecondaryText()
            }
        default:
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 24) {
                    DashboardMetricTile(
                        label: "Inbox",
                        value: "\(inboxCount)",
                        accent: glassTint(.primary),
                        caption: inboxCount == 0 ? "All clear" : "Tap Inbox to convert"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    DashboardMetricTile(
                        label: "Active tasks",
                        value: "\(activeTasksCount)",
                        accent: glassTint(.accent),
                        caption: overdueCount > 0 ? "\(overdueCount) overdue" : "On schedule"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    DashboardMetricTile(
                        label: "Completed today",
                        value: "\(completedToday)",
                        accent: glassTint(.success)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Divider()
                    .overlay(.white.opacity(0.08))
                
                VStack(alignment: .leading, spacing: 18) {
                    focusSection
                    inboxSection
                    
                    Text(nextActionCopy)
                        .font(.footnote)
                        .dashboardSecondaryText()
                }
            }
        }
    }
    
    private var inboxCount: Int {
        inbox.filter { $0.convertedAt == nil }.count
    }
    
    private var activeTasksCount: Int {
        tasks.filter { $0.status != .done }.count
    }
    
    private var overdueCount: Int {
        let now = Date()
        return tasks.filter { task in
            guard let due = task.dueDate else { return false }
            return task.status != .done && due < now
        }.count
    }
    
    private var upcomingTasks: [Task] {
        let cutoff = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
        return tasks.filter { task in
            guard let due = task.dueDate else { return false }
            return task.status != .done && due >= Date() && due <= cutoff
        }
        .sorted { ($0.dueDate ?? Date()) < ($1.dueDate ?? Date()) }
    }
    
    private var inboxToConvert: [InboxItem] {
        inbox.filter { $0.convertedAt == nil }
            .sorted { $0.createdAt < $1.createdAt }
    }
    
    @ViewBuilder
    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today's Focus")
                .font(.subheadline)
                .fontWeight(.semibold)
                .dashboardSecondaryText()
            
            if upcomingTasks.isEmpty {
                Text("No tasks due soon. Review projects or capture the next step.")
                    .font(.footnote)
                    .dashboardSecondaryText()
            } else {
                ForEach(upcomingTasks.prefix(3)) { task in
                    focusTaskRow(task)
                }
            }
        }
    }
    
    @ViewBuilder
    private var inboxSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Inbox To Convert")
                .font(.subheadline)
                .fontWeight(.semibold)
                .dashboardSecondaryText()
            
            if inboxToConvert.isEmpty {
                Text("Inbox is clear. Capture anything on your mind.")
                    .font(.footnote)
                    .dashboardSecondaryText()
            } else {
                ForEach(inboxToConvert.prefix(3)) { item in
                    inboxRow(item)
                }
            }
        }
    }
    
    @ViewBuilder
    private func focusTaskRow(_ task: Task) -> some View {
        HStack(spacing: 12) {
            DashboardTag(text: "Due", color: glassTint(.accent))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title.isEmpty ? "Untitled task" : task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if let due = task.dueDate {
                    Text(due.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .dashboardSecondaryText()
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.primary.opacity(0.03))
        )
    }
    
    @ViewBuilder
    private func inboxRow(_ item: InboxItem) -> some View {
        HStack(spacing: 12) {
            DashboardTag(text: "Capture", color: glassTint(.primary))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.content.isEmpty ? "Untitled item" : item.content)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .dashboardSecondaryText()
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.primary.opacity(0.03))
        )
    }
    
    private var completedToday: Int {
        tasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return Calendar.current.isDateInToday(completedAt)
        }.count
    }
    
    private var nextActionCopy: String {
        if !inboxToConvert.isEmpty { return "You have inbox items waiting. Convert a few now to keep flow moving." }
        if overdueCount > 0 { return "Tackle overdue tasks first to reset momentum." }
        if activeTasksCount == 0 { return "No active tasks. Capture what’s next to stay in motion." }
        return "Great pace today! Wrap with a quick review or reflection."
    }

    private func glassTint(_ role: GlassColorSystem.GlassRole) -> Color {
        glassColorSystem.glassTint(for: role)
    }
}

struct InboxCountCard: View {
    let size: DashboardCardSize
    @Query private var inboxItems: [InboxItem]
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var unconvertedCount: Int {
        inboxItems.filter { $0.convertedAt == nil }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardMetricTile(
                label: unconvertedCount == 1 ? "Item waiting" : "Items waiting",
                value: "\(unconvertedCount)",
                accent: glassTint(.primary)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(unconvertedCount == 0 ? "Inbox is clear."
                 : "Convert a handful now so planning stays effortless.")
                .font(.footnote)
                .dashboardSecondaryText()
        }
    }

    private func glassTint(_ role: GlassColorSystem.GlassRole) -> Color {
        glassColorSystem.glassTint(for: role)
    }
}

struct ActiveProjectsCard: View {
    let size: DashboardCardSize
    @Query(filter: #Predicate<Project> { $0.statusRaw == "active" }) private var projects: [Project]
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        switch size {
        case .small:
            VStack(alignment: .leading, spacing: 8) {
                Text("\(projects.count)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(glassTint(.accent))
                Text(projects.count == 1 ? "Active project" : "Active projects")
                    .font(.caption)
                    .dashboardSecondaryText()
            }
        default:
            VStack(alignment: .leading, spacing: 24) {
                DashboardMetricTile(
                    label: "Active projects",
                    value: "\(projects.count)",
                    accent: glassTint(.accent),
                    caption: focusSummary
                )
                
                Divider()
                    .overlay(.white.opacity(0.08))
                
                if projects.isEmpty {
                    Text("No active projects right now. Choose one area to advance next.")
                        .font(.footnote)
                        .dashboardSecondaryText()
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(projects.prefix(4)) { project in
                            projectRow(project)
                        }
                    }
                }
            }
        }
    }
    
    private var focusSummary: String {
        if projects.isEmpty { return "Spin up your next initiative." }
        let names = projects.prefix(3).map { $0.title }
        return "Focused on " + names.joined(separator: ", ")
    }
    
    @ViewBuilder
    private func projectRow(_ project: Project) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(glassTint(.accent))
                .frame(width: 24, height: 24)
                .opacity(0.2)
                .overlay(
                    Image(systemName: "folder.fill")
                        .foregroundColor(glassTint(.accent))
                        .font(.system(size: 12, weight: .semibold))
                )
            Text(project.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            Spacer()
            Text(project.statusRaw.capitalized)
                .font(.caption2)
                .dashboardSecondaryText()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.primary.opacity(0.03))
        )
    }

    private func glassTint(_ role: GlassColorSystem.GlassRole) -> Color {
        glassColorSystem.glassTint(for: role)
    }
} 

struct UpcomingTasksCard: View {
    let size: DashboardCardSize
    @Query private var tasks: [Task]
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var upcoming: [Task] {
        let deadline = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return tasks.filter { task in
            guard let due = task.dueDate else { return false }
            return due <= deadline && task.status != .done
        }
        .sorted { ($0.dueDate ?? Date()) < ($1.dueDate ?? Date()) }
    }
    
    var body: some View {
        switch size {
        case .small:
            VStack(alignment: .leading, spacing: 8) {
                Text("\(upcoming.count)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(upcoming.isEmpty ? .secondary : glassTint(.primary))
                Text(upcoming.count == 1 ? "Task due soon" : "Tasks due soon")
                    .font(.caption)
                    .dashboardSecondaryText()
            }
        default:
            VStack(alignment: .leading, spacing: 24) {
                DashboardMetricTile(
                    label: "Due this week",
                    value: "\(upcoming.count)",
                    accent: upcoming.isEmpty ? .secondary : glassTint(.primary),
                    caption: upcoming.first?.dueDate.map { "Next due \($0.formatted(date: .abbreviated, time: .omitted))" }
                )
                
                Divider()
                    .overlay(.white.opacity(0.08))
                
                if upcoming.isEmpty {
                    Text("You’re ahead of schedule. Check back for upcoming commitments.")
                        .font(.footnote)
                        .dashboardSecondaryText()
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(upcoming.prefix(5)) { task in
                            taskRow(task)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func taskRow(_ task: Task) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(glassTint(.accent))
                .frame(width: 24, height: 24)
                .opacity(0.18)
                .overlay(
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(glassTint(.accent))
                        .font(.system(size: 12, weight: .semibold))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if let due = task.dueDate {
                    Text(due.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .dashboardSecondaryText()
                }
            }
            Spacer()
            if let priority = TaskPriority(rawValue: task.priorityRaw) {
                DashboardTag(text: priority.displayName, color: color(for: priority))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.primary.opacity(0.03))
        )
    }
    
    private func color(for priority: TaskPriority) -> Color {
        switch priority {
        case .high: return glassTint(.danger)
        case .medium: return glassTint(.primary)
        case .low: return glassTint(.surface)
        }
    }

    private func glassTint(_ role: GlassColorSystem.GlassRole) -> Color {
        glassColorSystem.glassTint(for: role)
    }
}

struct ScheduledPostsCard: View {
    let size: DashboardCardSize
    @Query private var posts: [Post]
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var scheduledToday: Int {
        posts.filter { post in
            guard let scheduled = post.scheduledDate else { return false }
            return Calendar.current.isDateInToday(scheduled)
        }.count
    }
    
    var scheduledThisWeek: Int {
        let end = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return posts.filter { post in
            guard let scheduled = post.scheduledDate else { return false }
            return scheduled >= Date() && scheduled <= end
        }.count
    }
    
    var body: some View {
        switch size {
        case .small:
            VStack(alignment: .leading, spacing: 8) {
                Text("\(scheduledToday)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(glassTint(.accent))
                Text(scheduledToday == 1 ? "Post scheduled today" : "Posts scheduled today")
                    .font(.caption)
                    .dashboardSecondaryText()
            }
        default:
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 24) {
                    DashboardMetricTile(
                        label: "Today",
                        value: "\(scheduledToday)",
                        accent: glassTint(.accent)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    DashboardMetricTile(
                        label: "Next 7 days",
                        value: "\(scheduledThisWeek)",
                        accent: glassTint(.primary)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Divider()
                    .overlay(.white.opacity(0.08))
                
                Text(scheduledToday == 0 ? "No posts scheduled today. Queue something to keep feeds active." : "Content is lined up—review captions or creative if you need refinements.")
                    .font(.footnote)
                    .dashboardSecondaryText()
            }
        }
    }
    
    private func glassTint(_ role: GlassColorSystem.GlassRole) -> Color {
        glassColorSystem.glassTint(for: role)
    }
}

struct DraftCountCard: View {
    let size: DashboardCardSize
    @Query private var drafts: [Draft]
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var activeCount: Int {
        drafts.filter { !$0.isArchived }.count
    }
    
    var body: some View {
        switch size {
        case .small:
            VStack(alignment: .leading, spacing: 8) {
                Text("\(activeCount)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(glassTint(.primary))
                Text(activeCount == 1 ? "Active draft" : "Active drafts")
                    .font(.caption)
                    .dashboardSecondaryText()
            }
        default:
            VStack(alignment: .leading, spacing: 18) {
                DashboardMetricTile(
                    label: activeCount == 1 ? "Active draft" : "Active drafts",
                    value: "\(activeCount)",
                    accent: glassTint(.primary),
                    caption: drafts.isEmpty ? "Spin up a new idea." : "Newest edited \(latestEdit)"
                )
                
                Divider()
                    .overlay(.white.opacity(0.08))
                
                Text(activeCount == 0 ? "Repurpose a top post or outline a fresh concept." : "Review your top draft and move it into scheduling when ready.")
                    .font(.footnote)
                    .dashboardSecondaryText()
            }
        }
    }
    
    private var latestEdit: String {
        guard let last = drafts.sorted(by: { $0.updatedAt > $1.updatedAt }).first else { return "—" }
        return last.updatedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private func glassTint(_ role: GlassColorSystem.GlassRole) -> Color {
        glassColorSystem.glassTint(for: role)
    }
}

struct RecentNotesCard: View {
    let size: DashboardCardSize
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        switch size {
        case .small:
            VStack(alignment: .leading, spacing: 8) {
                Text("\(notes.count)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(glassTint(.accent))
                Text(notes.count == 1 ? "Note on file" : "Notes on file")
                    .font(.caption)
                    .dashboardSecondaryText()
            }
        default:
            VStack(alignment: .leading, spacing: 24) {
                DashboardMetricTile(
                    label: notes.count == 1 ? "Note archived" : "Notes archived",
                    value: "\(notes.count)",
                    accent: glassTint(.accent),
                    caption: latestNoteCopy
                )
                
                Divider()
                    .overlay(.white.opacity(0.08))
                
                if notes.isEmpty {
                    Text("You haven’t captured anything yet. Start a note to collect ideas and references.")
                        .font(.footnote)
                        .dashboardSecondaryText()
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(notes.prefix(5)) { note in
                            noteRow(note)
                        }
                    }
                }
            }
        }
    }
    
    private var latestNoteCopy: String {
        guard let latest = notes.first else { return "No notes yet" }
        return "Last updated " + latest.updatedAt.formatted(date: .abbreviated, time: .shortened)
    }
    
    @ViewBuilder
    private func noteRow(_ note: Note) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(glassTint(.primary))
                .frame(width: 24, height: 24)
                .opacity(0.18)
                .overlay(
                    Image(systemName: "doc.text")
                        .foregroundColor(glassTint(.primary))
                        .font(.system(size: 12, weight: .semibold))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title.isEmpty ? "Untitled note" : note.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .dashboardSecondaryText()
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.primary.opacity(0.03))
        )
    }

    private func glassTint(_ role: GlassColorSystem.GlassRole) -> Color {
        glassColorSystem.glassTint(for: role)
    }
}

#Preview {
    CustomizableDashboardView()
        .modelContainer(for: [DashboardCard.self, FocusOSShared.Task.self, FocusOSShared.InboxItem.self])
}
