//
//  NotesView.swift
//  Cloutmate
//
//  Full-featured note-taking experience
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers
import CloutmateShared

struct NotesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CloutmateShared.Note.updatedAt, order: .reverse) private var allNotes: [CloutmateShared.Note]
    
    @State private var searchText = ""
    @State private var selectedTags: Set<String> = []
    @State private var selectedNotes = Set<UUID>()
    @State private var showCreateSheet = false
    @State private var selectedNote: Note?
    
    var filteredNotes: [Note] {
        var filtered = allNotes
        
        if !searchText.isEmpty {
            filtered = filtered.filter { note in
                note.title.localizedCaseInsensitiveContains(searchText) ||
                note.markdown.localizedCaseInsensitiveContains(searchText) ||
                note.tags.joined(separator: " ").localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if !selectedTags.isEmpty {
            filtered = filtered.filter { note in
                !Set(note.tags).isDisjoint(with: selectedTags)
            }
        }
        
        return filtered
    }
    
    var availableTags: [String] {
        Array(Set(allNotes.flatMap { $0.tags })).sorted()
    }
    
    private var searchAndFiltersSection: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search notes...", text: $searchText)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            // Filter chips
            if !availableTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            title: "All",
                            isSelected: selectedTags.isEmpty,
                            action: { selectedTags.removeAll() }
                        )
                        
                        ForEach(availableTags.prefix(10), id: \.self) { tag in
                            FilterChip(
                                title: "#\(tag)",
                                isSelected: selectedTags.contains(tag),
                                action: {
                                    if selectedTags.contains(tag) {
                                        selectedTags.remove(tag)
                                    } else {
                                        selectedTags.insert(tag)
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    private var tableSection: some View {
        Table(filteredNotes, selection: $selectedNotes) {
            TableColumn("Title") { note in
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if !note.markdown.isEmpty {
                        Text(note.markdown.prefix(100))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                .contextMenu {
                    Button("Edit") {
                        selectedNote = note
                    }
                    Button("Duplicate") {
                        duplicateNote(note)
                    }
                    Button("Archive") {
                        archiveNote(note)
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        deleteNote(note)
                    }
                }
            }
            .width(min: 200, ideal: 300)
            
            TableColumn("Tags") { note in
                if !note.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(note.tags.prefix(3), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.kosmicPurple.opacity(0.1))
                                    .foregroundColor(.kosmicPurple)
                                    .cornerRadius(4)
                            }
                            if note.tags.count > 3 {
                                Text("+\(note.tags.count - 3)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } else {
                    Text("—")
                        .foregroundColor(.secondary)
                }
            }
            .width(min: 150)
            
            TableColumn("Highlights") { note in
                Text("\(note.highlights.count)")
                    .font(.caption)
                    .foregroundColor(note.highlights.isEmpty ? .secondary : .orange)
            }
            .width(min: 80)
            
            TableColumn("Updated") { note in
                Text(note.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .width(min: 120)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchAndFiltersSection
            
            if filteredNotes.isEmpty {
                ContentUnavailableView(
                    allNotes.isEmpty ? "No Notes" : "No matches",
                    systemImage: "note.text",
                    description: Text(allNotes.isEmpty ? "Create a note to get started" : "Try a different search or filter")
                )
                .frame(maxHeight: .infinity)
            } else {
                tableSection
            }
        }
        .background(Color(.windowBackgroundColor))
        .navigationTitle("Notes")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !selectedNotes.isEmpty {
                    Menu("Actions") {
                        Button("Export", systemImage: "square.and.arrow.up") {
                            exportSelectedNotes()
                        }
                        Button("Archive Selected", systemImage: "archivebox") {
                            archiveSelectedNotes()
                        }
                        Button("Delete Selected", systemImage: "trash") {
                            deleteSelectedNotes()
                        }
                    }
                }
                
                Button("New Note") {
                    showCreateSheet = true
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateNoteSheet()
        }
        .sheet(item: $selectedNote) { note in
            NoteDetailSheet(note: note)
        }
    }
    
    private func duplicateNote(_ note: Note) {
        let duplicated = Note(
            title: "\(note.title) (Copy)",
            markdown: note.markdown,
            tags: note.tags
        )
        modelContext.insert(duplicated)
        try? modelContext.save()
    }
    
    private func archiveNote(_ note: Note) {
        note.isArchived = true
        if selectedNotes.contains(note.id) {
            selectedNotes.remove(note.id)
        }
        try? modelContext.save()
    }
    
    private func deleteNote(_ note: Note) {
        modelContext.delete(note)
        if selectedNotes.contains(note.id) {
            selectedNotes.remove(note.id)
        }
        try? modelContext.save()
    }
    
    private func archiveSelectedNotes() {
        let notesToArchive = filteredNotes.filter { selectedNotes.contains($0.id) }
        for note in notesToArchive {
            note.isArchived = true
        }
        selectedNotes.removeAll()
        try? modelContext.save()
    }
    
    private func deleteSelectedNotes() {
        let notesToDelete = filteredNotes.filter { selectedNotes.contains($0.id) }
        for note in notesToDelete {
            modelContext.delete(note)
        }
        selectedNotes.removeAll()
        try? modelContext.save()
    }
    
    private func exportSelectedNotes() {
        let selectedNotesList = allNotes.filter { selectedNotes.contains($0.id) }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "cloutmate-notes-\(Date().formatted(date: .numeric, time: .omitted)).csv"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            
            var csvString = "Title,Content,Tags,Updated At\n"
            
            for note in selectedNotesList {
                let escapedTitle = note.title.replacingOccurrences(of: "\"", with: "\"\"")
                let escapedContent = note.markdown.replacingOccurrences(of: "\"", with: "\"\"")
                let tags = note.tags.joined(separator: "|")
                let updatedAt = note.updatedAt.formatted()
                
                csvString += "\"\(escapedTitle)\",\"\(escapedContent)\",\(tags),\(updatedAt)\n"
            }
            
            do {
                try csvString.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("Export error: \(error)")
            }
        }
    }
}

struct NoteDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let note: Note
    
    var body: some View {
        NavigationStack {
            NoteDetailView(note: note)
                .navigationTitle(note.title)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

struct NoteDetailView: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var modelContext
    @State private var editingContent = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Title", text: $note.title)
                    .font(.system(size: 28, weight: .bold))
                    .textFieldStyle(.plain)
                
                TextEditor(text: $editingContent)
                    .font(.body)
                    .frame(minHeight: 400)
                    .scrollContentBackground(.hidden)
            }
            .padding(28)
        }
        .background(Color(.windowBackgroundColor))
        .onAppear {
            editingContent = note.markdown
        }
        .onChange(of: editingContent) { _, newValue in
            note.markdown = newValue
            note.updatedAt = Date()
            try? modelContext.save()
        }
    }
}

struct CreateNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var content = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Enter note title...", text: $title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Content")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        VoiceInputButton(text: $content)
                    }
                    TextEditor(text: $content)
                        .font(.body)
                        .frame(minHeight: 300)
                        .glassPanel(tier: .contentCard, cornerRadius: 8)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Create Note") {
                        createNote()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.isEmpty)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("New Note")
        }
        .frame(width: 800, height: 600)
    }
    
    private func createNote() {
        let note = Note(title: title, markdown: content)
        modelContext.insert(note)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    NotesView()
        .modelContainer(for: [Note.self])
}
