//
//  AreaDetailDrawer.swift
//  Cloutmate
//
//  Areas V2 - Detail drawer with full area information
//

import SwiftUI
import SwiftData
import CloutmateShared

struct AreaDetailDrawer: View {
    @Bindable var area: Area
    let projects: [CloutmateShared.Project]
    let notes: [Note]
    let tasks: [CloutmateShared.Task]
    let onDismiss: () -> Void
    let onArchive: () -> Void
    let onOpenProject: (CloutmateShared.Project) -> Void
    let onOpenNote: (Note) -> Void
    let onOpenTask: (CloutmateShared.Task) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var editedTitle: String = ""
    @State private var editedNotes: String = ""
    @State private var editedTags: [String] = []
    @State private var editedStatus: AreaStatus = .active
    @State private var auroraInsight: String = ""
    @State private var showProjectLinker = false
    @State private var showNoteLinker = false
    @State private var showTaskLinker = false
    
    private var linkedProjects: [CloutmateShared.Project] {
        projects.filter { $0.areaId == area.id }
    }
    
    private var linkedNotes: [Note] {
        notes.filter { $0.areaId == area.id }
    }
    
    private var linkedTasks: [CloutmateShared.Task] {
        tasks.filter { $0.areaId == area.id }
    }
    
    private var availableProjects: [CloutmateShared.Project] {
        projects.filter { $0.areaId == nil || $0.areaId == area.id }
    }
    
    private var availableNotes: [Note] {
        notes.filter { $0.areaId == nil || $0.areaId == area.id }
    }
    
    private var availableTasks: [CloutmateShared.Task] {
        tasks.filter { $0.areaId == nil || $0.areaId == area.id }
    }
    
    private var arteColor: Color {
        let state = ReactiveThemeManager.shared.currentState
        switch state {
        case .calm: return .kosmicGreen
        case .focused: return .kosmicBlue
        case .energized: return .kosmicPurple
        case .reflective: return .kosmicPurple.opacity(0.8)
        case .fatigued: return .gray
        }
    }
    
    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                focusSidebar
                
                VStack(spacing: 0) {
                    header
                        .padding()
                        .background(.ultraThinMaterial)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            descriptionSection
                            linkedEntitiesSection
                            if !auroraInsight.isEmpty {
                                auroraInsightSection
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 24)
                    }
                    .background(Color(.windowBackgroundColor))
                    
                    actionsFooter
                        .padding(20)
                        .background(.ultraThinMaterial)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(glassColorSystem.backgroundColor())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        saveAndDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .frame(idealWidth: 800, idealHeight: 600)
        .onAppear {
            editedTitle = area.title
            editedNotes = area.notes ?? ""
            editedTags = area.tags
            editedStatus = area.status
            loadAuroraInsight()
        }
        .sheet(isPresented: $showProjectLinker) {
            projectLinkerSheet
        }
        .sheet(isPresented: $showNoteLinker) {
            noteLinkerSheet
        }
        .sheet(isPresented: $showTaskLinker) {
            taskLinkerSheet
        }
    }
    
    private var focusSidebar: some View {
        RoundedRectangle(cornerRadius: 0, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [arteColor.opacity(0.85), arteColor.opacity(0.35)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 4)
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                TextField("Area Title", text: $editedTitle)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .textFieldStyle(.plain)
                    .onChange(of: editedTitle) { _, newValue in
                        area.title = newValue
                        area.updatedAt = Date()
                        try? modelContext.save()
                    }
                
                Spacer()
                
                Menu {
                    ForEach([AreaStatus.active, .reviewNeeded, .archived], id: \.self) { status in
                        Button(action: {
                            editedStatus = status
                            area.status = status
                            area.updatedAt = Date()
                            try? modelContext.save()
                        }) {
                            Label(status.rawValue.capitalized, systemImage: editedStatus == status ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "flag")
                        Text(editedStatus.rawValue.capitalized)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(glassColorSystem.glassTint(for: .surface).opacity(0.3))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            EditableTagsView(tags: $editedTags)
                .onChange(of: editedTags) { _, newValue in
                    area.tags = newValue
                    area.updatedAt = Date()
                    try? modelContext.save()
                }
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Description")
                .font(.headline)
                .foregroundColor(glassColorSystem.textPrimary())
            
            TextEditor(text: $editedNotes)
                .font(.body)
                .frame(minHeight: 160)
                .padding(10)
                .background(glassColorSystem.glassTint(for: .surface).opacity(0.3))
                .cornerRadius(10)
                .onChange(of: editedNotes) { _, newValue in
                    area.notes = newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : newValue
                    area.updatedAt = Date()
                    try? modelContext.save()
                }
        }
    }
    
    private var linkedEntitiesSection: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(.kosmicBlue)
                    Text("Linked Entities")
                        .font(.headline)
                        .foregroundColor(glassColorSystem.textPrimary())
                    Spacer()
                    linkControlMenu
                }
                
                if linkedProjects.isEmpty && linkedNotes.isEmpty && linkedTasks.isEmpty {
                    Text("Link projects, tasks, or notes to keep this area anchored in your workflow.")
                        .font(.caption)
                        .foregroundColor(glassColorSystem.textSecondary())
                        .padding(.vertical, 4)
                }
                
                if !linkedProjects.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel(title: "Projects", icon: "folder.fill", color: .kosmicBlue)
                        ForEach(linkedProjects.sorted(by: { $0.updatedAt > $1.updatedAt })) { project in
                            Button {
                                onOpenProject(project)
                            } label: {
                                LinkedEntityRow(
                                    title: project.title,
                                    subtitle: project.status.displayName,
                                    icon: "folder",
                                    accent: .kosmicBlue
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                if !linkedTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel(title: "Tasks", icon: "checkmark.circle", color: .kosmicGreen)
                        ForEach(linkedTasks.sorted(by: { ($0.dueDate ?? Date.distantFuture) < ($1.dueDate ?? Date.distantFuture) })) { task in
                            Button {
                                onOpenTask(task)
                            } label: {
                                LinkedEntityRow(
                                    title: task.title,
                                    subtitle: subtitle(for: task),
                                    icon: task.status == .done ? "checkmark.circle.fill" : "circle",
                                    accent: task.status == .done ? .kosmicGreen : .kosmicBlue
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                if !linkedNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel(title: "Notes", icon: "doc.text.fill", color: .kosmicPurple)
                        ForEach(linkedNotes.sorted(by: { $0.updatedAt > $1.updatedAt })) { note in
                            Button {
                                onOpenNote(note)
                            } label: {
                                LinkedEntityRow(
                                    title: note.title.isEmpty ? "Untitled Note" : note.title,
                                    subtitle: note.updatedAt.formatted(date: .abbreviated, time: .shortened),
                                    icon: "doc.text",
                                    accent: .kosmicPurple
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
        }
    }
    
    private var auroraInsightSection: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.kosmicPurple)
                    Text("Aurora Insight")
                        .font(.headline)
                        .foregroundColor(glassColorSystem.textPrimary())
                }
                
                Text(auroraInsight)
                    .font(.body)
                    .foregroundColor(glassColorSystem.textSecondary())
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var actionsFooter: some View {
        HStack(spacing: 12) {
            Button(action: {
                saveEdits()
                onArchive()
            }) {
                Label("Archive Area", systemImage: "archivebox")
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button(action: {
                showProjectLinker = true
            }) {
                Label("Link Project", systemImage: "link")
            }
            .buttonStyle(.bordered)
            .disabled(availableProjects.isEmpty)
            
            Button(action: {
                showNoteLinker = true
            }) {
                Label("Link Note", systemImage: "doc.text")
            }
            .buttonStyle(.bordered)
            .disabled(availableNotes.isEmpty)
            
            Button(action: {
                showTaskLinker = true
            }) {
                Label("Link Task", systemImage: "checkmark.circle")
            }
            .buttonStyle(.bordered)
            .disabled(availableTasks.isEmpty)
            
            Button(action: saveAndDismiss) {
                Text("Done")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private func saveEdits() {
        area.title = editedTitle
        area.notes = editedNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editedNotes
        area.tags = editedTags
        area.status = editedStatus
        area.updatedAt = Date()
        try? modelContext.save()
    }
    
    private func saveAndDismiss() {
        saveEdits()
        onDismiss()
    }
    
    private func loadAuroraInsight() {
        auroraInsight = "You've maintained steady focus in this area. Consider reviewing linked projects for updates."
    }
    
    private var linkControlMenu: some View {
        Menu {
            Button("Link Project", systemImage: "folder") {
                showProjectLinker = true
            }
            .disabled(availableProjects.isEmpty)
            
            Button("Link Task", systemImage: "checkmark.circle") {
                showTaskLinker = true
            }
            .disabled(availableTasks.isEmpty)
            
            Button("Link Note", systemImage: "doc.text") {
                showNoteLinker = true
            }
            .disabled(availableNotes.isEmpty)
        } label: {
            Image(systemName: "plus.circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(glassColorSystem.textSecondary())
        }
        .menuStyle(.borderlessButton)
    }
    
    private func sectionLabel(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title.uppercased())
                .font(.caption2)
                .foregroundColor(glassColorSystem.textSecondary())
        }
    }
    
    private func subtitle(for task: CloutmateShared.Task) -> String {
        if let due = task.dueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return task.status == .done ? "Completed" : "Due \(formatter.string(from: due))"
        }
        return task.status.displayName
    }
    
    private func linkProject(_ project: Project) {
        project.areaId = area.id
        project.updatedAt = Date()
        area.updatedAt = Date()
        AreaStabilityService.shared.invalidateCache(for: area.id)
        try? modelContext.save()
        AreaReviewService.shared.syncStatus(for: area, modelContext: modelContext)
    }
    
    private func linkNote(_ note: Note) {
        note.areaId = area.id
        note.updatedAt = Date()
        area.updatedAt = Date()
        AreaStabilityService.shared.invalidateCache(for: area.id)
        try? modelContext.save()
        AreaReviewService.shared.syncStatus(for: area, modelContext: modelContext)
    }
    
    private func linkTask(_ task: CloutmateShared.Task) {
        task.areaId = area.id
        task.updatedAt = Date()
        area.updatedAt = Date()
        AreaStabilityService.shared.invalidateCache(for: area.id)
        try? modelContext.save()
        AreaReviewService.shared.syncStatus(for: area, modelContext: modelContext)
    }
    
    private var projectLinkerSheet: some View {
        NavigationStack {
            List {
                if availableProjects.isEmpty {
                    Text("No projects available to link.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(availableProjects) { project in
                        Button {
                            linkProject(project)
                            showProjectLinker = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(project.title)
                                        .font(.body)
                                    if let due = project.dueDate {
                                        Text("Due \(due.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                if project.areaId == area.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.kosmicBlue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Link Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        showProjectLinker = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("New Project") {
                        NotificationCenter.default.post(name: .showCreateProject, object: nil)
                        showProjectLinker = false
                    }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 420)
    }
    
    private var noteLinkerSheet: some View {
        NavigationStack {
            List {
                if availableNotes.isEmpty {
                    Text("No notes available to link.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(availableNotes) { note in
                        Button {
                            linkNote(note)
                            showNoteLinker = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(note.title.isEmpty ? "Untitled Note" : note.title)
                                        .font(.body)
                                    Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if note.areaId == area.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.kosmicPurple)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Link Note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        showNoteLinker = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("New Note") {
                        NotificationCenter.default.post(name: .showCreateNote, object: nil)
                        showNoteLinker = false
                    }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 420)
    }
    
    private var taskLinkerSheet: some View {
        NavigationStack {
            List {
                if availableTasks.isEmpty {
                    Text("No tasks available to link.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(availableTasks) { task in
                        Button {
                            linkTask(task)
                            showTaskLinker = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(task.title)
                                        .font(.body)
                                    Text(subtitle(for: task))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if task.areaId == area.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.kosmicGreen)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Link Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        showTaskLinker = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("New Task") {
                        NotificationCenter.default.post(name: .showCreateTask, object: nil)
                        showTaskLinker = false
                    }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 420)
    }
}

struct LinkedEntityRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(accent)
                .frame(width: 18, height: 18)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                    .foregroundColor(glassColorSystem.textPrimary())
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(glassColorSystem.textSecondary())
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "arrow.up.right")
                .font(.caption)
                .foregroundColor(glassColorSystem.textSecondary())
        }
        .padding(10)
        .background(glassColorSystem.glassTint(for: .surface).opacity(0.25))
        .cornerRadius(10)
    }
}

struct EditableTagsView: View {
    @Binding var tags: [String]
    @State private var newTag: String = ""
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    AreaTagChip(text: tag) {
                        tags.removeAll { $0 == tag }
                    }
                }
                
                TextField("Add tag", text: $newTag)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .frame(width: 80)
                    .onSubmit {
                        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
                        tags.append(trimmed)
                        newTag = ""
                    }
            }
        }
    }
}

struct AreaTagChip: View {
    let text: String
    let onDelete: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.kosmicBlue)
        .cornerRadius(8)
    }
}

#Preview {
    let area = Area(title: "Health & Wellness", notes: "Maintaining physical and mental health.")
    area.tags = ["personal", "health"]
    let sampleTask = Task(title: "Update workout plan")
    sampleTask.areaId = area.id
    
    return AreaDetailDrawer(
        area: area,
        projects: [],
        notes: [],
        tasks: [sampleTask],
        onDismiss: {},
        onArchive: {},
        onOpenProject: { _ in },
        onOpenNote: { _ in },
        onOpenTask: { _ in }
    )
    .environmentObject(GlassColorSystem())
}

