//
//  AdaptiveJournalView.swift
//  Cloutmate
//
//  Enhanced Adaptive Journal View - Weekly auto-entries with editing and export
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

struct AdaptiveJournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Journal> { journal in
            journal.entryType == "Personal Reflection"
        },
        sort: \Journal.entryDate,
        order: .reverse
    ) private var adaptiveEntries: [Journal]
    
    @State private var selectedEntry: Journal?
    @State private var isEditing = false
    @State private var editingContent = ""
    @State private var editingTitle = ""
    @State private var showingExportSheet = false
    @State private var exportFormat: ExportFormat = .markdown
    @State private var isGenerating = false
    
    enum ExportFormat: String, CaseIterable {
        case markdown = "Markdown"
        case pdf = "PDF"
        case digest = "Year in Review"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            if adaptiveEntries.isEmpty {
                emptyState
            } else {
                contentSection
            }
        }
        .background(Color(.windowBackgroundColor))
        .sheet(item: $selectedEntry) { entry in
            AdaptiveJournalDetailView(
                entry: entry,
                isEditing: $isEditing,
                editingContent: $editingContent,
                editingTitle: $editingTitle,
                onSave: {
                    saveEntry(entry)
                }
            )
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportOptionsSheet(
                entries: adaptiveEntries,
                format: $exportFormat,
                onExport: { format in
                    exportEntries(format: format)
                }
            )
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Adaptive Journal")
                        .font(.system(size: 28, weight: .bold))
                    
                    Text("Weekly auto-generated reflections with your story")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: generateWeeklyEntry) {
                        Label("Generate Weekly Entry", systemImage: "sparkles")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isGenerating)
                    
                    Menu {
                        Button("Export as Markdown") {
                            exportFormat = .markdown
                            showingExportSheet = true
                        }
                        Button("Export as PDF") {
                            exportFormat = .pdf
                            showingExportSheet = true
                        }
                        Button("Year in Review Digest") {
                            exportFormat = .digest
                            showingExportSheet = true
                        }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
            }
            
            if !adaptiveEntries.isEmpty {
                Text("\(adaptiveEntries.count) adaptive entr\(adaptiveEntries.count == 1 ? "y" : "ies")")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
    }
    
    private var contentSection: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(adaptiveEntries) { entry in
                    AdaptiveJournalCard(entry: entry) {
                        selectedEntry = entry
                        editingTitle = entry.title
                        editingContent = entry.content
                    }
                }
            }
            .padding(24)
        }
    }
    
    private var emptyState: some View {
        ContentUnavailableView(
            "No Adaptive Entries",
            systemImage: "book.fill",
            description: Text("Generate your first weekly reflection to see adaptive journal entries here.")
        )
        .frame(maxHeight: .infinity)
    }
    
    private func generateWeeklyEntry() {
        isGenerating = true
        
        Task {
            do {
                _ = try await AdaptiveJournalService.shared.generateWeeklyEntry(
                    modelContext: modelContext
                )
                await MainActor.run {
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                }
                print("Failed to generate weekly entry: \(error)")
            }
        }
    }
    
    private func saveEntry(_ entry: Journal) {
        entry.title = editingTitle
        entry.content = editingContent
        entry.updatedAt = Date()
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save entry: \(error)")
        }
    }
    
    private func exportEntries(format: ExportFormat) {
        switch format {
        case .markdown:
            exportAsMarkdown()
        case .pdf:
            exportAsPDF()
        case .digest:
            exportAsDigest()
        }
    }
    
    private func exportAsMarkdown() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "Adaptive Journal - \(Date().formatted(date: .numeric, time: .omitted)).md"
        
        if panel.runModal() == .OK {
            guard let url = panel.url else { return }
            
            var markdown = "# Adaptive Journal\n\n"
            markdown += "Generated: \(Date().formatted(date: .complete, time: .shortened))\n\n"
            markdown += "---\n\n"
            
            for entry in adaptiveEntries {
                markdown += "## \(entry.title)\n\n"
                markdown += "**Date:** \(entry.entryDate.formatted(date: .complete, time: .omitted))\n\n"
                markdown += "\(entry.content)\n\n"
                markdown += "---\n\n"
            }
            
            do {
                try markdown.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("Failed to export markdown: \(error)")
            }
        }
    }
    
    private func exportAsPDF() {
        // PDF export implementation would go here
        // For now, use the same as markdown but with PDF formatting
        exportAsMarkdown() // Placeholder
    }
    
    private func exportAsDigest() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "Year in Review - \(Date().formatted(date: .numeric, time: .omitted)).md"
        
        if panel.runModal() == .OK {
            guard let url = panel.url else { return }
            
            // Generate year in review digest
            var digest = "# Year in Review\n\n"
            digest += "A narrative summary of your journey\n\n"
            digest += "---\n\n"
            
            // Group by month
            let calendar = Calendar.current
            let grouped = Dictionary(grouping: adaptiveEntries) { entry in
                calendar.component(.month, from: entry.entryDate)
            }
            
            for month in grouped.keys.sorted() {
                let entries = grouped[month] ?? []
                let monthName = calendar.monthSymbols[month - 1]
                digest += "## \(monthName)\n\n"
                
                for entry in entries {
                    digest += "### \(entry.title)\n\n"
                    digest += "\(entry.content.prefix(200))...\n\n"
                }
            }
            
            do {
                try digest.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("Failed to export digest: \(error)")
            }
        }
    }
}

// MARK: - Adaptive Journal Card

struct AdaptiveJournalCard: View {
    let entry: Journal
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(entry.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if entry.author == .aurora {
                        Label("Auto-Generated", systemImage: "sparkles")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(entry.entryDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(entry.content)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                // Stats integration
                if let stats = extractStats(from: entry.content) {
                    HStack(spacing: 16) {
                        ForEach(stats.prefix(3), id: \.key) { stat in
                            HStack(spacing: 4) {
                                Image(systemName: stat.icon)
                                    .font(.caption)
                                Text(stat.value)
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(16)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private func extractStats(from content: String) -> [(key: String, value: String, icon: String)]? {
        var stats: [(key: String, value: String, icon: String)] = []
        
        // Extract focus sessions
        if let focusMatch = content.range(of: #"(\d+)\s*focus\s*sessions?"#, options: .regularExpression) {
            let focusCount = String(content[focusMatch])
            stats.append(("Focus", focusCount, "timer"))
        }
        
        // Extract tasks completed
        if let taskMatch = content.range(of: #"(\d+)\s*tasks?\s*completed"#, options: .regularExpression) {
            let taskCount = String(content[taskMatch])
            stats.append(("Tasks", taskCount, "checkmark.circle"))
        }
        
        return stats.isEmpty ? nil : stats
    }
}

// MARK: - Adaptive Journal Detail View

struct AdaptiveJournalDetailView: View {
    let entry: Journal
    @Binding var isEditing: Bool
    @Binding var editingContent: String
    @Binding var editingTitle: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isEditing {
                        TextField("Title", text: $editingTitle)
                            .font(.title2.bold())
                            .textFieldStyle(.roundedBorder)
                        
                        TextEditor(text: $editingContent)
                            .font(.body)
                            .frame(minHeight: 400)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(8)
                    } else {
                        Text(entry.title)
                            .font(.title2.bold())
                        
                        Text(entry.content)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                    
                    // Timeline view of journal evolution
                    if entry.author == .aurora && entry.updatedAt > entry.createdAt {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Journal Evolution")
                                .font(.headline)
                            
                            HStack {
                                Text("Auto-Generated")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Edited")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(6)
                        }
                    }
                }
                .padding(24)
            }
            .navigationTitle(isEditing ? "Edit Entry" : "Journal Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isEditing {
                            isEditing = false
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if isEditing {
                        Button("Save") {
                            onSave()
                            isEditing = false
                        }
                    } else {
                        Button("Edit") {
                            isEditing = true
                        }
                    }
                }
            }
        }
        .frame(width: 700, height: 600)
    }
}

// MARK: - Export Options Sheet

struct ExportOptionsSheet: View {
    let entries: [Journal]
    @Binding var format: AdaptiveJournalView.ExportFormat
    let onExport: (AdaptiveJournalView.ExportFormat) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Export Adaptive Journal")
                    .font(.title2.bold())
                
                Text("Choose export format")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 12) {
                    ForEach(AdaptiveJournalView.ExportFormat.allCases, id: \.self) { exportFormat in
                        Button(action: {
                            format = exportFormat
                            onExport(exportFormat)
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: icon(for: exportFormat))
                                    .font(.title3)
                                VStack(alignment: .leading) {
                                    Text(exportFormat.rawValue)
                                        .font(.headline)
                                    Text(description(for: exportFormat))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(format == exportFormat ? Color.kosmicBlue.opacity(0.1) : Color.secondary.opacity(0.05))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("Export")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 500, height: 400)
    }
    
    private func icon(for format: AdaptiveJournalView.ExportFormat) -> String {
        switch format {
        case .markdown: return "doc.text"
        case .pdf: return "doc.fill"
        case .digest: return "book.fill"
        }
    }
    
    private func description(for format: AdaptiveJournalView.ExportFormat) -> String {
        switch format {
        case .markdown: return "Export as Markdown file"
        case .pdf: return "Export as PDF document"
        case .digest: return "Generate year in review summary"
        }
    }
}

#Preview {
    AdaptiveJournalView()
        .modelContainer(for: [Journal.self], inMemory: true)
}

