//
//  NotesBoardView.swift
//  FocusOS
//
//  Kanban board view for Notes organized by tags
//

import SwiftUI
import FocusOSShared

struct NotesBoardView: View {
    let notes: [Note]
    let selectionMode: Bool
    let selectedNoteIDs: Set<UUID>
    let onNoteTap: (Note) -> Void
    let onNoteEdit: (Note) -> Void
    let onNotePin: (Note) -> Void
    let onNoteArchive: (Note) -> Void
    let onNoteDelete: (Note) -> Void
    let onNoteSendToTasks: (Note) -> Void
    let onSelectionToggle: (Note) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var tagColumns: [(tag: String, notes: [Note])] {
        // Get all unique tags from notes
        var tagMap: [String: [Note]] = [:]
        var untaggedNotes: [Note] = []
        
        for note in notes {
            if note.tags.isEmpty {
                untaggedNotes.append(note)
            } else {
                for tag in note.tags {
                    tagMap[tag, default: []].append(note)
                }
            }
        }
        
        // Sort tags by note count (most common first) and take top 5
        let sortedTags = tagMap.sorted { $0.value.count > $1.value.count }.prefix(5)
        
        var columns: [(tag: String, notes: [Note])] = []
        
        // Add "All" column first
        columns.append(("All", notes))
        
        // Add top tag columns
        for (tag, tagNotes) in sortedTags {
            // Remove duplicates (notes can appear in multiple tag columns)
            let uniqueNotes = Array(Set(tagNotes))
            columns.append((tag, uniqueNotes))
        }
        
        // Add "Untagged" column if there are untagged notes
        if !untaggedNotes.isEmpty {
            columns.append(("Untagged", untaggedNotes))
        }
        
        return columns
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 20) {
                ForEach(tagColumns, id: \.tag) { column in
                    NotesBoardColumn(
                        title: column.tag,
                        notes: column.notes,
                        selectionMode: selectionMode,
                        selectedNoteIDs: selectedNoteIDs,
                        onNoteTap: onNoteTap,
                        onNoteEdit: onNoteEdit,
                        onNotePin: onNotePin,
                        onNoteArchive: onNoteArchive,
                        onNoteDelete: onNoteDelete,
                        onNoteSendToTasks: onNoteSendToTasks,
                        onSelectionToggle: onSelectionToggle
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct NotesBoardColumn: View {
    let title: String
    let notes: [Note]
    let selectionMode: Bool
    let selectedNoteIDs: Set<UUID>
    let onNoteTap: (Note) -> Void
    let onNoteEdit: (Note) -> Void
    let onNotePin: (Note) -> Void
    let onNoteArchive: (Note) -> Void
    let onNoteDelete: (Note) -> Void
    let onNoteSendToTasks: (Note) -> Void
    let onSelectionToggle: (Note) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    private var accentColor: Color {
        switch title {
        case "All": return .kosmicBlue
        case "Untagged": return .gray
        default: return glassColorSystem.emotionalAccent()
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column header
            DashboardTile(accent: accentColor.opacity(0.8), padding: 16) {
                HStack(alignment: .center, spacing: 10) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                    
                    Spacer()
                    
                    Text("\(notes.count)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(accentColor.opacity(0.18))
                        )
                }
            }
            .padding(.bottom, 12)
            
            // Notes in column
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(notes) { note in
                        NotesBoardCard(
                            note: note,
                            selectionMode: selectionMode,
                            isSelected: selectedNoteIDs.contains(note.id),
                            onSelectionToggle: { onSelectionToggle(note) },
                            onTap: { onNoteTap(note) },
                            onEdit: { onNoteEdit(note) },
                            onPin: { onNotePin(note) },
                            onArchive: { onNoteArchive(note) },
                            onDelete: { onNoteDelete(note) },
                            onSendToTasks: { onNoteSendToTasks(note) }
                        )
                    }
                }
                .padding(.top, 4)
            }
        }
        .frame(width: 300)
    }
}

private struct NotesBoardCard: View {
    @Bindable var note: Note
    let selectionMode: Bool
    let isSelected: Bool
    let onSelectionToggle: () -> Void
    let onTap: () -> Void
    let onEdit: () -> Void
    let onPin: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void
    let onSendToTasks: () -> Void
    
    @State private var isHovered = false
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    private var previewText: String {
        let lines = note.markdown.components(separatedBy: .newlines)
        let firstThreeLines = Array(lines.prefix(3)).joined(separator: "\n")
        return firstThreeLines.isEmpty ? "No content" : firstThreeLines
    }
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    if note.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.kosmicBlue, .kosmicPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    
                    Text(note.title.isEmpty ? "Untitled Note" : note.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(note.isPinned ? 
                            AnyShapeStyle(LinearGradient(
                                colors: [.kosmicBlue, .kosmicPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )) :
                            AnyShapeStyle(glassColorSystem.textPrimary()))
                        .lineLimit(2)
                    
                    Spacer()
                    
                    if selectionMode {
                        SelectionIndicator(isSelected: isSelected)
                            .onTapGesture {
                                onSelectionToggle()
                            }
                    }
                }
                
                if !note.markdown.isEmpty {
                    MentionRenderedTextView(
                        text: previewText,
                        textFont: .system(size: 12, weight: .regular, design: .rounded),
                        mentionFont: .system(size: 12, weight: .medium, design: .rounded)
                    )
                    .foregroundStyle(glassColorSystem.textSecondary())
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                }
                
                HStack(spacing: 6) {
                    if note.author == .aurora {
                        AuroraAuthorBadge()
                    }
                    
                    Spacer()
                    
                    Text(note.updatedAt, style: .relative)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                }
            }
            .padding(14)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isSelected ? 
                    LinearGradient(
                        colors: [.kosmicBlue, .kosmicPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        colors: [glassColorSystem.borderColor().opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: isSelected ? 1.4 : 0.6
                )
                .animation(GlassMotion.Easing.spring, value: isSelected)
        )
        .shadow(
            color: glassColorSystem.emotionalAccent().opacity(isHovered ? 0.18 : 0.10),
            radius: isHovered ? 12 : 8,
            x: 0,
            y: isHovered ? 6 : 3
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(GlassMotion.Easing.spring, value: isHovered)
        .contentShape(Rectangle())
        .onTapGesture {
            if selectionMode {
                onSelectionToggle()
            } else {
                onTap()
            }
        }
        .onTapGesture(count: 2, perform: onEdit)
        .onHover { hovering in
            guard !selectionMode else {
                isHovered = hovering
                return
            }
            if reduceMotion {
                isHovered = hovering
            } else {
                withAnimation(GlassMotion.Easing.spring) {
                    isHovered = hovering
                }
            }
        }
        .contextMenu {
            Button("Edit") { onEdit() }
            Button("Send to Tasks", systemImage: "checkmark.circle") { onSendToTasks() }
            Button(note.isPinned ? "Unpin" : "Pin") { onPin() }
            Divider()
            Button("Archive") { onArchive() }
            Button("Delete", role: .destructive) { onDelete() }
        }
    }
}

