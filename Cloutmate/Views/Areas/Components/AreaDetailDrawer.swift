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
    @State private var isExpanded: Bool = false
    @State private var auroraInsight: String = ""
    
    var linkedProjects: [CloutmateShared.Project] {
        projects.filter { $0.areaId == area.id }
    }
    
    var linkedNotes: [Note] {
        notes.filter { $0.areaId == area.id }
    }
    
    var arteColor: Color {
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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // ARTE Color Bar
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [arteColor.opacity(0.6), arteColor.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    // Header: Editable Title, Tags, Status
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Area Title", text: $editedTitle)
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                            .textFieldStyle(.plain)
                            .onChange(of: editedTitle) { _, newValue in
                                area.title = newValue
                                area.updatedAt = Date()
                                try? modelContext.save()
                            }
                        
                        // Tags Row
                        EditableTagsView(tags: $editedTags)
                            .onChange(of: editedTags) { _, newValue in
                                area.tags = newValue
                                area.updatedAt = Date()
                                try? modelContext.save()
                            }
                        
                        // Status Dropdown
                        Menu {
                            ForEach([AreaStatus.active, .reviewNeeded, .archived], id: \.self) { status in
                                Button(action: {
                                    editedStatus = status
                                    area.status = status
                                    area.updatedAt = Date()
                                    try? modelContext.save()
                                }) {
                                    HStack {
                                        Text(status.rawValue.capitalized)
                                        if editedStatus == status {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text("Status: \(editedStatus.rawValue.capitalized)")
                                    .font(.caption)
                                    .foregroundColor(glassColorSystem.textSecondary())
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(glassColorSystem.glassTint(for: .surface).opacity(0.3))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    // Extended Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                            .foregroundColor(glassColorSystem.textPrimary())
                        
                        TextEditor(text: $editedNotes)
                            .font(.body)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(glassColorSystem.glassTint(for: .surface).opacity(0.3))
                            .cornerRadius(8)
                            .onChange(of: editedNotes) { _, newValue in
                                area.notes = newValue.isEmpty ? nil : newValue
                                area.updatedAt = Date()
                                try? modelContext.save()
                            }
                    }
                    .padding(.horizontal, 20)
                    
                    // Linked Entities Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Linked Entities")
                            .font(.headline)
                            .foregroundColor(glassColorSystem.textPrimary())
                            .padding(.horizontal, 20)
                        
                        // Projects Card
                        LinkedEntitiesCard(
                            title: "Projects",
                            icon: "folder.fill",
                            color: .kosmicBlue,
                            count: linkedProjects.count,
                            items: linkedProjects.prefix(5).map { $0.title }
                        )
                        
                        // Notes Card
                        LinkedEntitiesCard(
                            title: "Notes",
                            icon: "doc.text.fill",
                            color: .kosmicPurple,
                            count: linkedNotes.count,
                            items: linkedNotes.prefix(5).map { $0.title }
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Aurora Insight Card
                    if !auroraInsight.isEmpty {
                        GlassPanel(tier: .contentCard, cornerRadius: 12) {
                            VStack(alignment: .leading, spacing: 8) {
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
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 20)
            }
            .background(Color(.windowBackgroundColor))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
        .frame(minWidth: 400, idealWidth: 450, maxWidth: 500)
        .background(.ultraThinMaterial)
        .onAppear {
            editedTitle = area.title
            editedNotes = area.notes ?? ""
            editedTags = area.tags
            editedStatus = area.status
            loadAuroraInsight()
        }
    }
    
    private func loadAuroraInsight() {
        // Placeholder - will be integrated with AuroraPredictiveService
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
                        if !newTag.isEmpty && !tags.contains(newTag) {
                            tags.append(newTag)
                            newTag = ""
                        }
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

