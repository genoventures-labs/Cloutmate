//
//  DraftEditorDrawer.swift
//  FocusOS
//
//  Draft editor drawer with AI enhancements, version history, and auto-save
//

import SwiftUI
import SwiftData
import Combine

struct DraftEditorDrawer: View {
    @Bindable var draft: Draft
    @Binding var isPresented: Bool
    
    var onClose: () -> Void
    var onPublish: () -> Void
    var onDelete: () -> Void
    var onExport: (() -> Void)?
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @State private var titleText: String
    @State private var bodyText: String
    @State private var editableTags: [String]
    @State private var newTagText: String = ""
    @State private var isDirty: Bool = false
    @State private var lastAutoSaveDate: Date?
    @State private var saveError: String?
    
    // AI enhancement
    @State private var showAISidecar: Bool = false
    @State private var aiSuggestions: [DraftEnhancementSuggestion] = []
    @State private var isRequestingAISuggestions: Bool = false
    @State private var suggestionError: String?
    
    // Version history
    @State private var showHistoryPopover: Bool = false
    @State private var selectedVersion: DraftVersion?
    
    // Summary
    @State private var auroraSummary: String?
    @State private var isGeneratingSummary: Bool = false
    
    private let autoSaveTimer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()
    
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case title
        case body
        case tags
    }
    
    init(
        draft: Draft,
        isPresented: Binding<Bool>,
        onClose: @escaping () -> Void,
        onPublish: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onExport: (() -> Void)? = nil
    ) {
        self._draft = Bindable(draft)
        self._isPresented = isPresented
        self.onClose = onClose
        self.onPublish = onPublish
        self.onDelete = onDelete
        self.onExport = onExport
        _titleText = State(initialValue: draft.title)
        _bodyText = State(initialValue: draft.caption)
        _editableTags = State(initialValue: draft.tags)
        _auroraSummary = State(initialValue: DraftEditorDrawer.summaryFromMetadata(draft.metadataTags))
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            mainEditor
            if showAISidecar {
                aiSidecar
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(width: showAISidecar ? 820 : 520)
        .background(.ultraThinMaterial)
        .transition(.move(edge: .trailing).combined(with: .opacity))
        .onReceive(autoSaveTimer) { _ in
            autoSave()
        }
        .onDisappear {
            autoSave(force: true)
        }
    }
    
    // MARK: - Main Editor
    
    private var mainEditor: some View {
        VStack(spacing: 0) {
            headerSection
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
            
            Divider()
                .overlay(Color.white.opacity(0.12))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    tagsSection
                    editorSection
                    if let summary = auroraSummary {
                        summarySection(summary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            
            Divider()
                .overlay(Color.white.opacity(0.08))
            
            footerSection
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
    }
    
    private var headerSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Draft title", text: $titleText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .focused($focusedField, equals: .title)
                    .onChange(of: titleText) { _, _ in markDirty() }
                    .onSubmit {
                        focusedField = .body
                    }
                
                HStack(spacing: 8) {
                    Label(draft.source ?? "User-Created", systemImage: "bolt.horizontal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(draft.lastEditedAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button {
                    if reduceMotion {
                        showAISidecar.toggle()
                    } else {
                        withAnimation {
                            showAISidecar.toggle()
                        }
                    }
                    if showAISidecar {
                        Task { await requestAISuggestions() }
                    }
                } label: {
                    Label("Ask Aurora", systemImage: "sparkles")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [.kosmicBlue.opacity(0.25), .kosmicPurple.opacity(0.25)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                        )
                }
                .buttonStyle(.plain)
                .help("Ask Aurora to improve this draft")
                
                Button {
                    showHistoryPopover.toggle()
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showHistoryPopover, arrowEdge: .top) {
                    versionHistoryPopover
                        .frame(minWidth: 320, minHeight: 360)
                }
                
                Button {
                    isPresented = false
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
    }
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.caption)
                .foregroundColor(.secondary)
            
            NoteTagFlowLayout(spacing: 8) {
                ForEach(editableTags, id: \.self) { tag in
                    HStack(spacing: 6) {
                        Text("#\(tag)")
                            .font(.caption)
                            .fontWeight(.medium)
                        Button {
                            removeTag(tag)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.kosmicPurple.opacity(0.15))
                    .foregroundColor(.kosmicPurple)
                    .cornerRadius(8)
                }
                
                TextField("Add tag", text: $newTagText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    .focused($focusedField, equals: .tags)
                    .onSubmit {
                        commitNewTag()
                    }
                    .onChange(of: newTagText) { _, newValue in
                        if newValue.contains(",") {
                            commitNewTag()
                        }
                    }
                    .frame(height: 32)
            }
        }
    }
    
    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Content")
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextEditor(text: $bodyText)
                .font(.system(size: 15, weight: .regular, design: .default))
                .focused($focusedField, equals: .body)
                .frame(minHeight: 320)
                .scrollContentBackground(.hidden)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .onChange(of: bodyText) { _, _ in markDirty() }
                .onTapGesture {
                    focusedField = .body
                }
            
            if let error = saveError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else if let date = lastAutoSaveDate {
                Label("Auto-saved \(RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date()))", systemImage: "checkmark.circle")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func summarySection(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Aurora Summary", systemImage: "sun.max")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(LinearGradient(colors: [.kosmicBlue, .kosmicPurple], startPoint: .leading, endPoint: .trailing))
                Spacer()
                if isGeneratingSummary {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.6)
                } else {
                    Button("Refresh") {
                        Task { await generateSummary() }
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                }
            }
            Text(summary)
                .font(.callout)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(colors: [.kosmicBlue.opacity(0.4), .kosmicPurple.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
    }
    
    private var footerSection: some View {
        HStack(spacing: 12) {
            GlassButton("Save", icon: "tray.and.arrow.down", role: .accent) {
                saveDraft(auto: false)
            }
            .disabled(!isDirty)
            
            GlassButton("Export", icon: "square.and.arrow.up") {
                onExport?()
            }
            
            GlassButton("Publish", icon: "paperplane.fill", role: .success) {
                saveDraft(auto: false)
                onPublish()
            }
            
            Spacer()
            
            GlassButton("Delete", icon: "trash", role: .danger) {
                onDelete()
            }
        }
    }
    
    // MARK: - AI Sidecar
    
    private var aiSidecar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Aurora Suggestions", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Button {
                    if reduceMotion {
                        showAISidecar = false
                    } else {
                        withAnimation {
                            showAISidecar = false
                        }
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            
            if isRequestingAISuggestions {
                VStack(spacing: 12) {
                    ProgressView("Asking Aurora…")
                        .progressViewStyle(.circular)
                    Text("Aurora is reviewing tone, clarity, and momentum.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if let error = suggestionError {
                VStack(spacing: 12) {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Button("Try again") {
                        Task { await requestAISuggestions() }
                    }
                    .font(.caption)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if aiSuggestions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "wand.and.stars.inverse")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No suggestions yet. Ask Aurora to analyze your draft.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(aiSuggestions) { suggestion in
                            suggestionCard(suggestion)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 300)
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(colors: [.kosmicPurple.opacity(0.3), .kosmicBlue.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
        .padding(.trailing, 4)
    }
    
    private func suggestionCard(_ suggestion: DraftEnhancementSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(suggestion.title)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(suggestion.detail)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let replacement = suggestion.replacement {
                Button("Apply suggestion") {
                    applySuggestion(replacement)
                }
                .font(.caption)
                .buttonStyle(.borderedProminent)
                .tint(.kosmicBlue)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
    }
    
    // MARK: - Version History
    
    private var versionHistoryPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Version History")
                .font(.headline)
            
            if draft.versionHistory.isEmpty {
                Text("No saved versions yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 40)
            } else {
                List(draft.versionHistory.reversed()) { version in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(version.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(version.timestamp, format: .dateTime.month().day().hour().minute())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Button("Restore") {
                                restore(version: version)
                            }
                            .font(.caption)
                            
                            Button("Duplicate") {
                                duplicate(version: version)
                            }
                            .font(.caption)
                            
                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func markDirty() {
        isDirty = true
    }
    
    private func commitNewTag() {
        let trimmed = newTagText
            .replacingOccurrences(of: ",", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            newTagText = ""
            return
        }
        trimmed
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .forEach { tag in
                if !editableTags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
                    editableTags.append(tag)
                    markDirty()
                }
            }
        newTagText = ""
    }
    
    private func removeTag(_ tag: String) {
        editableTags.removeAll { $0 == tag }
        markDirty()
    }
    
    private func applySuggestion(_ replacement: String) {
        bodyText = replacement
        markDirty()
    }
    
    private func saveDraft(auto: Bool) {
        guard isDirty || auto else { return }
        
        let trimmedTitle = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.title = trimmedTitle
        draft.caption = bodyText
        draft.tags = editableTags
        draft.lastEditedAt = Date()
        draft.refreshContentSignals()
        draft.refreshWordMetrics()
        
        if !auto {
            draft.appendVersionHistory(summary: auroraSummary)
        }
        
        do {
            try modelContext.save()
            isDirty = false
            lastAutoSaveDate = Date()
            saveError = nil
            if !auto {
                Task { await generateSummary() }
            }
        } catch {
            saveError = "Unable to save draft: \(error.localizedDescription)"
        }
    }
    
    private func autoSave(force: Bool = false) {
        guard force || isDirty else { return }
        saveDraft(auto: true)
    }
    
    private func restore(version: DraftVersion) {
        titleText = version.title
        bodyText = version.caption
        editableTags = version.tags
        auroraSummary = version.summary
        markDirty()
        saveDraft(auto: false)
    }
    
    private func duplicate(version: DraftVersion) {
        let duplicate = Draft(
            title: version.title,
            caption: version.caption,
            mediaURLs: [],
            tags: version.tags,
            notes: version.notes
        )
        duplicate.metadataTags = version.metadataTags
        duplicate.wordCount = version.wordCount
        duplicate.lastEditedAt = Date()
        modelContext.insert(duplicate)
        try? modelContext.save()
    }
    
    private func requestAISuggestions() async {
        guard !bodyText.isEmpty else {
            aiSuggestions = []
            return
        }
        isRequestingAISuggestions = true
        suggestionError = nil
        do {
            let suggestions = try await DraftEnhancementService.shared.requestImprovement(
                for: draft,
                title: titleText,
                content: bodyText,
                tags: editableTags
            )
            await MainActor.run {
                self.aiSuggestions = suggestions
                self.isRequestingAISuggestions = false
            }
        } catch {
            await MainActor.run {
                self.suggestionError = error.localizedDescription
                self.isRequestingAISuggestions = false
            }
        }
    }
    
    private func generateSummary() async {
        guard !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            auroraSummary = nil
            return
        }
        await MainActor.run {
            isGeneratingSummary = true
        }
        do {
            let summary = try await DraftEnhancementService.shared.generateSummary(
                for: draft,
                title: titleText,
                content: bodyText
            )
            await MainActor.run {
                self.auroraSummary = summary
                self.isGeneratingSummary = false
                self.storeSummaryInMetadata(summary)
            }
        } catch {
            await MainActor.run {
                self.isGeneratingSummary = false
            }
        }
    }
    
    private func storeSummaryInMetadata(_ summary: String) {
        var tags = draft.metadataTags.filter { !$0.hasPrefix("Summary::") }
        tags.append("Summary::\(summary)")
        draft.metadataTags = tags
        try? modelContext.save()
    }
    
    private static func summaryFromMetadata(_ metadataTags: [String]) -> String? {
        metadataTags.first(where: { $0.hasPrefix("Summary::") })?.replacingOccurrences(of: "Summary::", with: "")
    }
}

// MARK: - Utilities

private extension RelativeDateTimeFormatter {
    static let relativeMedium: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}

// MARK: - Flow Layout for Tags

#Preview {
    let draft = Draft(
        title: "Aurora Weekly Recap",
        caption: """
        Aurora, can you summarize our weekly progress and prepare a momentum update for the core team?
        """,
        tags: ["recap", "team", "shared"],
        notes: "Keep tone calm and encouraging."
    )
    draft.metadataTags = ["AI"]
    draft.wordCount = 128
    draft.source = "AI Assistant"
    
    return DraftEditorDrawer(
        draft: draft,
        isPresented: .constant(true),
        onClose: {},
        onPublish: {},
        onDelete: {},
        onExport: {}
    )
    .frame(height: 640)
    .environmentObject(GlassColorSystem())
    .modelContainer(for: [Draft.self])
}

