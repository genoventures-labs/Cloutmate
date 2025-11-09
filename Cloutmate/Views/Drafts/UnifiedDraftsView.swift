//
//  UnifiedDraftsView.swift
//  Cloutmate
//
//  Drafts V2 main view with card grid and AI integration
//

import SwiftUI
import SwiftData
import CloutmateShared

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
    @FocusState private var focusedDraftID: UUID?
    
    private let gridColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 320, maximum: 420), spacing: 20, alignment: .top)
    ]
    
    var body: some View {
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
        .overlay(selectionToolbar, alignment: .bottom)
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
        .animation(reduceMotion ? .default : .spring(response: 0.45, dampingFraction: 0.85), value: filteredDrafts.map(\.id))
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
        if filteredDrafts.isEmpty {
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
                ForEach(filteredDrafts) { draft in
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
            if !filteredDrafts.isEmpty {
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
            .sorted { lhs, rhs in
                lhs.lastEditedAt > rhs.lastEditedAt
            }
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
        guard let index = filteredDrafts.firstIndex(where: { $0.id == currentDraft.id }) else { return }
        let targetIndex: Int?
        switch direction {
        case .up, .left:
            targetIndex = index > 0 ? index - 1 : nil
        case .down, .right:
            targetIndex = index < filteredDrafts.count - 1 ? index + 1 : nil
        default:
            targetIndex = nil
        }
        if let targetIndex {
            focusedDraftID = filteredDrafts[targetIndex].id
        }
    }
    
    private func openFocusedDraft() {
        guard let id = focusedDraftID,
              let draft = filteredDrafts.first(where: { $0.id == id }) else { return }
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

#Preview {
    UnifiedDraftsView()
        .modelContainer(for: [Draft.self])
        .environmentObject(GlassColorSystem())
}

