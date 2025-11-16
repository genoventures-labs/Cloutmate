//
//  ProjectDetailDrawer.swift
//  Cloutmate
//
//  Created by Assistant on 11/10/25.
//

import SwiftUI
import SwiftData
import CloutmateShared

struct ProjectDraft: Equatable {
    var title: String
    var goal: String
    var status: ProjectStatus
    var dueDate: Date?
    var areaId: UUID?
    var tags: [String]
    var linkedEntityIds: [UUID]
    var linkedEntityTypes: [String]
    
    init(
        title: String = "",
        goal: String = "",
        status: ProjectStatus = .active,
        dueDate: Date? = nil,
        areaId: UUID? = nil,
        tags: [String] = [],
        linkedEntityIds: [UUID] = [],
        linkedEntityTypes: [String] = []
    ) {
        self.title = title
        self.goal = goal
        self.status = status
        self.dueDate = dueDate
        self.areaId = areaId
        self.tags = tags
        self.linkedEntityIds = linkedEntityIds
        self.linkedEntityTypes = linkedEntityTypes
    }
    
    init(project: Project) {
        self.title = project.title
        self.goal = project.goal ?? ""
        self.status = project.status
        self.dueDate = project.dueDate
        self.areaId = project.areaId
        self.tags = project.tags
        self.linkedEntityIds = project.linkedEntityIds
        self.linkedEntityTypes = project.linkedEntityTypes
    }
    
    var canCommit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct ProjectDetailDrawer: View {
    enum Mode {
        case create
        case edit
    }
    
    let mode: Mode
    let existingProject: Project?
    let initialDraft: ProjectDraft
    @Binding var isPresented: Bool
    let onCommit: (ProjectDraft) -> Void
    let onCancel: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @FocusState private var isTitleFocused: Bool
    @Query private var allAreas: [Area]
    
    @State private var draft: ProjectDraft
    @State private var tagsText: String
    @State private var hasDueDate: Bool
    @State private var energyRequirement: EnergyRequirement?
    
    private var focusGravityIntensity: Double {
        guard mode == .edit, let project = existingProject else { return 0 }
        
        let daysSinceUpdate = Calendar.current.dateComponents([.day], from: project.updatedAt, to: Date()).day ?? 0
        let daysSinceCreation = Calendar.current.dateComponents([.day], from: project.createdAt, to: Date()).day ?? 1
        
        let recencyScore = max(0, 1.0 - (Double(daysSinceUpdate) / 30.0))
        let updateFrequency = Double(daysSinceCreation) > 0 ? Double(project.goal?.count ?? 0) / Double(daysSinceCreation) : 0.0
        let frequencyScore = min(1.0, updateFrequency / 100.0)
        
        return (recencyScore + frequencyScore) / 2.0
    }
    
    private var accentGradient: LinearGradient {
        let intensity = mode == .edit ? max(0.2, focusGravityIntensity) : 0.25
        return LinearGradient(
            colors: [
                Color.kosmicBlue.opacity(0.45 + 0.35 * intensity),
                Color.kosmicPurple.opacity(0.35 + 0.3 * intensity)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    init(
        mode: Mode,
        existingProject: Project?,
        initialDraft: ProjectDraft,
        isPresented: Binding<Bool>,
        onCommit: @escaping (ProjectDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.mode = mode
        self.existingProject = existingProject
        self.initialDraft = initialDraft
        self._isPresented = isPresented
        self.onCommit = onCommit
        self.onCancel = onCancel
        _draft = State(initialValue: initialDraft)
        _tagsText = State(initialValue: initialDraft.tags.joined(separator: ", "))
        _hasDueDate = State(initialValue: initialDraft.dueDate != nil)
    }
    
    var body: some View {
        NavigationStack {
            V2DrawerScaffold(
                accentGradient: accentGradient,
                showsSidebar: false,
                header: { headerContent },
                content: {
                    goalSection
                    statusSection
                    areaSection
                    dueDateSection
                    tagsSection
                    if mode == .create {
                        energyRequirementSection
                    }
                },
                sidebar: { EmptyView() }
            )
            .frame(minWidth: 680, minHeight: 540)
            .frame(idealWidth: 860, idealHeight: 640)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cancel()
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        commit()
                    }
                    .keyboardShortcut(.return, modifiers: [])
                    .disabled(!draft.canCommit)
                }
            }
        }
        .onEscape { cancel() }
        .frame(minWidth: 600, minHeight: 500)
        .frame(idealWidth: 800, idealHeight: 600)
        .onAppear {
            if draft.title.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTitleFocused = true
                }
            }
        }
        .onChange(of: tagsText) { _, newValue in
            draft.tags = parseTags(from: newValue)
        }
        .onChange(of: hasDueDate) { _, newValue in
            if !newValue {
                draft.dueDate = nil
            } else {
                draft.dueDate = draft.dueDate ?? Date()
            }
        }
        .onChange(of: isPresented) { _, newValue in
            if !newValue {
                draft = initialDraft
                tagsText = initialDraft.tags.joined(separator: ", ")
                hasDueDate = initialDraft.dueDate != nil
            }
        }
    }
    
    // MARK: - Sections
    
    private var headerContent: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Project Title", text: $draft.title)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.semibold)
                    .textFieldStyle(.plain)
                    .focused($isTitleFocused)
                    .drawerFocusGlow()
                
                HStack(spacing: 12) {
                    Label(draft.status.displayName, systemImage: "chart.bar.doc.horizontal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    let tagCount = draft.tags.count
                    if tagCount > 0 {
                        Label("\(tagCount) tag\(tagCount == 1 ? "" : "s")", systemImage: "number")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if hasDueDate, let dueDate = draft.dueDate {
                        Label(dueDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                GlassButton(
                    "Save",
                    icon: "tray.and.arrow.down.fill",
                    style: .standard,
                    role: .primary
                ) {
                    commit()
                }
                .disabled(!draft.canCommit)
                
                GlassButton(
                    "Cancel",
                    icon: "xmark",
                    style: .standard,
                    role: .surface
                ) {
                    cancel()
                }
            }
        }
    }
    
    private var goalSection: some View {
        DrawerSection(title: "Goal / Description", icon: "doc.richtext") {
            MentionTextEditor(
                text: Binding(
                    get: { draft.goal },
                    set: { newValue in
                        draft.goal = newValue
                    }
                ),
                placeholder: "Describe the project...",
                excludeObjectId: mode == .edit ? existingProject?.id : nil,
                excludeObjectType: mode == .edit ? .project : nil
            ) { ids, types in
                draft.linkedEntityIds = ids
                draft.linkedEntityTypes = types
            }
            .frame(minHeight: 220)
            .drawerFocusGlow()
        }
    }
    
    private var statusSection: some View {
        DrawerSection(title: "Status", icon: "chart.bar") {
            Picker("Status", selection: $draft.status) {
                ForEach(ProjectStatus.allCases, id: \.self) { status in
                    Text(status.displayName).tag(status)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    @ViewBuilder
    private var areaSection: some View {
        if !allAreas.isEmpty {
            DrawerSection(title: "Area", icon: "rectangle.stack.fill") {
                Picker("Area", selection: Binding(
                    get: { draft.areaId },
                    set: { newValue in
                        draft.areaId = newValue
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
        DrawerSection(title: "Due Date", icon: "calendar") {
            Toggle("Set Due Date", isOn: $hasDueDate)
            
            if hasDueDate, let dueDate = draft.dueDate {
                DatePicker(
                    "Due Date",
                    selection: Binding(
                        get: { dueDate },
                        set: { newValue in
                            draft.dueDate = newValue
                        }
                    ),
                    displayedComponents: .date
                )
            }
        }
    }
    
    private var tagsSection: some View {
        DrawerSection(title: "Tags", icon: "tag.fill", subtitle: "Use commas to separate tags") {
            TextField("e.g., work, priority", text: $tagsText)
                .textFieldStyle(.plain)
                .drawerFocusGlow()
        }
    }
    
    private var energyRequirementSection: some View {
        DrawerSection(title: "Energy Requirement", icon: "bolt.fill") {
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
    
    private func parseTags(from input: String) -> [String] {
        input
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    // MARK: - Actions
    
    private func cancel() {
        onCancel()
        isPresented = false
    }
    
    private func commit() {
        guard draft.canCommit else { return }
        draft.tags = parseTags(from: tagsText)
        onCommit(draft)
        isPresented = false
    }
}

struct ProjectDetailDrawer_Previews: PreviewProvider {
    static var previews: some View {
        ProjectDetailDrawer(
            mode: .edit,
            existingProject: Project(title: "Launch Campaign"),
            initialDraft: ProjectDraft(project: Project(title: "Launch Campaign")),
            isPresented: .constant(true),
            onCommit: { _ in },
            onCancel: {}
        )
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [Project.self, Area.self])
    }
}
//
