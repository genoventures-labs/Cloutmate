//
//  ComposerWindow.swift
//  FocusOS
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit
import os.log
import FocusOSShared

struct ComposerWindow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let draft: Draft?
    let existingPost: FocusOSShared.Post?
    let prefilledDate: Date?
    let onSave: ((DraftConversionResult) -> Void)?
    let onClose: (() -> Void)?
    
    @State private var caption = ""
    @State private var scheduledDate: Date?
    @State private var tags: [String] = []
    @State private var isScheduled = false
    @State private var isPublishing = false
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
    @State private var analyticsRefreshID = UUID()
    
    init(
        draft: Draft? = nil,
        existingPost: FocusOSShared.Post? = nil,
        prefilledDate: Date? = nil,
        onSave: ((DraftConversionResult) -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.draft = draft
        self.existingPost = existingPost
        self.prefilledDate = prefilledDate
        self.onSave = onSave
        self.onClose = onClose
    }
    
    @State private var showMorphIn = false
    
    private var contentSectionHeader: some View {
        HStack {
            Text("Content")
                .font(.headline)
            
            Spacer()
            
            // AI Assistant Button (only show if AI is enabled)
            if AISettings.shared.isAIEnabled {
                AIAssistantButton
            }
            
            Text("\(caption.count) characters")
                .font(.caption)
                .foregroundColor(.secondary)
        }
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
                TextEditor(text: $caption)
                    .frame(minHeight: 150)
                    .scrollContentBackground(.hidden)
                    .padding(8)
            }
        }
    }
    
    private var scheduleSection: some View {
        Section("Schedule") {
            Toggle("Schedule for later", isOn: $isScheduled)
            
            if isScheduled {
                DatePicker("Scheduled Date & Time", selection: Binding(
                    get: { scheduledDate ?? Date() },
                    set: { scheduledDate = $0 }
                ))
                .datePickerStyle(.compact)
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
    private var aiSuggestionsSection: some View {
        if !caption.isEmpty {
            Section {
                PerformancePredictorPanel(post: createPreviewPost(), refreshID: analyticsRefreshID)
            }
        }
        
        if !caption.isEmpty {
            Section("Hashtag Suggestions") {
                HashtagSuggestionPanel(
                    caption: caption,
                    selectedHashtags: $tags
                )
            }
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
                    close()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(isScheduled ? "Schedule" : "Publish Now") {
                    if validateInput() {
                        savePost()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPublishing)
            }
        }
    }
    
    var body: some View {
        Form {
            contentSection
            scheduleSection
            mediaSection
            tagsSection
            aiSuggestionsSection
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
            // Bloom highlight when focused
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
            // Morph-in animation (scale from 0.96 → 1.0)
            withAnimation(GlassMotion.Easing.modalOpen) {
                showMorphIn = true
            }
            if let draft = draft {
                // Pre-fill with draft data
                caption = draft.caption
                tags = draft.tags
                // Convert mediaURLs string paths to URLs
                mediaURLs = draft.mediaURLs.compactMap { URL(string: $0) }
                // Draft will be scheduled, so enable scheduling by default
                isScheduled = true
            } else if let post = existingPost {
                // Pre-fill with existing post data
                caption = post.caption
                tags = post.tags
                mediaURLs = post.mediaURLs.compactMap { URL(fileURLWithPath: $0) }
                if let postScheduledDate = post.scheduledDate {
                    isScheduled = true
                    scheduledDate = postScheduledDate
                }
            } else if let date = prefilledDate {
                // Pre-fill with date from calendar double-click
                isScheduled = true
                scheduledDate = date
            }
        }
        .onChange(of: caption) { _, _ in
            triggerAnalyticsRefresh()
        }
        .onChange(of: tags) { _, _ in
            triggerAnalyticsRefresh()
        }
        .onChange(of: isScheduled) { _, _ in
            triggerAnalyticsRefresh()
        }
        .onChange(of: scheduledDate) { _, _ in
            triggerAnalyticsRefresh()
        }
    }
    
    private func triggerAnalyticsRefresh() {
        analyticsRefreshID = UUID()
    }
    
    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
    
    private func validateInput() -> Bool {
        validationError = nil
        
        if caption.isEmpty {
            validationError = "Caption cannot be empty"
            return false
        }
        
        if isScheduled && scheduledDate == nil {
            validationError = "Please select a scheduled date"
            return false
        }
        
        if isScheduled, let scheduledDate = scheduledDate, scheduledDate < Date() {
            validationError = "Scheduled date must be in the future"
            return false
        }
        
        return true
    }
    
    private func savePost() {
        isPublishing = true
        validationError = nil
        
        _Concurrency.Task {
            let post: FocusOSShared.Post
            
            if let existing = existingPost {
                // Update existing post
                post = existing
                post.caption = caption
                post.mediaURLs = mediaURLs.map { $0.path }
                post.scheduledDate = isScheduled ? scheduledDate : nil
                post.status = isScheduled ? PostStatus.scheduled.rawValue : PostStatus.publishing.rawValue
                post.tags = tags
                post.updatedAt = Date()
            } else {
                // Create new post using FocusOSShared.Post explicitly
                post = FocusOSShared.Post(
                    caption: caption,
                    mediaURLs: mediaURLs.map { $0.path },
                    scheduledDate: isScheduled ? scheduledDate : nil,
                    status: isScheduled ? PostStatus.scheduled.rawValue : PostStatus.publishing.rawValue,
                    tags: tags
                )
                
                modelContext.insert(post)
            }
            
            try? modelContext.save()
            
            if isScheduled {
                // Post is in SwiftData, helper will pick it up
                // Trigger immediate check to ensure helper sees it
                if scheduledDate != nil {
                    XPCService.shared.checkScheduledPosts()
                }
            } else {
                // Publish immediately using direct services for better performance
                await publishPostDirectly(post: post, context: modelContext)
            }
            
            isPublishing = false
            
            // Call completion callback if draft conversion
            if draft != nil, let onSave = onSave {
                let date = isScheduled ? (scheduledDate ?? Date()) : Date()
                let status = isScheduled ? PostStatus.scheduled : PostStatus.publishing
                onSave(DraftConversionResult(postID: post.id, status: status, date: date))
            }
            
            dismiss()
        }
    }
    
    private func publishPostDirectly(post: FocusOSShared.Post, context: ModelContext) async {
        // Note: Social media posting services were removed
        // This function is kept for compatibility but does not perform actual publishing
        post.postStatus = .failed
        post.lastError = "Social media posting has been removed. Use artifacts instead."
        try? context.save()
    }
    
    private func createPreviewPost() -> Post {
        // Create a temporary post for prediction
        let preview = Post(
            caption: caption,
            mediaURLs: mediaURLs.map { $0.path },
            scheduledDate: isScheduled ? scheduledDate : nil,
            status: PostStatus.draft.rawValue,
            tags: tags
        )
        return preview
    }
    
    private func handleAITool(_ tool: AITool, userPrompt: String) {
        isAIGenerating = true
        
        _Concurrency.Task {
            // Use the user's prompt instead of the caption
            let result = await AICreativeService.shared.executeTool(tool, input: userPrompt, context: "")
            
            // Clean the response - remove markdown and headers
            let cleanedResult = cleanAIResponse(result.result)
            
            // Parse response into list items
            let items = try await CoreResponseService.shared.parseListResponse(cleanedResult, tool: tool)
            
            // Convert to AIGeneratedItem
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
        
        // Remove intro lines (lines that contain phrases like "Here's", "Here are", etc. at the beginning)
        let introKeywords = ["here's", "here are", "here is", "here we", "here you", "following", "below are", "see below"]
        var filteredLines = lines.filter { line in
            let lowercaseLine = line.lowercased().trimmingCharacters(in: .whitespaces)
            // Skip empty lines
            if lowercaseLine.isEmpty { return true }
            // Skip lines that are just intro text
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
        
        // Remove outro lines (lines at the end that are explanatory/asking for feedback)
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
        
        // Remove headers (lines starting with #)
        filteredLines = cleaned.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
        cleaned = filteredLines.joined(separator: "\n")
        
        // Remove markdown bold and italic
        cleaned = cleaned.replacingOccurrences(of: #"\*\*([^*]+)\*\*"#, with: "$1", options: .regularExpression) // **bold**
        cleaned = cleaned.replacingOccurrences(of: #"(?<!\*)\*([^*]+)\*(?!\*)"#, with: "$1", options: .regularExpression) // *italic*
        
        // Remove markdown code blocks
        cleaned = cleaned.replacingOccurrences(of: #"```[\s\S]*?```"#, with: "", options: .regularExpression) // ```code blocks```
        cleaned = cleaned.replacingOccurrences(of: #"`([^`]+)`"#, with: "$1", options: .regularExpression) // `inline code`
        
        // Remove markdown links but keep text
        cleaned = cleaned.replacingOccurrences(of: #"\[([^\]]+)\]\([^\)]+\)"#, with: "$1", options: .regularExpression)
        
        // Trim whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
    
    private func insertAIContent(_ content: String, tool: AITool) {
        switch tool {
        case .improveText, .generateCaptions:
            caption = content
        case .suggestHashtags:
            caption += "\n\n" + content
        case .brainstorm:
            // For brainstorming, content comes from selection
            caption = content
        default:
            caption = content
        }
    }
    

}

struct MediaPreviewView: View {
    let url: URL
    let onRemove: () -> Void
    
    @State private var image: NSImage?
    @State private var loadError: Bool = false
    @State private var isLoading: Bool = true
    @State private var isHovered = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .glassPanel(tier: .contentCard, cornerRadius: 12)
                        .scaleEffect(isHovered ? 1.02 : 1.0)
                        .animation(GlassMotion.Easing.spring, value: isHovered)
                } else if loadError {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.2))
                        .overlay(
                            VStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.red)
                                Text("Failed")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        )
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            ProgressView()
                                .progressViewStyle(.circular)
                        )
                }
            }
            .frame(width: 120, height: 120)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .offset(x: 6, y: -6)
        }
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        DispatchQueue.main.async {
            // Start with loading state
            self.isLoading = true
            self.loadError = false
            
            // Load image asynchronously
            DispatchQueue.global(qos: .userInitiated).async { [url] in
                // Try loading with security scoped access for sandboxed URLs
                let isSecurityScoped = url.startAccessingSecurityScopedResource()
                
                var loadedImage: NSImage?
                var loadFailed = false
                
                // Check if file exists
                let fileManager = FileManager.default
                let filePath = url.path
                
                if !fileManager.fileExists(atPath: filePath) {
                    print("MediaPreviewView: File does not exist at path: \(filePath)")
                    loadFailed = true
                } else {
                    // Try different approaches for loading the image
                    if let nsImage = NSImage(contentsOfFile: filePath) {
                        loadedImage = nsImage
                        print("MediaPreviewView: Successfully loaded image from file path")
                    } else if let nsImage = NSImage(contentsOf: url) {
                        loadedImage = nsImage
                        print("MediaPreviewView: Successfully loaded image from URL")
                    } else {
                        print("MediaPreviewView: Failed to load image. Path: \(filePath), URL: \(url)")
                        loadFailed = true
                    }
                }
                
                // Stop accessing security scoped resource
                if isSecurityScoped {
                    url.stopAccessingSecurityScopedResource()
                }
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let loadedImage = loadedImage {
                        self.image = loadedImage
                    } else if loadFailed {
                        self.loadError = true
                    }
                }
            }
        }
    }
}



#Preview {
    ComposerWindow()
        .modelContainer(for: [Post.self, Draft.self])
}
