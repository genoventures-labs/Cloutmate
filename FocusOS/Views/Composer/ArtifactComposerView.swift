//
//  ArtifactComposerView.swift
//  FocusOS
//
//  Artifact Composer - Capture and Craft modes for cognitive artifacts
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit
import os.log
import FocusOSShared

enum ComposerMode {
    case capture // Quick thought capture
    case craft   // Refine into finished artifact
}

struct ArtifactComposerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let draft: Draft?
    let existingArtifact: Artifact?
    let prefilledDate: Date?
    
    @State private var mode: ComposerMode = .capture
    @State private var title = ""
    @State private var content = ""
    @State private var selectedFormat: OutputFormat = .brief
    @State private var tags: [String] = []
    @State private var mediaURLs: [URL] = []
    @State private var showingMediaPicker = false
    @State private var validationError: String?
    @State private var showAIPopover = false
    @State private var showAISelectionSheet = false
    @State private var aiGeneratedItems: [AIGeneratedItem] = []
    @State private var selectedAITool: AITool?
    @State private var showAIPromptDialog = false
    @State private var userPromptText = ""
    @State private var isAIGenerating = false
    @State private var isCreating = false
    @State private var showMorphIn = false
    
    init(draft: Draft? = nil, existingArtifact: Artifact? = nil, prefilledDate: Date? = nil) {
        self.draft = draft
        self.existingArtifact = existingArtifact
        self.prefilledDate = prefilledDate
    }
    
    private var modeToggle: some View {
        Picker("Mode", selection: $mode) {
            Label("Capture", systemImage: "pencil.line").tag(ComposerMode.capture)
            Label("Craft", systemImage: "sparkles").tag(ComposerMode.craft)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
    
    private var contentSectionHeader: some View {
        HStack {
            Text(mode == .capture ? "Quick Capture" : "Content")
                .font(.headline)
            
            Spacer()
            
            // AI Assistant Button
            if AISettings.shared.isAIEnabled {
                AIAssistantButton
            }
            
            Text("\(fullContent.count) characters")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var fullContent: String {
        if title.isEmpty {
            return content
        }
        if content.isEmpty {
            return title
        }
        return "\(title)\n\n\(content)"
    }
    
    private var AIAssistantButton: some View {
        Button(action: {
            if !isAIGenerating {
                showAIPopover.toggle()
            }
        }) {
            HStack(spacing: 4) {
                if isAIGenerating {
                    ProgressView()
                        .scaleEffect(0.5)
                }
                Image(systemName: "sparkles")
                    .foregroundColor(.kosmicBlue)
                    .font(.caption)
                    .symbolEffect(.pulse.byLayer, options: .repeating, isActive: isAIGenerating)
            }
        }
        .buttonStyle(.plain)
        .disabled(isAIGenerating)
        .popover(isPresented: $showAIPopover) {
            AIAssistantPopover(
                onToolSelected: { tool in
                    showAIPopover = false
                    selectedAITool = tool
                    showAIPromptDialog = true
                }
            )
        }
    }
    
    private var contentSection: some View {
        Section {
            contentSectionHeader
            
            GlassPanel(tier: .overlay, cornerRadius: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    if mode == .craft {
                        TextField("Title", text: $title)
                            .font(.headline)
                            .padding(8)
                    }
                    
                    TextEditor(text: $content)
                        .frame(minHeight: mode == .capture ? 100 : 200)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                }
            }
        }
    }
    
    private var formatSection: some View {
        Section("Output Format") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(OutputFormat.allCases, id: \.self) { format in
                    GlassPanel(tier: .overlay, cornerRadius: 10, showInnerStroke: false) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(format.displayName)
                                    .font(.system(size: 14, weight: .medium))
                                Text(format.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedFormat == format {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.kosmicBlue)
                            }
                        }
                        .padding(8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedFormat = format
                        }
                    }
                }
            }
        }
    }
    
    private var mediaSection: some View {
        Section("Media Attachments") {
            if !mediaURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(mediaURLs, id: \.self) { url in
                            MediaPreviewView(url: url, onRemove: {
                                mediaURLs.removeAll { $0 == url }
                            })
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                }
                .frame(height: 140)
            }
            
            Button(action: {
                showingMediaPicker = true
            }) {
                Label("Add Media", systemImage: "photo.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .fileImporter(
                isPresented: $showingMediaPicker,
                allowedContentTypes: [.image, .movie],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    mediaURLs.append(contentsOf: urls)
                case .failure(let error):
                    validationError = "Failed to add media: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private var tagsSection: some View {
        Section("Tags") {
            TagsView(tags: $tags)
        }
    }
    
    @ViewBuilder
    private var errorSection: some View {
        if let error = validationError {
            Section {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }
    
    private var actionsSection: some View {
        Section {
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                if mode == .craft {
                    Button("Copy to Clipboard") {
                        copyToClipboard()
                    }
                    .buttonStyle(.bordered)
                }
                
                Button(mode == .capture ? "Save" : "Create Artifact") {
                    if validateInput() {
                        saveArtifact()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCreating)
            }
        }
    }
    
    var body: some View {
        Form {
            modeToggle
                .padding(.top)
            
            contentSection
            formatSection
            mediaSection
            tagsSection
            errorSection
            actionsSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 600, idealWidth: 700, minHeight: 600, idealHeight: 700)
        .padding()
        .background(.ultraThinMaterial.opacity(0.8))
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showAIPromptDialog) {
            AIPromptDialog(
                onConfirm: { prompt in
                    userPromptText = prompt
                    showAIPromptDialog = false
                    if let tool = selectedAITool {
                        handleAITool(tool, userPrompt: prompt)
                    }
                },
                onCancel: {
                    showAIPromptDialog = false
                }
            )
        }
        .sheet(isPresented: $showAISelectionSheet) {
            if let tool = selectedAITool {
                AISelectionSheet(
                    tool: tool,
                    items: aiGeneratedItems,
                    onInsert: { content in
                        insertAIContent(content, tool: tool)
                    },
                    onGenerate: nil
                )
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [.kosmicBlue.opacity(0.2), .kosmicPurple.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .blur(radius: 2)
        )
        .scaleEffect(showMorphIn ? 1.0 : 0.96)
        .opacity(showMorphIn ? 1.0 : 0.0)
        .onAppear {
            withAnimation(GlassMotion.Easing.modalOpen) {
                showMorphIn = true
            }
            
            // Pre-fill data
            if let draft = draft {
                let lines = draft.caption.components(separatedBy: .newlines)
                title = lines.first?.trimmingCharacters(in: .whitespaces) ?? ""
                content = lines.count > 1 ? lines.dropFirst().joined(separator: "\n") : ""
                if content.isEmpty { content = draft.caption }
                tags = draft.tags
                mediaURLs = draft.mediaURLs.compactMap { URL(string: $0) }
                mode = .craft // Start in craft mode for drafts
            } else if let artifact = existingArtifact {
                title = artifact.title
                content = artifact.content
                selectedFormat = artifact.format
                tags = artifact.tags
                mediaURLs = artifact.mediaURLs.compactMap { URL(fileURLWithPath: $0) }
                mode = .craft
            } else if prefilledDate != nil {
                mode = .capture
            }
        }
    }
    
    private func validateInput() -> Bool {
        validationError = nil
        
        if mode == .capture {
            // Capture mode: only content required
            if content.isEmpty && title.isEmpty {
                validationError = "Please enter some content"
                return false
            }
        } else {
            // Craft mode: title required
            if title.isEmpty {
                validationError = "Please enter a title"
                return false
            }
            if content.isEmpty {
                validationError = "Please enter content"
                return false
            }
        }
        
        return true
    }
    
    private func saveArtifact() {
        isCreating = true
        validationError = nil
        
        _Concurrency.Task {
            let artifact: Artifact
            
            if let existing = existingArtifact {
                // Update existing artifact
                artifact = existing
                artifact.title = title
                artifact.content = content
                artifact.format = selectedFormat
                artifact.mediaURLs = mediaURLs.map { $0.path }
                artifact.tags = tags
                artifact.updatedAt = Date()
                
                // Update state based on mode
                if mode == .craft {
                    artifact.artifactState = .final
                }
            } else {
                // Create new artifact
                let state: ArtifactState = mode == .capture ? .idea : .draft
                artifact = Artifact(
                    title: title.isEmpty ? content.prefix(50).description : title,
                    content: content.isEmpty ? title : content,
                    mediaURLs: mediaURLs.map { $0.path },
                    outputFormat: selectedFormat,
                    state: state,
                    tags: tags
                )
                
                modelContext.insert(artifact)
            }
            
            try? modelContext.save()
            
            isCreating = false
            dismiss()
        }
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        var exportText = ""
        if !title.isEmpty {
            exportText += "# \(title)\n\n"
        }
        exportText += content
        
        if !tags.isEmpty {
            exportText += "\n\nTags: \(tags.joined(separator: ", "))"
        }
        
        pasteboard.setString(exportText, forType: .string)
    }
    
    private func handleAITool(_ tool: AITool, userPrompt: String) {
        isAIGenerating = true
        
        _Concurrency.Task {
            let result = await AICreativeService.shared.executeTool(tool, input: userPrompt, context: selectedFormat.rawValue)
            let cleanedResult = cleanAIResponse(result.result)
            let items = try await CoreResponseService.shared.parseListResponse(cleanedResult, tool: tool)
            let generatedItems = items.map { AIGeneratedItem(content: $0, type: tool) }
            
            await MainActor.run {
                isAIGenerating = false
                aiGeneratedItems = generatedItems
                showAISelectionSheet = true
            }
        }
    }
    
    private func cleanAIResponse(_ text: String) -> String {
        var cleaned = text
        let lines = cleaned.components(separatedBy: .newlines)
        
        let introKeywords = ["here's", "here are", "here is", "here we", "here you", "following", "below are", "see below"]
        var filteredLines = lines.filter { line in
            let lowercaseLine = line.lowercased().trimmingCharacters(in: .whitespaces)
            if lowercaseLine.isEmpty { return true }
            for keyword in introKeywords {
                if lowercaseLine.starts(with: keyword) || 
                   lowercaseLine.contains("\(keyword):") || 
                   lowercaseLine.contains("\(keyword) your") ||
                   lowercaseLine.contains("\(keyword) some") ||
                   lowercaseLine.contains("enjoy!") ||
                   lowercaseLine.contains("hope this helps") ||
                   lowercaseLine.contains("let me know") {
                    return false
                }
            }
            return true
        }
        
        while let lastLine = filteredLines.last, !lastLine.trimmingCharacters(in: .whitespaces).isEmpty {
            let lowercaseLast = lastLine.lowercased().trimmingCharacters(in: .whitespaces)
            let outroKeywords = ["hope this", "let me know", "feel free", "if you need", "any other", "anything else", "good luck", "best of luck"]
            if outroKeywords.contains(where: { lowercaseLast.contains($0) }) {
                filteredLines.removeLast()
            } else {
                break
            }
        }
        
        cleaned = filteredLines.joined(separator: "\n")
        filteredLines = cleaned.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
        cleaned = filteredLines.joined(separator: "\n")
        
        cleaned = cleaned.replacingOccurrences(of: #"\*\*([^*]+)\*\*"#, with: "$1", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"(?<!\*)\*([^*]+)\*(?!\*)"#, with: "$1", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"```[\s\S]*?```"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"`([^`]+)`"#, with: "$1", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\[([^\]]+)\]\([^\)]+\)"#, with: "$1", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
    
    private func insertAIContent(_ content: String, tool: AITool) {
        switch tool {
        case .improveText, .generateCaptions:
            self.content = content
        case .suggestHashtags:
            self.content += "\n\n" + content
        case .brainstorm:
            self.content = content
        default:
            self.content = content
        }
    }
}

#Preview {
    ArtifactComposerView()
        .modelContainer(for: [Artifact.self, Draft.self])
}

