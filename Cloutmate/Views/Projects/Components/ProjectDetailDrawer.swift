//
//  ProjectDetailDrawer.swift
//  Cloutmate
//
//  Created by Assistant on 11/10/25.
//

import SwiftUI
import SwiftData
import CloutmateShared

struct ProjectDetailDrawer: View {
    enum Mode {
        case create
        case edit
    }
    
    @Bindable var project: Project
    @Binding var isPresented: Bool
    let mode: Mode
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @FocusState private var isTitleFocused: Bool
    @Query private var allAreas: [Area]
    
    @State private var tagsText: String = ""
    @State private var hasDueDate: Bool = false
    @State private var energyRequirement: EnergyRequirement?
    
    private var isCreation: Bool {
        mode == .create
    }
    
    private var focusGravityIntensity: Double {
        guard mode == .edit else { return 0 }
        
        let daysSinceUpdate = Calendar.current.dateComponents([.day], from: project.updatedAt, to: Date()).day ?? 0
        let daysSinceCreation = Calendar.current.dateComponents([.day], from: project.createdAt, to: Date()).day ?? 1
        
        let recencyScore = max(0, 1.0 - (Double(daysSinceUpdate) / 30.0))
        let updateFrequency = Double(daysSinceCreation) > 0 ? Double(project.goal?.count ?? 0) / Double(daysSinceCreation) : 0.0
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
                            goalSection
                            statusSection
                            areaSection
                            dueDateSection
                            tagsSection
                            
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
            tagsText = project.tags.joined(separator: ", ")
            hasDueDate = project.dueDate != nil
            
            if project.title.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTitleFocused = true
                }
            }
        }
        .onDisappear {
            guard mode == .create else { return }
            let trimmedTitle = project.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedGoal = (project.goal ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedTitle.isEmpty && trimmedGoal.isEmpty {
                modelContext.delete(project)
                try? modelContext.save()
            }
        }
    }
    
    // MARK: - Sections
    
    private var header: some View {
        HStack(spacing: 12) {
            TextField("Project Title", text: $project.title)
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .textFieldStyle(.plain)
                .focused($isTitleFocused)
                .onChange(of: project.title) { _, _ in
                    project.updatedAt = Date()
                }
            
            Spacer()
        }
    }
    
    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Goal / Description")
                .font(.caption)
                .foregroundColor(.secondary)
            
            MentionTextEditor(
                text: Binding(
                    get: { project.goal ?? "" },
                    set: { newValue in
                        project.goal = newValue.isEmpty ? nil : newValue
                        project.updatedAt = Date()
                    }
                ),
                placeholder: "Describe the project...",
                excludeObjectId: mode == .edit ? project.id : nil,
                excludeObjectType: mode == .edit ? .project : nil
            ) { ids, types in
                project.linkedEntityIds = ids
                project.linkedEntityTypes = types
                project.updatedAt = Date()
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
            
            Picker("Status", selection: $project.status) {
                ForEach(ProjectStatus.allCases, id: \.self) { status in
                    Text(status.displayName).tag(status)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: project.status) { _, _ in
                project.updatedAt = Date()
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
                    get: { project.areaId },
                    set: { newValue in
                        project.areaId = newValue
                        project.updatedAt = Date()
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
    
    private var dueDateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Set Due Date", isOn: Binding(
                get: { project.dueDate != nil },
                set: { newValue in
                    hasDueDate = newValue
                    if newValue {
                        project.dueDate = project.dueDate ?? Date()
                    } else {
                        project.dueDate = nil
                    }
                    project.updatedAt = Date()
                }
            ))
            
            if let dueDate = project.dueDate {
                DatePicker(
                    "Due Date",
                    selection: Binding(
                        get: { dueDate },
                        set: { newValue in
                            project.dueDate = newValue
                            project.updatedAt = Date()
                        }
                    ),
                    displayedComponents: .date
                )
            }
        }
    }
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags (comma separated)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextField("e.g., work, priority", text: $tagsText)
                .textFieldStyle(.plain)
                .padding(8)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .onChange(of: tagsText) { _, newValue in
                    let parsed = newValue
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    project.tags = parsed
                    project.updatedAt = Date()
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
                HStack(spacing: 8) {
                    Image(systemName: energyIcon(for: energyRequirement))
                        .foregroundColor(energyColor(for: energyRequirement))
                    Text(energyRequirement.displayName)
                        .font(.subheadline)
                        .foregroundColor(glassColorSystem.textSecondary())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(energyColor(for: energyRequirement).opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    private func energyIcon(for energy: EnergyRequirement) -> String {
        switch energy {
        case .deep:
            return "brain.head.profile"
        case .shallow:
            return "bolt.fill"
        case .creative:
            return "sparkles"
        case .admin:
            return "doc.text"
        }
    }
    
    private func energyColor(for energy: EnergyRequirement) -> Color {
        switch energy {
        case .deep:
            return .kosmicPurple
        case .shallow:
            return .kosmicBlue
        case .creative:
            return .orange
        case .admin:
            return .kosmicGreen
        }
    }
    
    // MARK: - Actions
    
    private func closeDrawer() {
        let trimmedTitle = project.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            project.title = "Untitled Project"
        }
        project.updatedAt = Date()
        try? modelContext.save()
        isPresented = false
    }
}

