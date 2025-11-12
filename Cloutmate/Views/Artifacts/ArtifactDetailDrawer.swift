//
//  ArtifactDetailDrawer.swift
//  Cloutmate
//
//  Artifacts V2 - Detail drawer for editing artifacts
//

import SwiftUI
import SwiftData
import CloutmateShared

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
    
    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                accentBar
                
                VStack(spacing: 0) {
                    headerSection
                    Divider().opacity(0.08)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            overviewCard
                            contentCard
                            tagsCard
                            assetLinksCard
                        }
                        .padding(.vertical, 24)
                        .padding(.horizontal, 24)
                        .frame(maxWidth: 720, alignment: .leading)
                    }
                    .background(glassColorSystem.backgroundColor())
                }
                
                Divider().opacity(0.08)
                
                analyticsSidebar
            }
            .background(glassColorSystem.backgroundColor())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveChanges()
                        dismiss()
                    }
                    .disabled(!draft.canCommit)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(minWidth: 1080, minHeight: 680)
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
    
    private var accentBar: some View {
        LinearGradient(
            colors: [
                Color.kosmicBlue.opacity(accentIntensity),
                Color.kosmicPurple.opacity(accentIntensity * 0.85)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: 5)
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 0)
    }
    
    private var headerSection: some View {
        GlassPanel(tier: .overlay, cornerRadius: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    TextField("Artifact Title", text: $draft.title)
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                        .textFieldStyle(.plain)
                        .focused($isContentFocused, equals: false)
                    
                    Spacer()
                    
                    modeToggle
                }
                
                HStack(spacing: 12) {
                    stateControl
                    formatControl
                    
                    associationChips
                    
                    Spacer()
                    
                    publicationControl
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }
    
    private var overviewCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(
                    title: "Artifact Overview",
                    subtitle: "Define the intent and outcome for Aurora",
                    icon: "square.grid.2x2"
                )
                
                VStack(alignment: .leading, spacing: 12) {
                    if draft.projectId == nil && draft.areaId == nil {
                        Text("Link this artifact to a Project or Area to surface it in weekly reviews.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let project = associatedProject {
                        associationChip(icon: "folder", color: .kosmicBlue, title: project.title, label: "Project")
                    }
                    
                    if let area = associatedArea {
                        associationChip(icon: "rectangle.3.group", color: .kosmicGreen, title: area.title, label: "Area")
                    }
                }
            }
            .padding(20)
        }
    }
    
    private var contentCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: mode == .capture ? "Quick Capture" : "Crafted Content",
                    subtitle: mode == .capture ? "Capture raw thoughts with mentions for later refinement" : "Polish the artifact before publishing",
                    icon: mode == .capture ? "pencil.line" : "sparkles"
                )
                
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
                .cornerRadius(14)
            }
            .padding(20)
        }
    }
    
    private var tagsCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Tags",
                    subtitle: "Categorize this artifact for future retrieval",
                    icon: "number"
                )
                
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
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(glassColorSystem.glassTint(for: .surface).opacity(0.35))
                .cornerRadius(10)
            }
            .padding(20)
        }
    }
    
    private var assetLinksCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Linked Context",
                    subtitle: "Entities connected through mentions",
                    icon: "link"
                )
                
                if linkedTasks.isEmpty && linkedProjects.isEmpty && linkedAreas.isEmpty && linkedNotes.isEmpty {
                    Text("Mention tasks, projects, areas, or notes using @ to create dynamic links.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
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
            .padding(20)
        }
    }
    
    private var analyticsSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GlassPanel(tier: .contentCard, cornerRadius: 18) {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Confidence Score", subtitle: "Aurora’s confidence in this artifact", icon: "chart.bar.xaxis")
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: draft.confidenceScore)
                                .progressViewStyle(.linear)
                            
                            Text("\(Int(draft.confidenceScore * 100))% confident")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(18)
                }
                
                GlassPanel(tier: .contentCard, cornerRadius: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Sentiment", subtitle: "Aurora’s tonal analysis", icon: "face.smiling")
                        
                        if let sentiment = draft.sentimentSummary, !sentiment.isEmpty {
                            Text(sentiment)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Sentiment analysis will appear after Aurora reviews this artifact.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(18)
                }
                
                GlassPanel(tier: .contentCard, cornerRadius: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Aurora Notes", subtitle: "Internal observations and guidance", icon: "sparkles")
                        
                        TextEditor(text: Binding(
                            get: { draft.auroraNotes ?? "" },
                            set: { draft.auroraNotes = $0.isEmpty ? nil : $0 }
                        ))
                        .frame(minHeight: 120)
                        .background(glassColorSystem.glassTint(for: .surface).opacity(0.2))
                        .cornerRadius(12)
                    }
                    .padding(18)
                }
                
                GlassPanel(tier: .contentCard, cornerRadius: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "History", subtitle: "Timeline for this artifact", icon: "clock")
                        
                        timelineRow(icon: "calendar.badge.plus", label: "Created", value: draft.createdAt.formatted(date: .abbreviated, time: .shortened))
                        timelineRow(icon: "calendar.badge.clock", label: "Updated", value: draft.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        
                        if let publishedAt = draft.publishedAt {
                            timelineRow(icon: "calendar.badge.checkmark", label: "Published", value: publishedAt.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                    .padding(18)
                }
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
        }
        .frame(width: 320)
        .background(glassColorSystem.backgroundColor())
    }
    
    private var modeToggle: some View {
        Picker("Mode", selection: $mode) {
            Text("Capture").tag(ComposerMode.capture)
            Text("Craft").tag(ComposerMode.craft)
        }
        .pickerStyle(.segmented)
        .frame(width: 180)
    }
    
    private var stateControl: some View {
        Menu {
            Picker("State", selection: $draft.state) {
                ForEach(ArtifactState.allCases, id: \.self) { state in
                    Text(state.displayName).tag(state)
                }
            }
            .pickerStyle(.inline)
        } label: {
            metaBadge(icon: "flag", title: "State", value: draft.state.displayName)
        }
        .menuStyle(.borderlessButton)
    }
    
    private var formatControl: some View {
        Menu {
            Picker("Format", selection: $draft.format) {
                ForEach(OutputFormat.allCases, id: \.self) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .pickerStyle(.inline)
        } label: {
            metaBadge(icon: "doc.richtext", title: "Format", value: draft.format.displayName)
        }
        .menuStyle(.borderlessButton)
    }
    
    private var associationChips: some View {
        HStack(spacing: 8) {
            if let project = associatedProject {
                associationChip(icon: "folder", color: .kosmicBlue, title: project.title, label: "Project")
            }
            if let area = associatedArea {
                associationChip(icon: "rectangle.grid.2x2", color: .kosmicGreen, title: area.title, label: "Area")
            }
        }
    }
    
    // MARK: - Helpers
    
    private func metaBadge(icon: String, title: String, value: String, interactive: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                Text(title.uppercased())
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(interactive ? .kosmicBlue : .secondary)
            }
            Text(value)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(glassColorSystem.glassTint(for: .surface).opacity(interactive ? 0.5 : 0.3))
        )
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
                metaBadge(icon: "calendar.badge.clock", title: "Published", value: publishedAt.formatted(date: .abbreviated, time: .omitted))
            } else {
                Button {
                    draft.publishedAt = Date()
                    draft.state = .published
                } label: {
                    metaBadge(icon: "calendar.badge.plus", title: "Publish", value: "Mark as shipped", interactive: true)
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

