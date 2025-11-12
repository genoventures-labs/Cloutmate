//
//  MentionTextView.swift
//
//  View for rendering text with mentions styled as inline callouts (Notion-style)
//

import SwiftUI
import SwiftData
import AppKit
import CloutmateShared

struct MentionRenderedTextView: View {
    let text: String
    var editableTextBinding: Binding<String>? // Optional binding for editable contexts
    var onMentionRemoved: ((UUID) -> Void)? // Optional callback for removal
    var textFont: Font
    var mentionFont: Font?
    
    @Environment(\.modelContext) private var modelContext
    @State private var resolvedMentions: [ResolvedMention] = []
    @State private var removedMentionIds: Set<UUID> = []
    
    init(
        text: String,
        editableText: Binding<String>? = nil,
        onMentionRemoved: ((UUID) -> Void)? = nil,
        textFont: Font = .body,
        mentionFont: Font? = nil
    ) {
        self.text = text
        self.editableTextBinding = editableText
        self.onMentionRemoved = onMentionRemoved
        self.textFont = textFont
        self.mentionFont = mentionFont
    }
    
    var body: some View {
        if #available(macOS 12.0, *) {
            renderedView
        } else {
            // Fallback for older macOS
            Text(text)
        }
    }
    
    @available(macOS 12.0, *)
    private var renderedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Parse and render with inline callouts
            renderTextWithCallouts()
        }
        .onAppear {
            resolveMentions()
        }
        .onChange(of: text) { _, _ in
            resolveMentions()
        }
    }
    
    private func resolveMentions() {
        resolvedMentions = MentionService.shared.resolveAllMentions(
            from: text,
            modelContext: modelContext
        )
    }
    
    @available(macOS 12.0, *)
    @ViewBuilder
    private func renderTextWithCallouts() -> some View {
        let parts = buildTextParts()
        
        // If no mentions found, render as plain text
        if parts.isEmpty {
            let displayText = MentionParser.stripTerminators(from: MentionService.shared.convertToDisplayNames(
                text: text,
                modelContext: modelContext
            ))
            Text(displayText)
                .font(textFont)
        } else {
            // Render parts with mentions as inline callouts
            renderPartsInline(parts)
        }
    }
    
    @available(macOS 12.0, *)
    private func buildTextParts() -> [TextPart] {
        // Convert structured mentions to display names for rendering
        let displayTextRaw = MentionService.shared.convertToDisplayNames(
            text: text,
            modelContext: modelContext
        )
        
        let mentions = MentionParser.parseMentions(from: displayTextRaw)
            .sorted(by: { $0.range.location < $1.range.location })
        
        var currentIndex = displayTextRaw.startIndex
        var parts: [TextPart] = []
        
        // Build parts array with text segments and mentions
        for mention in mentions {
            let mentionStart = displayTextRaw.index(displayTextRaw.startIndex, offsetBy: mention.range.location)
            let mentionEnd = displayTextRaw.index(mentionStart, offsetBy: mention.range.length)
            
            // Add text before mention
            if mentionStart > currentIndex {
                let textSegmentRaw = String(displayTextRaw[currentIndex..<mentionStart])
                let textSegment = MentionParser.stripTerminators(from: textSegmentRaw)
                if !textSegment.isEmpty {
                    parts.append(.text(textSegment))
                }
            }
            
            // Find resolved mention
            let resolved = resolvedMentions.first(where: { match in
                if let structuredId = mention.structuredId {
                    return match.id == structuredId && !removedMentionIds.contains(match.id)
                } else {
                    // For multi-word mentions, check exact match first, then partial match
                    let mentionLower = mention.mentionText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    let displayLower = match.displayName.lowercased()
                    
                    if displayLower == mentionLower || displayLower.contains(mentionLower) || mentionLower.contains(displayLower) {
                        return !removedMentionIds.contains(match.id)
                    }
                    return false
                }
            })
            
            if let resolved = resolved {
                parts.append(.mention(mention.fullText, resolved))
            } else {
                // Unresolved mention - render as plain text
                let mentionTextRaw = String(displayTextRaw[mentionStart..<mentionEnd])
                let mentionText = MentionParser.stripTerminators(from: mentionTextRaw)
                parts.append(.text(mentionText))
            }
            
            currentIndex = mentionEnd
        }
        
        // Add remaining text
        if currentIndex < displayTextRaw.endIndex {
            let textSegmentRaw = String(displayTextRaw[currentIndex...])
            let textSegment = MentionParser.stripTerminators(from: textSegmentRaw)
            if !textSegment.isEmpty {
                parts.append(.text(textSegment))
            }
        }
        
        return parts
    }
    
    @available(macOS 12.0, *)
    @ViewBuilder
    private func renderPartsInline(_ parts: [TextPart]) -> some View {
        // Use HStack with wrapping for inline callouts
        // Note: This is a simplified approach - for true inline text wrapping,
        // you'd need a custom TextLayout or use NSTextView
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                    switch part {
                    case .text(let text):
                        Text(text)
                            .font(textFont)
                    case .mention(_, let resolved):
                        MentionCallout(
                            mention: resolved,
                            onRemove: {
                                removeMention(resolved)
                            },
                            onTap: {
                                navigateToMention(resolved)
                            },
                            isEditable: editableTextBinding != nil,
                            textFont: mentionFont ?? textFont
                        )
                    }
                }
            }
        }
    }
    
    private func removeMention(_ mention: ResolvedMention) {
        removedMentionIds.insert(mention.id)
        
        // If editable text binding is provided, remove the mention from text
        if let binding = editableTextBinding {
            var editableText = binding.wrappedValue
            // Find and remove the mention from text
            let structuredMention = MentionParser.toStructuredFormat(type: mention.type, id: mention.id)
            let displayMention = "@\(mention.displayName)"
            let displayMentionWithTerminator = displayMention + MentionParser.mentionTerminator
            
            // Remove structured format
            editableText = editableText.replacingOccurrences(of: structuredMention, with: "")
            // Also remove display format if present
            editableText = editableText.replacingOccurrences(of: displayMentionWithTerminator, with: "")
            editableText = editableText.replacingOccurrences(of: displayMention, with: "")
            // Clean up extra spaces
            editableText = editableText.replacingOccurrences(of: "  ", with: " ")
            editableText = editableText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            binding.wrappedValue = editableText
        }
        
        // Call callback if provided
        onMentionRemoved?(mention.id)
        
        // Trigger re-render
        resolveMentions()
    }
    
    private func navigateToMention(_ mention: ResolvedMention) {
        let tab: TabIdentifier
        
        switch mention.type {
        case .task:
            tab = .tasks
        case .project:
            tab = .projects
        case .note:
            tab = .notes
        case .artifact:
            tab = .posts
        case .post:
            tab = .posts
        case .reminder:
            tab = .inbox
        case .inboxItem:
            tab = .inbox
        case .focusSession:
            tab = .focusMode
        }
        
        NotificationCenter.default.post(name: .switchTab, object: tab)
        NotificationCenter.default.post(
            name: .openEntity,
            object: nil,
            userInfo: ["id": mention.id, "type": mention.type.rawValue]
        )
    }
    
    private enum TextPart {
        case text(String)
        case mention(String, ResolvedMention)
    }
}
