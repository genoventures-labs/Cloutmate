//
//  RichTextEditor.swift
//  Cloutmate
//
//  Rich Markdown Editor with Live Preview
//

import SwiftUI
import SwiftData
import AppKit

struct RichTextEditor: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    @State private var selectedRange = NSRange()
    @State private var showToolbar = false
    @State private var renderedPreview: NSAttributedString?
    
    private let markdownParser = MarkdownParser()
    
    var body: some View {
        VStack(spacing: 0) {
            // Subtle Toolbar
            if showToolbar {
                ToolbarView(
                    selectedRange: $selectedRange,
                    onBold: { insertFormatting("**", "**") },
                    onItalic: { insertFormatting("*", "*") },
                    onCode: { insertFormatting("`", "`") },
                    onLink: { insertLink() },
                    onHeading: { level in insertHeading(level: level) },
                    onBullet: { insertBullet() }
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                Divider()
            }
            
            HStack(spacing: 0) {
                // Left: Markdown Editor
                VStack(alignment: .leading, spacing: 0) {
                    TextEditor(text: $text)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .focused($isFocused)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color.clear)
                        .onChange(of: text) { _, _ in
                            updatePreview()
                        }
                    
                    // Word count
                    HStack {
                        Spacer()
                        Text("\(text.wordCount) words")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }
                .frame(maxWidth: .infinity)
                
                // Divider
                Divider()
                
                // Right: Live Preview
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let preview = renderedPreview {
                            AttributedText(attributedString: preview)
                                .padding(12)
                        } else {
                            Text("Preview will appear here...")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding(12)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color(.textBackgroundColor))
        .onAppear {
            showToolbar = true
            updatePreview()
        }
        .onHover { hovering in
            showToolbar = hovering || isFocused
        }
    }
    
    private func updatePreview() {
        _Concurrency.Task {
            let rendered = await markdownParser.parse(text)
            await MainActor.run {
                renderedPreview = rendered
            }
        }
    }
    
    private func insertFormatting(_ prefix: String, _ suffix: String) {
        // Get selected text or insert markers
        if selectedRange.length > 0 {
            let nsText = text as NSString
            let formatted = "\(prefix)\(nsText.substring(with: selectedRange))\(suffix)"
            text = (nsText.replacingCharacters(in: selectedRange, with: formatted) as String)
        } else {
            // Insert formatting at cursor position
            text += "\(prefix)\(suffix)"
        }
    }
    
    private func insertLink() {
        text += "[Link text](https://example.com)"
    }
    
    private func insertHeading(level: Int) {
        let hashes = String(repeating: "#", count: level)
        if text.isEmpty || !text.hasSuffix("\n") {
            text += "\n"
        }
        text += "\(hashes) "
    }
    
    private func insertBullet() {
        if text.isEmpty || !text.hasSuffix("\n") {
            text += "\n"
        }
        text += "- "
    }
}

// Toolbar Component
struct ToolbarView: View {
    @Binding var selectedRange: NSRange
    
    let onBold: () -> Void
    let onItalic: () -> Void
    let onCode: () -> Void
    let onLink: () -> Void
    let onHeading: (Int) -> Void
    let onBullet: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBold) {
                Image(systemName: "bold")
            }
            .help("Bold")
            
            Button(action: onItalic) {
                Image(systemName: "italic")
            }
            .help("Italic")
            
            Button(action: onCode) {
                Image(systemName: "textbox")
            }
            .help("Code")
            
            Divider()
                .frame(height: 16)
            
            Button(action: { onHeading(1) }) {
                Image(systemName: "textformat.size")
            }
            .help("Heading")
            
            Button(action: onBullet) {
                Image(systemName: "list.bullet")
            }
            .help("Bullet List")
            
            Button(action: onLink) {
                Image(systemName: "link")
            }
            .help("Link")
        }
        .buttonStyle(.plain)
        .font(.system(size: 13))
    }
}

// Attributed Text Renderer
struct AttributedText: NSViewRepresentable {
    let attributedString: NSAttributedString
    
    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = false
        textView.backgroundColor = .clear
        textView.textStorage?.setAttributedString(attributedString)
        return textView
    }
    
    func updateNSView(_ nsView: NSTextView, context: Context) {
        nsView.textStorage?.setAttributedString(attributedString)
    }
}

// Markdown Parser
@MainActor
class MarkdownParser {
    func parse(_ markdown: String) async -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: markdown)
        
        // Bold **text**
        let boldPattern = #"\*\*([^*]+)\*\*"#
        attributed.enumerateMatches(pattern: boldPattern) { range in
            attributed.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize), range: range)
        }
        
        // Italic *text*
        let italicPattern = #"(?<!\*)\*([^*]+)\*(?!\*)"#
        attributed.enumerateMatches(pattern: italicPattern) { range in
            attributed.addAttribute(.font, value: NSFont.systemFont(ofSize: NSFont.systemFontSize).withSymbolicTraits(.italic) ?? NSFont.systemFont(ofSize: NSFont.systemFontSize), range: range)
        }
        
        // Code `text`
        let codePattern = #"`([^`]+)`"#
        attributed.enumerateMatches(pattern: codePattern) { range in
            attributed.addAttribute(.backgroundColor, value: NSColor.controlBackgroundColor, range: range)
            attributed.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular), range: range)
        }
        
        // Headers
        let lines = markdown.components(separatedBy: .newlines)
        var currentIndex = 0
        for line in lines {
            if line.hasPrefix("###") {
                let range = NSRange(location: currentIndex, length: line.count)
                attributed.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 14), range: range)
            } else if line.hasPrefix("##") {
                let range = NSRange(location: currentIndex, length: line.count)
                attributed.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 16), range: range)
            } else if line.hasPrefix("#") {
                let range = NSRange(location: currentIndex, length: line.count)
                attributed.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 18), range: range)
            }
            currentIndex += line.count + 1
        }
        
        return attributed
    }
}

extension NSMutableAttributedString {
    func enumerateMatches(pattern: String, block: (NSRange) -> Void) {
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let matches = regex?.matches(in: self.string, options: [], range: NSRange(location: 0, length: self.length)) ?? []
        
        for match in matches.reversed() {
            if match.numberOfRanges > 1 {
                block(match.range(at: 1))
            }
        }
    }
}

extension NSFont {
    @MainActor
    func withSymbolicTraits(_ traits: NSFontDescriptor.SymbolicTraits) -> NSFont? {
        let descriptor = fontDescriptor.withSymbolicTraits(traits)
        return NSFont(descriptor: descriptor, size: pointSize)
    }
}

extension String {
    var wordCount: Int {
        components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
}

#Preview {
    RichTextEditor(text: .constant("# Hello World\n\nThis is **bold** and this is *italic*"))
        .frame(height: 300)
}

