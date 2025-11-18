//
//  UnifiedAreasView.swift
//  FocusOS
//
//  Areas V2 - Unified view orchestrating header, cards, sidebar, and filtering
//

import SwiftUI
import SwiftData
import FocusOSShared

struct UnifiedAreasView: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    
    @Query(sort: \Area.updatedAt, order: .reverse) private var allAreas: [Area]
    @Query private var allProjects: [FocusOSShared.Project]
    @Query private var allNotes: [Note]
    @Query private var allTasks: [FocusOSShared.Task]
    
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
    @State private var isFilterSortDrawerVisible = false
    
    // Sort persistence
    @AppStorage("areas.sort") private var sortOption: String = AreaSortOption.updatedAtDesc.rawValue
    
    private var currentSortOption: AreaSortOption {
        AreaSortOption(rawValue: sortOption) ?? .updatedAtDesc
    }
    
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
        sortAreas(filteredAreas, by: currentSortOption)
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
            
            // Most common sorts (3 max)
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Sort")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
                
                HStack(spacing: 10) {
                    quickSortButton(.updatedAtDesc)
                    quickSortButton(.titleAsc)
                    quickSortButton(.stabilityHighToLow)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func sortAreas(_ areas: [Area], by option: AreaSortOption) -> [Area] {
        var sorted = areas
        
        switch option {
        // Date & Time
        case .updatedAtDesc:
            sorted.sort { $0.updatedAt > $1.updatedAt }
        case .updatedAtAsc:
            sorted.sort { $0.updatedAt < $1.updatedAt }
        case .createdAtDesc:
            sorted.sort { $0.createdAt > $1.createdAt }
        case .createdAtAsc:
            sorted.sort { $0.createdAt < $1.createdAt }
        case .lastReviewDateDesc:
            sorted.sort { area1, area2 in
                guard let date1 = area1.lastReviewDate else { return false }
                guard let date2 = area2.lastReviewDate else { return true }
                return date1 > date2
            }
        case .lastReviewDateAsc:
            sorted.sort { area1, area2 in
                guard let date1 = area1.lastReviewDate else { return false }
                guard let date2 = area2.lastReviewDate else { return true }
                return date1 < date2
            }
        case .archivedAtDesc:
            sorted.sort { area1, area2 in
                guard let date1 = area1.archivedAt else { return false }
                guard let date2 = area2.archivedAt else { return true }
                return date1 > date2
            }
        case .archivedAtAsc:
            sorted.sort { area1, area2 in
                guard let date1 = area1.archivedAt else { return false }
                guard let date2 = area2.archivedAt else { return true }
                return date1 < date2
            }
        
        // Alphabetical
        case .titleAsc:
            sorted.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .titleDesc:
            sorted.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        
        // Status
        case .statusActiveFirst:
            sorted.sort { area1, area2 in
                if area1.status == area2.status {
                    return area1.updatedAt > area2.updatedAt
                }
                let order: [AreaStatus] = [.active, .reviewNeeded, .archived]
                let index1 = order.firstIndex(of: area1.status) ?? 999
                let index2 = order.firstIndex(of: area2.status) ?? 999
                return index1 < index2
            }
        case .statusArchivedFirst:
            sorted.sort { area1, area2 in
                if area1.status == area2.status {
                    return area1.updatedAt > area2.updatedAt
                }
                let order: [AreaStatus] = [.archived, .reviewNeeded, .active]
                let index1 = order.firstIndex(of: area1.status) ?? 999
                let index2 = order.firstIndex(of: area2.status) ?? 999
                return index1 < index2
            }
        case .reviewNeededFirst:
            sorted.sort { area1, area2 in
                let review1 = AreaReviewService.shared.status(for: area1).isDue
                let review2 = AreaReviewService.shared.status(for: area2).isDue
                if review1 == review2 {
                    return area1.updatedAt > area2.updatedAt
                }
                return review1 && !review2
            }
        
        // Stability
        case .stabilityHighToLow:
            sorted.sort { area1, area2 in
                if area1.stabilityScore == area2.stabilityScore {
                    return area1.updatedAt > area2.updatedAt
                }
                return area1.stabilityScore > area2.stabilityScore
            }
        case .stabilityLowToHigh:
            sorted.sort { area1, area2 in
                if area1.stabilityScore == area2.stabilityScore {
                    return area1.updatedAt > area2.updatedAt
                }
                return area1.stabilityScore < area2.stabilityScore
            }
        
        // Tags
        case .tagCountDesc:
            sorted.sort { area1, area2 in
                if area1.tags.count == area2.tags.count {
                    return area1.updatedAt > area2.updatedAt
                }
                return area1.tags.count > area2.tags.count
            }
        case .tagCountAsc:
            sorted.sort { area1, area2 in
                if area1.tags.count == area2.tags.count {
                    return area1.updatedAt > area2.updatedAt
                }
                return area1.tags.count < area2.tags.count
            }
        
        // Combined
        case .statusThenUpdated:
            sorted.sort { area1, area2 in
                if area1.status != area2.status {
                    let order: [AreaStatus] = [.active, .reviewNeeded, .archived]
                    let index1 = order.firstIndex(of: area1.status) ?? 999
                    let index2 = order.firstIndex(of: area2.status) ?? 999
                    return index1 < index2
                }
                return area1.updatedAt > area2.updatedAt
            }
        case .stabilityThenUpdated:
            sorted.sort { area1, area2 in
                if area1.stabilityScore != area2.stabilityScore {
                    return area1.stabilityScore > area2.stabilityScore
                }
                return area1.updatedAt > area2.updatedAt
            }
        }
        
        return sorted
    }
    
    @ViewBuilder
    private func quickSortButton(_ sort: AreaSortOption) -> some View {
        Button {
            sortOption = sort.rawValue
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
    
    @ViewBuilder
    private func sortCategoryMenu(for category: AreaSortCategory) -> some View {
        let options = AreaSortOption.options(for: category)
        let currentOptionInCategory = options.first { $0 == currentSortOption }
        let isActive = currentOptionInCategory != nil
        
        Menu {
            ForEach(options) { option in
                Button {
                    sortOption = option.rawValue
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
                .opacity(isDrawerVisible || reviewDrawerVisible || isFilterSortDrawerVisible ? 0 : 1)
            
            if isFilterSortDrawerVisible {
                AreaFilterSortDrawer(
                    isPresented: $isFilterSortDrawerVisible,
                    selectedSort: $sortOption
                )
                .transition(.move(edge: .trailing))
            }
            
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

// MARK: - Area Filter Sort Drawer

struct AreaFilterSortDrawer: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @Binding var isPresented: Bool
    @Binding var selectedSort: String
    
    private var currentSortOption: AreaSortOption {
        AreaSortOption(rawValue: selectedSort) ?? .updatedAtDesc
    }
    
    var body: some View {
        V2DrawerScaffold(
            accentGradient: AuroraPalette.linearGradient(for: colorScheme),
            header: {
                V2GlassHeaderBar(
                    title: "Sort Areas",
                    subtitle: "Refine your area view"
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
                    // Sort Section
                    DrawerSection(title: "Sort Options", icon: "arrow.up.arrow.down.circle") {
                        VStack(alignment: .leading, spacing: 20) {
                            ForEach(AreaSortCategory.allCases, id: \.self) { category in
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
                                        ForEach(AreaSortOption.options(for: category), id: \.id) { sort in
                                            SortOptionButton(
                                                title: sort.displayName,
                                                icon: sort.icon,
                                                isSelected: currentSortOption.id == sort.id,
                                                action: {
                                                    selectedSort = sort.rawValue
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
}

// MARK: - Helper Views

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
    UnifiedAreasView()
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [Area.self, FocusOSShared.Project.self, FocusOSShared.Task.self, Note.self])
}

