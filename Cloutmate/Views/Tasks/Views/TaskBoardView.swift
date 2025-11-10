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
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color(.windowBackgroundColor))
    }
    
    private func updateTaskStatus(task: Task, to status: TaskStatus) {
        task.status = status
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
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Lane Header
            HStack {
                Text(lane.displayName)
                    .font(.headline)
                    .foregroundColor(glassColorSystem.textPrimary())
                
                Spacer()
                
                Text("\(tasks.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(lane.focusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(lane.focusColor.opacity(0.2))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(width: 280)
            .background(
                lane.focusColor.opacity(0.1)
                    .overlay(
                        Rectangle()
                            .fill(lane.focusColor.opacity(0.2))
                            .frame(height: 2),
                        alignment: .top
                    )
            )
            .cornerRadius(8)
            
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
                            onDelete: { onDeleteTask(task) }
                        )
                        .applyIf(!selectionMode) { view in
                            view.draggable(TaskDragInfo(taskID: task.id))
                        }
                        .padding(.horizontal, 2)
                        .padding(.vertical, 1)
                    }
                }
            }
            .frame(height: 600)
        }
        .frame(width: 280)
        .padding(.vertical, 8)
        .onDrop(of: [.text], delegate: TaskDropDelegate(
            targetLane: lane,
            tasks: allTasks,
            onTaskDropped: onTaskDropped,
            modelContext: modelContext
        ))
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
            Button("Start Focus Session") {
                // Handle focus session
            }
            Divider()
            Button("Edit") {
                onTap()
            }
            Button("Duplicate") {
                onDuplicate()
            }
            Button("Archive") {
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

