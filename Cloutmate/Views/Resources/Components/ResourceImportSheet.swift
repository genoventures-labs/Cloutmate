//
//  ResourceImportSheet.swift
//  Cloutmate
//
//  Resources V2 - Import Sheet
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers
import CloutmateShared

enum ImportMethod: String, CaseIterable {
    case uploadFile = "Upload File"
    case saveLink = "Save Link"
    case captureText = "Capture Text"
    case fromAI = "From AI Assistant"
    
    var icon: String {
        switch self {
        case .uploadFile: return "doc.badge.plus"
        case .saveLink: return "link"
        case .captureText: return "text.cursor"
        case .fromAI: return "sparkles"
        }
    }
}

struct ResourceImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @Query(sort: \AIMessage.timestamp, order: .reverse) private var allAIMessages: [AIMessage]
    
    @State private var selectedMethod: ImportMethod = .uploadFile
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var sourceURL: String = ""
    @State private var tags: [String] = []
    @State private var newTag: String = ""
    @State private var selectedType: ResourceType = .note
    @State private var isReference: Bool = false
    @State private var isLoadingMetadata: Bool = false
    @State private var isProcessing: Bool = false
    @State private var selectedAIMessage: AIMessage?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Navigation
                HStack(spacing: 0) {
                    ForEach(ImportMethod.allCases, id: \.self) { method in
                    Button(action: {
                        withAnimation(GlassMotion.Easing.spring) {
                            selectedMethod = method
                            // Clear AI selection when switching away from AI tab
                            if method != .fromAI {
                                selectedAIMessage = nil
                            }
                        }
                    }) {
                            VStack(spacing: 6) {
                                Image(systemName: method.icon)
                                    .font(.system(size: 16, weight: .medium))
                                Text(method.rawValue)
                                    .font(.system(.caption, design: .rounded))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                selectedMethod == method ?
                                Color.kosmicBlue.opacity(0.15) : Color.clear
                            )
                            .foregroundColor(
                                selectedMethod == method ? .kosmicBlue : .secondary
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(glassColorSystem.cardColor())
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(glassColorSystem.borderColor()),
                    alignment: .bottom
                )
                
                // Content Area
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedMethod {
                        case .uploadFile:
                            UploadFileSection(
                                title: $title,
                                content: $content,
                                selectedType: $selectedType
                            )
                            
                        case .saveLink:
                            SaveLinkSection(
                                sourceURL: $sourceURL,
                                title: $title,
                                content: $content,
                                isLoadingMetadata: $isLoadingMetadata,
                                onFetchMetadata: fetchLinkMetadata
                            )
                            
                        case .captureText:
                            CaptureTextSection(
                                title: $title,
                                content: $content,
                                selectedType: $selectedType
                            )
                            
                        case .fromAI:
                            FromAISection(
                                title: $title,
                                content: $content,
                                tags: $tags,
                                selectedMessage: $selectedAIMessage,
                                recentMessages: recentAIMessages
                            )
                            
                            // Title and Content fields for AI import
                            if selectedAIMessage != nil {
                                VStack(spacing: 16) {
                                    TextField("Title", text: $title)
                                        .textFieldStyle(.roundedBorder)
                                    
                                    TextEditor(text: $content)
                                        .frame(height: 150)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        // Common Fields
                        VStack(alignment: .leading, spacing: 12) {
                            // Type Selector
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Type")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Picker("Type", selection: $selectedType) {
                                    ForEach(ResourceType.allCases, id: \.self) { type in
                                        Text(type.rawValue).tag(type)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            
                            // Tags Editor
                            TagsInputSection(tags: $tags, newTag: $newTag)
                            
                            // Reference Toggle
                            Toggle("Mark as Reference (non-editable)", isOn: $isReference)
                                .font(.caption)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 20)
                }
                
                // Footer Actions
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button(action: createResource) {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Import Resource")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled((title.isEmpty && selectedAIMessage == nil) || isProcessing)
                }
                .padding(20)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Import Resource")
            .frame(width: 600, height: 550)
        }
    }
    
    private var recentAIMessages: [AIMessage] {
        allAIMessages
            .filter { $0.role == "assistant" && !($0.content?.isEmpty ?? true) }
            .prefix(20)
            .map { $0 }
    }
    
    private func fetchLinkMetadata() {
        guard !sourceURL.isEmpty, let url = URL(string: sourceURL) else { return }
        
        isLoadingMetadata = true
        
        // TODO: Implement actual web scraping/metadata fetching
        // For now, use placeholder
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if title.isEmpty {
                title = url.host ?? "Web Resource"
            }
            if content.isEmpty {
                content = "Content from \(url.absoluteString)"
            }
            isLoadingMetadata = false
        }
    }
    
    private func createResource() {
        isProcessing = true
        
        // Set source URL if importing from AI
        if selectedMethod == .fromAI, let message = selectedAIMessage {
            if let conversation = message.conversation {
                sourceURL = "ai-assistant://conversation/\(conversation.id.uuidString)"
            }
        }
        
        let note = Note(
            title: title,
            markdown: content,
            tags: tags,
            source: sourceURL.isEmpty ? nil : sourceURL,
            type: selectedType
        )
        
        modelContext.insert(note)
        
        // Process with Aurora in background
        _Concurrency.Task {
            await processWithAurora(note: note)
            
            await MainActor.run {
                try? modelContext.save()
                isProcessing = false
                dismiss()
            }
        }
    }
    
    private func processWithAurora(note: Note) async {
        // TODO: Integrate with OllamaBridgeService for auto-categorization
        // This will be implemented in Phase 6
    }
}

// MARK: - Import Method Sections

struct UploadFileSection: View {
    @Binding var title: String
    @Binding var content: String
    @Binding var selectedType: ResourceType
    
    @State private var selectedFileURL: URL?
    @State private var isDragging = false
    
    var body: some View {
        VStack(spacing: 16) {
            // File Picker
            Button(action: selectFile) {
                VStack(spacing: 12) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.kosmicBlue)
                    
                    Text("Choose File or Drag & Drop")
                        .font(.headline)
                    
                    if let fileURL = selectedFileURL {
                        Text(fileURL.lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.secondary.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(
                                    isDragging ? Color.kosmicBlue : Color.secondary.opacity(0.3),
                                    style: StrokeStyle(lineWidth: isDragging ? 2 : 1, lineCap: .round, dash: [5, 5])
                                )
                        )
                )
            }
            .buttonStyle(.plain)
            .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
                handleDrop(providers: providers)
            }
            
            // Title Input
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
        }
        .padding(.horizontal, 20)
    }
    
    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK {
            selectedFileURL = panel.url
            title = panel.url?.lastPathComponent ?? ""
            loadFileContent()
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            if let data = item as? Data,
               let url = URL(dataRepresentation: data, relativeTo: nil) {
                DispatchQueue.main.async {
                    selectedFileURL = url
                    title = url.lastPathComponent
                    loadFileContent()
                }
            }
        }
        
        return true
    }
    
    private func loadFileContent() {
        guard let fileURL = selectedFileURL else { return }
        
        // TODO: Load file content based on type
        // For now, just set placeholder
        content = "File content from \(fileURL.lastPathComponent)"
    }
}

struct SaveLinkSection: View {
    @Binding var sourceURL: String
    @Binding var title: String
    @Binding var content: String
    @Binding var isLoadingMetadata: Bool
    
    let onFetchMetadata: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            TextField("Paste URL", text: $sourceURL)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    onFetchMetadata()
                }
            
            if isLoadingMetadata {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Fetching metadata...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
            
            TextEditor(text: $content)
                .frame(height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                )
        }
        .padding(.horizontal, 20)
    }
}

struct CaptureTextSection: View {
    @Binding var title: String
    @Binding var content: String
    @Binding var selectedType: ResourceType
    
    var body: some View {
        VStack(spacing: 16) {
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
            
            TextEditor(text: $content)
                .frame(height: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .placeholder(when: content.isEmpty) {
                    Text("Enter your text snippet here...")
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                        .padding(.top, 8)
                }
        }
        .padding(.horizontal, 20)
    }
}

struct FromAISection: View {
    @Binding var title: String
    @Binding var content: String
    @Binding var tags: [String]
    @Binding var selectedMessage: AIMessage?
    let recentMessages: [AIMessage]
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Select AI Response")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if recentMessages.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("No AI responses yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Start a conversation with Aurora to see responses here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(recentMessages) { message in
                            AIMessageRow(
                                message: message,
                                isSelected: selectedMessage?.id == message.id,
                                onSelect: {
                                    selectedMessage = message
                                    loadMessageContent(message)
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: 250)
            }
            
            // Preview of selected message
            if let message = selectedMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(message.content ?? "")
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(glassColorSystem.cardColor())
                        )
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func loadMessageContent(_ message: AIMessage) {
        content = message.content ?? ""
        
        // Generate title from content (first line or first 50 chars)
        if title.isEmpty {
            let contentLines = (message.content ?? "").components(separatedBy: .newlines)
            if let firstLine = contentLines.first, !firstLine.isEmpty {
                // Remove markdown formatting for title
                let cleaned = firstLine
                    .replacingOccurrences(of: "**", with: "")
                    .replacingOccurrences(of: "*", with: "")
                    .replacingOccurrences(of: "#", with: "")
                    .trimmingCharacters(in: .whitespaces)
                title = String(cleaned.prefix(60))
            } else {
                title = "AI Response from \(message.timestamp?.formatted(date: .abbreviated, time: .omitted) ?? "recent conversation")"
            }
        }
        
        // Auto-add "AI" tag if not present
        if !tags.contains("AI") {
            tags.append("AI")
        }
    }
}

struct AIMessageRow: View {
    let message: AIMessage
    let isSelected: Bool
    let onSelect: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    private var previewText: String {
        let content = message.content ?? ""
        return String(content.prefix(100)).trimmingCharacters(in: .whitespaces)
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                // Selection indicator
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.kosmicBlue : Color.clear)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .strokeBorder(isSelected ? Color.kosmicBlue : Color.secondary.opacity(0.3), lineWidth: 2)
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    // Timestamp and conversation title
                    HStack {
                        if let conversation = message.conversation {
                            Text(conversation.title ?? "Untitled Conversation")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        if let timestamp = message.timestamp {
                            Text(timestamp, style: .relative)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Message preview
                    Text(previewText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.kosmicBlue.opacity(0.1) : glassColorSystem.cardColor())
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.kosmicBlue.opacity(0.4) : glassColorSystem.borderColor(),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct TagsInputSection: View {
    @Binding var tags: [String]
    @Binding var newTag: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Existing Tags
            if !tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag)
                                .font(.caption)
                            Button(action: {
                                tags.removeAll { $0 == tag }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.kosmicPurple.opacity(0.15))
                        )
                        .foregroundColor(.kosmicPurple)
                    }
                }
            }
            
            // Add Tag
            HStack {
                TextField("Add tag", text: $newTag)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .onSubmit {
                        addTag()
                    }
                
                Button(action: addTag) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.kosmicBlue)
                }
                .buttonStyle(.plain)
                .disabled(newTag.isEmpty)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.1))
            )
        }
    }
    
    private func addTag() {
        guard !newTag.isEmpty, !tags.contains(newTag) else { return }
        tags.append(newTag)
        newTag = ""
    }
}

// MARK: - View Extensions

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    ResourceImportSheet()
        .environmentObject(GlassColorSystem())
        .modelContainer(for: Note.self)
}

