//
//  UnifiedArchivesView.swift
//  Cloutmate
//
//  Archives V2 - Unified archive view
//

import SwiftUI
import SwiftData
import CloutmateShared

struct UnifiedArchivesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @Query private var projects: [CloutmateShared.Project]
    @Query private var areas: [Area]
    @Query private var notes: [CloutmateShared.Note]
    @Query private var artifacts: [CloutmateShared.Artifact]
    @Query private var drafts: [Draft]
    @Query private var reflections: [ArchiveReflection]
    
    @State private var searchText = ""
    @State private var selectedFilter: ArchiveFilter = .all
    @State private var selectedDateRange: ArchivesSidebar.DateRangeFilter = .allTime
    @State private var selectedToneFilter: EmotionalState? = nil
    @State private var showReviewSummary = false
    @State private var showRestoreMenu = false
    @State private var selectedArchiveItem: ArchiveItem?
    @State private var showDetailDrawer = false
    @State private var sidebarCollapsed = false
    @State private var scrollOffset: CGFloat = 0
    
    var filteredArchivedItems: [ArchiveItem] {
        var items: [ArchiveItem] = []
        
        // Collect archived items based on filter
        if selectedFilter == .all || selectedFilter == .projects {
            items.append(contentsOf: projects
                .filter { $0.status == .completed || $0.status == .paused }
                .map { .project($0) })
        }
        
        if selectedFilter == .all || selectedFilter == .areas {
            items.append(contentsOf: areas
                .filter { $0.status == .archived }
                .map { .area($0) })
        }
        
        if selectedFilter == .all || selectedFilter == .notes {
            items.append(contentsOf: notes
                .filter { $0.isArchived }
                .map { .note($0) })
        }
        
        if selectedFilter == .all || selectedFilter == .artifacts {
            items.append(contentsOf: artifacts
                .filter { $0.artifactState == .archived }
                .map { .artifact($0) })
        }
        
        if selectedFilter == .all || selectedFilter == .drafts {
            items.append(contentsOf: drafts
                .filter { $0.isArchived }
                .map { .draft($0) })
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            items = items.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply date range filter
        if let interval = dateInterval(for: selectedDateRange) {
            items = items.filter { item in
                guard let archived = item.archivedAt ?? item.getCreatedAt() else { return false }
                return interval.contains(archived)
            }
        }
        
        // Apply tone filter
        if let tone = selectedToneFilter {
            let reflectionsById = Dictionary(uniqueKeysWithValues: reflections.map { ($0.entityId, $0) })
            items = items.filter { item in
                guard let snapshot = reflectionsById[item.id]?.arteToneSnapshot,
                      let state = EmotionalState(rawValue: snapshot) else {
                    return false
                }
                return state == tone
            }
        }
        
        // Sort by archived date (most recent first)
        return items.sorted { item1, item2 in
            let date1 = item1.archivedAt ?? item1.getCreatedAt() ?? Date.distantPast
            let date2 = item2.archivedAt ?? item2.getCreatedAt() ?? Date.distantPast
            return date1 > date2
        }
    }
    
    var body: some View {
        ZStack {
            V2GlassContentScaffold(
                accentGradient: AuroraPalette.linearGradient(for: colorScheme),
                showsSidebar: !sidebarCollapsed,
                sidebarWidth: 320,
                header: { headerBar },
                content: { archivesContent },
                sidebar: { sidebarContent }
            )
            .opacity(showDetailDrawer || showReviewSummary ? 0 : 1)
            
            // Drawer overlays
            if showDetailDrawer, let item = selectedArchiveItem {
                ArchiveDetailDrawer(
                    archiveItem: item,
                    isPresented: $showDetailDrawer,
                    onRestore: {
                        restoreItem(item)
                        showDetailDrawer = false
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            
            if showReviewSummary {
                ArchiveReviewSheet(isPresented: $showReviewSummary)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(GlassMotion.Easing.spring, value: selectedFilter)
        .animation(GlassMotion.Easing.spring, value: searchText)
        .animation(GlassMotion.Easing.spring, value: filteredArchivedItems.count)
        .animation(GlassMotion.Easing.modalOpen, value: showDetailDrawer)
        .animation(GlassMotion.Easing.modalOpen, value: showReviewSummary)
    }
    
    // MARK: - Header Bar
    
    private var headerBar: some View {
        V2GlassHeaderBar(
            title: "Archives",
            subtitle: "Everything you've completed, remembered, and learned."
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
            // Trailing accessory - quick actions
            HStack(spacing: 12) {
                GlassButton(
                    icon: "chart.bar",
                    style: .iconOnly,
                    role: .primary,
                    tintColor: .kosmicBlue,
                    action: {
                        showReviewSummary = true
                    }
                )
                .frame(width: 32, height: 32)
                .help("Review Summary")
            }
        }
    }
    
    // MARK: - Content
    
    private var archivesContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 28) {
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
                    }
                    .frame(height: 0)
                    
                    filterPanel
                    
                if filteredArchivedItems.isEmpty {
                    ContentUnavailableView(
                        "No Archived Items",
                        systemImage: "archivebox",
                        description: Text("Items you complete or archive will appear here")
                    )
                    .frame(maxHeight: .infinity)
                        .padding(.top, 100)
                } else {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 320, maximum: 400), spacing: 16)
                        ], spacing: 16) {
                            ForEach(filteredArchivedItems, id: \.id) { item in
                                ArchiveCardV2(
                                    archiveItem: item,
                                    onTap: {
                                        selectedArchiveItem = item
                                        withAnimation(GlassMotion.Easing.modalOpen) {
                                        showDetailDrawer = true
                                        }
                                    },
                                    onRestore: {
                                        restoreItem(item)
                                    },
                                    onDelete: {
                                        deleteItem(item)
                                    }
                                )
                                .transition(.opacity.combined(with: .scale))
                            }
                        }
                    }
                }
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = -value
                }
            }
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
                    
                    TextField("Search memories or milestones…", text: $searchText)
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
                        ForEach(ArchiveFilter.allCases, id: \.self) { filter in
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
    
    // MARK: - Sidebar
    
    private var sidebarContent: some View {
        ArchivesSidebar(
            selectedTypeFilter: $selectedFilter,
            selectedDateRange: $selectedDateRange,
            selectedToneFilter: $selectedToneFilter
        )
    }
    
    private func restoreItem(_ item: ArchiveItem) {
        _Concurrency.Task { @MainActor in
            do {
                try await ArchiveReintegrationService.shared.reintegrate(
                    item: item,
                    modelContext: modelContext
                )
            } catch {
                print("Failed to restore item: \(error)")
            }
        }
    }
    
    private func deleteItem(_ item: ArchiveItem) {
        switch item {
        case .project(let project):
            modelContext.delete(project)
        case .area(let area):
            modelContext.delete(area)
        case .note(let note):
            modelContext.delete(note)
        case .artifact(let artifact):
            modelContext.delete(artifact)
        case .draft(let draft):
            modelContext.delete(draft)
        }
        try? modelContext.save()
    }
    
    private func dateInterval(for filter: ArchivesSidebar.DateRangeFilter) -> DateInterval? {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        
        switch filter {
        case .thisWeek:
            guard let start = calendar.date(byAdding: .day, value: -6, to: startOfToday) else { return nil }
            return DateInterval(start: start, end: now)
        case .thisMonth:
            guard let start = calendar.date(byAdding: .day, value: -29, to: startOfToday) else { return nil }
            return DateInterval(start: start, end: now)
        case .thisYear:
            guard let start = calendar.date(byAdding: .day, value: -364, to: startOfToday) else { return nil }
            return DateInterval(start: start, end: now)
        case .allTime:
            return nil
        }
    }
}

extension ArchiveItem {
    func getCreatedAt() -> Date? {
        switch self {
        case .project(let p): return p.createdAt
        case .area(let a): return a.createdAt
        case .note(let n): return n.createdAt
        case .artifact(let a): return a.createdAt
        case .draft(let d): return d.createdAt
        }
    }
}

#Preview {
    UnifiedArchivesView()
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [
            CloutmateShared.Project.self,
            Area.self,
            CloutmateShared.Note.self,
            CloutmateShared.Artifact.self,
            Draft.self,
            ArchiveReflection.self
        ])
}

