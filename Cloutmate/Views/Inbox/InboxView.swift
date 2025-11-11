//
//  InboxView.swift
//  Cloutmate
//
//  Inbox V2 - Modern Card-Based Capture Hub
//

import SwiftUI
import SwiftData
import CloutmateShared

struct InboxView: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \InboxItem.createdAt, order: .reverse) 
    private var inboxItems: [InboxItem]
    
    @State private var searchText = ""
    @State private var selectedFilter: InboxFilter = .all
    @State private var selectedDrawerItem: InboxItem?
    @State private var isQuickCaptureVisible = false
    
    var filteredItems: [InboxItem] {
        var filtered = inboxItems
        
        // Filter by conversion status
        switch selectedFilter {
        case .all:
            filtered = filtered.filter { $0.convertedAt == nil }
        case .unsorted:
            filtered = filtered.filter { $0.convertedAt == nil && !$0.isFlagged && !$0.isArchived }
        case .flagged:
            filtered = filtered.filter { $0.isFlagged && $0.convertedAt == nil }
        case .aiImports:
            filtered = filtered.filter { $0.aiImported && $0.convertedAt == nil }
        case .archived:
            filtered = filtered.filter { $0.isArchived }
        }
        
        // Search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { 
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    
    var body: some View {
        let hasOverlay = selectedDrawerItem != nil || isQuickCaptureVisible
        
        ZStack {
        ScrollView {
            LazyVStack(spacing: 0) {
                InboxHeaderView(
                    searchText: $searchText,
                    selectedFilter: $selectedFilter,
                        onQuickAdd: presentQuickCapture
                )
                
                if filteredItems.isEmpty {
                    ContentUnavailableView(
                        inboxItems.isEmpty ? "Inbox is empty" : "No matches",
                        systemImage: "tray",
                        description: Text(inboxItems.isEmpty ? "Capture new items to get started" : "Try a different search or filter")
                    )
                    .frame(maxHeight: .infinity)
                    .padding(.top, 40)
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 320, maximum: 400), spacing: 16)
                        ],
                        spacing: 16
                    ) {
                        ForEach(filteredItems) { item in
                            InboxCardV2(
                                item: item,
                                onTap: {
                                    selectedDrawerItem = item
                                },
                                onConvertToTask: {
                                    convertItemToTask(item)
                                },
                                onConvertToNote: {
                                    convertItemToNote(item)
                                },
                                onConvertToDraft: {
                                    convertItemToDraft(item)
                                },
                                onConvertToProject: {
                                    convertItemToProject(item)
                                },
                                onArchive: {
                                    archiveItem(item)
                                },
                                onPin: {
                                    toggleFlag(item)
                                },
                                onDelete: {
                                    deleteItem(item)
                                }
                            )
                        }
                    }
                    .padding(20)
                }
            }
        }
            .background(Color.clear)
            .opacity(hasOverlay ? 0 : 1)
            
                if let item = selectedDrawerItem {
                    InboxCaptureDrawer(item: item, isPresented: Binding(
                        get: { selectedDrawerItem != nil },
                        set: { if !$0 { selectedDrawerItem = nil } }
                    ))
                .transition(.move(edge: .trailing))
            }
            
            if isQuickCaptureVisible {
                QuickCaptureDrawer(isPresented: $isQuickCaptureVisible)
                    .transition(.move(edge: .trailing))
            }
        }
        .background(glassColorSystem.backgroundColor())
        .navigationTitle("")
    }
    
    private func presentQuickCapture() {
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isQuickCaptureVisible = true
        }
    }
    
    // MARK: - Conversion Actions
    
    private func convertItemToTask(_ item: InboxItem) {
        let task = Task(
            title: item.content.prefix(100).description,
            notes: item.fileURL ?? ""
        )
        modelContext.insert(task)
        item.convertedToType = "task"
        item.convertedToId = task.id
        item.convertedAt = Date()
        try? modelContext.save()
    }
    
    private func convertItemToNote(_ item: InboxItem) {
        let note = Note(
            title: item.content.prefix(50).description,
            markdown: item.content
        )
        note.author = .user
        modelContext.insert(note)
        item.convertedToType = "note"
        item.convertedToId = note.id
        item.convertedAt = Date()
        try? modelContext.save()
    }
    
    private func convertItemToDraft(_ item: InboxItem) {
        let draft = Draft(
            title: item.content.prefix(50).description,
            caption: item.content,
            notes: nil
        )
        modelContext.insert(draft)
        item.convertedToType = "draft"
        item.convertedToId = draft.id
        item.convertedAt = Date()
        try? modelContext.save()
    }
    
    private func convertItemToProject(_ item: InboxItem) {
        let project = Project(
            title: item.content.prefix(50).description
        )
        modelContext.insert(project)
        item.convertedToType = "project"
        item.convertedToId = project.id
        item.convertedAt = Date()
        try? modelContext.save()
    }
    
    private func archiveItem(_ item: InboxItem) {
        item.isArchived = true
        try? modelContext.save()
    }
    
    private func toggleFlag(_ item: InboxItem) {
        item.isFlagged.toggle()
        try? modelContext.save()
    }
    
    private func deleteItem(_ item: InboxItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }
}

#Preview {
    InboxView()
        .modelContainer(for: [InboxItem.self])
        .environmentObject(GlassColorSystem())
}
