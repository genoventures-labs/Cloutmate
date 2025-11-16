//
//  UnifiedProjectsView.swift
//  Cloutmate
//
//  Multi-mode orchestration hub for Projects with Focus Gravity integration
//

import SwiftUI
import SwiftData
import CloutmateShared

struct UnifiedProjectsView: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    
    @Query(sort: \CloutmateShared.Project.updatedAt, order: .reverse) private var allProjects: [CloutmateShared.Project]
    @Query private var allTasks: [CloutmateShared.Task]
    @Query private var allAreas: [Area]
    
    @State private var selectedViewMode: ProjectViewMode = .list
    @State private var selectedFilter: ProjectFilter = .all
    @State private var searchText = ""
    @State private var activeProject: Project?
    @State private var isDrawerVisible = false
    @State private var isCreatingProject = false
    @State private var pendingProjectDraft: ProjectDraft?
    @State private var isSelectionMode = false
    @State private var selectedProjectIDs: Set<UUID> = []
    @State private var focusOverlayProject: Project?
    @State private var focusDuration: TimeInterval = 1800 // Default 30 min
    @State private var detailProject: Project?

    var body: some View {
        ZStack {
            V2GlassContentScaffold(
                accentGradient: AuroraPalette.linearGradient(for: colorScheme),
                showsSidebar: false,
                header: { headerBar },
                content: { projectsContent },
                sidebar: { EmptyView() }
            )
            .opacity(isDrawerVisible ? 0 : 1)
            
            if isDrawerVisible {
                if isCreatingProject, let draft = pendingProjectDraft {
                    ProjectDetailDrawer(
                        mode: .create,
                        existingProject: nil,
                        initialDraft: draft,
                        isPresented: creationDrawerBinding(),
                        onCommit: { committedDraft in
                            commitNewProject(from: committedDraft)
                        },
                        onCancel: {
                            pendingProjectDraft = nil
                            withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                                isDrawerVisible = false
                            }
                            isCreatingProject = false
                        }
                    )
                    .transition(.move(edge: .trailing))
                } else if let project = activeProject {
                    ProjectDetailDrawer(
                        mode: .edit,
                        existingProject: project,
                        initialDraft: ProjectDraft(project: project),
                        isPresented: editDrawerBinding(),
                        onCommit: { draft in
                            apply(draft, to: project)
                            try? modelContext.save()
                            withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                                isDrawerVisible = false
                            }
                            DispatchQueue.main.async {
                                activeProject = nil
                            }
                        },
                        onCancel: {
                            withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                                isDrawerVisible = false
                            }
                            DispatchQueue.main.async {
                                activeProject = nil
                            }
                        }
                    )
                    .transition(.move(edge: .trailing))
                }
            }
            
            if let focusProject = focusOverlayProject {
                FocusDurationSheet(
                    isPresented: Binding(
                        get: { focusOverlayProject != nil },
                        set: { newValue in
                            if !newValue {
                                focusOverlayProject = nil
                            }
                        }
                    ),
                    selectedDuration: $focusDuration,
                    itemTitle: focusProject.title,
                    itemType: "Project",
                    onStart: {
                        startFocusSession(for: focusProject)
                    }
                )
            }
        }
        .sheet(item: $detailProject) { project in
            ProjectDetailView(project: project)
                .environmentObject(glassColorSystem)
                .frame(minWidth: 900, minHeight: 600)
        }
        .onChange(of: selectedFilter) { _, _ in
            pruneSelection()
        }
        .onChange(of: searchText) { _, _ in
            pruneSelection()
        }
    }
    
    var filteredProjects: [Project] {
        var filtered = allProjects
        
        if !searchText.isEmpty {
            filtered = filtered.filter { project in
                project.title.localizedCaseInsensitiveContains(searchText) ||
                (project.goal?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        if selectedFilter != .all {
            filtered = filtered.filter { selectedFilter.matches($0.status) }
        }
        
        return filtered
    }
    
    var activeProjectsCount: Int {
        filteredProjects.filter { $0.status == .active }.count
    }
    
    var selectedProjects: [Project] {
        filteredProjects.filter { selectedProjectIDs.contains($0.id) }
    }
    
    var visibleSelectedProjectCount: Int {
        selectedProjects.count
    }
    
    var isSelectionActive: Bool {
        isSelectionMode || !selectedProjectIDs.isEmpty
    }
    
    private func projectSelectionActions() -> [SelectionActionBar.Action] {
        var actions: [SelectionActionBar.Action] = []
        
        // Start Focus Session action (only if single project selected)
        if selectedProjects.count == 1, let project = selectedProjects.first {
            actions.append(.init(title: "Start Focus Session", icon: "timer") {
                requestFocusSession(for: project)
            })
        }
        
        if selectedProjects.contains(where: { $0.status != .active }) {
            actions.append(.init(title: "Mark Active", icon: "play.fill") {
                updateSelectedProjectsStatus(.active)
            })
        }
        if selectedProjects.contains(where: { $0.status != .paused }) {
            actions.append(.init(title: "Pause", icon: "pause.fill") {
                updateSelectedProjectsStatus(.paused)
            })
        }
        if selectedProjects.contains(where: { $0.status != .completed }) {
            actions.append(.init(title: "Complete", icon: "checkmark.seal.fill") {
                updateSelectedProjectsStatus(.completed)
            })
        }
        actions.append(.init(title: "Delete", icon: "trash", role: .danger) {
            deleteSelectedProjects()
        })
        return actions
    }
    
    private func toggleSelectionMode() {
        guard selectedViewMode != .roadmap else { return }
        if isSelectionMode || !selectedProjectIDs.isEmpty {
            clearSelection()
        } else if !filteredProjects.isEmpty {
            isSelectionMode = true
            if isDrawerVisible {
                withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                    isDrawerVisible = false
                }
                pendingProjectDraft = nil
                activeProject = nil
                isCreatingProject = false
            }
        }
    }
    
    private func toggleProjectSelection(_ project: Project) {
        if selectedProjectIDs.contains(project.id) {
            selectedProjectIDs.remove(project.id)
            if selectedProjectIDs.isEmpty {
                isSelectionMode = false
            }
        } else {
            if !isSelectionMode {
                isSelectionMode = true
            }
            selectedProjectIDs.insert(project.id)
        }
        if isSelectionActive {
            withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                isDrawerVisible = false
                focusOverlayProject = nil
            }
            pendingProjectDraft = nil
            activeProject = nil
            isCreatingProject = false
        }
    }
    
    private func clearSelection() {
        selectedProjectIDs.removeAll()
        isSelectionMode = false
    }
    
    private func pruneSelection() {
        let visibleIDs = Set(filteredProjects.map(\.id))
        selectedProjectIDs = selectedProjectIDs.intersection(visibleIDs)
        if selectedProjectIDs.isEmpty {
            isSelectionMode = false
        }
    }
    
    private func updateSelectedProjectsStatus(_ status: ProjectStatus) {
        for project in selectedProjects {
            project.status = status
            project.updatedAt = Date()
        }
        try? modelContext.save()
        clearSelection()
    }
    
    private func deleteSelectedProjects() {
        for project in selectedProjects {
            modelContext.delete(project)
        }
        try? modelContext.save()
        clearSelection()
    }
    
    private func duplicateProject(_ project: Project) {
        let duplicated = Project(
            title: "\(project.title) (Copy)",
            goal: project.goal,
            status: project.status,
            dueDate: project.dueDate,
            areaId: project.areaId,
            tags: project.tags
        )
        modelContext.insert(duplicated)
        try? modelContext.save()
    }
    
    private func archiveProject(_ project: Project) {
        project.status = .completed
        project.updatedAt = Date()
        try? modelContext.save()
        if selectedProjectIDs.contains(project.id) {
            selectedProjectIDs.remove(project.id)
            if selectedProjectIDs.isEmpty {
                isSelectionMode = false
            }
        }
    }
    
    private func deleteProject(_ project: Project) {
        modelContext.delete(project)
        try? modelContext.save()
        if selectedProjectIDs.contains(project.id) {
            selectedProjectIDs.remove(project.id)
            if selectedProjectIDs.isEmpty {
                isSelectionMode = false
            }
        }
    }
    
    private func persistProjectOrder(_ projects: [Project]) {
        let base = Date()
        for (offset, project) in projects.enumerated() {
            project.updatedAt = base.addingTimeInterval(Double(projects.count - offset))
        }
        try? modelContext.save()
    }
    
    private func handleProjectStatusChange(_ project: Project, status: ProjectStatus) {
        project.status = status
        switch status {
        case .completed:
            project.archivedAt = Date()
        case .active, .paused:
            project.archivedAt = nil
        }
        project.updatedAt = Date()
        try? modelContext.save()
    }
    
    private func requestFocusSession(for project: Project) {
        focusDuration = 1800
        withAnimation(.easeInOut(duration: 0.2)) {
            focusOverlayProject = project
            isDrawerVisible = false
        }
        pendingProjectDraft = nil
        isCreatingProject = false
        activeProject = nil
    }
    
    private func startFocusSession(for project: Project) {
        withAnimation(.easeOut(duration: 0.2)) {
            focusOverlayProject = nil
        }
        
        let params = PendingFocusSessionParams(
            objective: project.title,
            plannedDuration: focusDuration,
            targetObjectId: project.id,
            targetObjectType: "project",
            shouldAutoStart: true
        )
        
        clearSelection()
        NotificationCenter.default.post(name: .startPendingFocusSession, object: params)
        NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.focusMode)
    }
    
    private func toggleSelectAll() {
        let allVisibleIDs = Set(filteredProjects.map(\.id))
        if selectedProjectIDs == allVisibleIDs {
            clearSelection()
        } else {
            selectedProjectIDs = allVisibleIDs
            if !isSelectionMode {
                isSelectionMode = true
                if isDrawerVisible {
                    withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                        isDrawerVisible = false
                    }
                    pendingProjectDraft = nil
                    activeProject = nil
                    isCreatingProject = false
                }
            }
        }
    }
    
    private func startCreatingProject() {
        guard !isDrawerVisible else { return }
        
        pendingProjectDraft = ProjectDraft(
            title: "",
            goal: "",
            status: .active,
            dueDate: nil,
            areaId: nil,
            tags: [],
            linkedEntityIds: [],
            linkedEntityTypes: []
        )
        activeProject = nil
        isCreatingProject = true
        
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isDrawerVisible = true
        }
    }
    
    private func showProjectDetail(_ project: Project) {
        guard !isSelectionActive else { return }
        
        detailProject = project
        focusOverlayProject = nil
        
        if isDrawerVisible {
            withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                isDrawerVisible = false
            }
            pendingProjectDraft = nil
            activeProject = nil
            isCreatingProject = false
        }
    }
    
    private func openEditDrawer(for project: Project) {
        guard !isSelectionActive else { return }
        
        detailProject = nil
        activeProject = project
        pendingProjectDraft = nil
        isCreatingProject = false
        
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isDrawerVisible = true
        }
    }
    
    private func creationDrawerBinding() -> Binding<Bool> {
        Binding(
            get: { isDrawerVisible && isCreatingProject },
            set: { newValue in
                if !newValue {
                    pendingProjectDraft = nil
                    isCreatingProject = false
                }
                withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                    isDrawerVisible = newValue
                }
            }
        )
    }
    
    private func editDrawerBinding() -> Binding<Bool> {
        Binding(
            get: { isDrawerVisible && !isCreatingProject },
            set: { newValue in
                if !newValue {
                    activeProject = nil
                }
                withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                    isDrawerVisible = newValue
                }
            }
        )
    }
    
    private func commitNewProject(from draft: ProjectDraft) {
        let normalizedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedGoal = draft.goal.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle: String
        if !normalizedTitle.isEmpty {
            resolvedTitle = normalizedTitle
        } else if !normalizedGoal.isEmpty {
            resolvedTitle = String(normalizedGoal.prefix(64))
        } else {
            resolvedTitle = "Untitled Project"
        }
        
        let project = Project(
            title: resolvedTitle,
            goal: normalizedGoal.isEmpty ? nil : draft.goal,
            status: draft.status,
            dueDate: draft.dueDate,
            areaId: draft.areaId,
            tags: draft.tags
        )
        project.linkedEntityIds = draft.linkedEntityIds
        project.linkedEntityTypes = draft.linkedEntityTypes
        modelContext.insert(project)
        try? modelContext.save()
        
        pendingProjectDraft = nil
        isCreatingProject = false
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isDrawerVisible = false
        }
    }
    
    private func apply(_ draft: ProjectDraft, to project: Project) {
        let normalizedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedGoal = draft.goal.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !normalizedTitle.isEmpty {
            project.title = normalizedTitle
        } else if !normalizedGoal.isEmpty {
            project.title = String(normalizedGoal.prefix(64))
        } else {
            project.title = "Untitled Project"
        }
        
        project.goal = normalizedGoal.isEmpty ? nil : draft.goal
        project.status = draft.status
        project.dueDate = draft.dueDate
        project.areaId = draft.areaId
        project.tags = draft.tags
        project.linkedEntityIds = draft.linkedEntityIds
        project.linkedEntityTypes = draft.linkedEntityTypes
        project.updatedAt = Date()
    }
    
    // MARK: - Header & Layout
    
    private var headerBar: some View {
        V2GlassHeaderBar(
            title: "Projects",
            subtitle: headerSubtitle,
            trailingAccessory: {
                HStack(spacing: 12) {
                    viewModeSelector
                    selectionToggleButton
                    quickAddButton
                }
            }
        )
    }
    
    private var headerSubtitle: String {
        let total = filteredProjects.count
        if total == 0 {
            return "No projects yet — let’s start something new."
        }
        return "\(activeProjectsCount) active • \(total) total"
    }
    
    @ViewBuilder
    private var projectsContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            filterPanel
            
            if isSelectionActive {
                selectionBar
            }
            
            modeScrollContainer
        }
    }
    
    private var filterPanel: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.kosmicBlue.opacity(0.22), .kosmicPurple.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 42, height: 42)
                            .overlay(
                                Circle()
                                    .stroke(glassColorSystem.borderColor().opacity(0.5), lineWidth: 0.6)
                            )
                        
                        Image(systemName: "sparkles.rectangle.stack")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.kosmicBlue)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Line up your next focus arc")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(glassColorSystem.textPrimary())
                        Text(headerSubtitle)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(glassColorSystem.textSecondary())
            }
            
            Spacer()
            
                    GlassButton("Reset", icon: "arrow.uturn.backward", style: .pill, role: .surface) {
                        withAnimation(GlassMotion.Easing.spring) {
                            selectedFilter = .all
                            searchText = ""
                        }
                    }
                    .accessibilityLabel("Reset filters")
                    }
                
                GlassDivider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Search")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                    
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(glassColorSystem.textSecondary().opacity(0.75))
                        
                        TextField("Search projects", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(glassColorSystem.textPrimary())
                        
                        if !searchText.isEmpty {
                            GlassButton(icon: "xmark.circle.fill", style: .iconOnly, role: .surface) {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    searchText = ""
                                }
                            }
                            .accessibilityLabel("Clear search")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                            .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(glassColorSystem.backgroundSecondary().opacity(0.35))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(glassColorSystem.borderColor().opacity(0.55), lineWidth: 0.6)
                            )
                    )
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Status")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(ProjectFilter.allCases, id: \.self) { filter in
                                FilterPill(
                                    title: filter.displayName,
                                    isSelected: selectedFilter == filter,
                                    action: {
                                        withAnimation(GlassMotion.Easing.spring) {
                                            selectedFilter = filter
                ProjectHaptics.playSelection()
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
            .padding(24)
        }
    }
    
    private var selectionBar: some View {
        SelectionActionBar(
            count: visibleSelectedProjectCount,
            itemLabel: "Project",
            actions: projectSelectionActions(),
            onCancel: { clearSelection() },
            onSelectAll: selectedViewMode == .roadmap ? nil : { toggleSelectAll() },
            totalItems: selectedViewMode == .roadmap ? nil : filteredProjects.count
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    private var modeScrollContainer: some View {
        ScrollViewReader { _ in
            ScrollView {
                VStack(spacing: 0) {
                    activeModeView
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                }
            }
        }
    }
    
    @ViewBuilder
    private var activeModeView: some View {
                        switch selectedViewMode {
                        case .list:
                            ProjectListView(
                                projects: filteredProjects,
                                tasks: allTasks,
                                areas: allAreas,
                                selectionMode: isSelectionActive,
                                selectedProjectIDs: selectedProjectIDs,
                                onSelectionToggle: { project in toggleProjectSelection(project) },
                                onProjectDetail: { project in showProjectDetail(project) },
                                onProjectEdit: { project in openEditDrawer(for: project) },
                                onDuplicateProject: { project in duplicateProject(project) },
                                onArchiveProject: { project in archiveProject(project) },
                            onDeleteProject: { project in deleteProject(project) },
                            onReorderProjects: { reordered in persistProjectOrder(reordered) },
                            onMoveProjectToStatus: { project, status in handleProjectStatusChange(project, status: status) },
                            fetchProjectByID: { id in allProjects.first(where: { $0.id == id }) }
                            )
                        case .board:
                            ProjectBoardView(
                                projects: filteredProjects,
                                tasks: allTasks,
                                areas: allAreas,
                                selectionMode: isSelectionActive,
                                selectedProjectIDs: selectedProjectIDs,
                                onSelectionToggle: { project in toggleProjectSelection(project) },
                                onProjectDetail: { project in showProjectDetail(project) },
                                onProjectEdit: { project in openEditDrawer(for: project) },
                                onDuplicateProject: { project in duplicateProject(project) },
                                onArchiveProject: { project in archiveProject(project) },
                                onDeleteProject: { project in deleteProject(project) }
                            )
        case .roadmap:
            ProjectRoadmapView(
                                projects: filteredProjects,
                                tasks: allTasks,
                                areas: allAreas,
                                onProjectSelected: { project in showProjectDetail(project) }
                            )
                        case .gallery:
                            ProjectGalleryView(
                                projects: filteredProjects,
                                tasks: allTasks,
                                areas: allAreas,
                                selectionMode: isSelectionActive,
                                selectedProjectIDs: selectedProjectIDs,
                                onSelectionToggle: { project in toggleProjectSelection(project) },
                                onProjectDetail: { project in showProjectDetail(project) },
                                onProjectEdit: { project in openEditDrawer(for: project) }
                            )
                        }
                    }
    
    private var viewModeSelector: some View {
        HStack(spacing: 6) {
            ForEach(ProjectViewMode.allCases, id: \.self, content: modeButton)
        }
    }
    
    @ViewBuilder
    private func modeButton(for mode: ProjectViewMode) -> some View {
        let isSelected = selectedViewMode == mode
        Button {
            selectedViewMode = mode
            ProjectHaptics.playSelection()
        } label: {
            Image(systemName: mode.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : glassColorSystem.textSecondary())
                .frame(width: 28, height: 28)
                .background {
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.kosmicBlue, .kosmicPurple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(glassColorSystem.cardColor().opacity(0.35))
                        }
                }
            }
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(glassColorSystem.borderColor().opacity(0.5), lineWidth: 0.6)
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }
    
    private var selectionToggleButton: some View {
        GlassButton(
            icon: isSelectionActive ? "checkmark.circle.fill" : "checkmark.circle",
            style: .iconOnly,
            role: .surface
        ) {
            toggleSelectionMode()
        }
        .accessibilityLabel(isSelectionActive ? "Exit selection mode" : "Enter selection mode")
        .help(isSelectionActive ? "Done Selecting" : "Select Projects")
        .opacity(selectedViewMode == .roadmap ? 0.4 : 1.0)
        .disabled(selectedViewMode == .roadmap)
    }
    
    private var quickAddButton: some View {
        GlassButton(
            icon: "plus",
            style: .iconOnly,
            tintColor: .kosmicPurple
        ) {
            startCreatingProject()
            ProjectHaptics.playSelection()
        }
        .help("Create New Project (⌘N)")
    }
}

#Preview {
    UnifiedProjectsView()
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [CloutmateShared.Project.self, CloutmateShared.Task.self, Area.self])
}

