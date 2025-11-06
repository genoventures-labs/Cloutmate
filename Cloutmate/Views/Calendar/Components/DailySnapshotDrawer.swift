//
//  DailySnapshotDrawer.swift
//  Cloutmate
//
//  Calendar V2 - Daily Snapshot drawer showing tasks, projects, and artifacts for selected date
//

import SwiftUI
import SwiftData
import CloutmateShared

struct DailySnapshotDrawer: View {
    let date: Date
    @Binding var isPresented: Bool
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CloutmateShared.Task.dueDate) private var allTasks: [CloutmateShared.Task]
    @Query(sort: \CloutmateShared.Artifact.createdAt, order: .reverse) private var allArtifacts: [CloutmateShared.Artifact]
    @Query(sort: \CloutmateShared.Project.dueDate) private var allProjects: [CloutmateShared.Project]
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    private let calendar = Calendar.current
    
    private var tasksDue: [Task] {
        allTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: date)
        }
    }
    
    private var artifactsCaptured: [Artifact] {
        allArtifacts.filter { artifact in
            if let publishedAt = artifact.publishedAt, calendar.isDate(publishedAt, inSameDayAs: date) {
                return true
            }
            if calendar.isDate(artifact.createdAt, inSameDayAs: date) {
                return true
            }
            return false
        }
    }
    
    private var projectsWithDeadlines: [Project] {
        // Get week containing selected date
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return []
        }
        
        return allProjects.filter { project in
            guard let dueDate = project.dueDate else { return false }
            return weekInterval.contains(dueDate) && project.status == .active
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }
    
    var body: some View {
        Group {
            if isPresented {
                GeometryReader { geometry in
                    ZStack(alignment: .trailing) {
                        // Backdrop
                        Color.black.opacity(0.2)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(GlassMotion.Easing.modalOpen) {
                                    isPresented = false
                                }
                            }
                            .transition(.opacity)
                        
                        // Drawer
                        VStack(spacing: 0) {
                            // Header
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Daily Snapshot")
                                        .font(.system(.title2, design: .rounded))
                                        .fontWeight(.bold)
                                    
                                    Text(formattedDate)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    withAnimation(GlassMotion.Easing.modalOpen) {
                                        isPresented = false
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            
                            ScrollView {
                                VStack(alignment: .leading, spacing: 20) {
                                    // Tasks Due
                                    if !tasksDue.isEmpty {
                                        sectionHeader(title: "Tasks Due", icon: "checkmark.circle.fill", color: .kosmicGreen)
                                        
                                        ForEach(tasksDue) { task in
                                            TaskSnapshotRow(task: task)
                                        }
                                    }
                                    
                                    // Projects with Deadlines
                                    if !projectsWithDeadlines.isEmpty {
                                        sectionHeader(title: "Projects with Deadlines", icon: "folder.fill", color: .kosmicBlue)
                                        
                                        ForEach(projectsWithDeadlines) { project in
                                            ProjectSnapshotRow(project: project)
                                        }
                                    }
                                    
                                    // Artifacts Captured
                                    if !artifactsCaptured.isEmpty {
                                        sectionHeader(title: "Artifacts Captured", icon: "doc.text.fill", color: .kosmicPurple)
                                        
                                        ForEach(artifactsCaptured) { artifact in
                                            ArtifactSnapshotRow(artifact: artifact)
                                        }
                                    }
                                    
                                    // Empty State
                                    if tasksDue.isEmpty && projectsWithDeadlines.isEmpty && artifactsCaptured.isEmpty {
                                        VStack(spacing: 12) {
                                            Image(systemName: "calendar.badge.clock")
                                                .font(.system(size: 48))
                                                .foregroundColor(.secondary.opacity(0.5))
                                            
                                            Text("No items scheduled")
                                                .font(.headline)
                                                .foregroundColor(.secondary)
                                            
                                            Text("This day is clear. Take a moment to reflect or plan ahead.")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .multilineTextAlignment(.center)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 40)
                                    }
                                }
                                .padding()
                            }
                        }
                        .frame(width: 350)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .background(.ultraThinMaterial)
                        .transition(.move(edge: .trailing))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    }
                }
            }
        }
    }
    
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.headline)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding(.top, 8)
    }
}

struct TaskSnapshotRow: View {
    let task: Task
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                .foregroundColor(task.status == .done ? .kosmicGreen : .orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.status == .done)
                
                if let dueDate = task.dueDate {
                    Text(dueDate, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .glassPanel(tier: .contentCard, cornerRadius: 12)
    }
}

struct ProjectSnapshotRow: View {
    let project: Project
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .foregroundColor(.kosmicBlue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(.body)
                
                if let dueDate = project.dueDate {
                    Text("Due: \(dueDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .glassPanel(tier: .contentCard, cornerRadius: 12)
    }
}

struct ArtifactSnapshotRow: View {
    let artifact: Artifact
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: formatIcon)
                .foregroundColor(formatColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(artifact.title.isEmpty ? "Untitled Artifact" : artifact.title)
                    .font(.body)
                    .lineLimit(2)
                
                Text(artifact.format.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .glassPanel(tier: .contentCard, cornerRadius: 12)
    }
    
    private var formatIcon: String {
        switch artifact.format {
        case .brief: return "doc.text"
        case .summary: return "doc.text.below.ecg"
        case .reflection: return "brain.head.profile"
        case .report: return "doc.text.magnifyingglass"
        case .releaseNote: return "megaphone"
        case .lessonLearned: return "lightbulb"
        }
    }
    
    private var formatColor: Color {
        switch artifact.format {
        case .brief: return .kosmicCyan
        case .summary: return .kosmicBlue
        case .reflection: return .kosmicPurple
        case .report: return .kosmicPurple
        case .releaseNote: return .kosmicGreen
        case .lessonLearned: return .orange
        }
    }
}

#Preview {
    @Previewable @State var isPresented = true
    
    DailySnapshotDrawer(
        date: Date(),
        isPresented: $isPresented
    )
    .environmentObject(GlassColorSystem())
    .modelContainer(for: [Task.self, Artifact.self, Project.self])
}

