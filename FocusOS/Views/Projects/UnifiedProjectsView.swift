//
//  UnifiedProjectsView.swift
//  FocusOS
//
//  Multi-mode orchestration hub for Projects with Focus Gravity integration
//

import SwiftUI
import SwiftData
import FocusOSShared

struct UnifiedProjectsView: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    
    @Query(sort: \FocusOSShared.Project.updatedAt, order: .reverse) private var allProjects: [FocusOSShared.Project]
    @Query private var allTasks: [FocusOSShared.Task]
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
    @State private var isFilterSortDrawerVisible = false
    
    // Advanced filter state
    @State private var selectedAreaFilter: UUID?
    @State private var selectedTags: Set<String> = []
    
    // Sort persistence per view mode
    @AppStorage("projects.sort.list") private var listSortOption: String = ProjectSortOption.dueDateAsc.rawValue
    @AppStorage("projects.sort.board") private var boardSortOption: String = ProjectSortOption.dueDateAsc.rawValue
    @AppStorage("projects.sort.roadmap") private var roadmapSortOption: String = ProjectSortOption.dueDateAsc.rawValue
    @AppStorage("projects.sort.gallery") private var gallerySortOption: String = ProjectSortOption.dueDateAsc.rawValue
    
    private var currentSortOption: ProjectSortOption {
        let rawValue: String
        switch selectedViewMode {
        case .list: rawValue = listSortOption
        case .board: rawValue = boardSortOption
        case .roadmap: rawValue = roadmapSortOption
        case .gallery: rawValue = gallerySortOption
        }
        return ProjectSortOption(rawValue: rawValue) ?? .dueDateAsc
    }

    var body: some View {
        ZStack {
            V2GlassContentScaffold(
                accentGradient: AuroraPalette.linearGradient(for: colorScheme),
                showsSidebar: false,
                header: { headerBar },
                content: { projectsContent },
                sidebar: { EmptyView() }
            )
            .opacity(isDrawerVisible || isFilterSortDrawerVisible ? 0 : 1)
            
            if isFilterSortDrawerVisible {
                ProjectFilterSortDrawer(
                    isPresented: $isFilterSortDrawerVisible,
                    selectedFilter: $selectedFilter,
                    selectedSort: Binding(
                        get: { currentSortOption },
                        set: { newSort in
                            let rawValue = newSort.rawValue
                            switch selectedViewMode {
                            case .list: listSortOption = rawValue
                            case .board: boardSortOption = rawValue
                            case .roadmap: roadmapSortOption = rawValue
                            case .gallery: gallerySortOption = rawValue
                            }
                        }
                    ),
                    selectedAreaFilter: $selectedAreaFilter,
                    selectedTags: $selectedTags,
                    allAreas: allAreas,
                    allProjects: filteredProjects
                )
                .transition(.move(edge: .trailing))
            }
            
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
        .onChange(of: selectedViewMode) { _, _ in
            // Sort option is automatically updated via currentSortOption computed property
        }
    }
    
    var filteredProjects: [Project] {
        var filtered = allProjects
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { project in
                project.title.localizedCaseInsensitiveContains(searchText) ||
                (project.goal?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Apply status filter
        switch selectedFilter {
        // Basic filters
        case .all:
            break
        case .active:
            filtered = filtered.filter { $0.status == .active }
        case .paused:
            filtered = filtered.filter { $0.status == .paused }
        case .completed:
            filtered = filtered.filter { $0.status == .completed }
        
        // Due date filters
        case .withDueDate:
            filtered = filtered.filter { $0.dueDate != nil }
        case .withoutDueDate:
            filtered = filtered.filter { $0.dueDate == nil }
        case .overdue:
            filtered = filtered.filter { project in
                guard let due = project.dueDate else { return false }
                return due < Date() && project.status != .completed
            }
        case .dueThisWeek:
            filtered = filtered.filter { project in
                guard let due = project.dueDate else { return false }
                let days = Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0
                return days >= 0 && days <= 7 && project.status != .completed
            }
        case .dueThisMonth:
            filtered = filtered.filter { project in
                guard let due = project.dueDate else { return false }
                let days = Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0
                return days >= 0 && days <= 30 && project.status != .completed
            }
        case .dueThisQuarter:
            filtered = filtered.filter { project in
                guard let due = project.dueDate else { return false }
                let days = Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0
                return days >= 0 && days <= 90 && project.status != .completed
            }
        
        // Relationship filters
        case .unattached:
            filtered = filtered.filter { $0.areaId == nil }
        case .hasArea:
            filtered = filtered.filter { $0.areaId != nil }
        
        // Tag filters
        case .withTags:
            filtered = filtered.filter { !$0.tags.isEmpty }
        case .withoutTags:
            filtered = filtered.filter { $0.tags.isEmpty }
        
        // Activity filters
        case .recentlyUpdated:
            filtered = filtered.filter { project in
                let days = Calendar.current.dateComponents([.day], from: project.updatedAt, to: Date()).day ?? 0
                return days <= 7
            }
        case .recentlyCreated:
            filtered = filtered.filter { project in
                let days = Calendar.current.dateComponents([.day], from: project.createdAt, to: Date()).day ?? 0
                return days <= 7
            }
        case .stale:
            filtered = filtered.filter { project in
                let days = Calendar.current.dateComponents([.day], from: project.updatedAt, to: Date()).day ?? 0
                return days >= 30
            }
        }
        
        // Apply advanced filters (area/tag selection)
        if let areaId = selectedAreaFilter {
            filtered = filtered.filter { $0.areaId == areaId }
        }
        if !selectedTags.isEmpty {
            filtered = filtered.filter { project in
                !Set(project.tags).isDisjoint(with: selectedTags)
            }
        }
        
        // Apply sorting
        return sortProjects(filtered, by: currentSortOption)
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
            
                    Button {
                        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                            isFilterSortDrawerVisible = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 14, weight: .medium))
                            Text("All Options")
                                .font(.system(.caption, design: .rounded).weight(.medium))
                        }
                        .foregroundStyle(glassColorSystem.textPrimary())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(glassColorSystem.cardColor().opacity(0.4))
                                .overlay(
                                    Capsule()
                                        .stroke(glassColorSystem.borderColor().opacity(0.5), lineWidth: 0.8)
                                )
                        )
                    }
                    .buttonStyle(.plain)
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
                
                // Most common filters (3 max)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Filters")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                    
                    HStack(spacing: 10) {
                        quickFilterButton(.all)
                        quickFilterButton(.active)
                        quickFilterButton(.completed)
                    }
                }
                
                GlassDivider()
                
                // Most common sorts (3 max)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Sort")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                    
                    HStack(spacing: 10) {
                        quickSortButton(.dueDateAsc)
                        quickSortButton(.updatedDesc)
                        quickSortButton(.statusActiveFirst)
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
    
    private func updateSortOption(_ option: ProjectSortOption) {
        switch selectedViewMode {
        case .list:
            listSortOption = option.rawValue
        case .board:
            boardSortOption = option.rawValue
        case .roadmap:
            roadmapSortOption = option.rawValue
        case .gallery:
            gallerySortOption = option.rawValue
        }
    }
    
    private func sortProjects(_ projects: [Project], by option: ProjectSortOption) -> [Project] {
        var sorted = projects
        
        switch option {
        // Date/Time sorts
        case .dueDateAsc:
            sorted.sort { project1, project2 in
                guard let date1 = project1.dueDate else { return false }
                guard let date2 = project2.dueDate else { return true }
                return date1 < date2
            }
        case .dueDateDesc:
            sorted.sort { project1, project2 in
                guard let date1 = project1.dueDate else { return true }
                guard let date2 = project2.dueDate else { return false }
                return date1 > date2
            }
        case .createdAsc:
            sorted.sort { $0.createdAt < $1.createdAt }
        case .createdDesc:
            sorted.sort { $0.createdAt > $1.createdAt }
        case .updatedAsc:
            sorted.sort { $0.updatedAt < $1.updatedAt }
        case .updatedDesc:
            sorted.sort { $0.updatedAt > $1.updatedAt }
        case .archivedAsc:
            sorted.sort { project1, project2 in
                guard let date1 = project1.archivedAt else { return false }
                guard let date2 = project2.archivedAt else { return true }
                return date1 < date2
            }
        case .archivedDesc:
            sorted.sort { project1, project2 in
                guard let date1 = project1.archivedAt else { return true }
                guard let date2 = project2.archivedAt else { return false }
                return date1 > date2
            }
        
        // Status sorts
        case .statusActiveFirst:
            sorted.sort { project1, project2 in
                let status1 = project1.status
                let status2 = project2.status
                if status1 == status2 {
                    return project1.updatedAt > project2.updatedAt
                }
                let order: [ProjectStatus] = [.active, .paused, .completed]
                let index1 = order.firstIndex(of: status1) ?? 999
                let index2 = order.firstIndex(of: status2) ?? 999
                return index1 < index2
            }
        case .statusCompletedFirst:
            sorted.sort { project1, project2 in
                let status1 = project1.status
                let status2 = project2.status
                if status1 == status2 {
                    return project1.updatedAt > project2.updatedAt
                }
                let order: [ProjectStatus] = [.completed, .paused, .active]
                let index1 = order.firstIndex(of: status1) ?? 999
                let index2 = order.firstIndex(of: status2) ?? 999
                return index1 < index2
            }
        
        // Relationship sorts
        case .byArea:
            sorted.sort { project1, project2 in
                if project1.areaId == project2.areaId {
                    return project1.updatedAt > project2.updatedAt
                }
                if project1.areaId == nil { return false }
                if project2.areaId == nil { return true }
                return project1.areaId!.uuidString < project2.areaId!.uuidString
            }
        case .unattachedFirst:
            sorted.sort { project1, project2 in
                let project1Attached = project1.areaId != nil
                let project2Attached = project2.areaId != nil
                if project1Attached == project2Attached {
                    return project1.updatedAt > project2.updatedAt
                }
                return !project1Attached && project2Attached
            }
        case .unattachedLast:
            sorted.sort { project1, project2 in
                let project1Attached = project1.areaId != nil
                let project2Attached = project2.areaId != nil
                if project1Attached == project2Attached {
                    return project1.updatedAt > project2.updatedAt
                }
                return project1Attached && !project2Attached
            }
        
        // Tag sorts
        case .tagCountDesc:
            sorted.sort { project1, project2 in
                let count1 = project1.tags.count
                let count2 = project2.tags.count
                if count1 == count2 {
                    return project1.updatedAt > project2.updatedAt
                }
                return count1 > count2
            }
        case .tagCountAsc:
            sorted.sort { project1, project2 in
                let count1 = project1.tags.count
                let count2 = project2.tags.count
                if count1 == count2 {
                    return project1.updatedAt > project2.updatedAt
                }
                return count1 < count2
            }
        
        // Alphabetical sorts
        case .titleAsc:
            sorted.sort { project1, project2 in
                project1.title.localizedCaseInsensitiveCompare(project2.title) == .orderedAscending
            }
        case .titleDesc:
            sorted.sort { project1, project2 in
                project1.title.localizedCaseInsensitiveCompare(project2.title) == .orderedDescending
            }
        
        // Combined sorts
        case .statusThenDueDate:
            sorted.sort { project1, project2 in
                let status1 = project1.status
                let status2 = project2.status
                if status1 != status2 {
                    let order: [ProjectStatus] = [.active, .paused, .completed]
                    let index1 = order.firstIndex(of: status1) ?? 999
                    let index2 = order.firstIndex(of: status2) ?? 999
                    return index1 < index2
                }
                guard let date1 = project1.dueDate else { return false }
                guard let date2 = project2.dueDate else { return true }
                return date1 < date2
            }
        case .statusThenUpdated:
            sorted.sort { project1, project2 in
                let status1 = project1.status
                let status2 = project2.status
                if status1 != status2 {
                    let order: [ProjectStatus] = [.active, .paused, .completed]
                    let index1 = order.firstIndex(of: status1) ?? 999
                    let index2 = order.firstIndex(of: status2) ?? 999
                    return index1 < index2
                }
                return project1.updatedAt > project2.updatedAt
            }
        }
        
        return sorted
    }
    
    @ViewBuilder
    private func quickFilterButton(_ filter: ProjectFilter) -> some View {
        Button {
            withAnimation(GlassMotion.Easing.spring) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.system(size: 11, weight: .medium))
                Text(filter.displayName)
                    .font(.system(.caption, design: .rounded))
            }
            .foregroundStyle(selectedFilter == filter ? glassColorSystem.textPrimary() : glassColorSystem.textSecondary())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selectedFilter == filter ? glassColorSystem.cardColor().opacity(0.5) : glassColorSystem.backgroundSecondary().opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(selectedFilter == filter ? glassColorSystem.emotionalAccent().opacity(0.4) : glassColorSystem.borderColor().opacity(0.3), lineWidth: selectedFilter == filter ? 1.0 : 0.6)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func quickSortButton(_ sort: ProjectSortOption) -> some View {
        Button {
            let rawValue = sort.rawValue
            switch selectedViewMode {
            case .list: listSortOption = rawValue
            case .board: boardSortOption = rawValue
            case .roadmap: roadmapSortOption = rawValue
            case .gallery: gallerySortOption = rawValue
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: sort.icon)
                    .font(.system(size: 11, weight: .medium))
                Text(sort.displayName)
                    .font(.system(.caption, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(currentSortOption == sort ? glassColorSystem.textPrimary() : glassColorSystem.textSecondary())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(currentSortOption == sort ? glassColorSystem.cardColor().opacity(0.5) : glassColorSystem.backgroundSecondary().opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(currentSortOption == sort ? glassColorSystem.emotionalAccent().opacity(0.4) : glassColorSystem.borderColor().opacity(0.3), lineWidth: currentSortOption == sort ? 1.0 : 0.6)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private func filterCategoryMenu(for category: ProjectFilterCategory) -> some View {
        let filters = ProjectFilter.filters(for: category)
        let currentFilterInCategory = filters.first { $0 == selectedFilter }
        let isActive = currentFilterInCategory != nil
        
        return Menu {
            ForEach(filters) { filter in
                Button {
                    withAnimation(GlassMotion.Easing.spring) {
                        selectedFilter = filter
                        // Clear advanced filters when switching away from relationship/tags category
                        if filter.category != .relationship && filter.category != .tags {
                            selectedAreaFilter = nil
                            if filter.category != .tags {
                                selectedTags.removeAll()
                            }
                        }
                        ProjectHaptics.playSelection()
                    }
                } label: {
                    HStack {
                        Image(systemName: filter.icon)
                            .font(.system(size: 12, weight: .medium))
                        Text(filter.displayName)
                        Spacer()
                        if selectedFilter == filter {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isActive ? glassColorSystem.textPrimary() : glassColorSystem.textSecondary())
                
                if let current = currentFilterInCategory {
                    Text(current.displayName)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                        .lineLimit(1)
                } else {
                    Text(category.rawValue)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                        .lineLimit(1)
                }
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(glassColorSystem.textSecondary().opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isActive ? glassColorSystem.cardColor().opacity(0.5) : glassColorSystem.backgroundSecondary().opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isActive ? glassColorSystem.emotionalAccent().opacity(0.4) : glassColorSystem.borderColor().opacity(0.55), lineWidth: isActive ? 1.0 : 0.6)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private var areaFilterDropdown: some View {
        Menu {
            Button {
                selectedAreaFilter = nil
            } label: {
                HStack {
                    Text("All Areas")
                    if selectedAreaFilter == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            ForEach(allAreas) { area in
                Button {
                    selectedAreaFilter = area.id
                } label: {
                    HStack {
                        Text(area.title)
                        Spacer()
                        if selectedAreaFilter == area.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 11, weight: .medium))
                Text(selectedAreaFilter != nil ? allAreas.first(where: { $0.id == selectedAreaFilter })?.title ?? "Area" : "All Areas")
                    .font(.system(.caption, design: .rounded))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(glassColorSystem.backgroundSecondary().opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(glassColorSystem.borderColor().opacity(0.55), lineWidth: 0.6)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private var tagFilterDropdown: some View {
        let allTags = Set(allProjects.flatMap { $0.tags }).sorted()
        
        return Menu {
            Button {
                selectedTags.removeAll()
            } label: {
                HStack {
                    Text("All Tags")
                    if selectedTags.isEmpty {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            ForEach(allTags, id: \.self) { tag in
                Button {
                    if selectedTags.contains(tag) {
                        selectedTags.remove(tag)
                    } else {
                        selectedTags.insert(tag)
                    }
                } label: {
                    HStack {
                        Text(tag)
                        Spacer()
                        if selectedTags.contains(tag) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "tag")
                    .font(.system(size: 11, weight: .medium))
                Text(selectedTags.isEmpty ? "All Tags" : selectedTags.count == 1 ? selectedTags.first! : "\(selectedTags.count) tags")
                    .font(.system(.caption, design: .rounded))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(glassColorSystem.backgroundSecondary().opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(glassColorSystem.borderColor().opacity(0.55), lineWidth: 0.6)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func sortCategoryMenu(for category: ProjectSortCategory) -> some View {
        let options = ProjectSortOption.options(for: category)
        let currentOptionInCategory = options.first { $0 == currentSortOption }
        let isActive = currentOptionInCategory != nil
        
        Menu {
            ForEach(options) { option in
                Button {
                    updateSortOption(option)
                } label: {
                    HStack {
                        Text(option.displayName)
                        Spacer()
                        if currentSortOption == option {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isActive ? glassColorSystem.textPrimary() : glassColorSystem.textSecondary())
                
                if let current = currentOptionInCategory {
                    Text(current.displayName)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                        .lineLimit(1)
                } else {
                    Text(category.rawValue)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                        .lineLimit(1)
                }
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(glassColorSystem.textSecondary().opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isActive ? glassColorSystem.cardColor().opacity(0.5) : glassColorSystem.backgroundSecondary().opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isActive ? glassColorSystem.emotionalAccent().opacity(0.4) : glassColorSystem.borderColor().opacity(0.55), lineWidth: isActive ? 1.0 : 0.6)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Project Filter Sort Drawer

struct ProjectFilterSortDrawer: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @Binding var isPresented: Bool
    @Binding var selectedFilter: ProjectFilter
    @Binding var selectedSort: ProjectSortOption
    @Binding var selectedAreaFilter: UUID?
    @Binding var selectedTags: Set<String>
    
    let allAreas: [Area]
    let allProjects: [Project]
    
    var body: some View {
        V2DrawerScaffold(
            accentGradient: AuroraPalette.linearGradient(for: colorScheme),
            header: {
                V2GlassHeaderBar(
                    title: "Filter & Sort Projects",
                    subtitle: "Refine your project view"
                ) {
                    Button {
                        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                            isPresented = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                VStack(alignment: .leading, spacing: 32) {
                    // Filters Section
                    DrawerSection(title: "Filters", icon: "line.3.horizontal.decrease.circle") {
                        VStack(alignment: .leading, spacing: 20) {
                            ForEach(ProjectFilterCategory.allCases, id: \.self) { category in
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: category.icon)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(glassColorSystem.textSecondary())
                                        Text(category.rawValue)
                                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                            .foregroundStyle(glassColorSystem.textPrimary())
                                    }
                                    
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                                        ForEach(ProjectFilter.filters(for: category), id: \.id) { filter in
                                            FilterOptionButton(
                                                title: filter.displayName,
                                                icon: filter.icon,
                                                isSelected: selectedFilter.id == filter.id,
                                                action: {
                                                    selectedFilter = filter
                                                }
                                            )
                                        }
                                    }
                                }
                            }
                            
                            // Advanced filters
                            if selectedFilter == .hasArea || selectedAreaFilter != nil || selectedFilter == .withTags || !selectedTags.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Advanced Filters")
                                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                        .foregroundStyle(glassColorSystem.textPrimary())
                                    
                                    HStack(spacing: 12) {
                                        if selectedFilter == .hasArea || selectedAreaFilter != nil {
                                            areaFilterDropdown
                                        }
                                        if selectedFilter == .withTags || !selectedTags.isEmpty {
                                            tagFilterDropdown
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Sort Section
                    DrawerSection(title: "Sort Options", icon: "arrow.up.arrow.down.circle") {
                        VStack(alignment: .leading, spacing: 20) {
                            ForEach(ProjectSortCategory.allCases, id: \.self) { category in
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: category.icon)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(glassColorSystem.textSecondary())
                                        Text(category.rawValue)
                                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                            .foregroundStyle(glassColorSystem.textPrimary())
                                    }
                                    
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                                        ForEach(ProjectSortOption.options(for: category), id: \.id) { sort in
                                            SortOptionButton(
                                                title: sort.displayName,
                                                icon: sort.icon,
                                                isSelected: selectedSort.id == sort.id,
                                                action: {
                                                    selectedSort = sort
                                                }
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            sidebar: {
                EmptyView()
            }
        )
    }
    
    private var areaFilterDropdown: some View {
        Menu {
            ForEach(allAreas, id: \.id) { area in
                Button {
                    selectedAreaFilter = area.id
                } label: {
                    HStack {
                        Text(area.title)
                        if selectedAreaFilter == area.id {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text("Area")
                    .font(.system(.caption, design: .rounded))
                Spacer()
                if let areaId = selectedAreaFilter,
                   let area = allAreas.first(where: { $0.id == areaId }) {
                    Text(area.title)
                        .font(.system(.caption, design: .rounded))
                        .lineLimit(1)
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(glassColorSystem.cardColor().opacity(0.4))
            )
        }
    }
    
    private var tagFilterDropdown: some View {
        let allTags = Set(allProjects.flatMap { $0.tags }).sorted()
        
        return Menu {
            ForEach(allTags, id: \.self) { tag in
                Button {
                    if selectedTags.contains(tag) {
                        selectedTags.remove(tag)
                    } else {
                        selectedTags.insert(tag)
                    }
                } label: {
                    HStack {
                        Text(tag)
                        Spacer()
                        if selectedTags.contains(tag) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text("Tags")
                    .font(.system(.caption, design: .rounded))
                Spacer()
                if !selectedTags.isEmpty {
                    Text(selectedTags.count == 1 ? selectedTags.first! : "\(selectedTags.count) tags")
                        .font(.system(.caption, design: .rounded))
                        .lineLimit(1)
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(glassColorSystem.cardColor().opacity(0.4))
            )
        }
    }
}

// MARK: - Helper Views (reuse from Tasks)

private struct FilterOptionButton: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.system(.caption, design: .rounded))
                    .lineLimit(1)
                if isSelected {
                    Spacer()
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? glassColorSystem.cardColor().opacity(0.6) : glassColorSystem.backgroundSecondary().opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isSelected ? glassColorSystem.emotionalAccent().opacity(0.5) : glassColorSystem.borderColor().opacity(0.3), lineWidth: isSelected ? 1.2 : 0.8)
                    )
            )
            .foregroundStyle(isSelected ? glassColorSystem.textPrimary() : glassColorSystem.textSecondary())
        }
        .buttonStyle(.plain)
    }
}

private struct SortOptionButton: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.system(.caption, design: .rounded))
                    .lineLimit(1)
                if isSelected {
                    Spacer()
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? glassColorSystem.cardColor().opacity(0.6) : glassColorSystem.backgroundSecondary().opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isSelected ? glassColorSystem.emotionalAccent().opacity(0.5) : glassColorSystem.borderColor().opacity(0.3), lineWidth: isSelected ? 1.2 : 0.8)
                    )
            )
            .foregroundStyle(isSelected ? glassColorSystem.textPrimary() : glassColorSystem.textSecondary())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    UnifiedProjectsView()
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [FocusOSShared.Project.self, FocusOSShared.Task.self, Area.self])
}

