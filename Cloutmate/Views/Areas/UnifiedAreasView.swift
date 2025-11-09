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
    @State private var showCreateSheet = false
    @State private var selectedArea: Area?
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
        HStack(spacing: 0) {
            // Sidebar
            if !sidebarCollapsed {
                AreasSidebar(
                    areas: allAreas,
                    onAreaSelected: { area in
                        selectedArea = area
                    }
                )
                .transition(.move(edge: .leading))
            }
            
            // Main Content
            VStack(spacing: 0) {
                // Header Zone
                AreasHeaderView(
                    selectedFilter: selectedFilter,
                    searchText: $searchText,
                    onFilterChange: { filter in
                        selectedFilter = filter
                    },
                    onQuickAdd: {
                        showCreateSheet = true
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
                
                // Content Grid
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
                                                selectedArea = area
                                            },
                                            onEdit: {
                                                selectedArea = area
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
        }
        .background(glassColorSystem.backgroundColor())
        .sheet(isPresented: $showCreateSheet) {
            AreaQuickAddSheet()
        }
        .sheet(item: $selectedArea) { area in
            AreaDetailDrawer(
                area: area,
                projects: allProjects,
                notes: allNotes,
                onDismiss: {
                    selectedArea = nil
                },
                onAddProject: {
                    // TODO: Open project creation with area pre-selected
                    selectedArea = nil
                },
                onAddNote: {
                    // TODO: Open note creation with area pre-selected
                    selectedArea = nil
                },
                onArchive: {
                    archiveArea(area)
                    selectedArea = nil
                }
            )
        }
        .onChange(of: searchText) { _, _ in
            // Invalidate stability cache when search changes
            AreaStabilityService.shared.invalidateAllCache()
        }
        .onChange(of: selectedFilter) { _, _ in
            // Invalidate stability cache when filter changes
            AreaStabilityService.shared.invalidateAllCache()
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
}

#Preview {
    UnifiedAreasView()
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [Area.self, CloutmateShared.Project.self, Note.self])
}

