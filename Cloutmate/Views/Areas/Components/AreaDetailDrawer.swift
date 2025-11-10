//
//  AreaDetailDrawer.swift
//  Cloutmate
//
//  Areas V2 - Detail drawer with full area information
//

import SwiftUI
import SwiftData
import CloutmateShared

struct AreaDetailDrawer: View {
    @Bindable var area: Area
    let projects: [CloutmateShared.Project]
    let notes: [Note]
    let onDismiss: () -> Void
    let onAddProject: () -> Void
    let onAddNote: () -> Void
    let onArchive: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var editedTitle: String = ""
    @State private var editedNotes: String = ""
    @State private var editedTags: [String] = []
    @State private var editedStatus: AreaStatus = .active
    @State private var auroraInsight: String = ""
    
    private var linkedProjects: [CloutmateShared.Project] {
        projects.filter { $0.areaId == area.id }
    }
    
    private var linkedNotes: [Note] {
        notes.filter { $0.areaId == area.id }
    }
    
    private var arteColor: Color {
        let state = ReactiveThemeManager.shared.currentState
        switch state {
        case .calm: return .kosmicGreen
        case .focused: return .kosmicBlue
        case .energized: return .kosmicPurple
        case .reflective: return .kosmicPurple.opacity(0.8)
        case .fatigued: return .gray
        }
    }
    
    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                focusSidebar
                
                VStack(spacing: 0) {
                    header
                        .padding()
                        .background(.ultraThinMaterial)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            descriptionSection
                            linkedEntitiesSection
                            if !auroraInsight.isEmpty {
                                auroraInsightSection
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 24)
                    }
                    .background(Color(.windowBackgroundColor))
                    
                    actionsFooter
                        .padding(20)
                        .background(.ultraThinMaterial)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(glassColorSystem.backgroundColor())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        saveAndDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .frame(idealWidth: 800, idealHeight: 600)
        .onAppear {
            editedTitle = area.title
            editedNotes = area.notes ?? ""
            editedTags = area.tags
            editedStatus = area.status
            loadAuroraInsight()
        }
    }
    
    private var focusSidebar: some View {
        RoundedRectangle(cornerRadius: 0, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [arteColor.opacity(0.85), arteColor.opacity(0.35)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 4)
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                TextField("Area Title", text: $editedTitle)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .textFieldStyle(.plain)
                    .onChange(of: editedTitle) { _, newValue in
                        area.title = newValue
                        area.updatedAt = Date()
                        try? modelContext.save()
                    }
                
                Spacer()
                
                Menu {
                    ForEach([AreaStatus.active, .reviewNeeded, .archived], id: \.self) { status in
                        Button(action: {
                            editedStatus = status
                            area.status = status
                            area.updatedAt = Date()
                            try? modelContext.save()
                        }) {
                            Label(status.rawValue.capitalized, systemImage: editedStatus == status ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "flag")
                        Text(editedStatus.rawValue.capitalized)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(glassColorSystem.glassTint(for: .surface).opacity(0.3))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            EditableTagsView(tags: $editedTags)
                .onChange(of: editedTags) { _, newValue in
                    area.tags = newValue
                    area.updatedAt = Date()
                    try? modelContext.save()
                }
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Description")
                .font(.headline)
                .foregroundColor(glassColorSystem.textPrimary())
            
            TextEditor(text: $editedNotes)
                .font(.body)
                .frame(minHeight: 160)
                .padding(10)
                .background(glassColorSystem.glassTint(for: .surface).opacity(0.3))
                .cornerRadius(10)
                .onChange(of: editedNotes) { _, newValue in
                    area.notes = newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : newValue
                    area.updatedAt = Date()
                    try? modelContext.save()
                }
        }
    }
    
    private var linkedEntitiesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Linked Entities")
                .font(.headline)
                .foregroundColor(glassColorSystem.textPrimary())
            
            LinkedEntitiesCard(
                title: "Projects",
                icon: "folder.fill",
                color: .kosmicBlue,
                count: linkedProjects.count,
                items: linkedProjects.prefix(5).map { $0.title }
            )
            
            LinkedEntitiesCard(
                title: "Notes",
                icon: "doc.text.fill",
                color: .kosmicPurple,
                count: linkedNotes.count,
                items: linkedNotes.prefix(5).map { $0.title }
            )
        }
    }
    
    private var auroraInsightSection: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.kosmicPurple)
                    Text("Aurora Insight")
                        .font(.headline)
                        .foregroundColor(glassColorSystem.textPrimary())
                }
                
                Text(auroraInsight)
                    .font(.body)
                    .foregroundColor(glassColorSystem.textSecondary())
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var actionsFooter: some View {
        HStack(spacing: 12) {
            Button(action: {
                saveEdits()
                onArchive()
            }) {
                Label("Archive Area", systemImage: "archivebox")
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button(action: {
                saveEdits()
                onAddProject()
            }) {
                Label("Link Project", systemImage: "link")
            }
            .buttonStyle(.bordered)
            
            Button(action: {
                saveEdits()
                onAddNote()
            }) {
                Label("Link Note", systemImage: "doc.text")
            }
            .buttonStyle(.bordered)
            
            Button(action: saveAndDismiss) {
                Text("Done")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private func saveEdits() {
        area.title = editedTitle
        area.notes = editedNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editedNotes
        area.tags = editedTags
        area.status = editedStatus
        area.updatedAt = Date()
        try? modelContext.save()
    }
    
    private func saveAndDismiss() {
        saveEdits()
        onDismiss()
    }
    
    private func loadAuroraInsight() {
        auroraInsight = "You've maintained steady focus in this area. Consider reviewing linked projects for updates."
    }
}

struct EditableTagsView: View {
    @Binding var tags: [String]
    @State private var newTag: String = ""
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    AreaTagChip(text: tag) {
                        tags.removeAll { $0 == tag }
                    }
                }
                
                TextField("Add tag", text: $newTag)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .frame(width: 80)
                    .onSubmit {
                        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
                        tags.append(trimmed)
                        newTag = ""
                    }
            }
        }
    }
}

struct AreaTagChip: View {
    let text: String
    let onDelete: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.kosmicBlue)
        .cornerRadius(8)
    }
}

struct LinkedEntitiesCard: View {
    let title: String
    let icon: String
    let color: Color
    let count: Int
    let items: [String]
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                    Text(title)
                        .font(.headline)
                        .foregroundColor(glassColorSystem.textPrimary())
                    Text("(\(count))")
                        .font(.caption)
                        .foregroundColor(glassColorSystem.textSecondary())
                }
                
                if items.isEmpty {
                    Text("No \(title.lowercased()) linked")
                        .font(.caption)
                        .foregroundColor(glassColorSystem.textTertiary())
                        .padding(.vertical, 8)
                } else {
                    ForEach(items, id: \.self) { item in
                        Text(item)
                            .font(.body)
                            .foregroundColor(glassColorSystem.textSecondary())
                            .lineLimit(1)
                    }
                    
                    if count > items.count {
                        Text("+\(count - items.count) more")
                            .font(.caption)
                            .foregroundColor(glassColorSystem.textTertiary())
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    let area = Area(title: "Health & Wellness", notes: "Maintaining physical and mental health.")
    area.tags = ["personal", "health"]
    
    return AreaDetailDrawer(
        area: area,
        projects: [],
        notes: [],
        onDismiss: {},
        onAddProject: {},
        onAddNote: {},
        onArchive: {}
    )
    .environmentObject(GlassColorSystem())
}

