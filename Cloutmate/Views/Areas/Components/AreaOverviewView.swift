//
//  AreaOverviewView.swift
//  Cloutmate
//
//  Dashboard-style overview view for Areas with metrics and insights
//

import SwiftUI
import SwiftData
import CloutmateShared

struct AreaOverviewView: View {
    let areas: [Area]
    let projects: [CloutmateShared.Project]
    let notes: [Note]
    let tasks: [CloutmateShared.Task]
    let onAreaSelected: (Area) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    
    var activeAreasCount: Int {
        areas.filter { $0.status == .active }.count
    }
    
    var totalProjectsCount: Int {
        projects.count
    }
    
    var areasNeedingReview: Int {
        areas.filter { AreaReviewService.shared.status(for: $0).isDue }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Metrics Row
            HStack(spacing: 16) {
                metricCard(
                    title: "Active Areas",
                    value: "\(activeAreasCount)",
                    icon: "rectangle.stack.fill",
                    color: .kosmicBlue
                )
                
                metricCard(
                    title: "Total Projects",
                    value: "\(totalProjectsCount)",
                    icon: "folder.fill",
                    color: .kosmicPurple
                )
                
                metricCard(
                    title: "Need Review",
                    value: "\(areasNeedingReview)",
                    icon: "calendar.badge.exclamationmark",
                    color: .orange
                )
            }
            
            // Top Areas
            if !areas.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("All Areas")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                    
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 280, maximum: 350), spacing: 16)
                        ],
                        spacing: 16
                    ) {
                        ForEach(areas.prefix(6)) { area in
                            let reviewStatus = AreaReviewService.shared.status(for: area)
                            AreaCardV2(
                                area: area,
                                projects: projects,
                                notes: notes,
                                onTap: {
                                    onAreaSelected(area)
                                },
                                onEdit: {
                                    onAreaSelected(area)
                                },
                                onArchive: {},
                                onDelete: {},
                                isReviewDue: reviewStatus.isDue,
                                onReview: reviewStatus.isDue ? {
                                    onAreaSelected(area)
                                } : nil
                            )
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func metricCard(title: String, value: String, icon: String, color: Color) -> some View {
        DashboardTile(accent: color) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(color)
                    Spacer()
                }
                
                Text(value)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(glassColorSystem.textSecondary())
            }
        }
    }
}

#Preview {
    AreaOverviewView(
        areas: [],
        projects: [],
        notes: [],
        tasks: [],
        onAreaSelected: { _ in }
    )
    .padding()
    .environmentObject(GlassColorSystem())
}

