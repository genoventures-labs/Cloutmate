//
//  TaskDetailDrawer.swift
//  FocusOS
//
//  Created by Assistant on 11/10/25.
//

import SwiftUI
import SwiftData
import FocusOSShared

struct TaskDraft: Equatable {
    var title: String
    var notes: String
    var status: TaskStatus
    var priority: TaskPriority
    var dueDate: Date?
    var projectId: UUID?
    var areaId: UUID?
    var effort: String?
    var linkedEntityIds: [UUID]
    var linkedEntityTypes: [String]
    
    init(
        title: String = "",
        notes: String = "",
        status: TaskStatus = .todo,
        priority: TaskPriority = .medium,
        dueDate: Date? = nil,
        projectId: UUID? = nil,
        areaId: UUID? = nil,
        effort: String? = nil,
        linkedEntityIds: [UUID] = [],
        linkedEntityTypes: [String] = []
    ) {
        self.title = title
        self.notes = notes
        self.status = status
        self.priority = priority
        self.dueDate = dueDate
        self.projectId = projectId
        self.areaId = areaId
        self.effort = effort
        self.linkedEntityIds = linkedEntityIds
        self.linkedEntityTypes = linkedEntityTypes
    }
    
    init(task: Task) {
        self.title = task.title
        self.notes = task.notes ?? ""
        self.status = task.status
        self.priority = task.priority
        self.dueDate = task.dueDate
        self.projectId = task.projectId
        self.areaId = task.areaId
        self.effort = task.effort
        self.linkedEntityIds = task.linkedEntityIds
        self.linkedEntityTypes = task.linkedEntityTypes
    }
    
    var canCommit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct TaskDetailDrawer: View {
    enum Mode {
        case create
        case edit
    }
    
    let mode: Mode
    let existingTask: Task?
    let initialDraft: TaskDraft
    @Binding var isPresented: Bool
    let onCommit: (TaskDraft) -> Void
    let onCancel: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @FocusState private var isTitleFocused: Bool
    @Query private var allProjects: [Project]
    @Query private var allAreas: [Area]
    
    @State private var draft: TaskDraft
    @State private var energyRequirement: EnergyRequirement?
    
    private var focusGravityIntensity: Double {
        guard mode == .edit, let task = existingTask else { return 0 }
        
        let daysSinceUpdate = Calendar.current.dateComponents([.day], from: task.updatedAt, to: Date()).day ?? 0
        let daysSinceCreation = Calendar.current.dateComponents([.day], from: task.createdAt, to: Date()).day ?? 1
        
        let recencyScore = max(0, 1.0 - (Double(daysSinceUpdate) / 30.0))
        let updateFrequency = Double(daysSinceCreation) > 0 ? Double(task.notes?.count ?? 0) / Double(daysSinceCreation) : 0.0
        let frequencyScore = min(1.0, updateFrequency / 100.0)
        
        return (recencyScore + frequencyScore) / 2.0
    }
    
    private var accentGradient: LinearGradient {
        let intensity = mode == .edit ? max(0.2, focusGravityIntensity) : 0.25
        return LinearGradient(
            colors: [
                Color.kosmicBlue.opacity(0.4 + 0.4 * intensity),
                Color.kosmicPurple.opacity(0.3 + 0.3 * intensity)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    init(
        mode: Mode,
        existingTask: Task?,
        initialDraft: TaskDraft,
        isPresented: Binding<Bool>,
        onCommit: @escaping (TaskDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.mode = mode
        self.existingTask = existingTask
        self.initialDraft = initialDraft
        self._isPresented = isPresented
        self.onCommit = onCommit
        self.onCancel = onCancel
        _draft = State(initialValue: initialDraft)
    }
    
    var body: some View {
        NavigationStack {
            V2DrawerScaffold(
                accentGradient: accentGradient,
                showsSidebar: false,
                header: { headerContent },
                content: {
                    notesSection
                    detailsSection
                    associationsSection
                },
                sidebar: { EmptyView() }
            )
            .frame(minWidth: 680, minHeight: 540)
            .frame(idealWidth: 860, idealHeight: 640)
            .navigationTitle("")
        }
        .onEscape { cancel() }
        .frame(minWidth: 600, minHeight: 500)
        .frame(idealWidth: 800, idealHeight: 600)
        .onAppear {
            energyRequirement = nil
            
            if draft.title.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTitleFocused = true
                }
            }
        }
        .onChange(of: isPresented) { _, newValue in
            if !newValue {
                draft = initialDraft
            }
        }
    }
    
    // MARK: - Sections
    
    private var headerContent: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Task Title", text: $draft.title)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.semibold)
                    .textFieldStyle(.plain)
                    .focused($isTitleFocused)
                    .drawerFocusGlow()
                
                HStack(spacing: 12) {
                    metadataPill(title: draft.status.displayName, icon: "checkmark.circle")
                    metadataPill(title: draft.priority.displayName, icon: "flag.fill")
                    
                    if let dueDate = draft.dueDate {
                        metadataPill(
                            title: dueDate.formatted(date: .abbreviated, time: .omitted),
                            icon: "calendar"
                        )
                    }
                }
            }
            
            Spacer(minLength: 24)
            
            HStack(spacing: 12) {
                GlassButton(
                    "Cancel",
                    icon: "xmark",
                    style: .standard,
                    role: .surface
                ) {
                    cancel()
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                GlassButton(
                    mode == .create ? "Create Task" : "Save Changes",
                    icon: "tray.and.arrow.down.fill",
                    style: .standard,
                    role: .primary
                ) {
                    commit()
                }
                .disabled(!draft.canCommit)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
    }
    
    private func metadataPill(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.12))
        .clipShape(Capsule())
    }
    
    private var notesSection: some View {
        DrawerSection(title: "Notes", icon: "doc.richtext") {
            MentionTextEditor(
                text: Binding(
                    get: { draft.notes },
                    set: { newValue in
                        draft.notes = newValue
                    }
                ),
                placeholder: "Add notes...",
                excludeObjectId: mode == .edit ? existingTask?.id : nil,
                excludeObjectType: mode == .edit ? .task : nil
            ) { ids, types in
                draft.linkedEntityIds = ids
                draft.linkedEntityTypes = types
            }
            .frame(minHeight: 200)
            .drawerFocusGlow()
        }
    }
    
    private var detailsSection: some View {
        DrawerSection(title: "Details", icon: "slider.horizontal.3") {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 18) {
                GridRow {
                    detailField(title: "Status", icon: "checkmark.circle") {
                        Picker("Status", selection: $draft.status) {
                            ForEach(TaskStatus.allCases, id: \.self) { status in
                                Text(status.displayName).tag(status)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    detailField(title: "Priority", icon: "flag.fill") {
                        Picker("Priority", selection: $draft.priority) {
                            ForEach(TaskPriority.allCases, id: \.self) { priority in
                                Text(priority.displayName).tag(priority)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                GridRow {
                    detailField(title: "Due Date", icon: "calendar") {
                        Toggle(isOn: Binding(
                            get: { draft.dueDate != nil },
                            set: { newValue in
                                draft.dueDate = newValue ? (draft.dueDate ?? Date()) : nil
                            }
                        )) {
                            Text(draft.dueDate != nil ? "Enabled" : "Off")
                                .font(.subheadline.weight(.semibold))
                        }
                        .toggleStyle(.switch)
                        
                        if let dueDate = draft.dueDate {
                            DatePicker(
                                "Due date",
                                selection: Binding(
                                    get: { dueDate },
                                    set: { newValue in draft.dueDate = newValue }
                                ),
                                displayedComponents: .date
                            )
                            .labelsHidden()
                        }
                    }
                    
                    detailField(title: "Effort", icon: "timer") {
                        Picker("Effort", selection: Binding(
                            get: { draft.effort ?? "" },
                            set: { newValue in
                                draft.effort = newValue.isEmpty ? nil : newValue
                            }
                        )) {
                            Text("None").tag("")
                            Text("Small").tag("small")
                            Text("Medium").tag("medium")
                            Text("Large").tag("large")
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                if mode == .create {
                    GridRow {
                        detailField(title: "Energy Requirement", icon: "bolt.fill") {
                            Picker("Energy Requirement", selection: $energyRequirement) {
                                Text("None").tag(EnergyRequirement?.none)
                                ForEach(EnergyRequirement.allCases, id: \.self) { energy in
                                    Text(energy.displayName).tag(energy as EnergyRequirement?)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            if let energyRequirement {
                                HStack(spacing: 8) {
                                    Image(systemName: energyIcon(for: energyRequirement))
                                        .foregroundColor(energyColor(for: energyRequirement))
                                    Text(energyRequirement.displayName)
                                        .font(.caption)
                                        .foregroundColor(glassColorSystem.textSecondary())
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(energyColor(for: energyRequirement).opacity(0.12))
                                .cornerRadius(8)
                            }
                        }
                        .gridCellColumns(2)
                    }
                }
            }
        }
    }
    
    private var associationsSection: some View {
        DrawerSection(title: "Associations", icon: "link") {
            VStack(alignment: .leading, spacing: 16) {
                if !allProjects.isEmpty {
                    detailField(title: "Project", icon: "folder.fill") {
                        Picker("Project", selection: Binding(
                            get: { draft.projectId },
                            set: { newValue in
                                draft.projectId = newValue
                            }
                        )) {
                            Text("None").tag(UUID?.none)
                            ForEach(allProjects) { project in
                                Text(project.title).tag(project.id as UUID?)
                            }
                        }
                        .labelsHidden()
                    }
                }
                
                if !allAreas.isEmpty {
                    detailField(title: "Area", icon: "rectangle.stack.fill") {
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
                        .labelsHidden()
                    }
                }
            }
        }
    }
    
    private func detailField<Content: View>(
        title: String,
        icon: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            
            content()
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
    
    private func cancel() {
        onCancel()
        isPresented = false
    }
    
    private func commit() {
        guard draft.canCommit else { return }
        onCommit(draft)
        isPresented = false
    }
}

struct TaskDetailDrawer_Previews: PreviewProvider {
    static var previews: some View {
        TaskDetailDrawer(
            mode: .edit,
            existingTask: Task(title: "Draft blog outline"),
            initialDraft: TaskDraft(task: Task(title: "Draft blog outline")),
            isPresented: .constant(true),
            onCommit: { _ in },
            onCancel: {}
        )
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [Task.self, Project.self, Area.self])
    }
}
//

