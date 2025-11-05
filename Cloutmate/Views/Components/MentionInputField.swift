//
//  MentionInputField.swift
//  Cloutmate
//
//  Enhanced TextField with @ mention detection and autocomplete
//

import SwiftUI
import SwiftData

struct MentionInputField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    var placeholder: String = "Type here..."
    var onSubmit: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @State private var showAutocomplete = false
    @State private var autocompleteResults: [WorkspaceObjectResult] = []
    @State private var selectedIndex = 0
    @State private var currentMention: String? = nil
    @State private var searchDebounceTask: _Concurrency.Task<Void, Never>?
    @Binding var linkedContext: LinkedContext
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Text input
            TextField(placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    handleTextChange(newValue)
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        withAnimation {
                            showAutocomplete = false
                        }
                    }
                }
                .onKeyPress(.return) {
                    if showAutocomplete && !autocompleteResults.isEmpty {
                        selectCurrentResult()
                        return .handled
                    }
                    onSubmit()
                    return .handled
                }
                .onKeyPress(.escape) {
                    if showAutocomplete {
                        withAnimation {
                            showAutocomplete = false
                        }
                        return .handled
                    }
                    return .ignored
                }
                .onKeyPress(.upArrow) {
                    if showAutocomplete && !autocompleteResults.isEmpty {
                        selectedIndex = max(0, selectedIndex - 1)
                        return .handled
                    }
                    return .ignored
                }
                .onKeyPress(.downArrow) {
                    if showAutocomplete && !autocompleteResults.isEmpty {
                        selectedIndex = min(autocompleteResults.count - 1, selectedIndex + 1)
                        return .handled
                    }
                    return .ignored
                }
            
            // Autocomplete overlay
            if showAutocomplete && !autocompleteResults.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    MentionAutocompleteView(
                        results: autocompleteResults,
                        onSelect: { result in
                            selectResult(result)
                        },
                        selectedIndex: $selectedIndex
                    )
                    .frame(maxWidth: 400)
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    private func handleTextChange(_ newValue: String) {
        // Cancel previous debounce task
        searchDebounceTask?.cancel()
        
        // Check if cursor is inside a mention (simplified: check if text ends with @ or @ followed by non-space)
        if let lastAtIndex = newValue.lastIndex(of: "@") {
            let afterAt = String(newValue[newValue.index(after: lastAtIndex)...])
            
            // Check if there's a space or newline after @ (means mention ended)
            if let spaceIndex = afterAt.firstIndex(where: { $0.isWhitespace || $0.isNewline }) {
                currentMention = nil
                withAnimation {
                    showAutocomplete = false
                }
                return
            }
            
            // Extract mention text (everything after @ until end)
            let mentionText = afterAt.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !mentionText.isEmpty {
                currentMention = mentionText
                
                // Debounce search
                searchDebounceTask = _Concurrency.Task {
                    try? await _Concurrency.Task.sleep(nanoseconds: 200_000_000) // 200ms debounce
                    
                    if !_Concurrency.Task.isCancelled {
                        await MainActor.run {
                            performSearch(query: mentionText)
                        }
                    }
                }
                
                withAnimation {
                    showAutocomplete = true
                }
            } else {
                currentMention = nil
                withAnimation {
                    showAutocomplete = false
                }
            }
        } else {
            currentMention = nil
            withAnimation {
                showAutocomplete = false
            }
        }
    }
    
    private func performSearch(query: String) {
        let results = WorkspaceObjectSearchService.shared.search(
            query: query,
            modelContext: modelContext,
            limit: 8
        )
        
        autocompleteResults = results
        selectedIndex = 0
    }
    
    private func selectResult(_ result: WorkspaceObjectResult) {
        guard let mention = currentMention else { return }
        
        // Replace mention in text with selected object name
        let mentionPattern = "@\(mention)"
        if let range = text.range(of: mentionPattern, options: .caseInsensitive) {
            text.replaceSubrange(range, with: "@\(result.title)")
            
            // Add to linked context
            linkedContext.addLinkedObject(
                type: result.type,
                id: result.id,
                mentionText: "@\(result.title)",
                displayName: result.title
            )
        }
        
        // Close autocomplete
        withAnimation {
            showAutocomplete = false
        }
        currentMention = nil
        selectedIndex = 0
    }
    
    private func selectCurrentResult() {
        guard selectedIndex < autocompleteResults.count else { return }
        selectResult(autocompleteResults[selectedIndex])
    }
}

