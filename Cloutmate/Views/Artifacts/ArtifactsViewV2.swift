//
//  ArtifactsViewV2.swift
//  Cloutmate
//
//  Artifacts V2 - Main orchestration view
//

import SwiftUI
import SwiftData
import CloutmateShared

struct ArtifactsViewV2: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @Query(sort: \Artifact.updatedAt, order: .reverse) private var allArtifacts: [Artifact]
    
    @State private var selectedFilter: ArtifactFilter = .all
    @State private var searchText = ""
    @State private var scrollOffset: CGFloat = 0
    @State private var isCreateDrawerVisible = false
    @State private var selectedArtifact: Artifact?
    @State private var showDetailDrawer = false
    
    var filteredArtifacts: [Artifact] {
        var filtered = allArtifacts
        
        if !searchText.isEmpty {
            filtered = filtered.filter { artifact in
                artifact.title.localizedCaseInsensitiveContains(searchText) ||
                artifact.content.localizedCaseInsensitiveContains(searchText) ||
                artifact.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        if selectedFilter != .all {
            filtered = filtered.filter { selectedFilter.matches($0.artifactState) }
        }
        
        return filtered
    }
    
    var draftsCount: Int {
        allArtifacts.filter { $0.artifactState == .draft }.count
    }
    
    var headerOpacity: Double {
        let threshold: CGFloat = 50
        return scrollOffset > threshold ? 1.0 : max(0.3, Double(scrollOffset / threshold))
    }
    
    var body: some View {
        ZStack {
        HStack(spacing: 0) {
            // Main content
            VStack(spacing: 0) {
                // Header Zone
                headerZone
                    .opacity(headerOpacity)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: headerOpacity)
                
                Divider()
                
                // Content
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            GeometryReader { geometry in
                                Color.clear
                                    .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
                            }
                            .frame(height: 0)
                            
                            if filteredArtifacts.isEmpty {
                                ContentUnavailableView(
                                    "No Artifacts",
                                    systemImage: "doc.text",
                                    description: Text(searchText.isEmpty ? "Create your first artifact to get started" : "No artifacts match your search")
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.top, 100)
                            } else {
                                LazyVGrid(columns: [
                                    GridItem(.adaptive(minimum: 320), spacing: 16)
                                ], spacing: 16) {
                                    ForEach(filteredArtifacts) { artifact in
                                        ArtifactCardV2(
                                            artifact: artifact,
                                            onOpen: { openDetail(for: artifact) },
                                            onEdit: { openDetail(for: artifact) },
                                            onDuplicate: { duplicateArtifact(artifact) },
                                            onArchive: { archiveArtifact(artifact) },
                                            onDelete: { deleteArtifact(artifact) }
                                        )
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 24)
                            }
                        }
                    }
                    .coordinateSpace(name: "scroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        scrollOffset = -value
                    }
                }
            }
            
            // Sidebar
            ArtifactSidebar(
                artifacts: allArtifacts,
                filteredArtifacts: filteredArtifacts,
                onFilterChanged: { filter in
                    selectedFilter = filter
                }
            )
        }
        .background(Color(.windowBackgroundColor))
            .opacity(isCreateDrawerVisible ? 0 : 1)
            
            if isCreateDrawerVisible {
                ArtifactQuickAddDrawer(isPresented: $isCreateDrawerVisible)
                    .transition(.move(edge: .trailing))
            }
            
            if let artifact = selectedArtifact, showDetailDrawer {
                ArtifactDetailDrawer(artifact: artifact)
                    .transition(.move(edge: .trailing))
            }
        }
        .background(
            Button("New Artifact") {
                presentCreateDrawer()
            }
            .keyboardShortcut("n", modifiers: .command)
            .hidden()
        )
        .accessibilityLabel("Artifacts view")
        .accessibilityHint("Use Command+N to create a new artifact")
    }
    
    // MARK: - Header Zone
    
    private var headerZone: some View {
        HStack(alignment: .top, spacing: 20) {
            // Title & Count
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Text("Artifacts")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(glassColorSystem.textPrimary())
                    
                    if draftsCount > 0 {
                        Text("\(draftsCount) draft\(draftsCount == 1 ? "" : "s")")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.kosmicBlue.opacity(0.2))
                            .foregroundColor(.kosmicBlue)
                            .cornerRadius(8)
                    }
                }
            }
            
            Spacer()
            
            // Filter Chips
            HStack(spacing: 8) {
                ForEach(ArtifactFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        selectedFilter = filter
                    }) {
                        Text(filter.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                selectedFilter == filter ?
                                Color.kosmicBlue.opacity(0.2) :
                                glassColorSystem.glassTint(for: .surface).opacity(0.3)
                            )
                            .foregroundColor(
                                selectedFilter == filter ?
                                .kosmicBlue :
                                glassColorSystem.textPrimary()
                            )
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(glassColorSystem.textSecondary())
                    .font(.caption)
                
                TextField("Search artifacts...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .frame(width: 200)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(glassColorSystem.glassTint(for: .surface).opacity(0.3))
            .cornerRadius(8)
            
            // Quick Create Button
            Button(action: {
                presentCreateDrawer()
            }) {
                Image(systemName: "plus")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.kosmicBlue)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Create New Artifact (⌘N)")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            GlassPanel(tier: .overlay, cornerRadius: 0) {
                EmptyView()
            }
            .ignoresSafeArea(edges: .top)
        )
    }
    
    private func presentCreateDrawer() {
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isCreateDrawerVisible = true
        }
    }
    
    private func openDetail(for artifact: Artifact) {
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            selectedArtifact = artifact
            showDetailDrawer = true
        }
    }
    
    private func closeDetailDrawer() {
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            showDetailDrawer = false
            selectedArtifact = nil
        }
    }
    
    private func duplicateArtifact(_ artifact: Artifact) {
        let baseTitle = artifact.title.isEmpty ? "Untitled" : artifact.title
        let copyTitle = "\(baseTitle) Copy"
        
        let copy = Artifact(
            title: copyTitle,
            content: artifact.content,
            mediaURLs: artifact.mediaURLs,
            outputFormat: artifact.format,
            state: .draft,
            tags: artifact.tags,
            projectId: artifact.projectId,
            areaId: artifact.areaId,
            focusSessionId: artifact.focusSessionId,
            linkedEntityIds: artifact.linkedEntityIds,
            linkedEntityTypes: artifact.linkedEntityTypes,
            arteToneSnapshot: artifact.arteToneSnapshot,
            sentimentSummary: artifact.sentimentSummary,
            confidenceScore: artifact.confidenceScore,
            storyTokenIds: artifact.storyTokenIds,
            auroraNotes: artifact.auroraNotes,
            forecastSnapshot: artifact.forecastSnapshot
        )
        copy.customProperties = artifact.customProperties
        modelContext.insert(copy)
        try? modelContext.save()
    }
    
    private func archiveArtifact(_ artifact: Artifact) {
        artifact.artifactState = .archived
        artifact.archivedAt = Date()
        artifact.updatedAt = Date()
        try? modelContext.save()
        
        if selectedArtifact?.id == artifact.id {
            closeDetailDrawer()
        }
    }
    
    private func deleteArtifact(_ artifact: Artifact) {
        if selectedArtifact?.id == artifact.id {
            closeDetailDrawer()
        }
        modelContext.delete(artifact)
        try? modelContext.save()
    }
}

#Preview {
    ArtifactsViewV2()
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [Artifact.self])
}

