//
//  ArtifactQuickAddSheet.swift
//  Cloutmate
//
//  Artifacts V2 - Quick add modal for artifact creation
//

import SwiftUI
import SwiftData
import CloutmateShared

struct ArtifactQuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @State private var title = ""
    @State private var content = ""
    @State private var selectedFormat: OutputFormat = .brief
    @State private var linkedContext = LinkedContext()
    @FocusState private var isFocused: Bool
    @State private var showMorphIn = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Artifact")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(glassColorSystem.textPrimary())
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(glassColorSystem.textSecondary())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(GlassPanel(tier: .overlay, cornerRadius: 0) { EmptyView() })
            
            Divider()
            
            // Format Selector
            VStack(spacing: 0) {
                Picker("Format", selection: $selectedFormat) {
                    ForEach(OutputFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(glassColorSystem.backgroundColor())
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.caption)
                            .foregroundColor(glassColorSystem.textSecondary())
                            .textCase(.uppercase)
                        
                        TextField("Enter title...", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16, weight: .medium))
                            .padding(12)
                            .background(
                                GlassPanel(tier: .contentCard, cornerRadius: 8) {
                                    EmptyView()
                                }
                            )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Content Editor
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content")
                            .font(.caption)
                            .foregroundColor(glassColorSystem.textSecondary())
                            .textCase(.uppercase)
                        
                        TextEditor(text: $content)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 300)
                            .padding(12)
                            .background(
                                GlassPanel(tier: .contentCard, cornerRadius: 8) {
                                    EmptyView()
                                }
                            )
                            .focused($isFocused)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            
            Divider()
            
            // Actions
            HStack {
                Spacer()
                Button("Create") {
                    createArtifact()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(title.isEmpty && content.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(glassColorSystem.backgroundColor())
        }
        .frame(width: 700, height: 600)
        .background(glassColorSystem.backgroundColor())
        .scaleEffect(showMorphIn ? 1.0 : 0.96)
        .opacity(showMorphIn ? 1.0 : 0.0)
        .onAppear {
            withAnimation(GlassMotion.Easing.modalOpen) {
                showMorphIn = true
            }
            // Auto-focus content field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
    }
    
    private func createArtifact() {
        let artifact = Artifact(
            title: title.isEmpty ? content.prefix(50).description : title,
            content: content.isEmpty ? title : content,
            outputFormat: selectedFormat,
            state: .draft
        )
        
        // Capture ARTE tone snapshot
        artifact.arteToneSnapshot = ReactiveThemeManager.shared.currentState.rawValue
        
        // Capture forecast snapshot
        ArtifactPredictiveBridge.shared.captureForecastSnapshot(for: artifact, modelContext: modelContext)
        
        // Update linked entities from mentions
        ArtifactMentionService.shared.updateLinkedEntities(for: artifact, modelContext: modelContext)
        ArtifactMentionService.shared.boostCPSForMentions(in: artifact, modelContext: modelContext)
        
        modelContext.insert(artifact)
        try? modelContext.save()
        
        dismiss()
    }
}

#Preview {
    ArtifactQuickAddSheet()
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [Artifact.self])
}

