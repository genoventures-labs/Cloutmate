//
//  ProjectTimelineView.swift
//  Cloutmate
//
//  Timeline view for Projects with milestone visualization
//

import SwiftUI
import SwiftData
import CloutmateShared

struct ProjectTimelineView: View {
    let projects: [Project]
    let tasks: [Task]
    let areas: [Area]
    let onProjectSelected: (Project) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var scrollOffset: CGFloat = 0
    @State private var selectedProject: Project?
    
    var dateRange: (start: Date, end: Date) {
        let allDates = projects.compactMap { $0.dueDate } + projects.map { $0.createdAt }
        guard let minDate = allDates.min(), let maxDate = allDates.max() else {
            let now = Date()
            return (now, Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now)
        }
        return (minDate, maxDate)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if projects.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    GeometryReader { geometry in
                        ZStack(alignment: .topLeading) {
                            // Background Wave
                            if !reduceMotion {
                                FocusGravityWave(
                                    metrics: calculateOverallMetrics(),
                                    width: max(geometry.size.width, 1000),
                                    height: 200
                                )
                                .opacity(0.3)
                                .offset(y: 100)
                            }
                            
                            // Timeline Baseline
                            timelineBaseline(width: max(geometry.size.width, 1000))
                                .offset(y: 100)
                            
                            // Project Milestones
                            ForEach(Array(projects.sorted(by: { ($0.dueDate ?? $0.createdAt) < ($1.dueDate ?? $1.createdAt) }).enumerated()), id: \.element.id) { index, project in
                                TimelineMilestone(
                                    project: project,
                                    tasks: tasks.filter { $0.projectId == project.id },
                                    dateRange: dateRange,
                                    timelineWidth: max(geometry.size.width, 1000),
                                    onTap: {
                                        selectedProject = project
                                        onProjectSelected(project)
                                    }
                                )
                            }
                        }
                        .frame(width: max(geometry.size.width, 1000))
                        .padding(.horizontal, 40)
                    }
                    .frame(height: 300)
                }
            }
        }
        .sheet(item: $selectedProject) { project in
            ProjectSnapshotDrawer(project: project)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "timeline.selection")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No projects")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Create projects to see them on the timeline")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }
    
    private func timelineBaseline(width: CGFloat) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.kosmicBlue, .kosmicPurple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: 2)
    }
    
    private func calculateOverallMetrics() -> ProjectFocusMetrics {
        let allMetrics = projects.compactMap { project in
            ProjectFocusGravityService.shared.focusMetrics(for: project, modelContext: modelContext)
        }
        
        guard !allMetrics.isEmpty else {
            return ProjectFocusMetrics(
                cognitiveFocus: 0.5,
                creativeFlow: 0.5,
                completionEnergy: 0.5,
                lastActiveAt: nil,
                avgSessionDuration: 0,
                weeklyTrend: []
            )
        }
        
        let avgCognitive = allMetrics.map { $0.cognitiveFocus }.reduce(0, +) / Double(allMetrics.count)
        let avgCreative = allMetrics.map { $0.creativeFlow }.reduce(0, +) / Double(allMetrics.count)
        let avgCompletion = allMetrics.map { $0.completionEnergy }.reduce(0, +) / Double(allMetrics.count)
        
        return ProjectFocusMetrics(
            cognitiveFocus: avgCognitive,
            creativeFlow: avgCreative,
            completionEnergy: avgCompletion,
            lastActiveAt: nil,
            avgSessionDuration: 0,
            weeklyTrend: []
        )
    }
}

// MARK: - Timeline Milestone

struct TimelineMilestone: View {
    let project: Project
    let tasks: [Task]
    let dateRange: (start: Date, end: Date)
    let timelineWidth: CGFloat
    let onTap: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @State private var isHovered = false
    @State private var focusMetrics: ProjectFocusMetrics?
    
    var position: CGFloat {
        let projectDate = project.dueDate ?? project.createdAt
        let totalDuration = dateRange.end.timeIntervalSince(dateRange.start)
        guard totalDuration > 0 else { return 0 }
        let offsetFromStart = projectDate.timeIntervalSince(dateRange.start)
        let ratio = CGFloat(offsetFromStart / totalDuration)
        return min(max(ratio * timelineWidth, 0), timelineWidth - 16)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Milestone Dot
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .kosmicBlue.opacity(0.8),
                                .kosmicPurple.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 16, height: 16)
                
                if let metrics = focusMetrics {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .kosmicBlue.opacity(metrics.cognitiveFocus),
                                    .kosmicPurple.opacity(metrics.creativeFlow),
                                    .kosmicGreen.opacity(metrics.completionEnergy)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 24, height: 24)
                }
            }
            .shadow(color: .kosmicBlue.opacity(0.5), radius: 4)
            .scaleEffect(isHovered ? 1.3 : 1.0)
            .animation(.spring(duration: 0.3), value: isHovered)
            
            // Project Title (shown on hover)
            if isHovered {
                VStack(spacing: 4) {
                    Text(project.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(glassColorSystem.textPrimary())
                        .lineLimit(1)
                    
                    if let dueDate = project.dueDate {
                        Text(dueDate, format: .dateTime.month().day())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    GlassPanel(tier: .overlay, cornerRadius: 6) {
                        EmptyView()
                    }
                )
                .transition(.opacity.combined(with: .scale))
            }
        }
        .position(x: position, y: 100)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
        .task {
            focusMetrics = ProjectFocusGravityService.shared.focusMetrics(for: project, modelContext: modelContext)
        }
    }
}

// MARK: - Project Snapshot Drawer

struct ProjectSnapshotDrawer: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(project.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let goal = project.goal {
                        Text(goal)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Focus Graph Snippet
                    Text("Focus Gravity")
                        .font(.headline)
                    
                    // Add focus graph visualization here
                }
                .padding()
            }
            .navigationTitle("Project Snapshot")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 400, height: 500)
    }
}

