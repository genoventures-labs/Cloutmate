//
//  ProjectBoardView.swift
//  Cloutmate
//
//  Kanban board view for Projects with drag & drop
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Foundation
import CloutmateShared

struct ProjectBoardView: View {
    let projects: [Project]
    let tasks: [Task]
    let areas: [Area]
    let onProjectSelected: (Project) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    enum BoardLane: String, CaseIterable {
        case planning = "Planning"
        case building = "Building"
        case reviewing = "Reviewing"
        case complete = "Complete"
        
        var displayName: String {
            rawValue
        }
        
        var status: ProjectStatus {
            switch self {
            case .planning: return .paused
            case .building: return .active
            case .reviewing: return .active // Intermediate state
            case .complete: return .completed
            }
        }
        
        var focusColor: Color {
            switch self {
            case .planning: return .kosmicBlue
            case .building: return .kosmicPurple
            case .reviewing: return .kosmicGreen
            case .complete: return .gray
            }
        }
    }
    
    var projectsByLane: [BoardLane: [Project]] {
        var grouped: [BoardLane: [Project]] = [:]
        for lane in BoardLane.allCases {
            grouped[lane] = []
        }
        
        for project in projects {
            // Map status to lanes
            switch project.status {
            case .paused:
                grouped[.planning]?.append(project)
            case .active:
                // Distribute active projects between Building and Reviewing based on completion
                let completion = calculateCompletion(for: project)
                if completion > 0.75 {
                    grouped[.reviewing]?.append(project)
                } else {
                    grouped[.building]?.append(project)
                }
            case .completed:
                grouped[.complete]?.append(project)
            }
        }
        
        return grouped
    }
    
    func calculateCompletion(for project: Project) -> Double {
        let projectTasks = tasks.filter { $0.projectId == project.id }
        guard !projectTasks.isEmpty else { return 0.0 }
        let completed = projectTasks.filter { $0.status == .done }.count
        return Double(completed) / Double(projectTasks.count)
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(BoardLane.allCases, id: \.self) { lane in
                    BoardLaneColumn(
                        lane: lane,
                        projects: projectsByLane[lane] ?? [],
                        allProjects: projects,
                        tasks: tasks,
                        areas: areas,
                        onProjectSelected: onProjectSelected,
                        onProjectDropped: { project, newLane in
                            moveProject(project, to: newLane)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private func moveProject(_ project: Project, to lane: BoardLane) {
        switch lane {
        case .planning:
            project.status = .paused
        case .building, .reviewing:
            project.status = .active
        case .complete:
            project.status = .completed
        }
        
        project.updatedAt = Date()
        
        do {
            try modelContext.save()
            ProjectHaptics.playDrag()
        } catch {
            print("Failed to move project: \(error)")
        }
    }
}

// MARK: - Board Lane Column

struct BoardLaneColumn: View {
    let lane: ProjectBoardView.BoardLane
    let projects: [Project]
    let allProjects: [Project]
    let tasks: [Task]
    let areas: [Area]
    let onProjectSelected: (Project) -> Void
    let onProjectDropped: (Project, ProjectBoardView.BoardLane) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    
    @State private var laneMetrics: ProjectFocusMetrics?
    
    var averageFocusIntensity: Double {
        guard let metrics = laneMetrics else { return 0.0 }
        return (metrics.cognitiveFocus + metrics.creativeFlow + metrics.completionEnergy) / 3.0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Lane Header
            HStack {
                FocusGravityMarker(
                    metrics: laneMetrics ?? ProjectFocusMetrics(
                        cognitiveFocus: lane == .planning ? 0.7 : 0.3,
                        creativeFlow: lane == .building ? 0.7 : 0.3,
                        completionEnergy: lane == .reviewing ? 0.7 : 0.3,
                        lastActiveAt: nil,
                        avgSessionDuration: 0,
                        weeklyTrend: []
                    ),
                    size: 8
                )
                
                Text(lane.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(glassColorSystem.textPrimary())
                
                Spacer()
                
                Text("\(projects.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(width: 280)
            .background(
                lane.focusColor.opacity(0.1)
                    .overlay(
                        Rectangle()
                            .fill(lane.focusColor.opacity(0.2))
                            .frame(height: 2),
                        alignment: .top
                    )
            )
            .cornerRadius(8)
            
            // Projects in this lane
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(projects) { project in
                        BoardProjectCard(
                            project: project,
                            tasks: tasks.filter { $0.projectId == project.id },
                            areas: areas,
                            onTap: {
                                onProjectSelected(project)
                            }
                        )
                        .draggable(ProjectDragInfo(projectID: project.id))
                        .padding(.horizontal, 2)
                        .padding(.vertical, 1)
                    }
                    
                    // Quick Add Button
                    Button(action: {
                        // Create project with lane status
                    }) {
                        HStack {
                            Image(systemName: "plus")
                                .font(.caption)
                            Text("Add Project")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 600)
        }
        .frame(width: 280)
        .padding(.vertical, 8)
        .onDrop(of: [.text], delegate: ProjectDropDelegate(
            targetLane: lane,
            projects: allProjects,
            onProjectDropped: onProjectDropped,
            modelContext: modelContext
        ))
        .task {
            // Calculate average metrics for lane
            if !projects.isEmpty {
                let metrics = projects.compactMap { project in
                    ProjectFocusGravityService.shared.focusMetrics(for: project, modelContext: modelContext)
                }
                
                if !metrics.isEmpty {
                    let avgCognitive = metrics.map { $0.cognitiveFocus }.reduce(0, +) / Double(metrics.count)
                    let avgCreative = metrics.map { $0.creativeFlow }.reduce(0, +) / Double(metrics.count)
                    let avgCompletion = metrics.map { $0.completionEnergy }.reduce(0, +) / Double(metrics.count)
                    
                    laneMetrics = ProjectFocusMetrics(
                        cognitiveFocus: avgCognitive,
                        creativeFlow: avgCreative,
                        completionEnergy: avgCompletion,
                        lastActiveAt: nil,
                        avgSessionDuration: 0,
                        weeklyTrend: []
                    )
                }
            }
        }
    }
}

// MARK: - Board Project Card

struct BoardProjectCard: View {
    let project: Project
    let tasks: [Task]
    let areas: [Area]
    let onTap: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(project.title)
                .font(.headline)
                .lineLimit(2)
                .foregroundColor(glassColorSystem.textPrimary())
            
            if let goal = project.goal {
                Text(goal)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                ProjectStatusBadge(status: project.status)
                
                if !tasks.isEmpty {
                    Text("\(tasks.filter { $0.status != .done }.count) tasks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GlassPanel(tier: .contentCard, cornerRadius: 8) {
                EmptyView()
            }
        )
        .shadow(color: .black.opacity(isHovered ? 0.1 : 0.05), radius: isHovered ? 4 : 2, y: isHovered ? 2 : 1)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(duration: 0.3), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Drag & Drop Support

struct ProjectDragInfo: Codable, Transferable {
    let projectID: UUID
    
    init(projectID: UUID) {
        self.projectID = projectID
    }
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .text)
    }
}

struct ProjectDropDelegate: DropDelegate {
    let targetLane: ProjectBoardView.BoardLane
    let projects: [Project]
    let onProjectDropped: (Project, ProjectBoardView.BoardLane) -> Void
    let modelContext: ModelContext
    
    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.text]).first else {
            return false
        }
        
        _ = itemProvider.loadTransferable(type: ProjectDragInfo.self) { result in
            guard case .success(let dragInfo) = result else {
                return
            }
            
            _Concurrency.Task { @MainActor in
                guard let project = projects.first(where: { $0.id == dragInfo.projectID }) else {
                    return
                }
                onProjectDropped(project, targetLane)
            }
        }
        
        return true
    }
}

