//
//  NotesListView.swift
//  FocusOS
//
//  Compact list view for notes
//

import SwiftUI
import FocusOSShared

struct NotesListView: View {
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
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(notes) { note in
                    NoteListRow(
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
            .padding(.vertical, 4)
        }
    }
}

struct NoteListRow: View {
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
    
    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                glassColorSystem.emotionalAccent().opacity(0.6),
                glassColorSystem.emotionalAccent().opacity(0.4)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 18) {
            HStack(spacing: 14) {
                if selectionMode {
                    SelectionIndicator(isSelected: isSelected)
                        .onTapGesture {
                            onSelectionToggle()
                        }
                }
                
                if note.isPinned {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.kosmicBlue, .kosmicPurple],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 3)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(note.title.isEmpty ? "Untitled Note" : note.title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(note.isPinned ? 
                                AnyShapeStyle(LinearGradient(
                                    colors: [.kosmicBlue, .kosmicPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )) :
                                AnyShapeStyle(glassColorSystem.textPrimary()))
                            .lineLimit(1)
                        
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
                        
                        if note.author == .aurora {
                            AuroraAuthorBadge()
                        }
                        
                        Spacer()
                        
                        if !note.tags.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(note.tags.prefix(2), id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(
                                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                                .fill(glassColorSystem.emotionalAccent().opacity(0.15))
                                        )
                                        .foregroundStyle(glassColorSystem.emotionalAccent())
                                }
                            }
                        }
                    }
                    
                    if !note.markdown.isEmpty {
                        MentionRenderedTextView(
                            text: String(note.markdown.prefix(80)),
                            textFont: .system(size: 13, weight: .regular, design: .rounded),
                            mentionFont: .system(size: 13, weight: .medium, design: .rounded)
                        )
                        .foregroundStyle(glassColorSystem.textSecondary())
                        .lineLimit(1)
                    }
                    
                    HStack(spacing: 10) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 10, weight: .medium))
                            Text(note.updatedAt, style: .relative)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(glassColorSystem.textSecondary())
                        
                        if note.projectId != nil {
                            HStack(spacing: 4) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 10, weight: .medium))
                                Text("Linked")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(glassColorSystem.textSecondary())
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
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
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(borderGradient, lineWidth: isSelected ? 1.4 : 0.6)
                .animation(GlassMotion.Easing.spring, value: isSelected)
        )
        .shadow(
            color: glassColorSystem.emotionalAccent().opacity(isHovered ? 0.18 : 0.10),
            radius: isHovered ? 14 : 10,
            x: 0,
            y: isHovered ? 8 : 4
        )
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .animation(GlassMotion.Easing.spring, value: isHovered)
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

