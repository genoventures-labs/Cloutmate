//
//  UnifiedDraftsView.swift
//  FocusOS
//
//  Drafts V2 main view with card grid and AI integration
//

import SwiftUI
import SwiftData
import FocusOSShared

struct UnifiedDraftsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @Query(sort: \Draft.updatedAt, order: .reverse) private var allDrafts: [Draft]
    
    @State private var searchText: String = ""
    @State private var selectedFilter: DraftsFilter = .all
    @State private var isShowingQuickCreate: Bool = false
    @State private var selectionMode: Bool = false
    @State private var selectedDraftIDs: Set<UUID> = []
    @State private var editorDraft: Draft?
    @State private var publishingDraft: Draft?
    @State private var draftToDelete: Draft?
    @State private var showDeleteConfirmation: Bool = false
    @State private var isFilterSortDrawerVisible = false
    @FocusState private var focusedDraftID: UUID?
    @Environment(\.colorScheme) private var colorScheme
    
    // Sort persistence
    @AppStorage("drafts.sort") private var sortOption: String = DraftSortOption.lastEditedAtDesc.rawValue
    
    private var currentSortOption: DraftSortOption {
        DraftSortOption(rawValue: sortOption) ?? .lastEditedAtDesc
    }
    
    private let gridColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 320, maximum: 420), spacing: 20, alignment: .top)
    ]
    
    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    headerSection
                        .padding(.horizontal, 24)
                    
                    contentSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 80)
                }
            }
            .background(glassColorSystem.backgroundColor())
            .opacity(isFilterSortDrawerVisible ? 0 : 1)
            .overlay(selectionToolbar, alignment: .bottom)
            
            if isFilterSortDrawerVisible {
                DraftFilterSortDrawer(
                    isPresented: $isFilterSortDrawerVisible,
                    selectedSort: $sortOption
                )
                .transition(.move(edge: .trailing))
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                selectionToolbarItems
            }
        }
        .sheet(item: $editorDraft) { draft in
            DraftEditorDrawer(
                draft: draft,
                isPresented: Binding(
                    get: { editorDraft != nil },
                    set: { newValue in
                        if !newValue {
                            editorDraft = nil
                        }
                    }
                ),
                onClose: {
                    editorDraft = nil
                },
                onPublish: {
                    publishingDraft = draft
                },
                onDelete: {
                    draftToDelete = draft
                    showDeleteConfirmation = true
                },
                onExport: {
                    exportDraft(draft)
                }
            )
            .environmentObject(glassColorSystem)
        }
        .sheet(item: $publishingDraft) { draft in
            DraftPublishingSheet(
                draft: draft,
                isPresented: Binding(
                    get: { publishingDraft != nil },
                    set: { newValue in
                        if !newValue {
                            publishingDraft = nil
                        }
                    }
                ),
                onDismiss: {
                    publishingDraft = nil
                }
            )
            .environmentObject(glassColorSystem)
        }
        .alert("Delete Draft?", isPresented: $showDeleteConfirmation, presenting: draftToDelete) { draft in
            Button("Delete", role: .destructive) {
                deleteDraft(draft)
            }
            Button("Cancel", role: .cancel) {
                draftToDelete = nil
            }
        } message: { draft in
            Text("This action cannot be undone. \"\(draft.displayTitle)\" will be permanently removed.")
        }
        .onChange(of: isShowingQuickCreate) { _, newValue in
            if newValue {
                createBlankDraft()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openDraftEditor)) { notification in
            let context = notification.object as? String
            switch context {
            case "ai-assistant":
                createBlankDraft(source: "AI Assistant")
            case "note-reference":
                createBlankDraft(source: "Notes")
            default:
                createBlankDraft()
            }
        }
        .overlay(alignment: .bottomTrailing) {
            HiddenKeyboardTriggers(
                onDefault: openFocusedDraft,
                onCancel: closeEditorIfNeeded
            )
        }
        .animation(reduceMotion ? .default : .spring(response: 0.45, dampingFraction: 0.85), value: sortedDrafts.map(\.id))
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        DraftsHeaderView(
            searchText: $searchText,
            selectedFilter: $selectedFilter,
            isShowingQuickCreate: $isShowingQuickCreate,
            activeDraftCount: activeDrafts.count,
            aiDraftCount: aiDrafts.count,
            archivedCount: archivedDrafts.count,
            currentSortOption: currentSortOption,
            isFilterSortDrawerVisible: $isFilterSortDrawerVisible,
            onSortChange: { option in
                sortOption = option.rawValue
            },
            onFilterChanged: { _ in
                if selectedFilter == .archived {
                    selectionMode = false
                    selectedDraftIDs.removeAll()
                }
            }
        )
        .environmentObject(glassColorSystem)
    }
    
    @ViewBuilder
    private var contentSection: some View {
        if sortedDrafts.isEmpty {
            ContentUnavailableView(
                (allDrafts.isEmpty ? "No Drafts Yet" : "No Matches"),
                systemImage: "doc.text",
                description: Text(allDrafts.isEmpty ?
                                  "Create a draft to start shaping your ideas." :
                                    "Try a different search or filter.")
            )
            .frame(maxWidth: .infinity, minHeight: 320)
        } else {
            LazyVGrid(columns: gridColumns, spacing: 20) {
                ForEach(sortedDrafts) { draft in
                    DraftCardV2(
                        draft: draft,
                        isActive: editorDraft?.id == draft.id,
                        showSelectionIndicator: selectionMode,
                        isSelected: selectedDraftIDs.contains(draft.id),
                        onOpen: { openDraft(draft) },
                        onShare: { shareDraft(draft) },
                        onPublish: { publishDraft(draft) },
                        onExport: { exportDraft(draft) },
                        onDuplicate: { duplicateDraft(draft) },
                        onArchive: { toggleArchive(draft) },
                        onDelete: {
                            draftToDelete = draft
                            showDeleteConfirmation = true
                        },
                        onSelectionToggle: {
                            toggleSelection(for: draft)
                        }
                    )
                    .environmentObject(glassColorSystem)
                    .focusable(true)
                    .focused($focusedDraftID, equals: draft.id)
                    .onMoveCommand { direction in
                        handleMoveCommand(direction, currentDraft: draft)
                    }
                }
            }
        }
    }
    
    private var selectionToolbar: some View {
        Group {
            if selectionMode && !selectedDraftIDs.isEmpty {
                VStack {
                    Divider()
                    HStack(spacing: 12) {
                        Text("\(selectedDraftIDs.count) selected")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        GlassButton("Archive", icon: "archivebox") {
                            archiveSelected()
                        }
                        
                        GlassButton("Duplicate", icon: "doc.on.doc") {
                            duplicateSelected()
                        }
                        
                        GlassButton("Delete", icon: "trash", role: .danger) {
                            deleteSelected()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    private var selectionToolbarItems: some View {
        Group {
            if !sortedDrafts.isEmpty {
                if selectionMode {
                    Button("Done") {
                        selectionMode = false
                        selectedDraftIDs.removeAll()
                    }
                } else {
                    Button("Select") {
                        selectionMode = true
                    }
                }
            }
        }
    }
    
    // MARK: - Derived Collections
    
    private var filteredDrafts: [Draft] {
        allDrafts
            .filter { draft in
                guard matchesFilter(draft) else { return false }
                guard matchesSearch(draft) else { return false }
                return true
            }
    }
    
    var sortedDrafts: [Draft] {
        sortDrafts(filteredDrafts, by: currentSortOption)
    }
    
    private var activeDrafts: [Draft] {
        allDrafts.filter { !$0.isArchived }
    }
    
    private var archivedDrafts: [Draft] {
        allDrafts.filter { $0.isArchived }
    }
    
    private var aiDrafts: [Draft] {
        allDrafts.filter { draft in
            draft.metadataTags.contains("AI") || (draft.source?.localizedCaseInsensitiveContains("ai") ?? false)
        }
    }
    
    // MARK: - Helpers
    
    private func matchesFilter(_ draft: Draft) -> Bool {
        switch selectedFilter {
        case .all:
            return true
        case .unfinished:
            return !draft.isPublished && !draft.isArchived
        case .aiGenerated:
            return draft.metadataTags.contains("AI") || (draft.source?.localizedCaseInsensitiveContains("ai") ?? false)
        case .userCreated:
            return !(draft.metadataTags.contains("AI") || (draft.source?.localizedCaseInsensitiveContains("ai") ?? false))
        case .archived:
            return draft.isArchived
        }
    }
    
    private func matchesSearch(_ draft: Draft) -> Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let query = trimmed.lowercased()
        if draft.title.lowercased().contains(query) ||
            draft.displayTitle.lowercased().contains(query) ||
            draft.caption.lowercased().contains(query) ||
            (draft.notes?.lowercased().contains(query) ?? false) ||
            draft.tags.contains(where: { $0.lowercased().contains(query) }) ||
            draft.metadataTags.contains(where: { $0.lowercased().contains(query) }) {
            return true
        }
        return false
    }
    
    private func createBlankDraft(source: String? = nil) {
        let draft = Draft()
        draft.lastEditedAt = Date()
        draft.metadataTags = []
        if let source = source {
            draft.source = source
            draft.metadataTags = ["QuickCreate", "Source::\(source)"]
        }
        draft.refreshWordMetrics()
        modelContext.insert(draft)
        do {
            try modelContext.save()
            editorDraft = draft
            focusedDraftID = draft.id
        } catch {
            print("Failed to create draft: \(error)")
        }
        isShowingQuickCreate = false
    }
    
    private func openDraft(_ draft: Draft) {
        editorDraft = draft
    }
    
    private func exportDraft(_ draft: Draft) {
        publishingDraft = draft
    }
    
    private func publishDraft(_ draft: Draft) {
        publishingDraft = draft
    }
    
    private func shareDraft(_ draft: Draft) {
        publishingDraft = draft
    }
    
    private func duplicateDraft(_ draft: Draft) {
        let duplicated = Draft(
            title: draft.title,
            caption: draft.caption,
            mediaURLs: draft.mediaURLs,
            tags: draft.tags,
            notes: draft.notes
        )
        duplicated.metadataTags = draft.metadataTags
        duplicated.source = draft.source
        duplicated.refreshWordMetrics()
        modelContext.insert(duplicated)
        try? modelContext.save()
    }
    
    private func toggleArchive(_ draft: Draft) {
        draft.isArchived.toggle()
        draft.lastEditedAt = Date()
        try? modelContext.save()
    }
    
    private func deleteDraft(_ draft: Draft) {
        modelContext.delete(draft)
        try? modelContext.save()
        draftToDelete = nil
    }
    
    private func toggleSelection(for draft: Draft) {
        if selectedDraftIDs.contains(draft.id) {
            selectedDraftIDs.remove(draft.id)
        } else {
            selectedDraftIDs.insert(draft.id)
        }
        focusedDraftID = draft.id
    }
    
    private func archiveSelected() {
        let drafts = allDrafts.filter { selectedDraftIDs.contains($0.id) }
        drafts.forEach {
            $0.isArchived = true
            $0.lastEditedAt = Date()
        }
        selectedDraftIDs.removeAll()
        try? modelContext.save()
    }
    
    private func duplicateSelected() {
        let drafts = allDrafts.filter { selectedDraftIDs.contains($0.id) }
        drafts.forEach { duplicateDraft($0) }
        selectedDraftIDs.removeAll()
    }
    
    private func deleteSelected() {
        let drafts = allDrafts.filter { selectedDraftIDs.contains($0.id) }
        drafts.forEach { modelContext.delete($0) }
        selectedDraftIDs.removeAll()
        try? modelContext.save()
    }
    
    private func handleMoveCommand(_ direction: MoveCommandDirection, currentDraft: Draft) {
        guard let index = sortedDrafts.firstIndex(where: { $0.id == currentDraft.id }) else { return }
        let targetIndex: Int?
        switch direction {
        case .up, .left:
            targetIndex = index > 0 ? index - 1 : nil
        case .down, .right:
            targetIndex = index < sortedDrafts.count - 1 ? index + 1 : nil
        default:
            targetIndex = nil
        }
        if let targetIndex {
            focusedDraftID = sortedDrafts[targetIndex].id
        }
    }
    
    private func openFocusedDraft() {
        guard let id = focusedDraftID,
              let draft = sortedDrafts.first(where: { $0.id == id }) else { return }
        if selectionMode {
            toggleSelection(for: draft)
        } else {
            openDraft(draft)
        }
    }
    
    private func closeEditorIfNeeded() {
        if editorDraft != nil {
            editorDraft = nil
        }
    }
    
    private func sortDrafts(_ drafts: [Draft], by option: DraftSortOption) -> [Draft] {
        var sorted = drafts
        
        switch option {
        // Date & Time
        case .lastEditedAtDesc:
            sorted.sort { $0.lastEditedAt > $1.lastEditedAt }
        case .lastEditedAtAsc:
            sorted.sort { $0.lastEditedAt < $1.lastEditedAt }
        case .updatedAtDesc:
            sorted.sort { $0.updatedAt > $1.updatedAt }
        case .updatedAtAsc:
            sorted.sort { $0.updatedAt < $1.updatedAt }
        case .createdAtDesc:
            sorted.sort { $0.createdAt > $1.createdAt }
        case .createdAtAsc:
            sorted.sort { $0.createdAt < $1.createdAt }
        case .scheduledOrPublishedDateDesc:
            sorted.sort { draft1, draft2 in
                guard let date1 = draft1.scheduledOrPublishedDate else { return false }
                guard let date2 = draft2.scheduledOrPublishedDate else { return true }
                return date1 > date2
            }
        case .scheduledOrPublishedDateAsc:
            sorted.sort { draft1, draft2 in
                guard let date1 = draft1.scheduledOrPublishedDate else { return false }
                guard let date2 = draft2.scheduledOrPublishedDate else { return true }
                return date1 < date2
            }
        
        // Alphabetical
        case .titleAsc:
            sorted.sort { draft1, draft2 in
                let title1 = draft1.title.isEmpty ? draft1.caption : draft1.title
                let title2 = draft2.title.isEmpty ? draft2.caption : draft2.title
                return title1.localizedCaseInsensitiveCompare(title2) == .orderedAscending
            }
        case .titleDesc:
            sorted.sort { draft1, draft2 in
                let title1 = draft1.title.isEmpty ? draft1.caption : draft1.title
                let title2 = draft2.title.isEmpty ? draft2.caption : draft2.title
                return title1.localizedCaseInsensitiveCompare(title2) == .orderedDescending
            }
        
        // Status
        case .publishedFirst:
            sorted.sort { draft1, draft2 in
                if draft1.isPublished == draft2.isPublished {
                    return draft1.lastEditedAt > draft2.lastEditedAt
                }
                return draft1.isPublished && !draft2.isPublished
            }
        case .unpublishedFirst:
            sorted.sort { draft1, draft2 in
                if draft1.isPublished == draft2.isPublished {
                    return draft1.lastEditedAt > draft2.lastEditedAt
                }
                return !draft1.isPublished && draft2.isPublished
            }
        case .archivedFirst:
            sorted.sort { draft1, draft2 in
                if draft1.isArchived == draft2.isArchived {
                    return draft1.lastEditedAt > draft2.lastEditedAt
                }
                return draft1.isArchived && !draft2.isArchived
            }
        
        // Word Count
        case .wordCountDesc:
            sorted.sort { draft1, draft2 in
                if draft1.wordCount == draft2.wordCount {
                    return draft1.lastEditedAt > draft2.lastEditedAt
                }
                return draft1.wordCount > draft2.wordCount
            }
        case .wordCountAsc:
            sorted.sort { draft1, draft2 in
                if draft1.wordCount == draft2.wordCount {
                    return draft1.lastEditedAt > draft2.lastEditedAt
                }
                return draft1.wordCount < draft2.wordCount
            }
        
        // Tags
        case .tagCountDesc:
            sorted.sort { draft1, draft2 in
                if draft1.tags.count == draft2.tags.count {
                    return draft1.lastEditedAt > draft2.lastEditedAt
                }
                return draft1.tags.count > draft2.tags.count
            }
        case .tagCountAsc:
            sorted.sort { draft1, draft2 in
                if draft1.tags.count == draft2.tags.count {
                    return draft1.lastEditedAt > draft2.lastEditedAt
                }
                return draft1.tags.count < draft2.tags.count
            }
        
        // Source
        case .sourceAIGenerated:
            sorted.sort { draft1, draft2 in
                let draft1AI = draft1.metadataTags.contains("AI") || (draft1.source?.localizedCaseInsensitiveContains("ai") ?? false)
                let draft2AI = draft2.metadataTags.contains("AI") || (draft2.source?.localizedCaseInsensitiveContains("ai") ?? false)
                if draft1AI == draft2AI {
                    return draft1.lastEditedAt > draft2.lastEditedAt
                }
                return draft1AI && !draft2AI
            }
        case .sourceUserCreated:
            sorted.sort { draft1, draft2 in
                let draft1AI = draft1.metadataTags.contains("AI") || (draft1.source?.localizedCaseInsensitiveContains("ai") ?? false)
                let draft2AI = draft2.metadataTags.contains("AI") || (draft2.source?.localizedCaseInsensitiveContains("ai") ?? false)
                if draft1AI == draft2AI {
                    return draft1.lastEditedAt > draft2.lastEditedAt
                }
                return !draft1AI && draft2AI
            }
        
        // Combined
        case .statusThenLastEdited:
            sorted.sort { draft1, draft2 in
                // Published > Unpublished > Archived
                let status1 = draft1.isPublished ? 0 : (draft1.isArchived ? 2 : 1)
                let status2 = draft2.isPublished ? 0 : (draft2.isArchived ? 2 : 1)
                if status1 != status2 {
                    return status1 < status2
                }
                return draft1.lastEditedAt > draft2.lastEditedAt
            }
        case .wordCountThenLastEdited:
            sorted.sort { draft1, draft2 in
                if draft1.wordCount != draft2.wordCount {
                    return draft1.wordCount > draft2.wordCount
                }
                return draft1.lastEditedAt > draft2.lastEditedAt
            }
        }
        
        return sorted
    }
}

private struct HiddenKeyboardTriggers: View {
    let onDefault: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack {
            Button(action: onDefault) { EmptyView() }
                .keyboardShortcut(.return, modifiers: [])
            Button(action: onCancel) { EmptyView() }
                .keyboardShortcut(.escape, modifiers: [])
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }
}

// MARK: - Draft Filter Sort Drawer

struct DraftFilterSortDrawer: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @Binding var isPresented: Bool
    @Binding var selectedSort: String
    
    private var currentSortOption: DraftSortOption {
        DraftSortOption(rawValue: selectedSort) ?? .lastEditedAtDesc
    }
    
    var body: some View {
        V2DrawerScaffold(
            accentGradient: AuroraPalette.linearGradient(for: colorScheme),
            header: {
                V2GlassHeaderBar(
                    title: "Sort Drafts",
                    subtitle: "Refine your draft view"
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
                            ForEach(DraftSortCategory.allCases, id: \.self) { category in
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
                                        ForEach(DraftSortOption.options(for: category), id: \.id) { sort in
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
    UnifiedDraftsView()
        .modelContainer(for: [Draft.self])
        .environmentObject(GlassColorSystem())
}

