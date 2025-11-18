//
//  NoteCardV2.swift
//  FocusOS
//
//  Modern note card component for Notes V2 redesign
//

import SwiftUI
import SwiftData
import FocusOSShared

struct NoteCardV2: View {
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
    @State private var showHoverActions = false
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    private var previewText: String {
        let lines = note.markdown.components(separatedBy: .newlines)
        let firstThreeLines = Array(lines.prefix(3)).joined(separator: "\n")
        return firstThreeLines.isEmpty ? "No content" : firstThreeLines
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
                headerRow
                
                if !note.markdown.isEmpty {
                    previewSection
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
        .overlay(alignment: .topTrailing) {
            if selectionMode {
                SelectionIndicator(isSelected: isSelected)
                    .padding(12)
                    .onTapGesture {
                        onSelectionToggle()
                    }
            }
        }
        .contextMenu {
            if !selectionMode {
                Button("Edit") {
                    onEdit()
                }
                Button("Send to Tasks", systemImage: "checkmark.circle") {
                    onSendToTasks()
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
        }
        .accessibilityLabel("Note: \(note.title.isEmpty ? "Untitled" : note.title)")
        .accessibilityHint("Double tap to open")
        .accessibilityValue(note.isPinned ? "Pinned" : "")
        .accessibilityAddTraits(note.isPinned ? .isSelected : [])
        .onChange(of: selectionMode) { _, newValue in
            if newValue {
                isHovered = false
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
    
    private var headerRow: some View {
        HStack(alignment: .center, spacing: 12) {
            if note.isPinned {
                pinnedIndicator
            }
            
            VStack(alignment: .leading, spacing: 8) {
                titleRow
                metadataRow
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
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
    
    private var pinnedIndicator: some View {
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
    
    private var titleRow: some View {
        HStack(alignment: .center, spacing: 10) {
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
            
            if !note.tags.isEmpty {
                tagsPreview
            }
        }
    }
    
    private var tagsPreview: some View {
        HStack(spacing: 4) {
            ForEach(note.tags.prefix(2), id: \.self) { tag in
                Text("#\(tag)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(glassColorSystem.emotionalAccent().opacity(0.18))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(glassColorSystem.emotionalAccent().opacity(0.35), lineWidth: 0.8)
                    )
                    .foregroundStyle(glassColorSystem.emotionalAccent())
            }
            if note.tags.count > 2 {
                Text("+\(note.tags.count - 2)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
            }
        }
    }
    
    private var metadataRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11, weight: .medium))
                Text(note.updatedAt, style: .relative)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
            .foregroundStyle(glassColorSystem.textSecondary())
            
            if note.projectId != nil {
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 11, weight: .medium))
                    Text("Linked")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundStyle(glassColorSystem.textSecondary())
            }
        }
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .background(glassColorSystem.borderColor().opacity(0.3))
            
            MentionRenderedTextView(
                text: previewText,
                textFont: .system(size: 14, weight: .regular, design: .rounded),
                mentionFont: .system(size: 14, weight: .medium, design: .rounded)
            )
            .foregroundStyle(glassColorSystem.textSecondary())
            .lineLimit(4)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 26)
            .padding(.vertical, 18)
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
            selectionMode: false,
            isSelected: false,
            onSelectionToggle: {},
            onTap: {},
            onEdit: {},
            onPin: {},
            onArchive: {},
            onDelete: {},
            onSendToTasks: {}
        )
        
        NoteCardV2(
            note: {
                let note = Note(title: "Pinned Note", markdown: "This note is pinned and should show a gradient title.")
                note.isPinned = true
                return note
            }(),
            selectionMode: true,
            isSelected: true,
            onSelectionToggle: {},
            onTap: {},
            onEdit: {},
            onPin: {},
            onArchive: {},
            onDelete: {},
            onSendToTasks: {}
        )
    }
    .padding()
    .environmentObject(GlassColorSystem())
}

