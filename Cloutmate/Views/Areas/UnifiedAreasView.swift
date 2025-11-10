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
    
    @State private var selectedFilter: AreaFilter = .all
    @State private var searchText = ""
    @State private var scrollOffset: CGFloat = 0
    @State private var activeArea: Area?
    @State private var isDrawerVisible = false
    @State private var isCreatingArea = false
    @State private var sidebarCollapsed = false
    
    var filteredAreas: [Area] {
        var filtered = allAreas
        
        // Filter by status
        if selectedFilter != .all {
            switch selectedFilter {
            case .active:
                filtered = filtered.filter { $0.status == .active }
            case .reviewNeeded:
                filtered = filtered.filter { $0.status == .reviewNeeded }
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
                                                }
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
                .opacity(isDrawerVisible ? 0 : 1)
            }
            .background(glassColorSystem.backgroundColor())
            
            if let area = activeArea, isDrawerVisible {
                AreaDetailDrawer(
                    area: area,
                    projects: allProjects,
                    notes: allNotes,
                    onDismiss: {
                        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                            isDrawerVisible = false
                        }
                    },
                    onAddProject: {
                        NotificationCenter.default.post(name: .openEntity, object: TabIdentifier.projects)
                        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                            isDrawerVisible = false
                        }
                    },
                    onAddNote: {
                        NotificationCenter.default.post(name: .openEntity, object: TabIdentifier.notes)
                        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                            isDrawerVisible = false
                        }
                    },
                    onArchive: {
                        archiveArea(area)
                        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                            isDrawerVisible = false
                        }
                    }
                )
                .transition(.move(edge: .trailing))
            }
        }
        .onChange(of: searchText) { _, _ in
            // Invalidate stability cache when search changes
            AreaStabilityService.shared.invalidateAllCache()
        }
        .onChange(of: selectedFilter) { _, _ in
            // Invalidate stability cache when filter changes
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
    }
    
    private func archiveArea(_ area: Area) {
        area.status = .archived
        area.updatedAt = Date()
        try? modelContext.save()
        AreaStabilityService.shared.invalidateCache(for: area.id)
    }
    
    private func deleteArea(_ area: Area) {
        modelContext.delete(area)
        try? modelContext.save()
        AreaStabilityService.shared.invalidateCache(for: area.id)
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
        guard !isSelectionMode else { return }
        activeArea = area
        isCreatingArea = false
        
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isDrawerVisible = true
        }
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
}

#Preview {
    UnifiedAreasView()
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [Area.self, CloutmateShared.Project.self, Note.self])
}

