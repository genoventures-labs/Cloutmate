//
//  FocusObjectiveDrawer.swift
//  Cloutmate
//
//  Focus Mode V2 - Objective Drawer
//

import SwiftUI
import SwiftData
import CloutmateShared

struct FocusObjectiveDrawer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Binding var objective: String
    @Binding var selectedDuration: TimeInterval
    @Binding var reflectAfterSession: Bool
    
    @State private var selectedObjectType: ObjectType = .none
    @State private var selectedTaskId: UUID?
    @State private var selectedProjectId: UUID?
    @State private var selectedNoteId: UUID?
    @State private var cpsScore: Double?
    @State private var searchText: String = ""
    
    @Query(sort: \CloutmateShared.Task.updatedAt, order: .reverse) private var allTasks: [CloutmateShared.Task]
    @Query(sort: \CloutmateShared.Project.updatedAt, order: .reverse) private var allProjects: [CloutmateShared.Project]
    @Query(sort: \CloutmateShared.Note.updatedAt, order: .reverse) private var allNotes: [CloutmateShared.Note]
    
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
                            subtitle: task.status.displayName,
                            isSelected: selectedTaskId == task.id,
                            action: {
                                selectedTaskId = task.id
                            }
                        )
                    }
                case .project:
                    ForEach(filteredProjects) { project in
                        objectRow(
                            title: project.title,
                            subtitle: project.status.displayName,
                            isSelected: selectedProjectId == project.id,
                            action: {
                                selectedProjectId = project.id
                            }
                        )
                    }
                case .note:
                    ForEach(filteredNotes) { note in
                        objectRow(
                            title: note.title,
                            subtitle: String(note.markdown.prefix(50)),
                            isSelected: selectedNoteId == note.id,
                            action: {
                                selectedNoteId = note.id
                            }
                        )
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
    private func objectRow(title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
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
    
    private var filteredTasks: [CloutmateShared.Task] {
        if searchText.isEmpty {
            return Array(allTasks.prefix(20))
        }
        return allTasks.filter { task in
            task.title.localizedCaseInsensitiveContains(searchText)
        }.prefix(20).map { $0 }
    }
    
    private var filteredProjects: [CloutmateShared.Project] {
        if searchText.isEmpty {
            return Array(allProjects.prefix(20))
        }
        return allProjects.filter { project in
            project.title.localizedCaseInsensitiveContains(searchText)
        }.prefix(20).map { $0 }
    }
    
    private var filteredNotes: [CloutmateShared.Note] {
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
    .modelContainer(for: [CloutmateShared.Task.self, CloutmateShared.Project.self, CloutmateShared.Note.self])
}

