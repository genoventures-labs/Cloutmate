//
//  WorkflowInsightsCards.swift
//  FocusOS
//
//  PARA and Productivity Insight Cards
//

import SwiftUI
import SwiftData
import FocusOSShared

// MARK: - Projects Overview Card
struct ProjectsOverviewCard: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    let size: DashboardCardSize
    @Query private var projects: [FocusOSShared.Project]
    @Query private var tasks: [FocusOSShared.Task]
    
    var activeProjects: [FocusOSShared.Project] {
        projects.filter { $0.status == .active }
    }
    
    private var activeAreasCount: Int {
        Set(activeProjects.compactMap { $0.areaId }).count
    }
    
    private var nextProjectDeadline: Date? {
        activeProjects.compactMap { $0.dueDate }.sorted().first
    }
    
    private var upcomingMilestones: [(project: Project, task: Task)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        let projectTasks = tasks.filter { task in
            guard let due = task.dueDate else { return false }
            return task.status != .done && due >= Date() && due <= cutoff
        }
        return projectTasks.compactMap { task in
            guard let projectId = task.projectId,
                  let project = activeProjects.first(where: { $0.id == projectId }) else { return nil }
            return (project, task)
        }
        .sorted { ($0.task.dueDate ?? Date()) < ($1.task.dueDate ?? Date()) }
    }
    
    private var recentlyUpdated: [Project] {
        activeProjects.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    var body: some View {
        Group {
            if size == .large { largeContent } else if size == .medium { mediumContent } else { smallContent }
        }
    }

    private var largeContent: some View {
        cardBody
    }

    private var mediumContent: some View {
        cardBody
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 18) {
                DashboardMetricTile(
                    label: "Active projects",
                    value: "\(activeProjects.count)",
                    accent: glassTint(.primary),
                    caption: projects.isEmpty ? "Start a new initiative" : "Across \(projects.count) total"
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                
                DashboardMetricTile(
                    label: "Next deadline",
                    value: nextProjectDeadline.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "—",
                    accent: glassTint(.accent),
                    caption: nextProjectDeadline == nil ? "No project dates set" : "Keep the momentum"
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                
                DashboardMetricTile(
                    label: "Active areas",
                    value: "\(activeAreasCount)",
                    accent: glassTint(.primary),
                    caption: activeAreasCount == 0 ? "Assign projects to pillars" : "Coverage across PARA pillars"
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Divider()
                .overlay(.white.opacity(0.08))
            
            VStack(alignment: .leading, spacing: 18) {
                milestonesSection
                recentlyUpdatedSection
            }
        }
    }

    private var smallContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(activeProjects.count)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(glassTint(.primary))
            Text("Active Projects")
                .font(.caption)
                .dashboardSecondaryText()
        }
    }
    
    @ViewBuilder
    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Next milestones")
                .font(.subheadline)
                .fontWeight(.semibold)
                .dashboardSecondaryText()
            
            if upcomingMilestones.isEmpty {
                Text("No upcoming deadlines this week. Check in on each project to plan the next step.")
                    .font(.footnote)
                    .dashboardSecondaryText()
            } else {
                ForEach(upcomingMilestones.prefix(3), id: \.task.id) { milestone in
                    milestoneRow(project: milestone.project, task: milestone.task)
                }
            }
        }
    }
    
    @ViewBuilder
    private var recentlyUpdatedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recently updated")
                .font(.subheadline)
                .fontWeight(.semibold)
                .dashboardSecondaryText()
            
            if recentlyUpdated.isEmpty {
                Text("No active projects right now. Choose one area to advance next.")
                    .font(.footnote)
                    .dashboardSecondaryText()
            } else {
                ForEach(recentlyUpdated.prefix(3)) { project in
                    projectSnapshot(project)
                }
            }
        }
    }
    
    @ViewBuilder
    private func milestoneRow(project: Project, task: Task) -> some View {
        HStack(spacing: 12) {
            DashboardTag(text: project.title, color: glassTint(.primary))
            
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
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.primary.opacity(0.03))
        )
    }
    
    @ViewBuilder
    private func projectSnapshot(_ project: Project) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(glassTint(.primary).opacity(0.18))
                .frame(width: 20, height: 20)
                .overlay(
                    Image(systemName: "folder.fill")
                        .foregroundColor(glassTint(.primary))
                        .font(.system(size: 10, weight: .semibold))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(project.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text("Updated \(project.updatedAt.formatted(date: .abbreviated, time: .shortened))")
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

// MARK: - Tasks Overview Card
struct TasksOverviewCard: View {
    let size: DashboardCardSize
    @Query private var tasks: [Task]
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var tasksByPriority: (high: Int, medium: Int, low: Int) {
        let high = tasks.filter { $0.priority == .high && $0.status != .done }.count
        let medium = tasks.filter { $0.priority == .medium && $0.status != .done }.count
        let low = tasks.filter { $0.priority == .low && $0.status != .done }.count
        return (high, medium, low)
    }
    
    var overdueTasks: Int {
        let now = Date()
        return tasks.filter { task in
            guard let due = task.dueDate, task.status != .done else { return false }
            return due < now
        }.count
    }
    
    var completionRate: Double {
        guard !tasks.isEmpty else { return 0 }
        let completed = tasks.filter { $0.status == .done }.count
        return Double(completed) / Double(tasks.count)
    }

    private var dueSoonTasks: [Task] {
        let cutoff = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
        return tasks
            .filter { task in
                guard let due = task.dueDate else { return false }
                return task.status != .done && due >= Date() && due <= cutoff
            }
            .sorted { ($0.dueDate ?? Date()) < ($1.dueDate ?? Date()) }
    }
    
    var body: some View {
        switch size {
        case .small:
            compactContent
        default:
            fullContent
        }
    }
    
    private var fullContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 24) {
                DashboardMetricTile(
                    label: "Active Tasks",
                    value: "\(tasks.filter { $0.status != .done }.count)",
                    accent: glassTint(.primary)
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                
                DashboardMetricTile(
                    label: "Completed",
                    value: "\(tasks.filter { $0.status == .done }.count)",
                    accent: glassTint(.accent)
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                
                DashboardMetricTile(
                    label: "Overdue",
                    value: "\(overdueTasks)",
                    accent: overdueTasks > 0 ? glassTint(.danger) : glassTint(.surface)
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Divider()
                .overlay(.white.opacity(0.08))
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Priority Mix")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .dashboardSecondaryText()
                
                priorityStack
            }

            Divider()
                .overlay(.white.opacity(0.08))

            VStack(alignment: .leading, spacing: 10) {
                Text("Due Soon")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .dashboardSecondaryText()

                if dueSoonTasks.isEmpty {
                    Text("Nothing pressing in the next couple of days. Review backlogs or plan upcoming work.")
                        .font(.footnote)
                        .dashboardSecondaryText()
                } else {
                    ForEach(dueSoonTasks.prefix(3)) { task in
                        dueSoonRow(task)
                    }
                }
            }
        }
    }
    
    private var compactContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(tasks.filter { $0.status != .done }.count)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(glassTint(.primary))
            Text("Active Tasks")
                .font(.caption)
                .dashboardSecondaryText()
        }
    }
    
    private var priorityStack: some View {
        let total = max(tasksByPriority.high + tasksByPriority.medium + tasksByPriority.low, 1)
        return VStack(alignment: .leading, spacing: 10) {
            PriorityBar(priority: .high, count: tasksByPriority.high, total: total, color: glassTint(.accent))
            PriorityBar(priority: .medium, count: tasksByPriority.medium, total: total, color: glassTint(.primary))
            PriorityBar(priority: .low, count: tasksByPriority.low, total: total, color: glassTint(.surface))
        }
    }

    @ViewBuilder
    private func dueSoonRow(_ task: Task) -> some View {
        HStack(spacing: 12) {
            DashboardTag(text: task.priority.displayName, color: color(for: task.priority))
            
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
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.primary.opacity(0.03))
        )
    }
    
    private func color(for priority: TaskPriority) -> Color {
        switch priority {
        case .high: return glassTint(.accent)
        case .medium: return glassTint(.primary)
        case .low: return glassTint(.surface)
        }
    }
    
    private func glassTint(_ role: GlassColorSystem.GlassRole) -> Color {
        glassColorSystem.glassTint(for: role)
    }
}

struct PriorityBar: View {
    let priority: TaskPriority
    let count: Int
    let total: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                DashboardTag(text: priority.displayName, color: color)
                Spacer()
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                let width = geometry.size.width
                let ratio = total > 0 ? Double(count) / Double(total) : 0
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.primary.opacity(0.05))
                    .frame(height: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(color.opacity(0.85))
                            .frame(width: width * ratio, height: 10)
                            .animation(.easeInOut(duration: 0.3), value: ratio)
                    )
            }
            .frame(height: 10)
        }
    }
}

// MARK: - Areas Health Card
struct AreasHealthCard: View {
    let size: DashboardCardSize
    @Query private var areas: [Area]
    @Query private var tasks: [Task]
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var healthyAreas: Int {
        areas.filter { area in
            let areaTasks = tasks.filter { $0.areaId == area.id }
            guard !areaTasks.isEmpty else { return false }
            let completionRate = Double(areaTasks.filter { $0.status == .done }.count) / Double(areaTasks.count)
            return completionRate > 0.7
        }.count
    }
    
    var needsAttention: Int {
        areas.filter { area in
            let areaTasks = tasks.filter { $0.areaId == area.id && $0.status != .done }
            return !areaTasks.isEmpty
        }.count
    }
    
    private var highlightedAreas: [(area: Area, detail: String, tone: Color)] {
        let attention: [(Area, String, Color)] = areas.compactMap { area in
            let activeTasks = tasks.filter { $0.areaId == area.id && $0.status != .done }
            guard !activeTasks.isEmpty else { return nil }
            let overdue = activeTasks.filter { task in
                guard let due = task.dueDate else { return false }
                return due < Date()
            }.count
            let caption = overdue > 0 ? "\(overdue) overdue tasks" : "\(activeTasks.count) tasks queued"
            return (area, caption, glassTint(.danger))
        }
        
        let thriving: [(Area, String, Color)] = areas.compactMap { area in
            let allTasks = tasks.filter { $0.areaId == area.id }
            guard !allTasks.isEmpty else { return nil }
            let completion = Double(allTasks.filter { $0.status == .done }.count) / Double(allTasks.count)
            guard completion >= 0.7 else { return nil }
            return (area, "\(Int(completion * 100))% complete", glassTint(.success))
        }
        
        return Array(attention.prefix(3) + thriving.prefix(2))
    }
    
    var body: some View {
        switch size {
        case .small:
            VStack(alignment: .leading, spacing: 8) {
                Text("\(healthyAreas)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(glassTint(.success))
                Text("Healthy Areas")
                    .font(.caption)
                    .dashboardSecondaryText()
            }
        default:
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 24) {
            DashboardMetricTile(
                label: "Total Areas",
                value: "\(areas.count)",
                accent: glassTint(.primary)
            )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
            DashboardMetricTile(
                label: "Healthy",
                value: "\(healthyAreas)",
                accent: glassTint(.success)
            )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
            DashboardMetricTile(
                label: "Needs Attention",
                value: "\(needsAttention)",
                accent: needsAttention > 0 ? glassTint(.danger) : glassTint(.surface)
            )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Divider()
                    .overlay(.white.opacity(0.08))
                
                if highlightedAreas.isEmpty {
                    Text("All areas are on track. Keep logging progress to maintain balance.")
                        .font(.footnote)
                        .dashboardSecondaryText()
                } else {
                    ForEach(highlightedAreas, id: \.area.id) { entry in
                        areaRow(area: entry.area, caption: entry.detail, tone: entry.tone)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func areaRow(area: Area, caption: String, tone: Color) -> some View {
        HStack(spacing: 12) {
            DashboardTag(text: area.title, color: tone)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(caption)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text("Updated \(area.updatedAt.formatted(date: .abbreviated, time: .shortened))")
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

// MARK: - Notes Activity Card
struct NotesActivityCard: View {
    let size: DashboardCardSize
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var recentNotes: [Note] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return notes.filter { $0.updatedAt >= weekAgo }
    }
    
    var body: some View {
        switch size {
        case .small:
            VStack(alignment: .leading, spacing: 8) {
                Text("\(recentNotes.count)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(glassTint(.primary))
                Text("Notes this week")
                    .font(.caption)
                    .dashboardSecondaryText()
            }
        case .medium:
            summarySection
        case .large:
            VStack(alignment: .leading, spacing: 24) {
                summarySection
                
                Divider()
                    .overlay(.white.opacity(0.08))
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Latest additions")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .dashboardSecondaryText()
                    
                    ForEach(recentNotes.prefix(5)) { note in
                        noteRow(note)
                    }
                    
                    if recentNotes.isEmpty {
                        Text("No new notes this week. Capture something you learned!")
                            .font(.footnote)
                            .dashboardSecondaryText()
                    }
                }
            }
        }
    }
    
    private var summarySection: some View {
        HStack(spacing: 24) {
            DashboardMetricTile(
                label: "Notes this week",
                value: "\(recentNotes.count)",
                accent: glassTint(.primary)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            
            DashboardMetricTile(
                label: "Total library",
                value: "\(notes.count)",
                accent: glassTint(.accent)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func glassTint(_ role: GlassColorSystem.GlassRole) -> Color {
        glassColorSystem.glassTint(for: role)
    }
    
    @ViewBuilder
    private func noteRow(_ note: Note) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Circle()
                .fill(glassTint(.accent).opacity(0.18))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "doc.text")
                        .foregroundColor(glassTint(.accent))
                        .font(.caption)
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
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.primary.opacity(0.03))
        )
    }
}

// MARK: - Upcoming Deadlines Card
struct UpcomingDeadlinesCard: View {
    let size: DashboardCardSize
    @Query private var tasks: [Task]
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var upcomingTasks: [Task] {
        let weekLater = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return tasks.filter { task in
            guard let due = task.dueDate, task.status != .done else { return false }
            return due <= weekLater && due > Date()
        }
        .sorted { ($0.dueDate ?? Date()) < ($1.dueDate ?? Date()) }
    }
    
    var body: some View {
        switch size {
        case .small:
            VStack(alignment: .leading, spacing: 8) {
                Text("\(upcomingTasks.count)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(upcomingTasks.isEmpty ? .secondary : glassTint(.primary))
                Text(upcomingTasks.count == 1 ? "Deadline" : "Deadlines")
                    .font(.caption)
                    .dashboardSecondaryText()
            }
        default:
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 24) {
                    DashboardMetricTile(
                        label: "Next 7 days",
                        value: "\(upcomingTasks.count)",
                        accent: upcomingTasks.isEmpty ? glassTint(.surface) : glassTint(.primary),
                        caption: upcomingTasks.first.flatMap { task in
                            task.dueDate.map { date in
                                "Next due \(relativeFormatter.localizedString(for: date, relativeTo: Date()))"
                            }
                        }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    DashboardMetricTile(
                        label: "Projects impacted",
                        value: "\(impactedProjects)",
                        accent: glassTint(.accent)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Divider()
                    .overlay(.white.opacity(0.08))
                
                if upcomingTasks.isEmpty {
                    Text("No deadlines in the next week. Schedule checkpoints to keep momentum.")
                        .font(.footnote)
                        .dashboardSecondaryText()
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(upcomingTasks.prefix(5).enumerated()), id: \.offset) { _, task in
                            deadlineRow(task: task)
                        }
                    }
                }
            }
        }
    }
    
    private func glassTint(_ role: GlassColorSystem.GlassRole) -> Color {
        glassColorSystem.glassTint(for: role)
    }
    
    private var impactedProjects: Int {
        let projectIDs = upcomingTasks.compactMap { $0.projectId }
        return Set(projectIDs).count
    }
    
    private var relativeFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }
    
    @ViewBuilder
    private func deadlineRow(task: Task) -> some View {
        let due = task.dueDate ?? Date()
        HStack(spacing: 16) {
            DashboardTag(text: "Due", color: glassTint(.primary))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(due.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .dashboardSecondaryText()
            }
            
            Spacer()
            
            Text(relativeFormatter.string(for: due) ?? "")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(glassTint(.accent))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.primary.opacity(0.03))
        )
    }
}

// MARK: - Completion Rate Card
struct CompletionRateCard: View {
    let size: DashboardCardSize
    @Query private var tasks: [Task]
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var weeklyCompletionRate: Double {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentTasks = tasks.filter { $0.createdAt >= weekAgo }
        guard !recentTasks.isEmpty else { return 0 }
        let completed = recentTasks.filter { $0.status == .done }.count
        return Double(completed) / Double(recentTasks.count)
    }
    
    var monthlyCompletionRate: Double {
        let monthAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentTasks = tasks.filter { $0.createdAt >= monthAgo }
        guard !recentTasks.isEmpty else { return 0 }
        let completed = recentTasks.filter { $0.status == .done }.count
        return Double(completed) / Double(recentTasks.count)
    }
    
    var body: some View {
        switch size {
        case .small:
            VStack(alignment: .leading, spacing: 8) {
                Text(formattedPercent(weeklyCompletionRate))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(glassTint(.accent))
                Text("Week completion")
                    .font(.caption)
                    .dashboardSecondaryText()
            }
        default:
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 24) {
                    DashboardMetricTile(
                        label: "This week",
                        value: formattedPercent(weeklyCompletionRate),
                        accent: glassTint(.accent),
                        caption: "\(completedTasks(in: 7)) of \(tasksCreated(in: 7)) tasks"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    DashboardMetricTile(
                        label: "30 day trend",
                        value: formattedPercent(monthlyCompletionRate),
                        accent: glassTint(.primary),
                        caption: deltaCaption
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Divider()
                    .overlay(.white.opacity(0.08))
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Momentum")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .dashboardSecondaryText()
                    
                    GeometryReader { geometry in
                        let width = geometry.size.width
                        let progress = max(0, min(weeklyCompletionRate, 1))
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.primary.opacity(0.06))
                            .frame(height: 12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(glassTint(.accent))
                                    .frame(width: width * progress, height: 12)
                                    .animation(.easeInOut(duration: 0.3), value: progress)
                            )
                    }
                    .frame(height: 12)
                }
            }
        }
    }
    
    private func tasksCreated(in days: Int) -> Int {
        let window = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return tasks.filter { $0.createdAt >= window }.count
    }
    
    private func completedTasks(in days: Int) -> Int {
        let window = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return tasks.filter { $0.createdAt >= window && $0.status == .done }.count
    }
    
    private func formattedPercent(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        return "\(Int(round(value * 100)))%"
    }
    
    private var deltaCaption: String {
        let delta = (weeklyCompletionRate - monthlyCompletionRate) * 100
        if abs(delta) < 0.5 || !delta.isFinite { return "In line with monthly" }
        let rounded = Int(round(delta))
        let sign = rounded > 0 ? "+" : ""
        return "\(sign)\(rounded) pts vs month"
    }
    
    private func glassTint(_ role: GlassColorSystem.GlassRole) -> Color {
        glassColorSystem.glassTint(for: role)
    }
}
