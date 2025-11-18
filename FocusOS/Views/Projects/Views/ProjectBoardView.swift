//
//  ProjectBoardView.swift
//  FocusOS
//
//  Kanban board view for Projects with drag & drop
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Foundation
import FocusOSShared

struct ProjectBoardView: View {
    let projects: [Project]
    let tasks: [Task]
    let areas: [Area]
    let selectionMode: Bool
    let selectedProjectIDs: Set<UUID>
    let onSelectionToggle: (Project) -> Void
    let onProjectDetail: (Project) -> Void
    let onProjectEdit: (Project) -> Void
    let onDuplicateProject: (Project) -> Void
    let onArchiveProject: (Project) -> Void
    let onDeleteProject: (Project) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    enum BoardLane: String, CaseIterable {
        case planning = "Planning"
        case building = "Building"
        case reviewing = "Reviewing"
        case complete = "Complete"
        
        var displayName: String {
            rawValue
        }
        
        var status: ProjectStatus {
            switch self {
            case .planning: return .paused
            case .building: return .active
            case .reviewing: return .active // Intermediate state
            case .complete: return .completed
            }
        }
        
        var focusColor: Color {
            switch self {
            case .planning: return .kosmicBlue
            case .building: return .kosmicPurple
            case .reviewing: return .kosmicGreen
            case .complete: return .gray
            }
        }
    }
    
    var projectsByLane: [BoardLane: [Project]] {
        var grouped: [BoardLane: [Project]] = [:]
        for lane in BoardLane.allCases {
            grouped[lane] = []
        }
        
        for project in projects {
            // Map status to lanes
            switch project.status {
            case .paused:
                grouped[.planning]?.append(project)
            case .active:
                // Distribute active projects between Building and Reviewing based on completion
                let completion = calculateCompletion(for: project)
                if completion > 0.75 {
                    grouped[.reviewing]?.append(project)
                } else {
                    grouped[.building]?.append(project)
                }
            case .completed:
                grouped[.complete]?.append(project)
            }
        }
        
        return grouped
    }
    
    func calculateCompletion(for project: Project) -> Double {
        let projectTasks = tasks.filter { $0.projectId == project.id }
        guard !projectTasks.isEmpty else { return 0.0 }
        let completed = projectTasks.filter { $0.status == .done }.count
        return Double(completed) / Double(projectTasks.count)
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(BoardLane.allCases, id: \.self) { lane in
                    BoardLaneColumn(
                        lane: lane,
                        projects: projectsByLane[lane] ?? [],
                        allProjects: projects,
                        tasks: tasks,
                        areas: areas,
                        selectionMode: selectionMode,
                        selectedProjectIDs: selectedProjectIDs,
                        onSelectionToggle: onSelectionToggle,
                        onProjectDetail: onProjectDetail,
                        onProjectEdit: onProjectEdit,
                        onDuplicateProject: onDuplicateProject,
                        onArchiveProject: onArchiveProject,
                        onDeleteProject: onDeleteProject,
                        onProjectDropped: { project, newLane in
                            moveProject(project, to: newLane)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private func moveProject(_ project: Project, to lane: BoardLane) {
        switch lane {
        case .planning:
            project.status = .paused
        case .building, .reviewing:
            project.status = .active
        case .complete:
            project.status = .completed
        }
        
        project.updatedAt = Date()
        
        do {
            try modelContext.save()
            ProjectHaptics.playDrag()
        } catch {
            print("Failed to move project: \(error)")
        }
    }
}

// MARK: - Board Lane Column

struct BoardLaneColumn: View {
    let lane: ProjectBoardView.BoardLane
    let projects: [Project]
    let allProjects: [Project]
    let tasks: [Task]
    let areas: [Area]
    let selectionMode: Bool
    let selectedProjectIDs: Set<UUID>
    let onSelectionToggle: (Project) -> Void
    let onProjectDetail: (Project) -> Void
    let onProjectEdit: (Project) -> Void
    let onDuplicateProject: (Project) -> Void
    let onArchiveProject: (Project) -> Void
    let onDeleteProject: (Project) -> Void
    let onProjectDropped: (Project, ProjectBoardView.BoardLane) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    
    @State private var laneMetrics: ProjectFocusMetrics?
    @State private var isTargeted = false
    
    var averageFocusIntensity: Double {
        guard let metrics = laneMetrics else { return 0.0 }
        return (metrics.cognitiveFocus + metrics.creativeFlow + metrics.completionEnergy) / 3.0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [lane.focusColor.opacity(0.8), lane.focusColor.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 12, height: 12)
                    .shadow(color: lane.focusColor.opacity(0.35), radius: 6, y: 2)
                
                Text(lane.displayName)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(glassColorSystem.textPrimary())
                
                Spacer()
                
                Capsule()
                    .fill(lane.focusColor.opacity(0.12))
                    .overlay(
                        Text("\(projects.count)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(lane.focusColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    )
                    .frame(height: 24)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(width: 280)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(lane.focusColor.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(lane.focusColor.opacity(0.18), lineWidth: 1)
                    )
            )
            
            if metrics.hasHighlights {
                HStack(spacing: 6) {
                    if metrics.overdueCount > 0 {
                        ProjectMetricPill(icon: "exclamationmark.triangle.fill", text: "\(metrics.overdueCount) overdue", tint: .red)
                    }
                    if metrics.dueSoonCount > 0 {
                        ProjectMetricPill(icon: "clock.badge.exclamationmark", text: "\(metrics.dueSoonCount) due soon", tint: .orange)
                    }
                    if metrics.highPriorityCount > 0 {
                        ProjectMetricPill(icon: "bolt.fill", text: "\(metrics.highPriorityCount) high priority", tint: .kosmicPurple)
                    }
                }
                .padding(.horizontal, 12)
            }
            
            // Projects in this lane
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(projects) { project in
                        BoardProjectCard(
                            project: project,
                            tasks: tasks.filter { $0.projectId == project.id },
                            areas: areas,
                            selectionMode: selectionMode,
                            isSelected: selectedProjectIDs.contains(project.id),
                            onSelectionToggle: { onSelectionToggle(project) },
                            onOpenDetail: { onProjectDetail(project) },
                            onEdit: { onProjectEdit(project) },
                            onDuplicate: { onDuplicateProject(project) },
                            onArchive: { onArchiveProject(project) },
                            onDelete: { onDeleteProject(project) },
                            onMoveToLane: { targetLane in
                                onProjectDropped(project, targetLane)
                            }
                        )
                        .applyIf(!selectionMode) { view in
                            view.draggable(ProjectDragInfo(projectID: project.id))
                        }
                        .padding(.horizontal, 2)
                        .padding(.vertical, 1)
                    }
                    
                    // Quick Add Button
                    Button(action: {
                        // Create project with lane status
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Add project")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.secondary)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.secondary.opacity(0.06))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, projects.isEmpty ? 32 : 12)
                }
            }
            .frame(height: 600)
        }
        .frame(width: 280)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(lane.focusColor.opacity(isTargeted ? 0.45 : 0), lineWidth: isTargeted ? 3 : 0)
                .animation(.easeInOut(duration: 0.2), value: isTargeted)
        )
        .onDrop(of: [.text], delegate: ProjectDropDelegate(
            targetLane: lane,
            projects: allProjects,
            onProjectDropped: onProjectDropped,
            modelContext: modelContext,
            onHoverChanged: { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isTargeted = hovering
                }
            }
        ))
        .task {
            // Calculate average metrics for lane
            if !projects.isEmpty {
                let metrics = projects.compactMap { project in
                    ProjectFocusGravityService.shared.focusMetrics(for: project, modelContext: modelContext)
                }
                
                if !metrics.isEmpty {
                    let avgCognitive = metrics.map { $0.cognitiveFocus }.reduce(0, +) / Double(metrics.count)
                    let avgCreative = metrics.map { $0.creativeFlow }.reduce(0, +) / Double(metrics.count)
                    let avgCompletion = metrics.map { $0.completionEnergy }.reduce(0, +) / Double(metrics.count)
                    
                    laneMetrics = ProjectFocusMetrics(
                        cognitiveFocus: avgCognitive,
                        creativeFlow: avgCreative,
                        completionEnergy: avgCompletion,
                        lastActiveAt: nil,
                        avgSessionDuration: 0,
                        weeklyTrend: []
                    )
                }
            }
        }
    }
    
    private var metrics: ProjectLaneMetrics {
        ProjectLaneMetrics(projects: projects, tasks: tasks)
    }

}

// MARK: - Board Project Card

struct BoardProjectCard: View {
    @Bindable var project: Project
    let tasks: [Task]
    let areas: [Area]
    let selectionMode: Bool
    let isSelected: Bool
    let onSelectionToggle: () -> Void
    let onOpenDetail: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void
    let onMoveToLane: (ProjectBoardView.BoardLane) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(project.title)
                .font(.headline)
                .lineLimit(2)
                .foregroundColor(glassColorSystem.textPrimary())
            
            if let goal = project.goal {
                Text(goal)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                InteractiveProjectStatusBadge(project: project)
                
                if !tasks.isEmpty {
                    Text("\(tasks.filter { $0.status != .done }.count) tasks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GlassPanel(tier: .contentCard, cornerRadius: 8) {
                EmptyView()
            }
        )
        .shadow(color: .black.opacity(isHovered ? 0.1 : 0.05), radius: isHovered ? 4 : 2, y: isHovered ? 2 : 1)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(duration: 0.3), value: isHovered)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: isSelected ? [.kosmicBlue, .kosmicPurple] : [.clear, .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isSelected ? 2 : 0
                )
        )
        .overlay(alignment: .topTrailing) {
            if selectionMode {
                SelectionIndicator(isSelected: isSelected)
                    .padding(8)
                    .onTapGesture {
                        onSelectionToggle()
                    }
            } else {
                ProjectQuickActionBar(
                    isVisible: isHovered,
                    onOpen: onOpenDetail,
                    onEdit: onEdit,
                    onDuplicate: onDuplicate,
                    onArchive: onArchive,
                    onMove: onMoveToLane
                )
                .padding(.trailing, 4)
            }
        }
        .onHover { hovering in
            isHovered = selectionMode ? false : hovering
        }
        .onTapGesture {
            if selectionMode {
                onSelectionToggle()
            } else {
                onOpenDetail()
            }
        }
        .onTapGesture(count: 2) {
            if selectionMode {
                onSelectionToggle()
            } else {
                onEdit()
            }
        }
        .contextMenu {
            Button("Open") { onOpenDetail() }
            Button("Edit") { onEdit() }
            Menu("Move to") {
                ForEach(ProjectBoardView.BoardLane.allCases, id: \.self) { lane in
                    Button(lane.displayName) {
                        onMoveToLane(lane)
                    }
                }
            }
            Button("Duplicate", systemImage: "doc.on.doc") { onDuplicate() }
            Button("Archive", systemImage: "archivebox") { onArchive() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }
}

// MARK: - Drag & Drop Support

struct ProjectDragInfo: Codable, Transferable {
    let projectID: UUID
    
    init(projectID: UUID) {
        self.projectID = projectID
    }
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .text)
    }
}

struct ProjectDropDelegate: DropDelegate {
    let targetLane: ProjectBoardView.BoardLane
    let projects: [Project]
    let onProjectDropped: (Project, ProjectBoardView.BoardLane) -> Void
    let modelContext: ModelContext
    let onHoverChanged: (Bool) -> Void
    
    func validateDrop(info: DropInfo) -> Bool {
        onHoverChanged(true)
        return info.hasItemsConforming(to: [.text])
    }
    
    func dropEntered(info: DropInfo) {
        onHoverChanged(true)
    }
    
    func dropExited(info: DropInfo) {
        onHoverChanged(false)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.text]).first else {
            onHoverChanged(false)
            return false
        }
        
        _ = itemProvider.loadTransferable(type: ProjectDragInfo.self) { result in
            guard case .success(let dragInfo) = result else {
                onHoverChanged(false)
                return
            }
            
            _Concurrency.Task { @MainActor in
                guard let project = projects.first(where: { $0.id == dragInfo.projectID }) else {
                    onHoverChanged(false)
                    return
                }
                onProjectDropped(project, targetLane)
                onHoverChanged(false)
            }
        }
        
        return true
    }
}

private struct ProjectMetricPill: View {
    let icon: String
    let text: String
    let tint: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(tint)
            Text(text)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.08))
        .clipShape(Capsule())
    }
}

private struct ProjectLaneMetrics {
    let overdueCount: Int
    let dueSoonCount: Int
    let highPriorityCount: Int
    
    var hasHighlights: Bool {
        overdueCount > 0 || dueSoonCount > 0 || highPriorityCount > 0
    }
    
    init(projects: [Project], tasks: [Task]) {
        let projectIDs = Set(projects.map(\.id))
        let relatedTasks = tasks.filter { task in
            guard let projectId = task.projectId else { return false }
            return projectIDs.contains(projectId)
        }
        
        let now = Date()
        let calendar = Calendar.current
        
        overdueCount = relatedTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate < now && task.status != .done
        }.count
        
        dueSoonCount = relatedTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            guard dueDate >= now else { return false }
            let days = calendar.dateComponents([.day], from: now, to: dueDate).day ?? 0
            return days <= 3 && task.status != .done
        }.count
        
        highPriorityCount = relatedTasks.filter { task in
            task.priority == .high && task.status != .done
        }.count
    }
}

private struct ProjectQuickActionBar: View {
    let isVisible: Bool
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onArchive: () -> Void
    let onMove: (ProjectBoardView.BoardLane) -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            TaskBoardQuickActionButton(systemName: "eye.fill", tint: Color.primary, action: onOpen)
            TaskBoardQuickActionButton(systemName: "pencil", tint: .kosmicBlue, action: onEdit)
            TaskBoardQuickActionButton(systemName: "doc.on.doc", tint: .kosmicPurple, action: onDuplicate)
            
            Menu {
                ForEach(ProjectBoardView.BoardLane.allCases, id: \.self) { lane in
                    Button(lane.displayName) {
                        onMove(lane)
                    }
                }
            } label: {
                QuickActionGlyph(systemName: "arrow.triangle.2.circlepath", tint: Color.secondary)
            }
            .menuStyle(.borderlessButton)
            
            TaskBoardQuickActionButton(systemName: "archivebox", tint: .orange, action: onArchive)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.14), radius: 8, y: 4)
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: isVisible)
        .allowsHitTesting(isVisible)
    }
}

private struct TaskBoardQuickActionButton: View {
    let systemName: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            QuickActionGlyph(systemName: systemName, tint: tint)
        }
        .buttonStyle(.plain)
    }
}

private struct QuickActionGlyph: View {
    let systemName: String
    let tint: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(tint)
            .padding(6)
    }
}
