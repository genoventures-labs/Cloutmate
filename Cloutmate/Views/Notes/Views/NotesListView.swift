//
//  NotesListView.swift
//  Cloutmate
//
//  Compact list view for notes
//

import SwiftUI
import CloutmateShared

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
            LazyVStack(spacing: 8) {
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
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
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
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        HStack(spacing: 12) {
            if selectionMode {
                SelectionIndicator(isSelected: isSelected)
                    .onTapGesture {
                        onSelectionToggle()
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if note.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundColor(.kosmicBlue)
                    }
                    
                    Text(note.title.isEmpty ? "Untitled Note" : note.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if note.author == .aurora {
                        AuroraAuthorBadge()
                    }
                }
                
                if !note.markdown.isEmpty {
                    MentionRenderedTextView(
                        text: note.markdown,
                        textFont: .caption,
                        mentionFont: .caption
                    )
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 8) {
                    if !note.tags.isEmpty {
                        Text(note.tags.prefix(2).joined(separator: ", "))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(note.updatedAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.kosmicBlue.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.kosmicBlue : Color.clear, lineWidth: 1)
        )
        .onTapGesture {
            if selectionMode {
                onSelectionToggle()
            } else {
                onTap()
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

