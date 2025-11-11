//
//  MentionInputField.swift
//  Cloutmate
//
//  Enhanced TextField with @ mention detection and autocomplete
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

// Preference key for tracking text view frame
struct TextViewFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct MentionInputField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    var placeholder: String = "Type here..."
    var onSubmit: () -> Void
    @Binding var linkedContext: LinkedContext
    var isEnabled: Bool = true
    var excludeObjectId: UUID? = nil // ID of object to exclude from autocomplete
    var excludeObjectType: ObjectType? = nil // Type of object to exclude
    var onLinkingStateChanged: ((Bool) -> Void)? = nil // Callback for typing state
    
    @Environment(\.modelContext) private var modelContext
    @State private var showAutocomplete = false
    @State private var autocompleteResults: [WorkspaceObjectResult] = []
    @State private var selectedIndex = 0
    @State private var currentMention: String? = nil
    @State private var currentMentionRange: NSRange? = nil
    @State private var searchDebounceTask: _Concurrency.Task<Void, Never>?
    
    @State private var isMultiLine = false
    @State private var textViewRef: MentionTextView? = nil
    @State private var cursorPosition: CGPoint = .zero
    @State private var activeTabFilter: ObjectType? = nil // Track active tab filter
    @State private var isLinkingConfirmed = false // Track if link was just confirmed
    @State private var isCurrentLinkingState = false // Track linking state for callbacks
    
    var body: some View {
        // Use overlay approach to position autocomplete relative to text view
            MentionNSTextView(
                text: $text,
                isFocused: $isFocused,
                placeholder: placeholder,
                onSubmit: onSubmit,
                onTextChange: handleTextChange,
                onImagePaste: { image in
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("MentionInputImagePaste"),
                                        object: image
                                    )
                },
                showAutocomplete: $showAutocomplete,
                autocompleteResults: $autocompleteResults,
                selectedIndex: $selectedIndex,
                onSelectAutocomplete: selectCurrentResult,
                linkedContext: $linkedContext,
            isEnabled: isEnabled,
            textViewRef: $textViewRef,
            modelContext: modelContext,
            cursorPosition: $cursorPosition
            )
            .allowsHitTesting(true)
        .overlay(alignment: .topLeading) {
            // Autocomplete overlay - positioned below the cursor, outside the editing line
            if showAutocomplete && !autocompleteResults.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear
                        .frame(height: cursorPosition.y + 24)
                    ScrollViewReader { proxy in
                        ScrollView {
                            MentionAutocompleteView(
                                results: autocompleteResults,
                                onSelect: { result in
                                    selectResult(result)
                                },
                                selectedIndex: $selectedIndex,
                                tabFilter: activeTabFilter
                            )
                            .frame(maxWidth: 400)
                            .onChange(of: selectedIndex) { _, newIndex in
                                // Scroll to selected item
                                withAnimation {
                                    proxy.scrollTo(newIndex, anchor: .center)
                                }
                            }
                        }
                        .frame(maxHeight: 300)
                        .offset(x: cursorPosition.x)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .allowsHitTesting(true)
                        .zIndex(1000) // Ensure it's above other content
                    }
                }
            }
        }
    }
    
    private func updateLinkingState(_ linking: Bool) {
        if isCurrentLinkingState != linking {
            isCurrentLinkingState = linking
            onLinkingStateChanged?(linking)
        }
    }
    
    private func handleTextChange(_ newValue: String) {
        // Cancel previous debounce task
        searchDebounceTask?.cancel()
        
        // Get cursor position from text view
        guard let textView = textViewRef else {
            // Fallback: try to find mention at end of text
        if let lastAtIndex = newValue.lastIndex(of: "@") {
            let afterAt = String(newValue[newValue.index(after: lastAtIndex)...])
            // Check if there's a space or newline after @ (means mention ended)
            if let spaceIndex = afterAt.firstIndex(where: { $0.isWhitespace || $0.isNewline }) {
                currentMention = nil
                    currentMentionRange = nil
                withAnimation {
                    showAutocomplete = false
                }
                updateLinkingState(false)
                return
            }
            
                // If afterAt is empty, just "@" was typed - show all objects
                if afterAt.isEmpty {
                    currentMention = ""
                    let nsString = newValue as NSString
                    let atLocation = nsString.range(of: "@", options: .backwards).location
                    if atLocation != NSNotFound {
                        currentMentionRange = NSRange(location: atLocation, length: 1)
                        performSearch(query: "")
                        withAnimation {
                            showAutocomplete = true
                        }
                        updateLinkingState(true)
                        return
                    }
                }
                
            let mentionText = afterAt.trimmingCharacters(in: .whitespacesAndNewlines)
            if !mentionText.isEmpty {
                currentMention = mentionText
                    // Estimate range (from last @ to end)
                    let nsString = newValue as NSString
                    let atLocation = nsString.range(of: "@", options: .backwards).location
                    if atLocation != NSNotFound {
                        currentMentionRange = NSRange(location: atLocation, length: newValue.count - atLocation)
                
                searchDebounceTask = _Concurrency.Task {
                            try? await _Concurrency.Task.sleep(nanoseconds: 200_000_000)
                    if !_Concurrency.Task.isCancelled {
                        await MainActor.run {
                            performSearch(query: mentionText)
                        }
                    }
                }
                        
                        withAnimation {
                            showAutocomplete = true
                        }
                    updateLinkingState(true)
                        return
                    }
                }
            }
            currentMention = nil
            currentMentionRange = nil
            withAnimation {
                showAutocomplete = false
            }
        updateLinkingState(false)
            return
        }
        
        let cursorLocation = textView.selectedRange().location
        
        // Don't show autocomplete if we just confirmed a link
        guard !isLinkingConfirmed else {
            currentMention = nil
            currentMentionRange = nil
            showAutocomplete = false
            updateLinkingState(false)
            return
        }
        
        // Check if cursor is immediately after a structured mention - if so, don't show autocomplete
        // Also check if cursor is after a resolved mention (display name format)
        let textBeforeCursor = String(newValue.prefix(cursorLocation))
        
        // Parse mentions before cursor once (used in multiple places)
        let allMentionsBeforeCursor = MentionParser.parseMentions(from: textBeforeCursor)
        
        if cursorLocation > 0 {
            // Check if we're right after a structured mention pattern (@{type:id})
            if textBeforeCursor.hasSuffix("}") {
                // Might be end of structured mention - check if there's a @{ before it
                if let lastAtIndex = textBeforeCursor.lastIndex(of: "@"),
                   lastAtIndex < textBeforeCursor.endIndex {
                    let afterAt = textBeforeCursor[textBeforeCursor.index(after: lastAtIndex)...]
                    if afterAt.hasPrefix("{") && afterAt.contains(":") {
                        // Cursor is right after a structured mention - don't show autocomplete
                        currentMention = nil
                        currentMentionRange = nil
                        showAutocomplete = false
                        return
                    }
                }
            }
            
            // Before checking for new mentions, verify we're not after a resolved mention
            // Check if there's a resolved mention that ends before or at cursor position
            for mention in allMentionsBeforeCursor.reversed() {
                let resolvedMentionEnd = mention.range.location + mention.range.length
                
                // If cursor is after this mention
                if cursorLocation > resolvedMentionEnd {
                    // Check if this mention is resolved (either structured or can be resolved)
                    var isResolved = mention.structuredType != nil
                    
                    if !isResolved {
                        // Check linkedContext first
                        isResolved = linkedContext.mentionMap[mention.fullText.lowercased()] != nil
                        
                        // Also try to resolve it via MentionService
                        if !isResolved {
                            if let resolved = MentionService.shared.resolveMention(mention, modelContext: modelContext) {
                                isResolved = true
                                // Add to linked context for future reference
                                linkedContext.addLinkedObject(
                                    type: resolved.type,
                                    id: resolved.id,
                                    mentionText: mention.fullText,
                                    displayName: resolved.displayName
                                )
                            }
                        }
                    }
                    
                    if isResolved {
                        // There's a resolved mention before cursor - don't treat subsequent text as mention
                        // Check if there's a space or newline after the mention (normal text follows)
                        if resolvedMentionEnd < textBeforeCursor.count {
                            let charAfterMention = textBeforeCursor[textBeforeCursor.index(textBeforeCursor.startIndex, offsetBy: resolvedMentionEnd)]
                            // If there's a space or we're at the end, it's normal text
                            if charAfterMention.isWhitespace || cursorLocation == textBeforeCursor.count {
                                currentMention = nil
                                currentMentionRange = nil
                                showAutocomplete = false
                                updateLinkingState(false)
                                return
                            }
                        } else {
                            // Mention ends exactly at cursor - normal text mode
                            currentMention = nil
                            currentMentionRange = nil
                            showAutocomplete = false
                            updateLinkingState(false)
                            return
                        }
                    }
                }
            }
        }
        
        // Find mention at cursor position (only if cursor is INSIDE a mention, not after)
        if let mentionInfo = MentionParser.getCurrentMentionInfo(from: newValue, cursorPosition: cursorLocation) {
            // Double-check that cursor is actually inside the mention, not after it
            let foundMentionEnd = mentionInfo.range.location + mentionInfo.range.length
        if cursorLocation > foundMentionEnd {
                // Cursor is after the mention - don't treat as active mention
                currentMention = nil
                currentMentionRange = nil
                showAutocomplete = false
                updateLinkingState(false)
                return
            }
            
            // CRITICAL CHECK: If the mention found includes text after a resolved mention, stop detection
            // This prevents "@Focus Gravity Redo can i type" from being treated as one mention
            // Example: "@Focus Gravity Redo can i type" - if "@Focus Gravity Redo" is resolved,
            // then "can i type" should be normal text, not part of the mention
            
            let foundMentionStart = mentionInfo.range.location
            
            // Parse mentions before cursor to check for resolved ones (reuse if already parsed)
            let mentionsToCheck = allMentionsBeforeCursor
            
            // Check if there's a resolved mention that ends within this mention range
            for resolvedMention in mentionsToCheck {
                // Check if this mention is resolved
                var isResolved = resolvedMention.structuredType != nil
                
                if !isResolved {
                    // Check linkedContext
                    isResolved = linkedContext.mentionMap[resolvedMention.fullText.lowercased()] != nil
                    
                    // Also try to resolve it via MentionService
                    if !isResolved {
                        if let _ = MentionService.shared.resolveMention(resolvedMention, modelContext: modelContext) {
                            isResolved = true
                        }
                    }
                }
                
                if isResolved {
                    let resolvedMentionEndPos = resolvedMention.range.location + resolvedMention.range.length
                    
                    // If resolved mention ends within the found mention range AND cursor is after it
                    if resolvedMentionEndPos >= foundMentionStart && resolvedMentionEndPos < foundMentionEnd && cursorLocation > resolvedMentionEndPos {
                        // The found mention includes text after a resolved mention
                        // This means we're typing normal text after a resolved mention, not a new mention
                        currentMention = nil
                        currentMentionRange = nil
                        showAutocomplete = false
                        updateLinkingState(false)
                        return
                    }
                }
            }
            
            currentMention = mentionInfo.text
            currentMentionRange = mentionInfo.range
            updateLinkingState(true)
            
            // Debounce search (even if mention text is empty, show all objects)
            searchDebounceTask = _Concurrency.Task {
                try? await _Concurrency.Task.sleep(nanoseconds: 200_000_000) // 200ms debounce
                
                if !_Concurrency.Task.isCancelled {
                    await MainActor.run {
                        // Double-check we're still not in confirmation state
                        guard !self.isLinkingConfirmed else { return }
                        performSearch(query: mentionInfo.text)
                        // Update cursor position when showing autocomplete
                        if let textView = self.textViewRef {
                            self.updateCursorPosition(textView: textView)
                        }
                    }
                }
            }
            
            // Update cursor position immediately
            updateCursorPosition(textView: textView)
            
            withAnimation {
                showAutocomplete = true
            }
            updateLinkingState(true)
        } else {
            // Check if cursor is right after "@" (no text yet)
            if textBeforeCursor.hasSuffix("@") {
                // Just typed "@" - show all objects
                currentMention = ""
                // Estimate range (just the "@" symbol)
                let atLocation = textBeforeCursor.count - 1
                currentMentionRange = NSRange(location: atLocation, length: 1)
                
                // Update cursor position
                updateCursorPosition(textView: textView)
                
                // Show all objects immediately
                performSearch(query: "")
                
                withAnimation {
                    showAutocomplete = true
                }
                updateLinkingState(true)
            } else {
                // Check if space was just typed after a mention (hide autocomplete)
                if cursorLocation > 0 {
                    let charBeforeCursor = String(newValue[newValue.index(newValue.startIndex, offsetBy: cursorLocation - 1)])
                    if charBeforeCursor == " " && showAutocomplete {
                        // Space was typed - check if there was a mention immediately before it
                        let textBeforeSpace = String(newValue.prefix(cursorLocation - 1))
                        
                        // Check for structured mentions (@{type:id}) at the end
                        if textBeforeSpace.hasSuffix("}") {
                            // Might be end of structured mention - check if there's a @ before it
                            if let lastAtIndex = textBeforeSpace.lastIndex(of: "@"),
                               lastAtIndex < textBeforeSpace.endIndex {
                                let afterAt = textBeforeSpace[textBeforeSpace.index(after: lastAtIndex)...]
                                if afterAt.hasPrefix("{") {
                                    // Structured mention ends right before space - hide autocomplete
                                    withAnimation {
                                        showAutocomplete = false
                                    }
                                    currentMention = nil
                                    currentMentionRange = nil
                                    updateLinkingState(false)
                                    return
                                }
                            }
                        }
                        
                        // Check for plain mentions at the end
                        let mentions = MentionParser.parseMentions(from: textBeforeSpace)
                        if let lastMention = mentions.last,
                           lastMention.range.location + lastMention.range.length == textBeforeSpace.count {
                            // Plain mention ends right before space - hide autocomplete
                            withAnimation {
                                showAutocomplete = false
                            }
                            currentMention = nil
                            currentMentionRange = nil
                            updateLinkingState(false)
                            return
                        }
                    }
                }
                
                // If autocomplete is showing but we're not in a mention context, hide it
                if showAutocomplete {
                    // Only hide if we're not actively typing a mention
                    if currentMention == nil && currentMentionRange == nil {
                        withAnimation {
                            showAutocomplete = false
                        }
                        updateLinkingState(false)
                    }
                }
                
                currentMention = nil
                currentMentionRange = nil
                updateLinkingState(false)
            }
        }
    }
    
    private func performSearch(query: String) {
        // Check for tab filter in query (e.g., "@tasks", "@projects")
        let (results, tabFilter) = WorkspaceObjectSearchService.shared.searchWithTabFilter(
            query: query,
            modelContext: modelContext,
            limit: 20
        )
        
        // Update active tab filter
        activeTabFilter = tabFilter
        
        // Filter out the current object being edited
        var filteredResults = results
        if let excludeId = excludeObjectId, let excludeType = excludeObjectType {
            filteredResults = results.filter { result in
                !(result.id == excludeId && result.type == excludeType)
            }
        }
        
        var seenIds = Set<UUID>()
        autocompleteResults = filteredResults.filter { result in
            if seenIds.contains(result.id) {
                return false
            }
            seenIds.insert(result.id)
            return true
        }
        selectedIndex = 0
    }
    
    private func updateCursorPosition(textView: MentionTextView) {
        let selectedRange = textView.selectedRange()
        guard selectedRange.location != NSNotFound else {
            cursorPosition = .zero
            return
        }
        
        // Get the rect for the cursor position
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            cursorPosition = .zero
            return
        }
        
        // Get the glyph range for the selected range
        let glyphRange = layoutManager.glyphRange(forCharacterRange: selectedRange, actualCharacterRange: nil)
        
        // Get the bounding rect for the glyphs
        let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        
        // Convert to view coordinates (bottom-left of the character)
        var point = rect.origin
        point.y += rect.height
        
        // Account for text container insets
        point.x += textView.textContainerInset.width
        point.y += textView.textContainerInset.height
        
        // Store relative to text view origin
        cursorPosition = point
    }
    
    private func selectResult(_ result: WorkspaceObjectResult) {
        guard let mention = currentMention else { return }
        
        // Insert display name (user-friendly) instead of structured format
        let displayMention = "@\(result.title)\(MentionParser.mentionTerminator)"
        
        // Try to use text view directly if available, otherwise fallback to text binding
        if let textView = textViewRef, let mentionRange = currentMentionRange {
            // Replace mention in NSTextView directly with display name
            let nsRange = NSRange(location: mentionRange.location, length: mentionRange.length)
            if nsRange.location + nsRange.length <= textView.string.count {
                // Temporarily disable delegate to prevent recursive updates
                let originalDelegate = textView.delegate
                textView.delegate = nil
                
                textView.replaceCharacters(in: nsRange, with: displayMention)
                
                // Move cursor after the inserted mention
                let newCursorPosition = nsRange.location + displayMention.count
                textView.setSelectedRange(NSRange(location: newCursorPosition, length: 0))
                
                // Re-enable delegate
                textView.delegate = originalDelegate
                
                // Get the display text and convert to structured format for storage
                let displayText = textView.string
                let structuredText = MentionService.shared.convertToStructuredFormat(
                    text: displayText,
                    modelContext: modelContext
                )
                
                // Update text binding with structured format
                text = structuredText
                
                // Update styling with display text (this will properly style the mention and clear styling for subsequent text)
                textView.updateAttributedText(displayText, modelContext: modelContext)
                
                // Force update cursor position to ensure we're outside the mention
                DispatchQueue.main.async {
                    self.updateCursorPosition(textView: textView)
                }
                
                // Don't call handleTextChange here - it will be called by textDidChange delegate
                // This prevents re-opening autocomplete after linking
            }
        } else {
            // Fallback: update text binding directly
        let mentionPattern = "@\(mention)"
                if let range = text.range(of: mentionPattern, options: .caseInsensitive) {
                text.replaceSubrange(range, with: displayMention)
                // Convert to structured format
                let structuredText = MentionService.shared.convertToStructuredFormat(
                    text: text,
                    modelContext: modelContext
                )
                text = structuredText
                handleTextChange(structuredText)
            }
        }
            
            // Add to linked context
        let structuredMention = MentionParser.toStructuredFormat(type: result.type, id: result.id)
            linkedContext.addLinkedObject(
                type: result.type,
                id: result.id,
            mentionText: structuredMention,
                displayName: result.title
            )
        
        // Mark link as confirmed and close autocomplete IMMEDIATELY
        // This prevents any further mention detection from re-opening it
        isLinkingConfirmed = true
        showAutocomplete = false
        currentMention = nil
        currentMentionRange = nil
        selectedIndex = 0
        activeTabFilter = nil
        updateLinkingState(false)
        
        // Reset confirmation flag after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isLinkingConfirmed = false
        }
    }
    
    private func selectCurrentResult() {
        guard selectedIndex < autocompleteResults.count else { return }
        selectResult(autocompleteResults[selectedIndex])
    }
}

// MARK: - NSTextView-based Input

struct MentionNSTextView: NSViewRepresentable {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    var placeholder: String
    var onSubmit: () -> Void
    var onTextChange: (String) -> Void
    var onImagePaste: (NSImage) -> Void
    @Binding var showAutocomplete: Bool
    @Binding var autocompleteResults: [WorkspaceObjectResult]
    @Binding var selectedIndex: Int
    var onSelectAutocomplete: () -> Void
    @Binding var linkedContext: LinkedContext
    var isEnabled: Bool = true
    @Binding var textViewRef: MentionTextView?
    var modelContext: ModelContext
    @Binding var cursorPosition: CGPoint
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        // Create text storage and container explicitly
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        
        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        textContainer.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)
        
        // Create text view with explicit text container
        let textView = MentionTextView(frame: .zero, textContainer: textContainer)
        
        // CRITICAL: Set delegate BEFORE any other setup
        textView.delegate = context.coordinator
        
        // Basic setup
        textView.isRichText = true
        textView.importsGraphics = false
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        textView.drawsBackground = false
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .regular))
        textView.textColor = NSColor.labelColor
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 36)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.backgroundColor = NSColor.clear
        
        // CRITICAL: Set editable state
        textView.isEditable = isEnabled
        textView.isSelectable = isEnabled
        textView.allowsUndo = true
        
        // Set initial text - convert structured format to display names for editing
        textView.linkedContext = linkedContext
        if !text.isEmpty {
            // Convert structured mentions to display names for editing
            let displayText = MentionService.shared.convertToDisplayNames(
                text: text,
                modelContext: modelContext
            )
            textView.string = displayText
            textView.updateAttributedText(displayText, modelContext: modelContext)
        }
        
        // Set up callbacks
        textView.onSubmit = onSubmit
        textView.showAutocomplete = { self.showAutocomplete }
        textView.autocompleteResults = { self.autocompleteResults }
        textView.selectedIndex = { self.selectedIndex }
        textView.onSelectAutocomplete = onSelectAutocomplete
        textView.onUpdateSelectedIndex = { newIndex in
            DispatchQueue.main.async {
                self.selectedIndex = newIndex
            }
        }
        
        // Set placeholder
        if text.isEmpty {
            textView.setPlaceholder(placeholder)
        }
        
        // Enable proper arrow key navigation
        textView.allowsDocumentBackgroundColorChange = false
        
        // Set autoresizing mask
        textView.autoresizingMask = [.width]
        
        // Ensure text view can receive events
        textView.isHidden = false
        textView.alphaValue = 1.0
        
        // Create scroll view
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.documentView = textView
        scrollView.hasHorizontalScroller = false
        scrollView.verticalScrollElasticity = .automatic
        scrollView.horizontalScrollElasticity = .none
        scrollView.scrollerStyle = .overlay
        
        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        
        // Store text view reference
        DispatchQueue.main.async {
            self.textViewRef = textView
        }
        
        // Try to make text view first responder after a short delay
        DispatchQueue.main.async {
            if self.isFocused && self.isEnabled {
                scrollView.window?.makeFirstResponder(textView)
            }
        }
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = context.coordinator.textView else { return }
        
        // Update text view reference
        DispatchQueue.main.async {
            self.textViewRef = textView
        }
        
        // Update linked context
        textView.linkedContext = linkedContext
        
        // Only update text if it changed externally AND we're not currently editing
        // (to avoid overwriting user input while typing)
        let isCurrentlyFirstResponder = nsView.window?.firstResponder === textView
        if !isCurrentlyFirstResponder && textView.string != text {
            // Text changed externally - convert structured format to display names
            let displayText = MentionService.shared.convertToDisplayNames(
                text: text,
                modelContext: modelContext
            )
            let selectedRange = textView.selectedRange()
            textView.string = displayText
            textView.updateAttributedText(displayText, modelContext: modelContext)
            
            // Restore cursor position or move to end
            if selectedRange.location <= displayText.count {
                textView.setSelectedRange(selectedRange)
            } else {
                textView.setSelectedRange(NSRange(location: displayText.count, length: 0))
            }
        } else if isCurrentlyFirstResponder {
            // While typing, only update styling for mentions, don't change the text
            // The text binding will be updated via textDidChange delegate method
            textView.updateAttributedText(textView.string, modelContext: modelContext)
        }
        
        // Ensure text view size updates properly for multi-line content
        textView.sizeToFit()
        
        // Scroll to show cursor if needed
        if isCurrentlyFirstResponder {
            DispatchQueue.main.async {
                textView.scrollRangeToVisible(textView.selectedRange())
            }
        }
        
        // Update editable state - CRITICAL: ensure this is always set correctly
        textView.isEditable = isEnabled
        textView.isSelectable = isEnabled
        
        // Update callbacks in case they changed
        textView.onSubmit = onSubmit
        textView.showAutocomplete = { self.showAutocomplete }
        textView.autocompleteResults = { self.autocompleteResults }
        textView.selectedIndex = { self.selectedIndex }
        textView.onSelectAutocomplete = onSelectAutocomplete
        textView.onUpdateSelectedIndex = { newIndex in
            DispatchQueue.main.async {
                self.selectedIndex = newIndex
            }
        }
        
        // Update placeholder
        if text.isEmpty && !isCurrentlyFirstResponder {
            textView.setPlaceholder(placeholder)
        } else {
            textView.setPlaceholder(nil)
        }
        
        // Update focus - only change if necessary, preserve focus while typing
        // IMPORTANT: Trust the actual first responder state when user is actively typing
        // If text view is first responder, preserve focus even if binding says otherwise
        let shouldBeFocused = isFocused && isEnabled
        
        // If user is actively typing, preserve focus regardless of binding state
        // This prevents focus from being lost while typing
        if isCurrentlyFirstResponder {
            // User is typing - preserve focus, don't change it
            // Only remove focus if explicitly requested AND user is not typing
            if !shouldBeFocused {
                // Binding says we shouldn't be focused, but user is typing
                // Only remove focus if isEnabled is false (field was disabled)
                if !isEnabled {
                    DispatchQueue.main.async {
                        nsView.window?.makeFirstResponder(nil)
                    }
                }
                // Otherwise, preserve focus while typing
            }
        } else if shouldBeFocused && !isCurrentlyFirstResponder {
            // User wants focus but doesn't have it - set it (e.g., web search button clicked)
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(textView)
                textView.scrollRangeToVisible(textView.selectedRange())
            }
        }
        // If !shouldBeFocused && !isCurrentlyFirstResponder - do nothing
        
        // CRITICAL: Ensure text view is editable when enabled
        if isEnabled {
            textView.isEditable = true
            textView.isSelectable = true
        } else {
            textView.isEditable = false
            textView.isSelectable = false
        }
    }
    
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MentionNSTextView
        fileprivate weak var textView: MentionTextView?
        weak var scrollView: NSScrollView?
        
        init(parent: MentionNSTextView) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let displayText = textView.string
            
            // Convert display names back to structured format for storage
            let structuredText = MentionService.shared.convertToStructuredFormat(
                text: displayText,
                modelContext: parent.modelContext
            )
            
            // Update styling for mentions (using display text)
            if let mentionTextView = textView as? MentionTextView {
                mentionTextView.updateAttributedText(displayText, modelContext: parent.modelContext)
            }
            
            // Update binding with structured format - this will trigger onChange in MentionTextEditor
            if parent.text != structuredText {
                parent.text = structuredText
            }
            
            // Call text change handler for mention detection (using structured format)
            // But only if we're not in a confirmation state (just linked something)
            parent.onTextChange(structuredText)
            
            // Update cursor position asynchronously to avoid layout recursion
            DispatchQueue.main.async {
                self.updateCursorPosition(textView: textView)
            }
            
            // Ensure text view resizes and scrolls to show cursor
            DispatchQueue.main.async {
                textView.sizeToFit()
                textView.scrollRangeToVisible(textView.selectedRange())
            }
        }
        
        private func updateCursorPosition(textView: NSTextView) {
            let selectedRange = textView.selectedRange()
            guard selectedRange.location != NSNotFound else {
                parent.cursorPosition = .zero
                return
            }
            
            // Get the rect for the cursor position
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else {
                parent.cursorPosition = .zero
                return
            }
            
            // Get the glyph range for the selected range
            let glyphRange = layoutManager.glyphRange(forCharacterRange: selectedRange, actualCharacterRange: nil)
            
            // Get the bounding rect for the glyphs
            let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            
            // Convert to view coordinates (bottom-left of the character)
            var point = rect.origin
            point.y += rect.height
            
            // Store relative to text view origin
            parent.cursorPosition = point
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Handle Escape to close autocomplete
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                if parent.showAutocomplete {
                    parent.showAutocomplete = false
                    return true
                }
            }
            
            // Let keyDown handle other commands
            return false
        }
    }
}

// Custom NSTextView with placeholder, image paste support, and mention styling
final class MentionTextView: NSTextView {
    private var placeholderAttributedString: NSAttributedString?
    var onSubmit: (() -> Void)?
    var showAutocomplete: (() -> Bool)?
    var autocompleteResults: (() -> [WorkspaceObjectResult])?
    var selectedIndex: (() -> Int)?
    var onSelectAutocomplete: (() -> Void)?
    var onUpdateSelectedIndex: ((Int) -> Void)?
    var linkedContext: LinkedContext = LinkedContext()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupTextView()
    }
    
    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setupTextView()
    }
    
    convenience init() {
        // Create with default frame - NSTextView will create text container automatically
        self.init(frame: .zero, textContainer: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTextView()
    }
    
    private func setupTextView() {
        // Enable proper text editing
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticLinkDetectionEnabled = false
        
        // CRITICAL: Ensure text view is editable and selectable
        isEditable = true
        isSelectable = true
        allowsUndo = true
        
        // Ensure text storage is properly initialized
        if let textStorage = textStorage {
            textStorage.delegate = nil // Remove any existing delegate
        }
    }
    
    override func keyDown(with event: NSEvent) {
        // Ensure we're editable before handling keys
        guard isEditable else {
            super.keyDown(with: event)
            return
        }
        
        // Handle Return key
        if event.keyCode == 36 { // Return key
            // Check if autocomplete is showing - if so, select it
            if let showAutocomplete = showAutocomplete, showAutocomplete(),
               let autocompleteResults = autocompleteResults, !autocompleteResults().isEmpty {
                // Autocomplete is showing - select current item
                onSelectAutocomplete?()
                return // Don't insert newline
            }
            
            // No autocomplete - normal Enter behavior: insert newline
            super.insertNewline(nil)
            // Ensure cursor is visible after inserting newline
            DispatchQueue.main.async {
                self.scrollRangeToVisible(self.selectedRange())
            }
            return // Don't call super for Return key
        } else if event.keyCode == 53 { // Escape key
            if let showAutocomplete = showAutocomplete, showAutocomplete() {
                // Close autocomplete - handled by delegate
                super.keyDown(with: event)
            } else {
                super.keyDown(with: event)
            }
            return
        } else if event.keyCode == 126 || event.keyCode == 125 { // Up/Down arrow keys
            if let showAutocomplete = showAutocomplete, showAutocomplete(),
               let autocompleteResults = autocompleteResults, !autocompleteResults().isEmpty,
               let selectedIndex = selectedIndex {
                let currentIndex = selectedIndex()
                if event.keyCode == 126 { // Up arrow
                    onUpdateSelectedIndex?(max(0, currentIndex - 1))
                } else { // Down arrow
                    onUpdateSelectedIndex?(min(autocompleteResults().count - 1, currentIndex + 1))
                }
                return // Don't call super for arrow keys when autocomplete is showing
            }
        }
        
        // For all other keys (including normal text input), let NSTextView handle it
        super.keyDown(with: event)
    }
    
    override func didChangeText() {
        super.didChangeText()
        
        // Ensure text view resizes to fit content
        DispatchQueue.main.async {
            self.sizeToFit()
            // Scroll to show cursor if we're the first responder
            if self.window?.firstResponder === self {
                self.scrollRangeToVisible(self.selectedRange())
            }
        }
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Don't intercept key equivalents - let them through
        return super.performKeyEquivalent(with: event)
    }
    
    func setPlaceholder(_ placeholder: String?) {
        if let placeholder = placeholder {
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.placeholderTextColor,
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .regular))
            ]
            placeholderAttributedString = NSAttributedString(string: placeholder, attributes: attributes)
        } else {
            placeholderAttributedString = nil
        }
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw placeholder if text is empty
        if string.isEmpty, let placeholder = placeholderAttributedString {
            let textRect = textContainer?.containerSize ?? bounds.size
            let rect = NSRect(x: 8, y: 8, width: textRect.width - 16, height: textRect.height - 16)
            placeholder.draw(in: rect)
        }
    }
    
    override func paste(_ sender: Any?) {
        // Check for image paste
        let pasteboard = NSPasteboard.general
        if let image = NSImage(pasteboard: pasteboard) {
            // Post notification for image paste
            NotificationCenter.default.post(
                name: NSNotification.Name("MentionInputImagePaste"),
                object: image
            )
            return
        }
        
        // Fall back to normal paste
        super.paste(sender)
    }
    
    override var acceptsFirstResponder: Bool {
        return isEditable
    }
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            // Ensure we're editable when becoming first responder
            isEditable = true
            isSelectable = true
            
            // Don't update the binding here - let SwiftUI manage it naturally
            // Updating it causes updateNSView to be called, which can interfere with focus
            
            // Update focus binding
            NotificationCenter.default.post(
                name: NSNotification.Name("MentionTextViewBecameFirstResponder"),
                object: self
            )
            
            // Ensure cursor is visible
            DispatchQueue.main.async {
                self.scrollRangeToVisible(self.selectedRange())
            }
        }
        return result
    }
    
    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result {
            // Don't update the binding here - let SwiftUI manage it naturally
            // Updating it causes updateNSView to be called, which can interfere with focus
            
            // Update focus binding
            NotificationCenter.default.post(
                name: NSNotification.Name("MentionTextViewResignedFirstResponder"),
                object: self
            )
        }
        return result
    }
    
    override func mouseDown(with event: NSEvent) {
        // Ensure text view becomes first responder on click
        if isEditable {
            if let window = window {
                window.makeFirstResponder(self)
                
                // Update the SwiftUI binding to keep it in sync
                DispatchQueue.main.async {
                    if let parent = self.delegate as? MentionNSTextView.Coordinator {
                        parent.parent.isFocused = true
                    }
                }
            }
        }
        super.mouseDown(with: event)
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return isEditable
    }
    
    // MARK: - Mention Styling
    
    func updateAttributedText(_ text: String, modelContext: ModelContext) {
        // Text is already in display format (display names, not structured)
        let attributedString = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: text.count)
        
        // Set default attributes
        attributedString.addAttributes([
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .regular)),
            .foregroundColor: NSColor.labelColor
        ], range: fullRange)
        
        // Parse mentions and style them
        let mentions = MentionParser.parseMentions(from: text)
        for mention in mentions {
            let mentionRange = mention.range
            
            // Check if this is a @web mention
            let isWebMention = MentionParser.isWebSearchMention(mention)
            
            // Check if this mention is in linkedContext (resolved) - but @web is always special
            var isResolved = !isWebMention && linkedContext.mentionMap[mention.fullText.lowercased()] != nil
            
            // If not in linkedContext, try to resolve it
            if !isResolved && !isWebMention {
                // Try to resolve the mention
                if let resolved = MentionService.shared.resolveMention(mention, modelContext: modelContext) {
                    isResolved = true
                    // Add to linked context for future reference
                    linkedContext.addLinkedObject(
                        type: resolved.type,
                        id: resolved.id,
                        mentionText: mention.fullText,
                        displayName: resolved.displayName
                    )
                }
            }
            
            // Style the mention - @web gets special cyan/teal styling
            var attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .regular), weight: .semibold),
            ]
            
            if isWebMention {
                // Special styling for @web mentions - use soft cyan/teal instead of orange
                let webColor = NSColor(red: 0.20, green: 0.76, blue: 0.86, alpha: 1.0) // Soft cyan/teal
                attributes[.foregroundColor] = webColor
                attributes[.backgroundColor] = webColor.withAlphaComponent(0.2)
            } else {
                attributes[.foregroundColor] = isResolved ? NSColor.systemBlue : NSColor.labelColor
                attributes[.backgroundColor] = isResolved ? NSColor.systemBlue.withAlphaComponent(0.15) : NSColor.clear
            }
            
            // Add rounded background effect
            if isResolved || isWebMention {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = 2
                attributes[.paragraphStyle] = paragraphStyle
            }
            
            attributedString.addAttributes(attributes, range: mentionRange)
            
            // For @web mentions, also style the query text that follows
            if isWebMention {
                if let query = MentionParser.extractWebSearchQuery(from: text, mention: mention), !query.isEmpty {
                    let queryStart = mentionRange.location + mentionRange.length
                    let queryEnd = min(queryStart + query.count, text.count)
                    if queryEnd > queryStart {
                        let queryRange = NSRange(location: queryStart, length: queryEnd - queryStart)
                        let webColor = NSColor(red: 0.20, green: 0.76, blue: 0.86, alpha: 1.0) // Soft cyan/teal
                        attributedString.addAttributes([
                            .foregroundColor: webColor.withAlphaComponent(0.8),
                            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .regular), weight: .medium)
                        ], range: queryRange)
                    }
                }
            }
        }
        
        // Update text storage
        textStorage?.setAttributedString(attributedString)
        
        // Reset typing attributes so new text uses default styling
        typingAttributes = [
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .regular)),
            .foregroundColor: NSColor.labelColor
        ]
    }
}

