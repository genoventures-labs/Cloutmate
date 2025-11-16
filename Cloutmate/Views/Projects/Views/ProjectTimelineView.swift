//
//  ProjectTimelineView.swift
//  Cloutmate
//
//  Timeline view for Projects with milestone visualization
//

import SwiftUI
import SwiftData
import CloutmateShared

struct ProjectTimelineView: View {
    let projects: [Project]
    let tasks: [Task]
    let areas: [Area]
    let onProjectSelected: (Project) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var hoveredProjectID: UUID?
    @State private var selectedProject: Project?
    
    private var dateRange: (start: Date, end: Date) {
        let allDates = projects.compactMap { $0.dueDate } + projects.map { $0.createdAt }
        guard let minDate = allDates.min(), let maxDate = allDates.max() else {
            let now = Date()
            return (now, Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now)
        }
        return (minDate, maxDate)
    }
    
    private var positionedProjects: [PositionedProject] {
        let sorted = projects.sorted { ($0.dueDate ?? $0.createdAt) < ($1.dueDate ?? $1.createdAt) }
        let calendar = Calendar.current
        var counts: [Date: Int] = [:]
        sorted.forEach { project in
            let bucket = calendar.startOfDay(for: project.dueDate ?? project.createdAt)
            counts[bucket, default: 0] += 1
        }
        var laneAssignments: [Date: Int] = [:]
        
        return sorted.map { project in
            let bucket = calendar.startOfDay(for: project.dueDate ?? project.createdAt)
            let laneIndex = laneAssignments[bucket, default: 0]
            laneAssignments[bucket] = laneIndex + 1
            let laneCount = counts[bucket] ?? 1
            return PositionedProject(project: project, laneIndex: laneIndex, laneCount: laneCount)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if positionedProjects.isEmpty {
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
        .sheet(item: $selectedProject) { project in
            ProjectSnapshotDrawer(project: project)
        }
    }
    
    private var axisTickCount: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month], from: dateRange.start, to: dateRange.end)
        let months = max(components.month ?? 1, 1)
        return min(max(months, 3), 8)
    }
    
    @ViewBuilder
    private func timelineContent(trackWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            TimelineTrackBackground(
                width: trackWidth,
                height: TimelineLayout.trackHeight,
                accentGradient: AuroraPalette.linearGradient(for: colorScheme)
            )
            if !reduceMotion {
                FocusGravityWave(
                    metrics: calculateOverallMetrics(),
                    width: trackWidth,
                    height: TimelineLayout.trackHeight * 0.65
                )
                .opacity(0.28)
                .offset(y: TimelineLayout.baselineY - (TimelineLayout.trackHeight * 0.45))
            }
            
            let densityPoints = projectDensityPoints(for: trackWidth)
            if densityPoints.count >= 2 {
                TimelineDensityRibbon(
                    points: densityPoints,
                    baselineY: TimelineLayout.baselineY,
                    fillGradient: Gradient(colors: [
                        Color.kosmicBlue.opacity(0.12),
                        Color.kosmicPurple.opacity(0.1),
                        Color.kosmicGreen.opacity(0.08)
                    ]),
                    strokeGradient: Gradient(colors: [
                        Color.kosmicBlue.opacity(0.85),
                        Color.kosmicPurple.opacity(0.85),
                        Color.kosmicGreen.opacity(0.85)
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
            
            ForEach(positionedProjects) { positioned in
                TimelineMilestone(
                    project: positioned.project,
                    taskCount: tasks.filter { $0.projectId == positioned.project.id }.count,
                    dateRange: dateRange,
                    timelineWidth: trackWidth,
                    laneIndex: positioned.laneIndex,
                    laneCount: positioned.laneCount,
                    isActive: hoveredProjectID == positioned.project.id,
                    reduceMotion: reduceMotion,
                    modelContext: modelContext,
                    onTap: {
                        selectedProject = positioned.project
                        onProjectSelected(positioned.project)
                    },
                    onHoverChanged: { hovering in
                        hoveredProjectID = hovering ? positioned.project.id : nil
                    }
                )
                .zIndex(hoveredProjectID == positioned.project.id ? 3 : 1)
            }
        }
        .overlay(alignment: .topLeading) {
            TimelineDateRangeLabel(
                startDate: dateRange.start,
                endDate: dateRange.end,
                alignment: .leading,
                icon: "chart.bar.doc.horizontal"
            )
            .padding(.leading, 24)
            .padding(.top, 10)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "timeline.selection")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No projects")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Create projects to see them on the timeline")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }
    
    private func projectDensityPoints(for width: CGFloat) -> [TimelineDensityRibbon.Point] {
        let calendar = Calendar.current
        let buckets = projects.reduce(into: [Date: Int]()) { partial, project in
            let bucket = calendar.startOfDay(for: project.dueDate ?? project.createdAt)
            partial[bucket, default: 0] += 1
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
            let amplitude: CGFloat = 92
            let y = TimelineLayout.baselineY - max(normalized, 0.08) * amplitude
            return TimelineDensityRibbon.Point(x: x, y: y)
        }
    }
    
    private func calculateOverallMetrics() -> ProjectFocusMetrics {
        let allMetrics = projects.compactMap { project in
            ProjectFocusGravityService.shared.focusMetrics(for: project, modelContext: modelContext)
        }
        
        guard !allMetrics.isEmpty else {
            return ProjectFocusMetrics(
                cognitiveFocus: 0.5,
                creativeFlow: 0.5,
                completionEnergy: 0.5,
                lastActiveAt: nil,
                avgSessionDuration: 0,
                weeklyTrend: []
            )
        }
        
        let avgCognitive = allMetrics.map { $0.cognitiveFocus }.reduce(0, +) / Double(allMetrics.count)
        let avgCreative = allMetrics.map { $0.creativeFlow }.reduce(0, +) / Double(allMetrics.count)
        let avgCompletion = allMetrics.map { $0.completionEnergy }.reduce(0, +) / Double(allMetrics.count)
        
        return ProjectFocusMetrics(
            cognitiveFocus: avgCognitive,
            creativeFlow: avgCreative,
            completionEnergy: avgCompletion,
            lastActiveAt: nil,
            avgSessionDuration: 0,
            weeklyTrend: []
        )
    }
    
    private struct PositionedProject: Identifiable {
        let project: Project
        let laneIndex: Int
        let laneCount: Int
        
        var id: UUID { project.id }
    }
}

// MARK: - Timeline Milestone

private struct TimelineMilestone: View {
    let project: Project
    let taskCount: Int
    let dateRange: (start: Date, end: Date)
    let timelineWidth: CGFloat
    let laneIndex: Int
    let laneCount: Int
    let isActive: Bool
    let reduceMotion: Bool
    let modelContext: ModelContext
    let onTap: () -> Void
    let onHoverChanged: (Bool) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @State private var isHovered = false
    @State private var focusMetrics: ProjectFocusMetrics?
    
    private var projectDate: Date {
        project.dueDate ?? project.createdAt
    }
    
    private var xPosition: CGFloat {
        let totalDuration = dateRange.end.timeIntervalSince(dateRange.start)
        guard totalDuration > 0 else {
            return TimelineLayout.horizontalPadding
        }
        let offsetFromStart = projectDate.timeIntervalSince(dateRange.start)
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
    
    private var nodeScale: CGFloat {
        guard !reduceMotion else { return 1 }
        return isActive || isHovered ? TimelineLayout.activeNodeScale : 1
    }
    
    var body: some View {
        let isShowingDetails = isHovered || isActive
        let collapsedWidth: CGFloat = 108
        
        VStack(spacing: 0) {
            if isShowingDetails {
                detailCard
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity
                        )
                    )
                    .padding(.bottom, 18)
            }
            
            Rectangle()
                .fill(Color.kosmicBlue.opacity(isShowingDetails ? 0.45 : 0.28))
                .frame(width: 2.5, height: TimelineLayout.connectionHeight + 8)
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.42))
                        .frame(width: 1, height: TimelineLayout.connectionHeight + 8)
                )
                .opacity(isShowingDetails ? 1 : 0.7)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: isShowingDetails)
                .padding(.bottom, 16)
            
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.kosmicBlue.opacity(isShowingDetails ? 0.85 : 0.6),
                                Color.kosmicPurple.opacity(isShowingDetails ? 0.3 : 0.12),
                                Color.kosmicPurple.opacity(0.06)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: isShowingDetails ? 32 : 24
                        )
                    )
                    .frame(width: TimelineLayout.nodeBaseSize + 14, height: TimelineLayout.nodeBaseSize + 14)
                    .blur(radius: reduceMotion ? 0 : 8)
                    .opacity(reduceMotion ? 0.1 : 0.45)
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.kosmicBlue, .kosmicPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: TimelineLayout.nodeBaseSize, height: TimelineLayout.nodeBaseSize)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.82), lineWidth: isShowingDetails ? 2.6 : 1.6)
                    )
                    .shadow(color: Color.kosmicPurple.opacity(isShowingDetails ? 0.55 : 0.28), radius: isShowingDetails ? 14 : 8, y: isShowingDetails ? 7 : 3)
                
                if let metrics = focusMetrics {
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                colors: [
                                    Color.kosmicBlue.opacity(metrics.cognitiveFocus),
                                    Color.kosmicPurple.opacity(metrics.creativeFlow),
                                    Color.kosmicGreen.opacity(metrics.completionEnergy)
                                ],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: TimelineLayout.nodeBaseSize + 12, height: TimelineLayout.nodeBaseSize + 12)
                        .blur(radius: reduceMotion ? 0 : 0.5)
                }
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
        .zIndex(isShowingDetails ? 3 : 1)
        .task {
            focusMetrics = ProjectFocusGravityService.shared.focusMetrics(for: project, modelContext: modelContext)
        }
    }
    
    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(project.title)
                .font(.system(.callout, design: .rounded))
                .fontWeight(.semibold)
                .lineLimit(2)
            
            if let dueDate = project.dueDate {
                Label {
                    Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                } icon: {
                    Image(systemName: "calendar")
                        .imageScale(.small)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            } else {
                Text("No due date")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            
            HStack(spacing: 8) {
                if taskCount > 0 {
                    Label("\(taskCount) Task\(taskCount == 1 ? "" : "s")", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.9))
                }
                
                if let metrics = focusMetrics {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.kosmicBlue.opacity(metrics.cognitiveFocus),
                                    Color.kosmicPurple.opacity(metrics.creativeFlow)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 56, height: 6)
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.18))
                        )
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.14))
                )
        )
        .shadow(color: .black.opacity(0.16), radius: 18, x: 0, y: 12)
    }
}

// MARK: - Project Snapshot Drawer

struct ProjectSnapshotDrawer: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(project.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let goal = project.goal {
                        Text(goal)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Focus Graph Snippet
                    Text("Focus Gravity")
                        .font(.headline)
                    
                    // Add focus graph visualization here
                }
                .padding()
            }
            .navigationTitle("Project Snapshot")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 400, height: 500)
    }
}

