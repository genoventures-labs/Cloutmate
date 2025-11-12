//
//  TaskBoardView.swift
//  Cloutmate
//
//  Kanban board view for Tasks with drag & drop
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import CloutmateShared

struct TaskBoardView: View {
    let tasks: [Task]
    let projects: [Project]
    let areas: [Area]
    let selectionMode: Bool
    let selectedTaskIDs: Set<UUID>
    let onSelectionToggle: (Task) -> Void
    let onTaskSelected: (Task) -> Void
    let onDuplicateTask: (Task) -> Void
    let onArchiveTask: (Task) -> Void
    let onDeleteTask: (Task) -> Void
    let onStartFocus: (Task) -> Void
    let onQuickAddTask: (TaskStatus) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    enum BoardLane: String, CaseIterable {
        case todo = "To Do"
        case inProgress = "In Progress"
        case done = "Done"
        case cancelled = "Cancelled"
        
        var displayName: String {
            rawValue
        }
        
        var status: TaskStatus {
            switch self {
            case .todo: return .todo
            case .inProgress: return .inProgress
            case .done: return .done
            case .cancelled: return .cancelled
            }
        }
        
        var focusColor: Color {
            switch self {
            case .todo: return .kosmicBlue
            case .inProgress: return .orange
            case .done: return .kosmicGreen
            case .cancelled: return .gray
            }
        }
    }
    
    var tasksByLane: [BoardLane: [Task]] {
        var grouped: [BoardLane: [Task]] = [:]
        for lane in BoardLane.allCases {
            grouped[lane] = []
        }
        
        for task in tasks {
            switch task.status {
            case .todo:
                grouped[.todo]?.append(task)
            case .inProgress:
                grouped[.inProgress]?.append(task)
            case .done:
                grouped[.done]?.append(task)
            case .cancelled:
                grouped[.cancelled]?.append(task)
            }
        }
        
        return grouped
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(BoardLane.allCases, id: \.self) { lane in
                    TaskBoardLaneColumn(
                        lane: lane,
                        tasks: tasksByLane[lane] ?? [],
                        allTasks: tasks,
                        projects: projects,
                        areas: areas,
                        selectionMode: selectionMode,
                        selectedTaskIDs: selectedTaskIDs,
                        onSelectionToggle: onSelectionToggle,
                        onTaskSelected: onTaskSelected,
                        onDuplicateTask: onDuplicateTask,
                        onArchiveTask: onArchiveTask,
                        onDeleteTask: onDeleteTask,
                        onTaskDropped: { task, targetLane in
                            updateTaskStatus(task: task, to: targetLane.status)
                        },
                        onStartFocus: onStartFocus,
                        onQuickAddTask: onQuickAddTask
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color(.windowBackgroundColor))
    }
    
    private func updateTaskStatus(task: Task, to status: TaskStatus) {
        withAnimation(GlassMotion.Easing.spring) {
        task.status = status
        }
        try? modelContext.save()
    }
}

// MARK: - Task Board Lane Column

private struct TaskBoardLaneColumn: View {
    let lane: TaskBoardView.BoardLane
    let tasks: [Task]
    let allTasks: [Task]
    let projects: [Project]
    let areas: [Area]
    let selectionMode: Bool
    let selectedTaskIDs: Set<UUID>
    let onSelectionToggle: (Task) -> Void
    let onTaskSelected: (Task) -> Void
    let onDuplicateTask: (Task) -> Void
    let onArchiveTask: (Task) -> Void
    let onDeleteTask: (Task) -> Void
    let onTaskDropped: (Task, TaskBoardView.BoardLane) -> Void
    let onStartFocus: (Task) -> Void
    let onQuickAddTask: (TaskStatus) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @State private var isTargeted = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Lane Header
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
                    .shadow(color: lane.focusColor.opacity(0.4), radius: 6, y: 2)
                
                Text(lane.displayName)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(glassColorSystem.textPrimary())
                
                Spacer()
                
                Capsule()
                    .fill(lane.focusColor.opacity(0.12))
                    .overlay(
                Text("\(tasks.count)")
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
                        MetricPill(
                            icon: "exclamationmark.triangle.fill",
                            text: "\(metrics.overdueCount) overdue",
                            tint: .red
                        )
                    }
                    if metrics.dueSoonCount > 0 {
                        MetricPill(
                            icon: "clock.badge.exclamationmark",
                            text: "\(metrics.dueSoonCount) due soon",
                            tint: .orange
                        )
                    }
                    if metrics.highPriorityCount > 0 {
                        MetricPill(
                            icon: "bolt.fill",
                            text: "\(metrics.highPriorityCount) high priority",
                            tint: .kosmicPurple
                        )
                    }
                }
                .padding(.horizontal, 12)
            }
            
            // Tasks in this lane
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(tasks) { task in
                        BoardTaskCard(
                            task: task,
                            project: projects.first { $0.id == task.projectId },
                            area: areas.first { $0.id == task.areaId },
                            selectionMode: selectionMode,
                            isSelected: selectedTaskIDs.contains(task.id),
                            onSelectionToggle: { onSelectionToggle(task) },
                            onTap: { onTaskSelected(task) },
                            onDuplicate: { onDuplicateTask(task) },
                            onArchive: { onArchiveTask(task) },
                            onDelete: { onDeleteTask(task) },
                            onStartFocus: { onStartFocus(task) },
                            onMoveToLane: { targetLane in
                                onTaskDropped(task, targetLane)
                            }
                        )
                        .applyIf(!selectionMode) { view in
                            view.draggable(TaskDragInfo(taskID: task.id))
                        }
                        .padding(.horizontal, 2)
                        .padding(.vertical, 1)
                    }
                    
                    Button(action: {
                        onQuickAddTask(lane.status)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Quick add task")
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
                    .padding(.top, tasks.isEmpty ? 32 : 12)
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
        .onDrop(of: [.text], delegate: TaskDropDelegate(
            targetLane: lane,
            tasks: allTasks,
            onTaskDropped: onTaskDropped,
            modelContext: modelContext,
            onHoverChanged: { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isTargeted = hovering
                }
            }
        ))
    }
    
    private var metrics: TaskLaneMetrics {
        TaskLaneMetrics(tasks: tasks)
    }
    
    private struct TaskLaneMetrics {
        let overdueCount: Int
        let dueSoonCount: Int
        let highPriorityCount: Int
        
        var hasHighlights: Bool {
            overdueCount > 0 || dueSoonCount > 0 || highPriorityCount > 0
        }
        
        init(tasks: [Task]) {
            let now = Date()
            let calendar = Calendar.current
            
            overdueCount = tasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate < now && task.status != .done
            }.count
            
            dueSoonCount = tasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                guard dueDate >= now else { return false }
                let days = calendar.dateComponents([.day], from: now, to: dueDate).day ?? 0
                return days <= 3 && task.status != .done
            }.count
            
            highPriorityCount = tasks.filter { task in
                task.priority == .high && task.status != .done
            }.count
        }
    }
}

// MARK: - Board Task Card

private struct BoardTaskCard: View {
    @Bindable var task: Task
    let project: Project?
    let area: Area?
    let selectionMode: Bool
    let isSelected: Bool
    let onSelectionToggle: () -> Void
    let onTap: () -> Void
    let onDuplicate: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void
    let onStartFocus: () -> Void
    let onMoveToLane: (TaskBoardView.BoardLane) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Quick completion checkbox
                Button(action: {
                    withAnimation(GlassMotion.Easing.spring) {
                        if task.status == .done {
                            task.status = .todo
                        } else {
                            task.status = .done
                        }
                    }
                    try? modelContext.save()
                }) {
                    Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(task.status == .done ? .kosmicGreen : .secondary.opacity(0.6))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .allowsHitTesting(true)
                
                Text(task.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundColor(task.status == .done ? .secondary : glassColorSystem.textPrimary())
                    .strikethrough(task.status == .done)
            }
            
            if let notes = task.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            if project != nil || area != nil {
                HStack(spacing: 6) {
                    if let project {
                        AssociationChip(
                            icon: "folder.fill",
                            text: project.title,
                            tint: .kosmicBlue
                        )
                    }
                    if let area {
                        AssociationChip(
                            icon: "rectangle.stack.fill",
                            text: area.title,
                            tint: .kosmicPurple
                        )
                    }
                }
            }
            
            HStack {
                InteractiveProgressPill(task: task)
                
                if let dueDate = task.dueDate {
                    InteractiveDueDateBadge(task: task, color: dueDateColor(dueDate))
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
            if !selectionMode {
                QuickActionBar(
                    isVisible: isHovered,
                    onEdit: onTap,
                    onFocus: onStartFocus,
                    onDuplicate: onDuplicate,
                    onMove: onMoveToLane
                )
                .padding(.trailing, 4)
            }
        }
        .overlay(alignment: .topTrailing) {
            if selectionMode {
                SelectionIndicator(isSelected: isSelected)
                    .padding(8)
                    .onTapGesture {
                        onSelectionToggle()
                    }
            }
        }
        .onHover { hovering in
            isHovered = selectionMode ? false : hovering
        }
        .onTapGesture {
            if selectionMode {
                onSelectionToggle()
            } else {
                onTap()
            }
        }
        .contextMenu {
            Button("Edit") {
                onTap()
            }
            Menu("Move to") {
                ForEach(TaskBoardView.BoardLane.allCases, id: \.self) { lane in
                    Button(lane.displayName) {
                        onMoveToLane(lane)
                    }
                    .disabled(lane.status == task.status)
                }
            }
            Button("Start Focus Session", systemImage: "bolt.fill") {
                onStartFocus()
            }
            Divider()
            Button("Duplicate", systemImage: "doc.on.doc") {
                onDuplicate()
            }
            Button("Archive", systemImage: "archivebox") {
                onArchive()
            }
            Divider()
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
    
    private func dueDateColor(_ dueDate: Date) -> Color {
        let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
        if daysUntilDue < 0 {
            return .red
        } else if daysUntilDue == 0 {
            return .kosmicBlue
        } else if daysUntilDue <= 3 {
            return .kosmicPurple
        }
        return .gray
    }
}

// MARK: - Drag & Drop Support

struct TaskDragInfo: Codable, Transferable {
    let taskID: UUID
    
    init(taskID: UUID) {
        self.taskID = taskID
    }
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .text)
    }
}

struct TaskDropDelegate: DropDelegate {
    let targetLane: TaskBoardView.BoardLane
    let tasks: [Task]
    let onTaskDropped: (Task, TaskBoardView.BoardLane) -> Void
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
            return false
        }
        
        _ = itemProvider.loadTransferable(type: TaskDragInfo.self) { result in
            guard case .success(let dragInfo) = result else {
                return
            }
            
            DispatchQueue.main.async {
                guard let task = tasks.first(where: { $0.id == dragInfo.taskID }) else {
                    return
                }
                onTaskDropped(task, targetLane)
                onHoverChanged(false)
            }
        }
        
        return true
    }
}

extension View {
    func draggable(_ dragInfo: TaskDragInfo) -> some View {
        self.onDrag {
            if let data = try? JSONEncoder().encode(dragInfo) {
                return NSItemProvider(item: data as NSSecureCoding, typeIdentifier: UTType.text.identifier)
            }
            return NSItemProvider()
        }
    }
}

private struct MetricPill: View {
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

private struct AssociationChip: View {
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
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.08))
        .clipShape(Capsule())
    }
}

private struct QuickActionBar: View {
    let isVisible: Bool
    let onEdit: () -> Void
    let onFocus: () -> Void
    let onDuplicate: () -> Void
    let onMove: (TaskBoardView.BoardLane) -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            QuickActionButton(systemName: "pencil", tint: .primary, action: onEdit)
            QuickActionButton(systemName: "bolt.fill", tint: .kosmicGreen, action: onFocus)
            QuickActionButton(systemName: "doc.on.doc", tint: .kosmicBlue, action: onDuplicate)
            
            Menu {
                ForEach(TaskBoardView.BoardLane.allCases, id: \.self) { lane in
                    Button(lane.displayName) {
                        onMove(lane)
                    }
                }
            } label: {
                QuickActionGlyph(systemName: "ellipsis.circle", tint: .secondary)
            }
            .menuStyle(.borderlessButton)
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

private struct QuickActionButton: View {
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
            .foregroundColor(tint)
            .padding(8)
            .background(Color.white.opacity(0.15))
            .clipShape(Circle())
    }
}

private struct StatusBadge: View {
    let status: String
    let color: Color
    
    var body: some View {
        Text(status)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

private struct PriorityBadge: View {
    let priority: String
    let color: Color
    
    var body: some View {
        Text(priority)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

