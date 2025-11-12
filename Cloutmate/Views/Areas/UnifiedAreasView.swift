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
    
    @Query(sort: \Area.updatedAt, order: .reverse) private var allAreas: [Area]
    @Query private var allProjects: [CloutmateShared.Project]
    @Query private var allNotes: [Note]
    @Query private var allTasks: [CloutmateShared.Task]
    
    @State private var selectedFilter: AreaFilter = .all
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
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                if !sidebarCollapsed {
                    AreasSidebar(
                        areas: allAreas,
                        onAreaSelected: { area in
                            openDrawer(for: area)
                        }
                    )
                    .transition(.move(edge: .leading))
                }
                
                VStack(spacing: 0) {
                    AreasHeaderView(
                        selectedFilter: selectedFilter,
                        searchText: $searchText,
                        onFilterChange: { filter in
                            selectedFilter = filter
                        },
                        onQuickAdd: {
                            startCreatingArea()
                        },
                        sidebarCollapsed: sidebarCollapsed,
                        onToggleSidebar: {
                            withAnimation(reduceMotion ? nil : GlassMotion.Easing.spring) {
                                sidebarCollapsed.toggle()
                            }
                        }
                    )
                    .opacity(headerOpacity)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: headerOpacity)
                    
                    Divider()
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 0) {
                                GeometryReader { geometry in
                                    Color.clear
                                        .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
                                }
                                .frame(height: 0)
                                
                                if !areasNeedingReview.isEmpty {
                                    AreasReviewSummaryCard(
                                        items: areasNeedingReview,
                                        onSelect: { area in
                                            openReviewDrawer(for: area)
                                        }
                                    )
                                    .padding(.horizontal, 20)
                                    .padding(.top, 20)
                                }
                                
                                if sortedAreas.isEmpty {
                                    ContentUnavailableView(
                                        "No Areas",
                                        systemImage: "rectangle.stack",
                                        description: Text(filteredAreas.isEmpty && !searchText.isEmpty ? "Try a different search" : "Create your first area to get started")
                                    )
                                    .frame(maxHeight: .infinity)
                                    .padding(.top, 100)
                                } else {
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
                                    .padding(20)
                                }
                            }
                        }
                        .coordinateSpace(name: "scroll")
                        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                            scrollOffset = -value
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .opacity(isDrawerVisible || reviewDrawerVisible ? 0 : 1)
            }
            .background(glassColorSystem.backgroundColor())
            
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

