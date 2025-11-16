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
        GridItem(.adaptive(minimum: 300, maximum: 340), spacing: 20)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
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
            .padding(.vertical, 4)
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
    
    @State private var isHovered = false
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    private var previewText: String {
        let lines = note.markdown.components(separatedBy: .newlines)
        let firstFiveLines = Array(lines.prefix(5)).joined(separator: "\n")
        return firstFiveLines.isEmpty ? "No content" : firstFiveLines
    }
    
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
        GlassPanel(tier: .contentCard, cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(alignment: .top, spacing: 12) {
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
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .center, spacing: 8) {
                            Text(note.title.isEmpty ? "Untitled Note" : note.title)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(note.isPinned ? 
                                    AnyShapeStyle(LinearGradient(
                                        colors: [.kosmicBlue, .kosmicPurple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )) :
                                    AnyShapeStyle(glassColorSystem.textPrimary()))
                                .lineLimit(2)
                            
                            if note.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 11, weight: .semibold))
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
                                textFont: .system(size: 13, weight: .regular, design: .rounded),
                                mentionFont: .system(size: 13, weight: .medium, design: .rounded)
                            )
                            .foregroundStyle(glassColorSystem.textSecondary())
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .mask(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: .black, location: 0),
                                        .init(color: .black, location: 0.85),
                                        .init(color: .clear, location: 1.0)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // Footer
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                        .background(glassColorSystem.borderColor().opacity(0.3))
                    
                    HStack(spacing: 12) {
                        if !note.tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(note.tags.prefix(3), id: \.self) { tag in
                                        Text("#\(tag)")
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                    .fill(glassColorSystem.emotionalAccent().opacity(0.15))
                                            )
                                            .foregroundStyle(glassColorSystem.emotionalAccent())
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 10, weight: .medium))
                                Text(note.updatedAt, style: .relative)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(glassColorSystem.textSecondary())
                            
                            if note.projectId != nil {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(glassColorSystem.textSecondary())
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(borderGradient, lineWidth: isSelected ? 1.6 : 0.6)
                .animation(GlassMotion.Easing.spring, value: isSelected)
        )
        .shadow(
            color: glassColorSystem.emotionalAccent().opacity(isHovered ? 0.22 : 0.12),
            radius: isHovered ? 18 : 12,
            x: 0,
            y: isHovered ? 12 : 6
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
        .frame(minHeight: 220)
    }
}

