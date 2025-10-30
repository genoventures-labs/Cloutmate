//
//  WorkflowInsightsCards.swift
//  Cloutmate
//
//  PARA and Productivity Insight Cards
//

import SwiftUI
import SwiftData
import CloutmateShared

// MARK: - Projects Overview Card
struct ProjectsOverviewCard: View {
    let size: DashboardCardSize
    @Query private var projects: [Project]
    
    var activeProjects: [Project] {
        projects.filter { $0.status == .active }
    }
    
    var completedProjects: [Project] {
        projects.filter { $0.status == .completed }
    }
    
    var completionRate: Double {
        guard !projects.isEmpty else { return 0 }
        return Double(completedProjects.count) / Double(projects.count)
    }
    
    var body: some View {
        Group {
            if size == .large { largeContent } else if size == .medium { mediumContent } else { smallContent }
        }
    }

    @ViewBuilder
    private var largeContent: some View {
            VStack(alignment: .leading, spacing: 16) {
                // Header stats
                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("\(activeProjects.count)")
                            .metricValueStyle()
                        Text("Active")
                            .metricLabelStyle()
                    }
                    VStack(alignment: .leading) {
                        Text("\(completedProjects.count)")
                            .metricValueStyle()
                        Text("Completed")
                            .metricLabelStyle()
                    }
                    VStack(alignment: .leading) {
                        Text("\(Int(completionRate * 100))%")
                            .metricValueStyle()
                            .foregroundColor(KosmicPalette.violet)
                        Text("Complete")
                            .metricLabelStyle()
                    }
                    Spacer()
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(KosmicPalette.violet)
                            .frame(width: geometry.size.width * completionRate, height: 12)
                    }
                }
                .frame(height: 12)
            }
    }

    @ViewBuilder
    private var mediumContent: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Text("\(activeProjects.count)")
                            .font(.system(size: 24, weight: .bold))
                        Text("Active Projects")
                            .metricLabelStyle()
                    }
                    VStack(alignment: .leading) {
                        Text("\(Int(completionRate * 100))%")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(KosmicPalette.violet)
                        Text("Complete")
                            .metricLabelStyle()
                    }
                    Spacer()
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(KosmicPalette.violet)
                            .frame(width: geometry.size.width * completionRate, height: 8)
                    }
                }
                .frame(height: 8)
            }
    }

    @ViewBuilder
    private var smallContent: some View {
            VStack {
                Text("\(activeProjects.count)")
                    .font(.system(size: 36, weight: .bold))
                Text("Projects")
                    .font(.caption)
                    .foregroundColor(.secondary)
        }
    }
}

// MARK: - Tasks Overview Card
struct TasksOverviewCard: View {
    let size: DashboardCardSize
    @Query private var tasks: [Task]
    
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
    
    var body: some View {
        switch size {
        case .large:
            VStack(alignment: .leading, spacing: 16) {
                // Stats grid
                HStack(spacing: 12) {
                    VStack {
                        Text("\(tasks.filter { $0.status != .done }.count)")
                            .font(.system(size: 24, weight: .bold))
                        Text("Active")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack {
                        Text("\(tasks.filter { $0.status == .done }.count)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(KosmicPalette.cyan)
                        Text("Done")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack {
                        Text("\(overdueTasks)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(KosmicPalette.neutral600)
                        Text("Overdue")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                Divider()
                
                // Priority breakdown
                VStack(alignment: .leading, spacing: 8) {
                    Text("By Priority")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    PriorityBar(priority: .high, count: tasksByPriority.high, total: tasksByPriority.high + tasksByPriority.medium + tasksByPriority.low)
                    PriorityBar(priority: .medium, count: tasksByPriority.medium, total: tasksByPriority.high + tasksByPriority.medium + tasksByPriority.low)
                    PriorityBar(priority: .low, count: tasksByPriority.low, total: tasksByPriority.high + tasksByPriority.medium + tasksByPriority.low)
                }
            }
        case .medium:
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Text("\(tasks.filter { $0.status != .done }.count)")
                            .font(.system(size: 24, weight: .bold))
                        Text("Active Tasks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    VStack(alignment: .leading) {
                        Text("\(Int(completionRate * 100))%")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.green)
                        Text("Complete")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if overdueTasks > 0 {
                        VStack(alignment: .leading) {
                            Text("\(overdueTasks)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.red)
                            Text("Overdue")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
            }
        case .small:
            VStack {
                Text("\(tasks.filter { $0.status != .done }.count)")
                    .font(.system(size: 36, weight: .bold))
                Text("Tasks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct PriorityBar: View {
    let priority: TaskPriority
    let count: Int
    let total: Int
    
    var color: Color {
        switch priority {
        case .high: return KosmicPalette.violet
        case .medium: return KosmicPalette.cyan
        case .low: return KosmicPalette.neutral600
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(priority.displayName)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(count)")
                .font(.caption)
                .fontWeight(.semibold)
            
            if total > 0 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(KosmicPalette.neutral300.opacity(0.3))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .frame(width: geometry.size.width * (Double(count) / Double(total)), height: 6)
                    }
                }
                .frame(height: 6)
                .frame(maxWidth: 40)
            }
        }
    }
}

// MARK: - Areas Health Card
struct AreasHealthCard: View {
    let size: DashboardCardSize
    @Query private var areas: [Area]
    @Query private var tasks: [Task]
    
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
    
    var body: some View {
        switch size {
        case .large, .medium:
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("\(areas.count)")
                            .font(.system(size: 24, weight: .bold))
                        Text("Areas")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    VStack(alignment: .leading) {
                        Text("\(healthyAreas)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.green)
                        Text("Healthy")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if needsAttention > 0 {
                        VStack(alignment: .leading) {
                            Text("\(needsAttention)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.orange)
                            Text("Need Attention")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
            }
        case .small:
            VStack {
                Text("\(healthyAreas)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.green)
                Text("Healthy Areas")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Notes Activity Card
struct NotesActivityCard: View {
    let size: DashboardCardSize
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    
    var recentNotes: [Note] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return notes.filter { $0.updatedAt >= weekAgo }
    }
    
    var body: some View {
        switch size {
        case .large:
            VStack(alignment: .leading, spacing: 12) {
                Text("\(recentNotes.count) notes this week")
                    .font(.system(size: 24, weight: .bold))
                
                ForEach(recentNotes.prefix(5)) { note in
                    HStack {
                        Text(note.title)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(note.updatedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        case .medium:
            VStack(alignment: .leading, spacing: 8) {
                Text("\(recentNotes.count)")
                    .font(.system(size: 32, weight: .bold))
                Text("Notes this week")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .small:
            VStack {
                Text("\(recentNotes.count)")
                    .font(.system(size: 36, weight: .bold))
                Text("This Week")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Upcoming Deadlines Card
struct UpcomingDeadlinesCard: View {
    let size: DashboardCardSize
    @Query private var tasks: [Task]
    @Query private var projects: [Project]
    
    var upcomingDeadlines: [(String, Date)] {
        var deadlines: [(String, Date)] = []
        
        // Tasks due in next 7 days
        let weekLater = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        let upcomingTasks = tasks.filter { task in
            guard let due = task.dueDate, task.status != .done else { return false }
            return due <= weekLater && due > Date()
        }
        
        for task in upcomingTasks {
            if let due = task.dueDate {
                deadlines.append((task.title, due))
            }
        }
        
        return deadlines.sorted { $0.1 < $1.1 }.prefix(10).map { $0 }
    }
    
    var body: some View {
        switch size {
        case .large, .medium:
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(upcomingDeadlines.prefix(5).enumerated()), id: \.offset) { _, deadline in
                    HStack {
                        Circle()
                            .fill(KosmicPalette.neutral600)
                            .frame(width: 6, height: 6)
                        Text(deadline.0)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(deadline.1, style: .relative)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                if upcomingDeadlines.isEmpty {
                    Text("No deadlines in the next 7 days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        case .small:
            VStack {
                Text("\(upcomingDeadlines.count)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(upcomingDeadlines.isEmpty ? .secondary : KosmicPalette.cyan)
                Text(upcomingDeadlines.count == 1 ? "Deadline" : "Deadlines")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Completion Rate Card
struct CompletionRateCard: View {
    let size: DashboardCardSize
    @Query private var tasks: [Task]
    
    var weeklyCompletionRate: Double {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentTasks = tasks.filter { ($0.createdAt ?? Date()) >= weekAgo }
        guard !recentTasks.isEmpty else { return 0 }
        let completed = recentTasks.filter { $0.status == .done }.count
        return Double(completed) / Double(recentTasks.count)
    }
    
    var monthlyCompletionRate: Double {
        let monthAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentTasks = tasks.filter { ($0.createdAt ?? Date()) >= monthAgo }
        guard !recentTasks.isEmpty else { return 0 }
        let completed = recentTasks.filter { $0.status == .done }.count
        return Double(completed) / Double(recentTasks.count)
    }
    
    var body: some View {
        switch size {
        case .large:
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("This Week")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(weeklyCompletionRate * 100))%")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(KosmicPalette.violet)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("This Month")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(monthlyCompletionRate * 100))%")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(KosmicPalette.violet)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(KosmicPalette.neutral300.opacity(0.3))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(KosmicPalette.violet)
                            .frame(width: geometry.size.width * weeklyCompletionRate, height: 12)
                    }
                }
                .frame(height: 12)
            }
        case .medium:
            VStack(alignment: .leading, spacing: 12) {
                Text("\(Int(weeklyCompletionRate * 100))%")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(KosmicPalette.violet)
                Text("This week")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .small:
            VStack {
                Text("\(Int(weeklyCompletionRate * 100))%")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(KosmicPalette.violet)
                Text("Complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

