//
//  ProjectDetailView.swift
//  FocusOS
//
//  Detailed project view with tabs and Focus Gravity sidebar
//

import SwiftUI
import SwiftData
import Charts
import FocusOSShared

struct ProjectDetailView: View {
    let project: Project
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var allTasks: [Task]
    @Query private var allNotes: [Note]
    @Query private var allArtifacts: [FocusOSShared.Artifact]
    @Query private var allAreas: [Area]
    
    @State private var selectedTab: DetailTab = .overview
    @State private var focusMetrics: ProjectFocusMetrics?
    @State private var isSidebarHovered = false
    
    var projectTasks: [Task] {
        allTasks.filter { $0.projectId == project.id }
    }
    
    var projectNotes: [Note] {
        allNotes.filter { $0.projectId == project.id }
    }
    
    var projectArtifacts: [FocusOSShared.Artifact] {
        allArtifacts.filter { $0.projectId == project.id }
    }
    
    var area: Area? {
        guard let areaId = project.areaId else { return nil }
        return allAreas.first { $0.id == areaId }
    }
    
    enum DetailTab: String, CaseIterable {
        case overview = "Overview"
        case tasks = "Tasks"
        case artifacts = "Artifacts"
        case focusLog = "Focus Log"
        
        var icon: String {
            switch self {
            case .overview: return "doc.text"
            case .tasks: return "checkmark.circle"
            case .artifacts: return "sparkles"
            case .focusLog: return "chart.line.uptrend.xyaxis"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Main Content
            VStack(alignment: .leading, spacing: 0) {
                // Header
                headerSection
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Project: \(project.title). Status: \(project.status.displayName)")
                
                Divider()
                
                // Tabs
                tabBar
                
                Divider()
                
                // Tab Content
                tabContent
            }
            .onAppear {
                // Register access for CPS scoring
                AIRecallService.shared.registerAccessed(project, modelContext: modelContext)
            }
            
            Divider()
            
            // Focus Gravity Sidebar
            focusSidebar
                .frame(width: 280)
                .accessibilityLabel("Focus Gravity metrics")
        }
        .task {
            focusMetrics = ProjectFocusGravityService.shared.focusMetrics(for: project, modelContext: modelContext)
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Text(project.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(glassColorSystem.textPrimary())
                        
                        ProjectStatusBadge(status: project.status)
                        
                        if let area = area {
                            Text(area.title)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                    
                    if let goal = formattedText(from: project.goal) {
                        Text(goal)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Focus Ring Indicator
                HStack(spacing: 12) {
                    if let metrics = focusMetrics {
                        FocusRingIndicator(metrics: metrics)
                    }
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
            }
            
            // Progress Bar
            if !projectTasks.isEmpty {
                let completed = projectTasks.filter { $0.status == .done }.count
                let total = projectTasks.count
                let progress = Double(completed) / Double(total)
                
                HStack(spacing: 16) {
                    ProgressRingView(
                        progress: progress,
                        label: "\(completed)/\(total)",
                        isComplete: progress >= 0.999
                    )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Progress")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(progress >= 0.999 ? "All tasks complete" : "On track")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(progress >= 0.999 ? .kosmicPurple : .kosmicBlue)
                    }
                }
            }
        }
        .padding(20)
    }
    
    // MARK: - Tab Bar
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        selectedTab = tab
                        ProjectHaptics.playSelection()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.caption)
                        Text(tab.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(selectedTab == tab ? .kosmicBlue : .secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Rectangle()
                            .fill(selectedTab == tab ? Color.kosmicBlue.opacity(0.1) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Tab Content
    
    private var tabContent: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .overview:
                        overviewContent
                    case .tasks:
                        tasksContent
                    case .artifacts:
                        artifactsContent
                    case .focusLog:
                        focusLogContent
                    }
                }
                .padding(20)
            }
            .id(selectedTab)
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.35), value: selectedTab)
    }
    
    // MARK: - Overview Content
    
    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Context
            if let goal = formattedText(from: project.goal) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Goal")
                        .font(.headline)
                    Text(goal)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            
            // Milestones
            VStack(alignment: .leading, spacing: 8) {
                Text("Milestones")
                    .font(.headline)
                
                if let dueDate = project.dueDate {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.kosmicBlue)
                        Text("Due: \(dueDate, format: .dateTime.month().day().year())")
                            .font(.body)
                    }
                }
                
                Text("Created: \(project.createdAt, format: .dateTime.month().day().year())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Tags
            if !project.tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.headline)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(project.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Tasks Content
    
    private var tasksContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Linked Tasks (\(projectTasks.count))")
                .font(.headline)
            
            if projectTasks.isEmpty {
                Text("No tasks linked to this project")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(projectTasks) { task in
                    HStack {
                        Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(task.status == .done ? .kosmicGreen : .secondary)
                        
                        Text(task.title)
                            .font(.body)
                        
                        Spacer()
                        
                        if let dueDate = task.dueDate {
                            Text(dueDate, format: .dateTime.month().day())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - Artifacts Content
    
    private var artifactsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Related Artifacts (\(projectArtifacts.count))")
                .font(.headline)
            
            if projectArtifacts.isEmpty {
                Text("No artifacts linked to this project")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(projectArtifacts) { artifact in
                    ArtifactRow(artifact: artifact)
                }
            }
        }
    }
    
    // MARK: - Focus Log Content
    
    private var focusLogContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let metrics = focusMetrics {
                // Focus Type Breakdown
                VStack(alignment: .leading, spacing: 12) {
                    Text("Focus Type Breakdown")
                        .font(.headline)
                    
                    FocusBreakdownBar(metrics: metrics)
                }
                
                // Weekly Trend
                if !metrics.weeklyTrend.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Weekly Focus Trend")
                            .font(.headline)
                        
                        Chart(metrics.weeklyTrend, id: \.0) { date, value in
                            LineMark(
                                x: .value("Date", date, unit: .day),
                                y: .value("Focus", value)
                            )
                            .foregroundStyle(Color.kosmicBlue)
                            .interpolationMethod(.catmullRom)
                            
                            AreaMark(
                                x: .value("Date", date, unit: .day),
                                y: .value("Focus", value)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.kosmicBlue.opacity(0.3), Color.kosmicBlue.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                        .frame(height: 200)
                    }
                }
            } else {
                Text("No focus data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Focus Sidebar
    
    private var focusSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Focus Gravity")
                    .font(.headline)
                    .padding(.top, 20)
                
                if let metrics = focusMetrics {
                    // Focus Type Breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Focus Types")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        FocusTypeRow(label: "Cognitive", value: metrics.cognitiveFocus, color: .kosmicBlue)
                        FocusTypeRow(label: "Creative", value: metrics.creativeFlow, color: .kosmicPurple)
                        FocusTypeRow(label: "Completion", value: metrics.completionEnergy, color: .kosmicGreen)
                    }
                    
                    Divider()
                    
                    // Last Active
                    if let lastActive = metrics.lastActiveAt {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last Active")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(lastActive, style: .relative)
                                .font(.subheadline)
                        }
                    }
                    
                    // Avg Session Duration
                    if metrics.avgSessionDuration > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Avg Session")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatDuration(metrics.avgSessionDuration))
                                .font(.subheadline)
                        }
                    }
                    
                    // Weekly Trend Mini
                    if !metrics.weeklyTrend.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Weekly Trend")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Chart(metrics.weeklyTrend, id: \.0) { date, value in
                                LineMark(
                                    x: .value("Date", date, unit: .day),
                                    y: .value("Focus", value)
                                )
                                .foregroundStyle(Color.kosmicBlue)
                                .interpolationMethod(.catmullRom)
                            }
                            .frame(height: 100)
                        }
                    }
                } else {
                    Text("Loading focus metrics...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
        }
        .background(
            glassColorSystem.glassTint(for: .surface)
                .opacity(isSidebarHovered ? 0.42 : 0.3)
                .animation(.easeInOut(duration: 0.25), value: isSidebarHovered)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.25)) {
                isSidebarHovered = hovering
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formattedText(from raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let display = MentionService.shared.convertToDisplayNames(
            text: raw,
            modelContext: modelContext
        )
        return MentionParser.stripTerminators(from: display)
    }
}

// MARK: - Supporting Views

struct ProgressRingView: View {
    let progress: Double
    let label: String
    let isComplete: Bool
    
    @State private var pulse = false
    
    private var normalizedProgress: Double {
        min(max(progress, 0), 1)
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: 8)
            
            Circle()
                .trim(from: 0, to: normalizedProgress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [.kosmicBlue, .kosmicPurple, .kosmicBlue]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: .kosmicPurple.opacity(0.2), radius: 6, x: 0, y: 4)
                .animation(.easeInOut(duration: 0.6), value: normalizedProgress)
            
            Text(label)
                .font(.caption.bold())
                .foregroundColor(.primary)
        }
        .frame(width: 68, height: 68)
        .scaleEffect(isComplete ? (pulse ? 1.06 : 1.0) : 1.0)
        .animation(
            isComplete
                ? .easeInOut(duration: 1.4).repeatForever(autoreverses: true)
                : .default,
            value: pulse
        )
        .onAppear {
            if isComplete {
                pulse = true
            }
        }
        .onChange(of: isComplete) { _, newValue in
            if newValue {
                pulse = true
            } else {
                pulse = false
            }
        }
    }
}

struct FocusRingIndicator: View {
    let metrics: ProjectFocusMetrics
    
    private var dominantFocus: (color: Color, intensity: Double) {
        let maxValue = max(metrics.cognitiveFocus, metrics.creativeFlow, metrics.completionEnergy)
        if maxValue == metrics.cognitiveFocus {
            return (.kosmicBlue, metrics.cognitiveFocus)
        } else if maxValue == metrics.creativeFlow {
            return (.kosmicPurple, metrics.creativeFlow)
        } else {
            return (.kosmicGreen, metrics.completionEnergy)
        }
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(dominantFocus.color.opacity(0.2), lineWidth: 4)
                .frame(width: 40, height: 40)
            
            Circle()
                .trim(from: 0, to: dominantFocus.intensity)
                .stroke(dominantFocus.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(-90))
        }
    }
}

struct FocusBreakdownBar: View {
    let metrics: ProjectFocusMetrics
    
    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.kosmicBlue)
                .frame(width: CGFloat(metrics.cognitiveFocus) * 100)
            
            Rectangle()
                .fill(Color.kosmicPurple)
                .frame(width: CGFloat(metrics.creativeFlow) * 100)
            
            Rectangle()
                .fill(Color.kosmicGreen)
                .frame(width: CGFloat(metrics.completionEnergy) * 100)
        }
        .frame(height: 24)
        .cornerRadius(4)
    }
}

struct FocusTypeRow: View {
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(value), height: 4)
                }
            }
            .frame(height: 4)
        }
        .accessibilityLabel("\(label): \(Int(value * 100)) percent")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

struct ArtifactRow: View {
    let artifact: FocusOSShared.Artifact
    
    var body: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundColor(.kosmicPurple)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(artifact.title.isEmpty ? "Untitled" : artifact.title)
                    .font(.body)
                    .lineLimit(1)
                
                Text(artifact.artifactState.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let publishedAt = artifact.publishedAt {
                Text(publishedAt, format: .dateTime.month().day())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}


