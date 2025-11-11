//
//  AreasView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import CloutmateShared

struct AreasView: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Area.updatedAt, order: .reverse) private var allAreas: [Area]
    @Query private var allProjects: [CloutmateShared.Project]
    
    @State private var searchText = ""
    @State private var selectedTags: Set<String> = []
    @State private var hasCadenceFilter: Bool?
    @State private var selectedAreas = Set<UUID>()
    @State private var isCreateDrawerVisible = false
    @State private var selectedArea: Area?
    @State private var showArchiveConfirmation = false
    
    var filteredAreas: [Area] {
        var filtered = allAreas
        
        if !searchText.isEmpty {
            filtered = filtered.filter { area in
                area.title.localizedCaseInsensitiveContains(searchText) ||
                (area.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        if let hasCadence = hasCadenceFilter {
            filtered = filtered.filter { area in
                if hasCadence {
                    return area.cadenceSetting != nil && !area.cadenceSetting!.isEmpty
                } else {
                    return area.cadenceSetting == nil || area.cadenceSetting!.isEmpty
                }
            }
        }
        
        if !selectedTags.isEmpty {
            filtered = filtered.filter { area in
                !Set(area.tags).isDisjoint(with: selectedTags)
            }
        }
        
        return filtered
    }
    
    var availableTags: [String] {
        Array(Set(allAreas.flatMap { $0.tags })).sorted()
    }
    
    private var searchAndFiltersSection: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search areas...", text: $searchText)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "All",
                        isSelected: hasCadenceFilter == nil,
                        action: { hasCadenceFilter = nil }
                    )
                    
                    FilterChip(
                        title: "Has Schedule",
                        isSelected: hasCadenceFilter == true,
                        action: { hasCadenceFilter = true }
                    )
                    
                    FilterChip(
                        title: "No Schedule",
                        isSelected: hasCadenceFilter == false,
                        action: { hasCadenceFilter = false }
                    )
                }
            }
        }
        .padding()
    }
    
    private var tableSection: some View {
        Table(filteredAreas, selection: $selectedAreas) {
            TableColumn("Title") { area in
                VStack(alignment: .leading, spacing: 4) {
                    Text(area.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if let notes = area.notes {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                .contextMenu {
                    Button("Edit") {
                        selectedArea = area
                    }
                    Button("Manage Cadence") {
                        selectedArea = area
                    }
                    Button("Archive") {
                        // Archive functionality
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        deleteArea(area)
                    }
                }
            }
            .width(min: 200, ideal: 300)
            
            TableColumn("Projects") { area in
                let projectCount = allProjects.filter { $0.areaId == area.id }.count
                Text("\(projectCount)")
                    .font(.caption)
                    .foregroundColor(projectCount > 0 ? .kosmicBlue : .secondary)
            }
            .width(min: 100)
            
            TableColumn("Cadence") { area in
                if let cadence = area.cadenceSetting,
                   !cadence.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundColor(.kosmicBlue)
                        Text("Scheduled")
                            .font(.caption)
                    }
                } else {
                    Text("—")
                        .foregroundColor(.secondary)
                }
            }
            .width(min: 120)
            
            TableColumn("Tags") { area in
                if !area.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(area.tags.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.kosmicBlue.opacity(0.1))
                                    .foregroundColor(.kosmicBlue)
                                    .cornerRadius(4)
                            }
                            if area.tags.count > 3 {
                                Text("+\(area.tags.count - 3)")
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
            
            TableColumn("Updated") { area in
                Text(area.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .width(min: 120)
        }
        .onTapGesture {
            if let area = filteredAreas.first(where: { selectedAreas.contains($0.id) }) {
                selectedArea = area
            }
        }
    }
    
    var body: some View {
        ZStack {
        VStack(spacing: 0) {
            searchAndFiltersSection
            
            tableSection
            }
            .opacity(isCreateDrawerVisible ? 0 : 1)
            
            if isCreateDrawerVisible {
                CreateAreaDrawer(isPresented: $isCreateDrawerVisible)
                    .transition(.move(edge: .trailing))
            }
        }
        .background(Color(.windowBackgroundColor))
        .navigationTitle("Areas")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !selectedAreas.isEmpty {
                    Menu("Actions") {
                        Button("Archive Selected", systemImage: "archivebox") {
                            archiveSelectedAreas()
                        }
                        Button("Delete Selected", systemImage: "trash") {
                            deleteSelectedAreas()
                        }
                    }
                }
                
                Button("New Area") {
                    presentCreateDrawer()
                }
            }
        }
        .sheet(item: $selectedArea) { area in
            AreaDetailSheet(area: area)
        }
    }
    
    private func deleteArea(_ area: Area) {
        modelContext.delete(area)
        if selectedAreas.contains(area.id) {
            selectedAreas.remove(area.id)
        }
        try? modelContext.save()
    }
    
    private func archiveSelectedAreas() {
        // Archive functionality
        selectedAreas.removeAll()
    }
    
    private func deleteSelectedAreas() {
        let areasToDelete = filteredAreas.filter { selectedAreas.contains($0.id) }
        for area in areasToDelete {
            modelContext.delete(area)
        }
        selectedAreas.removeAll()
        try? modelContext.save()
    }
    
    private func presentCreateDrawer() {
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isCreateDrawerVisible = true
        }
    }
}

struct AreaDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let area: Area
    
    var body: some View {
        NavigationStack {
            AreaDetailView(area: area)
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

struct CreateAreaDrawer: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var title = ""
    @State private var notes = ""
    @State private var tags = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Basic Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Basic Information")
                            .font(.headline)
                        
                        TextField("Area Title *", text: $title)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextEditor(text: $notes)
                                .frame(height: 100)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tags (comma separated)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("e.g., personal, work, health", text: $tags)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.kosmicBlue)
                            Text("Note: Cadence settings can be configured after creating the area.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.kosmicBlue.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("New Area")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { closeDrawer() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createArea()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 420)
        .frame(idealWidth: 720, idealHeight: 520)
    }
    
    private func createArea() {
        let tagArray = tags.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let area = Area(
            title: title,
            notes: notes.isEmpty ? nil : notes,
            tags: tagArray
        )
        
        modelContext.insert(area)
        try? modelContext.save()
        closeDrawer()
    }
    
    private func closeDrawer() {
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isPresented = false
        }
    }
}

struct AreaCard: View {
    let area: Area
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "rectangle.stack.fill")
                    .foregroundStyle(Color.kosmicBlue)
                Text(area.title)
                    .font(.headline)
                Spacer()
            }
            
            if let notes = area.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Text(area.updatedAt, style: .relative)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 12)
    }
}

#Preview {
    AreasView()
        .modelContainer(for: [Area.self])
}

