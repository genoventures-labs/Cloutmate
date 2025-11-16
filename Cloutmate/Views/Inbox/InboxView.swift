//
//  InboxView.swift
//  Cloutmate
//
//  Inbox V2 - Modern Card-Based Capture Hub
//

import SwiftUI
import SwiftData
import CloutmateShared

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
    
    private var headerSubtitle: String {
        let count = filteredItems.count
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
            .opacity(hasActiveDrawer ? 0 : 1)
            .allowsHitTesting(!hasActiveDrawer)
            
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(InboxFilter.allCases, id: \.self) { filter in
                    filterChip(for: filter)
                }
            }
            .padding(.horizontal, 2)
        }
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
                if filteredItems.isEmpty {
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
                        ForEach(filteredItems) { item in
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
}

#Preview {
    InboxView()
        .modelContainer(for: [InboxItem.self])
        .environmentObject(GlassColorSystem())
}
