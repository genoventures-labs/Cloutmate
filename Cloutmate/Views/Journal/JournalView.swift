//
//  JournalView.swift
//  Cloutmate
//
//  Full-featured journaling experience
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Journal.entryDate, order: .reverse) private var allJournals: [Journal]
    @Query private var allNotes: [Note]
    @Query private var allAreas: [Area]
    @Query private var allProjects: [Project]
    
    @State private var searchText = ""
    @State private var selectedTags: Set<String> = []
    @State private var selectedEntryType: JournalEntryType?
    @State private var selectedMood: JournalMood?
    @State private var selectedJournals = Set<UUID>()
    @State private var showCreateSheet = false
    @State private var showJournalSheet = false
    @State private var showRecordingModal = false
    @State private var selectedJournal: Journal?
    
    var filteredJournals: [Journal] {
        var filtered = allJournals
        
        if !searchText.isEmpty {
            filtered = filtered.filter { journal in
                journal.title.localizedCaseInsensitiveContains(searchText) ||
                journal.content.localizedCaseInsensitiveContains(searchText) ||
                (journal.aiGeneratedContent?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                journal.tags.joined(separator: " ").localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if !selectedTags.isEmpty {
            filtered = filtered.filter { journal in
                !Set(journal.tags).isDisjoint(with: selectedTags)
            }
        }
        
        if let entryType = selectedEntryType {
            filtered = filtered.filter { $0.journalEntryType == entryType }
        }
        
        if let mood = selectedMood {
            filtered = filtered.filter { $0.journalMood == mood }
        }
        
        return filtered
    }
    
    var availableTags: [String] {
        Array(Set(allJournals.flatMap { $0.tags })).sorted()
    }
    
    private var searchAndFiltersSection: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search journal entries...", text: $searchText)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "All",
                        isSelected: selectedTags.isEmpty && selectedEntryType == nil && selectedMood == nil,
                        action: { 
                            selectedTags.removeAll()
                            selectedEntryType = nil
                            selectedMood = nil
                        }
                    )
                    
                    ForEach(JournalEntryType.allCases, id: \.self) { type in
                        FilterChip(
                            title: type.rawValue,
                            isSelected: selectedEntryType == type,
                            action: { 
                                selectedEntryType = selectedEntryType == type ? nil : type
                            }
                        )
                    }
                }
            }
            
            // Mood filter chips
            if !allJournals.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(JournalMood.allCases.filter { $0 != .none }, id: \.self) { mood in
                            FilterChip(
                                title: mood.rawValue,
                                isSelected: selectedMood == mood,
                                action: {
                                    selectedMood = selectedMood == mood ? nil : mood
                                }
                            )
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    private var tableSection: some View {
        Table(filteredJournals, selection: $selectedJournals) {
            TableColumn("Title") { journal in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: journal.journalEntryType.icon)
                            .font(.caption)
                            .foregroundColor(.pink)
                        Text(journal.title)
                            .font(.headline)
                            .lineLimit(1)
                    }
                    
                    if !journal.content.isEmpty {
                        Text(journal.content.prefix(100))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                .contextMenu {
                    Button("Edit") {
                        selectedJournal = journal
                        showJournalSheet = true
                    }
                    Button("Duplicate") {
                        duplicateJournal(journal)
                    }
                    Button("Archive") {
                        archiveJournal(journal)
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        deleteJournal(journal)
                    }
                }
            }
            .width(min: 200, ideal: 300)
            
            TableColumn("Type") { journal in
                HStack(spacing: 4) {
                    Image(systemName: journal.journalEntryType.icon)
                        .font(.caption)
                        .foregroundColor(.pink)
                    Text(journal.journalEntryType.rawValue)
                        .font(.caption)
                }
            }
            .width(min: 120)
            
            TableColumn("Mood") { journal in
                if journal.journalMood != .none {
                    Text(journal.journalMood.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(journal.journalMood.color).opacity(0.1))
                        .foregroundColor(Color(journal.journalMood.color))
                        .cornerRadius(4)
                } else {
                    Text("—")
                        .foregroundColor(.secondary)
                }
            }
            .width(min: 100)
            
            TableColumn("Tags") { journal in
                if !journal.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(journal.tags.prefix(3), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.pink.opacity(0.1))
                                    .foregroundColor(.pink)
                                    .cornerRadius(4)
                            }
                            if journal.tags.count > 3 {
                                Text("+\(journal.tags.count - 3)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } else {
                    Text("—")
                        .foregroundColor(.secondary)
                }
            }
            .width(min: 150)
            
            TableColumn("Date") { journal in
                Text(journal.entryDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .width(min: 120)
            
            TableColumn("Linked") { journal in
                let linkedCount = journal.linkedNoteIds.count + 
                                 journal.linkedAreaIds.count + 
                                 journal.linkedProjectIds.count +
                                 (journal.projectId != nil ? 1 : 0) +
                                 (journal.areaId != nil ? 1 : 0)
                
                if linkedCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "link")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text("\(linkedCount)")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                } else {
                    Text("—")
                        .foregroundColor(.secondary)
                }
            }
            .width(min: 80)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchAndFiltersSection
            
            if filteredJournals.isEmpty {
                ContentUnavailableView(
                    allJournals.isEmpty ? "No Journal Entries" : "No matches",
                    systemImage: "book.fill",
                    description: Text(allJournals.isEmpty ? "Create your first journal entry to get started" : "Try a different search or filter")
                )
                .frame(maxHeight: .infinity)
            } else {
                tableSection
            }
        }
        .background(Color(.windowBackgroundColor))
        .navigationTitle("Journal")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !selectedJournals.isEmpty {
                    Menu("Actions") {
                        Button("Export", systemImage: "square.and.arrow.up") {
                            exportSelectedJournals()
                        }
                        Button("Archive Selected", systemImage: "archivebox") {
                            archiveSelectedJournals()
                        }
                        Button("Delete Selected", systemImage: "trash") {
                            deleteSelectedJournals()
                        }
                    }
                }
                
                Button {
                    showRecordingModal = true
                } label: {
                    Label("Record Entry", systemImage: "mic")
                }
                
                Button("New Entry") {
                    showCreateSheet = true
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateJournalEntrySheet()
        }
        .sheet(isPresented: $showRecordingModal) {
            VoiceRecordModal(mode: .newEntry)
        }
        .sheet(isPresented: $showJournalSheet) {
            if let journal = selectedJournal {
                JournalDetailSheet(journal: journal)
            }
        }
    }
    
    private func duplicateJournal(_ journal: Journal) {
        let duplicated = Journal(
            title: "\(journal.title) (Copy)",
            content: journal.content,
            entryDate: Date(),
            entryType: journal.journalEntryType,
            mood: journal.journalMood,
            tags: journal.tags,
            projectId: journal.projectId,
            areaId: journal.areaId,
            linkedNoteIds: journal.linkedNoteIds,
            linkedAreaIds: journal.linkedAreaIds,
            linkedProjectIds: journal.linkedProjectIds
        )
        duplicated.aiPrompt = journal.aiPrompt
        duplicated.aiGeneratedContent = journal.aiGeneratedContent
        modelContext.insert(duplicated)
        try? modelContext.save()
    }
    
    private func archiveJournal(_ journal: Journal) {
        journal.isArchived = true
        if selectedJournals.contains(journal.id) {
            selectedJournals.remove(journal.id)
        }
        try? modelContext.save()
    }
    
    private func deleteJournal(_ journal: Journal) {
        modelContext.delete(journal)
        if selectedJournals.contains(journal.id) {
            selectedJournals.remove(journal.id)
        }
        try? modelContext.save()
    }
    
    private func archiveSelectedJournals() {
        let journalsToArchive = filteredJournals.filter { selectedJournals.contains($0.id) }
        for journal in journalsToArchive {
            journal.isArchived = true
        }
        selectedJournals.removeAll()
        try? modelContext.save()
    }
    
    private func deleteSelectedJournals() {
        let journalsToDelete = filteredJournals.filter { selectedJournals.contains($0.id) }
        for journal in journalsToDelete {
            modelContext.delete(journal)
        }
        selectedJournals.removeAll()
        try? modelContext.save()
    }
    
    private func exportSelectedJournals() {
        let selectedJournalsList = allJournals.filter { selectedJournals.contains($0.id) }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "cloutmate-journal-\(Date().formatted(date: .numeric, time: .omitted)).csv"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            
            var csvString = "Title,Content,Entry Type,Mood,Tags,Entry Date,Created At,AI Prompt,AI Generated Content\n"
            
            for journal in selectedJournalsList {
                let escapedTitle = journal.title.replacingOccurrences(of: "\"", with: "\"\"")
                let escapedContent = journal.content.replacingOccurrences(of: "\"", with: "\"\"")
                let escapedAIPrompt = (journal.aiPrompt ?? "").replacingOccurrences(of: "\"", with: "\"\"")
                let escapedAIContent = (journal.aiGeneratedContent ?? "").replacingOccurrences(of: "\"", with: "\"\"")
                let tags = journal.tags.joined(separator: "|")
                let entryDate = journal.entryDate.formatted()
                let createdAt = journal.createdAt.formatted()
                
                csvString += "\"\(escapedTitle)\",\"\(escapedContent)\",\(journal.entryType),\(journal.mood),\(tags),\(entryDate),\(createdAt),\"\(escapedAIPrompt)\",\"\(escapedAIContent)\"\n"
            }
            
            do {
                try csvString.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("Export error: \(error)")
            }
        }
    }
}

struct JournalDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let journal: Journal
    
    var body: some View {
        NavigationStack {
            JournalDetailView(journal: journal)
                .navigationTitle(journal.title)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

struct JournalDetailView: View {
    @Bindable var journal: Journal
    @Environment(\.modelContext) private var modelContext
    @State private var editingContent = ""
    @State private var editingTitle = ""
    @State private var showAIPanel = false
    @State private var showRecordToAppend = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Title", text: $editingTitle)
                    .font(.system(size: 28, weight: .bold))
                    .textFieldStyle(.plain)
                
                // Entry metadata
                HStack {
                    Label(journal.entryType, systemImage: journal.journalEntryType.icon)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if journal.journalMood != .none {
                        Label(journal.mood, systemImage: "heart.fill")
                            .font(.caption)
                            .foregroundColor(Color(journal.journalMood.color))
                    }
                    
                    Spacer()
                    
                    Text(journal.entryDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    Text("Content")
                        .font(.headline)
                    TextEditor(text: $editingContent)
                        .font(.body)
                        .frame(minHeight: 300)
                        .scrollContentBackground(.hidden)
                }
                
                // AI Generated Content
                if let aiContent = journal.aiGeneratedContent, !aiContent.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.blue)
                            Text("AI Generated Content")
                                .font(.headline)
                        }
                        Text(aiContent)
                            .font(.body)
                            .padding()
                            .background(Color.blue.opacity(0.05))
                            .cornerRadius(8)
                    }
                }
                
                // Tags
                if !journal.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.headline)
                        FlowLayout(spacing: 8) {
                            ForEach(journal.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.pink.opacity(0.1))
                                    .foregroundColor(.pink)
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
                
                // Linked items
                let linkedCount = journal.linkedNoteIds.count + 
                                 journal.linkedAreaIds.count + 
                                 journal.linkedProjectIds.count +
                                 (journal.projectId != nil ? 1 : 0) +
                                 (journal.areaId != nil ? 1 : 0)
                
                if linkedCount > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Linked Items")
                            .font(.headline)
                        Text("\(linkedCount) linked item(s)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(28)
        }
        .background(Color(.windowBackgroundColor))
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button(action: { showAIPanel.toggle() }) {
                    Label("AI Assistant", systemImage: "sparkles")
                }
                Button(action: { showRecordToAppend.toggle() }) {
                    Label("Voice", systemImage: "mic")
                }
            }
        }
        .sheet(isPresented: $showAIPanel) {
            JournalAIPanel(journal: journal)
        }
        .sheet(isPresented: $showRecordToAppend) {
            VoiceRecordModal(mode: .append(existing: journal))
        }
        .onAppear {
            editingContent = journal.content
            editingTitle = journal.title
        }
        .onChange(of: editingContent) { _, newValue in
            journal.content = newValue
            journal.updatedAt = Date()
            try? modelContext.save()
        }
        .onChange(of: editingTitle) { _, newValue in
            journal.title = newValue
            journal.updatedAt = Date()
            try? modelContext.save()
        }
    }
}

struct CreateJournalEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var content = ""
    @State private var entryType: JournalEntryType = .reflection
    @State private var mood: JournalMood = .none
    @State private var tags = ""
    @State private var entryDate = Date()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Entry Type
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Entry Type")
                            .font(.headline)
                        Picker("Entry Type", selection: $entryType) {
                            ForEach(JournalEntryType.allCases, id: \.self) { type in
                                Label(type.rawValue, systemImage: type.icon)
                                    .tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter entry title...", text: $title)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // Entry Date
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Entry Date")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        DatePicker("", selection: $entryDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                    }
                    
                    // Mood
                    if entryType == .reflection {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Mood")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("Mood", selection: $mood) {
                                ForEach(JournalMood.allCases, id: \.self) { moodOption in
                                    Text(moodOption.rawValue).tag(moodOption)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    
                    // Tags
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags (comma separated)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., daily, ideas, work", text: $tags)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // Content
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $content)
                            .font(.body)
                            .frame(minHeight: 300)
                            .glassPanel(tier: .contentCard, cornerRadius: 8)
                    }
                }
                .padding()
            }
            .navigationTitle("New Journal Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createJournal()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .frame(width: 700, height: 700)
    }
    
    private func createJournal() {
        let tagArray = tags.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let journal = Journal(
            title: title,
            content: content,
            entryDate: entryDate,
            entryType: entryType,
            mood: mood,
            tags: tagArray
        )
        
        modelContext.insert(journal)
        try? modelContext.save()
        dismiss()
    }
}

// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.width ?? .infinity,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: result.frames[index].minX + bounds.minX,
                                     y: result.frames[index].minY + bounds.minY),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var bounds = CGRect.zero
        var frames: [CGRect] = []
        var minX: CGFloat = 0
        var minY: CGFloat = 0
        var lineHeight: CGFloat = 0
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.bounds = CGRect(origin: .zero, size: CGSize(width: maxWidth, height: y + lineHeight))
        }
        
        var size: CGSize {
            bounds.size
        }
    }
}

// AI Panel with full functionality
struct JournalAIPanel: View {
    @Bindable var journal: Journal
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var aiPrompt = ""
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @Query(sort: \Journal.entryDate, order: .reverse) private var allJournals: [Journal]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Prompt input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AI Prompt")
                            .font(.headline)
                        TextField("e.g., Generate content ideas for my fitness area...", text: $aiPrompt, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                    }
                    
                    // Quick action buttons
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Actions")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            Button(action: { suggestReflectionPrompt() }) {
                                Label("Suggest Prompt", systemImage: "lightbulb")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            
                            Button(action: { generateContent() }) {
                                Label("Generate", systemImage: "sparkles")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(aiPrompt.isEmpty || isGenerating)
                        }
                        
                        Button(action: { analyzeEntries() }) {
                            Label("Analyze My Entries", systemImage: "chart.bar.doc.horizontal")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(allJournals.isEmpty || isGenerating)
                    }
                    
                    if isGenerating {
                        ProgressView()
                            .scaleEffect(1.5)
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // AI Generated Content preview
                    if let aiContent = journal.aiGeneratedContent, !aiContent.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("AI Generated Content")
                                .font(.headline)
                            Text(aiContent)
                                .font(.body)
                                .padding()
                                .background(Color.blue.opacity(0.05))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("AI Assistant")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(width: 600, height: 500)
        .onAppear {
            aiPrompt = journal.aiPrompt ?? ""
        }
    }
    
    private func suggestReflectionPrompt() {
        _Concurrency.Task { @MainActor in
            isGenerating = true
            errorMessage = nil
            
            let prompt = await JournalAIService.shared.suggestReflectionPrompt(for: journal.journalMood != .none ? journal.journalMood : nil)
            aiPrompt = prompt
            isGenerating = false
        }
    }
    
    private func generateContent() {
        _Concurrency.Task { @MainActor in
            isGenerating = true
            errorMessage = nil
            journal.aiPrompt = aiPrompt
            
            do {
                let content = try await JournalAIService.shared.generateJournalContent(
                    from: aiPrompt,
                    entryType: journal.journalEntryType,
                    context: journal.content
                )
                
                journal.aiGeneratedContent = content
                journal.updatedAt = Date()
                try? modelContext.save()
                isGenerating = false
            } catch {
                errorMessage = "Failed to generate content: \(error.localizedDescription)"
                isGenerating = false
            }
        }
    }
    
    private func analyzeEntries() {
        _Concurrency.Task { @MainActor in
            isGenerating = true
            errorMessage = nil
            
            do {
                let recentEntries = Array(allJournals.prefix(10))
                let analysis = try await JournalAIService.shared.analyzeJournalEntries(recentEntries)
                
                if journal.aiGeneratedContent?.isEmpty != false {
                    journal.aiGeneratedContent = analysis
                } else {
                    journal.aiGeneratedContent = (journal.aiGeneratedContent ?? "") + "\n\n## Recent Analysis\n\n\(analysis)"
                }
                journal.updatedAt = Date()
                try? modelContext.save()
                isGenerating = false
            } catch {
                errorMessage = "Failed to analyze entries: \(error.localizedDescription)"
                isGenerating = false
            }
        }
    }
}

#Preview {
    JournalView()
        .modelContainer(for: [Journal.self, Note.self, Area.self, Project.self])
}

