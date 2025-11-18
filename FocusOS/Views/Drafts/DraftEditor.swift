//
//  DraftEditor.swift
//  FocusOS
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import FocusOSShared

struct DraftEditor: View {
    @Bindable var draft: Draft
    @State private var showComposer = false
    @State private var showSaveConfirmation = false
    @FocusState private var isContentFocused: Bool
    @State private var showAIPopover = false
    @State private var showAISelectionSheet = false
    @State private var aiGeneratedItems: [AIGeneratedItem] = []
    @State private var selectedAITool: AITool?
    @State private var showAIPromptDialog = false
    @State private var userPromptText = ""
    @State private var isAIGenerating = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Welcome message for new drafts
                if draft.caption.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.title3)
                        Text("Start writing your content below")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.08))
                    .cornerRadius(8)
                }
                
                // Content editor
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "pencil.and.list.clipboard")
                            .foregroundColor(.accentColor)
                            .font(.headline)
                        Text("Content")
                            .font(.headline)
                        
                        Spacer()
                        
                        // Voice Input Button
                        VoiceInputButton(text: $draft.caption)
                        
                        // AI Assistant Button (only show if AI is enabled)
                        if AISettings.shared.isAIEnabled {
                            Button(action: {
                                if !isAIGenerating {
                                    showAIPopover.toggle()
                                }
                            }) {
                                HStack(spacing: 6) {
                                    if isAIGenerating {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                    }
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.kosmicBlue)
                                        .font(.headline)
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
                        
                        Text("\(draft.caption.count) characters")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.08))
                            .cornerRadius(6)
                    }
                    
                    ZStack(alignment: .bottomTrailing) {
                        GlassPanel(
                            tier: .contentCard,
                            cornerRadius: 14,
                            tintColor: isContentFocused ? Color.kosmicBlue.opacity(0.1) : nil
                        ) {
                            ZStack(alignment: .topLeading) {
                                if draft.caption.isEmpty {
                                    Text("Write your post content here...")
                                        .foregroundColor(.secondary.opacity(0.6))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .allowsHitTesting(false)
                                }
                                
                                TextEditor(text: $draft.caption)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 150)
                                    .padding(12)
                            }
                            .overlay(
                                // Cursor trail light effect
                                Group {
                                    if isContentFocused {
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [Color.kosmicBlue.opacity(0.3), Color.kosmicPurple.opacity(0.3)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 2
                                            )
                                    }
                                }
                            )
                        }
                        .focused($isContentFocused)
                        .animation(GlassMotion.Easing.spring, value: isContentFocused)
                    }
                }
                
                // Tags
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.headline)
                    
                    TagsView(tags: $draft.tags)
                        .padding(12)
                        .glassPanel(tier: .contentCard, cornerRadius: 12)
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                // Action Bar
                HStack(spacing: 12) {
                    Button("Schedule Post") {
                        showComposer = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Spacer()
                    
                    if showSaveConfirmation {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.kosmicGreen)
                            Text("Saved")
                                .font(.caption)
                                .foregroundColor(.kosmicGreen)
                        }
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                Divider()
                    .padding(.bottom, 8)
                
                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "note.text")
                            .foregroundColor(.accentColor)
                            .font(.headline)
                        Text("Notes")
                            .font(.headline)
                        
                        Spacer()
                        
                        if draft.notes?.isEmpty == false {
                            Text("Optional")
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.6))
                                .italic()
                        }
                    }
                    
                    GlassPanel(tier: .contentCard, cornerRadius: 14) {
                        ZStack(alignment: .topLeading) {
                            if draft.notes?.isEmpty != false {
                                Text("Add any additional notes or reminders for this draft...")
                                    .foregroundColor(.secondary.opacity(0.5))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .allowsHitTesting(false)
                            }
                            
                            TextEditor(text: Binding(
                                get: { draft.notes ?? "" },
                                set: { draft.notes = $0.isEmpty ? nil : $0 }
                            ))
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 80)
                            .padding(12)
                        }
                    }
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $showComposer) {
            ComposerWindow(draft: draft)
        }
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
        .animation(.easeInOut(duration: 0.2), value: showSaveConfirmation)
        .background(Color(.windowBackgroundColor))
        .onAppear {
            // Auto-focus content field for new drafts
            if draft.caption.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isContentFocused = true
                }
            }
        }
    }
    
    func convertToScheduledPost() {
        showComposer = true
    }
    
    private func handleAITool(_ tool: AITool, userPrompt: String) {
        isAIGenerating = true
        
		_Concurrency.Task {
            // Use the user's prompt instead of the draft caption
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
            let lowercaseLine = line.lowercased().trimmingCharacters(in: CharacterSet.whitespaces)
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
        while let lastLine = filteredLines.last, !lastLine.trimmingCharacters(in: CharacterSet.whitespaces).isEmpty {
            let lowercaseLast = lastLine.lowercased().trimmingCharacters(in: CharacterSet.whitespaces)
            let outroKeywords = ["hope this", "let me know", "feel free", "if you need", "any other", "anything else", "good luck", "best of luck"]
            if outroKeywords.contains(where: { lowercaseLast.contains($0) }) {
                filteredLines.removeLast()
            } else {
                break
            }
        }
        
        cleaned = filteredLines.joined(separator: "\n")
        
        // Remove headers (lines starting with #)
        filteredLines = cleaned.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: CharacterSet.whitespaces).hasPrefix("#") }
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
        cleaned = cleaned.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        return cleaned
    }
    
    private func insertAIContent(_ content: String, tool: AITool) {
        switch tool {
        case .improveText, .generateCaptions:
            draft.caption = content
        case .suggestHashtags:
            draft.caption += "\n\n" + content
        case .brainstorm:
            // For brainstorming, content comes from selection
            draft.caption = content
        default:
            draft.caption = content
        }
    }
    

}

struct TagsView: View {
    @Binding var tags: [String]
    @State private var newTag = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Existing tags
            if !tags.isEmpty {
                DraftEditorFlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(text: tag) {
                            tags.removeAll { $0 == tag }
                        }
                    }
                }
            }
            
            // Add tag field
            HStack {
                TextField("Add tag...", text: $newTag)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addTag()
                    }
                
                Button(action: addTag) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
                .disabled(newTag.isEmpty)
                .buttonStyle(.plain)
            }
        }
    }
    
    private func addTag() {
        guard !newTag.isEmpty, !tags.contains(newTag) else { return }
        tags.append(newTag)
        newTag = ""
    }
}

struct TagChip: View {
    let text: String
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial)
        .foregroundColor(.primary)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
    }
}

struct DraftEditorFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                     y: bounds.minY + result.frames[index].minY),
                          proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var current: CGPoint = .zero
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if current.x + size.width > maxWidth && current.x > 0 {
                    current.x = 0
                    current.y += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(origin: current, size: size))
                lineHeight = max(lineHeight, size.height)
                current.x += size.width + spacing
            }
            
            self.size = CGSize(
                width: subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0,
                height: current.y + lineHeight
            )
        }
    }
}

#Preview {
    DraftEditor(draft: Draft(caption: "Sample draft"))
}

