//
//  UnifiedJournalView.swift
//  Cloutmate
//
//  Journal V2 - Unified view with card-based layout and grouping
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers
import CloutmateShared

enum JournalGroupingMode: String, CaseIterable {
    case byDate = "Date"
    case byMood = "Mood"
}

struct UnifiedJournalView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Query(sort: \Journal.entryDate, order: .reverse) private var allJournals: [Journal]
    
    @State private var searchText: String = ""
    @State private var selectedFilter: JournalFilter = .all
    @State private var groupingMode: JournalGroupingMode = .byDate
    @State private var activeJournal: Journal?
    @State private var isDrawerVisible = false
    @State private var isCreatingJournal = false
    @State private var activeTemplate: JournalTemplate?
    @State private var expandedGroups: Set<String> = []
    @State private var showTimeline = false
    @State private var focusedJournalIndex: Int?
    @State private var isSelectionMode = false
    @State private var selectedJournalIDs: Set<UUID> = []
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isSearchFocused: Bool
    
    private var filteredJournals: [Journal] {
        var filtered = allJournals.filter { !$0.isArchived || selectedFilter == .all }
        
        // Apply filter
        switch selectedFilter {
        case .all:
            if selectedFilter != .all {
                filtered = filtered.filter { !$0.isArchived }
            }
        case .morning:
            filtered = filtered.filter { journal in
                let hour = Calendar.current.component(.hour, from: journal.entryDate)
                return hour >= 5 && hour < 12
            }
        case .evening:
            filtered = filtered.filter { journal in
                let hour = Calendar.current.component(.hour, from: journal.entryDate)
                return hour >= 17 && hour < 22
            }
        case .moodEntries:
            filtered = filtered.filter { $0.journalMood != .none }
        case .aiReflections:
            filtered = filtered.filter { journal in
                journal.aiGeneratedContent != nil && !journal.aiGeneratedContent!.isEmpty
            }
        }
        
        // Apply search
        if !searchText.isEmpty {
            filtered = filtered.filter { journal in
                journal.title.localizedCaseInsensitiveContains(searchText) ||
                journal.content.localizedCaseInsensitiveContains(searchText) ||
                journal.tags.joined(separator: " ").localizedCaseInsensitiveContains(searchText) ||
                journal.journalMood.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    
    private var sortedJournals: [Journal] {
        filteredJournals.sorted { $0.entryDate > $1.entryDate }
    }
    
    private var groupedJournals: [(key: String, journals: [Journal])] {
        let journalsToGroup = sortedJournals
        
        switch groupingMode {
        case .byDate:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            let groups = Dictionary(grouping: journalsToGroup) { journal in
                formatter.string(from: journal.entryDate)
            }
            return groups.map { (key: $0.key, journals: $0.value) }
                .sorted { lhs, rhs in
                    guard let lhsDate = formatter.date(from: lhs.key),
                          let rhsDate = formatter.date(from: rhs.key) else { return false }
                    return lhsDate > rhsDate
                }
            
        case .byMood:
            var groups: [String: [Journal]] = [:]
            for journal in journalsToGroup {
                let key = journal.journalMood == .none ? "No Mood" : journal.journalMood.rawValue
                groups[key, default: []].append(journal)
            }
            return groups.map { (key: $0.key, journals: $0.value) }
                .sorted { $0.key < $1.key }
        }
    }
    
    private var totalActiveJournals: Int {
        allJournals.filter { !$0.isArchived }.count
    }
    
    private var selectedJournals: [Journal] {
        filteredJournals.filter { selectedJournalIDs.contains($0.id) }
    }
    
    private var visibleSelectedJournalCount: Int {
        selectedJournals.count
    }
    
    private var isSelectionActive: Bool {
        isSelectionMode || !selectedJournalIDs.isEmpty
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(.windowBackgroundColor)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                contentView
            }
            .opacity(isDrawerVisible ? 0 : 1)
            
            if let journal = activeJournal, isDrawerVisible {
                JournalDetailDrawer(
                    journal: journal,
                    isPresented: Binding(
                        get: { isDrawerVisible },
                        set: { newValue in
                            withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                                isDrawerVisible = newValue
                            }
                        }
                    ),
                    template: isCreatingJournal ? activeTemplate : nil
                )
                .transition(.move(edge: .trailing))
            }
        }
        .overlay(alignment: .bottom) {
            if isSelectionActive && !isDrawerVisible {
                SelectionActionBar(
                    count: visibleSelectedJournalCount,
                    itemLabel: "journal",
                    actions: journalSelectionActions(),
                    onCancel: clearSelection,
                    onSelectAll: toggleSelectAll,
                    totalItems: filteredJournals.count
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openJournalEntry)) { notification in
            if let template = notification.object as? JournalTemplate {
                startCreatingJournal(template: template)
            } else if let journal = notification.object as? Journal {
                openDrawer(for: journal)
            }
        }
        .onAppear {
            setupKeyboardNavigation()
        }
        .onChange(of: searchText) { _, _ in
            pruneSelection()
        }
        .onChange(of: selectedFilter) { _, _ in
            pruneSelection()
        }
        .onChange(of: groupingMode) { _, _ in
            pruneSelection()
        }
        .onChange(of: isDrawerVisible) { _, newValue in
            if !newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if !isDrawerVisible {
                        activeJournal = nil
                        activeTemplate = nil
                        isCreatingJournal = false
                    }
                }
            }
        }
    }
    
    private var headerView: some View {
        JournalHeaderView(
            searchText: $searchText,
            selectedFilter: $selectedFilter,
            onCreate: startCreatingJournal,
            isSelectionMode: $isSelectionMode,
            selectionCount: visibleSelectedJournalCount,
            onToggleSelection: toggleSelectionMode
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
    
    @ViewBuilder
    private var contentView: some View {
        if sortedJournals.isEmpty {
            emptyState
        } else {
            ScrollView {
                ScrollViewReader { proxy in
                    LazyVStack(spacing: 24) {
                        // Timeline toggle
                        if !sortedJournals.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Button(action: {
                                    if !isSelectionActive {
                                        showTimeline.toggle()
                                    }
                                }) {
                                    HStack {
                                        Text("Emotional Timeline")
                                            .font(.system(.headline, design: .rounded))
                                            .fontWeight(.semibold)
                                        
                                        Spacer()
                                        
                                        Image(systemName: showTimeline ? "chevron.down" : "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                if showTimeline {
                                    JournalTimelineView(
                                        journals: sortedJournals,
                                        onEntryTap: { journal in
                                            openDrawer(for: journal)
                                        }
                                    )
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Grouped journals
                        ForEach(groupedJournals, id: \.key) { group in
                            JournalGroupSection(
                                title: group.key,
                                journals: group.journals,
                                isCollapsed: !expandedGroups.contains(group.key),
                                onToggleCollapse: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                        if expandedGroups.contains(group.key) {
                                            expandedGroups.remove(group.key)
                                        } else {
                                            expandedGroups.insert(group.key)
                                        }
                                    }
                                },
                                onJournalTap: { journal in
                                    openDrawer(for: journal)
                                },
                                onJournalEdit: { journal in
                                    openDrawer(for: journal)
                                },
                                onJournalDuplicate: { journal in
                                    duplicateJournal(journal)
                                },
                                onJournalExport: { journal in
                                    exportJournal(journal)
                                },
                                onJournalDelete: { journal in
                                    deleteJournal(journal)
                                },
                                selectionMode: isSelectionActive,
                                selectedJournalIDs: selectedJournalIDs,
                                onSelectionToggle: { journal in
                                    toggleJournalSelection(journal)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.fill")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No journal entries yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Start capturing your reflections.")
                .font(.body)
                .foregroundColor(.secondary)
            
            GlassButton("Create Entry", icon: "plus", style: .pill, role: .primary) {
                startCreatingJournal()
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func journalSelectionActions() -> [SelectionActionBar.Action] {
        let journals = selectedJournals
        guard !journals.isEmpty else { return [] }
        var actions: [SelectionActionBar.Action] = []
        actions.append(
            .init(title: "Archive", icon: "archivebox", role: .surface) {
                archiveSelectedJournals()
            }
        )
        actions.append(
            .init(title: "Delete", icon: "trash", role: .danger) {
                deleteSelectedJournals()
            }
        )
        return actions
    }
    
    private func toggleSelectionMode() {
        if isSelectionMode || !selectedJournalIDs.isEmpty {
            clearSelection()
        } else if !filteredJournals.isEmpty {
            isSelectionMode = true
            showTimeline = false
            if isDrawerVisible {
                withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                    isDrawerVisible = false
                }
            }
        }
    }
    
    private func toggleJournalSelection(_ journal: Journal) {
        if selectedJournalIDs.contains(journal.id) {
            selectedJournalIDs.remove(journal.id)
            if selectedJournalIDs.isEmpty {
                isSelectionMode = false
            }
        } else {
            if !isSelectionMode {
                isSelectionMode = true
                showTimeline = false
            }
            selectedJournalIDs.insert(journal.id)
        }
        if isSelectionActive {
            withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                isDrawerVisible = false
            }
        }
    }
    
    private func startCreatingJournal(template: JournalTemplate? = nil) {
        guard !isDrawerVisible else { return }
        
        let newJournal: Journal
        if let template {
            newJournal = Journal(
                title: "",
                content: template.content,
                entryDate: Date(),
                entryType: .reflection
            )
        } else {
            newJournal = Journal(title: "", content: "")
        }
        newJournal.author = .user
        modelContext.insert(newJournal)
        
        activeJournal = newJournal
        activeTemplate = template
        isCreatingJournal = true
        
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isDrawerVisible = true
        }
    }
    
    private func openDrawer(for journal: Journal) {
        guard !isSelectionActive else { return }
        
        activeJournal = journal
        activeTemplate = nil
        isCreatingJournal = false
        
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isDrawerVisible = true
        }
    }
    
    private func clearSelection() {
        selectedJournalIDs.removeAll()
        isSelectionMode = false
    }
    
    private func pruneSelection() {
        let visibleIDs = Set(filteredJournals.map(\.id))
        selectedJournalIDs = selectedJournalIDs.intersection(visibleIDs)
        if selectedJournalIDs.isEmpty {
            isSelectionMode = false
        }
    }
    
    private func archiveSelectedJournals() {
        let journals = selectedJournals
        guard !journals.isEmpty else { return }
        for journal in journals {
            journal.isArchived = true
            journal.updatedAt = Date()
        }
        try? modelContext.save()
        clearSelection()
    }
    
    private func deleteSelectedJournals() {
        let journals = selectedJournals
        guard !journals.isEmpty else { return }
        for journal in journals {
            modelContext.delete(journal)
        }
        try? modelContext.save()
        clearSelection()
    }
    
    private func toggleSelectAll() {
        let allVisibleIDs = Set(filteredJournals.map(\.id))
        if selectedJournalIDs == allVisibleIDs {
            // All selected, deselect all
            clearSelection()
        } else {
            // Not all selected, select all visible
            selectedJournalIDs = allVisibleIDs
            if !isSelectionMode {
                isSelectionMode = true
                showTimeline = false
                if isDrawerVisible {
                    withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                        isDrawerVisible = false
                    }
                }
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
        duplicated.author = journal.author
        modelContext.insert(duplicated)
        try? modelContext.save()
    }
    
    private func exportJournal(_ journal: Journal) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "journal-\(journal.entryDate.formatted(date: .numeric, time: .omitted)).txt"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            
            var content = "\(journal.title)\n\n"
            content += "Date: \(journal.entryDate.formatted())\n"
            content += "Mood: \(journal.journalMood.rawValue)\n"
            content += "Type: \(journal.journalEntryType.rawValue)\n\n"
            content += journal.content
            
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("Export error: \(error)")
            }
        }
    }
    
    private func archiveJournal(_ journal: Journal) {
        journal.isArchived = true
        try? modelContext.save()
        selectedJournalIDs.remove(journal.id)
        pruneSelection()
    }
    
    private func deleteJournal(_ journal: Journal) {
        modelContext.delete(journal)
        try? modelContext.save()
        selectedJournalIDs.remove(journal.id)
        pruneSelection()
    }
    
    private func setupKeyboardNavigation() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // ⌘N: Create new entry
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "n" {
                showCreateSheet = true
                return nil
            }
            
            // Escape: Close drawer
            if event.keyCode == 53 { // Escape key
                if showDrawer {
                    showDrawer = false
                    selectedJournal = nil
                    return nil
                }
            }
            
            // Enter: Open selected journal
            if event.keyCode == 36 && focusedJournalIndex != nil { // Enter key
                let journals = sortedJournals
                if let index = focusedJournalIndex, index < journals.count {
                    selectedJournal = journals[index]
                    showDrawer = true
                    return nil
                }
            }
            
            // Arrow keys: Navigate journals
            if event.keyCode == 126 { // Up arrow
                navigateJournals(direction: -1)
                return nil
            }
            if event.keyCode == 125 { // Down arrow
                navigateJournals(direction: 1)
                return nil
            }
            
            return event
        }
    }
    
    private func navigateJournals(direction: Int) {
        let journals = sortedJournals
        guard !journals.isEmpty else { return }
        
        let currentIndex = focusedJournalIndex ?? 0
        let newIndex = max(0, min(journals.count - 1, currentIndex + direction))
        focusedJournalIndex = newIndex
    }
}

// MARK: - Journal Group Section

struct JournalGroupSection: View {
    let title: String
    let journals: [Journal]
    let isCollapsed: Bool
    let onToggleCollapse: () -> Void
    let onJournalTap: (Journal) -> Void
    let onJournalEdit: (Journal) -> Void
    let onJournalDuplicate: (Journal) -> Void
    let onJournalExport: (Journal) -> Void
    let onJournalDelete: (Journal) -> Void
    let selectionMode: Bool
    let selectedJournalIDs: Set<UUID>
    let onSelectionToggle: (Journal) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Button(action: onToggleCollapse) {
                HStack {
                    Text(title)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.kosmicBlue, .kosmicPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Spacer()
                    
                    Text("\(journals.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            // Divider
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)
                .padding(.bottom, 4)
            
            // Journal cards
            if !isCollapsed {
                LazyVStack(spacing: 12) {
                    ForEach(journals) { journal in
                        JournalCardV2(
                            journal: journal,
                            selectionMode: selectionMode,
                            isSelected: selectedJournalIDs.contains(journal.id),
                            onSelectionToggle: { onSelectionToggle(journal) },
                            onTap: { onJournalTap(journal) },
                            onEdit: { onJournalEdit(journal) },
                            onDuplicate: { onJournalDuplicate(journal) },
                            onExport: { onJournalExport(journal) },
                            onDelete: { onJournalDelete(journal) }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    UnifiedJournalView()
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [Journal.self])
}

