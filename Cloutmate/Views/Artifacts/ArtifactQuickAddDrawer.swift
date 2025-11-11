//
//  ArtifactQuickAddDrawer.swift
//  Cloutmate
//
//  Artifacts V2 - Quick add modal for artifact creation
//

import SwiftUI
import SwiftData
import CloutmateShared

struct ArtifactQuickAddDrawer: View {
    @Binding var isPresented: Bool
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var title = ""
    @State private var content = ""
    @State private var selectedFormat: OutputFormat = .brief
    @State private var linkedContext = LinkedContext()
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
        VStack(spacing: 0) {
                    header
                    
                    Divider()
                    
                    formatSelector
                    
                    Divider()
                    
                    ScrollView {
                        formContent
                    }
                    
                    Divider()
                    
                    footer
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(glassColorSystem.backgroundColor())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(glassColorSystem.backgroundColor())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        closeDrawer()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                }
            }
                }
        .frame(minWidth: 640, minHeight: 520)
        .frame(idealWidth: 780, idealHeight: 560)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
    }
    
    private var header: some View {
        HStack {
            Text("New Artifact")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(glassColorSystem.textPrimary())
            Spacer()
            }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
            .background(GlassPanel(tier: .overlay, cornerRadius: 0) { EmptyView() })
    }
            
    private var formatSelector: some View {
                Picker("Format", selection: $selectedFormat) {
                    ForEach(OutputFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
            .background(glassColorSystem.backgroundColor())
    }
    
    private var formContent: some View {
        VStack(alignment: .leading, spacing: 24) {
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
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content")
                            .font(.caption)
                            .foregroundColor(glassColorSystem.textSecondary())
                            .textCase(.uppercase)
                        
                        TextEditor(text: $content)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                    .frame(minHeight: 320)
                            .padding(12)
                            .background(
                                GlassPanel(tier: .contentCard, cornerRadius: 8) {
                                    EmptyView()
                                }
                            )
                            .focused($isFocused)
                    }
                }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
            }
            
    private var footer: some View {
            HStack {
                Spacer()
                Button("Create") {
                    createArtifact()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                      content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(glassColorSystem.backgroundColor())
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
        
        closeDrawer()
    }
    
    private func closeDrawer() {
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isPresented = false
        }
    }
}

#Preview {
    ArtifactQuickAddDrawer(isPresented: .constant(true))
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [Artifact.self])
}

