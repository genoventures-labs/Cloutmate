//
//  ActiveWorkfeedView.swift
//  Cloutmate
//
//  Dashboard V2 - Active Workfeed with Ongoing Projects, Active Tasks, and Recent Artifacts
//

import SwiftUI
import SwiftData
import CloutmateShared

struct ActiveWorkfeedView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @Query(sort: \Project.updatedAt, order: .reverse)
    private var allProjects: [Project]
    
    @Query(sort: \Task.updatedAt, order: .reverse)
    private var allTasks: [Task]
    
    @Query(sort: \Artifact.createdAt, order: .reverse)
    private var allArtifacts: [Artifact]
    
    @State private var priorityProjects: [Project] = []
    @State private var priorityTasks: [Task] = []
    @State private var recentArtifacts: [Artifact] = []
    @State private var auroraReflection: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Ongoing Projects
            if !priorityProjects.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ongoing Projects")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(glassColorSystem.textPrimary())
                    
                    LazyVStack(spacing: 12) {
                        ForEach(priorityProjects.prefix(5)) { project in
                            CompactProjectCard(project: project)
                        }
                    }
                }
            }
            
            // Active Tasks
            if !priorityTasks.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Active Tasks")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(glassColorSystem.textPrimary())
                    
                    LazyVStack(spacing: 12) {
                        ForEach(priorityTasks.prefix(5)) { task in
                            CompactTaskCard(task: task)
                        }
                    }
                }
            }
            
            // Recent Artifacts
            if !recentArtifacts.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Artifacts")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(glassColorSystem.textPrimary())
                    
                    LazyVStack(spacing: 12) {
                        ForEach(recentArtifacts.prefix(3)) { artifact in
                            CompactArtifactTile(artifact: artifact)
                        }
                    }
                }
            }
            
            // Aurora Reflection
            if !auroraReflection.isEmpty {
                DashboardTile(accent: .kosmicPurple.opacity(0.85), padding: 18) {
                    HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundColor(.kosmicPurple)
                    Text(auroraReflection)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(glassColorSystem.textPrimary())
                        .italic()
                    }
                }
            }
        }
        .task {
            await loadData()
        }
    }
    
    @MainActor
    private func loadData() async {
        // Get priority projects (active, not completed)
        let priorityItems = PriorityEngine.shared.getTopObjects(ofType: "project", limit: 5, modelContext: modelContext)
        let projectIds = Set(priorityItems.map { $0.objectId })
        priorityProjects = allProjects.filter { projectIds.contains($0.id) && $0.status != .completed }
        
        // Get priority tasks (not completed)
        let taskPriorityItems = PriorityEngine.shared.getTopObjects(ofType: "task", limit: 5, modelContext: modelContext)
        let taskIds = Set(taskPriorityItems.map { $0.objectId })
        priorityTasks = allTasks.filter { taskIds.contains($0.id) && $0.status != .done }
        
        // Get recent artifacts (published or draft)
        recentArtifacts = allArtifacts.filter { $0.artifactState == .published || $0.artifactState == .draft }
        
        // Generate Aurora reflection (simplified for now)
        auroraReflection = generateAuroraReflection()
    }
    
    private func generateAuroraReflection() -> String {
        if priorityTasks.count >= 3 {
            return "Your current rhythm is steady — one more completed focus block will bring your streak to 5 days."
        } else if priorityProjects.count > 0 {
            return "You have \(priorityProjects.count) active projects pulling your attention."
        } else {
            return "A calm moment — perfect for reflection or planning."
        }
    }
}

// MARK: - Compact Project Card

struct CompactProjectCard: View {
    let project: Project
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Query private var allTasks: [Task]
    
    private var completionPercentage: Double {
        let projectTasks = allTasks.filter { $0.projectId == project.id }
        guard !projectTasks.isEmpty else { return 0.0 }
        let completed = projectTasks.filter { $0.status == .done }.count
        return Double(completed) / Double(projectTasks.count)
    }
    
    private var nextTask: Task? {
        allTasks.filter { $0.projectId == project.id && $0.status != .done }
            .sorted { $0.priority.rawValue > $1.priority.rawValue }
            .first
    }
    
    var body: some View {
        DashboardTile(accent: .kosmicBlue.opacity(0.9), padding: 18) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(project.title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundColor(glassColorSystem.textPrimary())
                        .lineLimit(1)
                    
                    HStack(spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "chart.bar.fill")
                                .font(.caption)
                                .foregroundColor(.kosmicBlue)
                        Text("\(Int(completionPercentage * 100))%")
                            .font(.caption)
                            .foregroundColor(.kosmicBlue)
                        }
                        
                        if let nextTask = nextTask {
                            Text("Next: \(nextTask.title)")
                                .font(.caption)
                                .foregroundColor(glassColorSystem.textSecondary())
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Compact Task Card

struct CompactTaskCard: View {
    @Bindable var task: Task
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        DashboardTile(accent: taskAccent, padding: 18) {
            HStack(spacing: 14) {
                Button {
                    task.status = task.status == .done ? .inProgress : .done
                    try? modelContext.save()
                } label: {
                    Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(taskAccent)
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                        .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(glassColorSystem.textPrimary())
                    .strikethrough(task.status == .done)
                    .lineLimit(2)
                    
                    if let dueDate = task.dueDate {
                        Text(dueDate, style: .time)
                            .font(.caption2)
                            .foregroundColor(glassColorSystem.textSecondary())
                    }
                }
                
                Spacer()
            }
        }
    }
    
    private var taskAccent: Color {
        if task.status == .done { return .kosmicGreen }
        switch task.priority {
        case .high: return .orange
        case .medium: return .kosmicPurple
        case .low: return .kosmicBlue
        }
    }
}

// MARK: - Compact Artifact Card

struct CompactArtifactTile: View {
    let artifact: Artifact
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        DashboardTile(accent: .kosmicPurple.opacity(0.85), padding: 18) {
            HStack(spacing: 14) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.kosmicGreen)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(artifact.title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundColor(glassColorSystem.textPrimary())
                        .lineLimit(1)
                    
                    Text(artifact.artifactState.displayName)
                        .font(.caption)
                        .foregroundColor(glassColorSystem.textSecondary())
                }
                
                Spacer()
            }
        }
    }
}

#Preview {
    ActiveWorkfeedView()
        .padding()
        .environmentObject(GlassColorSystem())
}

