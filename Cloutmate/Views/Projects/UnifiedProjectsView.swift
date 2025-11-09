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
    
    @Query(sort: \CloutmateShared.Project.updatedAt, order: .reverse) private var allProjects: [CloutmateShared.Project]
    @Query private var allTasks: [CloutmateShared.Task]
    @Query private var allAreas: [Area]
    
    @State private var selectedViewMode: ProjectViewMode = .list
    @State private var selectedFilter: ProjectFilter = .all
    @State private var searchText = ""
    @State private var scrollOffset: CGFloat = 0
    @State private var showCreateSheet = false
    @State private var projectToShow: Project?
    @State private var isSelectionMode = false
    @State private var selectedProjectIDs: Set<UUID> = []
    @State private var showFocusDurationSheet = false
    @State private var focusDuration: TimeInterval = 1800 // Default 30 min
    @State private var projectForFocus: Project?
    
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
    
    var headerOpacity: Double {
        let threshold: CGFloat = 50
        return scrollOffset > threshold ? 1.0 : max(0.3, Double(scrollOffset / threshold))
    }
    
    private func projectSelectionActions() -> [SelectionActionBar.Action] {
        var actions: [SelectionActionBar.Action] = []
        
        // Start Focus Session action (only if single project selected)
        if selectedProjects.count == 1, let project = selectedProjects.first {
            actions.append(.init(title: "Start Focus Session", icon: "timer") {
                startFocusSessionForProject(project)
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
        guard selectedViewMode != .timeline else { return }
        if isSelectionMode || !selectedProjectIDs.isEmpty {
            clearSelection()
        } else if !filteredProjects.isEmpty {
            isSelectionMode = true
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
            projectToShow = nil
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
    
    private func startFocusSessionForProject(_ project: Project) {
        projectForFocus = project
        showFocusDurationSheet = true
    }
    
    private func startFocusSession() {
        guard let project = projectForFocus else { return }
        showFocusDurationSheet = false
        
        // Post notification with session parameters instead of starting immediately
        let params = PendingFocusSessionParams(
            objective: project.title,
            plannedDuration: focusDuration,
            targetObjectId: project.id,
            targetObjectType: "project"
        )
        
        projectForFocus = nil
        clearSelection()
        
        // Post session parameters first (will be stored as pending)
        NotificationCenter.default.post(
            name: .startPendingFocusSession,
            object: params
        )
        
        // Switch to focus mode tab (session will start after switch completes)
        NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.focusMode)
    }
    
    private func toggleSelectAll() {
        let allVisibleIDs = Set(filteredProjects.map(\.id))
        if selectedProjectIDs == allVisibleIDs {
            // All selected, deselect all
            clearSelection()
        } else {
            // Not all selected, select all visible
            selectedProjectIDs = allVisibleIDs
            if !isSelectionMode {
                isSelectionMode = true
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Zone
            headerZone
                .opacity(headerOpacity)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: headerOpacity)
            
            Divider()
            
            // Content based on selected view mode
            contentView
        }
        .background(Color(.windowBackgroundColor))
        .sheet(isPresented: $showCreateSheet) {
            CreateProjectSheet()
        }
        .sheet(item: $projectToShow) { project in
            ProjectDetailSheet(project: project)
        }
        .sheet(isPresented: $showFocusDurationSheet) {
            if let project = projectForFocus {
                FocusDurationSheet(
                    selectedDuration: $focusDuration,
                    itemTitle: project.title,
                    itemType: "Project",
                    onStart: {
                        startFocusSession()
                    }
                )
            }
        }
        .overlay(alignment: .bottom) {
            if isSelectionActive {
                SelectionActionBar(
                    count: visibleSelectedProjectCount,
                    itemLabel: "project",
                    actions: projectSelectionActions(),
                    onCancel: clearSelection,
                    onSelectAll: toggleSelectAll,
                    totalItems: filteredProjects.count
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .background(
            Button("New Project") {
                showCreateSheet = true
            }
            .keyboardShortcut("n", modifiers: .command)
            .hidden()
        )
        .onKeyPress(.leftArrow) {
            if let currentIndex = ProjectViewMode.allCases.firstIndex(of: selectedViewMode),
               currentIndex > 0 {
                selectedViewMode = ProjectViewMode.allCases[currentIndex - 1]
                ProjectHaptics.playSelection()
            }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            if let currentIndex = ProjectViewMode.allCases.firstIndex(of: selectedViewMode),
               currentIndex < ProjectViewMode.allCases.count - 1 {
                selectedViewMode = ProjectViewMode.allCases[currentIndex + 1]
                ProjectHaptics.playSelection()
            }
            return .handled
        }
        .accessibilityLabel("Projects view")
        .accessibilityHint("Use arrow keys to switch between views. Press Command+N to create a new project.")
        .onChange(of: searchText) { _, _ in
            pruneSelection()
        }
        .onChange(of: selectedFilter) { _, _ in
            pruneSelection()
        }
        .onChange(of: selectedViewMode) { _, newValue in
            if newValue == .timeline {
                clearSelection()
            } else {
                pruneSelection()
            }
        }
    }
    
    // MARK: - Header Zone
    
    private var headerZone: some View {
        HStack(alignment: .top, spacing: 20) {
            // Title & Count
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Text("Projects")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(glassColorSystem.textPrimary())
                    
                    if activeProjectsCount > 0 {
                        Text("\(activeProjectsCount) active")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.kosmicBlue.opacity(0.2))
                            .foregroundColor(.kosmicBlue)
                            .cornerRadius(8)
                    }
                }
            }
            
            Spacer()
            
            // Filter Dropdown
            Menu {
                ForEach(ProjectFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        selectedFilter = filter
                        ProjectHaptics.playSelection()
                    }) {
                        Label(filter.displayName, systemImage: selectedFilter == filter ? "checkmark" : "")
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.caption)
                    Text(selectedFilter.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(glassColorSystem.glassTint(for: .surface).opacity(0.3))
                .foregroundColor(glassColorSystem.textPrimary())
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            // View Selector
            HStack(spacing: 4) {
                ForEach(ProjectViewMode.allCases, id: \.self) { mode in
                    Button(action: {
                        selectedViewMode = mode
                        ProjectHaptics.playSelection()
                    }) {
                        Image(systemName: mode.icon)
                            .font(.caption)
                            .foregroundColor(selectedViewMode == mode ? .kosmicBlue : glassColorSystem.textSecondary())
                            .frame(width: 32, height: 32)
                            .background(
                                selectedViewMode == mode ?
                                Color.kosmicBlue.opacity(0.2) :
                                glassColorSystem.glassTint(for: .surface).opacity(0.2)
                            )
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            GlassButton(
                icon: isSelectionActive ? "checkmark.circle.fill" : "checkmark.circle",
                style: .iconOnly,
                role: .surface
            ) {
                toggleSelectionMode()
            }
            .accessibilityLabel(isSelectionActive ? "Exit selection mode" : "Enter selection mode")
            .help(isSelectionActive ? "Done Selecting" : "Select Projects")
            .opacity(selectedViewMode == .timeline ? 0.5 : 1.0)
            .disabled(selectedViewMode == .timeline)
            
            // Quick Create Button
            Button(action: {
                showCreateSheet = true
                ProjectHaptics.playSelection()
            }) {
                Image(systemName: "plus")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.kosmicBlue)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Create New Project (⌘N)")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            GlassPanel(tier: .overlay, cornerRadius: 0) {
                EmptyView()
            }
            .ignoresSafeArea(edges: .top)
        )
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
                    }
                    .frame(height: 0)
                    
                    Group {
                        switch selectedViewMode {
                        case .list:
                            ProjectListView(
                                projects: filteredProjects,
                                tasks: allTasks,
                                areas: allAreas,
                                selectionMode: isSelectionActive,
                                selectedProjectIDs: selectedProjectIDs,
                                onSelectionToggle: { project in toggleProjectSelection(project) },
                                onProjectSelected: { project in
                                    projectToShow = project
                                },
                                onDuplicateProject: { project in duplicateProject(project) },
                                onArchiveProject: { project in archiveProject(project) },
                                onDeleteProject: { project in deleteProject(project) }
                            )
                        case .board:
                            ProjectBoardView(
                                projects: filteredProjects,
                                tasks: allTasks,
                                areas: allAreas,
                                selectionMode: isSelectionActive,
                                selectedProjectIDs: selectedProjectIDs,
                                onSelectionToggle: { project in toggleProjectSelection(project) },
                                onProjectSelected: { project in
                                    projectToShow = project
                                },
                                onDuplicateProject: { project in duplicateProject(project) },
                                onArchiveProject: { project in archiveProject(project) },
                                onDeleteProject: { project in deleteProject(project) }
                            )
                        case .timeline:
                            ProjectTimelineView(
                                projects: filteredProjects,
                                tasks: allTasks,
                                areas: allAreas,
                                onProjectSelected: { project in
                                    projectToShow = project
                                }
                            )
                        case .gallery:
                            ProjectGalleryView(
                                projects: filteredProjects,
                                tasks: allTasks,
                                areas: allAreas,
                                selectionMode: isSelectionActive,
                                selectedProjectIDs: selectedProjectIDs,
                                onSelectionToggle: { project in toggleProjectSelection(project) },
                                onProjectSelected: { project in
                                    projectToShow = project
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = -value
            }
        }
    }
}

// MARK: - Project Detail Sheet

struct ProjectDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let project: Project
    
    var body: some View {
        NavigationStack {
            ProjectDetailView(project: project)
                .navigationTitle(project.title)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

#Preview {
    UnifiedProjectsView()
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [CloutmateShared.Project.self, CloutmateShared.Task.self, Area.self])
}

