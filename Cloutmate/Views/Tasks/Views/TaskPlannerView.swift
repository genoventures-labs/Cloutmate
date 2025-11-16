import SwiftUI
import SwiftData
import CloutmateShared

struct TaskPlannerView: View {
    let tasks: [Task]
    let projects: [Project]
    let areas: [Area]
    let onTaskSelected: (Task) -> Void
    let onStartFocus: (Task) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    private var sections: [PlannerSection] {
        TaskPlannerView.buildSections(from: tasks, projects: projects, areas: areas)
    }
    
    var body: some View {
        if sections.isEmpty {
            emptyState
        } else {
            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(sections) { section in
                    PlannerSectionCard(
                        section: section,
                        onTaskSelected: onTaskSelected,
                        onStartFocus: onStartFocus
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.6))
            Text("Nothing scheduled yet")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(glassColorSystem.textPrimary())
            Text("Capture tasks or add due dates to populate the planner.")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(glassColorSystem.textSecondary())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
}

// MARK: - Section Builders

private extension TaskPlannerView {
    static func buildSections(from tasks: [Task], projects: [Project], areas: [Area]) -> [PlannerSection] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sevenDaysAhead = calendar.date(byAdding: .day, value: 7, to: today) ?? today
        let activeTasks = tasks.filter { $0.status != .done }
        
        let overdue = activeTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return due < today
        }
        
        let todayTasks = activeTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return calendar.isDate(due, inSameDayAs: today)
        }
        
        let upcoming = activeTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return due > today && due <= sevenDaysAhead
        }
        
        let later = activeTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return due > sevenDaysAhead
        }
        
        let unscheduled = activeTasks.filter { $0.dueDate == nil }
        
        let completed = tasks
            .filter { $0.status == .done }
            .sorted(by: { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) })
            .prefix(5)
        
        var sections: [PlannerSection] = []
        
        if !overdue.isEmpty {
            sections.append(PlannerSection(
                title: "Overdue",
                subtitle: "Nudge these back on course",
                accent: .red.opacity(0.85),
                tasks: enrichTasks(overdue, projects: projects, areas: areas)
            ))
        }
        
        if !todayTasks.isEmpty {
            sections.append(PlannerSection(
                title: "Today",
                subtitle: "Ground your focus",
                accent: Color.kosmicBlue.opacity(0.9),
                tasks: enrichTasks(todayTasks, projects: projects, areas: areas)
            ))
        }
        
        if !upcoming.isEmpty {
            sections.append(PlannerSection(
                title: "Next 7 Days",
                subtitle: "See what’s coming next",
                accent: Color.kosmicPurple.opacity(0.9),
                tasks: enrichTasks(upcoming.sorted(by: { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }), projects: projects, areas: areas)
            ))
        }
        
        if !later.isEmpty {
            sections.append(PlannerSection(
                title: "Later",
                subtitle: "Parked for future focus",
                accent: Color.kosmicGreen.opacity(0.9),
                tasks: enrichTasks(later.sorted(by: { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }), projects: projects, areas: areas)
            ))
        }
        
        if !unscheduled.isEmpty {
            sections.append(PlannerSection(
                title: "Someday",
                subtitle: "Ideas without a date",
                accent: Color.gray.opacity(0.65),
                tasks: enrichTasks(unscheduled, projects: projects, areas: areas)
            ))
        }
        
        if !completed.isEmpty {
            sections.append(PlannerSection(
                title: "Recently Completed",
                subtitle: "Momentum you’ve already built",
                accent: Color.kosmicBlue.opacity(0.55),
                tasks: enrichTasks(Array(completed), projects: projects, areas: areas, includeDue: false)
            ))
        }
        
        return sections
    }
    
    static func enrichTasks(_ tasks: [Task], projects: [Project], areas: [Area], includeDue: Bool = true) -> [PlannerTask] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return tasks.map { task in
            let project = projects.first(where: { $0.id == task.projectId })
            let area = areas.first(where: { $0.id == task.areaId })
            var dueDescription: String?
            if includeDue, let dueDate = task.dueDate {
                dueDescription = dueLabel(for: dueDate, calendar: calendar, today: today)
            }
            return PlannerTask(task: task, project: project, area: area, dueDescription: dueDescription)
        }
    }
    
    static func dueLabel(for dueDate: Date, calendar: Calendar, today: Date) -> String {
        if calendar.isDate(dueDate, inSameDayAs: today) {
            return "Due today"
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today), calendar.isDate(dueDate, inSameDayAs: tomorrow) {
            return "Due tomorrow"
        } else if dueDate < today {
            let days = calendar.dateComponents([.day], from: dueDate, to: today).day ?? 0
            return days == 1 ? "1 day overdue" : "\(days) days overdue"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: dueDate)
        }
    }
}

// MARK: - Models

private struct PlannerSection: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let accent: Color
    let tasks: [PlannerTask]
}

private struct PlannerTask: Identifiable {
    let id = UUID()
    let task: Task
    let project: Project?
    let area: Area?
    let dueDescription: String?
}

// MARK: - Section Card

private struct PlannerSectionCard: View {
    let section: PlannerSection
    let onTaskSelected: (Task) -> Void
    let onStartFocus: (Task) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        DashboardTile(accent: section.accent, padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                header
                Divider()
                    .background(glassColorSystem.dividerColor().opacity(0.35))
                if section.tasks.isEmpty {
                    Text("No tasks yet")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                } else {
                    VStack(spacing: 12) {
                        ForEach(section.tasks) { plannerTask in
                            PlannerTaskRow(
                                plannerTask: plannerTask,
                                onTaskSelected: { onTaskSelected(plannerTask.task) },
                                onStartFocus: { onStartFocus(plannerTask.task) }
                            )
                        }
                    }
                }
            }
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(section.title)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(glassColorSystem.textPrimary())
            Text(section.subtitle)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(glassColorSystem.textSecondary())
        }
    }
}

// MARK: - Task Row

private struct PlannerTaskRow: View {
    let plannerTask: PlannerTask
    let onTaskSelected: () -> Void
    let onStartFocus: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    private var task: Task { plannerTask.task }
    
    private var projectName: String? { plannerTask.project?.title }
    private var areaName: String? { plannerTask.area?.title }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(task.status == .done ? glassColorSystem.textSecondary() : glassColorSystem.textPrimary())
                    .lineLimit(2)
                    .strikethrough(task.status == .done, color: glassColorSystem.textSecondary())
                detailLine
            }
            .contentShape(Rectangle())
            .onTapGesture { onTaskSelected() }
            
            Spacer(minLength: 12)
            
            GlassButton(icon: "timer", style: .iconOnly, role: .surface) {
                onStartFocus()
            }
            .help("Start focus session")
        }
    }
    
    private var detailLine: some View {
        HStack(spacing: 10) {
            if let due = plannerTask.dueDescription {
                Label(due, systemImage: "calendar")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
            }
            
            if let projectName = projectName {
                Label(projectName, systemImage: "folder.fill")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
                    .lineLimit(1)
            }
            
            if let areaName = areaName {
                Label(areaName, systemImage: "square.grid.2x2")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
                    .lineLimit(1)
            }
            
            Label(task.priority.displayName, systemImage: "flag.fill")
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(task.priority.color)
        }
        .lineLimit(1)
    }
}
