//
//  MentionTextView.swift
//  Cloutmate
//
//  View for rendering text with mentions styled and tappable, showing inline previews
//

import SwiftUI
import SwiftData
import AppKit
import CloutmateShared

struct MentionRenderedTextView: View {
    let text: String
    @Environment(\.modelContext) private var modelContext
    @State private var resolvedMentions: [ResolvedMention] = []
    
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
        VStack(alignment: .leading, spacing: 0) {
            // Parse and render with mentions
            if let attributedString = createAttributedString() {
                AttributedTextWithMentions(
                    attributedString: attributedString,
                    resolvedMentions: resolvedMentions
                )
            } else {
                Text(text)
            }
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
    private func createAttributedString() -> AttributedString? {
        // First convert structured mentions to display names for rendering
        let displayText = MentionService.shared.convertToDisplayNames(
            text: text,
            modelContext: modelContext
        )
        
        var attributedString = try? AttributedString(
            markdown: displayText,
            options: AttributedString.MarkdownParsingOptions(
                allowsExtendedAttributes: true,
                interpretedSyntax: .full
            )
        )
        
        // Style mentions
        let mentions = MentionParser.parseMentions(from: displayText)
        for mention in mentions {
            if let resolved = resolvedMentions.first(where: { match in
                if let structuredId = mention.structuredId {
                    return match.id == structuredId
                } else {
                    return match.displayName.lowercased() == mention.mentionText.lowercased()
                }
            }) {
                // Find the range in attributed string and style it
                if let range = attributedString?.range(of: mention.fullText) {
                    attributedString?[range].foregroundColor = .kosmicBlue
                    attributedString?[range].font = .system(.body, design: .default).weight(.medium)
                    attributedString?[range].link = URL(string: "mention://\(resolved.type.rawValue)/\(resolved.id.uuidString)")
                }
            }
        }
        
        return attributedString
    }
}

@available(macOS 12.0, *)
struct AttributedTextWithMentions: View {
    let attributedString: AttributedString
    let resolvedMentions: [ResolvedMention]
    
    var body: some View {
        Text(attributedString)
            .textSelection(.enabled)
            .tint(.kosmicBlue)
    }
}


