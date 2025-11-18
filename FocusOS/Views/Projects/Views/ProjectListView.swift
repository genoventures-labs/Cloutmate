//
//  ProjectListView.swift
//  FocusOS
//
//  List view for Projects with compact GlassCards and Focus Gravity bars
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import FocusOSShared

struct ProjectListView: View {
    let projects: [Project]
    let tasks: [Task]
    let areas: [Area]
    let selectionMode: Bool
    let selectedProjectIDs: Set<UUID>
    let onSelectionToggle: (Project) -> Void
    let onProjectDetail: (Project) -> Void
    let onProjectEdit: (Project) -> Void
    let onDuplicateProject: (Project) -> Void
    let onArchiveProject: (Project) -> Void
    let onDeleteProject: (Project) -> Void
    let onReorderProjects: ([Project]) -> Void
    let onMoveProjectToStatus: (Project, ProjectStatus) -> Void
    let fetchProjectByID: (UUID) -> Project?
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @State private var orderedProjects: [Project]
    @State private var draggingProjectID: UUID?
    @State private var dropTargetProjectID: UUID?
    @State private var dropTargetStatus: ProjectStatus?
    
    init(
        projects: [Project],
        tasks: [Task],
        areas: [Area],
        selectionMode: Bool,
        selectedProjectIDs: Set<UUID>,
        onSelectionToggle: @escaping (Project) -> Void,
        onProjectDetail: @escaping (Project) -> Void,
        onProjectEdit: @escaping (Project) -> Void,
        onDuplicateProject: @escaping (Project) -> Void,
        onArchiveProject: @escaping (Project) -> Void,
        onDeleteProject: @escaping (Project) -> Void,
        onReorderProjects: @escaping ([Project]) -> Void,
        onMoveProjectToStatus: @escaping (Project, ProjectStatus) -> Void,
        fetchProjectByID: @escaping (UUID) -> Project?
    ) {
        self.projects = projects
        self.tasks = tasks
        self.areas = areas
        self.selectionMode = selectionMode
        self.selectedProjectIDs = selectedProjectIDs
        self.onSelectionToggle = onSelectionToggle
        self.onProjectDetail = onProjectDetail
        self.onProjectEdit = onProjectEdit
        self.onDuplicateProject = onDuplicateProject
        self.onArchiveProject = onArchiveProject
        self.onDeleteProject = onDeleteProject
        self.onReorderProjects = onReorderProjects
        self.onMoveProjectToStatus = onMoveProjectToStatus
        self.fetchProjectByID = fetchProjectByID
        _orderedProjects = State(initialValue: projects)
    }
    
    var body: some View {
        if projects.isEmpty {
            emptyState
        } else {
            VStack(spacing: 18) {
                if draggingProjectID != nil {
                    statusDropTargets
                }
                
            LazyVStack(spacing: 12) {
                    projectCards
                }
                .onDrop(
                    of: [.text],
                    delegate: ProjectListDropDelegate(
                        targetProject: nil,
                        projects: $orderedProjects,
                        draggingProjectID: $draggingProjectID,
                        dropTargetProjectID: $dropTargetProjectID,
                        fetchProject: fetchProjectByID,
                        onReorder: { reordered in
                            orderedProjects = reordered
                            onReorderProjects(reordered)
                        }
                    )
                )
            }
            .onChange(of: projects.map(\.id)) { _ in
                orderedProjects = projects
            }
        }
    }
    
    private var projectCards: some View {
        ForEach(orderedProjects, id: \.id) { project in
            projectCard(for: project)
        }
    }
    
    private func projectCard(for project: Project) -> some View {
        let projectTasks = tasks.filter { $0.projectId == project.id }
        let isSelected = selectedProjectIDs.contains(project.id)
        let isDragged = draggingProjectID == project.id
        let isDropHighlight = dropTargetProjectID == project.id
        
        return ProjectListCard(
                        project: project,
            tasks: projectTasks,
                        areas: areas,
                        selectionMode: selectionMode,
            isSelected: isSelected,
                        onSelectionToggle: { onSelectionToggle(project) },
                        onOpenDetail: { onProjectDetail(project) },
                        onEdit: { onProjectEdit(project) },
                        onDuplicate: { onDuplicateProject(project) },
                        onArchive: { onArchiveProject(project) },
            onDelete: { onDeleteProject(project) },
            isBeingDragged: isDragged,
            isDropTarget: isDropHighlight
                    )
                    .accessibilityLabel("Project: \(project.title)")
                    .accessibilityHint("Double tap to open. Press Enter to view details.")
                    .accessibilityAddTraits(.isButton)
        .onDrag {
            draggingProjectID = project.id
            dropTargetProjectID = project.id
            return NSItemProvider(object: project.id.uuidString as NSString)
        }
        .onDrop(
            of: [.text],
            delegate: ProjectListDropDelegate(
                targetProject: project,
                projects: $orderedProjects,
                draggingProjectID: $draggingProjectID,
                dropTargetProjectID: $dropTargetProjectID,
                fetchProject: fetchProjectByID,
                onReorder: { reordered in
                    orderedProjects = reordered
                    onReorderProjects(reordered)
                }
            )
        )
    }
    
    private var statusDropTargets: some View {
        HStack(spacing: 12) {
            ForEach(ProjectStatus.allCases, id: \.self) { status in
                statusChip(for: status)
            }
        }
        .padding(.horizontal, 4)
        .animation(.easeInOut(duration: 0.2), value: dropTargetStatus)
    }
    
    private func statusChip(for status: ProjectStatus) -> some View {
        let isActive = dropTargetStatus == status
        return Label(status.displayName, systemImage: statusIcon(for: status))
            .font(.system(.caption, design: .rounded).weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isActive ? glassColorSystem.emotionalAccent().opacity(0.22) : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(glassColorSystem.emotionalAccent().opacity(isActive ? 0.6 : 0.2), lineWidth: 1)
            )
            .onDrop(
                of: [.text],
                delegate: ProjectStatusDropDelegate(
                    status: status,
                    projects: $orderedProjects,
                    draggingProjectID: $draggingProjectID,
                    dropTargetStatus: $dropTargetStatus,
                    fetchProject: fetchProjectByID,
                    onMoveToStatus: onMoveProjectToStatus,
                    onReorder: { reordered in
                        orderedProjects = reordered
                        onReorderProjects(reordered)
                    }
                )
            )
    }
    
    private func statusIcon(for status: ProjectStatus) -> String {
        switch status {
        case .active: return "play.fill"
        case .paused: return "pause.fill"
        case .completed: return "checkmark.seal.fill"
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No projects")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Create your first project to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Project List Card

struct ProjectListCard: View {
    @Bindable var project: Project
    let tasks: [Task]
    let areas: [Area]
    let selectionMode: Bool
    let isSelected: Bool
    let onSelectionToggle: () -> Void
    let onOpenDetail: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void
    var isBeingDragged: Bool = false
    var isDropTarget: Bool = false
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var isHovered = false
    @State private var isExpanded = false
    @State private var focusMetrics: ProjectFocusMetrics?
    @State private var showFocusDurationSheet = false
    @State private var focusDuration: TimeInterval = 1800 // Default 30 min
    
    var completedTasksCount: Int {
        tasks.filter { $0.status == .done }.count
    }
    
    var totalTasksCount: Int {
        tasks.count
    }
    
    var completionPercentage: Double {
        guard totalTasksCount > 0 else { return 0.0 }
        return Double(completedTasksCount) / Double(totalTasksCount)
    }
    
    var isActiveToday: Bool {
        guard let lastActive = focusMetrics?.lastActiveAt else { return false }
        return Calendar.current.isDateInToday(lastActive)
    }
    
    var area: Area? {
        guard let areaId = project.areaId else { return nil }
        return areas.first { $0.id == areaId }
    }
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 22) {
            VStack(spacing: 0) {
                headerRow
                    .padding(.horizontal, 24)
                    .padding(.top, 22)
                    .padding(.bottom, showProgressSection || isExpanded ? 18 : 22)
                
                if showProgressSection {
                    progressSection
                }
                
                if isExpanded {
                    expandedSection
                }
            }
        }
        .overlay(alignment: .leading) {
            focusAccentBar
        }
        .overlay(alignment: .topTrailing) {
            if selectionMode {
                SelectionIndicator(isSelected: isSelected)
                    .padding(.top, 18)
                    .padding(.trailing, 18)
                    .onTapGesture {
                        onSelectionToggle()
                    }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(selectionBorderGradient, lineWidth: isSelected ? 1.8 : 0.8)
                .opacity(isSelected ? 1.0 : 0.55)
        )
        .overlay {
            if isActiveToday && !reduceMotion {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(activeHighlightGradient, lineWidth: 1.2)
                    .blur(radius: 6)
                    .opacity(0.65)
                    .allowsHitTesting(false)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(glassColorSystem.emotionalAccent().opacity(isDropTarget ? 0.85 : 0),
                        lineWidth: isDropTarget ? 1.6 : 0)
                .shadow(color: glassColorSystem.emotionalAccent().opacity(isDropTarget ? 0.45 : 0),
                        radius: isDropTarget ? 18 : 0,
                        x: 0,
                        y: isDropTarget ? 10 : 0)
                .animation(.easeInOut(duration: 0.16), value: isDropTarget)
        )
        .shadow(color: Color.black.opacity(isBeingDragged ? 0.18 : (isHovered ? 0.12 : 0.06)),
                radius: isBeingDragged ? 18 : (isHovered ? 16 : 10),
                x: 0,
                y: isBeingDragged ? 12 : (isHovered ? 10 : 6))
        .scaleEffect(isBeingDragged ? 1.02 : (isHovered ? 1.01 : 1.0))
        .rotation3DEffect(.degrees(isBeingDragged ? 4 : 0), axis: (x: 1, y: 0, z: 0))
        .offset(y: isBeingDragged ? -3 : 0)
        .animation(reduceMotion ? nil : .spring(duration: 0.25, bounce: 0.35), value: isBeingDragged)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isHovered)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isExpanded)
        .onHover { hovering in
            guard !selectionMode else {
                isHovered = hovering
                return
            }
            isHovered = hovering
        }
        .onTapGesture {
            if selectionMode {
                onSelectionToggle()
            } else {
                withAnimation(reduceMotion ? nil : GlassMotion.Easing.spring) {
                    isExpanded.toggle()
                }
            }
        }
        .onTapGesture(count: 2) {
            if selectionMode {
                onSelectionToggle()
            } else {
                onOpenDetail()
            }
        }
        .contextMenu {
            if !selectionMode {
                Button("Start Focus Session") {
                    showFocusDurationSheet = true
                }
                Divider()
                Button("Open") { onOpenDetail() }
                Button("Edit") { onEdit() }
                Button("Duplicate") { onDuplicate() }
                Divider()
                Button("Archive") { onArchive() }
                Button("Delete", role: .destructive) { onDelete() }
            }
        }
        .sheet(isPresented: $showFocusDurationSheet) {
            FocusDurationSheet(
                isPresented: $showFocusDurationSheet,
                selectedDuration: $focusDuration,
                itemTitle: project.title,
                itemType: "Project",
                onStart: startFocusSession
            )
        }
        .task {
            focusMetrics = ProjectFocusGravityService.shared.focusMetrics(for: project, modelContext: modelContext)
        }
        .onChange(of: selectionMode) { _, newValue in
            if newValue {
                isHovered = false
                withAnimation(reduceMotion ? nil : GlassMotion.Easing.spring) {
                    isExpanded = false
                }
            }
        }
    }
    
    // MARK: - Header & Meta
    
    private var headerRow: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text(project.title)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(glassColorSystem.textPrimary())
                    .lineLimit(2)
                
                metadataRow
            }
            
            Spacer(minLength: 16)
            
            if !selectionMode {
                quickActions
                    .opacity(isHovered ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.18), value: isHovered)
            }
        }
    }
    
    private var metadataRow: some View {
        HStack(spacing: 10) {
                    InteractiveProjectStatusBadge(project: project)
                    InteractiveProjectDueDateBadge(project: project)
                    
                    if let area = area {
                        InteractiveAreaBadge(project: project, area: area, areas: areas)
                    }
            
            focusSummaryChip
            
            if completionPercentage > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("\(Int(completionPercentage * 100))%")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.kosmicBlue.opacity(0.12))
                .foregroundColor(.kosmicBlue)
                .clipShape(Capsule())
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
    
    private var quickActions: some View {
        HStack(spacing: 8) {
            ProjectQuickActionButton(icon: "timer", color: .kosmicPurple) {
                showFocusDurationSheet = true
            }
            ProjectQuickActionButton(icon: "pencil", color: .kosmicBlue) {
                onEdit()
            }
            ProjectQuickActionButton(icon: "archivebox.fill", color: .gray) {
                onArchive()
            }
        }
    }
    
    private var focusSummaryChip: some View {
        Group {
            if let metrics = focusMetrics {
                let intensity = focusAverage(metrics)
                let percentage = Int(intensity * 100)
                
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("\(percentage)% focus")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.kosmicPurple.opacity(0.12))
                .foregroundColor(.kosmicPurple)
                .clipShape(Capsule())
                .accessibilityLabel("Focus intensity \(percentage) percent")
            }
        }
    }
    
    // MARK: - Sections
    
    private var showProgressSection: Bool {
        totalTasksCount > 0
    }
    
    private var progressSection: some View {
        VStack(spacing: 0) {
            GlassDivider()
                .padding(.horizontal, 24)
            progressRow
                .padding(.horizontal, 24)
                .padding(.vertical, isExpanded ? 16 : 22)
        }
    }
    
    private var progressRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(completedTasksCount)/\(totalTasksCount) tasks")
                    .font(.caption)
                    .foregroundStyle(glassColorSystem.textSecondary())
                Spacer()
                Text("\(Int(completionPercentage * 100))% complete")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.kosmicBlue)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(glassColorSystem.borderColor().opacity(0.15))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(LinearGradient(colors: [.kosmicBlue, .kosmicPurple], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geometry.size.width * CGFloat(completionPercentage), height: 6)
                        .animation(.easeInOut(duration: 0.25), value: completionPercentage)
                }
            }
            .frame(height: 6)
        }
    }
    
    private var expandedSection: some View {
        VStack(spacing: 0) {
            GlassDivider()
                .padding(.horizontal, 24)
            expandedDetails
                .padding(.horizontal, 24)
                .padding(.vertical, 22)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let goal = project.goal, !goal.isEmpty {
                Text(goal)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(glassColorSystem.textSecondary())
                    .lineLimit(4)
            }
            
            HStack(spacing: 12) {
                InteractiveProjectStatusPicker(project: project)
                InteractiveProjectDueDatePicker(project: project)
                Spacer()
            }
            
            if !tasks.isEmpty {
                relatedTasks
            }
        }
    }
    
    private var relatedTasks: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Linked Tasks")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(glassColorSystem.textSecondary())
            
            ForEach(tasks.prefix(5)) { task in
                HStack(spacing: 10) {
                    Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(task.status == .done ? .kosmicGreen : glassColorSystem.textSecondary().opacity(0.6))
                    Text(task.title)
                        .font(.caption)
                        .foregroundColor(glassColorSystem.textSecondary())
                        .lineLimit(1)
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Accents & Helpers
    
    private var focusAccentBar: some View {
        let gradient = LinearGradient(
            colors: [
                Color.kosmicBlue.opacity(isActiveToday ? 0.85 : 0.45),
                Color.kosmicPurple.opacity(isActiveToday ? 0.8 : 0.4),
                Color.kosmicGreen.opacity(isActiveToday ? 0.75 : 0.35)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        
        return RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(gradient)
            .frame(width: isActiveToday ? 6 : 4)
            .padding(.vertical, 18)
            .padding(.leading, 6)
            .opacity(focusMetrics == nil ? 0.25 : 0.85)
            .allowsHitTesting(false)
    }
    
    private var selectionBorderGradient: LinearGradient {
        if isSelected {
            return LinearGradient(colors: [.kosmicBlue, .kosmicPurple], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        return LinearGradient(colors: [glassColorSystem.borderColor().opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    private var activeHighlightGradient: LinearGradient {
        LinearGradient(
            colors: [.kosmicBlue.opacity(0.55), .kosmicPurple.opacity(0.45), .kosmicGreen.opacity(0.4)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func focusAverage(_ metrics: ProjectFocusMetrics) -> Double {
        max(0, min(1, (metrics.cognitiveFocus + metrics.creativeFlow + metrics.completionEnergy) / 3.0))
    }
    private func startFocusSession() {
        showFocusDurationSheet = false
        
        let params = PendingFocusSessionParams(
            objective: project.title,
            plannedDuration: focusDuration,
            targetObjectId: project.id,
            targetObjectType: "project",
            shouldAutoStart: true
        )
        
        NotificationCenter.default.post(name: .startPendingFocusSession, object: params)
        NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.focusMode)
    }
}

private struct ProjectListDropDelegate: DropDelegate {
    let targetProject: Project?
    @Binding var projects: [Project]
    @Binding var draggingProjectID: UUID?
    @Binding var dropTargetProjectID: UUID?
    let fetchProject: (UUID) -> Project?
    let onReorder: ([Project]) -> Void
    
    func validateDrop(info: DropInfo) -> Bool { true }
    
    func dropEntered(info: DropInfo) {
        guard let draggingID = draggingProjectID,
              let fromIndex = projects.firstIndex(where: { $0.id == draggingID }) else { return }
        var toIndex = projects.count - 1
        if let targetProject = targetProject,
           let index = projects.firstIndex(where: { $0.id == targetProject.id }) {
            toIndex = index
        }
        if fromIndex != toIndex {
            withAnimation(.easeInOut(duration: 0.16)) {
                let project = projects.remove(at: fromIndex)
                projects.insert(project, at: toIndex)
            }
            dropTargetProjectID = targetProject?.id
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
    
    func dropExited(info: DropInfo) {
        dropTargetProjectID = nil
    }
    
    func performDrop(info: DropInfo) -> Bool {
        defer {
            draggingProjectID = nil
            dropTargetProjectID = nil
        }
        guard draggingProjectID != nil else { return false }
        onReorder(projects)
        return true
    }
    
    func dropSessionDidEnd(_ session: DropSession) {
        draggingProjectID = nil
        dropTargetProjectID = nil
    }
}

private struct ProjectStatusDropDelegate: DropDelegate {
    let status: ProjectStatus
    @Binding var projects: [Project]
    @Binding var draggingProjectID: UUID?
    @Binding var dropTargetStatus: ProjectStatus?
    let fetchProject: (UUID) -> Project?
    let onMoveToStatus: (Project, ProjectStatus) -> Void
    let onReorder: ([Project]) -> Void
    
    func validateDrop(info: DropInfo) -> Bool { true }
    
    func dropEntered(info: DropInfo) {
        dropTargetStatus = status
    }
    
    func dropExited(info: DropInfo) {
        dropTargetStatus = nil
    }
    
    func performDrop(info: DropInfo) -> Bool {
        defer {
            dropTargetStatus = nil
            draggingProjectID = nil
        }
        
        guard let draggingID = draggingProjectID,
              let project = fetchProject(draggingID) else { return false }
        
        onMoveToStatus(project, status)
        onReorder(projects)
        return true
    }
    
    func dropSessionDidEnd(_ session: DropSession) {
        dropTargetStatus = nil
        draggingProjectID = nil
    }
}

// MARK: - Interactive Project Status Badge

struct InteractiveProjectStatusBadge: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Menu {
            ForEach(ProjectStatus.allCases, id: \.self) { status in
                Button(action: {
                    withAnimation(GlassMotion.Easing.spring) {
                        project.status = status
                        project.updatedAt = Date()
                    }
                    try? modelContext.save()
                }) {
                    HStack {
                        Text(status.displayName)
                        if project.status == status {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            ProjectStatusBadge(status: project.status)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Interactive Project Due Date Badge

struct InteractiveProjectDueDateBadge: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var modelContext
    @State private var showDatePicker = false
    
    var color: Color {
        guard let dueDate = project.dueDate else { return .gray }
        let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
        if daysUntilDue < 0 {
            return .red
        } else if daysUntilDue == 0 {
            return .kosmicBlue
        } else if daysUntilDue <= 3 {
            return .kosmicPurple
        }
        return .gray
    }
    
    var body: some View {
        Menu {
            Button("Set Due Date") {
                if project.dueDate == nil {
                    project.dueDate = Date()
                    project.updatedAt = Date()
                    try? modelContext.save()
                }
                showDatePicker = true
            }
            
            if project.dueDate != nil {
                Button("Remove Due Date", role: .destructive) {
                    project.dueDate = nil
                    project.updatedAt = Date()
                    try? modelContext.save()
                }
            }
            
            Divider()
            
            Button("Today") {
                project.dueDate = Calendar.current.startOfDay(for: Date())
                project.updatedAt = Date()
                try? modelContext.save()
            }
            
            Button("Tomorrow") {
                if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) {
                    project.dueDate = Calendar.current.startOfDay(for: tomorrow)
                    project.updatedAt = Date()
                    try? modelContext.save()
                }
            }
            
            Button("Next Week") {
                if let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date()) {
                    project.dueDate = Calendar.current.startOfDay(for: nextWeek)
                    project.updatedAt = Date()
                    try? modelContext.save()
                }
            }
        } label: {
            if let dueDate = project.dueDate {
                ProjectDueDateBadge(dueDate: dueDate)
            } else {
                Image(systemName: "calendar.badge.plus")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(6)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showDatePicker) {
            DatePicker(
                "Due Date",
                selection: Binding(
                    get: { project.dueDate ?? Date() },
                    set: {
                        project.dueDate = $0
                        project.updatedAt = Date()
                        try? modelContext.save()
                        showDatePicker = false
                    }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
        }
    }
}

// MARK: - Interactive Area Badge

struct InteractiveAreaBadge: View {
    @Bindable var project: Project
    let area: Area
    let areas: [Area]
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Menu {
            Button("None") {
                project.areaId = nil
                project.updatedAt = Date()
                try? modelContext.save()
            }
            
            if !areas.isEmpty {
                Divider()
                ForEach(areas) { areaOption in
                    Button(action: {
                        project.areaId = areaOption.id
                        project.updatedAt = Date()
                        try? modelContext.save()
                    }) {
                        HStack {
                            Text(areaOption.title)
                            if project.areaId == areaOption.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            Text(area.title)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Interactive Status Picker (for expanded view)

struct InteractiveProjectStatusPicker: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var modelContext
    
    private func statusColor(for status: ProjectStatus) -> Color {
        switch status {
        case .active:
            return .kosmicBlue
        case .paused:
            return .orange
        case .completed:
            return .kosmicGreen
        }
    }
    
    var body: some View {
        Menu {
            ForEach(ProjectStatus.allCases, id: \.self) { status in
                Button(action: {
                    withAnimation(GlassMotion.Easing.spring) {
                        project.status = status
                        project.updatedAt = Date()
                    }
                    try? modelContext.save()
                }) {
                    HStack {
                        Circle()
                            .fill(statusColor(for: status).opacity(0.2))
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .fill(statusColor(for: status))
                                    .frame(width: 6, height: 6)
                            )
                        Text(status.displayName)
                        if project.status == status {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor(for: project.status).opacity(0.2))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .fill(statusColor(for: project.status))
                            .frame(width: 6, height: 6)
                    )
                Text(project.status.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Interactive Due Date Picker (for expanded view)

struct InteractiveProjectDueDatePicker: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var modelContext
    @State private var showDatePicker = false
    
    var body: some View {
        Menu {
            Button("Set Due Date") {
                if project.dueDate == nil {
                    project.dueDate = Date()
                    project.updatedAt = Date()
                    try? modelContext.save()
                }
                showDatePicker = true
            }
            
            if project.dueDate != nil {
                Button("Remove Due Date", role: .destructive) {
                    project.dueDate = nil
                    project.updatedAt = Date()
                    try? modelContext.save()
                }
            }
            
            Divider()
            
            Button("Today") {
                project.dueDate = Calendar.current.startOfDay(for: Date())
                project.updatedAt = Date()
                try? modelContext.save()
            }
            
            Button("Tomorrow") {
                if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) {
                    project.dueDate = Calendar.current.startOfDay(for: tomorrow)
                    project.updatedAt = Date()
                    try? modelContext.save()
                }
            }
            
            Button("Next Week") {
                if let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date()) {
                    project.dueDate = Calendar.current.startOfDay(for: nextWeek)
                    project.updatedAt = Date()
                    try? modelContext.save()
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.caption2)
                if let dueDate = project.dueDate {
                    Text(dueDate, format: .dateTime.month(.abbreviated).day())
                        .font(.caption)
                } else {
                    Text("No due date")
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showDatePicker) {
            DatePicker(
                "Due Date",
                selection: Binding(
                    get: { project.dueDate ?? Date() },
                    set: {
                        project.dueDate = $0
                        project.updatedAt = Date()
                        try? modelContext.save()
                        showDatePicker = false
                    }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
        }
    }
}

// MARK: - Supporting Views

struct ProjectDueDateBadge: View {
    let dueDate: Date
    
    var color: Color {
        let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
        if daysUntilDue < 0 {
            return .red
        } else if daysUntilDue == 0 {
            return .kosmicBlue
        } else if daysUntilDue <= 3 {
            return .kosmicPurple
        }
        return .gray
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.caption2)
            Text(dueDate, format: .dateTime.month().day())
                .font(.caption)
        }
        .foregroundColor(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.1))
        .cornerRadius(4)
    }
}

struct ProjectQuickActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 24, height: 24)
                .background(color.opacity(0.1))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

