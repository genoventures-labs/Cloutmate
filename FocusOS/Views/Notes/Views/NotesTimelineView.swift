//
//  NotesTimelineView.swift
//  FocusOS
//
//  Timeline view for Notes showing chronological progression
//

import SwiftUI
import FocusOSShared

struct NotesTimelineView: View {
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
    
    private var groupedByDate: [(date: Date, notes: [Note])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: notes) { note in
            calendar.startOfDay(for: note.createdAt)
        }
        
        return grouped.map { (date: $0.key, notes: $0.value) }
            .sorted { $0.date > $1.date }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(groupedByDate, id: \.date) { group in
                    NotesTimelineDaySection(
                        date: group.date,
                        notes: group.notes,
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

private struct NotesTimelineDaySection: View {
    let date: Date
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
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }
    
    private var relativeDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    private var dateLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return dateFormatter.string(from: date)
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            // Date marker
            VStack(alignment: .trailing, spacing: 4) {
                Text(dateLabel)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                if !Calendar.current.isDateInToday(date) && !Calendar.current.isDateInYesterday(date) {
                    Text(relativeDateFormatter.string(from: date))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                }
                
                Text("\(notes.count)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(glassColorSystem.emotionalAccent().opacity(0.18))
                    )
            }
            .frame(width: 120, alignment: .trailing)
            
            // Timeline line
            VStack(spacing: 0) {
                Circle()
                    .fill(glassColorSystem.emotionalAccent())
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(glassColorSystem.backgroundElevated(), lineWidth: 2)
                    )
                
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                glassColorSystem.emotionalAccent().opacity(0.4),
                                glassColorSystem.emotionalAccent().opacity(0.1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 20)
            
            // Notes for this day
            VStack(alignment: .leading, spacing: 12) {
                ForEach(notes) { note in
                    NotesTimelineCard(
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
        }
    }
}

private struct NotesTimelineCard: View {
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
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    private var previewText: String {
        let lines = note.markdown.components(separatedBy: .newlines)
        let firstTwoLines = Array(lines.prefix(2)).joined(separator: "\n")
        return firstTwoLines.isEmpty ? "No content" : firstTwoLines
    }
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 18) {
            HStack(alignment: .top, spacing: 14) {
                // Time indicator
                VStack(alignment: .trailing, spacing: 4) {
                    Text(timeFormatter.string(from: note.createdAt))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                    
                    if note.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.kosmicBlue, .kosmicPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
                .frame(width: 60, alignment: .trailing)
                
                // Note content
                VStack(alignment: .leading, spacing: 8) {
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
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    if !note.tags.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(note.tags.prefix(3), id: \.self) { tag in
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
            }
            .padding(16)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
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
        .scaleEffect(isHovered ? 1.005 : 1.0)
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

