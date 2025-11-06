//
//  NoteCardV2.swift
//  Cloutmate
//
//  Modern note card component for Notes V2 redesign
//

import SwiftUI
import SwiftData
import CloutmateShared

struct NoteCardV2: View {
    @Bindable var note: Note
    let onTap: () -> Void
    let onEdit: () -> Void
    let onPin: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    @State private var showHoverActions = false
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    private var previewText: String {
        let lines = note.markdown.components(separatedBy: .newlines)
        let firstThreeLines = Array(lines.prefix(3)).joined(separator: "\n")
        return firstThreeLines.isEmpty ? "No content" : firstThreeLines
    }
    
    private var isSelected: Bool {
        false // Can be bound from parent if needed
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Focus Gravity accent border (left edge)
            if isSelected {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.kosmicBlue, .kosmicPurple],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 4)
            }
            
            // Main card content
            GlassPanel(tier: .contentCard, cornerRadius: 12) {
                HStack(alignment: .top, spacing: 12) {
                    // Content
                    VStack(alignment: .leading, spacing: 8) {
                        // Title with pin indicator
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            if note.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.caption2)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.kosmicBlue, .kosmicPurple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            }
                            
                            Text(note.title.isEmpty ? "Untitled Note" : note.title)
                                .font(.system(.body, design: .rounded))
                                .fontWeight(note.isPinned ? .semibold : .medium)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                                .applyIf(note.isPinned) { view in
                                    view.foregroundStyle(
                                        LinearGradient(
                                            colors: [.kosmicBlue, .kosmicPurple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                }
                        }
                        
                        // Preview text with fade-out
                        Text(previewText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .mask(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: .black, location: 0),
                                        .init(color: .black, location: 0.8),
                                        .init(color: .clear, location: 1.0)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        // Metadata row
                        HStack(spacing: 8) {
                            // Tags
                            if !note.tags.isEmpty {
                                HStack(spacing: 4) {
                                    ForEach(note.tags.prefix(3), id: \.self) { tag in
                                        Text("#\(tag)")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.kosmicPurple.opacity(0.1))
                                            .foregroundColor(.kosmicPurple)
                                            .cornerRadius(4)
                                    }
                                    if note.tags.count > 3 {
                                        Text("+\(note.tags.count - 3)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // Last modified date
                            Text(note.updatedAt, style: .relative)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            // Linked project/task icon
                            if note.projectId != nil {
                                Image(systemName: "folder.fill")
                                    .font(.caption2)
                                    .foregroundColor(.kosmicBlue)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Hover actions
                    if showHoverActions {
                        HStack(spacing: 8) {
                            Button(action: onEdit) {
                                Image(systemName: "pencil")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .padding(6)
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Edit")
                            
                            Button(action: {}) {
                                Image(systemName: "link")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .padding(6)
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Link")
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
                .padding(16)
                .frame(minHeight: 56)
            }
        }
        .floatLift()
        .onTapGesture {
            onTap()
        }
        .onHover { hovering in
            if reduceMotion {
                isHovered = hovering
                showHoverActions = hovering
            } else {
                withAnimation(GlassMotion.Easing.spring) {
                    isHovered = hovering
                    showHoverActions = hovering
                }
            }
        }
        .contextMenu {
            Button("Edit") {
                onEdit()
            }
            Button(note.isPinned ? "Unpin" : "Pin") {
                onPin()
            }
            Divider()
            Button("Archive") {
                onArchive()
            }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
        .accessibilityLabel("Note: \(note.title)")
        .accessibilityHint("Double tap to open")
        .accessibilityValue(note.isPinned ? "Pinned" : "")
        .accessibilityAddTraits(note.isPinned ? .isSelected : [])
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

// MARK: - View Extension for Conditional Modifier

extension View {
    @ViewBuilder
    func applyIf<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        NoteCardV2(
            note: Note(title: "Sample Note", markdown: "This is a sample note with some content that spans multiple lines.\n\nHere's another paragraph to show how the preview works."),
            onTap: {},
            onEdit: {},
            onPin: {},
            onArchive: {},
            onDelete: {}
        )
        
        NoteCardV2(
            note: {
                let note = Note(title: "Pinned Note", markdown: "This note is pinned and should show a gradient title.")
                note.isPinned = true
                note.pinnedAt = Date()
                note.tags = ["important", "ideas", "work"]
                return note
            }(),
            onTap: {},
            onEdit: {},
            onPin: {},
            onArchive: {},
            onDelete: {}
        )
    }
    .padding()
    .environmentObject(GlassColorSystem())
}

