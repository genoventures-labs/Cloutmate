//
//  UnifiedResourcesView.swift
//  FocusOS
//
//  Resources V2 - Unified Gallery View
//

import SwiftUI
import SwiftData
import AppKit
import FocusOSShared

struct UnifiedResourcesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<FocusOSShared.Note> { $0.isArchived == false && $0.projectId == nil }, sort: \FocusOSShared.Note.updatedAt, order: .reverse) private var resourceNotes: [FocusOSShared.Note]
    @Query private var allProjects: [FocusOSShared.Project]
    @Query private var allAreas: [Area]
    
    @State private var searchText = ""
    @State private var selectedFilter: ResourceFilter = .all
    @State private var activeResource: Note?
    @State private var isDetailVisible = false
    @State private var isCreatingResource = false
    @State private var isImportVisible = false
    @State private var isFilterSortDrawerVisible = false
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    
    // Sort persistence
    @AppStorage("resources.sort") private var sortOption: String = ResourceSortOption.updatedAtDesc.rawValue
    
    private var currentSortOption: ResourceSortOption {
        ResourceSortOption(rawValue: sortOption) ?? .updatedAtDesc
    }
    
    var filteredNotes: [Note] {
        var filtered = resourceNotes
        
        // Search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { note in
                note.title.localizedCaseInsensitiveContains(searchText) ||
                note.markdown.localizedCaseInsensitiveContains(searchText) ||
                note.tags.joined(separator: " ").localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Type filter
        switch selectedFilter {
        case .all:
            break
        case .documents:
            filtered = filtered.filter { $0.type == .note || $0.type == .reference }
        case .media:
            filtered = filtered.filter { $0.type == .video || $0.type == .podcast }
        case .templates:
            filtered = filtered.filter { $0.type == .book }
        case .articles:
            filtered = filtered.filter { $0.type == .article || $0.type == .link }
        case .archived:
            filtered = filtered.filter { $0.isArchived }
        }
        
        return filtered
    }
    
    var sortedNotes: [Note] {
        sortResources(filteredNotes, by: currentSortOption)
    }
    
    var body: some View {
        ZStack {
            glassColorSystem.backgroundColor()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ResourcesHeaderView(
                    searchText: $searchText,
                    selectedFilter: $selectedFilter,
                    currentSortOption: currentSortOption,
                    isFilterSortDrawerVisible: $isFilterSortDrawerVisible,
                    onSortChange: { option in
                        sortOption = option.rawValue
                    },
                    onQuickAdd: {
                        startImportFlow()
                    }
                )
                .zIndex(10)
                .opacity(isDetailVisible || isImportVisible || isFilterSortDrawerVisible ? 0 : 1)
                
            if isFilterSortDrawerVisible {
                ResourceFilterSortDrawer(
                    isPresented: $isFilterSortDrawerVisible,
                    selectedSort: $sortOption
                )
                .transition(.move(edge: .trailing))
                .zIndex(20)
            }
            
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            if sortedNotes.isEmpty {
                                emptyStateView
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .padding(.top, 100)
                            } else {
                                LazyVGrid(
                                    columns: [
                                        GridItem(.adaptive(minimum: 280, maximum: 320), spacing: 16)
                                    ],
                                    spacing: 16
                                ) {
                                    ForEach(sortedNotes) { note in
                                        ResourceCardV2(note: note) {
                                            openResource(note)
                                        }
                                        .id(note.id)
                                    }
                                }
                                .padding(20)
                                .padding(.top, 8)
                            }
                        }
                        .coordinateSpace(name: "scroll")
                    }
                }
            }
            
            if let resource = activeResource, isDetailVisible {
                ResourceDetailDrawer(
                    note: resource,
                    isPresented: Binding(
                        get: { isDetailVisible },
                        set: { newValue in
                            withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                                isDetailVisible = newValue
                            }
                        }
                    )
                )
                .transition(.move(edge: .trailing))
                .zIndex(1000)
            }
            
            if isImportVisible {
                ResourceImportDrawer(
                    isPresented: Binding(
                        get: { isImportVisible },
                        set: { newValue in
                            withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                                isImportVisible = newValue
                            }
                        }
                    ),
                    onComplete: { createdNote in
                        if let createdNote {
                            activeResource = createdNote
                            isCreatingResource = false
                            withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                                isDetailVisible = true
                            }
                        }
                    }
                )
                .zIndex(1200)
            }
        }
        .onChange(of: isDetailVisible) { _, newValue in
            if !newValue, let resource = activeResource {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if !isDetailVisible {
                        cleanupIfNecessary(resource)
                        activeResource = nil
                        isCreatingResource = false
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showResourceImport)) { _ in
            startImportFlow()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openResourceDetail)) { notification in
            if let note = notification.object as? Note {
                openResource(note)
            }
        }
        .onKeyPress(.escape) {
            if isDetailVisible {
                withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                    isDetailVisible = false
                }
                return .handled
            }
            if isImportVisible {
                withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                    isImportVisible = false
                }
                return .handled
            }
            return .ignored
        }
        .accessibilityLabel("Resources gallery")
        .accessibilityHint("Use arrow keys to navigate between resources. Press Enter to open details.")
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No Resources Yet")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Start building your knowledge vault by importing resources")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            GlassButton(
                "Add Your First Resource",
                icon: "plus",
                style: .standard,
                role: .primary
            ) {
                startImportFlow()
            }
            .padding(.top, 8)
        }
    }
    
    private func startImportFlow() {
        isCreatingResource = true
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isImportVisible = true
        }
    }
    
    private func openResource(_ note: Note) {
        guard !isDetailVisible else { return }
        activeResource = note
        isCreatingResource = false
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isDetailVisible = true
        }
    }
    
    private func cleanupIfNecessary(_ note: Note) {
        guard isCreatingResource else { return }
        let trimmedTitle = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = note.markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty && trimmedContent.isEmpty && note.tags.isEmpty {
            modelContext.delete(note)
            try? modelContext.save()
        } else {
            try? modelContext.save()
        }
    }
    
    private func sortResources(_ notes: [Note], by option: ResourceSortOption) -> [Note] {
        var sorted = notes
        
        switch option {
        // Date & Time
        case .updatedAtDesc:
            sorted.sort { $0.updatedAt > $1.updatedAt }
        case .updatedAtAsc:
            sorted.sort { $0.updatedAt < $1.updatedAt }
        case .createdAtDesc:
            sorted.sort { $0.createdAt > $1.createdAt }
        case .createdAtAsc:
            sorted.sort { $0.createdAt < $1.createdAt }
        
        // Alphabetical
        case .titleAsc:
            sorted.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .titleDesc:
            sorted.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        
        // Type
        case .typeNote:
            sorted.sort { note1, note2 in
                if note1.type == note2.type {
                    return note1.updatedAt > note2.updatedAt
                }
                return note1.type == .note && note2.type != .note
            }
        case .typeArticle:
            sorted.sort { note1, note2 in
                if note1.type == note2.type {
                    return note1.updatedAt > note2.updatedAt
                }
                return note1.type == .article && note2.type != .article
            }
        case .typeVideo:
            sorted.sort { note1, note2 in
                if note1.type == note2.type {
                    return note1.updatedAt > note2.updatedAt
                }
                return note1.type == .video && note2.type != .video
            }
        case .typePodcast:
            sorted.sort { note1, note2 in
                if note1.type == note2.type {
                    return note1.updatedAt > note2.updatedAt
                }
                return note1.type == .podcast && note2.type != .podcast
            }
        case .typeBook:
            sorted.sort { note1, note2 in
                if note1.type == note2.type {
                    return note1.updatedAt > note2.updatedAt
                }
                return note1.type == .book && note2.type != .book
            }
        case .typeLink:
            sorted.sort { note1, note2 in
                if note1.type == note2.type {
                    return note1.updatedAt > note2.updatedAt
                }
                return note1.type == .link && note2.type != .link
            }
        
        // Relationship
        case .byProject:
            sorted.sort { note1, note2 in
                if note1.projectId == note2.projectId {
                    return note1.updatedAt > note2.updatedAt
                }
                if note1.projectId == nil { return false }
                if note2.projectId == nil { return true }
                return note1.projectId!.uuidString < note2.projectId!.uuidString
            }
        case .byArea:
            sorted.sort { note1, note2 in
                if note1.areaId == note2.areaId {
                    return note1.updatedAt > note2.updatedAt
                }
                if note1.areaId == nil { return false }
                if note2.areaId == nil { return true }
                return note1.areaId!.uuidString < note2.areaId!.uuidString
            }
        case .unattachedFirst:
            sorted.sort { note1, note2 in
                let note1Attached = note1.projectId != nil || note1.areaId != nil
                let note2Attached = note2.projectId != nil || note2.areaId != nil
                if note1Attached == note2Attached {
                    return note1.updatedAt > note2.updatedAt
                }
                return !note1Attached && note2Attached
            }
        case .unattachedLast:
            sorted.sort { note1, note2 in
                let note1Attached = note1.projectId != nil || note1.areaId != nil
                let note2Attached = note2.projectId != nil || note2.areaId != nil
                if note1Attached == note2Attached {
                    return note1.updatedAt > note2.updatedAt
                }
                return note1Attached && !note2Attached
            }
        
        // Tags
        case .tagCountDesc:
            sorted.sort { note1, note2 in
                if note1.tags.count == note2.tags.count {
                    return note1.updatedAt > note2.updatedAt
                }
                return note1.tags.count > note2.tags.count
            }
        case .tagCountAsc:
            sorted.sort { note1, note2 in
                if note1.tags.count == note2.tags.count {
                    return note1.updatedAt > note2.updatedAt
                }
                return note1.tags.count < note2.tags.count
            }
        
        // Author
        case .authorUserFirst:
            sorted.sort { note1, note2 in
                if note1.author == note2.author {
                    return note1.updatedAt > note2.updatedAt
                }
                return note1.author == .user && note2.author != .user
            }
        case .authorAuroraFirst:
            sorted.sort { note1, note2 in
                if note1.author == note2.author {
                    return note1.updatedAt > note2.updatedAt
                }
                return note1.author == .aurora && note2.author != .aurora
            }
        
        // Combined
        case .typeThenUpdated:
            sorted.sort { note1, note2 in
                if note1.type != note2.type {
                    return note1.type.rawValue < note2.type.rawValue
                }
                return note1.updatedAt > note2.updatedAt
            }
        case .authorThenUpdated:
            sorted.sort { note1, note2 in
                if note1.author != note2.author {
                    return note1.author.rawValue < note2.author.rawValue
                }
                return note1.updatedAt > note2.updatedAt
            }
        }
        
        return sorted
    }
}

// MARK: - Resource Filter Sort Drawer

struct ResourceFilterSortDrawer: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @Binding var isPresented: Bool
    @Binding var selectedSort: String
    
    private var currentSortOption: ResourceSortOption {
        ResourceSortOption(rawValue: selectedSort) ?? .updatedAtDesc
    }
    
    var body: some View {
        V2DrawerScaffold(
            accentGradient: AuroraPalette.linearGradient(for: colorScheme),
            header: {
                V2GlassHeaderBar(
                    title: "Sort Resources",
                    subtitle: "Refine your resource view"
                ) {
                    Button {
                        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                            isPresented = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                VStack(alignment: .leading, spacing: 32) {
                    // Sort Section
                    DrawerSection(title: "Sort Options", icon: "arrow.up.arrow.down.circle") {
                        VStack(alignment: .leading, spacing: 20) {
                            ForEach(ResourceSortCategory.allCases, id: \.self) { category in
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: category.icon)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(glassColorSystem.textSecondary())
                                        Text(category.rawValue)
                                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                            .foregroundStyle(glassColorSystem.textPrimary())
                                    }
                                    
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                                        ForEach(ResourceSortOption.options(for: category), id: \.id) { sort in
                                            SortOptionButton(
                                                title: sort.displayName,
                                                icon: sort.icon,
                                                isSelected: currentSortOption.id == sort.id,
                                                action: {
                                                    selectedSort = sort.rawValue
                                                }
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            sidebar: {
                EmptyView()
            }
        )
    }
}

// MARK: - Helper Views

private struct SortOptionButton: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.system(.caption, design: .rounded))
                    .lineLimit(1)
                if isSelected {
                    Spacer()
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? glassColorSystem.cardColor().opacity(0.6) : glassColorSystem.backgroundSecondary().opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isSelected ? glassColorSystem.emotionalAccent().opacity(0.5) : glassColorSystem.borderColor().opacity(0.3), lineWidth: isSelected ? 1.2 : 0.8)
                    )
            )
            .foregroundStyle(isSelected ? glassColorSystem.textPrimary() : glassColorSystem.textSecondary())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    UnifiedResourcesView()
        .environmentObject(GlassColorSystem())
        .modelContainer(for: Note.self)
}

