//
//  TaskTimelineView.swift
//  Cloutmate
//
//  Timeline view for Tasks with due date visualization
//

import SwiftUI
import CloutmateShared

struct TaskTimelineView: View {
    let tasks: [Task]
    let projects: [Project]
    let areas: [Area]
    let onTaskSelected: (Task) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var scrollOffset: CGFloat = 0
    
    var dateRange: (start: Date, end: Date) {
        let allDates = tasks.compactMap { $0.dueDate } + tasks.map { $0.createdAt }
        guard let minDate = allDates.min(), let maxDate = allDates.max() else {
            let now = Date()
            return (now, Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now)
        }
        return (minDate, maxDate)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if tasks.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    GeometryReader { geometry in
                        ZStack(alignment: .topLeading) {
                            // Timeline Baseline
                            timelineBaseline(width: max(geometry.size.width, 1000))
                                .offset(y: 100)
                            
                            // Task Milestones
                            ForEach(Array(tasksWithDates.sorted(by: { ($0.dueDate ?? $0.createdAt) < ($1.dueDate ?? $1.createdAt) }).enumerated()), id: \.element.id) { index, task in
                                TimelineTaskMarker(
                                    task: task,
                                    project: projects.first { $0.id == task.projectId },
                                    dateRange: dateRange,
                                    timelineWidth: max(geometry.size.width, 1000),
                                    onTap: {
                                        onTaskSelected(task)
                                    }
                                )
                            }
                        }
                        .frame(width: max(geometry.size.width, 1000))
                        .padding(.horizontal, 40)
                    }
                    .frame(height: 300)
                }
            }
        }
    }
    
    private var tasksWithDates: [Task] {
        tasks.filter { $0.dueDate != nil || $0.createdAt != nil }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "timeline.selection")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No tasks")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Create tasks with due dates to see them on the timeline")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }
    
    private func timelineBaseline(width: CGFloat) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.kosmicBlue, .kosmicPurple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: 2)
    }
}

// MARK: - Timeline Task Marker

private struct TimelineTaskMarker: View {
    let task: Task
    let project: Project?
    let dateRange: (start: Date, end: Date)
    let timelineWidth: CGFloat
    let onTap: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @State private var isHovered = false
    
    var position: CGFloat {
        let taskDate = task.dueDate ?? task.createdAt
        let totalDuration = dateRange.end.timeIntervalSince(dateRange.start)
        guard totalDuration > 0 else { return 0 }
        let offsetFromStart = taskDate.timeIntervalSince(dateRange.start)
        let ratio = CGFloat(offsetFromStart / totalDuration)
        return min(max(ratio * timelineWidth, 0), timelineWidth - 16)
    }
    
    var markerColor: Color {
        if task.status == .done {
            return .kosmicGreen
        } else if task.status == .inProgress {
            return .orange
        } else if let dueDate = task.dueDate, dueDate < Date() {
            return .red
        }
        return .kosmicBlue
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Task Marker Dot
            ZStack {
                Circle()
                    .fill(markerColor.opacity(0.8))
                    .frame(width: 16, height: 16)
                
                Circle()
                    .stroke(markerColor, lineWidth: 2)
                    .frame(width: 24, height: 24)
            }
            .shadow(color: markerColor.opacity(0.5), radius: 4)
            .scaleEffect(isHovered ? 1.2 : 1.0)
            .animation(.spring(duration: 0.3), value: isHovered)
            
            // Task Info Card
            if isHovered {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    
                    if let project = project {
                        Text(project.title)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
                .frame(width: 120)
                .background(
                    GlassPanel(tier: .floatingAction, cornerRadius: 8) {
                        EmptyView()
                    }
                )
                .shadow(color: .black.opacity(0.2), radius: 8)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .position(x: position, y: 100)
        .onTapGesture {
            onTap()
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

