//
//  ArtifactDetailDrawer.swift
//  Cloutmate
//
//  Artifacts V2 - Detail drawer for editing artifacts
//

import SwiftUI
import SwiftData
import CloutmateShared

struct ArtifactDetailDrawer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    let artifact: Artifact
    
    @State private var mode: ComposerMode = .craft
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var linkedContext = LinkedContext()
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // Main Editor
            VStack(spacing: 0) {
                // Toolbar
                ArtifactEditorToolbar(artifact: artifact)
                    .padding()
                    .background(GlassPanel(tier: .overlay, cornerRadius: 0) { EmptyView() })
                
                Divider()
                
                // Mode Toggle
                Picker("Mode", selection: $mode) {
                    Label("Capture", systemImage: "pencil.line").tag(ComposerMode.capture)
                    Label("Craft", systemImage: "sparkles").tag(ComposerMode.craft)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Editor
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if mode == .craft {
                            TextField("Title", text: $title)
                                .font(.headline)
                                .textFieldStyle(.plain)
                        }
                        
                        MentionInputField(
                            text: $content,
                            isFocused: $isFocused,
                            placeholder: mode == .capture ? "Quick capture..." : "Write your artifact...",
                            onSubmit: {},
                            linkedContext: $linkedContext
                        )
                        .frame(minHeight: 400)
                    }
                    .padding()
                }
            }
            .frame(width: 600)
            
            Divider()
            
            // Side Metadata Panel
            VStack(alignment: .leading, spacing: 16) {
                Text("Metadata")
                    .font(.headline)
                    .padding()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Linked Items
                        if !artifact.linkedEntityIds.isEmpty {
                            Section("Linked Items") {
                                ForEach(Array(artifact.linkedEntityIds.enumerated()), id: \.element) { index, entityId in
                                    if index < artifact.linkedEntityTypes.count {
                                        Text("@\(artifact.linkedEntityTypes[index])")
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.kosmicBlue.opacity(0.2))
                                            .cornerRadius(6)
                                    }
                                }
                            }
                        }
                        
                        // Sentiment Summary
                        if let sentiment = artifact.sentimentSummary {
                            Section("Sentiment") {
                                Text(sentiment)
                                    .font(.caption)
                                    .foregroundColor(glassColorSystem.textSecondary())
                            }
                        }
                        
                        // Aurora Notes
                        if let notes = artifact.auroraNotes {
                            Section("Aurora Notes") {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundColor(glassColorSystem.textSecondary())
                            }
                        }
                    }
                    .padding()
                }
            }
            .frame(width: 300)
            .background(glassColorSystem.backgroundColor())
        }
        .frame(width: 900, height: 700)
        .onAppear {
            title = artifact.title
            content = artifact.content
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    saveChanges()
                    dismiss()
                }
            }
        }
    }
    
    private func saveChanges() {
        artifact.title = title
        artifact.content = content
        artifact.updatedAt = Date()
        
        // Update linked entities
        ArtifactMentionService.shared.updateLinkedEntities(for: artifact, modelContext: modelContext)
        
        try? modelContext.save()
    }
}

#Preview {
    ArtifactDetailDrawer(artifact: Artifact(title: "Test", content: "Content"))
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [Artifact.self])
}

