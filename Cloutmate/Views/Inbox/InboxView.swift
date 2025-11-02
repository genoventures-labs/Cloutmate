//
//  InboxView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import CloutmateShared

struct InboxView: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \InboxItem.createdAt, order: .reverse) 
    private var inboxItems: [InboxItem]
    
    @State private var searchText = ""
    @State private var selectedType: String?
    @State private var selectedDateRange: DateRange?
    @State private var selectedItems = Set<UUID>()
    @State private var selectedItem: InboxItem?
    
    var unconvertedItems: [InboxItem] {
        inboxItems.filter { $0.convertedAt == nil }
    }
    
    var filteredItems: [InboxItem] {
        var filtered = unconvertedItems
        
        if !searchText.isEmpty {
            filtered = filtered.filter { 
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if let type = selectedType {
            filtered = filtered.filter { $0.itemType == type }
        }
        
        if let range = selectedDateRange {
            filtered = filtered.filter { item in
                let itemDate = item.createdAt
                let now = Date()
                switch range {
                case .today:
                    return Calendar.current.isDateInToday(itemDate)
                case .thisWeek:
                    return Calendar.current.isDate(itemDate, equalTo: now, toGranularity: .weekOfYear)
                case .thisMonth:
                    return Calendar.current.isDate(itemDate, equalTo: now, toGranularity: .month)
                case .all:
                    return true
                }
            }
        }
        
        return filtered
    }
    
    enum DateRange: String {
        case all = "All"
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
    }
    
    private var searchAndFiltersSection: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search inbox...", text: $searchText)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "All",
                        isSelected: selectedType == nil && selectedDateRange == nil,
                        action: { 
                            selectedType = nil
                            selectedDateRange = nil
                        }
                    )
                    
                    ForEach(["text", "file", "url"], id: \.self) { type in
                        FilterChip(
                            title: type.capitalized,
                            isSelected: selectedType == type,
                            action: { selectedType = type }
                        )
                    }
                    
                    ForEach([DateRange.all, .today, .thisWeek, .thisMonth], id: \.self) { range in
                        FilterChip(
                            title: range.rawValue,
                            isSelected: selectedDateRange == range,
                            action: { selectedDateRange = range }
                        )
                    }
                }
            }
        }
        .padding()
    }
    
    private var tableSection: some View {
        Table(filteredItems, selection: $selectedItems) {
            TableColumn("Content") { item in
                Text(item.content)
                    .lineLimit(2)
                    .font(.body)
                    .contextMenu {
                        Button("Convert to Task") {
                            selectedItem = item
                            convertItemToTask(item)
                        }
                        Button("Convert to Note") {
                            selectedItem = item
                            convertItemToNote(item)
                        }
                        Button("Convert to Post") {
                            selectedItem = item
                            convertItemToPost(item)
                        }
                        Button("Convert to Project") {
                            selectedItem = item
                            convertItemToProject(item)
                        }
                        Divider()
                        Button("View Details") {
                            selectedItem = item
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            deleteItem(item)
                        }
                    }
            }
            .width(min: 250, ideal: 400)
            
            TableColumn("Type") { item in
                HStack(spacing: 6) {
                    Image(systemName: itemTypeIcon(item.itemType))
                        .foregroundColor(itemTypeColor(item.itemType))
                    Text(itemTypeLabel(item.itemType))
                        .font(.caption)
                }
            }
            .width(min: 100)
            
            TableColumn("Created") { item in
                Text(item.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .width(min: 120)
            
            TableColumn("Quick Actions") { item in
                HStack(spacing: 8) {
                    QuickConvertButton(icon: "checkmark.circle", color: .kosmicBlue) {
                        convertItemToTask(item)
                    }
                    QuickConvertButton(icon: "doc.text", color: .kosmicPurple) {
                        convertItemToNote(item)
                    }
                    QuickConvertButton(icon: "square.and.pencil", color: .orange) {
                        convertItemToPost(item)
                    }
                    QuickConvertButton(icon: "folder.fill", color: .kosmicGreen) {
                        convertItemToProject(item)
                    }
                }
            }
            .width(min: 180)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchAndFiltersSection
            
            if filteredItems.isEmpty {
                ContentUnavailableView(
                    unconvertedItems.isEmpty ? "Inbox is empty" : "No matches",
                    systemImage: "tray",
                    description: Text(unconvertedItems.isEmpty ? "Capture new items to get started" : "Try a different search or filter")
                )
                .frame(maxHeight: .infinity)
            } else {
                tableSection
            }
        }
        .background(Color(.windowBackgroundColor))
        .navigationTitle("Inbox")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !selectedItems.isEmpty {
                    Menu("Actions") {
                        Button("Convert Selected to Notes", systemImage: "doc.text") {
                            convertSelectedToNotes()
                        }
                        Divider()
                        Button("Delete Selected", systemImage: "trash") {
                            deleteSelectedItems()
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedItem) { item in
            InboxDetailSheet(item: item)
        }
    }
    
    private func itemTypeIcon(_ type: String) -> String {
        switch type {
        case "text": return "text.alignleft"
        case "file": return "doc"
        case "url": return "link"
        default: return "tray"
        }
    }
    
    private func itemTypeColor(_ type: String) -> Color {
        switch type {
        case "text": return .kosmicBlue
        case "file": return .kosmicPurple
        case "url": return .kosmicGreen
        default: return .gray
        }
    }
    
    private func itemTypeLabel(_ type: String) -> String {
        type.capitalized
    }
    
    private func convertItemToTask(_ item: InboxItem) {
        let task = Task(
            title: item.content.prefix(100).description,
            notes: item.fileURL ?? ""
        )
        modelContext.insert(task)
        item.convertedToType = "task"
        item.convertedToId = task.id
        item.convertedAt = Date()
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        }
        try? modelContext.save()
    }
    
    private func convertItemToNote(_ item: InboxItem) {
        let note = Note(
            title: item.content.prefix(50).description,
            markdown: item.content
        )
        modelContext.insert(note)
        item.convertedToType = "note"
        item.convertedToId = note.id
        item.convertedAt = Date()
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        }
        try? modelContext.save()
    }
    
    private func convertItemToPost(_ item: InboxItem) {
        let post = Post(caption: item.content)
        modelContext.insert(post)
        item.convertedToType = "post"
        item.convertedToId = post.id
        item.convertedAt = Date()
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        }
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
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        }
        try? modelContext.save()
    }
    
    private func deleteItem(_ item: InboxItem) {
        modelContext.delete(item)
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        }
        try? modelContext.save()
    }
    
    private func convertSelectedToNotes() {
        let itemsToConvert = filteredItems.filter { selectedItems.contains($0.id) }
        for item in itemsToConvert {
            convertItemToNote(item)
        }
    }
    
    private func deleteSelectedItems() {
        let itemsToDelete = filteredItems.filter { selectedItems.contains($0.id) }
        for item in itemsToDelete {
            modelContext.delete(item)
        }
        selectedItems.removeAll()
        try? modelContext.save()
    }
}

struct InboxItemCard: View {
    let item: InboxItem
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tray.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
                    .frame(width: 24, height: 24)
                Spacer()
                Text(item.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(item.content)
                .lineLimit(3)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        )
        .onTapGesture(perform: onTap)
    }
}

struct InboxDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let item: InboxItem
    @State private var showConvertSheet = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Header
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Triage Item")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text(item.createdAt, style: .date)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.bottom, 8)
                    
                    // Content
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Content")
                            .font(.system(size: 20, weight: .semibold))
                        
                        Text(item.content)
                            .font(.body)
                            .lineSpacing(6)
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
                            )
                    }
                    
                    // Convert Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Convert to...")
                            .font(.system(size: 20, weight: .semibold))
                        
                        HStack(spacing: 16) {
                            ConvertButton(icon: "checkmark.circle", title: "Task", color: .kosmicBlue) {
                                convertToTask()
                            }
                            ConvertButton(icon: "doc.text", title: "Note", color: .kosmicPurple) {
                                convertToNote()
                            }
                            ConvertButton(icon: "square.and.pencil", title: "Post", color: .orange) {
                                convertToPost()
                            }
                            ConvertButton(icon: "folder.fill", title: "Project", color: .kosmicGreen) {
                                convertToProject()
                            }
                        }
                    }
                }
                .padding(28)
            }
            .background(Color(.windowBackgroundColor))
            .navigationTitle("Triage Item")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func convertToTask() {
        let task = Task(
            title: item.content.prefix(100).description,
            notes: item.fileURL ?? ""
        )
        modelContext.insert(task)
        item.convertedToType = "task"
        item.convertedToId = task.id
        item.convertedAt = Date()
        try? modelContext.save()
        dismiss()
    }
    
    private func convertToNote() {
        let note = Note(
            title: item.content.prefix(50).description,
            markdown: item.content
        )
        modelContext.insert(note)
        item.convertedToType = "note"
        item.convertedToId = note.id
        item.convertedAt = Date()
        try? modelContext.save()
        dismiss()
    }
    
    private func convertToPost() {
        let post = Post(caption: item.content)
        modelContext.insert(post)
        item.convertedToType = "post"
        item.convertedToId = post.id
        item.convertedAt = Date()
        try? modelContext.save()
        dismiss()
    }
    
    private func convertToProject() {
        let project = Project(
            title: item.content.prefix(50).description
        )
        modelContext.insert(project)
        item.convertedToType = "project"
        item.convertedToId = project.id
        item.convertedAt = Date()
        try? modelContext.save()
        dismiss()
    }
}

struct QuickConvertButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(color.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
    }
}

struct ConvertButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(color)
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(color.opacity(0.1))
                    )
                
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    InboxView()
        .modelContainer(for: [InboxItem.self])
}

