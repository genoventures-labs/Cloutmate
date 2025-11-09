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

struct MentionInputField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    var placeholder: String = "Type here..."
    var onSubmit: () -> Void
    @Binding var linkedContext: LinkedContext
    var isEnabled: Bool = true
    
    @Environment(\.modelContext) private var modelContext
    @State private var showAutocomplete = false
    @State private var autocompleteResults: [WorkspaceObjectResult] = []
    @State private var selectedIndex = 0
    @State private var currentMention: String? = nil
    @State private var searchDebounceTask: _Concurrency.Task<Void, Never>?
    
    @State private var isMultiLine = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Use NSTextView for attributed string support
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
                isEnabled: isEnabled
            )
            .allowsHitTesting(true)
            
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
        
        // Set initial text
        textView.linkedContext = linkedContext
        if !text.isEmpty {
            textView.string = text
            textView.updateAttributedText(text)
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
        
        // Update linked context
        textView.linkedContext = linkedContext
        
        // Only update text if it changed externally AND we're not currently editing
        // (to avoid overwriting user input while typing)
        let isCurrentlyFirstResponder = nsView.window?.firstResponder === textView
        if !isCurrentlyFirstResponder && textView.string != text {
            // Text changed externally - update it
            let selectedRange = textView.selectedRange()
            textView.string = text
            textView.updateAttributedText(text)
            
            // Restore cursor position or move to end
            if selectedRange.location <= text.count {
                textView.setSelectedRange(selectedRange)
            } else {
                textView.setSelectedRange(NSRange(location: text.count, length: 0))
            }
        } else if isCurrentlyFirstResponder {
            // While typing, only update styling for mentions, don't change the text
            // The text binding will be updated via textDidChange delegate method
            textView.updateAttributedText(textView.string)
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
            let newText = textView.string
            
            // Update styling for mentions
            if let mentionTextView = textView as? MentionTextView {
                mentionTextView.updateAttributedText(newText)
            }
            
            // Update binding
            parent.text = newText
            
            // Call text change handler for mention detection
            parent.onTextChange(newText)
            
            // Ensure text view resizes and scrolls to show cursor
            DispatchQueue.main.async {
                textView.sizeToFit()
                textView.scrollRangeToVisible(textView.selectedRange())
            }
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
fileprivate final class MentionTextView: NSTextView {
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
            if event.modifierFlags.contains(.shift) {
                // Shift+Enter: insert newline
                super.insertNewline(nil)
                // Ensure cursor is visible after inserting newline
                DispatchQueue.main.async {
                    self.scrollRangeToVisible(self.selectedRange())
                }
            } else {
                // Enter without Shift: submit or select autocomplete
                if let showAutocomplete = showAutocomplete, showAutocomplete(),
                   let autocompleteResults = autocompleteResults, !autocompleteResults().isEmpty {
                    onSelectAutocomplete?()
                } else {
                    onSubmit?()
                }
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
    
    func updateAttributedText(_ text: String) {
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
            let isResolved = !isWebMention && linkedContext.mentionMap[mention.fullText.lowercased()] != nil
            
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
    }
}

