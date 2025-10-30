//
//  NoteHighlightingView.swift
//  Cloutmate
//
//  Note highlighting and snippet extraction system
//

import SwiftUI
import SwiftData

struct NoteHighlightingView: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var modelContext
    @State private var editingContent = ""
    @State private var selectedText = ""
    @State private var showHighlightActions = false
    @State private var showExtractSheet = false
    @State private var showHighlightsSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Enhanced toolbar with highlight actions
            HStack {
                Button(action: {}) {
                    Image(systemName: "bold")
                }
                Button(action: {}) {
                    Image(systemName: "italic")
                }
                Button(action: {}) {
                    Image(systemName: "text.bubble")
                }
                
                Divider()
                    .frame(height: 20)
                
                // Highlight button (becomes active when text is selected)
                Button(action: { handleHighlight() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "highlighter")
                        Text("Highlight")
                    }
                    .font(.caption)
                }
                .disabled(selectedText.isEmpty)
                
                // View highlights
                Button(action: { showHighlightsSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "text.alignleft")
                        if !note.highlights.isEmpty {
                            Text("\(note.highlights.count)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                    .font(.caption)
                }
                
                Spacer()
                
                Text("\(editingContent.isEmpty ? note.markdown : editingContent).wordCount) words")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .glassPanel(tier: .contentCard)
            
            Divider()
            
            // Content editor
            VStack(spacing: 0) {
                TextField("Note Title", text: $note.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .textFieldStyle(.plain)
                    .padding()
                
                Divider()
                
                TextEditorWithSelection(
                    text: $editingContent,
                    selectedText: $selectedText
                )
                .font(.body)
            }
        }
        .sheet(isPresented: $showHighlightsSheet) {
            HighlightsListView(note: note)
        }
        .onChange(of: editingContent) { _, newValue in
            note.markdown = newValue.isEmpty ? note.markdown : newValue
            note.updatedAt = Date()
        }
        .onAppear {
            editingContent = note.markdown
        }
    }
    
    private func handleHighlight() {
        guard !selectedText.isEmpty else { return }
        
        // Add to highlights
        note.highlights.append(selectedText)
        note.updatedAt = Date()
        
        try? modelContext.save()
        
        // Clear selection
        selectedText = ""
    }
}

struct TextEditorWithSelection: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedText: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        textView.isEditable = true
        textView.isSelectable = true
        textView.string = text
        textView.font = .systemFont(ofSize: 14)
        textView.autoresizingMask = [.width, .height]
        
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        
        // Monitor selection changes
        NotificationCenter.default.addObserver(
            forName: NSTextView.didChangeSelectionNotification,
            object: textView,
            queue: .main
        ) { _ in
            if let selectedRange = textView.selectedRanges.first as? NSRange,
               selectedRange.length > 0 {
                selectedText = (textView.string as NSString).substring(with: selectedRange)
            } else {
                selectedText = ""
            }
        }
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView,
           textView.string != text {
            textView.string = text
        }
    }
}

struct HighlightsListView: View {
    @Bindable var note: Note
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedHighlight: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(note.highlights.enumerated()), id: \.offset) { index, highlight in
                        HighlightCard(
                            highlight: highlight,
                            onExtract: {
                                extractToTask(from: highlight)
                            },
                            onExtractToPost: {
                                extractToPost(from: highlight)
                            },
                            onDelete: {
                                deleteHighlight(at: index)
                            }
                        )
                    }
                }
                .padding()
            }
            .background(Color.clear)
            .navigationTitle("Highlights (\(note.highlights.count))")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 600, height: 500)
    }
    
    private func extractToTask(from text: String) {
        let task = Task(title: text)
        task.notes = "From note: \(note.title)"
        modelContext.insert(task)
        note.backlinks.append(task.id)
        try? modelContext.save()
    }
    
    private func extractToPost(from text: String) {
        let post = Post(caption: text)
        modelContext.insert(post)
        note.backlinks.append(post.id)
        try? modelContext.save()
    }
    
    private func deleteHighlight(at index: Int) {
        note.highlights.remove(at: index)
        note.updatedAt = Date()
        try? modelContext.save()
    }
}

struct HighlightCard: View {
    let highlight: String
    let onExtract: () -> Void
    let onExtractToPost: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(highlight)
                .font(.body)
                .foregroundStyle(.primary)
            
            Divider()
            
            HStack(spacing: 8) {
                Button(action: onExtract) {
                    Label("To Task", systemImage: "checkmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                
                Button(action: onExtractToPost) {
                    Label("To Post", systemImage: "square.and.pencil")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 12)
    }
}

#Preview {
    NoteHighlightingView(note: Note(title: "Test", markdown: "This is a test note"))
        .modelContainer(for: [Note.self, Task.self, Post.self])
}

