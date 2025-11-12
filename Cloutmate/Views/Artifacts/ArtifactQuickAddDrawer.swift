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
    @FocusState private var isFocused: Bool
    
    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    formatTabs
                    formFields
                    createButton
                }
                .padding(24)
                .background(Color(.windowBackgroundColor))
            }
            .background(Color(.windowBackgroundColor))
            .navigationTitle("New Artifact")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        closeDrawer()
                    }
                }
            }
        }
        .frame(width: 620, height: 580)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isFocused = true
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Capture your ideas or drafts without breaking flow.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var formatTabs: some View {
        HStack(spacing: 12) {
            ForEach(OutputFormat.allCases, id: \.self) { format in
                formatTabButton(for: format)
            }
        }
    }
    
    private func formatTabButton(for format: OutputFormat) -> some View {
        let isSelected = selectedFormat == format
        return Button {
            withAnimation(GlassMotion.Easing.spring) {
                selectedFormat = format
            }
        } label: {
            VStack(spacing: 6) {
                Text(format.displayName)
                    .fontWeight(isSelected ? .semibold : .medium)
                Text(format.description)
                    .font(.caption2)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        isSelected ?
                        glassColorSystem.glassTint(for: .surface).opacity(0.35) :
                        Color.clear
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected ?
                        Color.kosmicBlue.opacity(0.55) :
                        Color.white.opacity(0.12),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
    
    private var formFields: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                TextField("Enter title…", text: $title)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.08))
                            )
                    )
                    .font(.system(size: 17, weight: .semibold))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Content")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                MentionTextEditor(
                    text: $content,
                    placeholder: "Draft your thoughts or paste material here…",
                    onMentionsChanged: { _, _ in }
                )
                .frame(minHeight: 260)
                .focused($isFocused)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.06))
                        )
                )
            }
        }
    }
    
    private var createButton: some View {
        HStack {
            Spacer()
            Button {
                createArtifact()
            } label: {
                Label("Create Artifact", systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canCreate)
        }
    }
    
    private func createArtifact() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle: String
        if !trimmedTitle.isEmpty {
            resolvedTitle = trimmedTitle
        } else if !trimmedContent.isEmpty {
            resolvedTitle = String(trimmedContent.prefix(50))
        } else {
            resolvedTitle = "Untitled Artifact"
        }
        
        let artifact = Artifact(
            title: resolvedTitle,
            content: trimmedContent.isEmpty ? resolvedTitle : content,
            outputFormat: selectedFormat,
            state: .draft
        )
        
        artifact.arteToneSnapshot = ReactiveThemeManager.shared.currentState.rawValue
        ArtifactPredictiveBridge.shared.captureForecastSnapshot(for: artifact, modelContext: modelContext)
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

