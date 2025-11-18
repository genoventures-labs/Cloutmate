//
//  MentionCallout.swift
//
//  Notion-style inline callout for linked mentions
//

import SwiftUI
import SwiftData
import FocusOSShared

struct MentionCallout: View {
    let mention: ResolvedMention
    let onRemove: () -> Void
    let onTap: () -> Void
    var isEditable: Bool = false // Whether removal is allowed
    var textFont: Font = .system(size: 13, weight: .medium)
    
    @Environment(\.modelContext) private var modelContext
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                // Icon
                Image(systemName: mention.type.icon)
                    .font(.system(size: 12))
                    .foregroundColor(.kosmicBlue)
                    .frame(width: 16, height: 16)
                
                // Title
                Text(mention.displayName)
                    .font(textFont)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Remove button - only show on hover and if editable
                if isHovered && isEditable {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove link")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.kosmicBlue.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.kosmicBlue.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

