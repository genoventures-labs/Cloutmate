//
//  AreaReviewDrawer.swift
//  FocusOS
//
//  V2 drawer for completing an Area review.
//

import SwiftUI
import SwiftData
import FocusOSShared

struct AreaReviewDrawer: View {
    @Bindable var area: Area
    let summary: AreaReviewSummary
    let tasks: [FocusOSShared.Task]
    let projects: [FocusOSShared.Project]
    let notes: [Note]
    let onClose: () -> Void
    let onMarkReviewed: (_ reflection: String?) -> Void
    let onSnooze: (_ days: Int) -> Void
    let onOpenProject: (FocusOSShared.Project) -> Void
    let onOpenTask: (FocusOSShared.Task) -> Void
    let onOpenNote: (Note) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var reflectionNotes: String = ""
    @State private var showReflectionField = false
    
    private var accentColor: LinearGradient {
        LinearGradient(
            colors: [.kosmicBlue.opacity(0.85), .kosmicPurple.opacity(0.7)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                accentColor
                    .frame(width: 4)
                    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 0)
                
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                        .background(
                            GlassPanel(tier: .overlay, cornerRadius: 0) {
                                EmptyView()
                            }
                        )
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            checklistSection
                            if !summary.overdueTasks.isEmpty {
                                overdueTasksSection
                            }
                            if !summary.pendingTasks.isEmpty {
                                activeTasksSection
                            }
                            if !summary.stalledProjects.isEmpty {
                                stalledProjectsSection
                            }
                            if !summary.recentNotes.isEmpty {
                                recentNotesSection
                            }
                            reflectionSection
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 24)
                    }
                    .background(glassColorSystem.backgroundColor())
                    
                    footer
                        .padding(20)
                        .background(
                            GlassPanel(tier: .overlay, cornerRadius: 0) {
                                EmptyView()
                            }
                        )
                }
            }
            .background(glassColorSystem.backgroundColor())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(minWidth: 720, minHeight: 640)
        .onAppear {
            showReflectionField = summary.pendingTasks.isEmpty == false || summary.overdueTasks.isEmpty == false
        }
    }
    
    // MARK: - Sections
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: area.categoryIcon ?? "rectangle.stack.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.kosmicBlue)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(area.title)
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(glassColorSystem.textPrimary())
                    
                    Text(summary.status.reason)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if let lastReview = summary.status.lastReviewDate {
                        Text("Last reviewed \(lastReview, style: .relative)")
                            .font(.caption)
                            .foregroundColor(glassColorSystem.textSecondary())
                    } else {
                        Text("Never reviewed")
                            .font(.caption)
                            .foregroundColor(glassColorSystem.textSecondary())
                    }
                    
                    Text("Next review \(summary.status.nextReviewDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundColor(glassColorSystem.textTertiary())
                }
            }
        }
    }
    
    private var checklistSection: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(title: "Review Checklist", icon: "checklist")
                
                ForEach(summary.checklistItems) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: item.icon)
                            .foregroundColor(item.state == .complete ? .kosmicGreen : .orange)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.callout.weight(.semibold))
                                .foregroundColor(glassColorSystem.textPrimary())
                            Text(item.detail)
                                .font(.caption)
                                .foregroundColor(glassColorSystem.textSecondary())
                        }
                        
                        Spacer()
                    }
                }
            }
            .padding(18)
        }
    }
    
    private var overdueTasksSection: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(title: "Overdue Tasks", icon: "exclamationmark.triangle.fill", iconColor: .red)
                
                ForEach(summary.overdueTasks) { task in
                    Button {
                        onOpenTask(task)
                    } label: {
                        LinkedReviewRow(
                            title: task.title,
                            subtitle: subtitle(for: task),
                            icon: "calendar.badge.clock",
                            accent: .red
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
        }
    }
    
    private var activeTasksSection: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(title: "Active Tasks", icon: "checkmark.circle")
                
                ForEach(summary.pendingTasks) { task in
                    Button {
                        onOpenTask(task)
                    } label: {
                        LinkedReviewRow(
                            title: task.title,
                            subtitle: subtitle(for: task),
                            icon: task.status == .inProgress ? "arrow.triangle.2.circlepath" : "circle",
                            accent: task.status == .inProgress ? .kosmicBlue : .gray
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
        }
    }
    
    private var stalledProjectsSection: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(title: "Projects to Review", icon: "folder.badge.questionmark", iconColor: .orange)
                
                ForEach(summary.stalledProjects) { project in
                    Button {
                        onOpenProject(project)
                    } label: {
                        LinkedReviewRow(
                            title: project.title,
                            subtitle: projectStatus(project),
                            icon: "folder",
                            accent: .kosmicBlue
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
        }
    }
    
    private var recentNotesSection: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(title: "Recent Notes", icon: "doc.text.fill", iconColor: .kosmicPurple)
                
                ForEach(summary.recentNotes) { note in
                    Button {
                        onOpenNote(note)
                    } label: {
                        LinkedReviewRow(
                            title: note.title.isEmpty ? "Untitled Note" : note.title,
                            subtitle: note.updatedAt.formatted(date: .abbreviated, time: .shortened),
                            icon: "note.text",
                            accent: .kosmicPurple
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
        }
    }
    
    private var reflectionSection: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(title: "Reflection", icon: "sparkles")
                
                Toggle(isOn: $showReflectionField.animation()) {
                    Text("Capture a note for this review")
                        .font(.caption)
                        .foregroundColor(glassColorSystem.textSecondary())
                }
                .toggleStyle(.switch)
                
                if showReflectionField {
                    TextEditor(text: $reflectionNotes)
                        .frame(minHeight: 120)
                        .padding(10)
                        .background(glassColorSystem.glassTint(for: .surface).opacity(0.3))
                        .cornerRadius(12)
                }
            }
            .padding(18)
        }
    }
    
    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                onSnooze(7)
            } label: {
                Label("Snooze 7 days", systemImage: "moon.zzz.fill")
            }
            .buttonStyle(.bordered)
            
            Button {
                onSnooze(14)
            } label: {
                Label("Snooze 14 days", systemImage: "calendar.badge.clock")
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button {
                onMarkReviewed(reflectionNotes.trimmingCharacters(in: .whitespacesAndNewlines))
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Mark Reviewed")
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Helpers
    
    private func sectionHeader(title: String, icon: String, iconColor: Color = .kosmicBlue) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
            Text(title)
                .font(.headline)
                .foregroundColor(glassColorSystem.textPrimary())
        }
    }
    
    private func subtitle(for task: FocusOSShared.Task) -> String {
        if let due = task.dueDate {
            if task.status == .done {
                return "Completed \(due.formatted(date: .abbreviated, time: .omitted))"
            }
            if due < Date() {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                return "Overdue since \(formatter.string(from: due))"
            }
            return "Due \(due.formatted(date: .abbreviated, time: .omitted))"
        }
        return task.status.displayName
    }
    
    private func projectStatus(_ project: FocusOSShared.Project) -> String {
        if let due = project.dueDate {
            if due < Date() && project.status != .completed {
                return "Past due (\(due.formatted(date: .abbreviated, time: .omitted)))"
            }
            return "Due \(due.formatted(date: .abbreviated, time: .omitted))"
        }
        return project.status.displayName
    }
}

private struct LinkedReviewRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(accent)
                .frame(width: 18, height: 18)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundColor(glassColorSystem.textPrimary())
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(glassColorSystem.textSecondary())
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "arrow.up.right")
                .font(.caption)
                .foregroundColor(glassColorSystem.textSecondary())
        }
        .padding(12)
        .background(glassColorSystem.glassTint(for: .surface).opacity(0.25))
        .cornerRadius(12)
    }
}

#Preview {
    let area = Area(title: "Health & Wellness")
    area.lastReviewDate = Calendar.current.date(byAdding: .day, value: -12, to: Date())
    
    let task1 = FocusOSShared.Task(title: "Schedule annual check-up", status: .todo, dueDate: Calendar.current.date(byAdding: .day, value: -3, to: Date()))
    task1.areaId = area.id
    let task2 = FocusOSShared.Task(title: "Plan meal prep", status: .inProgress, dueDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()))
    task2.areaId = area.id
    
    let project = FocusOSShared.Project(title: "Q4 Training Plan", status: .paused)
    project.areaId = area.id
    
    let note = Note(title: "Reflection", markdown: "Energy levels feel low this week.")
    note.areaId = area.id
    
    let status = AreaReviewService.shared.status(for: area)
    let summary = AreaReviewSummary(
        status: status,
        pendingTasks: [task1, task2],
        overdueTasks: [task1],
        stalledProjects: [project],
        recentNotes: [note],
        checklistItems: [
            AreaReviewChecklistItem(title: "Review cadence overdue", detail: "Review overdue by 5 days.", icon: "exclamationmark.triangle.fill", state: .attention),
            AreaReviewChecklistItem(title: "Tasks pending", detail: "Review open tasks and update progress.", icon: "checklist", state: .attention)
        ]
    )
    
    return AreaReviewDrawer(
        area: area,
        summary: summary,
        tasks: [task1, task2],
        projects: [project],
        notes: [note],
        onClose: {},
        onMarkReviewed: { _ in },
        onSnooze: { _ in },
        onOpenProject: { _ in },
        onOpenTask: { _ in },
        onOpenNote: { _ in }
    )
    .environmentObject(GlassColorSystem())
    .modelContainer(for: [Area.self, FocusOSShared.Task.self, FocusOSShared.Project.self, Note.self])
}


