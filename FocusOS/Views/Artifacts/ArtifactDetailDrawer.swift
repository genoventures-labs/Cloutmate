    private func insightRow<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundColor(.kosmicPurple)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                content()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

//
//  ArtifactDetailDrawer.swift
//  FocusOS
//
//  Artifacts V2 - Detail drawer for editing artifacts
//

import SwiftUI
import SwiftData
import FocusOSShared

private struct ArtifactDraft: Equatable {
    var title: String
    var content: String
    var format: OutputFormat
    var state: ArtifactState
    var tags: [String]
    var linkedEntityIds: [UUID]
    var linkedEntityTypes: [String]
    var sentimentSummary: String?
    var auroraNotes: String?
    var confidenceScore: Double
    var publishedAt: Date?
    var projectId: UUID?
    var areaId: UUID?
    var createdAt: Date
    var updatedAt: Date
    
    init(artifact: Artifact) {
        self.title = artifact.title
        self.content = artifact.content
        self.format = artifact.format
        self.state = artifact.artifactState
        self.tags = artifact.tags
        self.linkedEntityIds = artifact.linkedEntityIds
        self.linkedEntityTypes = artifact.linkedEntityTypes
        self.sentimentSummary = artifact.sentimentSummary
        self.auroraNotes = artifact.auroraNotes
        self.confidenceScore = artifact.confidenceScore
        self.publishedAt = artifact.publishedAt
        self.projectId = artifact.projectId
        self.areaId = artifact.areaId
        self.createdAt = artifact.createdAt
        self.updatedAt = artifact.updatedAt
    }
    
    var canCommit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct ArtifactDetailDrawer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @Bindable var artifact: Artifact
    
    @State private var draft: ArtifactDraft
    @State private var mode: ComposerMode = .craft
    @State private var newTagText: String = ""
    @FocusState private var isContentFocused: Bool
    
    @State private var linkedTasks: [Task] = []
    @State private var linkedProjects: [Project] = []
    @State private var linkedAreas: [Area] = []
    @State private var linkedNotes: [Note] = []
    @State private var associatedProject: Project?
    @State private var associatedArea: Area?
    
    init(artifact: Artifact) {
        self._artifact = Bindable(artifact)
        _draft = State(initialValue: ArtifactDraft(artifact: artifact))
        _mode = State(initialValue: artifact.title.isEmpty ? .capture : .craft)
    }
    
    private var accentIntensity: Double {
        max(0.25, min(0.95, draft.confidenceScore))
    }
    
    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.kosmicBlue.opacity(0.35 + accentIntensity * 0.4),
                Color.kosmicPurple.opacity(0.3 + accentIntensity * 0.35)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    var body: some View {
        NavigationStack {
            V2DrawerScaffold(
                accentGradient: accentGradient,
                showsSidebar: false,
                header: { headerContent },
                content: {
                    detailsSection
                    contentSection
                    tagsSection
                    linkedContextSection
                    analyticsSection
                },
                sidebar: { EmptyView() }
            )
            .frame(minWidth: 960, minHeight: 660)
        }
        .onEscape {
            dismiss()
        }
        .onAppear {
            loadAssociations()
            loadLinkedEntities()
        }
        .onChange(of: draft.linkedEntityIds) { _, _ in
            loadLinkedEntities()
        }
        .onChange(of: draft.projectId) { _, _ in
            loadAssociations()
        }
        .onChange(of: draft.areaId) { _, _ in
            loadAssociations()
        }
    }
    
    // MARK: - Layout
    
    private var headerContent: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 14) {
                TextField("Artifact Title", text: $draft.title)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.semibold)
                    .textFieldStyle(.plain)
                    .drawerFocusGlow()
                
                HStack(spacing: 12) {
                    metadataPill(
                        title: draft.state.displayName,
                        icon: "flag.fill",
                        tint: .kosmicBlue.opacity(0.8)
                    )
                    metadataPill(
                        title: draft.format.displayName,
                        icon: "doc.richtext",
                        tint: .kosmicPurple.opacity(0.8)
                    )
                    
                    if let project = associatedProject {
                        metadataPill(
                            title: project.title,
                            icon: "folder.fill",
                            tint: .kosmicBlue.opacity(0.6)
                        )
                    }
                    
                    if let area = associatedArea {
                        metadataPill(
                            title: area.title,
                            icon: "rectangle.grid.2x2",
                            tint: .kosmicGreen.opacity(0.6)
                        )
                    }
                }
            }
            
            Spacer(minLength: 24)
            
            VStack(spacing: 12) {
                GlassButton(
                    "Close",
                    icon: "xmark",
                    style: .standard,
                    role: .surface
                ) {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                GlassButton(
                    "Save Changes",
                    icon: "tray.and.arrow.down.fill",
                    style: .standard,
                    role: .primary
                ) {
                    saveChanges()
                    dismiss()
                }
                .disabled(!draft.canCommit)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
    }
    
    private var detailsSection: some View {
        DrawerSection(title: "Details", icon: "slider.horizontal.3") {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 16) {
                GridRow {
                    detailField(title: "Composer Mode") {
                        Picker("Mode", selection: $mode) {
                            Text("Capture").tag(ComposerMode.capture)
                            Text("Craft").tag(ComposerMode.craft)
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    detailField(title: "Format") {
                        Menu {
                            Picker("Format", selection: $draft.format) {
                                ForEach(OutputFormat.allCases, id: \.self) { format in
                                    Text(format.displayName).tag(format)
                                }
                            }
                            .pickerStyle(.inline)
                        } label: {
                            metaBadge(icon: "doc.richtext", title: draft.format.displayName)
                        }
                        .menuStyle(.borderlessButton)
                    }
                }
                
                GridRow {
                    detailField(title: "State") {
                        Menu {
                            Picker("State", selection: $draft.state) {
                                ForEach(ArtifactState.allCases, id: \.self) { state in
                                    Text(state.displayName).tag(state)
                                }
                            }
                            .pickerStyle(.inline)
                        } label: {
                            metaBadge(icon: "flag", title: draft.state.displayName)
                        }
                        .menuStyle(.borderlessButton)
                    }
                    
                    detailField(title: draft.publishedAt == nil ? "Publish" : "Published") {
                        publicationControl
                    }
                }
                
                GridRow {
                    detailField(title: "Associations") {
                        VStack(alignment: .leading, spacing: 8) {
                            if let project = associatedProject {
                                associationChip(icon: "folder", color: .kosmicBlue, title: project.title, label: "Project")
                            }
                            
                            if let area = associatedArea {
                                associationChip(icon: "rectangle.grid.2x2", color: .kosmicGreen, title: area.title, label: "Area")
                            }
                            
                            if associatedProject == nil && associatedArea == nil {
                                Text("Link to a project or area for surfaced reviews.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .gridCellColumns(2)
                }
            }
        }
    }
    
    private var contentSection: some View {
        DrawerSection(
            title: mode == .capture ? "Quick Capture" : "Crafted Content",
            icon: mode == .capture ? "pencil.line" : "sparkles",
            subtitle: mode == .capture ? "Capture raw thoughts with mentions for later refinement" : "Polish the artifact before publishing"
        ) {
            MentionTextEditor(
                text: $draft.content,
                placeholder: mode == .capture ? "Quick capture idea…" : "Write your artifact…",
                excludeObjectId: artifact.id,
                excludeObjectType: .artifact
            ) { ids, types in
                draft.linkedEntityIds = ids
                draft.linkedEntityTypes = types
            }
            .frame(minHeight: mode == .capture ? 240 : 320)
            .drawerFocusGlow()
        }
    }
    
    private var tagsSection: some View {
        DrawerSection(title: "Tags", icon: "number", subtitle: "Categorize this artifact for future retrieval") {
            if !draft.tags.isEmpty {
                NoteTagFlowLayout(spacing: 8) {
                    ForEach(draft.tags, id: \.self) { tag in
                        HStack(spacing: 6) {
                            Text("#\(tag)")
                                .font(.caption)
                            Button {
                                removeTag(tag)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.kosmicBlue.opacity(0.14))
                        .foregroundColor(.kosmicBlue)
                        .cornerRadius(8)
                    }
                }
            } else {
                Text("Add tags to map this artifact inside Aurora’s knowledge graph.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 10) {
                TextField("Add tag", text: $newTagText)
                    .textFieldStyle(.plain)
                    .onSubmit(addTag)
                
                Button(action: addTag) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.kosmicBlue)
                }
                .buttonStyle(.plain)
                .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .drawerFocusGlow()
        }
    }
    
    private var linkedContextSection: some View {
        DrawerSection(title: "Linked Context", icon: "link", subtitle: "Entities connected through mentions") {
            if linkedTasks.isEmpty && linkedProjects.isEmpty && linkedAreas.isEmpty && linkedNotes.isEmpty {
                Text("Mention tasks, projects, areas, or notes using @ to create dynamic links.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    if !linkedProjects.isEmpty {
                        LinkedEntityGroup(title: "Projects", icon: "folder", color: .kosmicPurple, items: linkedProjects.map(\.title))
                    }
                    if !linkedTasks.isEmpty {
                        LinkedEntityGroup(title: "Tasks", icon: "checkmark.circle", color: .kosmicBlue, items: linkedTasks.map(\.title))
                    }
                    if !linkedAreas.isEmpty {
                        LinkedEntityGroup(title: "Areas", icon: "rectangle.grid.2x2", color: .kosmicGreen, items: linkedAreas.map(\.title))
                    }
                    if !linkedNotes.isEmpty {
                        LinkedEntityGroup(title: "Notes", icon: "note.text", color: .kosmicCyan, items: linkedNotes.map(\.title))
                    }
                }
            }
        }
    }
    
    private var analyticsSection: some View {
        Group {
            DrawerSection(title: "Aurora Insights", icon: "sparkles") {
                VStack(alignment: .leading, spacing: 18) {
                    insightRow(
                        title: "Confidence Score",
                        icon: "shield.lefthalf.fill",
                        content: {
                            Text("\(Int(draft.confidenceScore * 100))% confidence")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.kosmicPurple)
                        }
                    )
                    
                    insightRow(
                        title: "Sentiment",
                        icon: "face.smiling",
                        content: {
                            Text(
                                draft.sentimentSummary?.isEmpty == false
                                ? draft.sentimentSummary!
                                : "Sentiment analysis will appear after Aurora reviews this artifact."
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    )
                    
                    insightRow(
                        title: "Aurora Notes",
                        icon: "wand.and.stars",
                        content: {
                            Text(
                                draft.auroraNotes?.isEmpty == false
                                ? draft.auroraNotes!
                                : "Aurora will populate notes after processing this artifact."
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    )
                }
            }
            
            DrawerSection(title: "History", icon: "clock.badge") {
                VStack(alignment: .leading, spacing: 8) {
                    timelineRow(icon: "calendar.badge.plus", label: "Created", value: draft.createdAt.formatted(date: .abbreviated, time: .shortened))
                    timelineRow(icon: "calendar.badge.clock", label: "Updated", value: draft.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    
                    if let publishedAt = draft.publishedAt {
                        timelineRow(icon: "calendar.badge.checkmark", label: "Published", value: publishedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func metaBadge(icon: String, title: String, tint: Color = .secondary) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(glassColorSystem.cardColor().opacity(0.45))
        )
        .foregroundStyle(tint)
    }
    
    private func associationChip(icon: String, color: Color, title: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
        }
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.12))
        .cornerRadius(10)
    }
    
    private func metadataPill(title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
            Text(title)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.18))
        .clipShape(Capsule())
        .foregroundColor(tint)
    }
    
    private func detailField<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            content()
        }
    }
    
    private func timelineRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.caption.weight(.medium))
            }
        }
    }
    
    private func addTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !draft.tags.contains(trimmed) else { return }
        draft.tags.append(trimmed)
        newTagText = ""
    }
    
    private func removeTag(_ tag: String) {
        draft.tags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
    }
    
    private var publicationControl: some View {
        Group {
            if let publishedAt = draft.publishedAt {
                metaBadge(
                    icon: "calendar.badge.clock",
                    title: publishedAt.formatted(date: .abbreviated, time: .omitted),
                    tint: .kosmicPurple
                )
            } else {
                Button {
                    draft.publishedAt = Date()
                    draft.state = .published
                } label: {
                    metaBadge(icon: "calendar.badge.plus", title: "Mark as shipped", tint: .kosmicBlue)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func loadLinkedEntities() {
        let ids = draft.linkedEntityIds
        guard !ids.isEmpty else {
            linkedTasks = []
            linkedProjects = []
            linkedAreas = []
            linkedNotes = []
            return
        }
        
        let idSet = Set(ids)
        
        linkedTasks = (try? modelContext.fetch(FetchDescriptor<Task>(
            predicate: #Predicate { idSet.contains($0.id) }
        ))) ?? []
        
        linkedProjects = (try? modelContext.fetch(FetchDescriptor<Project>(
            predicate: #Predicate { idSet.contains($0.id) }
        ))) ?? []
        
        linkedAreas = (try? modelContext.fetch(FetchDescriptor<Area>(
            predicate: #Predicate { idSet.contains($0.id) }
        ))) ?? []
        
        linkedNotes = (try? modelContext.fetch(FetchDescriptor<Note>(
            predicate: #Predicate { idSet.contains($0.id) }
        ))) ?? []
    }
    
    private func loadAssociations() {
        if let projectID = draft.projectId {
            associatedProject = try? modelContext.fetch(
                FetchDescriptor<Project>(predicate: #Predicate { $0.id == projectID })
            ).first
        } else {
            associatedProject = nil
        }
        
        if let areaID = draft.areaId {
            associatedArea = try? modelContext.fetch(
                FetchDescriptor<Area>(predicate: #Predicate { $0.id == areaID })
            ).first
        } else {
            associatedArea = nil
        }
    }
    
    private func saveChanges() {
        artifact.title = draft.title
        artifact.content = draft.content
        artifact.format = draft.format
        artifact.artifactState = draft.state
        artifact.tags = draft.tags
        artifact.linkedEntityIds = draft.linkedEntityIds
        artifact.linkedEntityTypes = draft.linkedEntityTypes
        artifact.sentimentSummary = draft.sentimentSummary
        artifact.auroraNotes = draft.auroraNotes
        artifact.confidenceScore = draft.confidenceScore
        artifact.publishedAt = draft.publishedAt
        artifact.projectId = draft.projectId
        artifact.areaId = draft.areaId
        artifact.updatedAt = Date()
        artifact.ensureTitle()
        
        ArtifactMentionService.shared.updateLinkedEntities(for: artifact, modelContext: modelContext)
        try? modelContext.save()
    }
}

// MARK: - Linked Entity Group

private struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.kosmicPurple)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

private struct LinkedEntityGroup: View {
    let title: String
    let icon: String
    let color: Color
    let items: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(color)
            }
            
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(color.opacity(0.08))
                    .cornerRadius(8)
            }
        }
    }
}

#Preview {
    ArtifactDetailDrawer(artifact: Artifact(title: "Product Launch Narrative", content: "Capture the positioning, emotional arc, and release notes."))
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [Artifact.self, Project.self, Task.self, Area.self, Note.self])
}

