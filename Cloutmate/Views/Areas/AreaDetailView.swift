//
//  AreaDetailView.swift
//  Cloutmate
//
//  Area Detail View showing projects, tasks, and notes
//

import SwiftUI
import SwiftData

struct AreaDetailView: View {
    let area: Area
    @Query private var allTasks: [Task]
    @Query private var allNotes: [Note]
    @Query private var allProjects: [Project]
    
    var areaTasks: [Task] {
        allTasks.filter { $0.areaId == area.id }
    }
    
    var areaNotes: [Note] {
        allNotes.filter { $0.areaId == area.id }
    }
    
    var areaProjects: [Project] {
        allProjects.filter { $0.areaId == area.id }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Area header
                AreaHeaderSection(area: area)
                
                // Projects in this area
                AreaProjectsSection(projects: areaProjects)
                
                // Tasks in this area
                AreaTasksSection(tasks: areaTasks)
                
                // Notes in this area
                AreaNotesSection(notes: areaNotes)
            }
            .padding()
        }
        .background(Color.clear)
        .navigationTitle(area.title)
    }
}

struct AreaHeaderSection: View {
    let area: Area
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "rectangle.stack.fill")
                    .foregroundStyle(.blue.gradient)
                    .font(.largeTitle)
                Text(area.title)
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
            }
            
            if let notes = area.notes {
                Text(notes)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .glassPanel(tier: .overlay, cornerRadius: 12)
    }
}

struct AreaProjectsSection: View {
    let projects: [Project]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.blue)
                Text("Projects")
                    .font(.headline)
                Text("(\(projects.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if projects.isEmpty {
                Text("No projects in this area")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(projects.prefix(10)) { project in
                    ProjectRow(project: project)
                }
            }
        }
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 12)
    }
}

struct ProjectRow: View {
    let project: Project
    
    var body: some View {
        HStack {
            Image(systemName: "folder")
                .foregroundColor(.blue)
            Text(project.title)
                .font(.body)
            Spacer()
            StatusBadge(status: project.status)
        }
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 8)
    }
}

struct AreaTasksSection: View {
    let tasks: [Task]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.blue)
                Text("Tasks")
                    .font(.headline)
                Text("(\(tasks.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if tasks.isEmpty {
                Text("No tasks in this area")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(tasks.prefix(10)) { task in
                    AreaTaskRow(task: task)
                }
            }
        }
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 12)
    }
}

struct AreaNotesSection: View {
    let notes: [Note]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(.purple)
                Text("Notes")
                    .font(.headline)
                Text("(\(notes.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if notes.isEmpty {
                Text("No notes in this area")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(notes.prefix(10)) { note in
                    AreaNoteRow(note: note)
                }
            }
        }
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 12)
    }
}

struct AreaNoteRow: View {
    let note: Note
    
    var body: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(.purple)
            Text(note.title)
                .font(.body)
            Spacer()
            Text(note.updatedAt, style: .relative)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 8)
    }
}

struct AreaTaskRow: View {
    let task: Task
    
    var body: some View {
        HStack {
            Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                .foregroundColor(task.status == .done ? .green : .blue)
            Text(task.title)
                .font(.body)
                .strikethrough(task.status == .done)
            Spacer()
        }
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 8)
    }
}

#Preview {
    AreaDetailView(area: Area(title: "Example Area", notes: "This is a sample area"))
        .modelContainer(for: [Area.self, Project.self, Task.self, Note.self])
}

