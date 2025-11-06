//
//  ProjectsView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import CloutmateShared

struct ProjectsView: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CloutmateShared.Project.updatedAt, order: .reverse) private var allProjects: [CloutmateShared.Project]
    @Query private var allTasks: [CloutmateShared.Task]
    @Query private var allAreas: [Area]
    
    @State private var searchText = ""
    @State private var selectedStatus: CloutmateShared.ProjectStatus?
    @State private var selectedArea: Area?
    @State private var selectedTags: Set<String> = []
    @State private var selectedProjects = Set<UUID>()
    @State private var showCreateSheet = false
    @State private var projectToShow: Project?
    @State private var showBulkStatusSheet = false
    @State private var showArchiveConfirmation = false
    
    var filteredProjects: [Project] {
        var filtered = allProjects
        
        if !searchText.isEmpty {
            filtered = filtered.filter { project in
                project.title.localizedCaseInsensitiveContains(searchText) ||
                (project.goal?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        if let status = selectedStatus {
            filtered = filtered.filter { $0.status == status }
        }
        
        if let area = selectedArea {
            filtered = filtered.filter { $0.areaId == area.id }
        }
        
        if !selectedTags.isEmpty {
            filtered = filtered.filter { project in
                !Set(project.tags).isDisjoint(with: selectedTags)
            }
        }
        
        return filtered
    }
    
    var availableTags: [String] {
        Array(Set(allProjects.flatMap { $0.tags })).sorted()
    }
    
    private var searchAndFiltersSection: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search projects...", text: $searchText)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "All",
                        isSelected: selectedStatus == nil && selectedArea == nil,
                        action: { 
                            selectedStatus = nil
                            selectedArea = nil
                        }
                    )
                    
                    ForEach(ProjectStatus.allCases, id: \.self) { status in
                        FilterChip(
                            title: status.displayName,
                            isSelected: selectedStatus == status,
                            action: { selectedStatus = status }
                        )
                    }
                }
            }
            
            // Area filter
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
        Table(filteredProjects, selection: $selectedProjects) {
            TableColumn("Title") { project in
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if let goal = project.goal {
                        Text(goal)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                .contextMenu {
                    Button("Edit") {
                        projectToShow = project
                    }
                    Button("Duplicate") {
                        duplicateProject(project)
                    }
                    Button("Archive") {
                        archiveProject(project)
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        deleteProject(project)
                    }
                }
            }
            .width(min: 200, ideal: 300)
            
            TableColumn("Status") { project in
                ProjectStatusBadge(status: project.status)
            }
            .width(min: 100)
            
            TableColumn("Due Date") { project in
                if let dueDate = project.dueDate {
                    Text(dueDate, format: .dateTime.month().day())
                } else {
                    Text("—")
                        .foregroundColor(.secondary)
                }
            }
            .width(min: 120)
            
            TableColumn("Area") { project in
                if let areaId = project.areaId,
                   let area = allAreas.first(where: { $0.id == areaId }) {
                    Text(area.title)
                        .font(.caption)
                } else {
                    Text("—")
                        .foregroundColor(.secondary)
                }
            }
            .width(min: 120)
            
            TableColumn("Tasks") { project in
                let taskCount = allTasks.filter { $0.projectId == project.id && $0.status != .done }.count
                Text("\(taskCount)")
                    .font(.caption)
                    .foregroundColor(taskCount > 0 ? .kosmicBlue : .secondary)
            }
            .width(min: 80)
            
            TableColumn("Updated") { project in
                Text(project.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .width(min: 120)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchAndFiltersSection
            
            tableSection
        }
        .background(Color(.windowBackgroundColor))
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !selectedProjects.isEmpty {
                    Menu("Actions") {
                        Button("Archive Selected", systemImage: "archivebox") {
                            archiveSelectedProjects()
                        }
                        Button("Delete Selected", systemImage: "trash") {
                            deleteSelectedProjects()
                        }
                        Button("Change Status", systemImage: "arrow.up.right.circle") {
                            showBulkStatusSheet = true
                        }
                    }
                }
                
                Button("New Project") {
                    showCreateSheet = true
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateProjectSheet()
        }
        .sheet(item: $projectToShow) { project in
            ProjectHubSheet(project: project)
        }
        .sheet(isPresented: $showBulkStatusSheet) {
            BulkStatusSheet(projects: filteredProjects.filter { selectedProjects.contains($0.id) }) { newStatus in
                updateBulkStatus(newStatus)
            }
        }
        .onChange(of: selectedProjects) { _, _ in
            if let firstSelected = selectedProjects.first,
               let project = filteredProjects.first(where: { $0.id == firstSelected }) {
                projectToShow = project
            }
        }
    }
    
    private func duplicateProject(_ project: Project) {
        let duplicated = Project(
            title: "\(project.title) (Copy)",
            goal: project.goal,
            status: project.status,
            dueDate: project.dueDate,
            areaId: project.areaId,
            tags: project.tags
        )
        modelContext.insert(duplicated)
        try? modelContext.save()
    }
    
    private func archiveProject(_ project: Project) {
        project.status = .completed
        try? modelContext.save()
    }
    
    private func deleteProject(_ project: Project) {
        modelContext.delete(project)
        if selectedProjects.contains(project.id) {
            selectedProjects.remove(project.id)
        }
        try? modelContext.save()
    }
    
    private func archiveSelectedProjects() {
        let projectsToArchive = filteredProjects.filter { selectedProjects.contains($0.id) }
        for project in projectsToArchive {
            project.status = .completed
        }
        selectedProjects.removeAll()
        try? modelContext.save()
    }
    
    private func deleteSelectedProjects() {
        let projectsToDelete = filteredProjects.filter { selectedProjects.contains($0.id) }
        for project in projectsToDelete {
            modelContext.delete(project)
        }
        selectedProjects.removeAll()
        try? modelContext.save()
    }
    
    private func updateBulkStatus(_ newStatus: ProjectStatus) {
        let projectsToUpdate = filteredProjects.filter { selectedProjects.contains($0.id) }
        for project in projectsToUpdate {
            project.status = newStatus
        }
        selectedProjects.removeAll()
        try? modelContext.save()
    }
}

struct ProjectCard: View {
    let project: Project
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(Color.kosmicBlue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.title)
                        .font(.headline)
                    
                    if let goal = project.goal {
                        Text(goal)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                ProjectStatusBadge(status: project.status)
            }
        }
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 12)
        .onTapGesture(perform: onTap)
    }
}

struct ProjectHubSheet: View {
    @Environment(\.dismiss) private var dismiss
    let project: Project
    
    var body: some View {
        NavigationStack {
            ProjectHubView(project: project)
                .navigationTitle(project.title)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

struct CreateProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allAreas: [Area]
    
    @State private var title = ""
    @State private var goal = ""
    @State private var status = ProjectStatus.active
    @State private var dueDate: Date?
    @State private var areaId: UUID?
    @State private var tags = ""
    @State private var hasDueDate = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Basic Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Basic Information")
                            .font(.headline)
                        
                        TextField("Project Title *", text: $title)
                        
                        TextField("Goal", text: $goal)
                            .lineLimit(3...5)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Status")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("Status", selection: $status) {
                                ForEach(ProjectStatus.allCases, id: \.self) { s in
                                    Text(s.displayName).tag(s)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    
                    Divider()
                    
                    // Organization
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Organization")
                            .font(.headline)
                        
                        if !allAreas.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Area")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Picker("Area", selection: $areaId) {
                                    Text("None").tag(UUID?.none)
                                    ForEach(allAreas) { area in
                                        Text(area.title).tag(area.id as UUID?)
                                    }
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Set Due Date", isOn: $hasDueDate)
                            
                            if hasDueDate {
                                DatePicker("Due Date", selection: Binding(
                                    get: { dueDate ?? Date() },
                                    set: { dueDate = $0 }
                                ), displayedComponents: .date)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tags (comma separated)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("e.g., work, priority", text: $tags)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("New Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createProject()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .frame(width: 600, height: 500)
    }
    
    private func createProject() {
        let tagArray = tags.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let project = Project(
            title: title,
            goal: goal.isEmpty ? nil : goal,
            status: status,
            dueDate: hasDueDate ? dueDate : nil,
            areaId: areaId,
            tags: tagArray
        )
        
        modelContext.insert(project)
        try? modelContext.save()
        dismiss()
    }
}

struct BulkStatusSheet: View {
    @Environment(\.dismiss) private var dismiss
    let projects: [Project]
    let onUpdate: (ProjectStatus) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Change status for \(projects.count) project\(projects.count == 1 ? "" : "s")")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(ProjectStatus.allCases, id: \.self) { status in
                        Button(action: {
                            onUpdate(status)
                            dismiss()
                        }) {
                            HStack {
                                Circle()
                                    .fill(status.color)
                                    .frame(width: 12, height: 12)
                                Text(status.displayName)
                                    .font(.body)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color(.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
            .frame(width: 400, height: 250)
            .navigationTitle("Change Status")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}


extension ProjectStatus {
    var color: Color {
        switch self {
        case .active: return .kosmicGreen
        case .paused: return .orange
        case .completed: return .kosmicBlue
        }
    }
}

struct ProjectHubView: View {
    let project: Project
    @Query private var allTasks: [Task]
    @Query private var allNotes: [Note]
    @Query private var allPosts: [CloutmateShared.Post]
    
    var projectTasks: [Task] {
        allTasks.filter { $0.projectId == project.id }
    }
    
    var projectNotes: [Note] {
        allNotes.filter { $0.projectId == project.id }
    }
    
    var projectPosts: [CloutmateShared.Post] {
        allPosts.filter { $0.projectId == project.id }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Project Header
                ProjectHeaderSection(project: project)
                
            // Tasks
            ProjectTasksSection(tasks: projectTasks)
            
            // Notes
            ProjectNotesSection(notes: projectNotes)
            
            // Posts
            ProjectPostsSection(posts: projectPosts)
            }
            .padding()
        }
        .navigationTitle(project.title)
    }
}

struct ProjectHeaderSection: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(Color.kosmicBlue)
                Text(project.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                ProjectStatusBadge(status: project.status)
            }
            
            if let goal = project.goal {
                Text(goal)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label("Created: \(project.createdAt, style: .date)", systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .glassPanel(tier: .overlay, cornerRadius: 12)
    }
}

struct ProjectTasksSection: View {
    let tasks: [Task]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(Color.kosmicBlue)
                Text("Tasks")
                    .font(.headline)
                Text("(\(tasks.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if tasks.isEmpty {
                Text("No tasks for this project")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
            ForEach(tasks.prefix(10)) { task in
                TaskRow(task: task)
            }
            }
        }
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 12)
    }
}

struct ProjectNotesSection: View {
    let notes: [Note]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(Color.kosmicPurple)
                Text("Notes")
                    .font(.headline)
                Text("(\(notes.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if notes.isEmpty {
                Text("No notes for this project")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(notes.prefix(10)) { note in
                    ProjectNoteRow(note: note)
                }
            }
        }
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 12)
    }
}

struct ProjectNoteRow: View {
    let note: Note
    
    var body: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(.kosmicPurple)
            
            Text(note.title)
                .font(.body)
            
            Spacer()
            
            Text(note.updatedAt, style: .relative)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 8)
    }
}

struct ProjectPostsSection: View {
    let posts: [CloutmateShared.Post]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.and.pencil")
                    .foregroundStyle(Color.kosmicGreen)
                Text("Posts")
                    .font(.headline)
                Text("(\(posts.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if posts.isEmpty {
                Text("No posts for this project")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(posts.prefix(10)) { post in
                    PostPreviewRow(post: post)
                }
            }
        }
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 12)
    }
}

#Preview {
    ProjectsView()
        .modelContainer(for: [CloutmateShared.Project.self, CloutmateShared.Task.self, CloutmateShared.Note.self, CloutmateShared.Post.self])
}

