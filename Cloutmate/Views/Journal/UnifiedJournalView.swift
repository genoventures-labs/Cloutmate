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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Query(sort: \Journal.entryDate, order: .reverse) private var allJournals: [Journal]
    
    @State private var searchText: String = ""
    @State private var selectedFilter: JournalFilter = .all
    @State private var selectedViewMode: JournalViewMode = .list
    @State private var groupingMode: JournalGroupingMode = .byDate
    @State private var activeJournal: Journal?
    @State private var isDrawerVisible = false
    @State private var isCreatingJournal = false
    @State private var activeTemplate: JournalTemplate?
    @State private var pendingJournalDraft: JournalDraft?
    @State private var expandedGroups: Set<String> = []
    @State private var focusedJournalIndex: Int?
    @State private var isSelectionMode = false
    @State private var selectedJournalIDs: Set<UUID> = []
    
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
    
    private var headerSubtitle: String {
        let count = filteredJournals.count
        if count == 0 {
            return "No entries"
        } else if count == 1 {
            return "1 entry"
        } else {
            return "\(count) entries"
        }
    }
    
    var body: some View {
        ZStack {
            V2GlassContentScaffold(
                accentGradient: AuroraPalette.linearGradient(for: colorScheme),
                showsSidebar: false,
                header: { headerBar },
                content: { journalContent },
                sidebar: { EmptyView() }
            )
            .opacity(isDrawerVisible ? 0 : 1)
            
            
            if isDrawerVisible {
                if isCreatingJournal, let draft = pendingJournalDraft {
                    JournalDetailDrawer(
                        mode: .create,
                        existingJournal: nil,
                        template: activeTemplate,
                        initialDraft: draft,
                        isPresented: creationDrawerBinding(),
                        onCommit: { committedDraft in
                            commitNewJournal(from: committedDraft)
                        },
                        onCancel: {
                            pendingJournalDraft = nil
                            activeTemplate = nil
                            withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                                isDrawerVisible = false
                            }
                            isCreatingJournal = false
                        }
                    )
                    .transition(.move(edge: .trailing))
                } else if let journal = activeJournal {
                    JournalDetailDrawer(
                        mode: .edit,
                        existingJournal: journal,
                        template: nil,
                        initialDraft: JournalDraft(journal: journal),
                        isPresented: editDrawerBinding(),
                        onCommit: { updatedDraft in
                            apply(updatedDraft, to: journal)
                            try? modelContext.save()
                            closeEditor()
                        },
                        onCancel: {
                            closeEditor()
                        }
                    )
                    .transition(.move(edge: .trailing))
                }
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
                activeJournal = nil
                activeTemplate = nil
                pendingJournalDraft = nil
                isCreatingJournal = false
            }
        }
    }
    
    private var headerBar: some View {
        V2GlassHeaderBar(
            title: "Journal",
            subtitle: headerSubtitle,
            trailingAccessory: {
                HStack(spacing: 12) {
                    viewModeSelector
                    selectionToggleButton
                    quickAddButton
                }
            }
        )
    }
    
    private var viewModeSelector: some View {
        HStack(spacing: 8) {
            ForEach(JournalViewMode.allCases, id: \.self) { mode in
                modeButton(for: mode)
            }
        }
    }
    
    private func modeButton(for mode: JournalViewMode) -> some View {
        let isSelected = selectedViewMode == mode
        let backgroundFill: some ShapeStyle = isSelected ? 
            AnyShapeStyle(AuroraPalette.linearGradient(for: colorScheme).opacity(0.85)) :
            AnyShapeStyle(glassColorSystem.backgroundElevated().opacity(0.4))
        let strokeColor: Color = isSelected ? 
            Color.white.opacity(0.3) : 
            glassColorSystem.borderColor().opacity(0.3)
        let strokeWidth: CGFloat = isSelected ? 1.2 : 0.8
        
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedViewMode = mode
            }
        } label: {
            Image(systemName: mode.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : glassColorSystem.textSecondary())
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(backgroundFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(strokeColor, lineWidth: strokeWidth)
                )
        }
        .buttonStyle(.plain)
        .help(mode.displayName)
    }
    
    private var selectionToggleButton: some View {
        GlassButton(
            nil,
            icon: isSelectionActive ? "checkmark.circle.fill" : "checkmark.circle",
            style: .iconOnly,
            role: .surface
        ) {
            toggleSelectionMode()
        }
        .accessibilityLabel(isSelectionActive ? "Exit selection mode" : "Enter selection mode")
    }
    
    private var quickAddButton: some View {
        GlassButton(
            "New Entry",
            icon: "plus",
            style: .pill,
            role: .primary
        ) {
            startCreatingJournal()
        }
    }
    
    @ViewBuilder
    private var journalContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            filterPanel
            activeModeView
        }
        .animation(.easeInOut(duration: 0.24), value: selectedViewMode)
    }
    
    private var filterPanel: some View {
        GlassPanel(tier: .overlay, cornerRadius: 26) {
            VStack(alignment: .leading, spacing: 18) {
                searchField
                filterChipRow
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 22)
        }
    }
    
    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(glassColorSystem.textSecondary().opacity(0.75))
            
            TextField("Search reflections or emotions…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .rounded))
                .foregroundColor(glassColorSystem.textPrimary())
                .disableAutocorrection(true)
                .focused($isSearchFocused)
            
            if !searchText.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(glassColorSystem.backgroundElevated().opacity(0.28))
        )
    }
    
    private var filterChipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(JournalFilter.allCases, id: \.self) { filter in
                    filterChip(for: filter)
                }
            }
        }
    }
    
    private func filterChip(for filter: JournalFilter) -> some View {
        let isActive = selectedFilter == filter
        
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: filterIcon(for: filter))
                    .font(.system(size: 13, weight: .semibold))
                Text(filter.rawValue)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(filterAccentColor(for: filter).opacity(isActive ? 0.26 : 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(filterAccentColor(for: filter).opacity(isActive ? 0.55 : 0.24), lineWidth: isActive ? 1.4 : 1)
            )
            .foregroundStyle(isActive ? Color.white : glassColorSystem.textSecondary())
            .shadow(color: filterAccentColor(for: filter).opacity(isActive ? 0.20 : 0.0), radius: isActive ? 12 : 0, y: isActive ? 6 : 0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(filter.rawValue) filter")
    }
    
    private func filterIcon(for filter: JournalFilter) -> String {
        switch filter {
        case .all: return "list.bullet"
        case .morning: return "sunrise.fill"
        case .evening: return "moon.fill"
        case .moodEntries: return "face.smiling"
        case .aiReflections: return "sparkles"
        }
    }
    
    private func filterAccentColor(for filter: JournalFilter) -> Color {
        switch filter {
        case .all: return .kosmicBlue
        case .morning: return .orange
        case .evening: return .kosmicPurple
        case .moodEntries: return .kosmicGreen
        case .aiReflections: return .pink
        }
    }
    
    @ViewBuilder
    private var activeModeView: some View {
        if sortedJournals.isEmpty {
            emptyState
        } else {
            switch selectedViewMode {
            case .list:
                listView
            case .timeline:
                timelineView
            case .gallery:
                galleryView
            }
        }
    }
    
    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
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
        }
    }
    
    private var timelineView: some View {
        JournalTimelineView(
            journals: sortedJournals,
            onEntryTap: { journal in
                openDrawer(for: journal)
            }
        )
    }
    
    private var galleryView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 320), spacing: 20)
            ], spacing: 20) {
                ForEach(sortedJournals) { journal in
                    JournalCardV2(
                        journal: journal,
                        selectionMode: isSelectionActive,
                        isSelected: selectedJournalIDs.contains(journal.id),
                        onSelectionToggle: { toggleJournalSelection(journal) },
                        onTap: { openDrawer(for: journal) },
                        onEdit: { openDrawer(for: journal) },
                        onDuplicate: { duplicateJournal(journal) },
                        onExport: { exportJournal(journal) },
                        onDelete: { deleteJournal(journal) }
                    )
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
            if isDrawerVisible {
                withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                    isDrawerVisible = false
                }
                pendingJournalDraft = nil
                activeTemplate = nil
                activeJournal = nil
                isCreatingJournal = false
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
            }
            selectedJournalIDs.insert(journal.id)
        }
        if isSelectionActive {
            withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                isDrawerVisible = false
            }
            pendingJournalDraft = nil
            activeTemplate = nil
            activeJournal = nil
            isCreatingJournal = false
        }
    }
    
    private func startCreatingJournal(template: JournalTemplate? = nil) {
        guard !isDrawerVisible else { return }
        
        let baseDraft: JournalDraft
        if let template {
            baseDraft = JournalDraft(content: template.content)
        } else {
            baseDraft = JournalDraft()
        }
        
        pendingJournalDraft = baseDraft
        activeTemplate = template
        isCreatingJournal = true
        activeJournal = nil
        
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isDrawerVisible = true
        }
    }
    
    private func creationDrawerBinding() -> Binding<Bool> {
        Binding(
            get: { isDrawerVisible && isCreatingJournal },
            set: { newValue in
                if !newValue {
                    pendingJournalDraft = nil
                    activeTemplate = nil
                    isCreatingJournal = false
                }
                withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                    isDrawerVisible = newValue
                }
            }
        )
    }
    
    private func editDrawerBinding() -> Binding<Bool> {
        Binding(
            get: { isDrawerVisible && !isCreatingJournal },
            set: { newValue in
                if !newValue {
                    activeJournal = nil
                }
                withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                    isDrawerVisible = newValue
                }
            }
        )
    }
    
    private func commitNewJournal(from draft: JournalDraft) {
        let normalizedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedContent = draft.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle: String
        if !normalizedTitle.isEmpty {
            resolvedTitle = normalizedTitle
        } else if !normalizedContent.isEmpty {
            resolvedTitle = String(normalizedContent.prefix(64))
        } else {
            resolvedTitle = "Untitled Entry"
        }
        
        let journal = Journal(
            title: resolvedTitle,
            content: draft.content,
            entryDate: draft.entryDate,
            entryType: draft.entryType,
            mood: draft.mood,
            tags: draft.tags,
            projectId: draft.projectId,
            areaId: draft.areaId,
            linkedNoteIds: draft.linkedNoteIds,
            linkedAreaIds: draft.linkedAreaIds,
            linkedProjectIds: draft.linkedProjectIds
        )
        journal.linkedEntityIds = draft.linkedEntityIds
        journal.linkedEntityTypes = draft.linkedEntityTypes
        journal.author = draft.author
        journal.aiPrompt = draft.aiPrompt
        journal.aiGeneratedContent = draft.aiGeneratedContent
        journal.auroraNotes = draft.auroraNotes
        journal.isArchived = draft.isArchived
        
        modelContext.insert(journal)
        try? modelContext.save()
        
        pendingJournalDraft = nil
        activeTemplate = nil
        isCreatingJournal = false
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isDrawerVisible = false
        }
    }
    
    private func apply(_ draft: JournalDraft, to journal: Journal) {
        let normalizedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedContent = draft.content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !normalizedTitle.isEmpty {
            journal.title = normalizedTitle
        } else if !normalizedContent.isEmpty {
            journal.title = String(normalizedContent.prefix(64))
        } else {
            journal.title = "Untitled Entry"
        }
        
        journal.content = draft.content
        journal.entryDate = draft.entryDate
        journal.journalEntryType = draft.entryType
        journal.journalMood = draft.mood
        journal.tags = draft.tags
        journal.projectId = draft.projectId
        journal.areaId = draft.areaId
        journal.linkedNoteIds = draft.linkedNoteIds
        journal.linkedAreaIds = draft.linkedAreaIds
        journal.linkedProjectIds = draft.linkedProjectIds
        journal.linkedEntityIds = draft.linkedEntityIds
        journal.linkedEntityTypes = draft.linkedEntityTypes
        journal.author = draft.author
        journal.aiPrompt = draft.aiPrompt
        journal.aiGeneratedContent = draft.aiGeneratedContent
        journal.auroraNotes = draft.auroraNotes
        journal.isArchived = draft.isArchived
        journal.updatedAt = Date()
    }
    
    private func closeEditor() {
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isDrawerVisible = false
        }
        DispatchQueue.main.async {
            activeJournal = nil
            pendingJournalDraft = nil
            activeTemplate = nil
            isCreatingJournal = false
        }
    }
    
    private func openDrawer(for journal: Journal) {
        guard !isSelectionActive else { return }
        
        activeJournal = journal
        activeTemplate = nil
        isCreatingJournal = false
        pendingJournalDraft = nil
        
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
                if isDrawerVisible {
                    withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                        isDrawerVisible = false
                    }
                    pendingJournalDraft = nil
                    activeTemplate = nil
                    activeJournal = nil
                    isCreatingJournal = false
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
                startCreatingJournal()
                return nil
            }
            
            // Escape: Close drawer
            if event.keyCode == 53 { // Escape key
                if isDrawerVisible {
                    withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                        isDrawerVisible = false
                    }
                    return nil
                }
            }
            
            // Enter: Open selected journal
            if event.keyCode == 36 && focusedJournalIndex != nil { // Enter key
                let journals = sortedJournals
                if let index = focusedJournalIndex, index < journals.count {
                    openDrawer(for: journals[index])
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

