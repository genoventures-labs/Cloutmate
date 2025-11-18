//
//  DraftPublishingSheet.swift
//  FocusOS
//
//  Publishing flow for Drafts V2 — exports to Notes, Resources, AI Assistant, or external formats
//

import SwiftUI
import SwiftData

struct DraftPublishingSheet: View {
    @Bindable var draft: Draft
    @Binding var isPresented: Bool
    
    var onDismiss: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityGlassManager) private var accessibilityManager
    
    @State private var selectedDestination: PublishingDestination = .notes
    @State private var externalFormat: ExternalExportFormat = .markdown
    @State private var includeCaptionGenerator: Bool = false
    @State private var generatedCaption: String?
    @State private var generatedTitles: [String] = []
    @State private var selectedTitleVariant: String?
    @State private var publishStatusMessage: String?
    @State private var isPublishing: Bool = false
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    
    @State private var destinationNotesTitle: String = ""
    @State private var destinationNotesTags: String = ""
    
    @State private var customExportFileName: String = ""
    
    private let titleSuggestionLimit: Int = 3
    
    init(
        draft: Draft,
        isPresented: Binding<Bool>,
        onDismiss: @escaping () -> Void
    ) {
        self._draft = Bindable(draft)
        self._isPresented = isPresented
        self.onDismiss = onDismiss
        _destinationNotesTitle = State(initialValue: draft.title)
        _destinationNotesTags = State(initialValue: draft.tags.joined(separator: ", "))
        _customExportFileName = State(initialValue: draft.displayTitle.replacingOccurrences(of: " ", with: "-"))
    }
    
    private var titleGradient: LinearGradient {
        if accessibilityManager.performanceMode == .balanced {
            return LinearGradient(
                colors: [.primary.opacity(0.85), .primary.opacity(0.85)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        return LinearGradient(colors: [.kosmicBlue, .kosmicPurple], startPoint: .leading, endPoint: .trailing)
    }
    
    private var toastGradient: LinearGradient {
        if accessibilityManager.performanceMode == .balanced {
            return LinearGradient(
                colors: [.primary.opacity(0.6), .primary.opacity(0.6)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        return LinearGradient(colors: [.kosmicBlue, .kosmicPurple], startPoint: .leading, endPoint: .trailing)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                destinationPicker
                destinationDetails
                titleSuggestionsSection
                captionGeneratorSection
                Spacer()
                footerButtons
            }
            .padding(24)
            .frame(width: 520, height: 640)
            .background(glassColorSystem.cardElevated())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        close()
                    }
                }
            }
            .overlay(toastView, alignment: .top)
            .task {
                await fetchTitleSuggestions()
            }
        }
    }
    
    // MARK: - Sections
    
    private var destinationPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Publish Draft")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(titleGradient)
            
            Picker("Destination", selection: $selectedDestination) {
                ForEach(PublishingDestination.allCases) { destination in
                    Label(destination.displayName, systemImage: destination.icon)
                        .tag(destination)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    @ViewBuilder
    private var destinationDetails: some View {
        switch selectedDestination {
        case .notes:
            NotesDestinationView(
                title: $destinationNotesTitle,
                tags: $destinationNotesTags
            )
        case .resources:
            ResourcesDestinationView(
                title: $destinationNotesTitle,
                tags: $destinationNotesTags
            )
        case .aiAssistant:
            AIAssistantDestinationView(draft: draft)
        case .external:
            ExternalDestinationView(
                format: $externalFormat,
                fileName: $customExportFileName
            )
        case .resourcesArchive:
            ArchiveDestinationView()
        }
    }
    
    @ViewBuilder
    private var titleSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Aurora Title Variants", systemImage: "textformat.alt")
                    .font(.headline)
                Spacer()
                Button("Refresh") {
                    Task { await fetchTitleSuggestions(force: true) }
                }
                .font(.caption)
            }
            
            if generatedTitles.isEmpty {
                Text("Aurora is analyzing the draft to propose title options.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(generatedTitles, id: \.self) { suggestion in
                    Button {
                        selectedTitleVariant = suggestion
                    } label: {
                        HStack {
                            Image(systemName: selectedTitleVariant == suggestion ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedTitleVariant == suggestion ? .kosmicBlue : .secondary)
                            Text(suggestion)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var captionGeneratorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $includeCaptionGenerator.animation()) {
                Label("Generate caption", systemImage: "sparkles.tv")
                    .font(.headline)
            }
            
            if includeCaptionGenerator {
                Button {
                    Task { await generateCaption() }
                } label: {
                    Label("Generate caption", systemImage: "wand.and.stars")
                        .font(.subheadline)
                }
                .buttonStyle(.borderedProminent)
                .tint(.kosmicBlue)
                
                if let caption = generatedCaption {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Suggested caption")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(caption)
                            .font(.callout)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04))
                    )
                }
            }
        }
    }
    
    private var footerButtons: some View {
        HStack(spacing: 12) {
            GlassButton("Publish", icon: "paperplane.fill", role: .success) {
                Task { await publish() }
            }
            .disabled(isPublishing)
            
            GlassButton("Export Only", icon: "square.and.arrow.up") {
                Task { await publish(exportOnly: true) }
            }
            .disabled(isPublishing)
            
            Spacer()
            
            if isPublishing {
                ProgressView()
            }
        }
    }
    
    @ViewBuilder
    private var toastView: some View {
        if showToast {
            VStack {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.white)
                    Text(toastMessage)
                        .foregroundColor(.white)
                        .font(.subheadline)
                    Spacer()
                }
                .padding()
                .background(
                    toastGradient
                        .cornerRadius(12)
                )
                Spacer()
            }
            .padding(.top, 16)
            .padding(.horizontal, 24)
            .transition(reduceMotion ? .identity : .move(edge: .top).combined(with: .opacity))
        }
    }
    
    // MARK: - Actions
    
    private func close() {
        isPresented = false
        onDismiss()
    }
    
    private func publish(exportOnly: Bool = false) async {
        guard !isPublishing else { return }
        await MainActor.run {
            isPublishing = true
        }
        
        do {
            let result = try await DraftPublisherService.shared.publish(
                draft: draft,
                destination: selectedDestination,
                options: DraftPublishingOptions(
                    titleOverride: selectedTitleVariant,
                    generatedCaption: includeCaptionGenerator ? generatedCaption : nil,
                    notesTitle: destinationNotesTitle,
                    tags: destinationNotesTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
                    externalFormat: externalFormat,
                    fileName: customExportFileName,
                    exportOnly: exportOnly
                ),
                modelContext: modelContext
            )
            
            await MainActor.run {
                showToast(message: result.successMessage)
                isPublishing = false
                if !exportOnly {
                    close()
                }
            }
        } catch {
            await MainActor.run {
                publishStatusMessage = error.localizedDescription
                showToast(message: "Publishing failed: \(error.localizedDescription)")
                isPublishing = false
            }
        }
    }
    
    private func showToast(message: String) {
        toastMessage = message
        if reduceMotion {
            showToast = true
        } else {
            withAnimation {
                showToast = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            if reduceMotion {
                showToast = false
            } else {
                withAnimation {
                    showToast = false
                }
            }
        }
    }
    
    private func fetchTitleSuggestions(force: Bool = false) async {
        guard force || generatedTitles.isEmpty else { return }
        do {
            let titles = try await DraftEnhancementService.shared.suggestTitleVariants(
                for: draft,
                limit: titleSuggestionLimit
            )
            await MainActor.run {
                self.generatedTitles = titles
                if selectedTitleVariant == nil {
                    selectedTitleVariant = titles.first
                }
            }
        } catch {
            // Silently ignore; suggestions optional
        }
    }
    
    private func generateCaption() async {
        do {
            let caption = try await DraftEnhancementService.shared.generateCaption(for: draft)
            await MainActor.run {
                self.generatedCaption = caption
            }
        } catch {
            await MainActor.run {
                self.generatedCaption = "Aurora couldn't generate a caption right now. Try again shortly."
            }
        }
    }
}

// MARK: - Supporting Views

private struct NotesDestinationView: View {
    @Binding var title: String
    @Binding var tags: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Note title", text: $title)
                .textFieldStyle(.roundedBorder)
            TextField("Tags (comma separated)", text: $tags)
                .textFieldStyle(.roundedBorder)
            Text("Draft will appear in Notes with rich text formatting.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

private struct ResourcesDestinationView: View {
    @Binding var title: String
    @Binding var tags: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Resource title", text: $title)
                .textFieldStyle(.roundedBorder)
            TextField("Tags (comma separated)", text: $tags)
                .textFieldStyle(.roundedBorder)
            Text("Draft becomes a resource card, ready to link inside Aurora's knowledge graph.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

private struct AIAssistantDestinationView: View {
    let draft: Draft
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export to AI Assistant")
                .font(.headline)
            Text("Aurora will reference this draft in future conversations, keeping tone and context intact.")
                .font(.caption)
                .foregroundColor(.secondary)
            Divider()
            Text("Preview")
                .font(.caption)
                .foregroundColor(.secondary)
            ScrollView {
                Text(draft.caption.isEmpty ? draft.notes ?? "" : draft.caption)
                    .font(.callout)
            }
            .frame(height: 160)
            .padding()
            .background(Color.white.opacity(0.03))
            .cornerRadius(12)
        }
    }
}

private struct ExternalDestinationView: View {
    @Binding var format: ExternalExportFormat
    @Binding var fileName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Format", selection: $format) {
                ForEach(ExternalExportFormat.allCases) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .pickerStyle(.segmented)
            
            TextField("File name", text: $fileName)
                .textFieldStyle(.roundedBorder)
            
            Text("Exports to your Downloads folder with selected format.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

private struct ArchiveDestinationView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Archive Draft")
                .font(.headline)
            Text("Moves the draft to Archived state without exporting. Use when the idea is complete or no longer needed.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Destination Types

enum PublishingDestination: String, CaseIterable, Identifiable {
    case notes
    case resources
    case aiAssistant
    case external
    case resourcesArchive
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .notes: return "Notes"
        case .resources: return "Resources"
        case .aiAssistant: return "AI Assistant"
        case .external: return "External"
        case .resourcesArchive: return "Archive"
        }
    }
    
    var icon: String {
        switch self {
        case .notes: return "note.text"
        case .resources: return "books.vertical"
        case .aiAssistant: return "bolt.horizontal"
        case .external: return "square.and.arrow.up"
        case .resourcesArchive: return "archivebox"
        }
    }
}

enum ExternalExportFormat: String, CaseIterable, Identifiable {
    case markdown
    case pdf
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .markdown: return "Markdown"
        case .pdf: return "PDF"
        }
    }
}

struct DraftPublishingOptions {
    let titleOverride: String?
    let generatedCaption: String?
    let notesTitle: String
    let tags: [String]
    let externalFormat: ExternalExportFormat
    let fileName: String
    let exportOnly: Bool
}

struct DraftPublishingResult {
    let successMessage: String
}

#Preview {
    let draft = Draft(
        title: "Launch Momentum Update",
        caption: "This is the body of the draft, ready to be exported into Notes or shared with Aurora.",
        tags: ["launch", "update"],
        notes: "Ensure we highlight momentum and update tone."
    )
    draft.source = "AI Assistant"
    return DraftPublishingSheet(
        draft: draft,
        isPresented: .constant(true),
        onDismiss: {}
    )
    .environmentObject(GlassColorSystem())
    .modelContainer(for: [Draft.self])
}

