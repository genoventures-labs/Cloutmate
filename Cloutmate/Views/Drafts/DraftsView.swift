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
    @Query(sort: \Template.name) private var templates: [Template]
    
    @State private var searchText = ""
    @State private var showArchived: Bool = false
    @State private var selectedDrafts = Set<UUID>()
    @State private var selectedDraft: Draft?
    @State private var showTemplates = false
    @State private var showComposer = false
    @State private var draftToConvert: Draft?
    @State private var showConversionAlert = false
    @State private var conversionResult: DraftConversionResult?
    @State private var draftToHandle: Draft?
    @State private var showAutoCleanInfo = false
    @State private var autoCleanEnabled = UserDefaults.standard.bool(forKey: "autoCleanDrafts")
    @State private var showCreateDraftSheet = false
    
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
    
    private var searchAndFiltersSection: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search drafts...", text: $searchText)
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
    
    private var tableSection: some View {
        Table(draftsToShow, selection: $selectedDrafts) {
            TableColumn("Content") { draft in
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
                    Button("Convert to Post") {
                        convertToPost(draft)
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
            }
            .width(min: 200, ideal: 300)
            
            TableColumn("Status") { draft in
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
            }
            .width(min: 100)
            
            TableColumn("Tags") { draft in
                if !draft.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(draft.tags.prefix(3), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.kosmicBlue.opacity(0.1))
                                    .foregroundColor(.kosmicBlue)
                                    .cornerRadius(4)
                            }
                            if draft.tags.count > 3 {
                                Text("+\(draft.tags.count - 3)")
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
            
            TableColumn("Updated") { draft in
                Text(draft.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .width(min: 120)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchAndFiltersSection
            
            if draftsToShow.isEmpty {
                ContentUnavailableView(
                    allDrafts.isEmpty ? "No Drafts" : "No matches",
                    systemImage: "doc.text",
                    description: Text(allDrafts.isEmpty ? "Create a draft to get started" : "Try a different search or filter")
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
                if !selectedDrafts.isEmpty {
                    Menu("Actions") {
                        Button("Convert Selected to Posts", systemImage: "paperplane") {
                            convertSelectedToPosts()
                        }
                        Button("Archive Selected", systemImage: "archivebox") {
                            archiveSelectedDrafts()
                        }
                        Button("Delete Selected", systemImage: "trash", role: .destructive) {
                            deleteSelectedDrafts()
                        }
                    }
                }
                
                Button(action: { showCreateDraftSheet = true }) {
                    Label("New Draft", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateDraftSheet) {
            CreateDraftSheet()
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
    
    private func deleteSelectedDrafts() {
        let draftsToDelete = draftsToShow.filter { selectedDrafts.contains($0.id) }
        for draft in draftsToDelete {
            modelContext.delete(draft)
        }
        selectedDrafts.removeAll()
        try? modelContext.save()
    }
    
    private func convertSelectedToPosts() {
        let draftsToConvert = draftsToShow.filter { selectedDrafts.contains($0.id) }
        for draft in draftsToConvert.prefix(1) {
            convertToPost(draft)
        }
    }
    
    private func convertToPost(_ draft: Draft) {
        // Open the composer window with this draft's content
        // Using sheet(item:) automatically shows/hides based on draftToConvert
        draftToConvert = draft
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

