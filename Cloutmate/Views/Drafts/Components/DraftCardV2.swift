//
//  DraftCardV2.swift
//  Cloutmate
//
//  Modern draft card component for Drafts V2 redesign
//

import SwiftUI
import SwiftData
import CloutmateShared

struct DraftCardV2: View {
    @Bindable var draft: Draft
    
    let isActive: Bool
    let showSelectionIndicator: Bool
    let isSelected: Bool
    
    let onOpen: () -> Void
    let onShare: () -> Void
    let onPublish: () -> Void
    let onExport: () -> Void
    let onDuplicate: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void
    let onSelectionToggle: () -> Void
    
    @State private var isHovered = false
    @State private var showHoverActions = false
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityGlassManager) private var accessibilityManager
    
    private var previewText: String {
        let caption = draft.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        if !caption.isEmpty {
            return caption
        }
        
        if let notes = draft.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
            return notes
        }
        
        return "No content yet — start writing to bring this draft to life."
    }
    
    private var footerSourceText: String {
        if let source = draft.source, !source.isEmpty {
            return source
        }
        return "User-Created"
    }
    
    private var metadataBadges: [DraftBadge] {
        var badges: [DraftBadge] = []
        
        if draft.metadataTags.contains("AI") || (draft.source?.localizedCaseInsensitiveContains("ai") ?? false) {
            badges.append(DraftBadge(title: "AI", icon: "sparkles", colors: [.kosmicBlue, .kosmicPurple]))
        } else {
            badges.append(DraftBadge(title: "Manual", icon: "hand.draw", colors: [.kosmicGreen.opacity(0.8), .kosmicBlue.opacity(0.7)]))
        }
        
        if draft.metadataTags.contains("Post-type Draft") {
            badges.append(DraftBadge(title: "Post", icon: "hash", colors: [.kosmicPurple.opacity(0.8), .kosmicBlue.opacity(0.7)]))
        }
        
        if draft.tags.contains(where: { $0.localizedCaseInsensitiveContains("shared") }) {
            badges.append(DraftBadge(title: "Shared", icon: "person.2.fill", colors: [.kosmicBlue.opacity(0.8), .kosmicGreen.opacity(0.7)]))
        }
        
        return badges
    }
    
    var body: some View {
        HStack(spacing: 0) {
            if isActive {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: calmMode ? [.secondary.opacity(0.4), .secondary.opacity(0.4)] : [.kosmicBlue, .kosmicGreen],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 4)
                    .accessibilityHidden(true)
            }
            
            GlassPanel(tier: .contentCard, cornerRadius: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    topRow
                    previewSection
                    footerRow
                }
                .padding(18)
                .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
            }
            .overlay(
                selectionOverlay,
                alignment: .topTrailing
            )
            .overlay(
                hoverActions,
                alignment: .topTrailing
            )
        }
        .applyIf(!reduceMotion) { view in
            view.floatLift()
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: borderColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isHovered ? 2 : 0.5
                )
        )
        .contentShape(Rectangle())
        .dynamicTypeSize(...DynamicTypeSize.accessibility5)
        .onHover { hovering in
            guard !showSelectionIndicator else {
                isHovered = hovering
                showHoverActions = false
                return
            }
            
            isHovered = hovering
            if reduceMotion {
                showHoverActions = hovering
            } else {
                withAnimation(GlassMotion.Easing.spring) {
                    showHoverActions = hovering
                }
            }
        }
        .onTapGesture {
            if showSelectionIndicator {
                onSelectionToggle()
            } else {
                onOpen()
            }
        }
        .contextMenu {
            Button("Open", systemImage: "arrow.up.right.square") {
                onOpen()
            }
            Button("Export", systemImage: "square.and.arrow.up") {
                onExport()
            }
            Button("Duplicate", systemImage: "doc.on.doc") {
                onDuplicate()
            }
            Button(draft.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox") {
                onArchive()
            }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) {
                onDelete()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(draft.displayTitle)")
        .accessibilityHint("Draft. Double tap to open editor.")
        .accessibilityValue(accessibilitySummary)
    }
    
    private var topRow: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(draft.displayTitle)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .accessibilityAddTraits(isActive ? .isSelected : [])
                
                if !metadataBadges.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(metadataBadges) { badge in
                                badgeView(badge)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            Spacer()
        }
    }
    
    private var previewSection: some View {
        Text(previewText)
            .font(.callout)
            .foregroundColor(.secondary)
            .lineLimit(dynamicTypeSize >= .accessibility1 ? 5 : 4)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .mask(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .black, location: 0.0),
                        .init(color: .black, location: 0.85),
                        .init(color: .clear, location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .padding(.trailing, showHoverActions ? 60 : 0)
    }
    
    private var footerRow: some View {
        HStack(spacing: 12) {
            Label {
                Text(draft.lastEditedAt, format: .relative(presentation: .named))
            } icon: {
                Image(systemName: "clock")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            Divider()
                .frame(height: 12)
            
            Label(footerSourceText, systemImage: "bolt.horizontal")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
                .frame(height: 12)
            
            Label("\(draft.wordCount) words", systemImage: "textformat.size")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    private var hoverActions: some View {
        Group {
            if showHoverActions {
                HStack(spacing: 8) {
                    hoverButton(title: "Open", icon: "arrow.up.right.square") {
                        onOpen()
                    }
                    hoverButton(title: "Share", icon: "square.and.arrow.up") {
                        onShare()
                    }
                    hoverButton(title: "Publish", icon: "paperplane.fill") {
                        onPublish()
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
                .padding([.top, .trailing], 12)
            }
        }
    }
    
    private func hoverButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.black.opacity(0.2))
            )
        }
        .buttonStyle(.plain)
        .tint(.white)
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
    }
    
    private func badgeView(_ badge: DraftBadge) -> some View {
        Label {
            Text(badge.title)
                .font(.caption2)
                .fontWeight(.medium)
        } icon: {
            Image(systemName: badge.icon)
                .font(.caption2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            LinearGradient(
                colors: badge.colors,
                startPoint: .leading,
                endPoint: .trailing
            )
            .opacity(0.18)
        )
        .foregroundColor(badge.colors.last ?? .primary)
        .cornerRadius(8)
    }
    
    private var selectionOverlay: some View {
        Group {
            if showSelectionIndicator {
                SelectionIndicator(isSelected: isSelected)
                    .padding(12)
                    .onTapGesture {
                        onSelectionToggle()
                    }
            }
        }
    }
    
    private var borderColors: [Color] {
        if calmMode {
            return [.white.opacity(0.08), .white.opacity(0.04)]
        }
        if isActive {
            return [.kosmicBlue.opacity(0.6), .kosmicGreen.opacity(0.6)]
        }
        return isHovered ? [.kosmicPurple.opacity(0.5), .kosmicBlue.opacity(0.4)] : [.white.opacity(0.06), .clear]
    }
    
    private var accessibilitySummary: String {
        var summary: [String] = []
        summary.append("\(draft.wordCount) words")
        summary.append("Last edited \(RelativeDateTimeFormatter().localizedString(for: draft.lastEditedAt, relativeTo: Date()))")
        summary.append("Source \(footerSourceText)")
        if draft.metadataTags.contains("Post-type Draft") {
            summary.append("Post type")
        }
        if isActive {
            summary.append("Active")
        }
        if !draft.tags.isEmpty {
            let tagSummary = draft.tags.prefix(3).joined(separator: ", ")
            summary.append("Tags \(tagSummary)")
        }
        return summary.joined(separator: ", ")
    }
    
    private var calmMode: Bool {
        accessibilityManager.performanceMode == .balanced
    }
}

private struct DraftBadge: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let icon: String
    let colors: [Color]
}

#Preview {
    let draft = Draft(
        caption: """
        Weekly Social Media Recap
        """,
        tags: ["marketing", "shared"],
        notes: """
        Key talking points:
        - Highlight engagement growth
        - Mention community shout-outs
        - CTA for newsletter signups
        """
    )
    draft.source = "AI Assistant"
    draft.metadataTags = ["AI", "Post-type Draft"]
    draft.wordCount = 148
    return DraftCardV2(
        draft: draft,
        isActive: true,
        showSelectionIndicator: false,
        isSelected: false,
        onOpen: {},
        onShare: {},
        onPublish: {},
        onExport: {},
        onDuplicate: {},
        onArchive: {},
        onDelete: {},
        onSelectionToggle: {}
    )
    .frame(width: 360)
    .environmentObject(GlassColorSystem())
    .padding()
}

