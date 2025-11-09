//
//  AuroraCreateSheet.swift
//  Cloutmate
//
//  Aurora-specific create sheets for toolbar actions
//  Collects required information and sends to Aurora as natural language prompt
//

import SwiftUI
import SwiftData
import CloutmateShared

struct AuroraCreateSheet: View {
    let action: ToolbarAction
    let onComplete: (String) -> Void // Returns formatted prompt string
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @Query private var allProjects: [Project]
    @Query private var allAreas: [Area]
    
    // Task fields
    @State private var taskTitle = ""
    @State private var taskNotes = ""
    @State private var taskStatus = CloutmateShared.TaskStatus.todo
    @State private var taskPriority = CloutmateShared.TaskPriority.medium
    @State private var taskDueDate: Date?
    @State private var taskProjectId: UUID?
    @State private var taskAreaId: UUID?
    @State private var taskHasDueDate = false
    
    // Project fields
    @State private var projectTitle = ""
    @State private var projectGoal = ""
    @State private var projectStatus = ProjectStatus.active
    @State private var projectDueDate: Date?
    @State private var projectAreaId: UUID?
    @State private var projectHasDueDate = false
    
    // Note fields
    @State private var noteTitle = ""
    @State private var noteBody = ""
    @State private var noteTags = ""
    @State private var noteProjectId: UUID?
    @State private var noteAreaId: UUID?
    
    // Reminder fields
    @State private var reminderTitle = ""
    @State private var reminderNotes = ""
    @State private var reminderDate = Date()
    @State private var reminderTime = Date()
    @State private var reminderHasTime = true
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    switch action {
                    case .createTask:
                        taskForm
                    case .createProject:
                        projectForm
                    case .createNote:
                        noteForm
                    case .createReminder:
                        reminderForm
                    case .analyzeDocument, .analyzeImage:
                        EmptyView()
                    }
                }
                .padding()
            }
            .background(glassColorSystem.backgroundColor())
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit to Aurora") {
                        submitToAurora()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .frame(width: 600, height: 500)
    }
    
    private var navigationTitle: String {
        switch action {
        case .createTask: return "Create Task"
        case .createProject: return "Create Project"
        case .createNote: return "Create Note"
        case .createReminder: return "Create Reminder"
        case .analyzeDocument, .analyzeImage: return ""
        }
    }
    
    private var isValid: Bool {
        switch action {
        case .createTask:
            return !taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .createProject:
            return !projectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .createNote:
            return !noteTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .createReminder:
            return !reminderTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .analyzeDocument, .analyzeImage:
            return false
        }
    }
    
    // MARK: - Task Form
    
    private var taskForm: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Task Title *")
                    .font(.headline)
                TextField("Enter task title", text: $taskTitle)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                
                Text("Notes (optional)")
                    .font(.headline)
                    .padding(.top, 8)
                TextEditor(text: $taskNotes)
                    .frame(height: 100)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Details")
                    .font(.headline)
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Status")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Status", selection: $taskStatus) {
                            ForEach(CloutmateShared.TaskStatus.allCases, id: \.self) { status in
                                Text(status.displayName).tag(status)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Priority")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Priority", selection: $taskPriority) {
                            ForEach(CloutmateShared.TaskPriority.allCases, id: \.self) { priority in
                                Text(priority.displayName).tag(priority)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                Toggle("Set Due Date", isOn: $taskHasDueDate)
                if taskHasDueDate {
                    DatePicker("Due Date", selection: Binding(
                        get: { taskDueDate ?? Date() },
                        set: { taskDueDate = $0 }
                    ), displayedComponents: .date)
                }
                
                if !allProjects.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Project (optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Project", selection: $taskProjectId) {
                            Text("None").tag(UUID?.none)
                            ForEach(allProjects) { project in
                                Text(project.title).tag(project.id as UUID?)
                            }
                        }
                    }
                }
                
                if !allAreas.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Area (optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Area", selection: $taskAreaId) {
                            Text("None").tag(UUID?.none)
                            ForEach(allAreas) { area in
                                Text(area.title).tag(area.id as UUID?)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Project Form
    
    private var projectForm: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Project Title *")
                    .font(.headline)
                TextField("Enter project title", text: $projectTitle)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                
                Text("Goal (optional)")
                    .font(.headline)
                    .padding(.top, 8)
                TextField("What's the goal of this project?", text: $projectGoal)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Details")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("Status", selection: $projectStatus) {
                        ForEach(ProjectStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Toggle("Set Due Date", isOn: $projectHasDueDate)
                if projectHasDueDate {
                    DatePicker("Due Date", selection: Binding(
                        get: { projectDueDate ?? Date() },
                        set: { projectDueDate = $0 }
                    ), displayedComponents: .date)
                }
                
                if !allAreas.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Area (optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Area", selection: $projectAreaId) {
                            Text("None").tag(UUID?.none)
                            ForEach(allAreas) { area in
                                Text(area.title).tag(area.id as UUID?)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Note Form
    
    private var noteForm: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Note Title *")
                    .font(.headline)
                TextField("Enter note title", text: $noteTitle)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                
                Text("Content (optional)")
                    .font(.headline)
                    .padding(.top, 8)
                TextEditor(text: $noteBody)
                    .frame(height: 150)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                
                Text("Tags (comma separated, optional)")
                    .font(.headline)
                    .padding(.top, 8)
                TextField("e.g., work, ideas", text: $noteTags)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Organization")
                    .font(.headline)
                
                if !allProjects.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Project (optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Project", selection: $noteProjectId) {
                            Text("None").tag(UUID?.none)
                            ForEach(allProjects) { project in
                                Text(project.title).tag(project.id as UUID?)
                            }
                        }
                    }
                }
                
                if !allAreas.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Area (optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Area", selection: $noteAreaId) {
                            Text("None").tag(UUID?.none)
                            ForEach(allAreas) { area in
                                Text(area.title).tag(area.id as UUID?)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Reminder Form
    
    private var reminderForm: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Reminder Title *")
                    .font(.headline)
                TextField("What should I remind you about?", text: $reminderTitle)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                
                Text("Notes (optional)")
                    .font(.headline)
                    .padding(.top, 8)
                TextEditor(text: $reminderNotes)
                    .frame(height: 100)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("When")
                    .font(.headline)
                
                DatePicker("Date", selection: $reminderDate, displayedComponents: .date)
                
                Toggle("Set Specific Time", isOn: $reminderHasTime)
                if reminderHasTime {
                    DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                }
            }
        }
    }
    
    // MARK: - Submit
    
    private func submitToAurora() {
        let prompt = formatPrompt()
        dismiss()
        onComplete(prompt)
    }
    
    private func formatPrompt() -> String {
        switch action {
        case .createTask:
            var parts: [String] = []
            
            // Build mention string if project/area selected
            var mentionParts: [String] = []
            if let projectId = taskProjectId, let project = allProjects.first(where: { $0.id == projectId }) {
                mentionParts.append("@\(project.title)")
            }
            if let areaId = taskAreaId, let area = allAreas.first(where: { $0.id == areaId }) {
                mentionParts.append("@\(area.title)")
            }
            
            // Start with task title and mentions
            if mentionParts.isEmpty {
                parts.append("Create a task: \(taskTitle)")
            } else {
                parts.append("Create a task \(mentionParts.joined(separator: " ")): \(taskTitle)")
            }
            
            // Add notes if provided
            if !taskNotes.isEmpty {
                parts.append(taskNotes)
            }
            
            // Add status if not default
            if taskStatus != .todo {
                parts.append("Status: \(taskStatus.displayName)")
            }
            
            // Add priority if not default
            if taskPriority != .medium {
                parts.append("Priority: \(taskPriority.displayName)")
            }
            
            // Add due date if set
            if let dueDate = taskDueDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                parts.append("Due date: \(formatter.string(from: dueDate))")
            }
            
            return parts.joined(separator: "\n")
            
        case .createProject:
            var parts: [String] = []
            
            // Build mention string if area selected
            var mentionParts: [String] = []
            if let areaId = projectAreaId, let area = allAreas.first(where: { $0.id == areaId }) {
                mentionParts.append("@\(area.title)")
            }
            
            // Start with project title and mentions
            if mentionParts.isEmpty {
                parts.append("Create a project: \(projectTitle)")
            } else {
                parts.append("Create a project \(mentionParts.joined(separator: " ")): \(projectTitle)")
            }
            
            // Add goal if provided
            if !projectGoal.isEmpty {
                parts.append("Goal: \(projectGoal)")
            }
            
            // Add status if not default
            if projectStatus != .active {
                parts.append("Status: \(projectStatus.displayName)")
            }
            
            // Add due date if set
            if let dueDate = projectDueDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                parts.append("Due date: \(formatter.string(from: dueDate))")
            }
            
            return parts.joined(separator: "\n")
            
        case .createNote:
            var parts: [String] = []
            
            // Build mention string if project/area selected
            var mentionParts: [String] = []
            if let projectId = noteProjectId, let project = allProjects.first(where: { $0.id == projectId }) {
                mentionParts.append("@\(project.title)")
            }
            if let areaId = noteAreaId, let area = allAreas.first(where: { $0.id == areaId }) {
                mentionParts.append("@\(area.title)")
            }
            
            // Start with note title and mentions
            if mentionParts.isEmpty {
                parts.append("Create a note: \(noteTitle)")
            } else {
                parts.append("Create a note \(mentionParts.joined(separator: " ")): \(noteTitle)")
            }
            
            // Add content if provided
            if !noteBody.isEmpty {
                parts.append(noteBody)
            }
            
            // Add tags if provided
            if !noteTags.isEmpty {
                let tags = noteTags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                parts.append("Tags: \(tags.joined(separator: ", "))")
            }
            
            return parts.joined(separator: "\n")
            
        case .createReminder:
            var parts: [String] = []
            
            // Format date/time
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            var dateTimeString = dateFormatter.string(from: reminderDate)
            if reminderHasTime {
                let timeFormatter = DateFormatter()
                timeFormatter.timeStyle = .short
                dateTimeString += " at \(timeFormatter.string(from: reminderTime))"
            }
            
            // Build prompt
            parts.append("Create a reminder: \(reminderTitle)")
            parts.append("When: \(dateTimeString)")
            
            // Add notes if provided
            if !reminderNotes.isEmpty {
                parts.append(reminderNotes)
            }
            
            return parts.joined(separator: "\n")
            
        case .analyzeDocument, .analyzeImage:
            return ""
        }
    }
}

