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
                        .font(.headline)
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
                        .font(.headline)
                        .foregroundColor(glassColorSystem.textPrimary())
                    
                    LazyVStack(spacing: 8) {
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
                        .font(.headline)
                        .foregroundColor(glassColorSystem.textPrimary())
                    
                    LazyVStack(spacing: 12) {
                        ForEach(recentArtifacts.prefix(3)) { artifact in
                            CompactArtifactCard(artifact: artifact)
                        }
                    }
                }
            }
            
            // Aurora Reflection
            if !auroraReflection.isEmpty {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundColor(.kosmicPurple)
                    Text(auroraReflection)
                        .font(.subheadline)
                        .foregroundColor(glassColorSystem.textSecondary())
                        .italic()
                }
                .padding(.top, 8)
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
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(project.title)
                        .font(.headline)
                        .foregroundColor(glassColorSystem.textPrimary())
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text("\(Int(completionPercentage * 100))%")
                            .font(.caption)
                            .foregroundColor(.kosmicBlue)
                        
                        if let nextTask = nextTask {
                            Text("• Next: \(nextTask.title)")
                                .font(.caption)
                                .foregroundColor(glassColorSystem.textSecondary())
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(12)
        }
    }
}

// MARK: - Compact Task Card

struct CompactTaskCard: View {
    @Bindable var task: Task
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            HStack(spacing: 12) {
                Button {
                    task.status = task.status == .done ? .inProgress : .done
                    try? modelContext.save()
                } label: {
                    Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundColor(task.status == .done ? .kosmicGreen : glassColorSystem.textSecondary())
                }
                .buttonStyle(.plain)
                
                Text(task.title)
                    .font(.subheadline)
                    .foregroundColor(glassColorSystem.textPrimary())
                    .strikethrough(task.status == .done)
                    .lineLimit(2)
                
                Spacer()
            }
            .padding(12)
        }
    }
}

// MARK: - Compact Artifact Card

struct CompactArtifactCard: View {
    let artifact: Artifact
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.kosmicGreen)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(artifact.title)
                        .font(.subheadline)
                        .foregroundColor(glassColorSystem.textPrimary())
                        .lineLimit(1)
                    
                    Text(artifact.artifactState.displayName)
                        .font(.caption)
                        .foregroundColor(glassColorSystem.textSecondary())
                }
                
                Spacer()
            }
            .padding(12)
        }
    }
}

#Preview {
    ActiveWorkfeedView()
        .padding()
        .environmentObject(GlassColorSystem())
}

