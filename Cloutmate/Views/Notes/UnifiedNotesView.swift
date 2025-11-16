//
//  UnifiedNotesView.swift
//  Cloutmate
//
//  Notes V2 - Unified view with card-based layout and grouping
//

import SwiftUI
import SwiftData
import AppKit
import CloutmateShared

enum NotesGroupingMode: String, CaseIterable {
    case byTag = "Tag"
    case byDate = "Date"
}

struct UnifiedNotesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Query(sort: \CloutmateShared.Note.updatedAt, order: .reverse) private var allNotes: [CloutmateShared.Note]
    
    @State private var searchText: String = ""
    @State private var selectedFilter: NotesFilter = .all
    @State private var groupingMode: NotesGroupingMode = .byTag
    @State private var selectedViewMode: NotesViewMode = .cards
    @State private var activeNote: Note?
    @State private var isDrawerVisible = false
    @State private var isCreatingNote = false
    @State private var expandedGroups: Set<String> = []
    @State private var focusedNoteIndex: Int?
    @State private var isSelectionMode = false
    @State private var selectedNoteIDs: Set<UUID> = []
    
    @FocusState private var isSearchFocused: Bool
    
    private var filteredNotes: [Note] {
        var filtered = allNotes.filter { !$0.isArchived || selectedFilter == .archived }
        
        // Apply filter
        switch selectedFilter {
        case .all:
            if selectedFilter != .archived {
                filtered = filtered.filter { !$0.isArchived }
            }
        case .tagged:
            filtered = filtered.filter { !$0.tags.isEmpty }
        case .recent:
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            filtered = filtered.filter { $0.updatedAt >= sevenDaysAgo }
        case .aiSummaries:
            // Notes with AI summaries (can be enhanced with actual summary tracking)
            filtered = filtered.filter { !$0.markdown.isEmpty && $0.markdown.count > 100 }
        case .archived:
            filtered = filtered.filter { $0.isArchived }
        }
        
        // Apply search
        if !searchText.isEmpty {
            filtered = filtered.filter { note in
                note.title.localizedCaseInsensitiveContains(searchText) ||
                note.markdown.localizedCaseInsensitiveContains(searchText) ||
                note.tags.joined(separator: " ").localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    
    private var sortedNotes: [Note] {
        // Pinned notes first, then by updatedAt
        let pinned = filteredNotes.filter { $0.isPinned }.sorted { note1, note2 in
            let date1 = note1.pinnedAt ?? note1.updatedAt
            let date2 = note2.pinnedAt ?? note2.updatedAt
            return date1 > date2
        }
        let unpinned = filteredNotes.filter { !$0.isPinned }.sorted { $0.updatedAt > $1.updatedAt }
        return pinned + unpinned
    }
    
    private var pinnedNotes: [Note] {
        sortedNotes.filter { $0.isPinned }
    }
    
    private var unpinnedNotes: [Note] {
        sortedNotes.filter { !$0.isPinned }
    }
    
    private var groupedNotes: [(key: String, notes: [Note])] {
        let notesToGroup = unpinnedNotes
        
        switch groupingMode {
        case .byTag:
            var groups: [String: [Note]] = [:]
            for note in notesToGroup {
                if note.tags.isEmpty {
                    let key = "Untagged"
                    groups[key, default: []].append(note)
                } else {
                    for tag in note.tags {
                        groups[tag, default: []].append(note)
                    }
                }
            }
            // Remove duplicates from groups (notes can appear in multiple tag groups)
            return groups.map { (key: $0.key, notes: Array(Set($0.value))) }
                .sorted { $0.key < $1.key }
            
        case .byDate:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            let groups = Dictionary(grouping: notesToGroup) { note in
                formatter.string(from: note.createdAt)
            }
            return groups.map { (key: $0.key, notes: $0.value) }
                .sorted { lhs, rhs in
                    guard let lhsDate = formatter.date(from: lhs.key),
                          let rhsDate = formatter.date(from: rhs.key) else { return false }
                    return lhsDate > rhsDate
                }
        }
    }
    
    private var totalActiveNotes: Int {
        allNotes.filter { !$0.isArchived }.count
    }
    
    private var taggedNotesCount: Int {
        allNotes.filter { !$0.isArchived && !$0.tags.isEmpty }.count
    }
    
    private var visibleSelectedNoteCount: Int {
        selectedNotes.count
    }
    
    private var isSelectionActive: Bool {
        isSelectionMode || !selectedNoteIDs.isEmpty
    }
    
    private var selectedNotes: [Note] {
        filteredNotes.filter { selectedNoteIDs.contains($0.id) }
    }
    
    private var headerSubtitle: String {
        let count = filteredNotes.count
        if count == 0 {
            return "No notes"
        } else if count == 1 {
            return "1 note • \(taggedNotesCount) tagged"
        } else {
            return "\(count) notes • \(taggedNotesCount) tagged"
        }
    }
    
    var body: some View {
        ZStack {
            V2GlassContentScaffold(
                accentGradient: AuroraPalette.linearGradient(for: colorScheme),
                showsSidebar: false,
                header: { headerBar },
                content: { notesContent },
                sidebar: { EmptyView() }
            )
            .opacity(isDrawerVisible ? 0 : 1)
            
            if let note = activeNote, isDrawerVisible {
                NoteDetailDrawer(
                    note: note,
                    isPresented: Binding(
                        get: { isDrawerVisible },
                        set: { newValue in
                            withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                                isDrawerVisible = newValue
                            }
                        }
                    )
                )
                .transition(.move(edge: .trailing))
            }
        }
        .overlay(alignment: .bottom) {
            if isSelectionActive && !isDrawerVisible {
                SelectionActionBar(
                    count: visibleSelectedNoteCount,
                    itemLabel: "note",
                    actions: noteSelectionActions(),
                    onCancel: clearSelection,
                    onSelectAll: toggleSelectAll,
                    totalItems: filteredNotes.count
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showCreateNote)) { _ in
            startCreatingNote()
        }
        .onAppear {
            setupKeyboardNavigation()
        }
        .onChange(of: searchText) { _, _ in
            pruneSelection()
        }
        .onChange(of: selectedFilter) { _, _ in
            pruneSelection()
        }
        .onChange(of: groupingMode) { _, _ in
            pruneSelection()
        }
        .onChange(of: isDrawerVisible) { _, newValue in
            if !newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    activeNote = nil
                    isCreatingNote = false
                }
            }
        }
    }
    
    private var headerBar: some View {
        V2GlassHeaderBar(
            title: "Notes",
            subtitle: headerSubtitle,
            trailingAccessory: {
                HStack(spacing: 12) {
                    viewModeSelector
                    selectionToggleButton
                    quickAddButton
                }
            }
        )
    }
    
    private var viewModeSelector: some View {
        HStack(spacing: 8) {
            ForEach(NotesViewMode.allCases, id: \.self) { mode in
                modeButton(for: mode)
            }
        }
    }
    
    private func modeButton(for mode: NotesViewMode) -> some View {
        let isSelected = selectedViewMode == mode
        let backgroundFill: some ShapeStyle = isSelected ? 
            AnyShapeStyle(AuroraPalette.linearGradient(for: colorScheme).opacity(0.85)) :
            AnyShapeStyle(glassColorSystem.backgroundElevated().opacity(0.4))
        let strokeColor: Color = isSelected ? 
            Color.white.opacity(0.3) : 
            glassColorSystem.borderColor().opacity(0.3)
        let strokeWidth: CGFloat = isSelected ? 1.2 : 0.8
        
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedViewMode = mode
            }
        } label: {
            Image(systemName: mode.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : glassColorSystem.textSecondary())
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(backgroundFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(strokeColor, lineWidth: strokeWidth)
                )
        }
        .buttonStyle(.plain)
        .help(mode.displayName)
    }
    
    private var selectionToggleButton: some View {
        GlassButton(
            nil,
            icon: isSelectionActive ? "checkmark.circle.fill" : "checkmark.circle",
            style: .iconOnly,
            role: .surface
        ) {
            toggleSelectionMode()
        }
        .accessibilityLabel(isSelectionActive ? "Exit selection mode" : "Enter selection mode")
    }
    
    private var quickAddButton: some View {
        GlassButton(
            "New Note",
            icon: "plus",
            style: .pill,
            role: .primary
        ) {
            startCreatingNote()
        }
    }
    
    @ViewBuilder
    private var notesContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            filterPanel
            activeModeView
        }
        .animation(.easeInOut(duration: 0.24), value: selectedViewMode)
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
            
            TextField("Search thoughts or tags…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .rounded))
                .foregroundColor(glassColorSystem.textPrimary())
                .disableAutocorrection(true)
                .focused($isSearchFocused)
            
            if !searchText.isEmpty {
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
        )
    }
    
    private var filterChipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(NotesFilter.allCases, id: \.self) { filter in
                    filterChip(for: filter)
                }
            }
        }
    }
    
    private func filterChip(for filter: NotesFilter) -> some View {
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
    }
    
    private func filterIcon(for filter: NotesFilter) -> String {
        switch filter {
        case .all: return "list.bullet"
        case .tagged: return "tag.fill"
        case .recent: return "clock.fill"
        case .aiSummaries: return "sparkles"
        case .archived: return "archivebox.fill"
        }
    }
    
    private func filterAccentColor(for filter: NotesFilter) -> Color {
        switch filter {
        case .all: return .kosmicBlue
        case .tagged: return .kosmicPurple
        case .recent: return .orange
        case .aiSummaries: return .pink
        case .archived: return .gray
        }
    }
    
    @ViewBuilder
    private var activeModeView: some View {
        if sortedNotes.isEmpty {
            emptyState
        } else {
            switch selectedViewMode {
            case .cards:
                notesScrollView
            case .list:
                NotesListView(
                    notes: sortedNotes,
                    selectionMode: isSelectionActive,
                    selectedNoteIDs: selectedNoteIDs,
                    onNoteTap: { note in
                        openDrawer(for: note)
                    },
                    onNoteEdit: { note in
                        openDrawer(for: note)
                    },
                    onNotePin: togglePin,
                    onNoteArchive: archiveNote,
                    onNoteDelete: deleteNote,
                    onNoteSendToTasks: sendNoteToTask,
                    onSelectionToggle: toggleNoteSelection
                )
            case .grid:
                NotesGridView(
                    notes: sortedNotes,
                    selectionMode: isSelectionActive,
                    selectedNoteIDs: selectedNoteIDs,
                    onNoteTap: { note in
                        openDrawer(for: note)
                    },
                    onNoteEdit: { note in
                        openDrawer(for: note)
                    },
                    onNotePin: togglePin,
                    onNoteArchive: archiveNote,
                    onNoteDelete: deleteNote,
                    onNoteSendToTasks: sendNoteToTask,
                    onSelectionToggle: toggleNoteSelection
                )
            case .board:
                NotesBoardView(
                    notes: sortedNotes,
                    selectionMode: isSelectionActive,
                    selectedNoteIDs: selectedNoteIDs,
                    onNoteTap: { note in
                        openDrawer(for: note)
                    },
                    onNoteEdit: { note in
                        openDrawer(for: note)
                    },
                    onNotePin: togglePin,
                    onNoteArchive: archiveNote,
                    onNoteDelete: deleteNote,
                    onNoteSendToTasks: sendNoteToTask,
                    onSelectionToggle: toggleNoteSelection
                )
            case .timeline:
                NotesTimelineView(
                    notes: sortedNotes,
                    selectionMode: isSelectionActive,
                    selectedNoteIDs: selectedNoteIDs,
                    onNoteTap: { note in
                        openDrawer(for: note)
                    },
                    onNoteEdit: { note in
                        openDrawer(for: note)
                    },
                    onNotePin: togglePin,
                    onNoteArchive: archiveNote,
                    onNoteDelete: deleteNote,
                    onNoteSendToTasks: sendNoteToTask,
                    onSelectionToggle: toggleNoteSelection
                )
            }
        }
    }
    
    private var notesScrollView: some View {
        ScrollView {
            ScrollViewReader { proxy in
                LazyVStack(spacing: 24) {
                    pinnedNotesSection
                    
                    // Grouped notes
                    ForEach(groupedNotes, id: \.key) { group in
                        NoteGroupSection(
                            title: group.key,
                            notes: group.notes,
                            isCollapsed: !expandedGroups.contains(group.key),
                            onToggleCollapse: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                    if expandedGroups.contains(group.key) {
                                        expandedGroups.remove(group.key)
                                    } else {
                                        expandedGroups.insert(group.key)
                                    }
                                }
                            },
                            onNoteTap: { note in
                                openDrawer(for: note)
                            },
                            onNoteEdit: { note in
                                openDrawer(for: note)
                            },
                            onNotePin: { note in
                                togglePin(note)
                            },
                            onNoteArchive: { note in
                                archiveNote(note)
                            },
                            onNoteDelete: { note in
                                deleteNote(note)
                            },
                            onNoteSendToTasks: { note in
                                sendNoteToTask(note)
                            },
                            selectionMode: isSelectionActive,
                            selectedNoteIDs: selectedNoteIDs,
                            onSelectionToggle: { note in
                                toggleNoteSelection(note)
                            }
                        )
                    }
                }
                .padding(.vertical, 20)
            }
        }
    }
    
    @ViewBuilder
    private var pinnedNotesSection: some View {
        if !pinnedNotes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Pinned")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.kosmicBlue, .kosmicPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Spacer()
                    
                    Text("\(pinnedNotes.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
                
                // Gradient divider
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.kosmicBlue.opacity(0.3), .kosmicPurple.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                
                // Pinned cards
                ForEach(pinnedNotes) { note in
                    NoteCardV2(
                        note: note,
                        selectionMode: isSelectionActive,
                        isSelected: selectedNoteIDs.contains(note.id),
                        onSelectionToggle: {
                            toggleNoteSelection(note)
                        },
                        onTap: {
                            openDrawer(for: note)
                        },
                        onEdit: {
                            openDrawer(for: note)
                        },
                        onPin: {
                            togglePin(note)
                        },
                        onArchive: {
                            archiveNote(note)
                        },
                        onDelete: {
                            deleteNote(note)
                        },
                        onSendToTasks: {
                            sendNoteToTask(note)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No notes yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Start capturing your ideas.")
                .font(.body)
                .foregroundColor(.secondary)
            
            GlassButton("Create Note", icon: "plus", style: .pill, role: .primary) {
                startCreatingNote()
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func toggleSelectionMode() {
        if isSelectionMode || !selectedNoteIDs.isEmpty {
            clearSelection()
        } else if !filteredNotes.isEmpty {
            isSelectionMode = true
            if isDrawerVisible {
                withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                    isDrawerVisible = false
                }
            }
        }
    }
    
    private func startCreatingNote() {
        guard !isDrawerVisible else { return }
        
        let newNote = Note(title: "", markdown: "")
        newNote.author = .user
        modelContext.insert(newNote)
        
        activeNote = newNote
        isCreatingNote = true
        
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isDrawerVisible = true
        }
    }
    
    private func openDrawer(for note: Note) {
        guard !isSelectionActive else { return }
        
        activeNote = note
        isCreatingNote = false
        
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isDrawerVisible = true
        }
    }
    
    private func toggleNoteSelection(_ note: Note) {
        if selectedNoteIDs.contains(note.id) {
            selectedNoteIDs.remove(note.id)
            if selectedNoteIDs.isEmpty {
                isSelectionMode = false
            }
        } else {
            if !isSelectionMode {
                isSelectionMode = true
            }
            selectedNoteIDs.insert(note.id)
        }
        // Prevent drawer from staying open when selecting
        if isSelectionActive {
            if isDrawerVisible {
                withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                    isDrawerVisible = false
                }
            }
        }
    }
    
    private func clearSelection() {
        selectedNoteIDs.removeAll()
        isSelectionMode = false
    }
    
    private func pruneSelection() {
        let visibleIDs = Set(filteredNotes.map(\.id))
        selectedNoteIDs = selectedNoteIDs.intersection(visibleIDs)
        if selectedNoteIDs.isEmpty {
            isSelectionMode = false
        }
    }
    
    private func noteSelectionActions() -> [SelectionActionBar.Action] {
        let notes = selectedNotes
        guard !notes.isEmpty else { return [] }
        
        var actions: [SelectionActionBar.Action] = []
        
        // Send to Tasks
        actions.append(
            .init(title: "Send to Tasks", icon: "checkmark.circle") {
                sendSelectedNotesToTasks()
            }
        )
        
        if notes.contains(where: { !$0.isPinned }) {
            actions.append(
                .init(title: "Pin", icon: "pin.fill") {
                    pinSelectedNotes()
                }
            )
        }
        
        if notes.contains(where: { $0.isPinned }) {
            actions.append(
                .init(title: "Unpin", icon: "pin.slash") {
                    unpinSelectedNotes()
                }
            )
        }
        
        actions.append(
            .init(title: "Archive", icon: "archivebox", role: .surface) {
                archiveSelectedNotes()
            }
        )
        
        actions.append(
            .init(title: "Delete", icon: "trash", role: .danger) {
                deleteSelectedNotes()
            }
        )
        
        return actions
    }
    
    private func pinSelectedNotes() {
        let timestamp = Date()
        let notesToPin = selectedNotes.filter { !$0.isPinned }
        for note in notesToPin {
            note.isPinned = true
            note.pinnedAt = timestamp
            note.updatedAt = timestamp
        }
        try? modelContext.save()
        clearSelection()
    }
    
    private func unpinSelectedNotes() {
        let notesToUnpin = selectedNotes.filter { $0.isPinned }
        for note in notesToUnpin {
            note.isPinned = false
            note.pinnedAt = nil
            note.updatedAt = Date()
        }
        try? modelContext.save()
        clearSelection()
    }
    
    private func archiveSelectedNotes() {
        let notesToArchive = selectedNotes
        guard !notesToArchive.isEmpty else { return }
        for note in notesToArchive {
            note.isArchived = true
            if note.isPinned {
                note.isPinned = false
                note.pinnedAt = nil
            }
            note.updatedAt = Date()
        }
        try? modelContext.save()
        clearSelection()
    }
    
    private func deleteSelectedNotes() {
        let notesToDelete = selectedNotes
        guard !notesToDelete.isEmpty else { return }
        for note in notesToDelete {
            modelContext.delete(note)
        }
        try? modelContext.save()
        clearSelection()
    }
    
    private func toggleSelectAll() {
        let allVisibleIDs = Set(filteredNotes.map(\.id))
        if selectedNoteIDs == allVisibleIDs {
            // All selected, deselect all
            clearSelection()
        } else {
            // Not all selected, select all visible
            selectedNoteIDs = allVisibleIDs
            if !isSelectionMode {
                isSelectionMode = true
            }
        }
    }
    
    private func sendSelectedNotesToTasks() {
        let notesToConvert = selectedNotes
        guard !notesToConvert.isEmpty else { return }
        
        for note in notesToConvert {
            let task = CloutmateShared.Task(
                title: note.title.isEmpty ? "Untitled Task" : note.title,
                notes: note.markdown,
                status: .todo,
                priority: .medium
            )
            // Preserve project link if it exists
            if let projectId = note.projectId {
                task.projectId = projectId
            }
            modelContext.insert(task)
        }
        
        try? modelContext.save()
        clearSelection()
    }
    
    private func sendNoteToTask(_ note: Note) {
        let task = CloutmateShared.Task(
            title: note.title.isEmpty ? "Untitled Task" : note.title,
            notes: note.markdown,
            status: .todo,
            priority: .medium
        )
        // Preserve project link if it exists
        if let projectId = note.projectId {
            task.projectId = projectId
        }
        modelContext.insert(task)
        try? modelContext.save()
    }
    
    private func togglePin(_ note: Note) {
        note.isPinned.toggle()
        if note.isPinned {
            note.pinnedAt = Date()
        } else {
            note.pinnedAt = nil
        }
        note.updatedAt = Date()
        try? modelContext.save()
    }
    
    private func archiveNote(_ note: Note) {
        note.isArchived = true
        if note.isPinned {
            note.isPinned = false
            note.pinnedAt = nil
        }
        selectedNoteIDs.remove(note.id)
        try? modelContext.save()
        pruneSelection()
    }
    
    private func deleteNote(_ note: Note) {
        modelContext.delete(note)
        selectedNoteIDs.remove(note.id)
        try? modelContext.save()
        pruneSelection()
    }
    
    private func setupKeyboardNavigation() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // ⌘N: Create new note
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "n" {
                startCreatingNote()
                return nil
            }
            
            // Escape: Close drawer
            if event.keyCode == 53 { // Escape key
                if isDrawerVisible {
                    withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                        isDrawerVisible = false
                    }
                    return nil
                } else if isSelectionActive {
                    clearSelection()
                    return nil
                }
            }
            
            // Enter: Open selected note
            if event.keyCode == 36 && focusedNoteIndex != nil { // Enter key
                let notes = sortedNotes
                if let index = focusedNoteIndex, index < notes.count {
                    openDrawer(for: notes[index])
                    return nil
                }
            }
            
            // Arrow keys: Navigate notes
            if event.keyCode == 126 { // Up arrow
                navigateNotes(direction: -1)
                return nil
            }
            if event.keyCode == 125 { // Down arrow
                navigateNotes(direction: 1)
                return nil
            }
            
            return event
        }
    }
    
    private func navigateNotes(direction: Int) {
        let notes = sortedNotes
        guard !notes.isEmpty else { return }
        
        let currentIndex = focusedNoteIndex ?? 0
        let newIndex = max(0, min(notes.count - 1, currentIndex + direction))
        focusedNoteIndex = newIndex
        
        // Scroll to focused note if needed
        // This can be enhanced with ScrollViewReader
    }
}

// MARK: - Note Group Section

struct NoteGroupSection: View {
    let title: String
    let notes: [Note]
    let isCollapsed: Bool
    let onToggleCollapse: () -> Void
    let onNoteTap: (Note) -> Void
    let onNoteEdit: (Note) -> Void
    let onNotePin: (Note) -> Void
    let onNoteArchive: (Note) -> Void
    let onNoteDelete: (Note) -> Void
    let onNoteSendToTasks: (Note) -> Void
    let selectionMode: Bool
    let selectedNoteIDs: Set<UUID>
    let onSelectionToggle: (Note) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Button(action: onToggleCollapse) {
                HStack {
                    Text(title)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.kosmicBlue, .kosmicPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Spacer()
                    
                    Text("\(notes.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            // Divider
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)
                .padding(.bottom, 4)
            
            // Note cards
            if !isCollapsed {
                LazyVStack(spacing: 12) {
                    ForEach(notes) { note in
                        NoteCardV2(
                            note: note,
                            selectionMode: selectionMode,
                            isSelected: selectedNoteIDs.contains(note.id),
                            onSelectionToggle: { onSelectionToggle(note) },
                            onTap: { onNoteTap(note) },
                            onEdit: { onNoteEdit(note) },
                            onPin: { onNotePin(note) },
                            onArchive: { onNoteArchive(note) },
                            onDelete: { onNoteDelete(note) },
                            onSendToTasks: { onNoteSendToTasks(note) }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    UnifiedNotesView()
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [Note.self])
}

