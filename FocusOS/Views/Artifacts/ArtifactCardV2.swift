//
//  ArtifactCardV2.swift
//  FocusOS
//
//  Artifacts V2 - Card component
//

import SwiftUI
import SwiftData
import FocusOSShared

struct ArtifactCardV2: View {
    let artifact: Artifact
    
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var isHovered = false
    @State private var arteTone: EmotionalState = .calm
    
    private var shadowColor: Color {
        isHovered ? arteToneColor.opacity(0.2) : Color.black.opacity(0.05)
    }
    
    private var shadowRadius: CGFloat {
        isHovered ? 12 : 4
    }
    
    private var shadowY: CGFloat {
        isHovered ? 8 : 2
    }
    
    private var scaleValue: CGFloat {
        reduceMotion ? 1.0 : (isHovered ? 1.015 : 1.0)
    }
    
    var arteToneColor: Color {
        let palette = EmotionalPalette.palette(for: arteTone)
        let hue = palette.accentHue / 360.0
        let saturation = palette.accentSaturation
        return Color(hue: hue, saturation: saturation, brightness: 0.7)
    }
    
    var statusColor: Color {
        switch artifact.artifactState {
        case .draft: return .kosmicBlue
        case .final: return .kosmicGreen
        case .published: return .kosmicPurple
        case .archived: return .gray
        case .idea: return .orange
        }
    }
    
    private var arteColorStrip: some View {
        Rectangle()
            .fill(arteToneColor.opacity(0.6))
            .frame(height: 3)
            .cornerRadius(1.5)
    }
    
    private var typeLabel: some View {
        Text(artifact.format.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(arteToneColor)
            .cornerRadius(6)
    }
    
    private var titleText: String {
        artifact.title.isEmpty ? "Untitled" : artifact.title
    }
    
    private var linkedEntityChips: some View {
        HStack(spacing: 6) {
            ForEach(Array(artifact.linkedEntityIds.prefix(3).enumerated()), id: \.element) { index, entityId in
                if index < artifact.linkedEntityTypes.count {
                    let entityType = artifact.linkedEntityTypes[index]
                    EntityBadge(
                        label: "@\(entityType)",
                        color: arteToneColor
                    )
                }
            }
            if artifact.linkedEntityIds.count > 3 {
                let remainingCount = artifact.linkedEntityIds.count - 3
                Text("+\(remainingCount)")
                    .font(.caption2)
                    .foregroundColor(glassColorSystem.textTertiary())
            }
        }
    }
    
    private var statusBar: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(statusColor.opacity(0.6))
                .frame(width: nil)
                .frame(maxWidth: .infinity)
            
            Rectangle()
                .fill(glassColorSystem.glassTint(for: .surface).opacity(0.2))
                .frame(width: nil)
        }
        .frame(height: 3)
        .cornerRadius(1.5)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ARTE Color Strip
            arteColorStrip
            
            // Top Row: Type Label, Menu
            HStack(alignment: .top, spacing: 12) {
                typeLabel
                
                Spacer()
                
                // Confidence Icon
                if artifact.confidenceScore < 0.8 {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
            
            // Title
            Text(titleText)
                .font(.headline)
                .foregroundColor(glassColorSystem.textPrimary())
                .lineLimit(2)
            
            // Content Preview
            if !artifact.content.isEmpty {
                Text(artifact.content)
                    .font(.caption)
                    .foregroundColor(glassColorSystem.textSecondary())
                    .lineLimit(3)
            }
            
            // Linked Entity Chips
            if !artifact.linkedEntityIds.isEmpty {
                linkedEntityChips
            }
            
            // Status Bar
            statusBar
            
            // Footer: Status + Timestamp
            HStack {
                Text(artifact.artifactState.displayName)
                    .font(.caption2)
                    .foregroundColor(statusColor)
                
                Spacer()
                
                Text(artifact.updatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundColor(glassColorSystem.textTertiary())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GlassPanel(tier: .contentCard, cornerRadius: 12) {
                EmptyView()
            }
        )
        .shadow(
            color: shadowColor,
            radius: shadowRadius,
            y: shadowY
        )
        .scaleEffect(scaleValue)
        .animation(reduceMotion ? nil : GlassMotion.Easing.spring, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onOpen()
        }
        .task {
            loadARTETone()
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to open artifact details")
        .contextMenu {
            Button("Open") {
                onOpen()
            }
            Button("Edit") {
                onEdit()
            }
            Button("Duplicate", systemImage: "doc.on.doc") {
                onDuplicate()
            }
            Button("Archive", systemImage: "archivebox") {
                onArchive()
            }
            Divider()
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
    
    private var accessibilityLabel: String {
        let title = artifact.title.isEmpty ? "Untitled" : artifact.title
        let status = artifact.artifactState.displayName
        let updated = artifact.updatedAt.formatted(date: .abbreviated, time: .omitted)
        return "Artifact: \(title), Status: \(status), Updated: \(updated)"
    }
    
    @MainActor
    private func loadARTETone() {
        if let arteToneString = artifact.arteToneSnapshot,
           let tone = EmotionalState(rawValue: arteToneString) {
            arteTone = tone
        } else {
            arteTone = ReactiveThemeManager.shared.currentState
        }
    }
}

// MARK: - Supporting Views

struct EntityBadge: View {
    let label: String
    let color: Color
    
    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .cornerRadius(8)
    }
}

#Preview {
    let artifact = Artifact(
        title: "Weekly Reflection",
        content: "This week I focused on improving my workflow and productivity.",
        outputFormat: .reflection,
        state: .draft
    )
    
    return ArtifactCardV2(
        artifact: artifact,
        onOpen: {},
        onEdit: {},
        onDuplicate: {},
        onArchive: {},
        onDelete: {}
    )
        .padding()
        .background(Color(.windowBackgroundColor))
        .environmentObject(GlassColorSystem())
}

