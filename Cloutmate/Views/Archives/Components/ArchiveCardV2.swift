//
//  ArchiveCardV2.swift
//  Cloutmate
//
//  Archives V2 - Archive card component
//

import SwiftUI
import SwiftData
import CloutmateShared

struct ArchiveCardV2: View {
    let archiveItem: ArchiveItem
    let onTap: () -> Void
    let onRestore: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    @State private var showHoverActions = false
    @State private var reflection: ArchiveReflection?
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    private var entityIcon: String {
        switch archiveItem {
        case .project: return "folder.fill"
        case .area: return "rectangle.stack.fill"
        case .note: return "doc.text.fill"
        case .artifact: return "brain.head.profile"
        case .draft: return "doc.text"
        }
    }
    
    private var entityColor: Color {
        switch archiveItem {
        case .project: return .kosmicBlue
        case .area: return .gray
        case .note: return .kosmicPurple
        case .artifact: return .kosmicGreen
        case .draft: return .kosmicBlue
        }
    }
    
    private var archivedDate: Date? {
        archiveItem.archivedAt
    }
    
    private var archivedDateString: String {
        guard let date = archivedDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private var excerpt: String {
        let desc = archiveItem.description ?? ""
        if desc.isEmpty {
            return "No description available"
        }
        return String(desc.prefix(120)) + (desc.count > 120 ? "..." : "")
    }
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 12) {
                headerRow
                bodySection
                footerRow
            }
            .padding(16)
        }
        .applyIf(!reduceMotion) { view in
            view.floatLift()
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [entityColor.opacity(0.3), entityColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isHovered ? 1.5 : 0.5
                )
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            if reduceMotion {
                showHoverActions = hovering
            } else {
                withAnimation(GlassMotion.Easing.spring) {
                    showHoverActions = hovering
                }
            }
        }
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button("Restore", systemImage: "arrow.counterclockwise") {
                onRestore()
            }
            Divider()
            Button("Permanently Delete", systemImage: "trash", role: .destructive) {
                onDelete()
            }
        }
        .task {
            await loadReflection()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(archiveItem.entityType): \(archiveItem.title)")
        .accessibilityHint("Archived on \(archivedDateString). Double tap to view details.")
    }
    
    private var headerRow: some View {
        HStack(alignment: .top, spacing: 12) {
            // Entity icon
            Image(systemName: entityIcon)
                .font(.title3)
                .foregroundColor(entityColor)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(archiveItem.title)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                
                // Tag badges
                if let themes = reflection?.learningThemes, !themes.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(themes.prefix(3), id: \.self) { theme in
                                Text(theme)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(entityColor.opacity(0.15))
                                    .foregroundColor(entityColor)
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            // Hover actions
            if showHoverActions {
                HStack(spacing: 8) {
                    Button(action: onRestore) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.caption)
                            .foregroundColor(.kosmicBlue)
                            .padding(6)
                            .background(Color.kosmicBlue.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Restore")
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(6)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete")
                }
            }
        }
    }
    
    private var bodySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Excerpt
            Text(excerpt)
                .font(.callout)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            // Captured Insight (Aurora summary)
            if let commentary = reflection?.auroraCommentary, !commentary.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundColor(.kosmicPurple)
                    Text(commentary)
                        .font(.caption)
                        .foregroundColor(.kosmicPurple.opacity(0.9))
                        .italic()
                        .lineLimit(1)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.kosmicPurple.opacity(0.1))
                .cornerRadius(6)
            }
            
            // Mini ARTE tone bar
            if let toneSnapshot = reflection?.arteToneSnapshot,
               let tone = EmotionalState(rawValue: toneSnapshot) {
                toneBar(for: tone)
            }
        }
    }
    
    private func toneBar(for tone: EmotionalState) -> some View {
        let palette = EmotionalPalette.palette(for: tone)
        let color = Color(
            hue: palette.accentHue / 360.0,
            saturation: palette.accentSaturation,
            brightness: 0.7
        )
        
        return HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(height: 4)
            Text(tone.displayName)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var footerRow: some View {
        HStack(spacing: 12) {
            // Archived date
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(archivedDateString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Source (if linked)
            if let projectId = getProjectId() {
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.caption2)
                        .foregroundColor(.kosmicBlue)
                    Text("From Project")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func getProjectId() -> UUID? {
        switch archiveItem {
        case .note(let note): return note.projectId
        case .artifact(let artifact): return artifact.projectId
        default: return nil
        }
    }
    
    private func loadReflection() async {
        // Extract UUID from enum first
        let entityId = archiveItem.id
        let descriptor = FetchDescriptor<ArchiveReflection>(
            predicate: #Predicate { reflection in
                reflection.entityId == entityId
            }
        )
        
        if let existing = try? modelContext.fetch(descriptor).first {
            await MainActor.run {
                reflection = existing
            }
        }
    }
}

#Preview {
    ArchiveCardV2(
        archiveItem: .project(CloutmateShared.Project(title: "Sample Project", goal: "Test goal")),
        onTap: {},
        onRestore: {},
        onDelete: {}
    )
    .padding()
    .environmentObject(GlassColorSystem())
}

