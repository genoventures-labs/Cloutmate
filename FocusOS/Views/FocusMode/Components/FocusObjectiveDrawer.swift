//
//  FocusObjectiveDrawer.swift
//  FocusOS
//
//  Focus Mode V2 - Objective Drawer
//

import SwiftUI
import SwiftData
import FocusOSShared

struct FocusObjectiveDrawer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Binding var objective: String
    @Binding var selectedDuration: TimeInterval
    @Binding var reflectAfterSession: Bool
    
    // Optional initial values for pre-filling from pending session params
    let initialTargetObjectId: UUID?
    let initialTargetObjectType: String?
    
    @State private var selectedObjectType: ObjectType = .none
    @State private var selectedTaskId: UUID?
    @State private var selectedProjectId: UUID?
    @State private var selectedNoteId: UUID?
    @State private var cpsScore: Double?
    @State private var searchText: String = ""
    
    @Query(sort: \FocusOSShared.Task.updatedAt, order: .reverse) private var allTasks: [FocusOSShared.Task]
    @Query(sort: \FocusOSShared.Project.updatedAt, order: .reverse) private var allProjects: [FocusOSShared.Project]
    @Query(sort: \FocusOSShared.Note.updatedAt, order: .reverse) private var allNotes: [FocusOSShared.Note]
    
    enum ObjectType: String, CaseIterable {
        case none = "None"
        case task = "Task"
        case project = "Project"
        case note = "Note"
    }
    
    let durations: [(String, TimeInterval)] = [
        ("15 min", 900),
        ("30 min", 1800),
        ("45 min", 2700),
        ("1 hour", 3600),
        ("2 hours", 7200)
    ]
    
    let onSave: (String, TimeInterval, UUID?, String?, Bool) -> Void
    
    init(
        objective: Binding<String>,
        selectedDuration: Binding<TimeInterval>,
        reflectAfterSession: Binding<Bool>,
        initialTargetObjectId: UUID? = nil,
        initialTargetObjectType: String? = nil,
        onSave: @escaping (String, TimeInterval, UUID?, String?, Bool) -> Void
    ) {
        self._objective = objective
        self._selectedDuration = selectedDuration
        self._reflectAfterSession = reflectAfterSession
        self.initialTargetObjectId = initialTargetObjectId
        self.initialTargetObjectType = initialTargetObjectType
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Title
                    Text("Set Focus Objective")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Objective Title Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What will you focus on?")
                            .font(.headline)
                        
                        TextField("e.g., Write blog post on AI tools", text: $objective)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }
                    
                    // Linked Project/Task Picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Link to Entity (Optional)")
                            .font(.headline)
                        
                        Picker("Object Type", selection: $selectedObjectType) {
                            ForEach(ObjectType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        if selectedObjectType != .none {
                            objectPicker
                        }
                        
                        // Priority Display (if linked)
                        if let score = cpsScore {
                            HStack {
                                Text("Priority Score:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(Int(score * 100))%")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.kosmicBlue)
                            }
                            .padding(.top, 4)
                        }
                    }
                    
                    // Expected Duration
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Expected Duration")
                            .font(.headline)
                        
                        Picker("Duration", selection: $selectedDuration) {
                            ForEach(durations, id: \.1) { label, value in
                                Text(label).tag(value)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Reflect After Session Toggle
                    Toggle("Reflect After Session", isOn: $reflectAfterSession)
                        .font(.subheadline)
                }
                .padding(24)
            }
            .background(Color(.windowBackgroundColor))
            .navigationTitle("Set Objective")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start Session") {
                        saveObjective()
                    }
                    .disabled(objective.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(width: 600, height: 520)
        .onChange(of: selectedObjectType) { _, _ in
            updateCPSScore()
        }
        .onChange(of: selectedTaskId) { _, _ in
            updateCPSScore()
        }
        .onChange(of: selectedProjectId) { _, _ in
            updateCPSScore()
        }
        .onChange(of: selectedNoteId) { _, _ in
            updateCPSScore()
        }
    }
    
    // MARK: - Object Picker
    
    @ViewBuilder
    private var objectPicker: some View {
        ScrollView {
            VStack(spacing: 8) {
                switch selectedObjectType {
                case .task:
                    ForEach(filteredTasks) { task in
                        objectRow(
                            title: task.title,
                            isSelected: selectedTaskId == task.id,
                            action: {
                                selectedTaskId = task.id
                            }
                        ) {
                            Text(task.status.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                    }
                case .project:
                    ForEach(filteredProjects) { project in
                        objectRow(
                            title: project.title,
                            isSelected: selectedProjectId == project.id,
                            action: {
                                selectedProjectId = project.id
                            }
                        ) {
                            Text(project.status.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                    }
                case .note:
                    ForEach(filteredNotes) { note in
                        objectRow(
                            title: note.title,
                            isSelected: selectedNoteId == note.id,
                            action: {
                                selectedNoteId = note.id
                            }
                        ) {
                            if note.markdown.isEmpty {
                                Text("No preview")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                MentionRenderedTextView(
                                    text: note.markdown,
                                    textFont: .caption,
                                    mentionFont: .caption
                                )
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            }
                        }
                    }
                case .none:
                    EmptyView()
                }
            }
        }
        .frame(maxHeight: 200)
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private func objectRow<Subtitle: View>(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder subtitle: () -> Subtitle
    ) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    subtitle()
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.kosmicBlue)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.kosmicBlue.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var filteredTasks: [FocusOSShared.Task] {
        if searchText.isEmpty {
            return Array(allTasks.prefix(20))
        }
        return allTasks.filter { task in
            task.title.localizedCaseInsensitiveContains(searchText)
        }.prefix(20).map { $0 }
    }
    
    private var filteredProjects: [FocusOSShared.Project] {
        if searchText.isEmpty {
            return Array(allProjects.prefix(20))
        }
        return allProjects.filter { project in
            project.title.localizedCaseInsensitiveContains(searchText)
        }.prefix(20).map { $0 }
    }
    
    private var filteredNotes: [FocusOSShared.Note] {
        if searchText.isEmpty {
            return Array(allNotes.prefix(20))
        }
        return allNotes.filter { note in
            note.title.localizedCaseInsensitiveContains(searchText) ||
            note.markdown.localizedCaseInsensitiveContains(searchText)
        }.prefix(20).map { $0 }
    }
    
    // MARK: - Helpers
    
    private func updateCPSScore() {
        let objectId: UUID?
        let objectType: String?
        
        switch selectedObjectType {
        case .task:
            objectId = selectedTaskId
            objectType = "task"
        case .project:
            objectId = selectedProjectId
            objectType = "project"
        case .note:
            objectId = selectedNoteId
            objectType = "note"
        case .none:
            objectId = nil
            objectType = nil
        }
        
        if let id = objectId {
            cpsScore = PriorityEngine.shared.getScoreValue(for: id, modelContext: modelContext)
        } else {
            cpsScore = nil
        }
    }
    
    private func saveObjective() {
        let objectId: UUID?
        let objectType: String?
        
        switch selectedObjectType {
        case .task:
            objectId = selectedTaskId
            objectType = "task"
        case .project:
            objectId = selectedProjectId
            objectType = "project"
        case .note:
            objectId = selectedNoteId
            objectType = "note"
        case .none:
            objectId = nil
            objectType = nil
        }
        
        onSave(objective, selectedDuration, objectId, objectType, reflectAfterSession)
        dismiss()
    }
}

#Preview {
    FocusObjectiveDrawer(
        objective: .constant(""),
        selectedDuration: .constant(1800),
        reflectAfterSession: .constant(true),
        onSave: { _, _, _, _, _ in }
    )
    .modelContainer(for: [FocusOSShared.Task.self, FocusOSShared.Project.self, FocusOSShared.Note.self])
}

