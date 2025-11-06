//
//  ProjectListView.swift
//  Cloutmate
//
//  List view for Projects with compact GlassCards and Focus Gravity bars
//

import SwiftUI
import SwiftData
import CloutmateShared

struct ProjectListView: View {
    let projects: [Project]
    let tasks: [Task]
    let areas: [Area]
    let onProjectSelected: (Project) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        if projects.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: 12) {
                ForEach(projects) { project in
                    ProjectListCard(
                        project: project,
                        tasks: tasks.filter { $0.projectId == project.id },
                        areas: areas,
                        onTap: {
                            onProjectSelected(project)
                        }
                    )
                    .accessibilityLabel("Project: \(project.title)")
                    .accessibilityHint("Double tap to open. Press Enter to view details.")
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.fill")
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

// MARK: - Project List Card

struct ProjectListCard: View {
    let project: Project
    let tasks: [Task]
    let areas: [Area]
    let onTap: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var isHovered = false
    @State private var isExpanded = false
    @State private var focusMetrics: ProjectFocusMetrics?
    
    var completedTasksCount: Int {
        tasks.filter { $0.status == .done }.count
    }
    
    var totalTasksCount: Int {
        tasks.count
    }
    
    var completionPercentage: Double {
        guard totalTasksCount > 0 else { return 0.0 }
        return Double(completedTasksCount) / Double(totalTasksCount)
    }
    
    var isActiveToday: Bool {
        guard let lastActive = focusMetrics?.lastActiveAt else { return false }
        return Calendar.current.isDateInToday(lastActive)
    }
    
    var area: Area? {
        guard let areaId = project.areaId else { return nil }
        return areas.first { $0.id == areaId }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            focusGravityBarView
            cardContentView
        }
        .background(cardBackgroundView)
        .shadow(color: .black.opacity(isHovered ? 0.1 : 0.05), radius: isHovered ? 6 : 2, y: isHovered ? 3 : 1)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.3), value: isHovered)
        .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.3), value: isExpanded)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.3)) {
                isExpanded.toggle()
            }
        }
        .onTapGesture(count: 2) {
            onTap()
        }
        .contextMenu {
            contextMenuContent
        }
        .task {
            focusMetrics = ProjectFocusGravityService.shared.focusMetrics(for: project, modelContext: modelContext)
        }
    }
    
    // MARK: - View Components
    
    private var focusGravityBarView: some View {
        Group {
            if let metrics = focusMetrics {
                FocusGravityBar(metrics: metrics, isActive: isActiveToday)
                    .frame(height: cardHeight)
                    .accessibilityLabel(focusGravityAccessibilityLabel(metrics: metrics))
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 4, height: cardHeight)
            }
        }
    }
    
    private var cardContentView: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeaderView
            if totalTasksCount > 0 {
                progressBarView
            }
            if isExpanded {
                expandedContentView
            }
        }
        .padding(16)
    }
    
    private var cardHeaderView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(.headline)
                    .foregroundColor(glassColorSystem.textPrimary())
                
                HStack(spacing: 8) {
                    ProjectStatusBadge(status: project.status)
                    
                    if let dueDate = project.dueDate {
                        ProjectDueDateBadge(dueDate: dueDate)
                    }
                    
                    if let area = area {
                        Text(area.title)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            if isHovered {
                quickActionsView
            }
        }
    }
    
    private var quickActionsView: some View {
        HStack(spacing: 8) {
            ProjectQuickActionButton(icon: "pencil", color: .kosmicBlue) {
                // Edit action
            }
            ProjectQuickActionButton(icon: "archivebox.fill", color: .gray) {
                // Archive action
            }
        }
        .transition(.opacity.combined(with: .scale))
    }
    
    private var progressBarView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(completedTasksCount)/\(totalTasksCount) tasks")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(completionPercentage * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.kosmicBlue)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressGradient)
                        .frame(width: geometry.size.width * CGFloat(completionPercentage), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
    
    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [.kosmicBlue, .kosmicPurple],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var expandedContentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let goal = project.goal {
                Text(goal)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            if !tasks.isEmpty {
                tasksListView
            }
        }
        .padding(.top, 8)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    private var tasksListView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Linked Tasks")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            ForEach(tasks.prefix(5)) { task in
                HStack {
                    Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(task.status == .done ? .kosmicGreen : .secondary)
                        .font(.caption)
                    Text(task.title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }
    
    private var cardBackgroundView: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            EmptyView()
        }
        .overlay(cardOverlayView)
    }
    
    private var cardOverlayView: some View {
        Group {
            if isActiveToday && !reduceMotion {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(activeBorderGradient, lineWidth: 2)
                    .shimmer()
            }
        }
    }
    
    private var activeBorderGradient: LinearGradient {
        LinearGradient(
            colors: [
                .kosmicBlue.opacity(0.3),
                .kosmicPurple.opacity(0.3),
                .kosmicGreen.opacity(0.3)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var contextMenuContent: some View {
        Group {
            Button("Open") {
                onTap()
            }
            Button("Edit") {
                // Edit action
            }
            Button("Duplicate") {
                // Duplicate action
            }
            Divider()
            Button("Archive") {
                // Archive action
            }
            Button("Delete", role: .destructive) {
                // Delete action
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func focusGravityAccessibilityLabel(metrics: ProjectFocusMetrics) -> String {
        let average = (metrics.cognitiveFocus + metrics.creativeFlow + metrics.completionEnergy) / 3.0
        let percentage = Int(average * 100)
        return "Focus gravity: \(percentage) percent"
    }
    
    private var cardHeight: CGFloat {
        isExpanded ? 200 : 80
    }
}

// MARK: - Supporting Views

struct ProjectDueDateBadge: View {
    let dueDate: Date
    
    var color: Color {
        let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
        if daysUntilDue < 0 {
            return .red
        } else if daysUntilDue == 0 {
            return .kosmicBlue
        } else if daysUntilDue <= 3 {
            return .kosmicPurple
        }
        return .gray
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.caption2)
            Text(dueDate, format: .dateTime.month().day())
                .font(.caption)
        }
        .foregroundColor(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.1))
        .cornerRadius(4)
    }
}

struct ProjectQuickActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 24, height: 24)
                .background(color.opacity(0.1))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

