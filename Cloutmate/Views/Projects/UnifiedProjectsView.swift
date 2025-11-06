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
    
    var headerOpacity: Double {
        let threshold: CGFloat = 50
        return scrollOffset > threshold ? 1.0 : max(0.3, Double(scrollOffset / threshold))
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
                                onProjectSelected: { project in
                                    projectToShow = project
                                }
                            )
                        case .board:
                            ProjectBoardView(
                                projects: filteredProjects,
                                tasks: allTasks,
                                areas: allAreas,
                                onProjectSelected: { project in
                                    projectToShow = project
                                }
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

