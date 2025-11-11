//
//  ResourceDetailDrawer.swift
//  Cloutmate
//
//  Resources V2 - Detail Drawer
//

import SwiftUI
import SwiftData
import AppKit
import CloutmateShared

struct ResourceDetailDrawer: View {
    @Bindable var note: Note
    @Binding var isPresented: Bool
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var allProjects: [Project]
    @Query private var allNotes: [Note]
    
    @State private var editableTitle: String = ""
    @State private var aiSummary: String = ""
    @State private var isLoadingSummary = false
    @State private var relatedResources: [Note] = []
    @State private var linkedProjects: [Project] = []
    @State private var auroraRecommendation: String?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                // Backdrop
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        saveChanges()
                        closeDrawer()
                    }
                    .transition(.opacity)
                
                // Drawer
                HStack(spacing: 0) {
                    // Main Content
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Resource Title", text: $editableTitle)
                                    .font(.system(.title3, design: .rounded))
                                    .fontWeight(.semibold)
                                    .textFieldStyle(.plain)
                                
                                HStack(spacing: 8) {
                                    TypeBadge(type: note.type.rawValue)
                                    
                                    Text(note.createdAt, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                saveChanges()
                                closeDrawer()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(20)
                        .background(.ultraThinMaterial)
                        
                        // Body
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                // File Preview
                                ResourcePreviewSection(note: note)
                                    .padding(.horizontal, 24)
                                    .padding(.top, 20)
                                
                                // AI Summary
                                if isLoadingSummary {
                                    HStack {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Generating summary...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 24)
                                } else if !aiSummary.isEmpty {
                                    SimpleAISummarySection(summary: aiSummary)
                                        .padding(.horizontal, 24)
                                }
                                
                                // Tags Editor
                                TagsEditorSection(note: note)
                                    .padding(.horizontal, 24)
                                
                                // Related Items
                                if !linkedProjects.isEmpty {
                                    LinkedProjectsSection(projects: linkedProjects)
                                        .padding(.horizontal, 24)
                                }
                            }
                            .padding(.vertical, 20)
                        }
                        
                        // Footer Actions
                        HStack(spacing: 12) {
                            if let source = note.source, !source.isEmpty, source.hasPrefix("http") {
                                Button(action: {
                                    if let url = URL(string: source) {
                                        NSWorkspace.shared.open(url)
                                    }
                                }) {
                                    Label("Open in Browser", systemImage: "safari")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                saveChanges()
                                closeDrawer()
                            }) {
                                Text("Done")
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.medium)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(20)
                        .background(.ultraThinMaterial)
                    }
                    .frame(width: 350)
                    .background(.ultraThinMaterial)
                    
                    // Sidebar
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Related")
                            .font(.system(.headline, design: .rounded))
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                // Related Resources
                                if !relatedResources.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Resources")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 16)
                                        
                                        ForEach(relatedResources.prefix(5)) { resource in
                                            RelatedResourceRow(resource: resource)
                                                .padding(.horizontal, 16)
                                        }
                                    }
                                }
                                
                                // Aurora Recommendation
                                if let recommendation = auroraRecommendation {
                                    AuroraRecommendationPanel(recommendation: recommendation)
                                        .padding(.horizontal, 16)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .frame(width: 100)
                    .background(glassColorSystem.cardColor())
                }
                .frame(width: 450)
                .frame(maxHeight: .infinity, alignment: .trailing)
            }
        }
        .onAppear {
            editableTitle = note.title
            loadRelatedItems()
            generateAISummary()
        }
        .onChange(of: editableTitle) { _, newValue in
            note.title = newValue
        }
    }
    
    private func closeDrawer() {
        let generator = NSHapticFeedbackManager.defaultPerformer
        generator.perform(.generic, performanceTime: .default)
        
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isPresented = false
        }
    }
    
    private func saveChanges() {
        note.updatedAt = Date()
        try? modelContext.save()
    }
    
    private func loadRelatedItems() {
        // Find linked projects
        if let projectId = note.projectId {
            linkedProjects = allProjects.filter { $0.id == projectId }
        }
        
        // Find related resources by tags
        relatedResources = allNotes.filter { relatedNote in
            relatedNote.id != note.id &&
            !Set(relatedNote.tags).isDisjoint(with: Set(note.tags))
        }
        .prefix(5)
        .map { $0 }
    }
    
    private func generateAISummary() {
        guard aiSummary.isEmpty else { return }
        
        isLoadingSummary = true
        
        // TODO: Integrate with Aurora for AI summary generation
        // For now, use a simple placeholder
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            aiSummary = "This resource contains information about \(note.type.rawValue.lowercased()). " +
                       "It includes \(note.tags.joined(separator: ", ")) tags and was created on \(note.createdAt.formatted(date: .abbreviated, time: .omitted))."
            isLoadingSummary = false
        }
    }
}

// MARK: - Supporting Views

struct ResourcePreviewSection: View {
    let note: Note
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.primary)
            
            if !note.markdown.isEmpty {
                ScrollView {
                    MentionRenderedTextView(
                        text: note.markdown,
                        textFont: .system(.body, design: .rounded),
                        mentionFont: .system(.body, design: .rounded)
                    )
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                }
                .frame(height: 200)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(glassColorSystem.cardColor())
                )
            } else {
                Text("No content preview available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(glassColorSystem.cardColor())
                    )
            }
        }
    }
}

struct SimpleAISummarySection: View {
    let summary: String
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundColor(.kosmicPurple)
                Text("AI Summary")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            Text(summary)
                .font(.system(.body, design: .rounded))
                .foregroundColor(.secondary)
                .lineSpacing(4)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(glassColorSystem.cardColor())
                )
        }
    }
}

struct TagsEditorSection: View {
    @Bindable var note: Note
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @State private var newTag: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.primary)
            
            // Existing Tags
            if !note.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                    ForEach(note.tags, id: \.self) { tag in
                        HStack(spacing: 6) {
                            Text(tag)
                                .font(.caption)
                            Button(action: {
                                note.tags.removeAll { $0 == tag }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.kosmicPurple.opacity(0.15))
                        )
                        .foregroundColor(.kosmicPurple)
                    }
                }
                .padding(.top, 4)
                }
            }
            
            // Add Tag
            HStack {
                TextField("Add tag", text: $newTag)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .onSubmit {
                        addTag()
                    }
                
                Button(action: addTag) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.kosmicBlue)
                }
                .buttonStyle(.plain)
                .disabled(newTag.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(glassColorSystem.cardColor())
            )
            .padding(.top, 4)
        }
    }
    
    private func addTag() {
        guard !newTag.isEmpty, !note.tags.contains(newTag) else { return }
        note.tags.append(newTag)
        newTag = ""
    }
}

struct LinkedProjectsSection: View {
    let projects: [Project]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Linked Projects")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.primary)
            
            ForEach(projects) { project in
                HStack {
                    Image(systemName: "folder.fill")
                        .font(.caption)
                        .foregroundColor(.kosmicBlue)
                    Text(project.title)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.kosmicBlue.opacity(0.1))
                )
            }
        }
    }
}

struct RelatedResourceRow: View {
    let resource: Note
    
    var body: some View {
        Button(action: {}) {
            VStack(alignment: .leading, spacing: 4) {
                Text(resource.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(resource.type.rawValue)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }
}

struct AuroraRecommendationPanel: View {
    let recommendation: String
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundColor(.kosmicPurple)
                Text("Aurora Suggests")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.kosmicPurple)
            }
            
            Text(recommendation)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.kosmicPurple.opacity(0.1))
                )
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Note.self, configurations: config)
    let note = Note(title: "Sample Resource", markdown: "This is a sample resource", type: .article)
    note.tags = ["Study", "Design"]
    
    return ResourceDetailDrawer(note: note, isPresented: .constant(true))
        .environmentObject(GlassColorSystem())
        .modelContainer(container)
}

