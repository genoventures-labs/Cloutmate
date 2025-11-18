//
//  InboxCardV2.swift
//  FocusOS
//
//  Inbox V2 - Modern Capture Card System
//

import SwiftUI
import SwiftData
import AppKit
import FocusOSShared

struct InboxCardV2: View {
    @Bindable var item: InboxItem
    let onTap: () -> Void
    let onConvertToTask: () -> Void
    let onConvertToNote: () -> Void
    let onConvertToDraft: () -> Void
    let onConvertToProject: () -> Void
    let onArchive: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityGlassManager) private var accessibilityManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    private var accentColor: Color {
        if item.isArchived {
            return .gray
        } else if item.convertedAt != nil {
            return .kosmicGreen
        } else {
            return .kosmicBlue
        }
    }
    
    private var itemTypeIcon: String {
        switch item.itemType {
        case "text": return "text.alignleft"
        case "file": return "doc"
        case "url": return "link"
        case "voice": return "mic.fill"
        default: return "tray"
        }
    }
    
    private var itemTypeColor: Color {
        switch item.itemType {
        case "text": return .kosmicBlue
        case "file": return .kosmicPurple
        case "url": return .kosmicGreen
        case "voice": return .orange
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Card Content
            VStack(alignment: .leading, spacing: 12) {
                // Header: Type Icon + Timestamp
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: itemTypeIcon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(itemTypeColor)
                            .frame(width: 20, height: 20)
                        
                        if item.isFlagged {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                        }
                        
                        if item.aiImported {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                                .foregroundColor(.kosmicPurple)
                        }
                    }
                    
                    Spacer()
                    
                    Text(item.createdAt, style: .relative)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                // Body: Content Snippet
                Text(item.content)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Footer: Action Buttons (shown on hover)
                if isHovered {
                    HStack(spacing: 8) {
                        // Convert Menu
                        Menu {
                            Button(action: {
                                withAnimation(GlassMotion.Easing.spring) {
                                    onConvertToTask()
                                }
                            }) {
                                Label("Task", systemImage: "checkmark.circle")
                            }
                            Button(action: {
                                withAnimation(GlassMotion.Easing.spring) {
                                    onConvertToNote()
                                }
                            }) {
                                Label("Note", systemImage: "doc.text")
                            }
                            Button(action: {
                                withAnimation(GlassMotion.Easing.spring) {
                                    onConvertToDraft()
                                }
                            }) {
                                Label("Draft", systemImage: "square.and.pencil")
                            }
                            Button(action: {
                                withAnimation(GlassMotion.Easing.spring) {
                                    onConvertToProject()
                                }
                            }) {
                                Label("Project", systemImage: "folder.fill")
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("Convert")
                                    .font(.system(.caption, design: .rounded))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8))
                            }
                            .foregroundColor(.kosmicBlue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.kosmicBlue.opacity(0.1))
                            )
                        }
                        .buttonStyle(.plain)
                        .ripple(color: .kosmicBlue)
                        
                        Spacer()
                        
                        // Archive Button
                        Button(action: onArchive) {
                            Image(systemName: "archivebox")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(Color.gray.opacity(0.1))
                                )
                        }
                        .buttonStyle(.plain)
                        
                        // Pin Button
                        if !item.isFlagged {
                            Button(action: onPin) {
                                Image(systemName: "pin")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.gray)
                                    .frame(width: 28, height: 28)
                                    .background(
                                        Circle()
                                            .fill(Color.gray.opacity(0.1))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(16)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
            .offset(x: dragOffset)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        isDragging = true
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        withAnimation(GlassMotion.Easing.spring) {
                            if value.translation.width < -100 {
                                // Swipe left = Archive
                                onArchive()
                            } else if value.translation.width > 100 {
                                // Swipe right = Quick convert menu (could show menu)
                                // For now, convert to note as default
                                onConvertToNote()
                            }
                            dragOffset = 0
                            isDragging = false
                        }
                    }
            )
            .onTapGesture {
                onTap()
            }
            .onHover { hovering in
                withAnimation(GlassMotion.Easing.spring) {
                    isHovered = hovering
                }
            }
            .contextMenu {
                Button("Convert to Task", systemImage: "checkmark.circle") {
                    onConvertToTask()
                }
                Button("Convert to Note", systemImage: "doc.text") {
                    onConvertToNote()
                }
                Button("Convert to Draft", systemImage: "square.and.pencil") {
                    onConvertToDraft()
                }
                Button("Convert to Project", systemImage: "folder.fill") {
                    onConvertToProject()
                }
                Divider()
                Button(item.isFlagged ? "Unflag" : "Flag", systemImage: item.isFlagged ? "flag.slash" : "flag") {
                    onPin() // Reusing pin handler for flag
                }
                Button("Archive", systemImage: "archivebox") {
                    onArchive()
                }
                Divider()
                Button("Delete", systemImage: "trash", role: .destructive) {
                    onDelete()
                }
            }
        }
        .glassPanel(tier: .contentCard, cornerRadius: 12)
        .overlay(
            // Accent border
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    accentColor.opacity(item.isArchived ? 0.3 : (isHovered ? 0.6 : 0.4)),
                    lineWidth: item.isArchived ? 1 : (isHovered ? 2 : 1)
                )
                .animation(GlassMotion.Easing.spring, value: isHovered)
        )
        .shadow(
            color: Color.kosmicBlue.opacity(isHovered ? 0.2 : 0.1),
            radius: isHovered ? 6 : 4,
            x: 0,
            y: isHovered ? 3 : 2
        )
        .scaleEffect(reduceMotion ? 1.0 : (isHovered ? 1.01 : 1.0))
        .opacity(item.isArchived ? 0.6 : 1.0)
        .animation(reduceMotion ? nil : GlassMotion.Easing.spring, value: isHovered)
        .animation(reduceMotion ? nil : GlassMotion.Easing.spring, value: dragOffset)
        .accessibilityLabel("Inbox entry, \(item.itemType), created \(item.createdAt.formatted(date: .abbreviated, time: .shortened))")
        .accessibilityHint("Double tap to open details")
        .accessibilityAddTraits(item.isFlagged ? .isSelected : [])
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

#Preview {
    let item = InboxItem(content: "This is a sample inbox item with some content that might be longer than expected.", itemType: "text")
    
    return InboxCardV2(
        item: item,
        onTap: {},
        onConvertToTask: {},
        onConvertToNote: {},
        onConvertToDraft: {},
        onConvertToProject: {},
        onArchive: {},
        onPin: {},
        onDelete: {}
    )
    .padding()
    .environmentObject(GlassColorSystem())
}

