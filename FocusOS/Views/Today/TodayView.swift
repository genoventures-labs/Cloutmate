//
//  TodayView.swift
//  FocusOS
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import FocusOSShared

struct TodayView: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @EnvironmentObject private var accessibilityManager: AccessibilityGlassManager
    @Query private var tasks: [FocusOSShared.Task]
    @Query private var posts: [FocusOSShared.Post]
    @Query private var inboxItems: [FocusOSShared.InboxItem]
    @Query private var projects: [FocusOSShared.Project]
    
    var unconvertedInbox: Int {
        inboxItems.filter { $0.convertedAt == nil }.count
    }
    
    var todayTasks: [Task] {
        tasks.filter { task in
            guard let due = task.dueDate else { return false }
            return Calendar.current.isDateInToday(due) && task.status != .done
        }
    }
    
    var todayPosts: [FocusOSShared.Post] {
        posts.filter { post in
            guard let scheduled = post.scheduledDate else { return false }
            return Calendar.current.isDateInToday(scheduled)
        }
    }
    
    var activeProjects: [Project] {
        projects.filter { $0.status == .active }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with Glass Styling
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(glassColorSystem.auroralGradient())
                        
                        Text(Date().formatted(date: .complete, time: .omitted))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .glassPanel(tier: .overlay, cornerRadius: 12)
                .padding()
                
                // Check if anything exists to show
                if unconvertedInbox == 0 && todayTasks.isEmpty && todayPosts.isEmpty && activeProjects.isEmpty {
                    // Empty state
                    EmptyTodayView()
                        .padding(.horizontal)
                } else {
                // Inbox Banner
                if unconvertedInbox > 0 {
                    InboxBanner(count: unconvertedInbox)
                        .padding(.horizontal)
                }
                
                // Today's Tasks
                if !todayTasks.isEmpty {
                    TodayTasksSection(tasks: todayTasks)
                }
                
                // Today's Posts
                if !todayPosts.isEmpty {
                    TodayPostsSection(posts: todayPosts)
                }
                
                // Active Projects
                if !activeProjects.isEmpty {
                    ActiveProjectsSection(projects: activeProjects)
                    }
                }
            }
            .padding()
        }
        .background(Color.clear)
        .navigationTitle("Today")
    }
}

struct InboxBanner: View {
    let count: Int
    
    var body: some View {
        HStack {
            Image(systemName: "tray.fill")
                .foregroundStyle(.orange.gradient)
                .font(.title2)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(count) items in inbox waiting")
                    .font(.headline)
                Text("Convert them to organize your workflow")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 12)
    }
}

struct TodayTasksSection: View {
    let tasks: [Task]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(Color.kosmicBlue)
                Text("Tasks Due Today")
                    .font(.headline)
            }
            .padding(.horizontal)
            
            ForEach(tasks) { task in
                TaskRow(task: task)
            }
        }
    }
}

struct TaskRow: View {
    @Bindable var task: Task
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        HStack {
            Button(action: {
                task.status = task.status == .done ? .todo : .done
                task.updatedAt = Date()
                try? modelContext.save()
            }) {
                Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.status == .done ? .kosmicGreen : .kosmicBlue)
            }
            .buttonStyle(.plain)
            
            Text(task.title)
                .font(.body)
                .strikethrough(task.status == .done)
            
            Spacer()
            
            if let due = task.dueDate {
                Text(due, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 8)
    }
}

struct TodayPostsSection: View {
    let posts: [FocusOSShared.Post]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.and.pencil")
                    .foregroundStyle(Color.kosmicPurple)
                Text("Posts Scheduled Today")
                    .font(.headline)
            }
            .padding(.horizontal)
            
            ForEach(posts) { post in
                PostPreviewRow(post: post)
            }
        }
    }
}

struct PostPreviewRow: View {
    let post: FocusOSShared.Post
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(post.caption)
                    .lineLimit(2)
                    .font(.body)
                
                if let date = post.scheduledDate {
                    Text(date, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            TodayPostStatusBadge(status: post.postStatus)
        }
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 8)
    }
}

struct TodayPostStatusBadge: View {
    let status: FocusOSShared.PostStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(6)
    }
    
    private var statusColor: Color {
        switch status {
        case .draft: return .gray
        case .scheduled: return .kosmicBlue
        case .publishing: return .orange
        case .published: return .kosmicGreen
        case .failed: return .red
        @unknown default: return .gray
        }
    }
}

struct ActiveProjectsSection: View {
    let projects: [Project]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(Color.kosmicBlue)
                Text("Active Projects")
                    .font(.headline)
            }
            .padding(.horizontal)
            
            ForEach(projects.prefix(5)) { project in
                ProjectPreviewRow(project: project)
            }
        }
    }
}

struct ProjectPreviewRow: View {
    let project: Project
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.kosmicBlue.opacity(0.2))
                .frame(width: 8, height: 8)
            
            Text(project.title)
                .font(.body)
            
            Spacer()
        }
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 8)
    }
}

struct EmptyTodayView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange.gradient)
            
            Text("All caught up!")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Nothing scheduled for today")
                    .font(.body)
                    .foregroundStyle(.secondary)
                
                Text("Get started:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("Add tasks with due dates", systemImage: "checkmark.circle")
                        .font(.caption)
                    Label("Schedule posts for today", systemImage: "square.and.pencil")
                        .font(.caption)
                    Label("Create active projects", systemImage: "folder.fill")
                        .font(.caption)
                    Label("Add items to inbox", systemImage: "tray.fill")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            .padding()
            .glassPanel(tier: .contentCard, cornerRadius: 12)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

#Preview {
    TodayView()
        .modelContainer(for: [FocusOSShared.Task.self, FocusOSShared.Post.self, FocusOSShared.InboxItem.self, FocusOSShared.Project.self])
}

