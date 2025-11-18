//
//  InboxView.swift
//  FocusOS
//
//  Inbox V2 - Modern Card-Based Capture Hub
//

import SwiftUI
import SwiftData
import FocusOSShared

struct InboxView: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \InboxItem.createdAt, order: .reverse) 
    private var inboxItems: [InboxItem]
    
    @State private var searchText = ""
    @State private var selectedFilter: InboxFilter = .all
    @State private var selectedDrawerItem: InboxItem?
    @State private var isQuickCaptureVisible = false
    @State private var isFilterSortDrawerVisible = false
    
    // Sort persistence
    @AppStorage("inbox.sort") private var sortOption: String = InboxSortOption.createdAtDesc.rawValue
    
    private var currentSortOption: InboxSortOption {
        InboxSortOption(rawValue: sortOption) ?? .createdAtDesc
    }
    
    private var normalizedSearchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var filteredItems: [InboxItem] {
        var filtered = inboxItems
        
        // Filter by conversion status
        switch selectedFilter {
        case .all:
            filtered = filtered.filter { $0.convertedAt == nil }
        case .unsorted:
            filtered = filtered.filter { $0.convertedAt == nil && !$0.isFlagged && !$0.isArchived }
        case .flagged:
            filtered = filtered.filter { $0.isFlagged && $0.convertedAt == nil }
        case .aiImports:
            filtered = filtered.filter { $0.aiImported && $0.convertedAt == nil }
        case .archived:
            filtered = filtered.filter { $0.isArchived }
        }
        
        // Search filter
        if !normalizedSearchQuery.isEmpty {
            filtered = filtered.filter { 
                $0.content.localizedCaseInsensitiveContains(normalizedSearchQuery)
            }
        }
        
        return filtered
    }
    
    var sortedItems: [InboxItem] {
        sortInboxItems(filteredItems, by: currentSortOption)
    }
    
    private var headerSubtitle: String {
        let count = sortedItems.count
        if count == 0 {
            return "No items"
        } else if count == 1 {
            return "1 item awaiting action"
        } else {
            return "\(count) items awaiting action"
        }
    }
    
    var body: some View {
        ZStack {
            V2GlassContentScaffold(
                accentGradient: AuroraPalette.linearGradient(for: colorScheme),
                showsSidebar: false,
                header: { headerBar },
                content: { inboxContent },
                sidebar: { EmptyView() }
            )
            .opacity(hasActiveDrawer || isFilterSortDrawerVisible ? 0 : 1)
            .allowsHitTesting(!hasActiveDrawer && !isFilterSortDrawerVisible)
            
            if isFilterSortDrawerVisible {
                InboxFilterSortDrawer(
                    isPresented: $isFilterSortDrawerVisible,
                    selectedSort: $sortOption
                )
                .transition(.move(edge: .trailing))
            }
            
            drawerOverlays
        }
    }
    
    private var hasActiveDrawer: Bool {
        selectedDrawerItem != nil || isQuickCaptureVisible
    }
    
    private var headerBar: some View {
        V2GlassHeaderBar(
            title: "Inbox",
            subtitle: headerSubtitle,
            trailingAccessory: {
                HStack(spacing: 12) {
                    GlassButton("Quick Capture", icon: "plus", style: .pill, role: .accent) {
                        presentQuickCapture()
                    }
                }
            }
        )
    }
    
    @ViewBuilder
    private var inboxContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            filterPanel
            itemsGrid
        }
    }
    
    private var filterPanel: some View {
        GlassPanel(tier: .overlay, cornerRadius: 26) {
            VStack(alignment: .leading, spacing: 18) {
                searchField
                filterChipRow
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 22)
        }
    }
    
    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(glassColorSystem.textSecondary().opacity(0.75))
            
            TextField("Search ideas or entries...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .rounded))
                .foregroundColor(glassColorSystem.textPrimary())
                .disableAutocorrection(true)
            
            if !normalizedSearchQuery.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(glassColorSystem.backgroundElevated().opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(glassColorSystem.borderColor().opacity(0.45), lineWidth: 0.9)
                )
        )
    }
    
    private var filterChipRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(InboxFilter.allCases, id: \.self) { filter in
                        filterChip(for: filter)
                    }
                }
                .padding(.horizontal, 2)
            }
            
            HStack {
                // Most common sorts (3 max)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Sort")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                    
                    HStack(spacing: 10) {
                        quickSortButton(.createdAtDesc)
                        quickSortButton(.typeText)
                        quickSortButton(.flaggedFirst)
                    }
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
        }
    }
    
    @ViewBuilder
    private func quickSortButton(_ sort: InboxSortOption) -> some View {
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
    
    private func filterChip(for filter: InboxFilter) -> some View {
        let isActive = selectedFilter == filter
        
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: filterIcon(for: filter))
                    .font(.system(size: 13, weight: .semibold))
                Text(filter.rawValue)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(filterAccentColor(for: filter).opacity(isActive ? 0.26 : 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(filterAccentColor(for: filter).opacity(isActive ? 0.55 : 0.24), lineWidth: isActive ? 1.4 : 1)
            )
            .foregroundStyle(isActive ? Color.white : glassColorSystem.textSecondary())
            .shadow(color: filterAccentColor(for: filter).opacity(isActive ? 0.20 : 0.0), radius: isActive ? 12 : 0, y: isActive ? 6 : 0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(filter.rawValue) filter")
        .accessibilityHint(isActive ? "Tap to remove filter" : "Tap to include \(filter.rawValue.lowercased())")
    }
    
    private func filterIcon(for filter: InboxFilter) -> String {
        switch filter {
        case .all: return "list.bullet"
        case .unsorted: return "tray"
        case .flagged: return "pin.fill"
        case .aiImports: return "sparkles"
        case .archived: return "archivebox.fill"
        }
    }
    
    private func filterAccentColor(for filter: InboxFilter) -> Color {
        switch filter {
        case .all: return .kosmicBlue
        case .unsorted: return .kosmicPurple
        case .flagged: return .orange
        case .aiImports: return .kosmicPurple
        case .archived: return .gray
        }
    }
    
    @ViewBuilder
    private var itemsGrid: some View {
                if sortedItems.isEmpty {
                    ContentUnavailableView(
                        inboxItems.isEmpty ? "Inbox is empty" : "No matches",
                        systemImage: "tray",
                        description: Text(inboxItems.isEmpty ? "Capture new items to get started" : "Try a different search or filter")
                    )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 320, maximum: 400), spacing: 16)
                        ],
                        spacing: 16
                    ) {
                        ForEach(sortedItems) { item in
                            InboxCardV2(
                                item: item,
                                onTap: {
                                    selectedDrawerItem = item
                                },
                                onConvertToTask: {
                                    convertItemToTask(item)
                                },
                                onConvertToNote: {
                                    convertItemToNote(item)
                                },
                                onConvertToDraft: {
                                    convertItemToDraft(item)
                                },
                                onConvertToProject: {
                                    convertItemToProject(item)
                                },
                                onArchive: {
                                    archiveItem(item)
                                },
                                onPin: {
                                    toggleFlag(item)
                                },
                                onDelete: {
                                    deleteItem(item)
                                }
                            )
                }
            }
        }
    }
            
    @ViewBuilder
    private var drawerOverlays: some View {
                if let item = selectedDrawerItem {
                    InboxCaptureDrawer(item: item, isPresented: Binding(
                        get: { selectedDrawerItem != nil },
                        set: { if !$0 { selectedDrawerItem = nil } }
                    ))
                .transition(.move(edge: .trailing))
            }
            
            if isQuickCaptureVisible {
                QuickCaptureDrawer(isPresented: $isQuickCaptureVisible)
                    .transition(.move(edge: .trailing))
            }
    }
    
    private func presentQuickCapture() {
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isQuickCaptureVisible = true
        }
    }
    
    // MARK: - Conversion Actions
    
    private func convertItemToTask(_ item: InboxItem) {
        let task = Task(
            title: item.content.prefix(100).description,
            notes: item.fileURL ?? ""
        )
        modelContext.insert(task)
        item.convertedToType = "task"
        item.convertedToId = task.id
        item.convertedAt = Date()
        try? modelContext.save()
    }
    
    private func convertItemToNote(_ item: InboxItem) {
        let note = Note(
            title: item.content.prefix(50).description,
            markdown: item.content
        )
        note.author = .user
        modelContext.insert(note)
        item.convertedToType = "note"
        item.convertedToId = note.id
        item.convertedAt = Date()
        try? modelContext.save()
    }
    
    private func convertItemToDraft(_ item: InboxItem) {
        let draft = Draft(
            title: item.content.prefix(50).description,
            caption: item.content,
            notes: nil
        )
        modelContext.insert(draft)
        item.convertedToType = "draft"
        item.convertedToId = draft.id
        item.convertedAt = Date()
        try? modelContext.save()
    }
    
    private func convertItemToProject(_ item: InboxItem) {
        let project = Project(
            title: item.content.prefix(50).description
        )
        modelContext.insert(project)
        item.convertedToType = "project"
        item.convertedToId = project.id
        item.convertedAt = Date()
        try? modelContext.save()
    }
    
    private func archiveItem(_ item: InboxItem) {
        item.isArchived = true
        try? modelContext.save()
    }
    
    private func toggleFlag(_ item: InboxItem) {
        item.isFlagged.toggle()
        try? modelContext.save()
    }
    
    private func deleteItem(_ item: InboxItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }
    
    private func sortInboxItems(_ items: [InboxItem], by option: InboxSortOption) -> [InboxItem] {
        var sorted = items
        
        switch option {
        // Date & Time
        case .createdAtDesc:
            sorted.sort { $0.createdAt > $1.createdAt }
        case .createdAtAsc:
            sorted.sort { $0.createdAt < $1.createdAt }
        case .convertedAtDesc:
            sorted.sort { item1, item2 in
                guard let date1 = item1.convertedAt else { return false }
                guard let date2 = item2.convertedAt else { return true }
                return date1 > date2
            }
        case .convertedAtAsc:
            sorted.sort { item1, item2 in
                guard let date1 = item1.convertedAt else { return false }
                guard let date2 = item2.convertedAt else { return true }
                return date1 < date2
            }
        
        // Type
        case .typeText:
            sorted.sort { item1, item2 in
                if item1.itemType == item2.itemType {
                    return item1.createdAt > item2.createdAt
                }
                return item1.itemType == "text" && item2.itemType != "text"
            }
        case .typeImage:
            sorted.sort { item1, item2 in
                if item1.itemType == item2.itemType {
                    return item1.createdAt > item2.createdAt
                }
                return item1.itemType == "image" && item2.itemType != "image"
            }
        case .typeFile:
            sorted.sort { item1, item2 in
                if item1.itemType == item2.itemType {
                    return item1.createdAt > item2.createdAt
                }
                return item1.itemType == "file" && item2.itemType != "file"
            }
        case .typeURL:
            sorted.sort { item1, item2 in
                if item1.itemType == item2.itemType {
                    return item1.createdAt > item2.createdAt
                }
                return item1.itemType == "url" && item2.itemType != "url"
            }
        case .typeVoice:
            sorted.sort { item1, item2 in
                if item1.itemType == item2.itemType {
                    return item1.createdAt > item2.createdAt
                }
                return item1.itemType == "voice" && item2.itemType != "voice"
            }
        
        // Status
        case .flaggedFirst:
            sorted.sort { item1, item2 in
                if item1.isFlagged == item2.isFlagged {
                    return item1.createdAt > item2.createdAt
                }
                return item1.isFlagged && !item2.isFlagged
            }
        case .unflaggedFirst:
            sorted.sort { item1, item2 in
                if item1.isFlagged == item2.isFlagged {
                    return item1.createdAt > item2.createdAt
                }
                return !item1.isFlagged && item2.isFlagged
            }
        case .convertedFirst:
            sorted.sort { item1, item2 in
                let item1Converted = item1.convertedAt != nil
                let item2Converted = item2.convertedAt != nil
                if item1Converted == item2Converted {
                    return item1.createdAt > item2.createdAt
                }
                return item1Converted && !item2Converted
            }
        case .unconvertedFirst:
            sorted.sort { item1, item2 in
                let item1Converted = item1.convertedAt != nil
                let item2Converted = item2.convertedAt != nil
                if item1Converted == item2Converted {
                    return item1.createdAt > item2.createdAt
                }
                return !item1Converted && item2Converted
            }
        
        // AI
        case .aiImportedFirst:
            sorted.sort { item1, item2 in
                if item1.aiImported == item2.aiImported {
                    return item1.createdAt > item2.createdAt
                }
                return item1.aiImported && !item2.aiImported
            }
        case .userImportedFirst:
            sorted.sort { item1, item2 in
                if item1.aiImported == item2.aiImported {
                    return item1.createdAt > item2.createdAt
                }
                return !item1.aiImported && item2.aiImported
            }
        
        // Combined
        case .flaggedThenCreated:
            sorted.sort { item1, item2 in
                if item1.isFlagged != item2.isFlagged {
                    return item1.isFlagged && !item2.isFlagged
                }
                return item1.createdAt > item2.createdAt
            }
        case .typeThenCreated:
            sorted.sort { item1, item2 in
                if item1.itemType != item2.itemType {
                    return item1.itemType < item2.itemType
                }
                return item1.createdAt > item2.createdAt
            }
        }
        
        return sorted
    }
    
    @ViewBuilder
    private func sortCategoryMenu(for category: InboxSortCategory) -> some View {
        let options = InboxSortOption.options(for: category)
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
}

// MARK: - Inbox Filter Sort Drawer

struct InboxFilterSortDrawer: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @Binding var isPresented: Bool
    @Binding var selectedSort: String
    
    private var currentSortOption: InboxSortOption {
        InboxSortOption(rawValue: selectedSort) ?? .createdAtDesc
    }
    
    var body: some View {
        V2DrawerScaffold(
            accentGradient: AuroraPalette.linearGradient(for: colorScheme),
            header: {
                V2GlassHeaderBar(
                    title: "Sort Inbox",
                    subtitle: "Refine your inbox view"
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
                            ForEach(InboxSortCategory.allCases, id: \.self) { category in
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
                                        ForEach(InboxSortOption.options(for: category), id: \.id) { sort in
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
    InboxView()
        .modelContainer(for: [InboxItem.self])
        .environmentObject(GlassColorSystem())
}
