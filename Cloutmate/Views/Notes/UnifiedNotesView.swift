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
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Query(sort: \CloutmateShared.Note.updatedAt, order: .reverse) private var allNotes: [CloutmateShared.Note]
    
    @State private var searchText: String = ""
    @State private var selectedFilter: NotesFilter = .all
    @State private var groupingMode: NotesGroupingMode = .byTag
    @State private var showCreateSheet = false
    @State private var selectedNote: Note?
    @State private var showDrawer = false
    @State private var expandedGroups: Set<String> = []
    @State private var focusedNoteIndex: Int?
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            return groups.sorted { lhs, rhs in
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
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(.windowBackgroundColor)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                NotesHeaderView(
                    searchText: $searchText,
                    selectedFilter: $selectedFilter,
                    showCreateSheet: $showCreateSheet,
                    totalNotes: totalActiveNotes,
                    taggedNotes: taggedNotesCount
                )
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                // Content
                if sortedNotes.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        ScrollViewReader { proxy in
                            LazyVStack(spacing: 24) {
                                // Pinned notes section
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
                                                onTap: {
                                                    selectedNote = note
                                                    showDrawer = true
                                                },
                                                onEdit: {
                                                    selectedNote = note
                                                    showDrawer = true
                                                },
                                                onPin: {
                                                    togglePin(note)
                                                },
                                                onArchive: {
                                                    archiveNote(note)
                                                },
                                                onDelete: {
                                                    deleteNote(note)
                                                }
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                                
                                // Grouped notes
                                ForEach(groupedNotes, id: \.key) { group in
                                    NoteGroupSection(
                                        title: group.key,
                                        notes: group.notes,
                                        isCollapsed: !expandedGroups.contains(group.key),
                                        onToggleCollapse: {
                                            withAnimation(GlassMotion.Easing.spring(duration: 0.35)) {
                                                if expandedGroups.contains(group.key) {
                                                    expandedGroups.remove(group.key)
                                                } else {
                                                    expandedGroups.insert(group.key)
                                                }
                                            }
                                        },
                                        onNoteTap: { note in
                                            selectedNote = note
                                            showDrawer = true
                                        },
                                        onNoteEdit: { note in
                                            selectedNote = note
                                            showDrawer = true
                                        },
                                        onNotePin: { note in
                                            togglePin(note)
                                        },
                                        onNoteArchive: { note in
                                            archiveNote(note)
                                        },
                                        onNoteDelete: { note in
                                            deleteNote(note)
                                        }
                                    )
                                }
                            }
                            .padding(.vertical, 20)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            // Create new note - will use drawer UI
            NoteDetailDrawer(
                note: {
                    let newNote = Note(title: "", markdown: "")
                    modelContext.insert(newNote)
                    return newNote
                }(),
                isPresented: $showCreateSheet
            )
        }
        .overlay {
            if showDrawer, let note = selectedNote {
                NoteDetailDrawer(
                    note: note,
                    isPresented: $showDrawer
                )
                .transition(.move(edge: .trailing))
            }
        }
        .onChange(of: selectedNote) { _, newValue in
            showDrawer = newValue != nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .showCreateNote)) { _ in
            showCreateSheet = true
        }
        .onAppear {
            setupKeyboardNavigation()
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
                showCreateSheet = true
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
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
        try? modelContext.save()
    }
    
    private func deleteNote(_ note: Note) {
        modelContext.delete(note)
        try? modelContext.save()
    }
    
    private func setupKeyboardNavigation() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // ⌘N: Create new note
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "n" {
                showCreateSheet = true
                return nil
            }
            
            // Escape: Close drawer
            if event.keyCode == 53 { // Escape key
                if showDrawer {
                    showDrawer = false
                    selectedNote = nil
                    return nil
                }
            }
            
            // Enter: Open selected note
            if event.keyCode == 36 && focusedNoteIndex != nil { // Enter key
                let notes = sortedNotes
                if let index = focusedNoteIndex, index < notes.count {
                    selectedNote = notes[index]
                    showDrawer = true
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
                            onTap: { onNoteTap(note) },
                            onEdit: { onNoteEdit(note) },
                            onPin: { onNotePin(note) },
                            onArchive: { onNoteArchive(note) },
                            onDelete: { onNoteDelete(note) }
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

