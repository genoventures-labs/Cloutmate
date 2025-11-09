//
//  TasksView.swift
//  Cloutmate
//
//  Created by Assistant on 10/28/25.
//

import SwiftUI
import SwiftData
import AppKit
import CloutmateShared

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Query(sort: \CloutmateShared.Task.updatedAt, order: .reverse) private var allTasks: [CloutmateShared.Task]
    @Query private var allProjects: [CloutmateShared.Project]
    @Query private var allAreas: [Area]
    
    @State private var searchText: String = ""
    @State private var selectedStatus: CloutmateShared.TaskStatus?
    @State private var selectedPriority: CloutmateShared.TaskPriority?
    @State private var selectedArea: Area?
    @State private var showUnattachedOnly: Bool = false
    @State private var selectedTasks = Set<UUID>()
    
    @State private var showCreateSheet = false
    @State private var showEditSheet = false
    @State private var taskToEdit: Task?
    
    @State private var showBulkStatusSheet = false
    @State private var showBulkPrioritySheet = false
    
    // Sorting state
    @State private var sortColumn: SortColumn = .updated
    @State private var sortOrder: SortOrder = .reverse
    @State private var lastSortUpdate: (column: SortColumn, timestamp: Date)?
    
    enum SortColumn: String, CaseIterable {
        case title, status, priority, dueDate, project, area, effort, updated
    }
    
    private var filteredTasks: [Task] {
        var filtered = allTasks
        
        if !searchText.isEmpty {
            filtered = filtered.filter { task in
                task.title.localizedCaseInsensitiveContains(searchText) ||
                (task.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        if let status = selectedStatus {
            filtered = filtered.filter { $0.status == status }
        }
        
        if let priority = selectedPriority {
            filtered = filtered.filter { $0.priority == priority }
        }
        
        if let area = selectedArea {
            filtered = filtered.filter { $0.areaId == area.id }
        }
        
        if showUnattachedOnly {
            filtered = filtered.filter { $0.projectId == nil }
        }
        
        // Apply manual sorting
        let sorted = filtered.sorted { task1, task2 in
            let comparison = compareTasks(task1, task2, by: sortColumn)
            // When forward, return true when task1 < task2 (orderedAscending)
            // When reverse, return true when task1 > task2 (orderedDescending)
            return sortOrder == .forward ? comparison == .orderedAscending : comparison == .orderedDescending
        }
        
        return sorted
    }
    
    private var selectedTaskModels: [Task] {
        filteredTasks.filter { selectedTasks.contains($0.id) }
    }
    
    private var selectedTaskCount: Int {
        selectedTaskModels.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchAndFiltersSection
            tableSection
        }
        .background(Color(.windowBackgroundColor))
        .navigationTitle("Tasks")
        .toolbar { toolbarItems }
        .sheet(isPresented: $showCreateSheet) {
            CreateTaskSheet()
        }
        .sheet(isPresented: $showEditSheet) {
            if let task = taskToEdit {
                EditTaskSheet(task: task)
            }
        }
        .sheet(isPresented: $showBulkStatusSheet) {
            BulkTaskStatusSheet(tasks: filteredTasks.filter { selectedTasks.contains($0.id) }) { newStatus in
                applyBulkStatus(newStatus)
            }
        }
        .sheet(isPresented: $showBulkPrioritySheet) {
            BulkTaskPrioritySheet(tasks: filteredTasks.filter { selectedTasks.contains($0.id) }) { newPriority in
                applyBulkPriority(newPriority)
            }
        }
        .overlay(alignment: .top) {
            ClickableTableHeadersView(sortColumn: $sortColumn, sortOrder: $sortOrder)
                .frame(height: 0)
        }
        .overlay(alignment: .bottom) {
            if !selectedTasks.isEmpty {
                SelectionActionBar(
                    count: selectedTaskCount,
                    itemLabel: "task",
                    actions: taskSelectionActions(),
                    onCancel: { selectedTasks.removeAll() },
                    onSelectAll: toggleSelectAll,
                    totalItems: filteredTasks.count
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
    
    private func taskSelectionActions() -> [SelectionActionBar.Action] {
        [
            .init(title: "Change Status", icon: "arrow.up.right.circle") {
                showBulkStatusSheet = true
            },
            .init(title: "Change Priority", icon: "flag") {
                showBulkPrioritySheet = true
            },
            .init(title: "Delete", icon: "trash", role: .danger) {
                deleteSelectedTasks()
            }
        ]
    }
    
    private var searchAndFiltersSection: some View {
        VStack(spacing: 12) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Search tasks...", text: $searchText)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            // Status & Priority chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "All",
                        isSelected: selectedStatus == nil && selectedPriority == nil && selectedArea == nil && !showUnattachedOnly,
                        action: {
                            selectedStatus = nil
                            selectedPriority = nil
                            selectedArea = nil
                            showUnattachedOnly = false
                        }
                    )
                    
                    ForEach(CloutmateShared.TaskStatus.allCases, id: \.self) { status in
                        FilterChip(
                            title: status.displayName,
                            isSelected: selectedStatus == status,
                            action: { selectedStatus = status }
                        )
                    }
                    
                    ForEach(CloutmateShared.TaskPriority.allCases, id: \.self) { priority in
                        FilterChip(
                            title: priority.displayName,
                            isSelected: selectedPriority == priority,
                            action: { selectedPriority = priority }
                        )
                    }
                    
                    FilterChip(
                        title: "Unattached",
                        isSelected: showUnattachedOnly,
                        action: { showUnattachedOnly.toggle() }
                    )
                }
            }
            
            // Area chips
            if !allAreas.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(allAreas) { area in
                            FilterChip(
                                title: area.title,
                                isSelected: selectedArea?.id == area.id,
                                action: {
                                    if selectedArea?.id == area.id {
                                        selectedArea = nil
                                    } else {
                                        selectedArea = area
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    private var tableSection: some View {
        Table(filteredTasks, selection: $selectedTasks) {
            TableColumn("Title") { task in
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.headline)
                        .lineLimit(1)
                    if let notes = task.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    taskToEdit = task
                    showEditSheet = true
                }
                .contextMenu {
                    Button("Edit") {
                        taskToEdit = task
                        showEditSheet = true
                    }
                    Button("Duplicate") { duplicateTask(task) }
                    Divider()
                    Button("Delete", role: .destructive) { deleteTask(task) }
                }
            }
            .width(min: 220, ideal: 320)
            
            TableColumn("Status") { task in
                InteractiveTaskStatusBadge(task: task)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        taskToEdit = task
                        showEditSheet = true
                    }
            }
            .width(min: 110, ideal: 110)
            
            TableColumn("Priority") { task in
                InteractiveTaskPriorityBadge(task: task)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        taskToEdit = task
                        showEditSheet = true
                    }
            }
            .width(min: 110, ideal: 110)
            
            TableColumn("Due Date") { task in
                Group {
                    if let due = task.dueDate {
                        Text(due, format: .dateTime.month().day())
                    } else {
                        Text("—").foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    taskToEdit = task
                    showEditSheet = true
                }
            }
            .width(min: 120, ideal: 120)
            
            TableColumn("Project") { task in
                if let pid = task.projectId, let project = allProjects.first(where: { $0.id == pid }) {
                    Text(project.title).font(.caption)
                } else {
                    Text("—").foregroundColor(.secondary)
                }
            }
            .width(min: 140, ideal: 140)
            
            TableColumn("Area") { task in
                if let aid = task.areaId, let area = allAreas.first(where: { $0.id == aid }) {
                    Text(area.title).font(.caption)
                } else {
                    Text("—").foregroundColor(.secondary)
                }
            }
            .width(min: 140, ideal: 140)
            
            TableColumn("Effort") { task in
                Text(task.effort ?? "—").font(.caption).foregroundColor(.secondary)
            }
            .width(min: 90, ideal: 90)
            
            TableColumn("Updated") { task in
                Text(task.updatedAt, style: .relative).font(.caption).foregroundColor(.secondary)
            }
            .width(min: 120, ideal: 120)
        }
    }
    
    private func compareTasks(_ task1: CloutmateShared.Task, _ task2: CloutmateShared.Task, by column: SortColumn) -> ComparisonResult {
        switch column {
        case .title:
            return task1.title.localizedCompare(task2.title)
        case .status:
            return task1.status.rawValue.localizedCompare(task2.status.rawValue)
        case .priority:
            let priorityOrder: [CloutmateShared.TaskPriority: Int] = [.high: 3, .medium: 2, .low: 1]
            let p1 = priorityOrder[task1.priority] ?? 0
            let p2 = priorityOrder[task2.priority] ?? 0
            return p1 == p2 ? .orderedSame : (p1 > p2 ? .orderedDescending : .orderedAscending)
        case .dueDate:
            switch (task1.dueDate, task2.dueDate) {
            case (nil, nil): return .orderedSame
            case (nil, _): return .orderedDescending
            case (_, nil): return .orderedAscending
            case (let d1?, let d2?): return d1.compare(d2)
            }
        case .project:
            let p1Title = task1.projectId.flatMap { pid in allProjects.first(where: { $0.id == pid })?.title } ?? ""
            let p2Title = task2.projectId.flatMap { pid in allProjects.first(where: { $0.id == pid })?.title } ?? ""
            return p1Title.localizedCompare(p2Title)
        case .area:
            let a1Title = task1.areaId.flatMap { aid in allAreas.first(where: { $0.id == aid })?.title } ?? ""
            let a2Title = task2.areaId.flatMap { aid in allAreas.first(where: { $0.id == aid })?.title } ?? ""
            return a1Title.localizedCompare(a2Title)
        case .effort:
            let e1 = task1.effort ?? ""
            let e2 = task2.effort ?? ""
            return e1.localizedCompare(e2)
        case .updated:
            return task1.updatedAt.compare(task2.updatedAt)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if !selectedTasks.isEmpty {
                Menu("Actions") {
                    Button("Change Status", systemImage: "arrow.up.right.circle") { showBulkStatusSheet = true }
                    Button("Change Priority", systemImage: "flag") { showBulkPrioritySheet = true }
                    
                    Menu("Assign to Project", systemImage: "folder") {
                        Button("None") { assignSelectedTasksToProject(nil) }
                        Divider()
                        ForEach(allProjects) { project in
                            Button(project.title) { assignSelectedTasksToProject(project.id) }
                        }
                    }
                    
                    Divider()
                    Button("Delete Selected", systemImage: "trash", role: .destructive) { deleteSelectedTasks() }
                }
            }
            
            Button("New Task") { showCreateSheet = true }
        }
    }
    
    // MARK: - Actions
    private func deleteTask(_ task: CloutmateShared.Task) {
        modelContext.delete(task)
        if selectedTasks.contains(task.id) { selectedTasks.remove(task.id) }
        try? modelContext.save()
    }
    
    private func duplicateTask(_ task: CloutmateShared.Task) {
        let copy = CloutmateShared.Task(
            title: task.title,
            notes: task.notes,
            status: task.status,
            priority: task.priority,
            dueDate: task.dueDate,
            projectId: task.projectId,
            areaId: task.areaId,
            effort: task.effort
        )
        modelContext.insert(copy)
        try? modelContext.save()
    }
    
    private func deleteSelectedTasks() {
        let tasksToDelete = filteredTasks.filter { selectedTasks.contains($0.id) }
        for task in tasksToDelete { modelContext.delete(task) }
        selectedTasks.removeAll()
        try? modelContext.save()
    }
    
    private func applyBulkStatus(_ newStatus: CloutmateShared.TaskStatus) {
        let tasksToUpdate = filteredTasks.filter { selectedTasks.contains($0.id) }
        for task in tasksToUpdate { task.status = newStatus }
        selectedTasks.removeAll()
        try? modelContext.save()
    }
    
    private func applyBulkPriority(_ newPriority: CloutmateShared.TaskPriority) {
        let tasksToUpdate = filteredTasks.filter { selectedTasks.contains($0.id) }
        for task in tasksToUpdate { task.priority = newPriority }
        selectedTasks.removeAll()
        try? modelContext.save()
    }
    
    private func assignSelectedTasksToProject(_ projectId: UUID?) {
        let tasksToUpdate = filteredTasks.filter { selectedTasks.contains($0.id) }
        for task in tasksToUpdate { task.projectId = projectId }
        selectedTasks.removeAll()
        try? modelContext.save()
    }
    
    private func toggleSelectAll() {
        let allVisibleIDs = Set(filteredTasks.map(\.id))
        if selectedTasks == allVisibleIDs {
            // All selected, deselect all
            selectedTasks.removeAll()
        } else {
            // Not all selected, select all visible
            selectedTasks = allVisibleIDs
        }
    }
}

// MARK: - Badges
struct TaskStatusBadge: View {
    let status: CloutmateShared.TaskStatus
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                (status == .done ? Color.kosmicGreen : status == .inProgress ? Color.orange : status == .cancelled ? Color.gray : Color.kosmicBlue)
                    .opacity(0.2)
            )
            .foregroundColor(status == .done ? .kosmicGreen : status == .inProgress ? .orange : status == .cancelled ? .gray : .kosmicBlue)
            .cornerRadius(6)
    }
}

struct TaskPriorityBadge: View {
    let priority: CloutmateShared.TaskPriority
    var body: some View {
        Text(priority.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(priority.color.opacity(0.2))
            .foregroundColor(priority.color)
            .cornerRadius(6)
    }
}

// MARK: - Interactive Badges
struct InteractiveTaskStatusBadge: View {
    @Bindable var task: CloutmateShared.Task
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Menu {
            ForEach(CloutmateShared.TaskStatus.allCases, id: \.self) { status in
                Button(action: {
                    task.status = status
                    task.updatedAt = Date()
                    try? modelContext.save()
                }) {
                    HStack {
                        Text(status.displayName)
                        if task.status == status {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            TaskStatusBadge(status: task.status)
        }
        .buttonStyle(.plain)
    }
}

struct InteractiveTaskPriorityBadge: View {
    @Bindable var task: CloutmateShared.Task
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Menu {
            ForEach(CloutmateShared.TaskPriority.allCases, id: \.self) { priority in
                Button(action: {
                    task.priority = priority
                    task.updatedAt = Date()
                    try? modelContext.save()
                }) {
                    HStack {
                        Text(priority.displayName)
                        if task.priority == priority {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            TaskPriorityBadge(priority: task.priority)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Create / Edit Sheets
struct CreateTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allProjects: [CloutmateShared.Project]
    @Query private var allAreas: [Area]
    
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var status: CloutmateShared.TaskStatus = .todo
    @State private var priority: CloutmateShared.TaskPriority = .medium
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var projectId: UUID?
    @State private var areaId: UUID?
    @State private var effort: String = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Task Title *", text: $title)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                        TextField("Notes", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Status").font(.caption).foregroundColor(.secondary)
                        Picker("Status", selection: $status) {
                            ForEach(CloutmateShared.TaskStatus.allCases, id: \.self) { s in Text(s.displayName).tag(s) }
                        }.pickerStyle(.segmented)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Priority").font(.caption).foregroundColor(.secondary)
                        Picker("Priority", selection: $priority) {
                            ForEach(CloutmateShared.TaskPriority.allCases, id: \.self) { p in Text(p.displayName).tag(p) }
                        }.pickerStyle(.segmented)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Set Due Date", isOn: $hasDueDate)
                        if hasDueDate {
                            DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                        }
                    }
                    
                    if !allProjects.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Project").font(.caption).foregroundColor(.secondary)
                            Picker("Project", selection: $projectId) {
                                Text("None").tag(UUID?.none)
                                ForEach(allProjects) { p in Text(p.title).tag(p.id as UUID?) }
                            }
                        }
                    }
                    
                    if !allAreas.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Area").font(.caption).foregroundColor(.secondary)
                            Picker("Area", selection: $areaId) {
                                Text("None").tag(UUID?.none)
                                ForEach(allAreas) { a in Text(a.title).tag(a.id as UUID?) }
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Effort").font(.caption).foregroundColor(.secondary)
                        Picker("Effort", selection: $effort) {
                            Text("None").tag("")
                            Text("Small").tag("small")
                            Text("Medium").tag("medium")
                            Text("Large").tag("large")
                        }
                    }
                }
                .padding()
            }
            .background(Color(.windowBackgroundColor))
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createTask() }.disabled(title.isEmpty)
                }
            }
        }
        .frame(width: 600, height: 520)
    }
    
    private func createTask() {
        let task = CloutmateShared.Task(
            title: title,
            notes: notes.isEmpty ? nil : notes,
            status: status,
            priority: priority,
            dueDate: hasDueDate ? dueDate : nil,
            projectId: projectId,
            areaId: areaId,
            effort: effort.isEmpty ? nil : effort
        )
        modelContext.insert(task)
        try? modelContext.save()
        dismiss()
    }
}

struct EditTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allProjects: [CloutmateShared.Project]
    @Query private var allAreas: [Area]
    
    @Bindable var task: CloutmateShared.Task
    
    @State private var hasDueDate: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Task Title *", text: $task.title)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                        TextField("Notes", text: Binding(get: { task.notes ?? "" }, set: { task.notes = $0.isEmpty ? nil : $0 }), axis: .vertical)
                            .lineLimit(3...6)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Status").font(.caption).foregroundColor(.secondary)
                        Picker("Status", selection: $task.status) {
                            ForEach(CloutmateShared.TaskStatus.allCases, id: \.self) { s in Text(s.displayName).tag(s) }
                        }.pickerStyle(.segmented)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Priority").font(.caption).foregroundColor(.secondary)
                        Picker("Priority", selection: $task.priority) {
                            ForEach(CloutmateShared.TaskPriority.allCases, id: \.self) { p in Text(p.displayName).tag(p) }
                        }.pickerStyle(.segmented)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Set Due Date", isOn: Binding(get: { task.dueDate != nil }, set: { newValue in
                            if newValue && task.dueDate == nil { task.dueDate = Date() }
                            if !newValue { task.dueDate = nil }
                        }))
                        if let _ = task.dueDate {
                            DatePicker("Due Date", selection: Binding(get: { task.dueDate ?? Date() }, set: { task.dueDate = $0 }), displayedComponents: .date)
                        }
                    }
                    
                    if !allProjects.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Project").font(.caption).foregroundColor(.secondary)
                            Picker("Project", selection: Binding(get: { task.projectId }, set: { task.projectId = $0 })) {
                                Text("None").tag(UUID?.none)
                                ForEach(allProjects) { p in Text(p.title).tag(p.id as UUID?) }
                            }
                        }
                    }
                    
                    if !allAreas.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Area").font(.caption).foregroundColor(.secondary)
                            Picker("Area", selection: Binding(get: { task.areaId }, set: { task.areaId = $0 })) {
                                Text("None").tag(UUID?.none)
                                ForEach(allAreas) { a in Text(a.title).tag(a.id as UUID?) }
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Effort").font(.caption).foregroundColor(.secondary)
                        Picker("Effort", selection: Binding(get: { task.effort ?? "" }, set: { task.effort = $0.isEmpty ? nil : $0 })) {
                            Text("None").tag("")
                            Text("Small").tag("small")
                            Text("Medium").tag("medium")
                            Text("Large").tag("large")
                        }
                    }
                }
                .padding()
            }
            .background(Color(.windowBackgroundColor))
            .navigationTitle("Edit Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        task.updatedAt = Date()
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 600, height: 520)
        .background(Color(.windowBackgroundColor))
    }
}

// MARK: - Bulk Sheets
struct BulkTaskStatusSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    let tasks: [CloutmateShared.Task]
    let onUpdate: (CloutmateShared.TaskStatus) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Change status for \(tasks.count) task\(tasks.count == 1 ? "" : "s")")
                    .font(.headline)
                
                ForEach(CloutmateShared.TaskStatus.allCases, id: \.self) { status in
                    Button(action: { onUpdate(status); dismiss() }) {
                        HStack {
                            Circle().fill(
                                status == .done ? Color.kosmicGreen : status == .inProgress ? Color.orange : status == .cancelled ? Color.gray : Color.kosmicBlue
                            ).frame(width: 12, height: 12)
                            Text(status.displayName)
                            Spacer()
                        }
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                    }.buttonStyle(.plain)
                }
            }
            .padding()
            .background(glassColorSystem.backgroundColor())
            .frame(width: 380, height: 280)
            .navigationTitle("Change Status")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

struct BulkTaskPrioritySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    let tasks: [CloutmateShared.Task]
    let onUpdate: (CloutmateShared.TaskPriority) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Change priority for \(tasks.count) task\(tasks.count == 1 ? "" : "s")")
                    .font(.headline)
                
                ForEach(CloutmateShared.TaskPriority.allCases, id: \.self) { priority in
                    Button(action: { onUpdate(priority); dismiss() }) {
                        HStack {
                            Circle().fill(priority.color).frame(width: 12, height: 12)
                            Text(priority.displayName)
                            Spacer()
                        }
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                    }.buttonStyle(.plain)
                }
            }
            .padding()
            .background(glassColorSystem.backgroundColor())
            .frame(width: 380, height: 280)
            .navigationTitle("Change Priority")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

// MARK: - Clickable Table Headers
struct ClickableTableHeadersView: NSViewRepresentable {
    @Binding var sortColumn: TasksView.SortColumn
    @Binding var sortOrder: SortOrder
    
    func makeNSView(context: Context) -> NSView {
        let view = HeadersTrackingView(sortColumn: $sortColumn, sortOrder: $sortOrder)
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // No-op
    }
}

class HeadersTrackingView: NSView {
    @Binding var sortColumn: TasksView.SortColumn
    @Binding var sortOrder: SortOrder
    private var trackedTableView: NSTableView?
    
    init(sortColumn: Binding<TasksView.SortColumn>, sortOrder: Binding<SortOrder>) {
        _sortColumn = sortColumn
        _sortOrder = sortOrder
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        // Try to find table view after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.findAndSetupTableView()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func findAndSetupTableView() {
        guard let window = self.window else { return }
        guard let contentView = window.contentView else { return }
        
        if let tableView = findTableView(in: contentView), tableView != trackedTableView {
            trackedTableView = tableView
            setupClickableHeaders(tableView)
        }
    }
    
    func findTableView(in view: NSView) -> NSTableView? {
        if let tableView = view as? NSTableView {
            return tableView
        }
        for subview in view.subviews {
            if let tableView = findTableView(in: subview) {
                return tableView
            }
        }
        return nil
    }
    
    func setupClickableHeaders(_ tableView: NSTableView) {
        // Update column titles with sort indicators first
        updateColumnTitles(tableView)
        
        // Create a custom header view
        let customHeader = ClickableTaskHeaderView(
            tableView: tableView,
            sortColumn: $sortColumn,
            sortOrder: $sortOrder,
            updateHandler: { [weak self] in
                self?.updateColumnTitles(tableView)
            }
        )
        
        // Set the frame to match existing header
        if let existingHeader = tableView.headerView {
            customHeader.frame = existingHeader.frame
        }
        
        // Replace the header
        tableView.headerView = customHeader
    }
    
    func updateColumnTitles(_ tableView: NSTableView) {
        let columnMap: [TasksView.SortColumn: Int] = [
            .title: 0, .status: 1, .priority: 2, .dueDate: 3,
            .project: 4, .area: 5, .effort: 6, .updated: 7
        ]
        
        for (columnEnum, index) in columnMap where index < tableView.tableColumns.count {
            let column = tableView.tableColumns[index]
            let baseTitle = column.title.replacingOccurrences(of: " ↑", with: "").replacingOccurrences(of: " ↓", with: "")
            
            if sortColumn == columnEnum {
                let indicator = sortOrder == .forward ? " ↑" : " ↓"
                column.title = baseTitle + indicator
            } else {
                column.title = baseTitle
            }
        }
    }
}

class ClickableTaskHeaderView: NSTableHeaderView {
    weak var myTableView: NSTableView?
    @Binding var sortColumn: TasksView.SortColumn
    @Binding var sortOrder: SortOrder
    var updateHandler: (() -> Void)?
    
    init(
        tableView: NSTableView,
        sortColumn: Binding<TasksView.SortColumn>,
        sortOrder: Binding<SortOrder>,
        updateHandler: @escaping () -> Void
    ) {
        self.myTableView = tableView
        _sortColumn = sortColumn
        _sortOrder = sortOrder
        self.updateHandler = updateHandler
        super.init(frame: .zero)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseDown(with event: NSEvent) {
        guard let tableView = myTableView else {
            super.mouseDown(with: event)
            return
        }
        
        let location = self.convert(event.locationInWindow, from: nil)
        let columnIndex = column(at: NSPoint(x: location.x, y: 0))
        
        if columnIndex >= 0 && columnIndex < tableView.tableColumns.count {
            let column = tableView.tableColumns[columnIndex]
            handleColumnClick(columnTitle: column.title)
            updateHandler?()
        }
        
        super.mouseDown(with: event)
    }
    
    private func handleColumnClick(columnTitle: String) {
        // Map column titles to SortColumn enum
        let columnMap: [String: TasksView.SortColumn] = [
            "Title": .title,
            "Status": .status,
            "Priority": .priority,
            "Due Date": .dueDate,
            "Project": .project,
            "Area": .area,
            "Effort": .effort,
            "Updated": .updated
        ]
        
        let baseTitle = columnTitle.replacingOccurrences(of: " ↑", with: "").replacingOccurrences(of: " ↓", with: "")
        
        if let clickedColumn = columnMap[baseTitle] {
            if sortColumn == clickedColumn {
                // Toggle order if same column clicked
                sortOrder = sortOrder == .forward ? .reverse : .forward
            } else {
                // Switch to new column with ascending order
                sortColumn = clickedColumn
                sortOrder = .forward
            }
        }
    }
}

#Preview {
    TasksView()
        .modelContainer(for: [CloutmateShared.Task.self, CloutmateShared.Project.self, Area.self])
}

