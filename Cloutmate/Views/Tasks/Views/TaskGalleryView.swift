//
//  TaskGalleryView.swift
//  Cloutmate
//
//  Gallery view for Tasks with visual showcase
//

import SwiftUI
import SwiftData
import CloutmateShared

struct TaskGalleryView: View {
    let tasks: [Task]
    let projects: [Project]
    let areas: [Area]
    let selectionMode: Bool
    let selectedTaskIDs: Set<UUID>
    let onSelectionToggle: (Task) -> Void
    let onTaskSelected: (Task) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        if tasks.isEmpty {
            emptyState
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(tasks) { task in
                    TaskGalleryCard(
                        task: task,
                        project: projects.first { $0.id == task.projectId },
                        area: areas.first { $0.id == task.areaId },
                        selectionMode: selectionMode,
                        isSelected: selectedTaskIDs.contains(task.id),
                        onSelectionToggle: { onSelectionToggle(task) },
                        onTap: {
                            onTaskSelected(task)
                        }
                    )
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No tasks")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Create your first task to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Task Gallery Card

private struct TaskGalleryCard: View {
    @Bindable var task: Task
    let project: Project?
    let area: Area?
    let selectionMode: Bool
    let isSelected: Bool
    let onSelectionToggle: () -> Void
    let onTap: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var isHovered = false
    @State private var metrics: TaskFocusMetrics?
    
    var backgroundGradient: LinearGradient {
        let defaultMetrics = TaskFocusMetrics(
            cognitiveFocus: 0.3,
            creativeFlow: 0.3,
            completionEnergy: 0.3
        )
        
        let taskMetrics = metrics ?? defaultMetrics
        
        return LinearGradient(
            colors: [
                .kosmicBlue.opacity(taskMetrics.cognitiveFocus * 0.6),
                .kosmicPurple.opacity(taskMetrics.creativeFlow * 0.6),
                .kosmicGreen.opacity(taskMetrics.completionEnergy * 0.6)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover Gradient Area
            ZStack {
                backgroundGradient
                    .frame(height: 100)
                
                if isHovered, let taskMetrics = metrics {
                    TaskFocusIntensityRings(metrics: taskMetrics, isVisible: true)
                }
            }
            
            // Content Area
            VStack(alignment: .leading, spacing: 8) {
                Text(task.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundColor(glassColorSystem.textPrimary())
                
                HStack {
                    InteractiveProgressPill(task: task)
                    
                    if let dueDate = task.dueDate {
                        InteractiveDueDateBadge(task: task, color: dueDateColor(dueDate))
                    }
                }
                
                if let project = project {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill")
                            .font(.caption2)
                            .foregroundColor(.kosmicBlue)
                        Text(project.title)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
        }
        .frame(minHeight: 180)
        .background(
            GlassPanel(tier: .contentCard, cornerRadius: 12) {
                EmptyView()
            }
        )
        .shadow(color: .black.opacity(isHovered ? 0.15 : 0.05), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(reduceMotion ? nil : .spring(duration: 0.3), value: isHovered)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: isSelected ? [.kosmicBlue, .kosmicPurple] : [.clear, .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isSelected ? 2 : 0
                )
        )
        .overlay(alignment: .topTrailing) {
            if selectionMode {
                SelectionIndicator(isSelected: isSelected)
                    .padding(12)
                    .onTapGesture {
                        onSelectionToggle()
                    }
            }
        }
        .onHover { hovering in
            guard !selectionMode else {
                isHovered = hovering
                return
            }
            isHovered = hovering
        }
        .onTapGesture {
            if selectionMode {
                onSelectionToggle()
            } else {
                onTap()
            }
        }
        .task {
            // Load focus metrics for task
            metrics = TaskFocusMetrics.defaultMetrics(for: task)
        }
    }
    
    private func dueDateColor(_ dueDate: Date) -> Color {
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
}

// MARK: - Task Focus Intensity Rings

private struct TaskFocusIntensityRings: View {
    let metrics: TaskFocusMetrics
    let isVisible: Bool
    
    private var dominantFocus: Color {
        let maxValue = max(metrics.cognitiveFocus, metrics.creativeFlow, metrics.completionEnergy)
        if maxValue == metrics.cognitiveFocus {
            return .kosmicBlue
        } else if maxValue == metrics.creativeFlow {
            return .kosmicPurple
        } else {
            return .kosmicGreen
        }
    }
    
    private var intensity: Double {
        max(metrics.cognitiveFocus, metrics.creativeFlow, metrics.completionEnergy)
    }
    
    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .stroke(
                        dominantFocus.opacity(intensity * (0.3 - Double(index) * 0.07)),
                        lineWidth: 2
                    )
                    .frame(width: 60 + CGFloat(index * 20), height: 60 + CGFloat(index * 20))
            }
        }
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.spring(duration: 0.3), value: isVisible)
    }
}

