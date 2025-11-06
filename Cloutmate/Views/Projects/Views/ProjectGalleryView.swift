//
//  ProjectGalleryView.swift
//  Cloutmate
//
//  Gallery view for Projects with visual showcase
//

import SwiftUI
import SwiftData
import CloutmateShared

struct ProjectGalleryView: View {
    let projects: [Project]
    let tasks: [Task]
    let areas: [Area]
    let onProjectSelected: (Project) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        if projects.isEmpty {
            emptyState
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(projects) { project in
                    ProjectGalleryCard(
                        project: project,
                        tasks: tasks.filter { $0.projectId == project.id },
                        areas: areas,
                        onTap: {
                            onProjectSelected(project)
                        }
                    )
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No projects")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Create your first project to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Project Gallery Card

struct ProjectGalleryCard: View {
    let project: Project
    let tasks: [Task]
    let areas: [Area]
    let onTap: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var isHovered = false
    @State private var focusMetrics: ProjectFocusMetrics?
    
    var area: Area? {
        guard let areaId = project.areaId else { return nil }
        return areas.first { $0.id == areaId }
    }
    
    var backgroundGradient: LinearGradient {
        let metrics = focusMetrics ?? ProjectFocusMetrics(
            cognitiveFocus: 0.3,
            creativeFlow: 0.3,
            completionEnergy: 0.3,
            lastActiveAt: nil,
            avgSessionDuration: 0,
            weeklyTrend: []
        )
        
        return LinearGradient(
            colors: [
                .kosmicBlue.opacity(metrics.cognitiveFocus * 0.6),
                .kosmicPurple.opacity(metrics.creativeFlow * 0.6),
                .kosmicGreen.opacity(metrics.completionEnergy * 0.6)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover Image/Gradient Area
            ZStack {
                backgroundGradient
                    .frame(height: 120)
                
                if isHovered, let metrics = focusMetrics {
                    FocusIntensityRings(metrics: metrics, isVisible: true)
                }
            }
            
            // Content Area
            VStack(alignment: .leading, spacing: 8) {
                Text(project.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundColor(glassColorSystem.textPrimary())
                
                HStack {
                    ProjectStatusBadge(status: project.status)
                    
                    if let dueDate = project.dueDate {
                        Text(dueDate, format: .dateTime.month().day())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if !tasks.isEmpty {
                    Text("\(tasks.filter { $0.status != .done }.count) tasks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
        }
        .frame(minHeight: 200)
        .background(
            GlassPanel(tier: .contentCard, cornerRadius: 12) {
                EmptyView()
            }
        )
        .shadow(color: .black.opacity(isHovered ? 0.15 : 0.05), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.3), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button("Open") {
                onTap()
            }
            Button("Edit") {
                // Edit action
            }
            Divider()
            Button("Archive") {
                // Archive action
            }
        }
        .task {
            focusMetrics = ProjectFocusGravityService.shared.focusMetrics(for: project, modelContext: modelContext)
        }
    }
}

