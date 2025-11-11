//
//  MentionTextEditor.swift
//  Cloutmate
//
//  Wrapper around MentionInputField for use in text areas throughout the app
//  Handles binding to model properties and updates linkedEntityIds/backlinks
//

import SwiftUI
import SwiftData
import CloutmateShared

struct MentionTextEditor: View {
    @Binding var text: String
    var placeholder: String = "Type here..."
    var onSubmit: (() -> Void)? = nil
    var excludeObjectId: UUID? = nil // ID of object to exclude from autocomplete
    var excludeObjectType: ObjectType? = nil // Type of object to exclude
    
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isFocused: Bool
    @State private var linkedContext = LinkedContext()
    @State private var resolvedMentions: [ResolvedMention] = []
    @State private var removedMentionIds: Set<UUID> = []
    @State private var isTypingMention = false // Track if user is actively typing a mention
    
    // Callback to update model's linkedEntityIds/backlinks
    var onMentionsChanged: (([UUID], [String]) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MentionInputField(
                text: $text,
                isFocused: $isFocused,
                placeholder: placeholder,
                onSubmit: {
                    onSubmit?()
                },
                linkedContext: $linkedContext,
                isEnabled: true,
                excludeObjectId: excludeObjectId,
                excludeObjectType: excludeObjectType,
                onLinkingStateChanged: { linking in
                    isTypingMention = linking
                }
            )
            
            if isTypingMention {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Linking…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                )
                .accessibilityLabel("Linking in progress")
            }
            
            // Show preview cards below the editor for CONFIRMED linked mentions only
            // Don't show while user is actively typing "@" or a mention
            // But show them if there are resolved mentions, even if user is typing elsewhere
            if !resolvedMentions.isEmpty {
                // Only hide if user is actively typing a NEW mention (not an existing one)
                let shouldShow = !isTypingMention
                
                if shouldShow {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(resolvedMentions.filter { !removedMentionIds.contains($0.id) }, id: \.id) { mention in
                            MentionPreviewCardEditor(
                                mention: mention,
                                onRemove: {
                                    removeMention(mention)
                                },
                                onTap: {
                                    navigateToMention(mention)
                                }
                            )
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .onChange(of: text) { _, newValue in
            // Update mentions first to get resolved mentions
            updateMentions(from: newValue)
            
            // Check if user is actively typing a NEW mention
            // Only hide preview cards if actively typing "@" AND there are no resolved mentions yet
            
            // Check if text ends with "@" (user is typing a new mention)
            let endsWithAt = newValue.hasSuffix("@")
            
            // Check if there's an unresolved mention (plain @name that hasn't been converted to structured format yet)
            let mentions = MentionParser.parseMentions(from: newValue)
            let hasUnresolvedMention = mentions.contains { mention in
                mention.structuredType == nil && !mention.mentionText.isEmpty && mention.mentionText.lowercased() != "web"
            }
            
            // User is actively typing if:
            // 1. Text ends with "@" (just typed @)
            // 2. There's an unresolved mention AND no resolved mentions yet (transition period)
            // If there are resolved mentions, show preview cards even if typing (they're for existing mentions)
            let hasResolvedMentions = !resolvedMentions.isEmpty
            isTypingMention = endsWithAt || (hasUnresolvedMention && !hasResolvedMentions)
        }
        .onAppear {
            updateMentions(from: text)
        }
    }
    
    private func updateMentions(from text: String) {
        let resolved = MentionService.shared.resolveAllMentions(
            from: text,
            modelContext: modelContext
        )
        
        resolvedMentions = resolved
        
        let ids = resolved.map { $0.id }
        let types = resolved.map { $0.type.rawValue }
        
        onMentionsChanged?(ids, types)
        
        // Convert plain mentions to structured format when user finishes typing
        // Only convert when not actively editing (debounced)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let structuredText = MentionService.shared.convertToStructuredFormat(
                text: text,
                modelContext: modelContext
            )
            
            if structuredText != text && self.text == text {
                // Update text with structured format (preserves user's display names in UI)
                self.text = structuredText
            }
        }
    }
    
    private func removeMention(_ mention: ResolvedMention) {
        removedMentionIds.insert(mention.id)
        
        // Remove the mention from text
        let structuredMention = MentionParser.toStructuredFormat(type: mention.type, id: mention.id)
        let displayMention = "@\(mention.displayName)"
        let displayMentionWithTerminator = displayMention + MentionParser.mentionTerminator
        
        // Remove structured format
        text = text.replacingOccurrences(of: structuredMention, with: "")
        // Also remove display format if present
        text = text.replacingOccurrences(of: displayMentionWithTerminator, with: "")
        text = text.replacingOccurrences(of: displayMention, with: "")
        // Clean up extra spaces
        text = text.replacingOccurrences(of: "  ", with: " ")
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Update mentions
        updateMentions(from: text)
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
}

