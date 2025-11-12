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
    let selectionMode: Bool
    let selectedProjectIDs: Set<UUID>
    let onSelectionToggle: (Project) -> Void
    let onProjectDetail: (Project) -> Void
    let onProjectEdit: (Project) -> Void
    let onDuplicateProject: (Project) -> Void
    let onArchiveProject: (Project) -> Void
    let onDeleteProject: (Project) -> Void
    
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
                        selectionMode: selectionMode,
                        isSelected: selectedProjectIDs.contains(project.id),
                        onSelectionToggle: { onSelectionToggle(project) },
                        onOpenDetail: { onProjectDetail(project) },
                        onEdit: { onProjectEdit(project) },
                        onDuplicate: { onDuplicateProject(project) },
                        onArchive: { onArchiveProject(project) },
                        onDelete: { onDeleteProject(project) }
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
    @Bindable var project: Project
    let tasks: [Task]
    let areas: [Area]
    let selectionMode: Bool
    let isSelected: Bool
    let onSelectionToggle: () -> Void
    let onOpenDetail: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var isHovered = false
    @State private var isExpanded = false
    @State private var focusMetrics: ProjectFocusMetrics?
    @State private var showFocusDurationSheet = false
    @State private var focusDuration: TimeInterval = 1800 // Default 30 min
    
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
                withAnimation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.3)) {
                    isExpanded.toggle()
                }
            }
        }
        .onTapGesture(count: 2) {
            if selectionMode {
                onSelectionToggle()
            } else {
                onOpenDetail()
            }
        }
        .contextMenu {
            if !selectionMode {
                Button("Start Focus Session") {
                    showFocusDurationSheet = true
                }
                Divider()
                Button("Open") {
                    onOpenDetail()
                }
                Button("Edit") {
                    onEdit()
                }
                Button("Duplicate") {
                    onDuplicate()
                }
                Divider()
                Button("Archive") {
                    onArchive()
                }
                Button("Delete", role: .destructive) {
                    onDelete()
                }
            }
        }
        .sheet(isPresented: $showFocusDurationSheet) {
            FocusDurationSheet(
                isPresented: $showFocusDurationSheet,
                selectedDuration: $focusDuration,
                itemTitle: project.title,
                itemType: "Project",
                onStart: startFocusSession
            )
        }
        .task {
            focusMetrics = ProjectFocusGravityService.shared.focusMetrics(for: project, modelContext: modelContext)
        }
        .onChange(of: selectionMode) { _, newValue in
            if newValue {
                isHovered = false
                withAnimation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.3)) {
                    isExpanded = false
                }
            }
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
                    // Interactive status badge
                    InteractiveProjectStatusBadge(project: project)
                    
                    // Interactive due date badge
                    InteractiveProjectDueDateBadge(project: project)
                    
                    // Area badge (could be made interactive too)
                    if let area = area {
                        InteractiveAreaBadge(project: project, area: area, areas: areas)
                    }
                }
            }
            
            Spacer()
            
            if isHovered && !selectionMode {
                quickActionsView
            }
        }
    }
    
    private var quickActionsView: some View {
        HStack(spacing: 8) {
            ProjectQuickActionButton(icon: "pencil", color: .kosmicBlue) {
                onEdit()
            }
            ProjectQuickActionButton(icon: "archivebox.fill", color: .gray) {
                onArchive()
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
            
            // Interactive fields row
            HStack(spacing: 12) {
                InteractiveProjectStatusPicker(project: project)
                InteractiveProjectDueDatePicker(project: project)
                Spacer()
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
    
    // MARK: - Helper Methods
    
    private func focusGravityAccessibilityLabel(metrics: ProjectFocusMetrics) -> String {
        let average = (metrics.cognitiveFocus + metrics.creativeFlow + metrics.completionEnergy) / 3.0
        let percentage = Int(average * 100)
        return "Focus gravity: \(percentage) percent"
    }
    
    private var cardHeight: CGFloat {
        isExpanded ? 200 : 80
    }
    
    private func startFocusSession() {
        showFocusDurationSheet = false
        
        // Post notification with session parameters instead of starting immediately
        let params = PendingFocusSessionParams(
            objective: project.title,
            plannedDuration: focusDuration,
            targetObjectId: project.id,
            targetObjectType: "project",
            shouldAutoStart: true
        )
        
        // Post session parameters first (will be stored as pending)
        NotificationCenter.default.post(
            name: .startPendingFocusSession,
            object: params
        )
        
        // Switch to focus mode tab (session will start after switch completes)
        NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.focusMode)
    }
}

// MARK: - Interactive Project Status Badge

struct InteractiveProjectStatusBadge: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Menu {
            ForEach(ProjectStatus.allCases, id: \.self) { status in
                Button(action: {
                    withAnimation(GlassMotion.Easing.spring) {
                        project.status = status
                        project.updatedAt = Date()
                    }
                    try? modelContext.save()
                }) {
                    HStack {
                        Text(status.displayName)
                        if project.status == status {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            ProjectStatusBadge(status: project.status)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Interactive Project Due Date Badge

struct InteractiveProjectDueDateBadge: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var modelContext
    @State private var showDatePicker = false
    
    var color: Color {
        guard let dueDate = project.dueDate else { return .gray }
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
        Menu {
            Button("Set Due Date") {
                if project.dueDate == nil {
                    project.dueDate = Date()
                    project.updatedAt = Date()
                    try? modelContext.save()
                }
                showDatePicker = true
            }
            
            if project.dueDate != nil {
                Button("Remove Due Date", role: .destructive) {
                    project.dueDate = nil
                    project.updatedAt = Date()
                    try? modelContext.save()
                }
            }
            
            Divider()
            
            Button("Today") {
                project.dueDate = Calendar.current.startOfDay(for: Date())
                project.updatedAt = Date()
                try? modelContext.save()
            }
            
            Button("Tomorrow") {
                if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) {
                    project.dueDate = Calendar.current.startOfDay(for: tomorrow)
                    project.updatedAt = Date()
                    try? modelContext.save()
                }
            }
            
            Button("Next Week") {
                if let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date()) {
                    project.dueDate = Calendar.current.startOfDay(for: nextWeek)
                    project.updatedAt = Date()
                    try? modelContext.save()
                }
            }
        } label: {
            if let dueDate = project.dueDate {
                ProjectDueDateBadge(dueDate: dueDate)
            } else {
                Image(systemName: "calendar.badge.plus")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(6)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showDatePicker) {
            DatePicker(
                "Due Date",
                selection: Binding(
                    get: { project.dueDate ?? Date() },
                    set: {
                        project.dueDate = $0
                        project.updatedAt = Date()
                        try? modelContext.save()
                        showDatePicker = false
                    }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
        }
    }
}

// MARK: - Interactive Area Badge

struct InteractiveAreaBadge: View {
    @Bindable var project: Project
    let area: Area
    let areas: [Area]
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Menu {
            Button("None") {
                project.areaId = nil
                project.updatedAt = Date()
                try? modelContext.save()
            }
            
            if !areas.isEmpty {
                Divider()
                ForEach(areas) { areaOption in
                    Button(action: {
                        project.areaId = areaOption.id
                        project.updatedAt = Date()
                        try? modelContext.save()
                    }) {
                        HStack {
                            Text(areaOption.title)
                            if project.areaId == areaOption.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            Text(area.title)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Interactive Status Picker (for expanded view)

struct InteractiveProjectStatusPicker: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var modelContext
    
    private func statusColor(for status: ProjectStatus) -> Color {
        switch status {
        case .active:
            return .kosmicBlue
        case .paused:
            return .orange
        case .completed:
            return .kosmicGreen
        }
    }
    
    var body: some View {
        Menu {
            ForEach(ProjectStatus.allCases, id: \.self) { status in
                Button(action: {
                    withAnimation(GlassMotion.Easing.spring) {
                        project.status = status
                        project.updatedAt = Date()
                    }
                    try? modelContext.save()
                }) {
                    HStack {
                        Circle()
                            .fill(statusColor(for: status).opacity(0.2))
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .fill(statusColor(for: status))
                                    .frame(width: 6, height: 6)
                            )
                        Text(status.displayName)
                        if project.status == status {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor(for: project.status).opacity(0.2))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .fill(statusColor(for: project.status))
                            .frame(width: 6, height: 6)
                    )
                Text(project.status.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Interactive Due Date Picker (for expanded view)

struct InteractiveProjectDueDatePicker: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var modelContext
    @State private var showDatePicker = false
    
    var body: some View {
        Menu {
            Button("Set Due Date") {
                if project.dueDate == nil {
                    project.dueDate = Date()
                    project.updatedAt = Date()
                    try? modelContext.save()
                }
                showDatePicker = true
            }
            
            if project.dueDate != nil {
                Button("Remove Due Date", role: .destructive) {
                    project.dueDate = nil
                    project.updatedAt = Date()
                    try? modelContext.save()
                }
            }
            
            Divider()
            
            Button("Today") {
                project.dueDate = Calendar.current.startOfDay(for: Date())
                project.updatedAt = Date()
                try? modelContext.save()
            }
            
            Button("Tomorrow") {
                if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) {
                    project.dueDate = Calendar.current.startOfDay(for: tomorrow)
                    project.updatedAt = Date()
                    try? modelContext.save()
                }
            }
            
            Button("Next Week") {
                if let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date()) {
                    project.dueDate = Calendar.current.startOfDay(for: nextWeek)
                    project.updatedAt = Date()
                    try? modelContext.save()
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.caption2)
                if let dueDate = project.dueDate {
                    Text(dueDate, format: .dateTime.month(.abbreviated).day())
                        .font(.caption)
                } else {
                    Text("No due date")
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showDatePicker) {
            DatePicker(
                "Due Date",
                selection: Binding(
                    get: { project.dueDate ?? Date() },
                    set: {
                        project.dueDate = $0
                        project.updatedAt = Date()
                        try? modelContext.save()
                        showDatePicker = false
                    }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
        }
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

