//
//  UnifiedAreasView.swift
//  Cloutmate
//
//  Areas V2 - Unified view orchestrating header, cards, sidebar, and filtering
//

import SwiftUI
import SwiftData
import CloutmateShared

struct UnifiedAreasView: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    
    @Query(sort: \Area.updatedAt, order: .reverse) private var allAreas: [Area]
    @Query private var allProjects: [CloutmateShared.Project]
    @Query private var allNotes: [Note]
    @Query private var allTasks: [CloutmateShared.Task]
    
    @State private var selectedFilter: AreaFilter = .all
    @State private var selectedViewMode: AreaViewMode = .grid
    @State private var searchText = ""
    @State private var scrollOffset: CGFloat = 0
    @State private var activeArea: Area?
    @State private var isDrawerVisible = false
    @State private var isCreatingArea = false
    @State private var sidebarCollapsed = false
    @State private var reviewArea: Area?
    @State private var reviewSummary: AreaReviewSummary?
    @State private var reviewDrawerVisible = false
    
    var filteredAreas: [Area] {
        var filtered = allAreas
        
        // Filter by status
        if selectedFilter != .all {
            switch selectedFilter {
            case .active:
                filtered = filtered.filter { $0.status == .active }
            case .reviewNeeded:
                filtered = filtered.filter { AreaReviewService.shared.status(for: $0).isDue }
            case .archived:
                filtered = filtered.filter { $0.status == .archived }
            case .all:
                break
            }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { area in
                area.title.localizedCaseInsensitiveContains(searchText) ||
                (area.notes?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                area.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        return filtered
    }
    
    var sortedAreas: [Area] {
        filteredAreas.sorted { area1, area2 in
            // Sort by updatedAt (most recent first)
            area1.updatedAt > area2.updatedAt
        }
    }
    
    var areasNeedingReview: [(Area, AreaReviewStatus)] {
        allAreas
            .filter { $0.status != .archived }
            .map { area in (area, AreaReviewService.shared.status(for: area)) }
            .filter { $0.1.isDue }
            .sorted { lhs, rhs in
                let leftOverdue = lhs.1.overdueDays ?? 0
                let rightOverdue = rhs.1.overdueDays ?? 0
                if leftOverdue == rightOverdue {
                    return lhs.0.updatedAt < rhs.0.updatedAt
                }
                return leftOverdue > rightOverdue
            }
    }
    
    var headerOpacity: Double {
        let threshold: CGFloat = 50
        return scrollOffset > threshold ? 1.0 : max(0.3, Double(scrollOffset / threshold))
    }
    
    // MARK: - Header Bar
    
    private var headerBar: some View {
        V2GlassHeaderBar(
            title: "Areas",
            subtitle: "Your ongoing domains of focus"
        ) {
            // Leading accessory - sidebar toggle
            Button(action: {
                withAnimation(reduceMotion ? nil : GlassMotion.Easing.spring) {
                    sidebarCollapsed.toggle()
                }
            }) {
                Image(systemName: sidebarCollapsed ? "sidebar.right" : "sidebar.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(glassColorSystem.textSecondary())
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .help(sidebarCollapsed ? "Show Sidebar" : "Hide Sidebar")
        } trailingAccessory: {
            // Trailing accessory - view mode selector and quick add
            HStack(spacing: 12) {
                // View mode selector
                viewModeSelector
                
                // Quick Add button
                GlassButton(
                    icon: "plus",
                    style: .iconOnly,
                    role: .primary,
                    tintColor: .kosmicBlue,
                    action: {
                            startCreatingArea()
                    }
                )
                .frame(width: 32, height: 32)
            }
        }
    }
    
    // MARK: - View Mode Selector
    
    private var viewModeSelector: some View {
        HStack(spacing: 6) {
            ForEach(AreaViewMode.allCases, id: \.self) { mode in
                modeButton(for: mode)
            }
        }
    }
    
    @ViewBuilder
    private func modeButton(for mode: AreaViewMode) -> some View {
        let isSelected = selectedViewMode == mode
        Button {
                            withAnimation(reduceMotion ? nil : GlassMotion.Easing.spring) {
                selectedViewMode = mode
            }
            if !reduceMotion {
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
            }
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
                                .fill(glassColorSystem.backgroundSecondary().opacity(0.4))
                        }
                    }
                }
        }
        .buttonStyle(.plain)
        .help(mode.displayName)
    }
    
    // MARK: - Filter Panel
    
    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(glassColorSystem.textSecondary().opacity(0.75))
                    
                    TextField("Search areas", text: $searchText)
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
                
                Spacer()
                
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(AreaFilter.allCases, id: \.self) { filter in
                            FilterPill(
                                title: filter.rawValue,
                                isSelected: selectedFilter == filter,
                                action: {
                                    withAnimation(GlassMotion.Easing.spring) {
                                        selectedFilter = filter
                                    }
                                    if !reduceMotion {
                                        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Content
    
    private var areasContent: some View {
                    ScrollViewReader { proxy in
                        ScrollView {
                VStack(spacing: 28) {
                                GeometryReader { geometry in
                                    Color.clear
                                        .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
                                }
                                .frame(height: 0)
                    
                    filterPanel
                                
                                if !areasNeedingReview.isEmpty {
                                    AreasReviewSummaryCard(
                                        items: areasNeedingReview,
                                        onSelect: { area in
                                            openReviewDrawer(for: area)
                                        }
                                    )
                    }
                    
                    activeModeView
                }
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = -value
            }
        }
    }
    
    @ViewBuilder
    private var activeModeView: some View {
                                if sortedAreas.isEmpty {
                                    ContentUnavailableView(
                                        "No Areas",
                                        systemImage: "rectangle.stack",
                                        description: Text(filteredAreas.isEmpty && !searchText.isEmpty ? "Try a different search" : "Create your first area to get started")
                                    )
                                    .frame(maxHeight: .infinity)
                                    .padding(.top, 100)
                                } else {
            switch selectedViewMode {
            case .grid:
                                    LazyVGrid(
                                        columns: [
                                            GridItem(.adaptive(minimum: 320, maximum: 400), spacing: 16)
                                        ],
                                        spacing: 16
                                    ) {
                                        ForEach(sortedAreas) { area in
                                            let reviewStatus = AreaReviewService.shared.status(for: area)
                                            AreaCardV2(
                                                area: area,
                                                projects: allProjects,
                                                notes: allNotes,
                                                onTap: {
                                                    openDrawer(for: area)
                                                },
                                                onEdit: {
                                                    openDrawer(for: area)
                                                },
                                                onArchive: {
                                                    archiveArea(area)
                                                },
                                                onDelete: {
                                                    deleteArea(area)
                                                },
                                                isReviewDue: reviewStatus.isDue,
                                                onReview: reviewStatus.isDue ? {
                                                    openReviewDrawer(for: area)
                                                } : nil
                                            )
                                        }
                                    }
            case .list:
                VStack(spacing: 12) {
                    ForEach(sortedAreas) { area in
                        let reviewStatus = AreaReviewService.shared.status(for: area)
                        AreaListCard(
                            area: area,
                            projects: allProjects,
                            notes: allNotes,
                            onTap: {
                                openDrawer(for: area)
                            },
                            isReviewDue: reviewStatus.isDue,
                            onReview: reviewStatus.isDue ? {
                                openReviewDrawer(for: area)
                            } : nil
                        )
                    }
                }
            case .board:
                AreaBoardView(
                    areas: sortedAreas,
                    projects: allProjects,
                    notes: allNotes,
                    onAreaSelected: { area in
                        openDrawer(for: area)
                    }
                )
            case .overview:
                AreaOverviewView(
                    areas: sortedAreas,
                    projects: allProjects,
                    notes: allNotes,
                    tasks: allTasks,
                    onAreaSelected: { area in
                        openDrawer(for: area)
                    }
                )
            }
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebarContent: some View {
        AreasSidebar(
            areas: allAreas,
            onAreaSelected: { area in
                openDrawer(for: area)
            }
        )
    }
    
    var body: some View {
        ZStack {
            V2GlassContentScaffold(
                accentGradient: AuroraPalette.linearGradient(for: colorScheme),
                showsSidebar: !sidebarCollapsed,
                sidebarWidth: 320,
                header: { headerBar },
                content: { areasContent },
                sidebar: { sidebarContent }
            )
                .opacity(isDrawerVisible || reviewDrawerVisible ? 0 : 1)
            
            if let area = activeArea, isDrawerVisible {
                AreaDetailDrawer(
                    area: area,
                    projects: allProjects,
                    notes: allNotes,
                    tasks: allTasks,
                    onDismiss: {
                        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                            isDrawerVisible = false
                        }
                    },
                    onArchive: {
                        archiveArea(area)
                        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                            isDrawerVisible = false
                        }
                    },
                    onOpenProject: { project in
                        navigateTo(tab: .projects, id: project.id, type: .project)
                    },
                    onOpenNote: { note in
                        navigateTo(tab: .notes, id: note.id, type: .note)
                    },
                    onOpenTask: { task in
                        navigateTo(tab: .tasks, id: task.id, type: .task)
                    }
                )
                .transition(.move(edge: .trailing))
            }
            
            if reviewDrawerVisible, let area = reviewArea, let summary = reviewSummary {
                AreaReviewDrawer(
                    area: area,
                    summary: summary,
                    tasks: allTasks,
                    projects: allProjects,
                    notes: allNotes,
                    onClose: closeReviewDrawer,
                    onMarkReviewed: { notes in
                        AreaReviewService.shared.markReviewed(area: area, modelContext: modelContext, note: notes)
                        syncReviewStatuses()
                        closeReviewDrawer()
                    },
                    onSnooze: { days in
                        AreaReviewService.shared.snoozeReview(area: area, by: days, modelContext: modelContext)
                        syncReviewStatuses()
                        closeReviewDrawer()
                    },
                    onOpenProject: { project in
                        navigateTo(tab: .projects, id: project.id, type: .project)
                    },
                    onOpenTask: { task in
                        navigateTo(tab: .tasks, id: task.id, type: .task)
                    },
                    onOpenNote: { note in
                        navigateTo(tab: .notes, id: note.id, type: .note)
                    }
                )
                .transition(.move(edge: .trailing))
            }
        }
        .onChange(of: searchText) { _, _ in
            AreaStabilityService.shared.invalidateAllCache()
        }
        .onChange(of: selectedFilter) { _, _ in
            AreaStabilityService.shared.invalidateAllCache()
        }
        .onChange(of: isDrawerVisible) { _, newValue in
            if !newValue, let area = activeArea {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if !isDrawerVisible {
                        cleanupIfNecessary(area)
                        activeArea = nil
                        isCreatingArea = false
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAreaDetail)) { notification in
            if let area = notification.object as? Area {
                openDrawer(for: area)
            } else {
                startCreatingArea()
            }
        }
        .task {
            syncReviewStatuses()
        }
    }
    
    private func archiveArea(_ area: Area) {
        area.status = .archived
        area.updatedAt = Date()
        try? modelContext.save()
        AreaStabilityService.shared.invalidateCache(for: area.id)
        syncReviewStatuses()
    }
    
    private func deleteArea(_ area: Area) {
        modelContext.delete(area)
        try? modelContext.save()
        AreaStabilityService.shared.invalidateCache(for: area.id)
        syncReviewStatuses()
    }
    
    private func startCreatingArea() {
        guard !isDrawerVisible else { return }
        
        let newArea = Area(title: "")
        modelContext.insert(newArea)
        activeArea = newArea
        isCreatingArea = true
        
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isDrawerVisible = true
        }
    }
    
    private func openDrawer(for area: Area) {
        activeArea = area
        isCreatingArea = false
        
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isDrawerVisible = true
        }
    }
    
    private func openReviewDrawer(for area: Area) {
        reviewArea = area
        reviewSummary = AreaReviewService.shared.summary(
            for: area,
            tasks: allTasks,
            projects: allProjects,
            notes: allNotes
        )
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            reviewDrawerVisible = true
        }
    }
    
    private func closeReviewDrawer() {
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            reviewDrawerVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if !reviewDrawerVisible {
                reviewArea = nil
                reviewSummary = nil
            }
        }
        syncReviewStatuses()
    }
    
    private func cleanupIfNecessary(_ area: Area) {
        guard isCreatingArea else { return }
        let trimmedTitle = area.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = (area.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty && trimmedNotes.isEmpty && area.tags.isEmpty {
            modelContext.delete(area)
            try? modelContext.save()
        } else {
            try? modelContext.save()
        }
    }
    
    private func syncReviewStatuses() {
        for area in allAreas where area.status != .archived {
            AreaReviewService.shared.syncStatus(for: area, modelContext: modelContext)
        }
    }
    
    private func navigateTo(tab: TabIdentifier, id: UUID, type: ObjectType) {
        NotificationCenter.default.post(name: .switchTab, object: tab)
        NotificationCenter.default.post(
            name: .openEntity,
            object: nil,
            userInfo: ["id": id, "type": type.rawValue]
        )
    }
}

#Preview {
    UnifiedAreasView()
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [Area.self, CloutmateShared.Project.self, CloutmateShared.Task.self, Note.self])
}

