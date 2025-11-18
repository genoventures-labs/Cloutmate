//
//  ArtifactPreviewSheet.swift
//  FocusOS
//
//  Preview sheet for Artifact details
//

import SwiftUI
import SwiftData
import FocusOSShared

struct ArtifactPreviewSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Binding var artifact: FocusOSShared.Artifact?
    @State private var showingComposer = false
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        if let artifact = artifact {
            artifactContent(artifact)
        }
    }
    
    private func artifactContent(_ artifact: FocusOSShared.Artifact) -> some View {
        NavigationStack {
            Form {
                titleSection(artifact)
                contentSection(artifact)
                formatSection(artifact)
                stateSection(artifact)
                publishedSection(artifact)
                mediaSection(artifact)
                tagsSection(artifact)
            }
            .formStyle(.grouped)
            .navigationTitle("Artifact Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Edit") {
                        showingComposer = true
                    }
                }
                
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .sheet(isPresented: $showingComposer) {
                ArtifactComposerView(existingArtifact: artifact)
            }
            .alert("Delete Artifact?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteArtifact()
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }
    
    private func titleSection(_ artifact: FocusOSShared.Artifact) -> some View {
        Section("Title") {
            Text(artifact.title.isEmpty ? "Untitled" : artifact.title)
                .textSelection(.enabled)
        }
    }
    
    private func contentSection(_ artifact: FocusOSShared.Artifact) -> some View {
        Section("Content") {
            Text(artifact.content)
                .textSelection(.enabled)
            
            Text("\(artifact.content.count) characters")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func formatSection(_ artifact: FocusOSShared.Artifact) -> some View {
        Section("Output Format") {
            HStack {
                Image(systemName: formatIcon(for: artifact.format))
                    .font(.title3)
                    .foregroundColor(formatColor(for: artifact.format))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(artifact.format.displayName)
                        .font(.body)
                    Text(artifact.format.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func stateSection(_ artifact: FocusOSShared.Artifact) -> some View {
        Section("State") {
            ArtifactStateBadge(state: artifact.artifactState)
        }
    }
    
    @ViewBuilder
    private func publishedSection(_ artifact: FocusOSShared.Artifact) -> some View {
        if let publishedAt = artifact.publishedAt {
            Section("Published") {
                Text(publishedAt, style: .date)
                
                Text(publishedAt, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func mediaSection(_ artifact: FocusOSShared.Artifact) -> some View {
        if !artifact.mediaURLs.isEmpty {
            Section("Media Attachments") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(artifact.mediaURLs, id: \.self) { urlString in
                            MediaPreviewView(url: URL(fileURLWithPath: urlString), onRemove: {})
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    @ViewBuilder
    private func tagsSection(_ artifact: FocusOSShared.Artifact) -> some View {
        if !artifact.tags.isEmpty {
            Section("Tags") {
                HStack {
                    ForEach(artifact.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundColor(.accentColor)
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    private func formatIcon(for format: OutputFormat) -> String {
        switch format {
        case .brief: return "doc.text"
        case .summary: return "doc.text.below.ecg"
        case .reflection: return "brain.head.profile"
        case .report: return "doc.text.magnifyingglass"
        case .releaseNote: return "megaphone"
        case .lessonLearned: return "lightbulb"
        }
    }
    
    private func formatColor(for format: OutputFormat) -> Color {
        switch format {
        case .brief: return .kosmicCyan
        case .summary: return .kosmicBlue
        case .reflection: return .kosmicPurple
        case .report: return .kosmicPurple
        case .releaseNote: return .kosmicGreen
        case .lessonLearned: return .orange
        }
    }
    
    private func deleteArtifact() {
        if let artifact = artifact {
            modelContext.delete(artifact)
            dismiss()
        }
    }
}

#Preview {
    ArtifactPreviewSheet(artifact: .constant(FocusOSShared.Artifact(title: "Test Artifact", content: "Test content", outputFormat: .brief)))
        .modelContainer(for: [FocusOSShared.Artifact.self])
}

