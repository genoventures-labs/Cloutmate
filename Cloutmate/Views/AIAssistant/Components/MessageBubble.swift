//
//  MessageBubble.swift
//  Cloutmate
//
//  Glass-themed Message Bubble
//

import SwiftUI
import AppKit

struct MessageBubble: View {
    let message: AIMessage
    let onEdit: ((AIMessage, String) -> Void)?
    let onCopy: ((String) -> Void)?
    
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
            // Message text with markdown rendering
            if let content = message.content, !content.isEmpty {
                if isUser {
                    Text(content)
                        .foregroundColor(.white)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(6)
                        .lineLimit(nil)
                        .tint(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if #available(macOS 12.0, *) {
                    // Split content into sections for proper spacing
                    let sections = splitIntoSections(content)
                    
                    if sections.count > 1 {
                        // Multiple sections - render with explicit spacing
                        ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                            if let attributedSection = try? AttributedString(
                                markdown: section,
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
                                        .tint(.kosmicBlue)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    } else {
                        // Single section - render normally
                        if let attributedContent = try? AttributedString(
                            markdown: content,
                            options: AttributedString.MarkdownParsingOptions(
                                allowsExtendedAttributes: true,
                                interpretedSyntax: .full
                            )
                        ) {
                            Text(attributedContent)
                                .foregroundColor(isSystemMessage ? .secondary : .primary)
                                .textSelection(.enabled)
                                .multilineTextAlignment(.leading)
                                .lineSpacing(6)
                                .lineLimit(nil)
                                .allowsTightening(false)
                                .minimumScaleFactor(1.0)
                                .tint(.kosmicBlue)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            // Fallback to plain text if markdown parsing fails
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
            
            // Chart visualization (for reflection responses)
            if !isUser, let chartData = message.chartData {
                ReflectionChartView(chartData: chartData)
                    .padding(.top, 8)
            } else if !isUser, let chartCollection = message.chartCollection {
                ChartCollectionView(collection: chartCollection)
                    .padding(.top, 8)
            }
            
            // Action buttons inside the message
            if !isSystemMessage {
                HStack(spacing: 8) {
                    if isUser {
                        // Edit button for user messages
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
                        // Copy button for AI messages
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
                    }
                }
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
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
    
    // MARK: - Helper Methods
    
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
        
        // Show copied toast
        withAnimation {
            showCopiedToast = true
        }
        
        // Hide after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedToast = false
            }
        }
        
        // Call callback if provided
        onCopy?(content)
    }
}

#Preview {
    VStack {
        MessageBubble(
            message: AIMessage(role: "user", content: "Generate a hook for my social media post"),
            onEdit: { _, _ in },
            onCopy: { _ in }
        )
        MessageBubble(
            message: AIMessage(role: "assistant", content: "Here are some engaging hook ideas:\n\n💡 Ever wondered...\n🚀 This one simple trick..."),
            onEdit: { _, _ in },
            onCopy: { _ in }
        )
    }
    .environmentObject(GlassColorSystem())
}
