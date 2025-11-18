//
//  AreaBoardView.swift
//  FocusOS
//
//  Kanban-style board view for Areas organized by status
//

import SwiftUI
import SwiftData
import FocusOSShared

struct AreaBoardView: View {
    let areas: [Area]
    let projects: [FocusOSShared.Project]
    let notes: [Note]
    let onAreaSelected: (Area) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var activeAreas: [Area] {
        areas.filter { $0.status == .active }
    }
    
    var reviewNeededAreas: [Area] {
        areas.filter { AreaReviewService.shared.status(for: $0).isDue }
    }
    
    var archivedAreas: [Area] {
        areas.filter { $0.status == .archived }
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 20) {
                // Active Areas
                boardColumn(
                    title: "Active",
                    areas: activeAreas,
                    color: .kosmicBlue
                )
                
                // Review Needed
                if !reviewNeededAreas.isEmpty {
                    boardColumn(
                        title: "Review Needed",
                        areas: reviewNeededAreas,
                        color: .orange
                    )
                }
                
                // Archived
                if !archivedAreas.isEmpty {
                    boardColumn(
                        title: "Archived",
                        areas: archivedAreas,
                        color: .gray
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    @ViewBuilder
    private func boardColumn(title: String, areas: [Area], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                Text("\(areas.count)")
                    .font(.caption)
                    .foregroundStyle(glassColorSystem.textSecondary())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            VStack(spacing: 12) {
                ForEach(areas) { area in
                    AreaBoardCard(
                        area: area,
                        projects: projects,
                        notes: notes,
                        onTap: {
                            onAreaSelected(area)
                        }
                    )
                }
            }
        }
        .frame(width: 320)
        .background(
            DashboardTile(accent: color.opacity(0.1)) {
                EmptyView()
            }
        )
    }
}

private struct AreaBoardCard: View {
    let area: Area
    let projects: [FocusOSShared.Project]
    let notes: [Note]
    let onTap: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var linkedProjectsCount: Int {
        projects.filter { $0.areaId == area.id }.count
    }
    
    var accentColor: Color {
        switch area.colorAccent {
        case "kosmicBlue": return .kosmicBlue
        case "kosmicPurple": return .kosmicPurple
        case "kosmicGreen": return .kosmicGreen
        default: return .kosmicBlue
        }
    }
    
    var body: some View {
        DashboardTile(accent: accentColor) {
            VStack(alignment: .leading, spacing: 10) {
                Text(area.title)
                    .font(.headline)
                    .foregroundStyle(glassColorSystem.textPrimary())
                    .lineLimit(2)
                
                if let notes = area.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(glassColorSystem.textSecondary())
                        .lineLimit(3)
                }
                
                if linkedProjectsCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill")
                            .font(.caption2)
                        Text("\(linkedProjectsCount) projects")
                            .font(.caption2)
                    }
                    .foregroundStyle(glassColorSystem.textTertiary())
                }
            }
        }
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    AreaBoardView(
        areas: [],
        projects: [],
        notes: [],
        onAreaSelected: { _ in }
    )
    .padding()
    .environmentObject(GlassColorSystem())
}

