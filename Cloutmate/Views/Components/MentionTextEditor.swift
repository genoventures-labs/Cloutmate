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
    
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isFocused: Bool
    @State private var linkedContext = LinkedContext()
    
    // Callback to update model's linkedEntityIds/backlinks
    var onMentionsChanged: (([UUID], [String]) -> Void)?
    
    var body: some View {
        MentionInputField(
            text: $text,
            isFocused: $isFocused,
            placeholder: placeholder,
            onSubmit: {
                onSubmit?()
            },
            linkedContext: $linkedContext,
            isEnabled: true
        )
        .onChange(of: text) { _, newValue in
            updateMentions(from: newValue)
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
}

