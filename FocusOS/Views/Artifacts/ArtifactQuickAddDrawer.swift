//
//  ArtifactQuickAddDrawer.swift
//  FocusOS
//
//  Artifacts V2 - Quick add modal for artifact creation
//

import SwiftUI
import SwiftData
import FocusOSShared

struct ArtifactQuickAddDrawer: View {
    @Binding var isPresented: Bool
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.colorScheme) private var colorScheme
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
            V2DrawerScaffold(
                accentGradient: accentGradient,
                showsSidebar: false,
                header: { headerContent },
                content: {
                    formatSection
                    contentSection
                },
                sidebar: { EmptyView() }
            )
            .frame(minWidth: 840, minHeight: 620)
            .frame(maxHeight: .infinity)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isFocused = true
            }
        }
        .onEscape {
            closeDrawer()
        }
    }
    
    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.kosmicBlue.opacity(0.4),
                Color.kosmicPurple.opacity(0.32)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var headerContent: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Artifact Title", text: $title)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                    .textFieldStyle(.plain)
                    .drawerFocusGlow()
                    .focused($isFocused)
                
                Text("Capture your ideas or drafts without breaking flow.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            Spacer(minLength: 20)
            
            VStack(spacing: 12) {
                GlassButton(
                    "Cancel",
                    icon: "xmark",
                    style: .standard,
                    role: .surface
                ) {
                    closeDrawer()
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                GlassButton(
                    "Create Artifact",
                    icon: "sparkles",
                    style: .standard,
                    role: .primary
                ) {
                    createArtifact()
                }
                .disabled(!canCreate)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
    }
    
    private var formatSection: some View {
        DrawerSection(title: "Format", icon: "rectangle.grid.2x2", subtitle: "Choose the best structure for this capture") {
            HStack(spacing: 12) {
                ForEach(OutputFormat.allCases, id: \.self) { format in
                    formatTabButton(for: format)
                }
            }
        }
    }
    
    private var contentSection: some View {
        DrawerSection(title: "Content", icon: "doc.richtext", subtitle: "Draft your thoughts or paste material here") {
            MentionTextEditor(
                text: $content,
                placeholder: "Draft your thoughts or paste material here…",
                onMentionsChanged: { _, _ in }
            )
            .frame(minHeight: 260)
            .drawerFocusGlow()
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
                        glassColorSystem.cardColor().opacity(0.35) :
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

