//
//  AuroraCreateSheet.swift
//  FocusOS
//
//  Aurora-specific create sheets for toolbar actions
//  Collects required information and sends to Aurora as natural language prompt
//

import SwiftUI
import SwiftData
import FocusOSShared

struct AuroraCreateSheet: View {
    let action: ToolbarAction
    @Binding var isPresented: Bool // Only used for dismiss callback, not for conditional rendering
    let onComplete: (String) -> Void // Returns formatted prompt string
    var height: CGFloat = 400 // Default height, can be overridden
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @Query private var allProjects: [Project]
    @Query private var allAreas: [Area]
    
    // Task fields
    @State private var taskTitle = ""
    @State private var taskNotes = ""
    @State private var taskStatus = FocusOSShared.TaskStatus.todo
    @State private var taskPriority = FocusOSShared.TaskPriority.medium
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
    
    private var accentGradient: LinearGradient {
        AuroraPalette.linearGradient(for: colorScheme)
    }
    
    private var drawerTitle: String {
        switch action {
        case .createTask: return "Create Task"
        case .createProject: return "Create Project"
        case .createNote: return "Create Note"
        case .createReminder: return "Create Reminder"
        case .analyzeDocument, .analyzeImage: return "Create"
        }
    }
    
    private var drawerSubtitle: String {
        switch action {
        case .createTask: return "Provide details for Aurora to create"
        case .createProject: return "Provide details for Aurora to create"
        case .createNote: return "Provide details for Aurora to create"
        case .createReminder: return "Provide details for Aurora to create"
        case .analyzeDocument, .analyzeImage: return ""
        }
    }
    
    var body: some View {
        // Explicitly prevent any modal behavior - this is a drawer component only
        VStack(spacing: 0) {
            // Header - subtle, V2 polished (matching SlashCommandDrawerView style)
            HStack(spacing: 10) {
                Image(systemName: headerIcon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(glassColorSystem.textSecondary())
                
                Text(drawerTitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
                
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    AuroraShimmerView(colorScheme: colorScheme)
                }
            )
            .overlay(
                Divider()
                    .opacity(0.08),
                alignment: .bottom
            )
            
            // Content - scrollable form, centered vertically in available space
            GeometryReader { geometry in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        drawerContent
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: geometry.size.height)
                }
                .background(glassColorSystem.backgroundColor())
            }
        }
        .background(glassColorSystem.backgroundColor())
        .frame(maxHeight: height)
    }
    
    private struct AuroraShimmerView: View {
        let colorScheme: ColorScheme
        
        var body: some View {
            Rectangle()
                .fill(
                    AuroraPalette.linearGradient(
                        for: colorScheme,
                        start: .leading,
                        end: .trailing
                    )
                )
                .opacity(0.12)
                .auroraShimmer()
                .allowsHitTesting(false)
            }
    }
    
    private var headerIcon: String {
        switch action {
        case .createTask: return "checkmark.circle.fill"
        case .createProject: return "folder.fill"
        case .createNote: return "note.text"
        case .createReminder: return "bell.fill"
        case .analyzeDocument, .analyzeImage: return "doc.text"
        }
    }
    
    private func closeDrawer() {
        // Update binding to trigger dismiss callback in parent
        isPresented = false
    }
    
    @ViewBuilder
    private var drawerContent: some View {
        VStack(spacing: 24) {
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
            
            // Submit button at bottom of content
            HStack(spacing: 12) {
                Spacer()
                
                Button {
                    closeDrawer()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(glassColorSystem.glassTint(for: .surface).opacity(0.2))
                        )
                }
                .buttonStyle(.plain)
                
                Button {
                    submitToAurora()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Submit to Aurora")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
        .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                isValid
                                ? LinearGradient(
                                    colors: [.kosmicBlue, .kosmicPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                : LinearGradient(
                                    colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(!isValid)
            }
            .padding(.top, 8)
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
        VStack(alignment: .leading, spacing: 24) {
            DrawerSection(title: "Task Details", icon: "checkmark.circle") {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                Text("Task Title *")
                            .font(.caption)
                            .foregroundStyle(glassColorSystem.textSecondary())
                TextField("Enter task title", text: $taskTitle)
                    .textFieldStyle(.plain)
                            .font(.body)
                            .foregroundStyle(glassColorSystem.textPrimary())
                    .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(glassColorSystem.backgroundSecondary().opacity(0.4))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(glassColorSystem.borderColor().opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                Text("Notes (optional)")
                            .font(.caption)
                            .foregroundStyle(glassColorSystem.textSecondary())
                TextEditor(text: $taskNotes)
                    .frame(height: 100)
                            .font(.body)
                            .foregroundStyle(glassColorSystem.textPrimary())
                    .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(glassColorSystem.backgroundSecondary().opacity(0.4))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(glassColorSystem.borderColor().opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .scrollContentBackground(.hidden)
                    }
                }
            }
            
            DrawerSection(title: "Options", icon: "slider.horizontal.3") {
                VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Status")
                            .font(.caption)
                                .foregroundStyle(glassColorSystem.textSecondary())
                        Picker("Status", selection: $taskStatus) {
                            ForEach(FocusOSShared.TaskStatus.allCases, id: \.self) { status in
                                Text(status.displayName).tag(status)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Priority")
                            .font(.caption)
                                .foregroundStyle(glassColorSystem.textSecondary())
                        Picker("Priority", selection: $taskPriority) {
                            ForEach(FocusOSShared.TaskPriority.allCases, id: \.self) { priority in
                                Text(priority.displayName).tag(priority)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                Toggle("Set Due Date", isOn: $taskHasDueDate)
                        .foregroundStyle(glassColorSystem.textPrimary())
                    
                if taskHasDueDate {
                    DatePicker("Due Date", selection: Binding(
                        get: { taskDueDate ?? Date() },
                        set: { taskDueDate = $0 }
                    ), displayedComponents: .date)
                        .foregroundStyle(glassColorSystem.textPrimary())
                }
                
                if !allProjects.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Project (optional)")
                            .font(.caption)
                                .foregroundStyle(glassColorSystem.textSecondary())
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
                                .foregroundStyle(glassColorSystem.textSecondary())
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
    }
    
    // MARK: - Project Form
    
    private var projectForm: some View {
        VStack(alignment: .leading, spacing: 24) {
            DrawerSection(title: "Project Details", icon: "folder") {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                Text("Project Title *")
                            .font(.caption)
                            .foregroundStyle(glassColorSystem.textSecondary())
                TextField("Enter project title", text: $projectTitle)
                    .textFieldStyle(.plain)
                            .font(.body)
                            .foregroundStyle(glassColorSystem.textPrimary())
                    .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(glassColorSystem.backgroundSecondary().opacity(0.4))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(glassColorSystem.borderColor().opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                Text("Goal (optional)")
                            .font(.caption)
                            .foregroundStyle(glassColorSystem.textSecondary())
                TextField("What's the goal of this project?", text: $projectGoal)
                    .textFieldStyle(.plain)
                            .font(.body)
                            .foregroundStyle(glassColorSystem.textPrimary())
                    .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(glassColorSystem.backgroundSecondary().opacity(0.4))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(glassColorSystem.borderColor().opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                }
            }
            
            DrawerSection(title: "Options", icon: "slider.horizontal.3") {
                VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Status")
                        .font(.caption)
                            .foregroundStyle(glassColorSystem.textSecondary())
                    Picker("Status", selection: $projectStatus) {
                        ForEach(ProjectStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Toggle("Set Due Date", isOn: $projectHasDueDate)
                        .foregroundStyle(glassColorSystem.textPrimary())
                    
                if projectHasDueDate {
                    DatePicker("Due Date", selection: Binding(
                        get: { projectDueDate ?? Date() },
                        set: { projectDueDate = $0 }
                    ), displayedComponents: .date)
                        .foregroundStyle(glassColorSystem.textPrimary())
                }
                
                if !allAreas.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Area (optional)")
                            .font(.caption)
                                .foregroundStyle(glassColorSystem.textSecondary())
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
    }
    
    // MARK: - Note Form
    
    private var noteForm: some View {
        VStack(alignment: .leading, spacing: 24) {
            DrawerSection(title: "Note Details", icon: "note.text") {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                Text("Note Title *")
                            .font(.caption)
                            .foregroundStyle(glassColorSystem.textSecondary())
                TextField("Enter note title", text: $noteTitle)
                    .textFieldStyle(.plain)
                            .font(.body)
                            .foregroundStyle(glassColorSystem.textPrimary())
                    .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(glassColorSystem.backgroundSecondary().opacity(0.4))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(glassColorSystem.borderColor().opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                Text("Content (optional)")
                            .font(.caption)
                            .foregroundStyle(glassColorSystem.textSecondary())
                TextEditor(text: $noteBody)
                    .frame(height: 150)
                            .font(.body)
                            .foregroundStyle(glassColorSystem.textPrimary())
                    .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(glassColorSystem.backgroundSecondary().opacity(0.4))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(glassColorSystem.borderColor().opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .scrollContentBackground(.hidden)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                Text("Tags (comma separated, optional)")
                            .font(.caption)
                            .foregroundStyle(glassColorSystem.textSecondary())
                TextField("e.g., work, ideas", text: $noteTags)
                    .textFieldStyle(.plain)
                            .font(.body)
                            .foregroundStyle(glassColorSystem.textPrimary())
                    .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(glassColorSystem.backgroundSecondary().opacity(0.4))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(glassColorSystem.borderColor().opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                }
            }
            
            DrawerSection(title: "Organization", icon: "folder") {
                VStack(alignment: .leading, spacing: 16) {
                if !allProjects.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Project (optional)")
                            .font(.caption)
                                .foregroundStyle(glassColorSystem.textSecondary())
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
                                .foregroundStyle(glassColorSystem.textSecondary())
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
    }
    
    // MARK: - Reminder Form
    
    private var reminderForm: some View {
        VStack(alignment: .leading, spacing: 24) {
            DrawerSection(title: "Reminder Details", icon: "bell") {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                Text("Reminder Title *")
                            .font(.caption)
                            .foregroundStyle(glassColorSystem.textSecondary())
                TextField("What should I remind you about?", text: $reminderTitle)
                    .textFieldStyle(.plain)
                            .font(.body)
                            .foregroundStyle(glassColorSystem.textPrimary())
                    .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(glassColorSystem.backgroundSecondary().opacity(0.4))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(glassColorSystem.borderColor().opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                Text("Notes (optional)")
                            .font(.caption)
                            .foregroundStyle(glassColorSystem.textSecondary())
                TextEditor(text: $reminderNotes)
                    .frame(height: 100)
                            .font(.body)
                            .foregroundStyle(glassColorSystem.textPrimary())
                    .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(glassColorSystem.backgroundSecondary().opacity(0.4))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(glassColorSystem.borderColor().opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .scrollContentBackground(.hidden)
                    }
                }
            }
            
            DrawerSection(title: "When", icon: "clock") {
                VStack(alignment: .leading, spacing: 16) {
                DatePicker("Date", selection: $reminderDate, displayedComponents: .date)
                        .foregroundStyle(glassColorSystem.textPrimary())
                
                Toggle("Set Specific Time", isOn: $reminderHasTime)
                        .foregroundStyle(glassColorSystem.textPrimary())
                    
                if reminderHasTime {
                    DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .foregroundStyle(glassColorSystem.textPrimary())
                    }
                }
            }
        }
    }
    
    // MARK: - Submit
    
    private func submitToAurora() {
        let prompt = formatPrompt()
        closeDrawer()
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

