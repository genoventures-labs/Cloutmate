//
//  ResourcesView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers
import CloutmateShared

struct ResourcesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<CloutmateShared.Note> { $0.isArchived == false && $0.projectId == nil }, sort: \CloutmateShared.Note.updatedAt, order: .reverse) private var resourceNotes: [CloutmateShared.Note]
    @Query private var allProjects: [CloutmateShared.Project]
    @Query private var allAreas: [Area]
    
    @State private var searchText = ""
    @State private var selectedProject: CloutmateShared.Project?
    @State private var selectedArea: Area?
    @State private var selectedTags: Set<String> = []
    @State private var hasHighlightsFilter: Bool?
    @State private var selectedType: CloutmateShared.ResourceType?
    @State private var selectedNotes = Set<UUID>()
    @State private var selectedNote: Note?
    @State private var showCreateSheet = false
    
    var filteredNotes: [Note] {
        var filtered = resourceNotes
        
        if !searchText.isEmpty {
            filtered = filtered.filter { note in
                note.title.localizedCaseInsensitiveContains(searchText) ||
                note.markdown.localizedCaseInsensitiveContains(searchText) ||
                note.tags.joined(separator: " ").localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if let project = selectedProject {
            filtered = filtered.filter { $0.projectId == project.id }
        }
        
        if let area = selectedArea {
            filtered = filtered.filter { $0.areaId == area.id }
        }
        
        if !selectedTags.isEmpty {
            filtered = filtered.filter { note in
                !Set(note.tags).isDisjoint(with: selectedTags)
            }
        }
        
        if let hasHighlights = hasHighlightsFilter {
            filtered = filtered.filter { note in
                if hasHighlights {
                    return !note.highlights.isEmpty
                } else {
                    return note.highlights.isEmpty
                }
            }
        }
        
        if let type = selectedType {
            filtered = filtered.filter { $0.type == type }
        }
        
        return filtered
    }
    
    var availableTags: [String] {
        Array(Set(resourceNotes.flatMap { $0.tags })).sorted()
    }
    
    private var searchAndFiltersSection: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search resources...", text: $searchText)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "All",
                        isSelected: hasHighlightsFilter == nil,
                        action: { hasHighlightsFilter = nil }
                    )
                    
                    FilterChip(
                        title: "Has Highlights",
                        isSelected: hasHighlightsFilter == true,
                        action: { hasHighlightsFilter = true }
                    )
                    
                    FilterChip(
                        title: "No Highlights",
                        isSelected: hasHighlightsFilter == false,
                        action: { hasHighlightsFilter = false }
                    )
                }
            }
            
            // Type filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "All Types",
                        isSelected: selectedType == nil,
                        action: { selectedType = nil }
                    )
                    
                    ForEach(ResourceType.allCases, id: \.self) { type in
                        FilterChip(
                            title: type.rawValue,
                            isSelected: selectedType == type,
                            action: { selectedType = type }
                        )
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
                    Button("Highlight") {
                        selectedNote = note
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
            
            TableColumn("Type") { note in
                HStack(spacing: 4) {
                    Image(systemName: iconForType(note.type))
                        .font(.caption)
                        .foregroundColor(.kosmicBlue)
                    Text(note.type.rawValue)
                        .font(.caption)
                }
            }
            .width(min: 100, ideal: 120)
            
            TableColumn("Source") { note in
                if let source = note.source {
                    Text(source)
                        .font(.caption)
                        .lineLimit(1)
                } else {
                    Text("—")
                        .foregroundColor(.secondary)
                }
            }
            .width(min: 150)
            
            TableColumn("Project/Area") { note in
                if let projectId = note.projectId,
                   let project = allProjects.first(where: { $0.id == projectId }) {
                    Text(project.title)
                        .font(.caption)
                        .foregroundColor(.kosmicBlue)
                } else if let areaId = note.areaId,
                          let area = allAreas.first(where: { $0.id == areaId }) {
                    Text(area.title)
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    Text("—")
                        .foregroundColor(.secondary)
                }
            }
            .width(min: 120)
            
            TableColumn("Tags") { note in
                if !note.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(note.tags.prefix(3), id: \.self) { tag in
                                Text(tag)
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
            
            tableSection
        }
        .background(Color(.windowBackgroundColor))
        .navigationTitle("Resources")
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
                
                Button("New Resource") {
                    showCreateSheet = true
                }
            }
        }
        .sheet(item: $selectedNote) { note in
            NoteEditorSheet(note: note)
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateResourceSheet()
        }
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
        let selectedNotesList = resourceNotes.filter { selectedNotes.contains($0.id) }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "cloutmate-resources-\(Date().formatted(date: .numeric, time: .omitted)).csv"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            
            var csvString = "Title,Content,Tags,Source,Updated At\n"
            
            for note in selectedNotesList {
                let escapedTitle = note.title.replacingOccurrences(of: "\"", with: "\"\"")
                let escapedContent = note.markdown.replacingOccurrences(of: "\"", with: "\"\"")
                let tags = note.tags.joined(separator: "|")
                let source = note.source ?? ""
                let updatedAt = note.updatedAt.formatted()
                
                csvString += "\"\(escapedTitle)\",\"\(escapedContent)\",\(tags),\"\(source)\",\(updatedAt)\n"
            }
            
            do {
                try csvString.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("Export error: \(error)")
            }
        }
    }
    
    private func iconForType(_ type: ResourceType) -> String {
        switch type {
        case .note: return "doc.text"
        case .article: return "newspaper"
        case .video: return "play.rectangle"
        case .book: return "book"
        case .podcast: return "waveform"
        case .link: return "link"
        case .idea: return "lightbulb"
        case .reference: return "doc.append"
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search resources", text: $text)
                .textFieldStyle(.plain)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .glassPanel(tier: .contentCard, cornerRadius: 8)
        .padding()
    }
}

struct NoteCard: View {
    let note: Note
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(Color.kosmicPurple)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(note.updatedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            if !note.markdown.isEmpty {
                Text(note.markdown.prefix(150))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 12)
        .onTapGesture(perform: onTap)
    }
}

struct NoteEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var note: Note
    
    var body: some View {
        NavigationStack {
            NoteHighlightingView(note: note)
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

struct NoteEditorView: View {
    @Bindable var note: Note
    @State private var editedContent = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Button(action: {}) {
                    Image(systemName: "bold")
                }
                Button(action: {}) {
                    Image(systemName: "italic")
                }
                Button(action: {}) {
                    Image(systemName: "text.bubble")
                }
                Spacer()
                
                Text("\((editedContent.isEmpty ? note.markdown : editedContent).wordCount) words")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .glassPanel(tier: .contentCard)
            
            Divider()
            
            VStack(spacing: 0) {
                TextField("Note Title", text: $note.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .textFieldStyle(.plain)
                    .padding()
                
                Divider()
                
                TextEditor(text: Binding(
                    get: { editedContent.isEmpty ? note.markdown : editedContent },
                    set: { newValue in
                        editedContent = newValue
                    }
                ))
                .font(.body)
            }
        }
        .onChange(of: editedContent) { _, newValue in
            note.markdown = newValue.isEmpty ? note.markdown : newValue
            note.updatedAt = Date()
        }
        .onAppear {
            editedContent = note.markdown
        }
    }
}

struct CreateResourceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allProjects: [Project]
    @Query private var allAreas: [Area]
    
    @State private var title = ""
    @State private var content = ""
    @State private var source = ""
    @State private var tags = ""
    @State private var type: ResourceType = .note
    @State private var projectId: UUID?
    @State private var areaId: UUID?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Basic Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Basic Information")
                            .font(.headline)
                        
                        TextField("Title *", text: $title)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Content")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextEditor(text: $content)
                                .frame(height: 120)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Source (optional)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("URL, book, article, etc.", text: $source)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Type")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("Type", selection: $type) {
                                ForEach(ResourceType.allCases, id: \.self) { resourceType in
                                    Text(resourceType.rawValue).tag(resourceType)
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Organization
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Organization")
                            .font(.headline)
                        
                        if !allProjects.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Project (optional)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Picker("Project", selection: $projectId) {
                                    Text("None").tag(UUID?.none)
                                    ForEach(allProjects) { project in
                                        Text(project.title).tag(project.id as UUID?)
                                    }
                                }
                            }
                        }
                        
                        if !allAreas.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Area (optional)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Picker("Area", selection: $areaId) {
                                    Text("None").tag(UUID?.none)
                                    ForEach(allAreas) { area in
                                        Text(area.title).tag(area.id as UUID?)
                                    }
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tags (comma separated)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("e.g., knowledge, reference, idea", text: $tags)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("New Resource")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createResource()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .frame(width: 600, height: 550)
    }
    
    private func createResource() {
        let tagArray = tags.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let note = Note(
            title: title,
            markdown: content,
            tags: tagArray,
            projectId: projectId,
            areaId: areaId,
            source: source.isEmpty ? nil : source,
            type: type
        )
        
        modelContext.insert(note)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    ResourcesView()
        .modelContainer(for: [Note.self])
}

