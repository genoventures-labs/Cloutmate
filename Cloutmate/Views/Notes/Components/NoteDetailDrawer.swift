//
//  NoteDetailDrawer.swift
//  Cloutmate
//
//  Note detail drawer with AI summary and Focus Gravity sidebar
//

import SwiftUI
import SwiftData
import CloutmateShared
import AppKit

struct NoteDetailDrawer: View {
    @Bindable var note: Note
    @Binding var isPresented: Bool
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @State private var editingTitle: String = ""
    @State private var editingContent: String = ""
    @State private var editingTags: [String] = []
    @State private var newTag: String = ""
    
    @State private var aiSummary: String?
    @State private var isGeneratingSummary = false
    @State private var isSummaryExpanded = true
    @State private var emotionalTone: String?
    
    @State private var linkedTasks: [Task] = []
    @State private var linkedProjects: [Project] = []
    @State private var linkedArtifacts: [Artifact] = []
    
    @FocusState private var isContentFocused: Bool
    
    private var focusGravityIntensity: Double {
        // Calculate engagement weight based on update frequency and age
        let daysSinceUpdate = Calendar.current.dateComponents([.day], from: note.updatedAt, to: Date()).day ?? 0
        let daysSinceCreation = Calendar.current.dateComponents([.day], from: note.createdAt, to: Date()).day ?? 1
        
        // More recent updates = higher intensity
        let recencyScore = max(0, 1.0 - (Double(daysSinceUpdate) / 30.0))
        
        // More frequent updates = higher intensity
        let updateFrequency = Double(daysSinceCreation) > 0 ? Double(note.markdown.count) / Double(daysSinceCreation) : 0.0
        let frequencyScore = min(1.0, updateFrequency / 100.0)
        
        return (recencyScore + frequencyScore) / 2.0
    }
    
    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.kosmicBlue.opacity(0.45 + 0.4 * focusGravityIntensity),
                Color.kosmicPurple.opacity(0.35 + 0.3 * focusGravityIntensity)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    var body: some View {
        V2DrawerScaffold(
            accentGradient: accentGradient,
            showsSidebar: false,
            header: { headerContent },
            content: {
                contentSection
                tagsSection
                aiSummarySection
                if hasLinkedItems {
                    linkedItemsSection
                }
                auroraSection
            },
            sidebar: { EmptyView() }
        )
        .frame(minWidth: 700, minHeight: 560)
        .frame(idealWidth: 860, idealHeight: 640)
        .background(glassColorSystem.backgroundColor())
        .onEscape {
            saveNote()
            isPresented = false
        }
        .onAppear {
            editingTitle = note.title
            editingContent = note.markdown
            editingTags = note.tags
            loadLinkedItems()
        }
        .onChange(of: editingTitle) { _, newValue in
            note.title = newValue
            note.updatedAt = Date()
        }
        .onChange(of: editingContent) { _, newValue in
            note.markdown = newValue
            note.updatedAt = Date()
        }
        .onChange(of: editingTags) { _, newValue in
            note.tags = newValue
            note.updatedAt = Date()
        }
        .task {
            // Auto-focus content field on open
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isContentFocused = true
            }
        }
        .onDisappear {
            // Delete empty notes when sheet closes
            if note.title.isEmpty && note.markdown.isEmpty && note.tags.isEmpty {
                modelContext.delete(note)
                try? modelContext.save()
            }
        }
    }
    
    private var headerContent: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    TextField("Note Title", text: $editingTitle)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .textFieldStyle(.plain)
                        .foregroundStyle(glassColorSystem.textPrimary())
                        .disableAutocorrection(true)
                        .drawerFocusGlow()
                    
                    if note.author == .aurora {
                        AuroraAuthorBadge()
                    }
                }
                
                HStack(spacing: 14) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 12, weight: .medium))
                        Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(glassColorSystem.textSecondary())
                    
                    if !note.tags.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "tag.fill")
                                .font(.system(size: 12, weight: .medium))
                            Text("\(note.tags.count) tag\(note.tags.count == 1 ? "" : "s")")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(glassColorSystem.textSecondary())
                    }
                    
                    if let projectId = note.projectId,
                       let project = linkedProjects.first(where: { $0.id == projectId }) {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 12, weight: .medium))
                            Text(project.title)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(glassColorSystem.textSecondary())
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                GlassButton(
                    "Done",
                    icon: "checkmark",
                    style: .pill,
                    role: .primary
                ) {
                    saveNote()
                    isPresented = false
                }
                
                GlassButton(
                    nil,
                    icon: "xmark",
                    style: .iconOnly,
                    role: .surface,
                    tintColor: glassColorSystem.backgroundElevated()
                ) {
                    saveNote()
                    isPresented = false
                }
                .accessibilityLabel("Close")
            }
        }
    }
    
    private var contentSection: some View {
        DrawerSection(title: "Content", icon: "doc.richtext") {
            VStack(alignment: .leading, spacing: 8) {
                MentionTextEditor(
                    text: $editingContent,
                    placeholder: "Write your note...",
                    excludeObjectId: note.id,
                    excludeObjectType: .note
                ) { ids, _ in
                    note.backlinks = ids
                }
                .focused($isContentFocused)
                .frame(minHeight: 220)
                .drawerFocusGlow()
            }
        }
    }
    
    private var tagsSection: some View {
        DrawerSection(title: "Tags", icon: "tag.fill") {
            VStack(alignment: .leading, spacing: 12) {
                if !editingTags.isEmpty {
                    NoteTagFlowLayout(spacing: 8) {
                        ForEach(editingTags, id: \.self) { tag in
                            HStack(spacing: 6) {
                                Text("#\(tag)")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        editingTags.removeAll { $0 == tag }
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.kosmicPurple.opacity(0.18))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.kosmicPurple.opacity(0.32), lineWidth: 1)
                                    )
                            )
                            .foregroundColor(.kosmicPurple)
                        }
                    }
                } else {
                    Text("Add tags to organize and surface this note in other contexts.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                }
                
                HStack(spacing: 10) {
                    TextField("Add tag", text: $newTag)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                        .onSubmit(addTag)
                    
                    GlassButton(
                        nil,
                        icon: "plus",
                        style: .iconOnly,
                        role: .accent
                    ) {
                        addTag()
                    }
                    .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(glassColorSystem.backgroundElevated().opacity(0.28))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(glassColorSystem.borderColor().opacity(0.35), lineWidth: 0.9)
                        )
                )
                .drawerFocusGlow()
            }
        }
    }
    
    private var aiSummarySection: some View {
        DrawerSection(title: "Aurora Summary", icon: "sparkles") {
            AISummarySection(
                summary: aiSummary,
                isGenerating: isGeneratingSummary,
                isExpanded: $isSummaryExpanded,
                emotionalTone: emotionalTone,
                onRegenerate: generateSummary
            )
        }
    }
    
    private var hasLinkedItems: Bool {
        !linkedTasks.isEmpty || !linkedProjects.isEmpty || !linkedArtifacts.isEmpty
    }
    
    private var linkedItemsSection: some View {
        DrawerSection(title: "Linked Items", icon: "link") {
            LinkedItemsSection(
                tasks: linkedTasks,
                projects: linkedProjects,
                artifacts: linkedArtifacts
            )
        }
    }
    
    private var auroraSection: some View {
        DrawerSection(title: "Aurora Tools", icon: "wand.and.stars") {
            GlassButton(
                "Ask Aurora",
                icon: "sparkles",
                style: .pill,
                role: .accent
            ) {
                // TODO: Open Aurora chat overlay contextual to this note
            }
        }
    }
    
    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !editingTags.contains(trimmed) else { return }
        editingTags.append(trimmed)
        newTag = ""
    }
    
    private func saveNote() {
        note.title = editingTitle
        note.markdown = editingContent
        note.tags = editingTags
        note.updatedAt = Date()
        
        // Provide haptic feedback
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        
        try? modelContext.save()
    }
    
    private func generateSummary() {
        guard !note.markdown.isEmpty else { return }
        isGeneratingSummary = true
        
        _Concurrency.Task {
            do {
                let descriptor = DocumentDescriptor(
                    text: note.markdown,
                    preview: String(note.markdown.prefix(500)),
                    fileName: note.title.isEmpty ? "Untitled" : note.title,
                    mimeType: "text/plain",
                    sizeInBytes: note.markdown.utf8.count,
                    pageCount: nil,
                    sourceURL: nil
                )
                
                let result = try await OllamaBridgeService.shared.analyzeDocument(
                    descriptor: descriptor,
                    userPrompt: "Summarize this note and extract key emotional themes",
                    appContext: "note_summary"
                )
                await MainActor.run {
                    aiSummary = result.summary
                    emotionalTone = extractEmotionalTone(from: result.summary)
                    note.author = .aurora // Mark as Aurora-authored when AI generates content
                    isGeneratingSummary = false
                }
            } catch {
                await MainActor.run {
                    aiSummary = "Failed to generate summary: \(error.localizedDescription)"
                    isGeneratingSummary = false
                }
            }
        }
    }
    
    private func extractEmotionalTone(from summary: String) -> String {
        // Simple keyword extraction for emotional tone
        let keywords = ["excited", "calm", "focused", "creative", "analytical", "reflective"]
        for keyword in keywords {
            if summary.localizedCaseInsensitiveContains(keyword) {
                return keyword.capitalized
            }
        }
        return "Neutral"
    }
    
    private func loadLinkedItems() {
        // Load linked tasks
        if let projectId = note.projectId {
            let taskDescriptor = FetchDescriptor<Task>(
                predicate: #Predicate { $0.projectId == projectId }
            )
            linkedTasks = (try? modelContext.fetch(taskDescriptor)) ?? []
            
            let projectDescriptor = FetchDescriptor<Project>(
                predicate: #Predicate { $0.id == projectId }
            )
            linkedProjects = (try? modelContext.fetch(projectDescriptor)) ?? []
        }
        
        // Load artifacts (if any are referenced in markdown - simple string matching)
        // This is a placeholder; actual implementation would parse markdown for artifact IDs
    }
}

// MARK: - AI Summary Section

struct AISummarySection: View {
    let summary: String?
    let isGenerating: Bool
    @Binding var isExpanded: Bool
    let emotionalTone: String?
    let onRegenerate: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            Button(action: { 
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.kosmicBlue, .kosmicPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        Text("AI Summary")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(glassColorSystem.textPrimary())
                    }
                    
                    Spacer()
                    
                    if let tone = emotionalTone {
                        Text(tone)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.kosmicPurple.opacity(0.18))
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(Color.kosmicPurple.opacity(0.32), lineWidth: 1)
                                    )
                            )
                            .foregroundColor(.kosmicPurple)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(glassColorSystem.textSecondary())
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                if isGenerating {
                    HStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Generating summary...")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(glassColorSystem.textSecondary())
                    }
                    .padding(.vertical, 8)
                } else if let summary = summary {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(summary)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(glassColorSystem.textPrimary())
                            .lineSpacing(4)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(glassColorSystem.backgroundElevated().opacity(0.32))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(glassColorSystem.borderColor().opacity(0.35), lineWidth: 0.9)
                                    )
                            )
                        
                        GlassButton(
                            "Regenerate",
                            icon: "arrow.clockwise",
                            style: .pill,
                            role: .surface,
                            tintColor: glassColorSystem.backgroundElevated()
                        ) {
                            onRegenerate()
                        }
                    }
                } else {
                    GlassButton(
                        "Generate AI Summary",
                        icon: "sparkles",
                        style: .pill,
                        role: .accent
                    ) {
                        onRegenerate()
                    }
                }
            }
        }
    }
}

// MARK: - Linked Items Section

struct LinkedItemsSection: View {
    let tasks: [Task]
    let projects: [Project]
    let artifacts: [Artifact]
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        if !tasks.isEmpty || !projects.isEmpty || !artifacts.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                if !tasks.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.kosmicBlue)
                            Text("Tasks")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(glassColorSystem.textSecondary())
                        }
                        
                        ForEach(tasks) { task in
                            HStack(spacing: 10) {
                                Image(systemName: "circle")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.kosmicBlue.opacity(0.6))
                                Text(task.title)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(glassColorSystem.textPrimary())
                            }
                            .padding(.leading, 4)
                        }
                    }
                }
                
                if !projects.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.kosmicPurple)
                            Text("Projects")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(glassColorSystem.textSecondary())
                        }
                        
                        ForEach(projects) { project in
                            HStack(spacing: 10) {
                                Image(systemName: "folder")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.kosmicPurple.opacity(0.6))
                                Text(project.title)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(glassColorSystem.textPrimary())
                            }
                            .padding(.leading, 4)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Note Tag Flow Layout

struct NoteTagFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        
        for size in sizes {
            if lineWidth + size.width > (proposal.width ?? 0) {
                totalHeight += lineHeight + spacing
                lineWidth = size.width + spacing
                lineHeight = size.height
            } else {
                lineWidth += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            totalWidth = max(totalWidth, lineWidth)
        }
        
        totalHeight += lineHeight
        return CGSize(width: totalWidth, height: totalHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var lineX = bounds.minX
        var lineY = bounds.minY
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if lineX + size.width > bounds.maxX && lineX > bounds.minX {
                lineY += lineHeight + spacing
                lineHeight = 0
                lineX = bounds.minX
            }
            
            subview.place(at: CGPoint(x: lineX, y: lineY), proposal: .unspecified)
            
            lineHeight = max(lineHeight, size.height)
            lineX += size.width + spacing
        }
    }
}

#Preview {
    NoteDetailDrawer(
        note: Note(title: "Sample Note", markdown: "This is a sample note"),
        isPresented: .constant(true)
    )
    .environmentObject(GlassColorSystem())
    .frame(width: 700, height: 600)
}
