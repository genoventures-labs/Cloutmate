//
//  TaskDetailDrawer.swift
//  Cloutmate
//
//  Created by Assistant on 11/10/25.
//

import SwiftUI
import SwiftData
import CloutmateShared

struct TaskDetailDrawer: View {
    enum Mode {
        case create
        case edit
    }
    
    @Bindable var task: Task
    @Binding var isPresented: Bool
    let mode: Mode
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @FocusState private var isTitleFocused: Bool
    @Query private var allProjects: [Project]
    @Query private var allAreas: [Area]
    
    @State private var energyRequirement: EnergyRequirement?
    
    private var isCreation: Bool {
        mode == .create
    }
    
    private var focusGravityIntensity: Double {
        guard mode == .edit else { return 0 }
        
        let daysSinceUpdate = Calendar.current.dateComponents([.day], from: task.updatedAt, to: Date()).day ?? 0
        let daysSinceCreation = Calendar.current.dateComponents([.day], from: task.createdAt, to: Date()).day ?? 1
        
        let recencyScore = max(0, 1.0 - (Double(daysSinceUpdate) / 30.0))
        let updateFrequency = Double(daysSinceCreation) > 0 ? Double(task.notes?.count ?? 0) / Double(daysSinceCreation) : 0.0
        let frequencyScore = min(1.0, updateFrequency / 100.0)
        
        return (recencyScore + frequencyScore) / 2.0
    }
    
    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                if mode == .edit {
                    RoundedRectangle(cornerRadius: 0, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .kosmicBlue.opacity(focusGravityIntensity),
                                    .kosmicPurple.opacity(focusGravityIntensity * 0.8)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 4)
                }
                
                VStack(spacing: 0) {
                    header
                        .padding()
                        .background(.ultraThinMaterial)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            notesSection
                            statusSection
                            prioritySection
                            dueDateSection
                            projectSection
                            areaSection
                            effortSection
                            
                            if mode == .create {
                                energyRequirementSection
                            }
                        }
                        .padding()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(glassColorSystem.backgroundColor())
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        closeDrawer()
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
            if mode == .create {
                energyRequirement = nil
            }
            
            if task.title.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTitleFocused = true
                }
            }
        }
        .onDisappear {
            guard mode == .create else { return }
            let trimmedTitle = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedNotes = (task.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedTitle.isEmpty && trimmedNotes.isEmpty {
                modelContext.delete(task)
                try? modelContext.save()
            }
        }
    }
    
    // MARK: - Sections
    
    private var header: some View {
        HStack(spacing: 12) {
            TextField("Task Title", text: $task.title)
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .textFieldStyle(.plain)
                .focused($isTitleFocused)
                .onChange(of: task.title) { _, _ in
                    task.updatedAt = Date()
                }
            
            Spacer()
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.caption)
                .foregroundColor(.secondary)
            
            MentionTextEditor(
                text: Binding(
                    get: { task.notes ?? "" },
                    set: { newValue in
                        task.notes = newValue.isEmpty ? nil : newValue
                        task.updatedAt = Date()
                    }
                ),
                placeholder: "Add notes..."
            ) { ids, types in
                task.linkedEntityIds = ids
                task.linkedEntityTypes = types
                task.updatedAt = Date()
            }
            .frame(minHeight: 200)
            .padding(8)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
        }
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Picker("Status", selection: $task.status) {
                ForEach(TaskStatus.allCases, id: \.self) { status in
                    Text(status.displayName).tag(status)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Priority")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Picker("Priority", selection: $task.priority) {
                ForEach(TaskPriority.allCases, id: \.self) { priority in
                    Text(priority.displayName).tag(priority)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var dueDateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Set Due Date", isOn: Binding(
                get: { task.dueDate != nil },
                set: { newValue in
                    if newValue {
                        task.dueDate = task.dueDate ?? Date()
                    } else {
                        task.dueDate = nil
                    }
                    task.updatedAt = Date()
                }
            ))
            
            if let dueDate = task.dueDate {
                DatePicker(
                    "Due Date",
                    selection: Binding(
                        get: { dueDate },
                        set: { newValue in
                            task.dueDate = newValue
                            task.updatedAt = Date()
                        }
                    ),
                    displayedComponents: .date
                )
            }
        }
    }
    
    private var projectSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if allProjects.isEmpty {
                EmptyView()
            } else {
                Text("Project")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Project", selection: Binding(
                    get: { task.projectId },
                    set: { newValue in
                        task.projectId = newValue
                        task.updatedAt = Date()
                    }
                )) {
                    Text("None").tag(UUID?.none)
                    ForEach(allProjects) { project in
                        Text(project.title).tag(project.id as UUID?)
                    }
                }
            }
        }
    }
    
    private var areaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if allAreas.isEmpty {
                EmptyView()
            } else {
                Text("Area")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Area", selection: Binding(
                    get: { task.areaId },
                    set: { newValue in
                        task.areaId = newValue
                        task.updatedAt = Date()
                    }
                )) {
                    Text("None").tag(UUID?.none)
                    ForEach(allAreas) { area in
                        Text(area.title).tag(area.id as UUID?)
                    }
                }
            }
        }
    }
    
    private var effortSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Effort")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Picker("Effort", selection: Binding(
                get: { task.effort ?? "" },
                set: { newValue in
                    task.effort = newValue.isEmpty ? nil : newValue
                    task.updatedAt = Date()
                }
            )) {
                Text("None").tag("")
                Text("Small").tag("small")
                Text("Medium").tag("medium")
                Text("Large").tag("large")
            }
        }
    }
    
    private var energyRequirementSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Energy Requirement")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Picker("Energy Requirement", selection: $energyRequirement) {
                Text("None").tag(EnergyRequirement?.none)
                ForEach(EnergyRequirement.allCases, id: \.self) { energy in
                    Text(energy.displayName).tag(energy as EnergyRequirement?)
                }
            }
            
            if let energyRequirement {
                EnergyRequirementIndicator(energyRequirement: energyRequirement)
            }
        }
    }
    
    // MARK: - Actions
    
    private func closeDrawer() {
        let trimmedTitle = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            task.title = "Untitled Task"
        }
        task.updatedAt = Date()
        try? modelContext.save()
        isPresented = false
    }
}

