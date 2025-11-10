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
    
    var body: some View {
        NavigationStack {
        HStack(spacing: 0) {
            // Focus Gravity Sidebar
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .kosmicBlue.opacity(focusGravityIntensity),
                            .kosmicPurple.opacity(focusGravityIntensity * 0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4)
            
            // Main content
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    TextField("Note Title", text: $editingTitle)
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                        .textFieldStyle(.plain)
                    
                    if note.author == .aurora {
                        AuroraAuthorBadge()
                    }
                    
                    Spacer()
                }
                .padding()
                .background(.ultraThinMaterial)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Body editor
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Content")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                                MentionTextEditor(
                                    text: $editingContent,
                                    placeholder: "Write your note..."
                                ) { ids, types in
                                    // Update note's backlinks when mentions change
                                    note.backlinks = ids
                                }
                                .frame(minHeight: 200)
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                        }
                        
                        // Tags editor
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tags")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // Tag chips
                            if !editingTags.isEmpty {
                                NoteTagFlowLayout(spacing: 8) {
                                    ForEach(editingTags, id: \.self) { tag in
                                        HStack(spacing: 4) {
                                            Text("#\(tag)")
                                                .font(.caption)
                                            Button(action: {
                                                editingTags.removeAll { $0 == tag }
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.caption2)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.kosmicPurple.opacity(0.1))
                                        .foregroundColor(.kosmicPurple)
                                        .cornerRadius(6)
                                    }
                                }
                            }
                            
                            // Add tag field
                            HStack {
                                TextField("Add tag", text: $newTag)
                                    .textFieldStyle(.plain)
                                    .onSubmit {
                                        addTag()
                                    }
                                
                                Button(action: addTag) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.kosmicPurple)
                                }
                                .buttonStyle(.plain)
                                .disabled(newTag.isEmpty)
                            }
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                        }
                        
                        // AI Summary Section
                        AISummarySection(
                            summary: aiSummary,
                            isGenerating: isGeneratingSummary,
                            isExpanded: $isSummaryExpanded,
                            emotionalTone: emotionalTone,
                            onRegenerate: generateSummary
                        )
                        
                        // Linked Items
                        LinkedItemsSection(
                            tasks: linkedTasks,
                            projects: linkedProjects,
                            artifacts: linkedArtifacts
                        )
                        
                        // Ask Aurora button
                        Button(action: {
                            // TODO: Open Aurora chat overlay contextual to this note
                        }) {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Ask Aurora")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [.kosmicBlue, .kosmicPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                }
            }
        }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(glassColorSystem.backgroundColor())
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        saveNote()
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .frame(idealWidth: 800, idealHeight: 600)
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
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.kosmicBlue, .kosmicPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        Text("AI Summary")
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    if let tone = emotionalTone {
                        Text(tone)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.kosmicPurple.opacity(0.1))
                            .foregroundColor(.kosmicPurple)
                            .cornerRadius(6)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                if isGenerating {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Generating summary...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else if let summary = summary {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(summary)
                            .font(.body)
                            .foregroundColor(.primary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                        
                        Button(action: onRegenerate) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Regenerate")
                            }
                            .font(.caption)
                            .foregroundColor(.kosmicPurple)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Button(action: onRegenerate) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Generate AI Summary")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.kosmicPurple.opacity(0.1))
                        .foregroundColor(.kosmicPurple)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

// MARK: - Linked Items Section

struct LinkedItemsSection: View {
    let tasks: [Task]
    let projects: [Project]
    let artifacts: [Artifact]
    
    var body: some View {
        if !tasks.isEmpty || !projects.isEmpty || !artifacts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Linked Items")
                    .font(.headline)
                
                if !tasks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tasks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ForEach(tasks) { task in
                            HStack {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(.kosmicBlue)
                                Text(task.title)
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                if !projects.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Projects")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ForEach(projects) { project in
                            HStack {
                                Image(systemName: "folder")
                                    .foregroundColor(.kosmicPurple)
                                Text(project.title)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
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
