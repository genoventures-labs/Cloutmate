//
//  UnifiedResourcesView.swift
//  Cloutmate
//
//  Resources V2 - Unified Gallery View
//

import SwiftUI
import SwiftData
import AppKit
import CloutmateShared

struct UnifiedResourcesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<CloutmateShared.Note> { $0.isArchived == false && $0.projectId == nil }, sort: \CloutmateShared.Note.updatedAt, order: .reverse) private var resourceNotes: [CloutmateShared.Note]
    @Query private var allProjects: [CloutmateShared.Project]
    @Query private var allAreas: [Area]
    
    @State private var searchText = ""
    @State private var selectedFilter: ResourceFilter = .all
    @State private var activeResource: Note?
    @State private var isDetailVisible = false
    @State private var isCreatingResource = false
    @State private var isImportVisible = false
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
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
    
    var body: some View {
        ZStack {
            glassColorSystem.backgroundColor()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ResourcesHeaderView(
                    searchText: $searchText,
                    selectedFilter: $selectedFilter,
                    onQuickAdd: {
                        startImportFlow()
                    }
                )
                .zIndex(10)
                .opacity(isDetailVisible || isImportVisible ? 0 : 1)
                
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            if filteredNotes.isEmpty {
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
                                    ForEach(filteredNotes) { note in
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
}

#Preview {
    UnifiedResourcesView()
        .environmentObject(GlassColorSystem())
        .modelContainer(for: Note.self)
}

