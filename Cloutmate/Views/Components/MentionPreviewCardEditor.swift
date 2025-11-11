//
//  MentionPreviewCardEditor.swift
//
//  Notion-style preview card for linked mentions in editing area
//

import SwiftUI
import SwiftData
import CloutmateShared

struct MentionPreviewCardEditor: View {
    let mention: ResolvedMention
    let onRemove: () -> Void
    let onTap: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: mention.type.icon)
                    .font(.system(size: 16))
                    .foregroundColor(.kosmicBlue)
                    .frame(width: 20, height: 20)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(mention.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if !mention.subtitle.isEmpty {
                        Text(cleanSubtitle(mention.subtitle))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Remove button - only show on hover
                if isHovered {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove link")
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func cleanSubtitle(_ subtitle: String) -> String {
        // Convert any structured mentions in subtitle to display names
        var cleaned = MentionService.shared.convertToDisplayNames(
            text: subtitle,
            modelContext: modelContext
        )
        cleaned = MentionParser.stripTerminators(from: cleaned)
        
        // Remove any remaining structured mention patterns that couldn't be resolved
        // Pattern: @{type:UUID} or @{type:UUID-...}
        let structuredPattern = #"@\{[^}]+\}"#
        cleaned = cleaned.replacingOccurrences(
            of: structuredPattern,
            with: "",
            options: .regularExpression
        )
        
        // Clean up extra spaces that might result from removal
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned.isEmpty ? "No description available" : cleaned
    }
}

