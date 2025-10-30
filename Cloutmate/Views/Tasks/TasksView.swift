//
//  TasksView.swift
//  Cloutmate
//
//  Created by Assistant on 10/28/25.
//

import SwiftUI
import SwiftData

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Query(sort: \Task.updatedAt, order: .reverse) private var allTasks: [Task]
    @Query private var allProjects: [Project]
    @Query private var allAreas: [Area]
    
    @State private var searchText: String = ""
    @State private var selectedStatus: TaskStatus?
    @State private var selectedPriority: TaskPriority?
    @State private var selectedArea: Area?
    @State private var showUnattachedOnly: Bool = false
    @State private var selectedTasks = Set<UUID>()
    
    @State private var showCreateSheet = false
    @State private var showEditSheet = false
    @State private var taskToEdit: Task?
    
    @State private var showBulkStatusSheet = false
    @State private var showBulkPrioritySheet = false
    
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
        
        return filtered
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
                    
                    ForEach(TaskStatus.allCases, id: \.self) { status in
                        FilterChip(
                            title: status.displayName,
                            isSelected: selectedStatus == status,
                            action: { selectedStatus = status }
                        )
                    }
                    
                    ForEach(TaskPriority.allCases, id: \.self) { priority in
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
                TaskStatusBadge(status: task.status)
            }
            .width(min: 110)
            
            TableColumn("Priority") { task in
                TaskPriorityBadge(priority: task.priority)
            }
            .width(min: 110)
            
            TableColumn("Due Date") { task in
                if let due = task.dueDate {
                    Text(due, format: .dateTime.month().day())
                } else {
                    Text("—").foregroundColor(.secondary)
                }
            }
            .width(min: 120)
            
            TableColumn("Project") { task in
                if let pid = task.projectId, let project = allProjects.first(where: { $0.id == pid }) {
                    Text(project.title).font(.caption)
                } else {
                    Text("—").foregroundColor(.secondary)
                }
            }
            .width(min: 140)
            
            TableColumn("Area") { task in
                if let aid = task.areaId, let area = allAreas.first(where: { $0.id == aid }) {
                    Text(area.title).font(.caption)
                } else {
                    Text("—").foregroundColor(.secondary)
                }
            }
            .width(min: 140)
            
            TableColumn("Effort") { task in
                Text(task.effort ?? "—").font(.caption).foregroundColor(.secondary)
            }
            .width(min: 90)
            
            TableColumn("Updated") { task in
                Text(task.updatedAt, style: .relative).font(.caption).foregroundColor(.secondary)
            }
            .width(min: 120)
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
    private func deleteTask(_ task: Task) {
        modelContext.delete(task)
        if selectedTasks.contains(task.id) { selectedTasks.remove(task.id) }
        try? modelContext.save()
    }
    
    private func duplicateTask(_ task: Task) {
        let copy = Task(
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
    
    private func applyBulkStatus(_ newStatus: TaskStatus) {
        let tasksToUpdate = filteredTasks.filter { selectedTasks.contains($0.id) }
        for task in tasksToUpdate { task.status = newStatus }
        selectedTasks.removeAll()
        try? modelContext.save()
    }
    
    private func applyBulkPriority(_ newPriority: TaskPriority) {
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
}

// MARK: - Badges
struct TaskStatusBadge: View {
    let status: TaskStatus
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                (status == .done ? Color.green : status == .inProgress ? Color.orange : status == .cancelled ? Color.gray : Color.blue)
                    .opacity(0.2)
            )
            .foregroundColor(status == .done ? .green : status == .inProgress ? .orange : status == .cancelled ? .gray : .blue)
            .cornerRadius(6)
    }
}

struct TaskPriorityBadge: View {
    let priority: TaskPriority
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

// MARK: - Create / Edit Sheets
struct CreateTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allProjects: [Project]
    @Query private var allAreas: [Area]
    
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var status: TaskStatus = .todo
    @State private var priority: TaskPriority = .medium
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
                        TextField("Notes", text: $notes, axis: .vertical).lineLimit(3...6)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Status").font(.caption).foregroundColor(.secondary)
                        Picker("Status", selection: $status) {
                            ForEach(TaskStatus.allCases, id: \.self) { s in Text(s.displayName).tag(s) }
                        }.pickerStyle(.segmented)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Priority").font(.caption).foregroundColor(.secondary)
                        Picker("Priority", selection: $priority) {
                            ForEach(TaskPriority.allCases, id: \.self) { p in Text(p.displayName).tag(p) }
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
        let task = Task(
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
    @Query private var allProjects: [Project]
    @Query private var allAreas: [Area]
    
    @Bindable var task: Task
    
    @State private var hasDueDate: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Task Title *", text: $task.title)
                        TextField("Notes", text: Binding(get: { task.notes ?? "" }, set: { task.notes = $0.isEmpty ? nil : $0 }), axis: .vertical).lineLimit(3...6)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Status").font(.caption).foregroundColor(.secondary)
                        Picker("Status", selection: $task.status) {
                            ForEach(TaskStatus.allCases, id: \.self) { s in Text(s.displayName).tag(s) }
                        }.pickerStyle(.segmented)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Priority").font(.caption).foregroundColor(.secondary)
                        Picker("Priority", selection: $task.priority) {
                            ForEach(TaskPriority.allCases, id: \.self) { p in Text(p.displayName).tag(p) }
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
    }
}

// MARK: - Bulk Sheets
struct BulkTaskStatusSheet: View {
    @Environment(\.dismiss) private var dismiss
    let tasks: [Task]
    let onUpdate: (TaskStatus) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Change status for \(tasks.count) task\(tasks.count == 1 ? "" : "s")")
                    .font(.headline)
                
                ForEach(TaskStatus.allCases, id: \.self) { status in
                    Button(action: { onUpdate(status); dismiss() }) {
                        HStack {
                            Circle().fill(
                                status == .done ? Color.green : status == .inProgress ? Color.orange : status == .cancelled ? Color.gray : Color.blue
                            ).frame(width: 12, height: 12)
                            Text(status.displayName)
                            Spacer()
                        }
                        .padding(10)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(8)
                    }.buttonStyle(.plain)
                }
            }
            .padding()
            .frame(width: 380, height: 240)
            .navigationTitle("Change Status")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

struct BulkTaskPrioritySheet: View {
    @Environment(\.dismiss) private var dismiss
    let tasks: [Task]
    let onUpdate: (TaskPriority) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Change priority for \(tasks.count) task\(tasks.count == 1 ? "" : "s")")
                    .font(.headline)
                
                ForEach(TaskPriority.allCases, id: \.self) { priority in
                    Button(action: { onUpdate(priority); dismiss() }) {
                        HStack {
                            Circle().fill(priority.color).frame(width: 12, height: 12)
                            Text(priority.displayName)
                            Spacer()
                        }
                        .padding(10)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(8)
                    }.buttonStyle(.plain)
                }
            }
            .padding()
            .frame(width: 380, height: 240)
            .navigationTitle("Change Priority")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

#Preview {
    TasksView()
        .modelContainer(for: [Task.self, Project.self, Area.self])
}


