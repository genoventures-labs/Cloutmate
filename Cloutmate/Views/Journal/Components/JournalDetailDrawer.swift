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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isContentFocused: Bool
    
    @State private var draft: JournalDraft
    @State private var newTagText: String = ""
    @State private var aiSummary: String?
    @State private var isGeneratingSummary = false
    @State private var isSummaryExpanded = true
    @State private var emotionalState: EmotionalStateDetection?
    @State private var dailySnapshot: AnalyticsSnapshot?
    @State private var showAuroraChat = false
    
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
            HStack(spacing: 0) {
                accentBar
                
                VStack(spacing: 0) {
                    headerSection
                    Divider().opacity(0.08)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            entryDetailsCard
                            contentCard
                            tagsCard
                            if !linkedTasks.isEmpty || !linkedProjects.isEmpty || !linkedArtifacts.isEmpty {
                                linkedItemsCard
                            }
                            if mode == .create {
                                templateCard
                            }
                        }
                        .padding(.vertical, 24)
                        .padding(.horizontal, 24)
                        .frame(maxWidth: 680, alignment: .leading)
                    }
                    .background(glassColorSystem.backgroundColor())
                }
                
                if mode == .edit {
                    Divider().opacity(0.08)
                    insightsSidebar
                }
            }
            .background(glassColorSystem.backgroundColor())
            .navigationTitle("Journal Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        commit()
                    }
                    .keyboardShortcut(.return, modifiers: [])
                    .disabled(!draft.canCommit)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(minWidth: 960, minHeight: 640)
        .onAppear(perform: handleOnAppear)
        .onChange(of: draft.linkedEntityIds) { _, _ in
            loadLinkedItems()
        }
        .onChange(of: isPresented) { _, newValue in
            if !newValue {
                resetState()
            }
        }
        .sheet(isPresented: $showAuroraChat) {
            if let journal = existingJournal {
                AuroraJournalChatOverlay(journal: journal, isPresented: $showAuroraChat)
            }
        }
    }
    
    // MARK: - Layout Sections
    
    private var accentBar: some View {
        LinearGradient(
            colors: [
                Color.kosmicBlue.opacity(accentIntensity),
                Color.kosmicPurple.opacity(accentIntensity * 0.8)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: 4)
        .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 0)
    }
    
    private var headerSection: some View {
        GlassPanel(tier: .overlay, cornerRadius: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    TextField("Journal Title", text: $draft.title)
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                        .textFieldStyle(.plain)
                    
                    if draft.author == .aurora {
                        AuroraAuthorBadge()
                    }
                    
                    Spacer()
                }
                
                HStack(spacing: 12) {
                    typeControl
                    moodControl
                    dateControl
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
        }
    }
    
    private var entryDetailsCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(title: "Entry Details", subtitle: "Capture context and framing")
                
                if mode == .create {
                    Text("Choose a template or start freeform. Aurora will adapt the tone and structure.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Picker("Entry Type", selection: $draft.entryType) {
                            ForEach(JournalEntryType.allCases, id: \.self) { type in
                                Text(type.rawValue.capitalized).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        Picker("Mood", selection: $draft.mood) {
                            ForEach(JournalMood.allCases, id: \.self) { mood in
                                Text(mood.rawValue.capitalized).tag(mood)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 180)
                    }
                    
                    DatePicker(
                        "Entry Date",
                        selection: $draft.entryDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.compact)
                }
            }
            .padding(20)
        }
    }
    
    private var contentCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Content",
                    subtitle: "Mentions, context links, and reflective narrative",
                    icon: "square.and.pencil"
                )
                
                MentionTextEditor(
                    text: $draft.content,
                    placeholder: "Capture your thoughts…",
                    excludeObjectId: existingJournal?.id,
                    excludeObjectType: .journal
                ) { ids, types in
                    draft.linkedEntityIds = ids
                    draft.linkedEntityTypes = types
                }
                .frame(minHeight: 260)
                .focused($isContentFocused)
                .cornerRadius(14)
            }
            .padding(20)
        }
    }
    
    private var tagsCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(
                    title: "Tags",
                    subtitle: "Organize this entry with lightweight metadata",
                    icon: "number"
                )
                
                if draft.tags.isEmpty {
                    Text("Add tags to surface this entry in reflections and search.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !draft.tags.isEmpty {
                    NoteTagFlowLayout(spacing: 8) {
                        ForEach(draft.tags, id: \.self) { tag in
                            HStack(spacing: 4) {
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
                            .background(Color.kosmicPurple.opacity(0.12))
                            .foregroundColor(.kosmicPurple)
                            .cornerRadius(8)
                        }
                    }
                }
                
                HStack(spacing: 10) {
                    TextField("Add tag", text: $newTagText)
                        .textFieldStyle(.plain)
                        .onSubmit(addTag)
                    
                    Button(action: addTag) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.kosmicPurple)
                    }
                    .buttonStyle(.plain)
                    .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(glassColorSystem.glassTint(for: .surface).opacity(0.45))
                .cornerRadius(10)
            }
            .padding(20)
        }
    }
    
    private var linkedItemsCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Linked Items",
                    subtitle: "Context captured from mentions and associations",
                    icon: "link"
                )
                
                LinkedItemsSection(
                    tasks: linkedTasks,
                    projects: linkedProjects,
                    artifacts: linkedArtifacts
                )
            }
            .padding(20)
        }
    }
    
    private var templateCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Templates",
                    subtitle: "Kick off with guided prompts sourced from Aurora",
                    icon: "sparkles"
                )
                
                HStack(spacing: 12) {
                    templateButton(.morning)
                    templateButton(.evening)
                    templateButton(.freeWrite)
                }
            }
            .padding(20)
        }
    }
    
    private func templateButton(_ template: JournalTemplate) -> some View {
        Button {
            applyTemplate(template)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(template.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(template.content.isEmpty ? "Blank canvas" : template.content)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(glassColorSystem.glassTint(for: .surface).opacity(0.3))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private var insightsSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let journal = existingJournal, let emotionalState {
                    GlassPanel(tier: .contentCard, cornerRadius: 18) {
                        ARTEReflectionCard(
                            journal: journal,
                            emotionalState: emotionalState,
                            snapshot: dailySnapshot
                        )
                        .padding(20)
                    }
                }
                
                GlassPanel(tier: .contentCard, cornerRadius: 18) {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(
                            title: "Emotional Radar",
                            subtitle: "How Aurora perceives your tonal balance",
                            icon: "circle.grid.cross"
                        )
                        MoodRadarChart(
                            calm: calculateMoodValue(for: .calm),
                            creative: calculateMoodValue(for: .creative),
                            chaotic: calculateMoodValue(for: .frustrated),
                            restless: calculateMoodValue(for: .excited)
                        )
                        .frame(height: 200)
                    }
                    .padding(20)
                }
                
                GlassPanel(tier: .contentCard, cornerRadius: 18) {
                    JournalAISummarySection(
                        summary: aiSummary,
                        isGenerating: isGeneratingSummary,
                        isExpanded: $isSummaryExpanded,
                        onRegenerate: generateSummary
                    )
                    .padding(20)
                }
                
                if existingJournal != nil {
                    GlassPanel(tier: .contentCard, cornerRadius: 18) {
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeader(
                                title: "Aurora Assistance",
                                subtitle: "Request coaching or reflective prompts",
                                icon: "sparkles"
                            )
                            
                            Button {
                                showAuroraChat = true
                            } label: {
                                HStack {
                                    Image(systemName: "message.and.waveform")
                                    Text("Ask Aurora for a reflection")
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(
                                    LinearGradient(
                                        colors: [.kosmicBlue, .kosmicPurple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(20)
                    }
                }
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
        }
        .frame(width: 320)
        .background(glassColorSystem.backgroundColor())
    }
    
    // MARK: - Controls
    
    private var typeControl: some View {
        Menu {
            Picker("Entry Type", selection: $draft.entryType) {
                ForEach(JournalEntryType.allCases, id: \.self) { type in
                    Text(type.rawValue.capitalized).tag(type)
                }
            }
            .pickerStyle(.inline)
        } label: {
            metaControlLabel(icon: "doc.richtext", title: draft.entryType.rawValue.capitalized)
        }
        .menuStyle(.borderlessButton)
    }
    
    private var moodControl: some View {
        Menu {
            Picker("Mood", selection: $draft.mood) {
                ForEach(JournalMood.allCases, id: \.self) { mood in
                    Text(mood.rawValue.capitalized).tag(mood)
                }
            }
            .pickerStyle(.inline)
        } label: {
            metaControlLabel(icon: "face.smiling", title: draft.mood.rawValue.capitalized)
        }
        .menuStyle(.borderlessButton)
    }
    
    private var dateControl: some View {
        DatePicker(
            "",
            selection: $draft.entryDate,
            displayedComponents: .date
        )
        .labelsHidden()
        .datePickerStyle(.compact)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(glassColorSystem.glassTint(for: .surface).opacity(0.3))
        .cornerRadius(12)
    }
    
    private func metaControlLabel(icon: String, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(glassColorSystem.glassTint(for: .surface).opacity(0.3))
        .cornerRadius(12)
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
            loadARTEData()
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
        emotionalState = nil
        dailySnapshot = nil
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
    
    private func loadARTEData() {
        guard let journal = existingJournal else { return }
        
        Task { @MainActor in
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: journal.entryDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? journal.entryDate
            
            let snapshot = await AnalyticsEngine.shared.generateSnapshot(
                for: .custom,
                customRange: (startOfDay, endOfDay),
                modelContext: modelContext
            )
            dailySnapshot = snapshot
            
            let detector = EmotionalStateDetector()
            emotionalState = detector.detectState(from: snapshot, modelContext: modelContext)
        }
    }
    
    private func generateSummary() {
        guard !isGeneratingSummary, existingJournal != nil else { return }
        
        isGeneratingSummary = true
        
        Task { @MainActor in
            defer { isGeneratingSummary = false }
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
                
                aiSummary = result.summary
                draft.aiGeneratedContent = result.summary
            } catch {
                aiSummary = "Unable to generate summary: \(error.localizedDescription)"
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
    
    private func calculateMoodValue(for mood: JournalMood) -> Double {
        if draft.mood == mood {
            return 0.85
        }
        
        guard let detection = emotionalState else {
            return 0.35
        }
        
        switch mood {
        case .calm:
            return detection.state == .calm ? 0.7 : 0.3
        case .creative:
            return detection.state == .reflective ? 0.65 : 0.25
        case .frustrated:
            return detection.state == .fatigued ? 0.55 : 0.15
        case .excited:
            return detection.state == .energized ? 0.75 : 0.25
        default:
            return 0.3
        }
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
                    
                    Button(action: onRegenerate) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Regenerate summary")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.kosmicPurple)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: onRegenerate) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text("Generate summary with Aurora")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.kosmicPurple)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.kosmicPurple.opacity(0.12))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
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

