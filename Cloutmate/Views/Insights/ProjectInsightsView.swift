//
//  ProjectInsightsView.swift
//  Cloutmate
//
//  Project performance analytics
//

import SwiftUI
import SwiftData
import Charts
import CloutmateShared

struct ProjectInsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var projects: [Project]
    @Query private var posts: [CloutmateShared.Post]
    @Query private var tasks: [Task]
    @Query private var insights: [InsightSnapshot]
    
    @State private var selectedProject: Project?
    @State private var showProjectDetail = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    Text("Project Insights")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding()
                .glassPanel(tier: .overlay, cornerRadius: 12)
                
                // Active Projects Summary
                ActiveProjectsSummary(projects: activeProjects, posts: posts, tasks: tasks)
                
                // Project performance cards
                ForEach(activeProjects) { project in
                    ProjectPerformanceCard(
                        project: project,
                        posts: posts.filter { project.postIds.contains($0.id) },
                        tasks: tasks.filter { $0.projectId == project.id },
                        onTap: {
                            selectedProject = project
                            showProjectDetail = true
                        }
                    )
                    .padding(.horizontal)
                }
                
                // Completed projects
                if !completedProjects.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                            Text("Completed Projects")
                                .font(.headline)
                        }
                        .padding(.horizontal)
                        
                        ForEach(completedProjects.prefix(5)) { project in
                            CompletedProjectCard(project: project)
                                .padding(.horizontal)
                        }
                    }
                }
            }
        }
        .background(Color.clear)
        .navigationTitle("Project Insights")
        .sheet(isPresented: $showProjectDetail) {
            if let project = selectedProject {
                ProjectDetailInsightsSheet(project: project, posts: posts, tasks: tasks, insights: insights)
            }
        }
    }
    
    var activeProjects: [Project] {
        projects.filter { $0.status == .active }
    }
    
    var completedProjects: [Project] {
        projects.filter { $0.status == .completed }
    }
}

struct ActiveProjectsSummary: View {
    let projects: [Project]
    let posts: [CloutmateShared.Post]
    let tasks: [Task]
    
    var totalPostsCount: Int {
        projects.reduce(0) { total, project in
            total + posts.filter { project.postIds.contains($0.id) }.count
        }
    }
    
    var totalTasksCount: Int {
        projects.reduce(0) { total, project in
            total + tasks.filter { $0.projectId == project.id }.count
        }
    }
    
    var completionRate: Double {
        guard totalTasksCount > 0 else { return 0 }
        let completedTasks = tasks.filter { $0.status == .done }.count
        return Double(completedTasks) / Double(totalTasksCount)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            SummaryCard(
                icon: "folder.fill",
                title: "Active Projects",
                value: "\(projects.count)",
                color: .blue
            )
            
            SummaryCard(
                icon: "square.and.pencil",
                title: "Total Posts",
                value: "\(totalPostsCount)",
                color: .purple
            )
            
            SummaryCard(
                icon: "checkmark.circle",
                title: "Completion",
                value: "\(Int(completionRate * 100))%",
                color: .green
            )
        }
        .padding(.horizontal)
    }
}

struct SummaryCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color.gradient)
                .font(.title2)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 12)
    }
}

struct ProjectPerformanceCard: View {
    let project: Project
    let posts: [CloutmateShared.Post]
    let tasks: [Task]
    let onTap: () -> Void
    
    var completionRate: Double {
        let total = tasks.count
        guard total > 0 else { return 0 }
        let completed = tasks.filter { $0.status == .done }.count
        return Double(completed) / Double(total)
    }
    
    var publishedPosts: Int {
        posts.filter { $0.postStatus == .published }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.blue.gradient)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.title)
                        .font(.headline)
                    if let goal = project.goal {
                        Text(goal)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                Button("View Details", action: onTap)
                    .buttonStyle(.bordered)
            }
            
            // Stats
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(publishedPosts)/\(posts.count)")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Posts")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(Int(completionRate * 100))%")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(completionRate > 0.7 ? .green : .orange)
                    Text("Complete")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geometry.size.width * completionRate, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 12)
    }
}

struct CompletedProjectCard: View {
    let project: Project
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
            Text(project.title)
                .font(.body)
            Spacer()
            Text(project.createdAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 8)
    }
}

struct ProjectDetailInsightsSheet: View {
    let project: Project
    let posts: [CloutmateShared.Post]
    let tasks: [Task]
    let insights: [InsightSnapshot]
    @Environment(\.dismiss) private var dismiss
    
    var projectPosts: [CloutmateShared.Post] {
        posts.filter { project.postIds.contains($0.id) }
    }
    
    var projectTasks: [Task] {
        tasks.filter { $0.projectId == project.id }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(project.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding()
                        .glassPanel(tier: .overlay, cornerRadius: 12)
                    
                    // Performance metrics
                    Text("Performance")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if !projectPosts.isEmpty {
                        let publishedCount = projectPosts.filter { $0.postStatus == .published }.count
                        Text("Posts: \(publishedCount)/\(projectPosts.count) published")
                            .font(.body)
                            .padding()
                            .glassPanel(tier: .contentCard, cornerRadius: 12)
                            .padding(.horizontal)
                    }
                }
                .padding()
            }
            .background(Color.clear)
            .navigationTitle("Project Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 700, height: 600)
    }
}

#Preview {
    ProjectInsightsView()
        .modelContainer(for: [Project.self, Post.self, Task.self, InsightSnapshot.self])
}

