//
//  MessageBubble.swift
//  Cloutmate
//
//  Glass-themed Message Bubble
//

import SwiftUI
import AppKit
import SwiftData
import CloutmateShared

struct MessageBubble: View {
    let message: AIMessage
    let onEdit: ((AIMessage, String) -> Void)?
    let onCopy: ((String) -> Void)?
    let onResend: ((AIMessage) -> Void)?
    let canResend: Bool
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @State private var isEditing = false
    @State private var editText = ""
    @State private var showCopiedToast = false
    
    var isUser: Bool {
        message.role ?? "user" == "user"
    }
    
    var isSystemMessage: Bool {
        message.isSystemMessage
    }
    
    @ViewBuilder
    private var messageBackground: some View {
        if isUser {
            LinearGradient(
                colors: [Color.kosmicBlue, Color.kosmicPurple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isSystemMessage {
            Color.yellow.opacity(0.2)
                .background(.ultraThinMaterial)
        } else {
            Color.clear
                .background(.ultraThinMaterial)
        }
    }
    
    var body: some View {
        HStack(alignment: .top) {
            if isUser && !isSystemMessage {
                Spacer(minLength: 60)
            }
            
            if isSystemMessage {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isSystemMessage ? .center : (isUser ? .trailing : .leading), spacing: 4) {
                // Message content or edit field
                if isEditing {
                    editMessageView
                } else {
                    messageContentView
                }
                
                // Timestamp
                Text((message.timestamp ?? Date()).formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                
                // Tool used indicator
                if let tool = message.toolUsed {
                    Text("Used: \(tool)")
                        .font(.caption2)
                        .foregroundColor(.kosmicBlue)
                        .padding(.horizontal, 4)
                }
            }
            
            if !isUser && !isSystemMessage {
                Spacer(minLength: 60)
            }
            
            if isSystemMessage {
                Spacer(minLength: 60)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 16)
        .overlay(alignment: .top) {
            if showCopiedToast {
                copiedToastView
                    .padding(.top, -40)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Message Content View
    
    private var messageContentView: some View {
        VStack(alignment: isSystemMessage ? .center : .leading, spacing: 12) {
            if let documentName = message.documentFileName {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(isUser ? .white.opacity(0.9) : .kosmicBlue)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(documentName)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(isUser ? .white : .primary)
                            Text(documentMetadataLine(for: message))
                                .font(.caption2)
                                .foregroundColor(isUser ? .white.opacity(0.85) : .secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    if let preview = message.documentTextPreview?.trimmingCharacters(in: .whitespacesAndNewlines), !preview.isEmpty {
                        Text(preview)
                            .font(.caption2)
                            .foregroundColor(isUser ? .white.opacity(0.85) : .secondary)
                            .lineLimit(4)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isUser ? Color.white.opacity(0.12) : Color.gray.opacity(0.08))
                )
            }

            if let imageData = message.imageData,
               let image = NSImage(data: imageData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 320, maxHeight: 320)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(isUser ? 0.3 : 0.15), lineWidth: 1)
                    )
            }
            
            // Message text with markdown rendering
            if let content = message.content, !content.isEmpty {
                if isUser {
                    styledUserMessage(content)
                } else if #available(macOS 12.0, *) {
                    // Split content into sections for proper spacing
                    let sections = splitIntoSections(content)
                    
                    if sections.count > 1 {
                        // Multiple sections - render with explicit spacing
                        ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                            if let attributedSection = try? AttributedString(
                                markdown: normalizeSpacing(section),
                                options: AttributedString.MarkdownParsingOptions(
                                    allowsExtendedAttributes: true,
                                    interpretedSyntax: .full
                                )
                            ) {
                                VStack(alignment: .leading, spacing: 0) {
                                    if index > 0 {
                                        Spacer()
                                            .frame(height: 16)
                                    }
                                    
                                    Text(attributedSection)
                                        .foregroundColor(isSystemMessage ? .secondary : .primary)
                                        .textSelection(.enabled)
                                        .multilineTextAlignment(.leading)
                                        .lineSpacing(6)
                                        .lineLimit(nil)
                                        .allowsTightening(false)
                                        .minimumScaleFactor(1.0)
                                        .kerning(0) // Prevent character spacing issues
                                        .tint(.kosmicBlue)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            } else {
                                // Fallback to plain text with normalized spacing
                                VStack(alignment: .leading, spacing: 0) {
                                    if index > 0 {
                                        Spacer()
                                            .frame(height: 16)
                                    }
                                    Text(normalizeSpacing(section))
                                        .font(isSystemMessage ? .caption : .body)
                                        .fontWeight(isSystemMessage ? .medium : .regular)
                                        .foregroundColor(isSystemMessage ? .secondary : .primary)
                                        .textSelection(.enabled)
                                        .multilineTextAlignment(.leading)
                                        .lineSpacing(6)
                                        .lineLimit(nil)
                                        .allowsTightening(false)
                                        .kerning(0)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    } else {
                        // Single section - render normally with mention styling
                        if let attributedContent = try? AttributedString(
                            markdown: normalizeSpacing(content),
                            options: AttributedString.MarkdownParsingOptions(
                                allowsExtendedAttributes: true,
                                interpretedSyntax: .full
                            )
                        ) {
                            // Use MentionTextView for rendering with inline previews
                            MentionRenderedTextView(text: normalizeSpacing(content))
                                .foregroundColor(isSystemMessage ? .secondary : .primary)
                                .textSelection(.enabled)
                                .multilineTextAlignment(.leading)
                                .lineSpacing(6)
                                .lineLimit(nil)
                                .tint(.kosmicBlue)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            // Fallback to plain text with mention styling
                            let mentions = MentionParser.parseMentions(from: content)
                            if mentions.isEmpty {
                            Text(normalizeSpacing(content))
                                .font(isSystemMessage ? .caption : .body)
                                .fontWeight(isSystemMessage ? .medium : .regular)
                                .foregroundColor(isSystemMessage ? .secondary : .primary)
                                .textSelection(.enabled)
                                .multilineTextAlignment(.leading)
                                .lineSpacing(6)
                                .lineLimit(nil)
                                .allowsTightening(false)
                                .kerning(0)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                let styledContent = createAttributedStringWithMentions(content, mentions: mentions, isUser: false)
                                Text(styledContent)
                                    .font(isSystemMessage ? .caption : .body)
                                    .fontWeight(isSystemMessage ? .medium : .regular)
                                    .foregroundColor(isSystemMessage ? .secondary : .primary)
                                    .textSelection(.enabled)
                                    .multilineTextAlignment(.leading)
                                    .lineSpacing(6)
                                    .lineLimit(nil)
                                    .allowsTightening(false)
                                    .kerning(0)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                } else {
                    // Fallback for older macOS versions
                    Text(content)
                        .font(isSystemMessage ? .caption : .body)
                        .fontWeight(isSystemMessage ? .medium : .regular)
                        .foregroundColor(isSystemMessage ? .secondary : .primary)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(6)
                        .lineLimit(nil)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            // Document summary with source model indicator (assistant messages only)
            if !isUser, let summary = message.documentSummary, !summary.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    if let attributedSummary = try? AttributedString(
                        markdown: summary,
                        options: AttributedString.MarkdownParsingOptions(
                            allowsExtendedAttributes: true,
                            interpretedSyntax: .full
                        )
                    ) {
                        Text(attributedSummary)
                            .foregroundColor(isSystemMessage ? .secondary : .primary)
                            .textSelection(.enabled)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(6)
                            .lineLimit(nil)
                            .tint(.kosmicBlue)
                    } else {
                        Text(summary)
                            .foregroundColor(isSystemMessage ? .secondary : .primary)
                            .textSelection(.enabled)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(6)
                            .lineLimit(nil)
                    }
                    
                    // Powered by indicator (subtle, at bottom)
                    if let sourceModel = message.documentSourceModel, !sourceModel.isEmpty {
                        HStack(spacing: 4) {
                            Text("Powered by")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.7))
                            Text(sourceModelBadgeLabel(for: sourceModel))
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(sourceModelColor(for: sourceModel).opacity(0.8))
                        }
                        .padding(.top, 4)
                    }
                }
            }
            
            // Web search results with confidence and source previews (assistant messages only)
            if !isUser, let webResults = message.webSearchResults, !webResults.results.isEmpty {
                webSearchResultsView(webResults: webResults, confidence: message.webSearchConfidence ?? webResults.confidence)
            }
            
            // Chart visualization (for reflection responses)
            if !isUser, let chartData = message.chartData {
                ReflectionChartView(chartData: chartData)
                    .padding(.top, 8)
            } else if !isUser, let chartCollection = message.chartCollection {
                ChartCollectionView(collection: chartCollection)
                    .padding(.top, 8)
            }
            
            if isUser,
               let docSummary = message.documentSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
               !docSummary.isEmpty {
                Text("Aurora summarized: \(truncatedSummary(docSummary))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Action buttons inside the message
            if !isSystemMessage {
                HStack(spacing: 8) {
                    if isUser {
                        Button(action: {
                            editText = message.content ?? ""
                            isEditing = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil")
                                    .font(.caption2)
                                Text("Edit")
                                    .font(.caption2)
                            }
                            .foregroundColor(isUser ? .white.opacity(0.8) : .secondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: copyMessage) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption2)
                                Text("Copy")
                                    .font(.caption2)
                            }
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            onResend?(message)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.caption2)
                                Text("Resend")
                                    .font(.caption2)
                            }
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .opacity(canResend ? 1 : 0.4)
                        .disabled(!canResend || onResend == nil)
                    }
                }
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
            }
            
            // Thinking view (collapsible) for assistant messages - only show when thinking was actually enabled
            if !isUser, message.wasThinking, let thinking = message.thinkingContent, !thinking.isEmpty {
                ThinkingView(thinkingContent: thinking)
                    .padding(.top, 8)
            }
            
            // Model badge at bottom
            if !isUser, let modelUsed = message.modelUsed, !modelUsed.isEmpty {
                ModelBadge(modelName: modelUsed)
                    .padding(.top, 8)
            }
            
            // Powered by indicator for document summaries
            if !isUser,
               let sourceModel = message.documentSourceModel,
               !sourceModel.isEmpty,
               message.documentFileName != nil {
                HStack(spacing: 4) {
                    Text("Powered by")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(sourceModelBadgeLabel(for: sourceModel))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(sourceModelColor(for: sourceModel))
                }
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(messageBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isUser ? Color.white.opacity(0.2) : Color.white.opacity(0.15),
                    lineWidth: 1
                )
        )
    }
    
    // MARK: - Edit Message View
    
    private var editMessageView: some View {
        VStack(alignment: .trailing, spacing: 8) {
            TextEditor(text: $editText)
                .font(.body)
                .frame(minHeight: 60)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.kosmicBlue, lineWidth: 2)
                )
            
            HStack(spacing: 8) {
                Button("Cancel") {
                    isEditing = false
                    editText = ""
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                
                Button("Submit") {
                    submitEdit()
                }
                .buttonStyle(.borderedProminent)
                .disabled(editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.kosmicBlue.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Copied Toast
    
    private var copiedToastView: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.kosmicGreen)
            Text("Copied!")
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .shadow(radius: 4)
    }
    
    // MARK: - Mention Styling
    
    @ViewBuilder
    private func styledUserMessage(_ content: String) -> some View {
        if #available(macOS 12.0, *) {
            let mentions = MentionParser.parseMentions(from: content)
            if mentions.isEmpty {
                // No mentions, render normally
                Text(content)
                    .foregroundColor(.white)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(6)
                    .lineLimit(nil)
                    .tint(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // Has mentions, style them
                let attributedString = createAttributedStringWithMentions(content, mentions: mentions, isUser: true)
                Text(attributedString)
                    .foregroundColor(.white)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(6)
                    .lineLimit(nil)
                    .tint(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Text(content)
                .foregroundColor(.white)
                .textSelection(.enabled)
                .multilineTextAlignment(.leading)
                .lineSpacing(6)
                .lineLimit(nil)
                .tint(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    @available(macOS 12.0, *)
    private func createAttributedStringWithMentions(_ content: String, mentions: [MentionMatch], isUser: Bool) -> AttributedString {
        var attributedString = AttributedString(content)
        
        // Only style mentions in user messages - don't highlight @web in Aurora's responses
        guard isUser else {
            // For assistant messages, don't style @web mentions at all
            return attributedString
        }
        
        // Style mentions
        for mention in mentions.reversed() { // Reverse to maintain indices
            let range = Range(mention.range, in: content)!
            let mentionRange = Range(range, in: attributedString)!
            
            // Check if this is a @web mention
            let isWebMention = MentionParser.isWebSearchMention(mention)
            
            // Style the mention
            var mentionAttributes = AttributeContainer()
            mentionAttributes.font = .system(size: NSFont.systemFontSize(for: .regular), weight: isWebMention ? .semibold : .medium)
            
            if isWebMention {
                // Special styling for @web mentions - use soft cyan/teal instead of orange
                let webColor = Color(red: 0.20, green: 0.76, blue: 0.86) // Soft cyan/teal
                mentionAttributes.foregroundColor = webColor.opacity(0.9)
                mentionAttributes.backgroundColor = webColor.opacity(0.25)
            } else {
                mentionAttributes.foregroundColor = Color.white
                mentionAttributes.backgroundColor = Color.white.opacity(0.2)
            }
            
            attributedString[mentionRange].mergeAttributes(mentionAttributes)
            
            // For @web mentions, also style the query text that follows
            if isWebMention {
                if let query = MentionParser.extractWebSearchQuery(from: content, mention: mention), !query.isEmpty {
                    let queryStart = mention.range.location + mention.range.length
                    let queryEnd = min(queryStart + query.count, content.count)
                    if queryEnd > queryStart, let queryRange = Range(NSRange(location: queryStart, length: queryEnd - queryStart), in: content) {
                        if let queryAttributedRange = Range(queryRange, in: attributedString) {
                            var queryAttributes = AttributeContainer()
                            queryAttributes.font = .system(size: NSFont.systemFontSize(for: .regular), weight: .medium)
                            let webColor = Color(red: 0.20, green: 0.76, blue: 0.86) // Soft cyan/teal
                            queryAttributes.foregroundColor = webColor.opacity(0.8)
                            attributedString[queryAttributedRange].mergeAttributes(queryAttributes)
                        }
                    }
                }
            }
        }
        
        return attributedString
    }
    
    @available(macOS 12.0, *)
    private func applyMentionStyling(to attributedString: AttributedString, originalText: String, isUser: Bool) -> AttributedString {
        var styled = attributedString
        let mentions = MentionParser.parseMentions(from: originalText)
        
        // Only style mentions in user messages - don't highlight @web in Aurora's responses
        guard isUser else {
            // For assistant messages, don't style @web mentions at all
            return styled
        }
        
        // Style mentions
        for mention in mentions.reversed() { // Reverse to maintain indices
            let range = Range(mention.range, in: originalText)!
            if let mentionRange = Range(range, in: styled) {
                // Check if this is a @web mention
                let isWebMention = MentionParser.isWebSearchMention(mention)
                
                // Style the mention
                var mentionAttributes = AttributeContainer()
                mentionAttributes.font = .system(size: NSFont.systemFontSize(for: .regular), weight: isWebMention ? .semibold : .medium)
                
                if isWebMention {
                    // Special styling for @web mentions - use soft cyan/teal instead of orange
                    let webColor = Color(red: 0.20, green: 0.76, blue: 0.86) // Soft cyan/teal
                    mentionAttributes.foregroundColor = webColor.opacity(0.9)
                    mentionAttributes.backgroundColor = webColor.opacity(0.25)
                } else {
                    mentionAttributes.foregroundColor = Color.white
                    mentionAttributes.backgroundColor = Color.white.opacity(0.2)
                }
                
                styled[mentionRange].mergeAttributes(mentionAttributes)
                
                // For @web mentions, also style the query text that follows
                if isWebMention {
                    if let query = MentionParser.extractWebSearchQuery(from: originalText, mention: mention), !query.isEmpty {
                        let queryStart = mention.range.location + mention.range.length
                        let queryEnd = min(queryStart + query.count, originalText.count)
                        if queryEnd > queryStart, let queryRange = Range(NSRange(location: queryStart, length: queryEnd - queryStart), in: originalText) {
                            if let queryAttributedRange = Range(queryRange, in: styled) {
                                var queryAttributes = AttributeContainer()
                                queryAttributes.font = .system(size: NSFont.systemFontSize(for: .regular), weight: .medium)
                                let webColor = Color(red: 0.20, green: 0.76, blue: 0.86) // Soft cyan/teal
                                queryAttributes.foregroundColor = webColor.opacity(0.8)
                                styled[queryAttributedRange].mergeAttributes(queryAttributes)
                            }
                        }
                    }
                }
            }
        }
        
        return styled
    }
    
    // MARK: - Helper Methods
    
    /// Normalize spacing to ensure proper rendering - fixes collapsed spaces after punctuation
    private func normalizeSpacing(_ text: String) -> String {
        var normalized = text
        
        // Split into lines to handle line-by-line spacing issues
        let lines = normalized.components(separatedBy: .newlines)
        var processedLines: [String] = []
        
        for line in lines {
            var processedLine = line
            
            // Ensure space after punctuation marks (periods, colons, exclamation, question marks)
            // but only if followed by a non-whitespace, non-newline, non-markdown character
            // This won't match periods at the end of lines, which is correct
            processedLine = processedLine.replacingOccurrences(
                of: #"([\.:!?])([^\s\n\*#])"#,
            with: "$1 $2",
            options: .regularExpression
        )
            
            // Handle em-dashes separately (they should have spaces around them)
            processedLine = processedLine.replacingOccurrences(
                of: #"([^\s])(—)([^\s])"#,
                with: "$1 $2 $3",
                options: .regularExpression
            )
        
        // Ensure space after closing markdown bold markers (**) before text
            processedLine = processedLine.replacingOccurrences(
            of: #"(\*\*)([^\s\n\*])"#,
            with: "$1 $2",
            options: .regularExpression
        )
        
        // Ensure space before opening markdown bold markers (**) after text
            processedLine = processedLine.replacingOccurrences(
            of: #"([^\s\n\*])(\*\*)"#,
            with: "$1 $2",
            options: .regularExpression
        )
        
        // Ensure space after closing markdown bold before a colon (for headers like "**Header:**")
            processedLine = processedLine.replacingOccurrences(
            of: #"(\*\*)(:)"#,
            with: "$1$2",
            options: .regularExpression
        )
        
        // Handle case where text ends with punctuation and a bold header starts
            processedLine = processedLine.replacingOccurrences(
            of: #"([\.:!?])(\*\*[A-Z])"#,
            with: "$1 $2",
            options: .regularExpression
        )
        
            // Fix double spaces after periods (common issue)
            processedLine = processedLine.replacingOccurrences(
                of: #"([\.:!?])\s{2,}"#,
                with: "$1 ",
                options: .regularExpression
            )
            
            // Clean up any triple+ spaces (but preserve double spaces which might be intentional for markdown)
            processedLine = processedLine.replacingOccurrences(
                of: "   +",
                with: "  ",
                options: .regularExpression
            )
            
            // Remove trailing spaces from this line (but preserve the line itself)
            processedLine = processedLine.trimmingCharacters(in: .whitespaces)
            
            processedLines.append(processedLine)
        }
        
        // Join lines back together, preserving line breaks
        normalized = processedLines.joined(separator: "\n")
        
        // Final cleanup: remove excessive consecutive newlines (more than 2)
        normalized = normalized.replacingOccurrences(
            of: "\n\n\n+",
            with: "\n\n",
            options: .regularExpression
        )
        
        // Trim only the very beginning and end of the entire text (not individual lines)
        normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return normalized
    }
    
    private func splitIntoSections(_ content: String) -> [String] {
        // Split content by bold headers to create distinct sections with spacing
        let lines = content.components(separatedBy: .newlines)
        var sections: [String] = []
        var currentSection = ""
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Check if this line is a bold header (section marker)
            let isBoldHeader = trimmed.hasPrefix("**") && trimmed.dropFirst(2).contains("**")
            let isMarkdownHeader = trimmed.hasPrefix("#") && trimmed.contains(" ")
            
            if (isBoldHeader || isMarkdownHeader) && !currentSection.isEmpty {
                // Start new section - save current and start fresh
                sections.append(currentSection.trimmingCharacters(in: .whitespacesAndNewlines))
                currentSection = line
            } else {
                // Add to current section
                if !currentSection.isEmpty {
                    currentSection += "\n" + line
                } else {
                    currentSection = line
                }
            }
        }
        
        // Add final section
        if !currentSection.isEmpty {
            sections.append(currentSection.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        return sections.isEmpty ? [content] : sections
    }
    
    private func documentMetadataLine(for message: AIMessage) -> String {
        var parts: [String] = []
        if let mime = message.documentMimeType, !mime.isEmpty {
            parts.append(mime)
        }
        if let urlString = message.documentSourceURL,
           let url = URL(string: urlString) {
            let host = url.host ?? url.absoluteString
            parts.append(host)
        }
        if parts.isEmpty {
            parts.append("Uploaded document")
        }
        return parts.joined(separator: " • ")
    }
    
    private func truncatedSummary(_ summary: String, limit: Int = 220) -> String {
        guard summary.count > limit else { return summary }
        let index = summary.index(summary.startIndex, offsetBy: limit)
        return String(summary[..<index]) + "…"
    }
    
    // MARK: - Actions
    
    private func submitEdit() {
        let trimmedText = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        onEdit?(message, trimmedText)
        isEditing = false
        editText = ""
    }
    
    private func copyMessage() {
        let content = message.content ?? ""
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        
        withAnimation {
            showCopiedToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedToast = false
            }
        }
        
        onCopy?(content)
    }
    
    // MARK: - Source Model Helpers
    
    private func sourceModelBadgeLabel(for sourceModel: String) -> String {
        switch sourceModel.lowercased() {
        case "ollama":
            return "Ollama"
        case "applellm":
            return "Apple Intelligence"
        case "offline":
            return "Offline"
        default:
            return sourceModel
        }
    }
    
    private func sourceModelColor(for sourceModel: String) -> Color {
        switch sourceModel.lowercased() {
        case "ollama":
            return .kosmicBlue
        case "applellm":
            return .kosmicPurple
        case "offline":
            return .orange
        default:
            return .secondary
        }
    }
    
    // MARK: - Web Search Results View
    
    @ViewBuilder
    private func webSearchResultsView(webResults: WebSearchResults, confidence: Double) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Confidence meter
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.caption)
                    .foregroundColor(.kosmicBlue)
                
                Text("Web Search Confidence")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Confidence bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(confidenceColor(for: confidence))
                            .frame(width: geometry.size.width * CGFloat(confidence), height: 6)
                    }
                }
                .frame(width: 80, height: 6)
                
                Text("\(Int(confidence * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.05))
            )
            
            // Source previews
            VStack(alignment: .leading, spacing: 8) {
                Text("Sources")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                ForEach(Array(webResults.results.prefix(3).enumerated()), id: \.offset) { index, result in
                    sourcePreviewCard(result: result, index: index)
                }
            }
        }
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private func sourcePreviewCard(result: WebSearchItem, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                // Source number badge
                Text("\(index + 1)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(
                        Circle()
                            .fill(Color.kosmicBlue)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    // Title (clickable link)
                    if let url = URL(string: result.url) {
                        Link(destination: url) {
                            Text(result.title)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.kosmicBlue)
                                .lineLimit(2)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(result.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                    
                    // URL
                    Text(result.url)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .textSelection(.enabled)
                    
                    // Snippet if available
                    if let snippet = result.snippet, !snippet.isEmpty {
                        Text(snippet)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .padding(.top, 2)
                    }
                }
                
                Spacer()
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func confidenceColor(for confidence: Double) -> Color {
        if confidence >= 0.7 {
            return .kosmicGreen
        } else if confidence >= 0.4 {
            return Color(red: 0.20, green: 0.76, blue: 0.86) // Soft cyan/teal
        } else {
            return .orange.opacity(0.7)
        }
    }
}

// MARK: - Thinking View

struct ThinkingView: View {
    let thinkingContent: String
    @State private var isExpanded = false
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ScrollView {
                Text(thinkingContent)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(maxHeight: 200)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.caption2)
                    .foregroundColor(.kosmicBlue)
                Text("Thinking")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Model Badge

struct ModelBadge: View {
    let modelName: String
    
    private var badgeColor: Color {
        switch modelName.lowercased() {
        case "qwen3":
            return .kosmicPurple
        case "granite3":
            return .orange
        case "gemini":
            return Color(red: 0.20, green: 0.76, blue: 0.86) // Soft cyan/teal
        default:
            return .secondary
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Text(modelName)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(badgeColor.opacity(0.9))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
        .background(
            Capsule()
                .fill(badgeColor.opacity(0.15))
        )
        .overlay(
            Capsule()
                .stroke(badgeColor.opacity(0.3), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

#Preview {
    VStack {
        MessageBubble(
            message: AIMessage(role: "user", content: "Generate a hook for my social media post"),
            onEdit: { _, _ in },
            onCopy: { _ in },
            onResend: { _ in },
            canResend: false
        )
        MessageBubble(
            message: AIMessage(role: "assistant", content: "Here are some engaging hook ideas:\n\n💡 Ever wondered...\n🚀 This one simple trick..."),
            onEdit: { _, _ in },
            onCopy: { _ in },
            onResend: { _ in },
            canResend: true
        )
    }
    .environmentObject(GlassColorSystem())
}
