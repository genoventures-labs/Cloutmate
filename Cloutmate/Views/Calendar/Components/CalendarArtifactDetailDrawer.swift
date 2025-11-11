//
//  CalendarArtifactDetailDrawer.swift
//  Cloutmate
//
//  Drawer presentation for calendar artifact previews
//

import SwiftUI
import SwiftData
import CloutmateShared

struct CalendarArtifactDetailDrawer: View {
    @Bindable var artifact: CloutmateShared.Artifact
    @Binding var isPresented: Bool
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var accentColor: Color {
        artifact.publishedAt == nil ? .kosmicPurple : .kosmicGreen
    }
    
    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                gradientSidebar
                
                VStack(spacing: 0) {
                    header
                        .padding()
                        .background(.ultraThinMaterial)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            metaSection
                            contentSection
                            timelineSection
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 24)
                    }
                    .background(Color(.windowBackgroundColor))
                    
                    footer
                        .padding(20)
                        .background(.ultraThinMaterial)
                }
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
        .frame(minWidth: 600, minHeight: 500)
        .frame(idealWidth: 800, idealHeight: 600)
    }
    
    private var gradientSidebar: some View {
        RoundedRectangle(cornerRadius: 0, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [accentColor.opacity(0.85), accentColor.opacity(0.35)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 4)
    }
    
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(artifact.title.isEmpty ? "Untitled Artifact" : artifact.title)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(glassColorSystem.textPrimary())
                    .lineLimit(2)
                
                if let publishedAt = artifact.publishedAt {
                    Text("Published")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
    
    private var metaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metadata")
                .font(.headline)
                .foregroundColor(glassColorSystem.textPrimary())
            
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Captured", value: artifact.createdAt.formatted(date: .abbreviated, time: .shortened))
                
                if let publishedAt = artifact.publishedAt {
                    LabeledContent("Published", value: publishedAt.formatted(date: .abbreviated, time: .shortened))
                }
                
                if !artifact.tags.isEmpty {
                    LabeledContent("Tags") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                            ForEach(artifact.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.kosmicPurple.opacity(0.15))
                                    .foregroundColor(.kosmicPurple)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            .font(.subheadline)
            .foregroundColor(glassColorSystem.textSecondary())
        }
    }
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Content")
                .font(.headline)
                .foregroundColor(glassColorSystem.textPrimary())
            
            if !artifact.content.isEmpty {
                Text(artifact.content)
                    .font(.body)
                    .foregroundColor(glassColorSystem.textSecondary())
            } else if let summary = artifact.sentimentSummary, !summary.isEmpty {
                Text(summary)
                    .font(.body)
                    .foregroundColor(glassColorSystem.textSecondary())
            } else {
                Text("No content available")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .font(.headline)
                .foregroundColor(glassColorSystem.textPrimary())
            
                VStack(alignment: .leading, spacing: 8) {
                LabeledContent("State", value: artifact.artifactState.displayName)
                
                if let archivedAt = artifact.archivedAt {
                    LabeledContent("Archived", value: archivedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                
                LabeledContent("Last Updated", value: artifact.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }
            .font(.subheadline)
            .foregroundColor(glassColorSystem.textSecondary())
        }
    }
    
    private var footer: some View {
        HStack(spacing: 12) {
            Button(action: archiveArtifact) {
                Label("Archive", systemImage: "archivebox")
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button(action: closeDrawer) {
                Text("Done")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private func archiveArtifact() {
        artifact.archivedAt = Date()
        artifact.updatedAt = Date()
        try? modelContext.save()
        closeDrawer()
    }
    
    private func closeDrawer() {
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isPresented = false
        }
    }
}
