//
//  ConversationCardV2.swift
//  FocusOS
//
//  AI Assistant V2 - Conversation Card Component
//  GlassCard-based design with hover effects and smooth animations
//

import SwiftUI
import FocusOSShared

struct ConversationCardV2: View {
    let conversation: AIConversation
    let isSelected: Bool
    let isMultiSelectMode: Bool
    let isMultiSelected: Bool
    let onTap: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    let onRefreshSummary: () -> Void
    let onExportToDraft: () -> Void
    let onToggleMultiSelect: () -> Void
    
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        cardContent
            .overlay(borderOverlay)
            .background(backgroundColor)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(reduceMotion ? nil : GlassMotion.Easing.spring) {
                    onTap()
                }
            }
            .onHover { hovering in
                withAnimation(reduceMotion ? nil : GlassMotion.Easing.spring) {
                    isHovered = hovering
                }
            }
            .modifier(ConditionalFloatLiftEffect(shouldApply: !reduceMotion))
            .contextMenu {
                contextMenuContent
            }
    }
    
    private var cardContent: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 8) {
                headerRow
                titleText
                if let summary = conversation.summary, !summary.isEmpty {
                    summaryText(summary)
                }
                dateText
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }
    
    private var headerRow: some View {
        HStack(spacing: 8) {
            // Checkbox for multi-select (always visible, but only functional when in multi-select mode)
            Button(action: onToggleMultiSelect) {
                Image(systemName: isMultiSelected ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundColor(isMultiSelected ? .kosmicBlue : .secondary)
                    .opacity(isMultiSelectMode ? 1.0 : 0.3)
            }
            .buttonStyle(.plain)
            .help(isMultiSelectMode ? (isMultiSelected ? "Deselect" : "Select") : "Click to select multiple conversations")
            
            if conversation.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundColor(.kosmicBlue)
            }
            
            if !conversation.tags.isEmpty {
                tagsView
            }
            
            Spacer()
            
            if isHovered && !isMultiSelectMode {
                hoverActions
            }
        }
    }
    
    private var tagsView: some View {
        HStack(spacing: 4) {
            ForEach(conversation.tags.prefix(2), id: \.self) { tag in
                Text(tag)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.kosmicBlue.opacity(0.15))
                    .foregroundColor(.kosmicBlue)
                    .cornerRadius(4)
            }
            if conversation.tags.count > 2 {
                Text("+\(conversation.tags.count - 2)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var hoverActions: some View {
        HStack(spacing: 6) {
            if conversation.summary != nil {
                Button(action: onRefreshSummary) {
                    Image(systemName: "doc.text")
                        .font(.caption)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Refresh summary")
            }
            
            Button(action: onExportToDraft) {
                Image(systemName: "square.and.arrow.down")
                    .font(.caption)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help("Export to Drafts")
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .frame(width: 20, height: 20)
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .help("Delete conversation")
        }
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
    }
    
    private var titleText: some View {
        Text(conversation.title ?? "")
            .font(.system(.body, design: .rounded))
            .fontWeight(isSelected ? .medium : .regular)
            .lineLimit(1)
    }
    
    private func summaryText(_ summary: String) -> some View {
        Text(summary)
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(2)
    }
    
    private var dateText: some View {
        Text((conversation.createdAt ?? Date()).formatted(date: .abbreviated, time: .shortened))
            .font(.caption2)
            .foregroundColor(.secondary)
    }
    
    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(borderColor, lineWidth: borderWidth)
    }
    
    private var borderColor: Color {
        if isSelected {
            return Color.kosmicBlue.opacity(0.5)
        } else if conversation.isPinned {
            return Color.kosmicBlue.opacity(0.3)
        } else {
            return Color.clear
        }
    }
    
    private var borderWidth: CGFloat {
        if isSelected {
            return 2
        } else if conversation.isPinned {
            return 1.5
        } else {
            return 0
        }
    }
    
    @ViewBuilder
    private var backgroundColor: some View {
        if isSelected {
            Color.kosmicBlue.opacity(0.1)
        } else if conversation.isPinned {
            Color.kosmicBlue.opacity(0.05)
        }
    }
    
    private var contextMenuContent: some View {
        Group {
            Button(conversation.isPinned ? "Unpin" : "Pin to Top", systemImage: conversation.isPinned ? "pin.slash" : "pin") {
                onTogglePin()
            }
            
            Divider()
            
            Button("Rename", systemImage: "pencil") {
                onRename()
            }
            
            if conversation.summary != nil {
                Button("Refresh Summary", systemImage: "arrow.clockwise") {
                    onRefreshSummary()
                }
            }
            
            Divider()
            
            Button("Export to Drafts", systemImage: "square.and.arrow.down") {
                onExportToDraft()
            }
            
            Divider()
            
            Button("Delete", systemImage: "trash", role: .destructive) {
                onDelete()
            }
        }
    }
}

// MARK: - Conditional Float Lift Effect

struct ConditionalFloatLiftEffect: ViewModifier {
    let shouldApply: Bool
    
    func body(content: Content) -> some View {
        if shouldApply {
            content.modifier(FloatLiftEffect())
        } else {
            content
        }
    }
}

#Preview {
    @Previewable @State var conversation = AIConversation(title: "Sample Conversation")
    
    ConversationCardV2(
        conversation: conversation,
        isSelected: false,
        isMultiSelectMode: false,
        isMultiSelected: false,
        onTap: {},
        onRename: {},
        onDelete: {},
        onTogglePin: {},
        onRefreshSummary: {},
        onExportToDraft: {},
        onToggleMultiSelect: {}
    )
    .padding()
    .environmentObject(GlassColorSystem())
}

