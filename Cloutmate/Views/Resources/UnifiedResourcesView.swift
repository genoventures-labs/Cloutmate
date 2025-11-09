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
    @State private var selectedNote: Note?
    @State private var showDetailDrawer = false
    @State private var showImportSheet = false
    
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
                // Fixed Header
                ResourcesHeaderView(
                    searchText: $searchText,
                    selectedFilter: $selectedFilter,
                    onQuickAdd: {
                        showImportSheet = true
                    }
                )
                .zIndex(10)
                
                // Scrollable Content
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
                                            selectedNote = note
                                            showDetailDrawer = true
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
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
                        }
                    )
                }
            }
        }
        .overlay(
            // Detail Drawer
            Group {
                if showDetailDrawer, let note = selectedNote {
                    ResourceDetailDrawer(note: note, isPresented: $showDetailDrawer)
                        .transition(.move(edge: .trailing))
                        .zIndex(1000)
                }
            }
            .animation(reduceMotion ? nil : GlassMotion.Easing.modalOpen, value: showDetailDrawer)
        )
        .sheet(isPresented: $showImportSheet) {
            ResourceImportSheet()
        }
        .onChange(of: selectedNote) { _, newValue in
            if newValue == nil {
                showDetailDrawer = false
            }
        }
        .onKeyPress(.escape) {
            if showDetailDrawer {
                selectedNote = nil
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
                showImportSheet = true
            }
            .padding(.top, 8)
        }
    }
}

#Preview {
    UnifiedResourcesView()
        .environmentObject(GlassColorSystem())
        .modelContainer(for: Note.self)
}

