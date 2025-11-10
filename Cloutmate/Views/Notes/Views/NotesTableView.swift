//
//  NotesTableView.swift
//  Cloutmate
//
//  Table view for notes
//

import SwiftUI
import CloutmateShared

struct NotesTableView: View {
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
        Table(notes) {
            TableColumn("") { note in
                if selectionMode {
                    SelectionIndicator(isSelected: selectedNoteIDs.contains(note.id))
                        .onTapGesture {
                            onSelectionToggle(note)
                        }
                } else {
                    Image(systemName: note.isPinned ? "pin.fill" : "note.text")
                        .font(.caption)
                        .foregroundColor(note.isPinned ? .kosmicBlue : .secondary)
                        .frame(width: 20)
                }
            }
            .width(30)
            
            TableColumn("Title") { note in
                HStack(spacing: 6) {
                    Text(note.title.isEmpty ? "Untitled Note" : note.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if note.author == .aurora {
                        AuroraAuthorBadge()
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectionMode {
                        onSelectionToggle(note)
                    } else {
                        onNoteTap(note)
                    }
                }
            }
            
            TableColumn("Preview") { note in
                Text(note.markdown.isEmpty ? "—" : String(note.markdown.prefix(60)))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectionMode {
                            onSelectionToggle(note)
                        } else {
                            onNoteTap(note)
                        }
                    }
            }
            
            TableColumn("Tags") { note in
                if !note.tags.isEmpty {
                    Text(note.tags.prefix(3).joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("—")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            
            TableColumn("Updated") { note in
                Text(note.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .width(100)
        }
        .tableStyle(.inset)
    }
}

