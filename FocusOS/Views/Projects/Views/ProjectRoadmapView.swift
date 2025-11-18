import SwiftUI
import SwiftData
import FocusOSShared

struct ProjectRoadmapView: View {
    let projects: [Project]
    let tasks: [Task]
    let areas: [Area]
    let onProjectSelected: (Project) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    private var gridColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 320, maximum: 420), spacing: 20)
        ]
    }
    
    var body: some View {
        if projects.isEmpty {
            emptyState
        } else {
            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 20) {
                ForEach(projects) { project in
                    let projectTasks = tasks.filter { $0.projectId == project.id }
                    let projectArea = areas.first(where: { $0.id == project.areaId })
                    ProjectRoadmapCard(
                        project: project,
                        tasks: projectTasks,
                        area: projectArea,
                        onSelect: { onProjectSelected(project) }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 44, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.6))
            Text("No projects for the roadmap")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(glassColorSystem.textPrimary())
            Text("Create a project to start mapping your focus arcs.")
                .font(.system(.caption, design: .rounded))
                .foregroundColor(glassColorSystem.textSecondary())
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }
}

private struct ProjectRoadmapCard: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let project: Project
    let tasks: [Task]
    let area: Area?
    let onSelect: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    private var accentColor: Color {
        switch project.status {
        case .active: return .kosmicBlue
        case .paused: return .orange
        case .completed: return .kosmicGreen
        }
    }
    
    private var completionRatio: Double {
        guard !tasks.isEmpty else { return 0 }
        let completed = tasks.filter { $0.status == .done }.count
        return Double(completed) / Double(tasks.count)
    }
    
    private var remainingDaysText: String? {
        guard let dueDate = project.dueDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
        if days < 0 {
            return "Past due"
        } else if days == 0 {
            return "Due today"
        } else if days == 1 {
            return "Due tomorrow"
        } else {
            return "Due in \(days) days"
        }
    }
    
    private var linkedTasksPreview: ArraySlice<Task> {
        tasks.prefix(3)
    }
    
    var body: some View {
        DashboardTile(accent: accentColor.opacity(0.92), padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                progressSection
                Divider()
                    .background(glassColorSystem.dividerColor().opacity(0.4))
                footerSection
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(glassColorSystem.borderColor().opacity(isHovered ? 0.6 : 0.35), lineWidth: 0.9)
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            guard !isPressed else { return }
            isPressed = true
            withAnimation(.easeInOut(duration: 0.12)) {
                onSelect()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isPressed = false
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(project.title)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                        .lineLimit(2)
                    if let goal = project.goal, !goal.isEmpty {
                        Text(goal)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(glassColorSystem.textSecondary())
                            .lineLimit(2)
                    }
                }
                Spacer()
                statusBadge
            }
            metadataRow
        }
    }
    
    private var statusBadge: some View {
        Text(project.status.displayName)
            .font(.system(.caption, design: .rounded).weight(.medium))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(accentColor.opacity(0.85))
            .clipShape(Capsule())
    }
    
    private var metadataRow: some View {
        HStack(spacing: 10) {
            if let dueText = remainingDaysText {
                Label(dueText, systemImage: "calendar")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
            }
            
            if let area = area {
                Label(area.title, systemImage: "square.grid.2x2")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
                    .lineLimit(1)
            }
        }
    }
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(Int(completionRatio * 100))% complete")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
                Spacer()
                if project.dueDate != nil {
                    Text(project.dueDate!, format: .dateTime.month(.abbreviated).day())
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(glassColorSystem.textSecondary())
                }
            }
            ProgressView(value: completionRatio)
                .tint(accentColor)
        }
    }
    
    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !linkedTasksPreview.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Next steps")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(glassColorSystem.textSecondary())
                    ForEach(Array(linkedTasksPreview.enumerated()), id: \.element.id) { index, task in
                        HStack(spacing: 6) {
                            Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(task.status == .done ? .kosmicGreen : glassColorSystem.textSecondary().opacity(0.7))
                                .font(.system(size: 11, weight: .semibold))
                            Text(task.title)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(glassColorSystem.textSecondary())
                                .lineLimit(1)
                            Spacer()
                        }
                        .opacity(index == 0 ? 1.0 : 0.85)
                    }
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 12, weight: .bold))
                Text("Open project")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
            }
            .foregroundColor(accentColor)
        }
    }
}
