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
        Group {
            if isPresented {
                GeometryReader { geometry in
                    ZStack(alignment: .trailing) {
                        // Backdrop
                        Color.black.opacity(0.2)
                            .ignoresSafeArea()
                            .onTapGesture {
                                saveNote()
                                withAnimation(GlassMotion.Easing.modalOpen) {
                                    isPresented = false
                                }
                            }
                            .transition(.opacity)
                        
                        // Drawer
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
                                HStack {
                                    TextField("Note Title", text: $editingTitle)
                                        .font(.system(.title2, design: .rounded))
                                        .fontWeight(.bold)
                                        .textFieldStyle(.plain)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        saveNote()
                                        withAnimation(GlassMotion.Easing.modalOpen) {
                                            isPresented = false
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .keyboardShortcut(.escape, modifiers: [])
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
                                            
                                            TextEditor(text: $editingContent)
                                                .font(.body)
                                                .frame(minHeight: 200)
                                                .scrollContentBackground(.hidden)
                                                .focused($isContentFocused)
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
                                                FlowLayout(spacing: 8) {
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
                            .frame(width: 400)
                            .background(.ultraThinMaterial)
                            .transition(.move(edge: .trailing))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    }
                }
            }
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
    }
    
    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !editingTags.contains(trimmed) {
            editingTags.append(trimmed)
            newTag = ""
        }
    }
    
    private func saveNote() {
        let isNewNote = note.title.isEmpty && note.markdown.isEmpty && editingTitle.isEmpty && editingContent.isEmpty
        
        note.title = editingTitle.isEmpty ? "Untitled Note" : editingTitle
        note.markdown = editingContent
        note.tags = editingTags
        note.updatedAt = Date()
        try? modelContext.save()
        
        // Haptic feedback
        let generator = NSHapticFeedbackManager.defaultPerformer
        generator.perform(.generic, performanceTime: .default)
        
        // Shimmer effect for new notes (light confetti shimmer)
        if isNewNote {
            // Trigger shimmer animation - can be enhanced with overlay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Shimmer effect will be handled by parent view if needed
            }
        }
        
        // Update Memory Graph
        updateMemoryGraph()
    }
    
    private func generateSummary() {
        guard !isGeneratingSummary else { return }
        
        isGeneratingSummary = true
        
        Task {
            do {
                let ollamaService = OllamaBridgeService.shared
                
                // Create document descriptor
                let descriptor = DocumentDescriptor(
                    text: note.markdown,
                    preview: String(note.markdown.prefix(200)),
                    fileName: note.title.isEmpty ? "Untitled Note" : note.title,
                    mimeType: "text/markdown",
                    sizeInBytes: note.markdown.utf8.count,
                    pageCount: nil,
                    sourceURL: nil
                )
                
                // Build app context
                let appContext = buildAppContext()
                
                // Analyze document
                let result = try await ollamaService.analyzeDocument(
                    descriptor: descriptor,
                    userPrompt: "Provide a concise summary with key points and emotional tone.",
                    appContext: appContext
                )
                
                await MainActor.run {
                    aiSummary = result.summary
                    // Extract emotional tone from summary (simplified)
                    emotionalTone = extractEmotionalTone(from: result.summary)
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
        var context = "Note: \(note.title)\n"
        context += "Tags: \(note.tags.joined(separator: ", "))\n"
        if let projectId = note.projectId {
            context += "Linked to project: \(projectId.uuidString)\n"
        }
        return context
    }
    
    private func extractEmotionalTone(from summary: String) -> String? {
        let lowercased = summary.lowercased()
        if lowercased.contains("excited") || lowercased.contains("energetic") {
            return "Energetic"
        } else if lowercased.contains("calm") || lowercased.contains("peaceful") {
            return "Calm"
        } else if lowercased.contains("reflective") || lowercased.contains("thoughtful") {
            return "Reflective"
        } else if lowercased.contains("focused") || lowercased.contains("concentrated") {
            return "Focused"
        }
        return nil
    }
    
    private func loadLinkedItems() {
        // Load linked tasks, projects, and artifacts based on note's relationships
        // This is a simplified version - can be enhanced with actual relationship queries
    }
    
    private func updateMemoryGraph() {
        // Update Memory Graph on note save
        Task { @MainActor in
            // Register note update with Recall Service (which auto-creates Memory Graph node)
            AIRecallService.shared.registerUpdated(note, modelContext: modelContext)
            
            // Link to related concepts/themes via tags
            if !note.tags.isEmpty && AIConfigService.shared.config.featureFlags.memoryGraphEnabled {
                do {
                    // Find or create node for this note
                    let node = try await MemoryGraphService.shared.findOrCreateNode(
                        for: note,
                        modelContext: modelContext
                    )
                    
                    // Update node tags
                    node.tags = note.tags
                    try? modelContext.save()
                    
                    // TODO: Create edges to concept nodes based on tags
                    // This can be enhanced later to link notes with same tags
                } catch {
                    // Silently fail if Memory Graph is disabled or unavailable
                }
            }
        }
    }
}

// MARK: - AI Summary Section

struct AISummarySection: View {
    let summary: String?
    let isGenerating: Bool
    @Binding var isExpanded: Bool
    let emotionalTone: String?
    let onRegenerate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(GlassMotion.Easing.spring) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.kosmicPurple)
                    Text("AI Summary")
                        .font(.headline)
                    if let tone = emotionalTone {
                        Text("• \(tone)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
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
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                } else if let summary = summary {
                    Text(summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                } else {
                    Button(action: onRegenerate) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Generate Summary")
                        }
                        .font(.caption)
                        .foregroundColor(.kosmicPurple)
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
            VStack(alignment: .leading, spacing: 8) {
                Text("Linked Items")
                    .font(.headline)
                
                if !tasks.isEmpty {
                    ForEach(tasks) { task in
                        LinkedItemRow(icon: "checkmark.circle.fill", title: task.title, color: .kosmicGreen)
                    }
                }
                
                if !projects.isEmpty {
                    ForEach(projects) { project in
                        LinkedItemRow(icon: "folder.fill", title: project.title, color: .kosmicBlue)
                    }
                }
                
                if !artifacts.isEmpty {
                    ForEach(artifacts) { artifact in
                        LinkedItemRow(icon: "doc.text.fill", title: artifact.title.isEmpty ? "Untitled Artifact" : artifact.title, color: .kosmicPurple)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
    }
}

struct LinkedItemRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.width ?? .infinity,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

#Preview {
    @Previewable @State var isPresented = true
    
    NoteDetailDrawer(
        note: Note(title: "Sample Note", markdown: "This is a sample note with some content."),
        isPresented: $isPresented
    )
    .environmentObject(GlassColorSystem())
    .modelContainer(for: [Note.self])
}

