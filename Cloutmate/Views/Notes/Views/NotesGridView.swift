//
//  NotesGridView.swift
//  Cloutmate
//
//  Grid view for notes
//

import SwiftUI
import CloutmateShared

struct NotesGridView: View {
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
    
    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 320), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(notes) { note in
                    NoteGridCard(
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

struct NoteGridCard: View {
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
    
    private var previewText: String {
        let lines = note.markdown.components(separatedBy: .newlines)
        let firstFiveLines = Array(lines.prefix(5)).joined(separator: "\n")
        return firstFiveLines.isEmpty ? "No content" : firstFiveLines
    }
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            if note.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.caption2)
                                    .foregroundColor(.kosmicBlue)
                            }
                            
                            Text(note.title.isEmpty ? "Untitled Note" : note.title)
                                .font(.headline)
                                .fontWeight(note.isPinned ? .semibold : .medium)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                            
                            if note.author == .aurora {
                                AuroraAuthorBadge()
                            }
                        }
                        
                        MentionRenderedTextView(
                            text: previewText,
                            textFont: .caption,
                            mentionFont: .caption
                        )
                            .foregroundColor(.secondary)
                            .lineLimit(4)
                    }
                    
                    Spacer()
                    
                    if selectionMode {
                        SelectionIndicator(isSelected: isSelected)
                            .onTapGesture {
                                onSelectionToggle()
                            }
                    }
                }
                
                if !note.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(note.tags.prefix(4), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.kosmicPurple.opacity(0.1))
                                    .foregroundColor(.kosmicPurple)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                
                HStack {
                    Text(note.updatedAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if note.projectId != nil {
                        Image(systemName: "folder.fill")
                            .font(.caption2)
                            .foregroundColor(.kosmicBlue)
                    }
                }
            }
            .padding(16)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSelected ? LinearGradient(
                        colors: [.kosmicBlue, .kosmicPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom),
                    lineWidth: isSelected ? 2 : 0
                )
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
        .frame(height: 200)
    }
}

