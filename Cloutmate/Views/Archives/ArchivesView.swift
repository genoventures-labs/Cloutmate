//
//  ArchivesView.swift
//  Cloutmate
//
//  Unified view for all archived content
//

import SwiftUI
import SwiftData
import AppKit

struct ArchivesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var projects: [Project]
    @Query private var areas: [Area]
    @Query private var resources: [Note]
    
    @State private var selectedCategory: ArchiveCategory = .all
    @State private var searchText = ""
    @State private var selectedItems = Set<UUID>()
    
    private let calendar = Calendar.current
    
    var allArchivedItems: [ArchiveItem] {
        var items: [ArchiveItem] = []
        
        if selectedCategory == .all || selectedCategory == .projects {
            items.append(contentsOf: filteredArchivedProjects.map { .project($0) })
        }
        
        if selectedCategory == .all || selectedCategory == .areas {
            items.append(contentsOf: filteredArchivedAreas.map { .area($0) })
        }
        
        if selectedCategory == .all || selectedCategory == .resources {
            items.append(contentsOf: filteredArchivedResources.map { .resource($0) })
        }
        
        return items.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    var filteredItems: [ArchiveItem] {
        if searchText.isEmpty {
            return allArchivedItems
        }
        
        return allArchivedItems.filter { item in
            item.title.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    enum ArchiveItem: Identifiable {
        case project(Project)
        case area(Area)
        case resource(Note)
        
        var id: UUID {
            switch self {
            case .project(let p): return p.id
            case .area(let a): return a.id
            case .resource(let n): return n.id
            }
        }
        
        var title: String {
            switch self {
            case .project(let p): return p.title
            case .area(let a): return a.title
            case .resource(let n): return n.title
            }
        }
        
        var updatedAt: Date {
            switch self {
            case .project(let p): return p.updatedAt
            case .area(let a): return a.updatedAt
            case .resource(let n): return n.updatedAt
            }
        }
        
        var category: ArchiveCategory {
            switch self {
            case .project: return .projects
            case .area: return .areas
            case .resource: return .resources
            }
        }
    }
    
    private var searchAndFiltersSection: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search archives...", text: $searchText)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            // Category filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ArchiveCategory.allCases, id: \.self) { category in
                        FilterChip(
                            title: category.rawValue,
                            isSelected: selectedCategory == category,
                            action: { selectedCategory = category }
                        )
                    }
                }
            }
        }
        .padding()
    }
    
    private var tableSection: some View {
        Table(filteredItems, selection: $selectedItems) {
            TableColumn("Title") { item in
                HStack(spacing: 8) {
                    Image(systemName: iconForItem(item))
                        .foregroundColor(colorForItem(item))
                    Text(item.title)
                        .font(.body)
                        .lineLimit(2)
                }
                .contextMenu {
                    Button("Restore") {
                        restoreItem(item)
                    }
                    Divider()
                    Button("Delete Permanently", role: .destructive) {
                        deleteItem(item)
                    }
                }
            }
            .width(min: 200, ideal: 300)
            
            TableColumn("Category") { item in
                Text(item.category.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .width(min: 100)
            
            TableColumn("Archived") { item in
                Text(item.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .width(min: 120)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchAndFiltersSection
            
            if filteredItems.isEmpty {
                ContentUnavailableView(
                    "No Archived Items",
                    systemImage: "archivebox",
                    description: Text("Items you complete or archive will appear here")
                )
                .frame(maxHeight: .infinity)
            } else {
                tableSection
            }
        }
        .background(Color(.windowBackgroundColor))
        .navigationTitle("Archives")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !selectedItems.isEmpty {
                    Menu("Actions") {
                        Button("Restore Selected", systemImage: "arrow.counterclockwise") {
                            restoreSelectedItems()
                        }
                        Button("Delete Permanently", systemImage: "trash", role: .destructive) {
                            deleteSelectedItems()
                        }
                    }
                }
            }
        }
    }
    
    private func iconForItem(_ item: ArchiveItem) -> String {
        switch item {
        case .project: return "folder.fill"
        case .area: return "rectangle.stack.fill"
        case .resource: return "doc.text"
        }
    }
    
    private func colorForItem(_ item: ArchiveItem) -> Color {
        switch item {
        case .project: return .blue
        case .area: return .gray
        case .resource: return .purple
        }
    }
    
    private func restoreItem(_ item: ArchiveItem) {
        switch item {
        case .project(let project):
            project.status = .active
        case .area(_):
            // Areas don't have archive status yet
            break
        case .resource(let note):
            note.isArchived = false
        }
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        }
        try? modelContext.save()
    }
    
    private func deleteItem(_ item: ArchiveItem) {
        switch item {
        case .project(let project):
            modelContext.delete(project)
        case .area(let area):
            modelContext.delete(area)
        case .resource(let note):
            modelContext.delete(note)
        }
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        }
        try? modelContext.save()
    }
    
    private func restoreSelectedItems() {
        let itemsToRestore = filteredItems.filter { selectedItems.contains($0.id) }
        for item in itemsToRestore {
            restoreItem(item)
        }
    }
    
    private func deleteSelectedItems() {
        let itemsToDelete = filteredItems.filter { selectedItems.contains($0.id) }
        for item in itemsToDelete {
            deleteItem(item)
        }
        selectedItems.removeAll()
        try? modelContext.save()
    }
    
    private var filteredArchivedProjects: [Project] {
        let archived = projects.filter { $0.status == .completed || $0.status == .paused }
        
        switch selectedCategory {
        case .all, .projects:
            return archived
        case .areas, .resources:
            return []
        }
    }
    
    private var filteredArchivedAreas: [Area] {
        switch selectedCategory {
        case .all, .areas:
            // Areas don't have archived status yet
            return []
        case .projects, .resources:
            return []
        }
    }
    
    private var filteredArchivedResources: [Note] {
        switch selectedCategory {
        case .all, .resources:
            return resources.filter { $0.isArchived }
        case .projects, .areas:
            return []
        }
    }
}

enum ArchiveCategory: String, CaseIterable {
    case all = "All"
    case projects = "Projects"
    case areas = "Areas"
    case resources = "Resources"
}


#Preview {
    ArchivesView()
        .modelContainer(for: [Project.self, Area.self, Note.self])
}

