//
//  DraftsView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import AppKit
import CloutmateShared

struct DraftsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Draft.updatedAt, order: .reverse) private var allDrafts: [Draft]
    @Query(sort: \CloutmateShared.Artifact.updatedAt, order: .reverse) private var allArtifacts: [CloutmateShared.Artifact]
    @Query(sort: \Template.name) private var templates: [Template]
    
    @State private var searchText = ""
    @State private var showArchived: Bool = false
    @State private var selectedDrafts = Set<UUID>()
    @State private var selectedArtifacts = Set<UUID>()
    @State private var selectedDraft: Draft?
    @State private var selectedArtifact: CloutmateShared.Artifact?
    @State private var showTemplates = false
    @State private var showComposer = false
    @State private var showArtifactComposer = false
    @State private var draftToConvert: Draft?
    @State private var showConversionAlert = false
    @State private var conversionResult: DraftConversionResult?
    @State private var draftToHandle: Draft?
    @State private var showAutoCleanInfo = false
    @State private var autoCleanEnabled = UserDefaults.standard.bool(forKey: "autoCleanDrafts")
    @State private var showCreateDraftSheet = false
    
    var draftArtifacts: [CloutmateShared.Artifact] {
        allArtifacts.filter { $0.artifactState == .draft }
    }
    
    var draftsToShow: [Draft] {
        allDrafts.filter { draft in
            if !searchText.isEmpty {
                let matchesSearch = draft.caption.localizedCaseInsensitiveContains(searchText) ||
                                  draft.tags.joined(separator: " ").localizedCaseInsensitiveContains(searchText)
                if !matchesSearch { return false }
            }
            
            if draft.isArchived {
                return showArchived
            } else {
                return !showArchived
            }
        }
    }
    
    var artifactsToShow: [CloutmateShared.Artifact] {
        draftArtifacts.filter { artifact in
            if !searchText.isEmpty {
                let matchesSearch = artifact.title.localizedCaseInsensitiveContains(searchText) ||
                                  artifact.content.localizedCaseInsensitiveContains(searchText) ||
                                  artifact.tags.joined(separator: " ").localizedCaseInsensitiveContains(searchText)
                if !matchesSearch { return false }
            }
            
            if artifact.artifactState == .archived {
                return showArchived
            } else {
                return !showArchived
            }
        }
    }
    
    private var searchAndFiltersSection: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search drafts & artifacts...", text: $searchText)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "Active",
                        isSelected: !showArchived,
                        action: { showArchived = false }
                    )
                    
                    FilterChip(
                        title: "Archived",
                        isSelected: showArchived,
                        action: { showArchived = true }
                    )
                }
            }
        }
        .padding()
    }
    
    private var selectionBinding: Binding<Set<UUID>> {
        Binding(
            get: {
                var ids = Set<UUID>()
                ids.formUnion(selectedDrafts)
                ids.formUnion(selectedArtifacts)
                return ids
            },
            set: { newSelection in
                selectedDrafts.removeAll()
                selectedArtifacts.removeAll()
                for id in newSelection {
                    if draftsToShow.contains(where: { $0.id == id }) {
                        selectedDrafts.insert(id)
                    } else if artifactsToShow.contains(where: { $0.id == id }) {
                        selectedArtifacts.insert(id)
                    }
                }
            }
        )
    }
    
    private var tableSection: some View {
        Table(combinedItems, selection: selectionBinding) {
            TableColumn("Content") { listItem in
                switch listItem {
                case .draft(let draft):
                    VStack(alignment: .leading, spacing: 4) {
                        Text(draft.caption.isEmpty ? "Untitled Draft" : draft.caption)
                            .font(.body)
                            .fontWeight(draft.caption.isEmpty ? .regular : .medium)
                            .lineLimit(2)
                        
                        if !draft.caption.isEmpty {
                            Text("\(draft.caption.count) characters")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .contextMenu {
                        Button("Convert to Artifact") {
                            convertDraftToArtifact(draft)
                        }
                        Button("Duplicate") {
                            duplicateDraft(draft)
                        }
                        Button(draft.isArchived ? "Unarchive" : "Archive") {
                            toggleArchive(draft)
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            deleteDraft(draft)
                        }
                    }
                case .artifact(let artifact):
                    VStack(alignment: .leading, spacing: 4) {
                        Text(artifact.title.isEmpty ? "Untitled Artifact" : artifact.title)
                            .font(.body)
                            .fontWeight(artifact.title.isEmpty ? .regular : .medium)
                            .lineLimit(2)
                        
                        if !artifact.content.isEmpty {
                            Text("\(artifact.content.count) characters")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .contextMenu {
                        Button("Edit") {
                            selectedArtifact = artifact
                        }
                        Button("Duplicate") {
                            duplicateArtifact(artifact)
                        }
                        Button(artifact.artifactState == .archived ? "Unarchive" : "Archive") {
                            toggleArchiveArtifact(artifact)
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            deleteArtifact(artifact)
                        }
                    }
                }
            }
            .width(min: 200, ideal: 300)
            
            TableColumn("Status") { listItem in
                switch listItem {
                case .draft(let draft):
                    if draft.scheduledOrPublishedDate != nil {
                        let isScheduled = draft.associatedPostID != nil
                        let statusText = isScheduled ? "Scheduled" : "Published"
                        let statusColor = isScheduled ? Color.kosmicBlue : Color.kosmicGreen
                        
                        HStack(spacing: 6) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 8, height: 8)
                            Text(statusText)
                                .font(.caption)
                                .foregroundColor(statusColor)
                        }
                    } else if draft.caption.isEmpty {
                        Text("Empty")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        Text("Ready")
                            .font(.caption)
                            .foregroundColor(.kosmicGreen)
                    }
                case .artifact(let artifact):
                    ArtifactStateBadge(state: artifact.artifactState)
                }
            }
            .width(min: 100)
            
            TableColumn("Tags") { listItem in
                let tags: [String] = {
                    switch listItem {
                    case .draft(let draft):
                        return draft.tags
                    case .artifact(let artifact):
                        return artifact.tags
                    }
                }()
                
                Group {
                    if !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(tags.prefix(3), id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.kosmicBlue.opacity(0.1))
                                        .foregroundColor(.kosmicBlue)
                                        .cornerRadius(4)
                                }
                                if tags.count > 3 {
                                    Text("+\(tags.count - 3)")
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
            }
            .width(min: 150)
            
            TableColumn("Updated") { listItem in
                let date: Date = {
                    switch listItem {
                    case .draft(let draft):
                        return draft.updatedAt
                    case .artifact(let artifact):
                        return artifact.updatedAt
                    }
                }()
                
                Text(date, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .width(min: 120)
        }
    }
    
    enum DraftItem: Identifiable {
        case draft(Draft)
        case artifact(CloutmateShared.Artifact)
        
        var id: UUID {
            switch self {
            case .draft(let draft): return draft.id
            case .artifact(let artifact): return artifact.id
            }
        }
        
        var updatedAt: Date {
            switch self {
            case .draft(let draft): return draft.updatedAt
            case .artifact(let artifact): return artifact.updatedAt
            }
        }
    }
    
    var combinedItems: [DraftItem] {
        var items: [DraftItem] = []
        items.append(contentsOf: draftsToShow.map { .draft($0) })
        items.append(contentsOf: artifactsToShow.map { .artifact($0) })
        return items.sorted { item1, item2 in
            let date1 = item1.updatedAt
            let date2 = item2.updatedAt
            return date1 > date2
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchAndFiltersSection
            
            if combinedItems.isEmpty {
                ContentUnavailableView(
                    (allDrafts.isEmpty && draftArtifacts.isEmpty) ? "No Drafts" : "No matches",
                    systemImage: "doc.text",
                    description: Text((allDrafts.isEmpty && draftArtifacts.isEmpty) ? "Create a draft or artifact to get started" : "Try a different search or filter")
                )
                .frame(maxHeight: .infinity)
            } else {
                tableSection
            }
        }
        .background(Color(.windowBackgroundColor))
        .navigationTitle("Drafts")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !selectedDrafts.isEmpty || !selectedArtifacts.isEmpty {
                    Menu("Actions") {
                        Button("Convert Selected to Artifacts", systemImage: "sparkles") {
                            convertSelectedToArtifacts()
                        }
                        Button("Archive Selected", systemImage: "archivebox") {
                            archiveSelected()
                        }
                        Button("Delete Selected", systemImage: "trash", role: .destructive) {
                            deleteSelected()
                        }
                    }
                }
                
                Menu("New") {
                    Button(action: { showCreateDraftSheet = true }) {
                        Label("New Draft", systemImage: "doc.text")
                    }
                    Button(action: { showArtifactComposer = true }) {
                        Label("New Artifact", systemImage: "sparkles")
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateDraftSheet) {
            CreateDraftSheet()
        }
        .sheet(isPresented: $showArtifactComposer) {
            ArtifactComposerView()
        }
        .sheet(isPresented: $showTemplates) {
            TemplateManagementView()
        }
        .sheet(item: $draftToConvert) { draft in
            ComposerWindow(
                draft: draft,
                onSave: { result in
                    conversionResult = result
                    draftToHandle = draft
                    showConversionAlert = true
                }
            )
            .frame(width: 700, height: 800)
        }
        .sheet(item: $selectedArtifact) { artifact in
            ArtifactComposerView(existingArtifact: artifact)
        }
        .alert("", isPresented: $showConversionAlert, presenting: conversionResult) { result in
            Button("Keep Draft") {
                if let draft = draftToHandle, let result = conversionResult {
                    handleDraftKept(draft: draft, result: result)
                }
            }
            Button("Remove") {
                if let draft = draftToHandle {
                    handleDraftRemoved(draft: draft)
                }
            }
        } message: { result in
            Text(result.status == .scheduled 
                ? "Your post has been scheduled. Would you like to remove this draft?"
                : "Your post has been published. Would you like to remove this draft?")
        }
    }
    
    private func createNewDraft() {
        let newDraft = Draft()
        modelContext.insert(newDraft)
        try? modelContext.save()
    }
    
    private func deleteDraft(_ draft: Draft) {
        withAnimation {
            if selectedDrafts.contains(draft.id) {
                selectedDrafts.remove(draft.id)
            }
            modelContext.delete(draft)
            try? modelContext.save()
        }
    }
    
    private func duplicateDraft(_ draft: Draft) {
        let newDraft = Draft(
            caption: draft.caption,
            mediaURLs: draft.mediaURLs,
            tags: draft.tags,
            notes: draft.notes
        )
        modelContext.insert(newDraft)
        try? modelContext.save()
    }
    
    private func toggleArchive(_ draft: Draft) {
        draft.isArchived.toggle()
        if selectedDrafts.contains(draft.id) {
            selectedDrafts.remove(draft.id)
        }
        try? modelContext.save()
    }
    
    private func archiveSelectedDrafts() {
        let draftsToArchive = draftsToShow.filter { selectedDrafts.contains($0.id) }
        for draft in draftsToArchive {
            draft.isArchived = true
        }
        selectedDrafts.removeAll()
        try? modelContext.save()
    }
    
    private func archiveSelectedArtifacts() {
        let artifactsToArchive = artifactsToShow.filter { selectedArtifacts.contains($0.id) }
        for artifact in artifactsToArchive {
            artifact.artifactState = .archived
        }
        selectedArtifacts.removeAll()
        try? modelContext.save()
    }
    
    private func archiveSelected() {
        archiveSelectedDrafts()
        archiveSelectedArtifacts()
    }
    
    private func deleteSelectedDrafts() {
        let draftsToDelete = draftsToShow.filter { selectedDrafts.contains($0.id) }
        for draft in draftsToDelete {
            modelContext.delete(draft)
        }
        selectedDrafts.removeAll()
        try? modelContext.save()
    }
    
    private func deleteSelectedArtifacts() {
        let artifactsToDelete = artifactsToShow.filter { selectedArtifacts.contains($0.id) }
        for artifact in artifactsToDelete {
            modelContext.delete(artifact)
        }
        selectedArtifacts.removeAll()
        try? modelContext.save()
    }
    
    private func deleteSelected() {
        deleteSelectedDrafts()
        deleteSelectedArtifacts()
    }
    
    private func convertSelectedToPosts() {
        let draftsToConvert = draftsToShow.filter { selectedDrafts.contains($0.id) }
        for draft in draftsToConvert.prefix(1) {
            convertToPost(draft)
        }
    }
    
    private func convertSelectedToArtifacts() {
        let draftsToConvert = draftsToShow.filter { selectedDrafts.contains($0.id) }
        for draft in draftsToConvert {
            convertDraftToArtifact(draft)
        }
    }
    
    private func convertToPost(_ draft: Draft) {
        draftToConvert = draft
    }
    
    private func convertDraftToArtifact(_ draft: Draft) {
        let artifact = ArtifactMigrationService.shared.migrateDraftToArtifact(draft, context: modelContext)
        modelContext.insert(artifact)
        try? modelContext.save()
    }
    
    private func deleteArtifact(_ artifact: CloutmateShared.Artifact) {
        withAnimation {
            if selectedArtifacts.contains(artifact.id) {
                selectedArtifacts.remove(artifact.id)
            }
            modelContext.delete(artifact)
            try? modelContext.save()
        }
    }
    
    private func duplicateArtifact(_ artifact: CloutmateShared.Artifact) {
        let newArtifact = Artifact(
            title: artifact.title,
            content: artifact.content,
            mediaURLs: artifact.mediaURLs,
            outputFormat: artifact.format,
            state: .draft,
            tags: artifact.tags
        )
        modelContext.insert(newArtifact)
        try? modelContext.save()
    }
    
    private func toggleArchiveArtifact(_ artifact: CloutmateShared.Artifact) {
        if artifact.artifactState == .archived {
            artifact.artifactState = .draft
        } else {
            artifact.artifactState = .archived
        }
        if selectedArtifacts.contains(artifact.id) {
            selectedArtifacts.remove(artifact.id)
        }
        try? modelContext.save()
    }
    
    private func applyTemplate(_ template: CloutmateShared.Template, to draft: Draft) {
        draft.caption = template.caption
        draft.tags = template.tags
        draft.updatedAt = Date()
    }
    
    private func handleDraftKept(draft: Draft, result: DraftConversionResult) {
        // Update draft with conversion metadata
        draft.associatedPostID = result.postID
        draft.convertedAt = Date()
        draft.scheduledOrPublishedDate = result.date
        
        // Check if auto-clean is enabled
        let autoClean = UserDefaults.standard.bool(forKey: "autoCleanDrafts")
        if autoClean {
            // Auto-clean enabled, delete immediately
            if selectedDraft == draft {
                selectedDraft = nil
            }
            modelContext.delete(draft)
        } else {
            // Keep draft but archive it
            draft.isArchived = true
        }
    }
    
    private func handleDraftRemoved(draft: Draft) {
        if selectedDraft == draft {
            selectedDraft = nil
        }
        modelContext.delete(draft)
    }
}

struct DraftRow: View {
    let draft: Draft
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(draft.caption.isEmpty ? "Untitled Draft" : draft.caption)
                .lineLimit(2)
                .font(.body)
                .fontWeight(draft.caption.isEmpty ? .regular : .medium)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if !draft.caption.isEmpty {
                Text("\(draft.caption.count) characters")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text(draft.updatedAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !draft.tags.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "tag.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(draft.tags.count)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Dynamic status tag based on draft state
                if let date = draft.scheduledOrPublishedDate {
                    // Draft has been converted
                    let isScheduled = draft.associatedPostID != nil
                    let statusText = isScheduled ? "Scheduled" : "Published"
                    let statusColor = isScheduled ? Color.kosmicBlue : Color.kosmicGreen
                    
                    Text("\(statusText) \(date, format: .dateTime.month().day().hour().minute())")
                        .font(.caption)
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.1))
                        .cornerRadius(4)
                } else if draft.caption.isEmpty {
                    Text("Empty")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(4)
                } else {
                    Text("Ready")
                        .font(.caption)
                        .foregroundColor(.kosmicGreen)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.kosmicGreen.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
}

struct DraftListSidebar: View {
    let activeDrafts: [Draft]
    let archivedDrafts: [Draft]
    @Binding var isArchiveExpanded: Bool
    @Binding var selectedDraft: Draft?
    let onDraftSelected: (Draft) -> Void
    let onDelete: (Draft) -> Void
    let onDuplicate: (Draft) -> Void
    let onConvertToPost: (Draft) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Drafts")
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                Spacer()
            }
            
            Divider()
            
            // Drafts list
            ScrollView {
                VStack(spacing: 0) {
                    // Active Drafts
                    if !activeDrafts.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(activeDrafts) { draft in
                                DraftListItem(
                                    draft: draft,
                                    isSelected: selectedDraft?.id == draft.id,
                                    onSelect: { onDraftSelected(draft) },
                                    onDelete: { onDelete(draft) },
                                    onDuplicate: { onDuplicate(draft) },
                                    onConvertToPost: { onConvertToPost(draft) }
                                )
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Archive Section
                    if !archivedDrafts.isEmpty {
                        Divider()
                            .padding(.vertical, 8)
                        
                        Button(action: { withAnimation { isArchiveExpanded.toggle() } }) {
                            HStack {
                                Image(systemName: "archivebox")
                                    .foregroundColor(.secondary)
                                Text("Archived")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Image(systemName: isArchiveExpanded ? "chevron.down" : "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        
                        if isArchiveExpanded {
                            VStack(spacing: 8) {
                                ForEach(archivedDrafts) { draft in
                                    DraftListItem(
                                        draft: draft,
                                        isSelected: selectedDraft?.id == draft.id,
                                        onSelect: { onDraftSelected(draft) },
                                        onDelete: { onDelete(draft) },
                                        onDuplicate: { onDuplicate(draft) },
                                        onConvertToPost: { onConvertToPost(draft) }
                                    )
                                    .opacity(0.7)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct DraftListItem: View {
    let draft: Draft
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    let onConvertToPost: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            Button(action: onSelect) {
                DraftRow(draft: draft)
            }
            .buttonStyle(.plain)
            .glassPanel(
                tier: isSelected ? .overlay : .contentCard,
                cornerRadius: 12,
                tintColor: isSelected ? Color.kosmicBlue.opacity(0.15) : nil
            )
            .shadow(
                color: isSelected ? Color.kosmicBlue.opacity(0.2) : .black.opacity(0.05),
                radius: isSelected ? 8 : 2,
                y: isSelected ? 4 : 1
            )
        }
        .padding(.horizontal, 12)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(GlassMotion.Easing.spring, value: isHovered)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < -50 {
                        onDelete()
                    }
                }
        )
        .contextMenu {
            Button("Duplicate", systemImage: "doc.on.doc") {
                onDuplicate()
            }
            
            Button("Convert to Post", systemImage: "paperplane") {
                onConvertToPost()
            }
            
            Divider()
            
            Button("Delete", systemImage: "trash", role: .destructive) {
                onDelete()
            }
        }
    }
}

struct CreateDraftSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var caption = ""
    @State private var notes = ""
    @State private var tags = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Caption")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Enter draft caption...", text: $caption, axis: .vertical)
                        .lineLimit(3...10)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $notes)
                        .font(.body)
                        .frame(minHeight: 200)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags (comma separated)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("e.g., work, ideas", text: $tags)
                        .textFieldStyle(.roundedBorder)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Create Draft") {
                        createDraft()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("New Draft")
        }
        .frame(width: 800, height: 600)
    }
    
    private func createDraft() {
        let draftTags = tags.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let newDraft = Draft(
            caption: caption,
            tags: draftTags,
            notes: notes.isEmpty ? nil : notes
        )
        modelContext.insert(newDraft)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    DraftsView()
        .modelContainer(for: [Draft.self])
}

