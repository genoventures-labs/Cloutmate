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
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var hoveredTaskID: UUID?
    
    private var dateRange: (start: Date, end: Date) {
        let allDates = tasks.compactMap { $0.dueDate } + tasks.map { $0.createdAt }
        guard let minDate = allDates.min(), let maxDate = allDates.max() else {
            let now = Date()
            return (now, Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now)
        }
        return (minDate, maxDate)
    }
    
    private var positionedTasks: [PositionedTask] {
        let sorted = tasksWithDates.sorted { ($0.dueDate ?? $0.createdAt) < ($1.dueDate ?? $1.createdAt) }
        let calendar = Calendar.current
        var counts: [Date: Int] = [:]
        sorted.forEach { task in
            let bucket = calendar.startOfDay(for: task.dueDate ?? task.createdAt)
            counts[bucket, default: 0] += 1
        }
        
        var laneAssignments: [Date: Int] = [:]
        return sorted.map { task in
            let bucket = calendar.startOfDay(for: task.dueDate ?? task.createdAt)
            let laneIndex = laneAssignments[bucket, default: 0]
            laneAssignments[bucket] = laneIndex + 1
            let laneCount = counts[bucket] ?? 1
            return PositionedTask(
                task: task,
                project: projects.first { $0.id == task.projectId },
                laneIndex: laneIndex,
                laneCount: laneCount
            )
        }
    }
    
    private var tasksWithDates: [Task] {
        tasks.filter { $0.dueDate != nil || $0.createdAt != nil }
    }
    
    private var axisTickCount: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month], from: dateRange.start, to: dateRange.end)
        let months = max(components.month ?? 1, 1)
        return min(max(months, 3), 8)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if positionedTasks.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    GeometryReader { geometry in
                        let trackWidth = max(geometry.size.width, TimelineLayout.minTrackWidth)
                        timelineContent(trackWidth: trackWidth)
                            .frame(width: trackWidth, height: TimelineLayout.trackHeight)
                    }
                    .frame(height: TimelineLayout.trackHeight)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
    
    @ViewBuilder
    private func timelineContent(trackWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            TimelineTrackBackground(
                width: trackWidth,
                height: TimelineLayout.trackHeight,
                accentGradient: AuroraPalette.linearGradient(for: colorScheme)
            )
            
            let densityPoints = densityRibbonPoints(for: trackWidth)
            if densityPoints.count >= 2 {
                TimelineDensityRibbon(
                    points: densityPoints,
                    baselineY: TimelineLayout.baselineY,
                    fillGradient: Gradient(colors: [
                        Color.kosmicBlue.opacity(0.16),
                        Color.kosmicPurple.opacity(0.12),
                        Color.kosmicPurple.opacity(0.05)
                    ]),
                    strokeGradient: Gradient(colors: [
                        Color.kosmicBlue.opacity(0.85),
                        Color.kosmicPurple.opacity(0.85)
                    ])
                )
                .blendMode(.screen)
                .allowsHitTesting(false)
            }
            
            TimelineAxis(
                width: trackWidth,
                tickCount: axisTickCount,
                tickHeight: TimelineLayout.tickHeight
            )
            
            ForEach(positionedTasks) { positioned in
                TimelineTaskMarker(
                    task: positioned.task,
                    project: positioned.project,
                    dateRange: dateRange,
                    timelineWidth: trackWidth,
                    laneIndex: positioned.laneIndex,
                    laneCount: positioned.laneCount,
                    isActive: hoveredTaskID == positioned.task.id,
                    reduceMotion: reduceMotion,
                    onTap: { onTaskSelected(positioned.task) },
                    onHoverChanged: { hovering in
                        hoveredTaskID = hovering ? positioned.task.id : nil
                    }
                )
                .zIndex(hoveredTaskID == positioned.task.id ? 2 : 1)
            }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .topLeading) {
            TimelineDateRangeLabel(
                startDate: dateRange.start,
                endDate: dateRange.end,
                alignment: .leading
            )
            .padding(.leading, 28)
            .padding(.top, 12)
        }
    }
    
    private func densityRibbonPoints(for width: CGFloat) -> [TimelineDensityRibbon.Point] {
        let calendar = Calendar.current
        let buckets = tasksWithDates.reduce(into: [Date: Int]()) { partial, task in
            let bucketDate = calendar.startOfDay(for: task.dueDate ?? task.createdAt)
            partial[bucketDate, default: 0] += 1
        }
        guard !buckets.isEmpty else { return [] }
        
        let sortedKeys = buckets.keys.sorted()
        let maxCount = max(buckets.values.max() ?? 1, 1)
        let usableWidth = width - (TimelineLayout.horizontalPadding * 2)
        
        return sortedKeys.map { date in
            let offset = date.timeIntervalSince(dateRange.start)
            let total = dateRange.end.timeIntervalSince(dateRange.start)
            let ratio = total == 0 ? 0.5 : min(max(CGFloat(offset / total), 0), 1)
            let x = TimelineLayout.horizontalPadding + ratio * usableWidth
            let normalized = CGFloat(buckets[date] ?? 0) / CGFloat(maxCount)
            let amplitude: CGFloat = 78
            let y = TimelineLayout.baselineY - max(normalized, 0.08) * amplitude
            return TimelineDensityRibbon.Point(x: x, y: y)
        }
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
    
    private struct PositionedTask: Identifiable {
        let task: Task
        let project: Project?
        let laneIndex: Int
        let laneCount: Int
        
        var id: UUID { task.id }
    }
}

// MARK: - Timeline Task Marker

private struct TimelineTaskMarker: View {
    let task: Task
    let project: Project?
    let dateRange: (start: Date, end: Date)
    let timelineWidth: CGFloat
    let laneIndex: Int
    let laneCount: Int
    let isActive: Bool
    let reduceMotion: Bool
    let onTap: () -> Void
    let onHoverChanged: (Bool) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @State private var isHovered = false
    
    private var taskDate: Date {
        task.dueDate ?? task.createdAt
    }
    
    private var xPosition: CGFloat {
        let totalDuration = dateRange.end.timeIntervalSince(dateRange.start)
        guard totalDuration > 0 else {
            return TimelineLayout.horizontalPadding
        }
        
        let offsetFromStart = taskDate.timeIntervalSince(dateRange.start)
        let ratio = CGFloat(offsetFromStart / totalDuration)
        let availableWidth = timelineWidth - (TimelineLayout.horizontalPadding * 2)
        let basePosition = TimelineLayout.horizontalPadding + ratio * availableWidth
        
        if laneCount == 1 {
            return basePosition
        } else {
            let totalSpread = CGFloat(laneCount - 1) * TimelineLayout.duplicateSpacing
            let centeredOffset = CGFloat(laneIndex) * TimelineLayout.duplicateSpacing - totalSpread / 2
            return min(max(basePosition + centeredOffset, TimelineLayout.horizontalPadding), timelineWidth - TimelineLayout.horizontalPadding)
        }
    }
    
    private var markerColor: Color {
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
        let isShowingDetails = isHovered || isActive
        let collapsedWidth: CGFloat = 96
        
        VStack(spacing: 0) {
            if isShowingDetails {
                detailCard
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity
                        )
                    )
                    .padding(.bottom, 14)
            }
            
            Rectangle()
                .fill(markerColor.opacity(0.42))
                .frame(width: 2, height: TimelineLayout.connectionHeight)
                .opacity(isShowingDetails ? 1 : 0.6)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: isShowingDetails)
                .padding(.bottom, 12)
            
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                markerColor.opacity(isShowingDetails ? 0.9 : 0.65),
                                markerColor.opacity(isShowingDetails ? 0.18 : 0.08)
                            ],
                            center: .center,
                            startRadius: 4,
                            endRadius: isShowingDetails ? 28 : 20
                        )
                    )
                    .frame(width: TimelineLayout.nodeBaseSize + 8, height: TimelineLayout.nodeBaseSize + 8)
                    .blur(radius: reduceMotion ? 0 : 6)
                    .opacity(reduceMotion ? 0 : 0.45)
                
                Circle()
                    .fill(markerColor)
                    .frame(width: TimelineLayout.nodeBaseSize, height: TimelineLayout.nodeBaseSize)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.75), lineWidth: isShowingDetails ? 2.4 : 1.4)
                    )
                    .shadow(color: markerColor.opacity(isShowingDetails ? 0.5 : 0.25), radius: isShowingDetails ? 12 : 6, y: isShowingDetails ? 6 : 3)
            }
            .scaleEffect(nodeScale, anchor: .center)
            .animation(reduceMotion ? nil : GlassMotion.Easing.spring, value: nodeScale)
                    }
        .frame(width: isShowingDetails ? TimelineLayout.infoCardWidth : collapsedWidth)
        .position(x: xPosition, y: TimelineLayout.baselineY)
        .onTapGesture { onTap() }
        .onHover { hovering in
            if isHovered != hovering {
                isHovered = hovering
                onHoverChanged(hovering)
            }
        }
        .contentShape(Rectangle())
        .zIndex(isShowingDetails ? 2 : 1)
    }
    
    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(task.title)
                .font(.system(.callout, design: .rounded))
                .fontWeight(.semibold)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            if let project {
                Label {
                    Text(project.title)
                        .lineLimit(1)
                } icon: {
                    Image(systemName: "folder.badge.person.crop")
                        .imageScale(.small)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            HStack(spacing: 8) {
                if let dueDate = task.dueDate {
                    Label(dueDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.9))
                }
                
                if task.status != .todo {
                    Text(task.status.displayName.uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(markerColor.opacity(0.9))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(markerColor.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12))
                )
        )
        .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 12)
    }
    
    private var nodeScale: CGFloat {
        guard !reduceMotion else { return 1 }
        return isActive || isHovered ? TimelineLayout.activeNodeScale : 1
    }
}


