//
//  JournalDetailDrawer.swift
//  Cloutmate
//
//  Modern side-drawer for composing and editing journals with draft support.
//

import SwiftUI
import SwiftData
import CloutmateShared

enum JournalTemplate {
    case morning
    case evening
    case freeWrite
    
    var content: String {
        switch self {
        case .morning:
            return "Today I intend to…"
        case .evening:
            return "Today I learned…"
        case .freeWrite:
            return ""
        }
    }
    
    var title: String {
        switch self {
        case .morning:
            return "Morning Intention"
        case .evening:
            return "Evening Reflection"
        case .freeWrite:
            return "Free Write"
        }
    }
}

struct JournalDraft: Equatable {
    var title: String
    var content: String
    var entryDate: Date
    var entryType: JournalEntryType
    var mood: JournalMood
    var tags: [String]
    var projectId: UUID?
    var areaId: UUID?
    var linkedNoteIds: [UUID]
    var linkedAreaIds: [UUID]
    var linkedProjectIds: [UUID]
    var linkedEntityIds: [UUID]
    var linkedEntityTypes: [String]
    var author: JournalAuthor
    var aiPrompt: String?
    var aiGeneratedContent: String?
    var auroraNotes: String?
    var isArchived: Bool
    
    init(
        title: String = "",
        content: String = "",
        entryDate: Date = Date(),
        entryType: JournalEntryType = .reflection,
        mood: JournalMood = .none,
        tags: [String] = [],
        projectId: UUID? = nil,
        areaId: UUID? = nil,
        linkedNoteIds: [UUID] = [],
        linkedAreaIds: [UUID] = [],
        linkedProjectIds: [UUID] = [],
        linkedEntityIds: [UUID] = [],
        linkedEntityTypes: [String] = [],
        author: JournalAuthor = .user,
        aiPrompt: String? = nil,
        aiGeneratedContent: String? = nil,
        auroraNotes: String? = nil,
        isArchived: Bool = false
    ) {
        self.title = title
        self.content = content
        self.entryDate = entryDate
        self.entryType = entryType
        self.mood = mood
        self.tags = tags
        self.projectId = projectId
        self.areaId = areaId
        self.linkedNoteIds = linkedNoteIds
        self.linkedAreaIds = linkedAreaIds
        self.linkedProjectIds = linkedProjectIds
        self.linkedEntityIds = linkedEntityIds
        self.linkedEntityTypes = linkedEntityTypes
        self.author = author
        self.aiPrompt = aiPrompt
        self.aiGeneratedContent = aiGeneratedContent
        self.auroraNotes = auroraNotes
        self.isArchived = isArchived
    }
    
    init(journal: Journal) {
        self.title = journal.title
        self.content = journal.content
        self.entryDate = journal.entryDate
        self.entryType = journal.journalEntryType
        self.mood = journal.journalMood
        self.tags = journal.tags
        self.projectId = journal.projectId
        self.areaId = journal.areaId
        self.linkedNoteIds = journal.linkedNoteIds
        self.linkedAreaIds = journal.linkedAreaIds
        self.linkedProjectIds = journal.linkedProjectIds
        self.linkedEntityIds = journal.linkedEntityIds
        self.linkedEntityTypes = journal.linkedEntityTypes
        self.author = journal.author
        self.aiPrompt = journal.aiPrompt
        self.aiGeneratedContent = journal.aiGeneratedContent
        self.auroraNotes = journal.auroraNotes
        self.isArchived = journal.isArchived
    }
    
    var canCommit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct JournalDetailDrawer: View {
    enum Mode {
        case create
        case edit
    }
    
    let mode: Mode
    let existingJournal: Journal?
    
    let template: JournalTemplate?
    let initialDraft: JournalDraft
    @Binding var isPresented: Bool
    let onCommit: (JournalDraft) -> Void
    let onCancel: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isContentFocused: Bool
    
    @State private var draft: JournalDraft
    @State private var newTagText: String = ""
    @State private var aiSummary: String?
    @State private var isGeneratingSummary = false
    @State private var isSummaryExpanded = true
    
    @State private var linkedTasks: [Task] = []
    @State private var linkedProjects: [Project] = []
    @State private var linkedArtifacts: [Artifact] = []
    
    init(
        mode: Mode,
        existingJournal: Journal?,
        template: JournalTemplate? = nil,
        initialDraft: JournalDraft,
        isPresented: Binding<Bool>,
        onCommit: @escaping (JournalDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.mode = mode
        self.existingJournal = existingJournal
        self.template = template
        self.initialDraft = initialDraft
        self._isPresented = isPresented
        self.onCommit = onCommit
        self.onCancel = onCancel
        _draft = State(initialValue: initialDraft)
        _aiSummary = State(initialValue: initialDraft.aiGeneratedContent)
    }
    
    private var accentIntensity: Double {
        guard let journal = existingJournal else { return 0.2 }
        let daysSinceUpdate = Calendar.current.dateComponents([.day], from: journal.updatedAt, to: Date()).day ?? 0
        let daysSinceCreation = Calendar.current.dateComponents([.day], from: journal.createdAt, to: Date()).day ?? 1
        let recencyScore = max(0, 1.0 - (Double(daysSinceUpdate) / 30.0))
        let updateFrequency = Double(daysSinceCreation) > 0 ? Double(journal.content.count) / Double(daysSinceCreation) : 0.0
        let frequencyScore = min(1.0, updateFrequency / 100.0)
        return max(0.2, (recencyScore + frequencyScore) / 2.0)
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
                    if hasLinkedItems {
                        linkedItemsSection
                    }
                    if mode == .create {
                        templatesSection
                    }
                    if mode == .edit {
                        auroraSummarySection
                    }
                },
                sidebar: { EmptyView() }
            )
            .frame(minWidth: 840, minHeight: 640)
        }
        .onEscape { cancel() }
        .onAppear(perform: handleOnAppear)
        .onChange(of: draft.linkedEntityIds) { _, _ in
            loadLinkedItems()
        }
        .onChange(of: isPresented) { _, newValue in
            if !newValue {
                resetState()
            }
        }
    }
    
    // MARK: - Layout Sections
    
    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.kosmicBlue.opacity(0.35 + accentIntensity * 0.4),
                Color.kosmicPurple.opacity(0.3 + accentIntensity * 0.3)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var headerContent: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    TextField("Journal Title", text: $draft.title)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .textFieldStyle(.plain)
                        .foregroundStyle(glassColorSystem.textPrimary())
                        .disableAutocorrection(true)
                        .drawerFocusGlow()
                    
                    if draft.author == .aurora {
                        AuroraAuthorBadge()
                    }
                }
                
                HStack(spacing: 14) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12, weight: .medium))
                        Text(draft.entryDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(glassColorSystem.textSecondary())
                    
                    HStack(spacing: 6) {
                        Image(systemName: "doc.richtext")
                            .font(.system(size: 12, weight: .medium))
                        Text(draft.entryType.rawValue.capitalized)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(glassColorSystem.textSecondary())
                    
                    HStack(spacing: 6) {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 12, weight: .medium))
                        Text(draft.mood.rawValue.capitalized)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(glassColorSystem.textSecondary())
                    
                    if !draft.tags.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "tag.fill")
                                .font(.system(size: 12, weight: .medium))
                            Text("\(draft.tags.count) tag\(draft.tags.count == 1 ? "" : "s")")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(glassColorSystem.textSecondary())
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                GlassButton(
                    mode == .create ? "Create Entry" : "Done",
                    icon: mode == .create ? "plus" : "checkmark",
                    style: .pill,
                    role: .primary
                ) {
                    commit()
                }
                .disabled(!draft.canCommit)
                .keyboardShortcut(.return, modifiers: [])
                
                GlassButton(
                    nil,
                    icon: "xmark",
                    style: .iconOnly,
                    role: .surface,
                    tintColor: glassColorSystem.backgroundElevated()
                ) {
                    cancel()
                }
                .accessibilityLabel("Close")
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
    }
    
    private var detailsSection: some View {
        DrawerSection(title: "Entry Details", icon: "slider.horizontal.3") {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 16) {
                GridRow {
                    detailField(title: "Entry Type") {
                        Picker("Entry Type", selection: $draft.entryType) {
                            ForEach(JournalEntryType.allCases, id: \.self) { type in
                                Text(type.rawValue.capitalized).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    detailField(title: "Mood") {
                        Picker("Mood", selection: $draft.mood) {
                            ForEach(JournalMood.allCases, id: \.self) { mood in
                                Text(mood.rawValue.capitalized).tag(mood)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                GridRow {
                    detailField(title: "Entry Date") {
                        DatePicker(
                            "",
                            selection: $draft.entryDate,
                            displayedComponents: [.date]
                        )
                        .labelsHidden()
                    }
                    .gridCellColumns(2)
                }
            }
        }
    }
    
    private var contentSection: some View {
        DrawerSection(title: "Content", icon: "square.and.pencil", subtitle: "Capture your reflection and context links") {
            MentionTextEditor(
                text: $draft.content,
                placeholder: "Capture your thoughts…",
                excludeObjectId: existingJournal?.id,
                excludeObjectType: nil
            ) { ids, types in
                draft.linkedEntityIds = ids
                draft.linkedEntityTypes = types
            }
            .frame(minHeight: 260)
            .focused($isContentFocused)
            .drawerFocusGlow()
        }
    }
    
    private var tagsSection: some View {
        DrawerSection(title: "Tags", icon: "tag.fill") {
            VStack(alignment: .leading, spacing: 14) {
                if draft.tags.isEmpty {
                    Text("Add tags to surface this entry in reflections and search.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                } else {
                    NoteTagFlowLayout(spacing: 8) {
                        ForEach(draft.tags, id: \.self) { tag in
                            HStack(spacing: 6) {
                                Text("#\(tag)")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                Button {
                                    removeTag(tag)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(glassColorSystem.emotionalAccent().opacity(0.18))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(glassColorSystem.emotionalAccent().opacity(0.35), lineWidth: 0.8)
                            )
                            .foregroundStyle(glassColorSystem.emotionalAccent())
                        }
                    }
                }
                
                HStack(spacing: 10) {
                    TextField("Add tag", text: $newTagText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(glassColorSystem.backgroundElevated().opacity(0.4))
                        )
                        .onSubmit(addTag)
                    
                    GlassButton(
                        nil,
                        icon: "plus",
                        style: .iconOnly,
                        role: .accent
                    ) {
                        addTag()
                    }
                    .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .drawerFocusGlow()
            }
        }
    }
    
    private var linkedItemsSection: some View {
        DrawerSection(title: "Linked Items", icon: "link", subtitle: "Mentions captured from this entry") {
            LinkedItemsSection(
                tasks: linkedTasks,
                projects: linkedProjects,
                artifacts: linkedArtifacts
            )
        }
    }
    
    private var templatesSection: some View {
        DrawerSection(title: "Templates", icon: "sparkles", subtitle: "Kick off with guided prompts or start freeform") {
            HStack(spacing: 12) {
                templateButton(.morning)
                templateButton(.evening)
                templateButton(.freeWrite)
            }
        }
    }
    
    private var auroraSummarySection: some View {
        DrawerSection(title: "Aurora Summary", icon: "sparkles") {
            JournalAISummarySection(
                summary: aiSummary,
                isGenerating: isGeneratingSummary,
                isExpanded: $isSummaryExpanded,
                onRegenerate: generateSummary
            )
        }
    }
    
    private func templateButton(_ template: JournalTemplate) -> some View {
        Button {
            applyTemplate(template)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(template.title)
                    .font(.caption.weight(.semibold))
                Text(template.content.isEmpty ? "Blank canvas" : template.content)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(glassColorSystem.cardColor().opacity(0.45))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private var hasLinkedItems: Bool {
        !linkedTasks.isEmpty || !linkedProjects.isEmpty || !linkedArtifacts.isEmpty
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
    
    // MARK: - Actions
    
    private func addTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !draft.tags.contains(trimmed) else { return }
        draft.tags.append(trimmed)
        newTagText = ""
    }
    
    private func removeTag(_ tag: String) {
        draft.tags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
    }
    
    private func applyTemplate(_ template: JournalTemplate) {
        switch template {
        case .morning:
            draft.entryType = .contentIdea
            draft.mood = .motivated
        case .evening:
            draft.entryType = .reflection
            draft.mood = .reflective
        case .freeWrite:
            draft.entryType = .reflection
        }
        
        draft.content = template.content
        draft.title = template.title
        isContentFocused = true
    }
    
    private func handleOnAppear() {
        if mode == .create {
            draft.entryDate = Date()
            if draft.content.isEmpty, let template {
                applyTemplate(template)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isContentFocused = true
            }
        } else {
            loadLinkedItems()
        }
    }
    
    private func loadLinkedItems() {
        linkedTasks.removeAll()
        linkedProjects.removeAll()
        linkedArtifacts.removeAll()
        
        guard !draft.linkedEntityIds.isEmpty else { return }
        let idSet = Set(draft.linkedEntityIds)
        
        let taskDescriptor = FetchDescriptor<Task>(predicate: #Predicate { idSet.contains($0.id) })
        linkedTasks = (try? modelContext.fetch(taskDescriptor)) ?? []
        
        let projectDescriptor = FetchDescriptor<Project>(predicate: #Predicate { idSet.contains($0.id) })
        linkedProjects = (try? modelContext.fetch(projectDescriptor)) ?? []
        
        let artifactDescriptor = FetchDescriptor<Artifact>(predicate: #Predicate { idSet.contains($0.id) })
        linkedArtifacts = (try? modelContext.fetch(artifactDescriptor)) ?? []
    }
    
    private func resetState() {
        draft = initialDraft
        newTagText = ""
        aiSummary = initialDraft.aiGeneratedContent
        loadLinkedItems()
    }
    
    private func cancel() {
        onCancel()
        isPresented = false
    }
    
    private func commit() {
        var updatedDraft = draft
        updatedDraft.aiGeneratedContent = aiSummary
        onCommit(updatedDraft)
        isPresented = false
    }
    
    // MARK: - Insights & Analytics
    
    private func generateSummary() {
        guard !isGeneratingSummary, existingJournal != nil else { return }
        
        isGeneratingSummary = true
        
        _Concurrency.Task {
            do {
                let descriptor = DocumentDescriptor(
                    text: draft.content,
                    preview: String(draft.content.prefix(200)),
                    fileName: draft.title.isEmpty ? "Untitled Entry" : draft.title,
                    mimeType: "text/plain",
                    sizeInBytes: draft.content.utf8.count,
                    pageCount: nil,
                    sourceURL: nil
                )
                
                let result = try await OllamaBridgeService.shared.analyzeDocument(
                    descriptor: descriptor,
                    userPrompt: "Provide a concise reflection summary with key insights and emotional tone.",
                    appContext: buildAppContext(),
                    payloadContext: nil,
                    conversationMessages: nil,
                    currentMessageStyle: nil,
                    userStyleProfile: nil,
                    confidence: nil
                )
                
                await MainActor.run {
                    aiSummary = result.summary
                    draft.aiGeneratedContent = result.summary
                    isGeneratingSummary = false
                }
            } catch {
                await MainActor.run {
                    aiSummary = "Unable to generate summary: \(error.localizedDescription)"
                    isGeneratingSummary = false
                }
            }
        }
    }
    
    private func buildAppContext() -> String {
        var context = "Journal Entry: \(draft.title)\n"
        context += "Mood: \(draft.mood.rawValue)\n"
        context += "Type: \(draft.entryType.rawValue)\n"
        context += "Date: \(draft.entryDate.formatted(date: .abbreviated, time: .omitted))\n"
        return context
    }
}

// MARK: - Subviews

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

struct JournalAISummarySection: View {
    let summary: String?
    let isGenerating: Bool
    @Binding var isExpanded: Bool
    let onRegenerate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(GlassMotion.Easing.spring) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.kosmicPurple)
                    Text("AI Summary")
                        .font(.headline)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                if isGenerating {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Generating summary…")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                } else if let summary {
                    Text(summary)
                        .font(.callout)
                        .foregroundColor(.primary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    
                    GlassButton(
                        "Regenerate summary",
                        icon: "arrow.clockwise",
                        style: .standard,
                        role: .primary,
                        action: onRegenerate
                    )
                    .frame(maxWidth: 220, alignment: .leading)
                } else {
                    GlassButton(
                        "Generate summary",
                        icon: "sparkles",
                        style: .standard,
                        role: .primary,
                        action: onRegenerate
                    )
                    .frame(maxWidth: 240, alignment: .leading)
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var isPresented = true
    
    JournalDetailDrawer(
        mode: .edit,
        existingJournal: Journal(title: "Sample Entry", content: "This is a sample journal entry."),
        template: nil,
        initialDraft: JournalDraft(journal: Journal(title: "Sample Entry", content: "This is a sample journal entry.")),
        isPresented: $isPresented,
        onCommit: { _ in },
        onCancel: {}
    )
    .environmentObject(GlassColorSystem())
    .modelContainer(for: [Journal.self, Task.self, Project.self, Artifact.self])
}

