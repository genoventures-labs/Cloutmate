//
//  UnifiedTasksView.swift
//  Cloutmate
//
//  Tasks V2 - Unified view with sectioned grouping and focus orchestration
//

import SwiftUI
import SwiftData
import AppKit
import CloutmateShared
// Note: Area is defined in Cloutmate/Models/Area.swift, not CloutmateShared

struct UnifiedTasksView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Query(sort: \CloutmateShared.Task.updatedAt, order: .reverse) private var allTasks: [CloutmateShared.Task]
    @Query private var allProjects: [CloutmateShared.Project]
    @Query private var allAreas: [Area]
    
    @State private var selectedFilter: TasksHeaderView.TaskFilter = .all
    @State private var selectedViewMode: TaskViewMode = .list
    @State private var activeTask: Task?
    @State private var isDrawerVisible = false
    @State private var isCreatingTask = false
    @State private var focusOverlayTask: Task?
    @State private var focusDuration: TimeInterval = 1800
    @State private var scrollOffset: CGFloat = 0
    @State private var focusedTaskIndex: Int?
    @State private var showFocusRecap = false
    @State private var expandedSections: Set<TaskSectionType> = [.today, .nextUp, .later]
    @State private var isSelectionMode = false
    @State private var selectedTaskIDs: Set<UUID> = []
    
    enum TaskSectionType: String, CaseIterable {
        case today = "Today"
        case nextUp = "Next Up"
        case later = "Later"
        case completed = "Completed"
    }
    
    struct TaskSection: Identifiable {
        let id = UUID()
        let type: TaskSectionType
        var tasks: [Task]
        var isCollapsed: Bool
    }
    
    private var filteredTasks: [Task] {
        var filtered = allTasks
        
        switch selectedFilter {
        case .all:
            break
        case .today:
            filtered = filtered.filter { task in
                guard let due = task.dueDate else { return false }
                return Calendar.current.isDateInToday(due) && task.status != .done
            }
        case .upcoming:
            filtered = filtered.filter { task in
                guard let due = task.dueDate else { return false }
                let days = Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0
                return days > 0 && days <= 7 && task.status != .done
            }
        case .completed:
            filtered = filtered.filter { $0.status == .done }
        }
        
        return filtered
    }
    
    private var groupedSections: [TaskSection] {
        let today = Calendar.current.startOfDay(for: Date())
        let threeDaysFromNow = Calendar.current.date(byAdding: .day, value: 3, to: today)!
        
        let todayTasks = filteredTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return Calendar.current.isDateInToday(due) && task.status != .done
        }
        
        let nextUpTasks = filteredTasks.filter { task in
            guard let due = task.dueDate else { return false }
            let days = Calendar.current.dateComponents([.day], from: today, to: due).day ?? 0
            return days > 0 && days <= 3 && task.status != .done && !Calendar.current.isDateInToday(due)
        }
        
        let laterTasks = filteredTasks.filter { task in
            if task.status == .done { return false }
            guard let due = task.dueDate else { return true }
            let days = Calendar.current.dateComponents([.day], from: today, to: due).day ?? 0
            return days > 3 || days < 0
        }
        
        let completedTasks = filteredTasks.filter { $0.status == .done }
        
        return [
            TaskSection(type: .today, tasks: todayTasks, isCollapsed: !expandedSections.contains(.today)),
            TaskSection(type: .nextUp, tasks: nextUpTasks, isCollapsed: !expandedSections.contains(.nextUp)),
            TaskSection(type: .later, tasks: laterTasks, isCollapsed: !expandedSections.contains(.later)),
            TaskSection(type: .completed, tasks: completedTasks, isCollapsed: !expandedSections.contains(.completed))
        ]
    }
    
    private var todayCompletionRate: String {
        let todayTasks = allTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return Calendar.current.isDateInToday(due)
        }
        let completed = todayTasks.filter { $0.status == .done }.count
        let total = todayTasks.count
        return total > 0 ? "\(completed)/\(total) complete" : "0/0 complete"
    }
    
    private var currentStreak: Int {
        // Calculate streak based on completed tasks per day
        // Simplified implementation - can be enhanced later
        var streak = 0
        var checkDate = Calendar.current.startOfDay(for: Date())
        
        while streak < 365 { // Max 365 day streak
            let dayTasks = allTasks.filter { task in
                guard let completed = task.completedAt else { return false }
                return Calendar.current.isDate(completed, inSameDayAs: checkDate)
            }
            
            if dayTasks.isEmpty {
                break
            }
            
            streak += 1
            guard let prevDate = Calendar.current.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prevDate
        }
        
        return streak
    }
    
    private var isSelectionActive: Bool {
        isSelectionMode || !selectedTaskIDs.isEmpty
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(.windowBackgroundColor)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                TasksHeaderView(
                    todayCompletionRate: todayCompletionRate,
                    currentStreak: currentStreak,
                    selectedFilter: selectedFilter,
                    selectedViewMode: selectedViewMode,
                    onFilterChange: { selectedFilter = $0 },
                    onViewModeChange: { selectedViewMode = $0 },
                    onQuickAdd: {
                        startCreatingTask()
                    }
                )
                .glassPanel(tier: .overlay, cornerRadius: 12)
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 8)
                .opacity(headerOpacity)
                .offset(y: headerOffset)
                .transition(.move(edge: .top).combined(with: .opacity))
                
                Divider()
                
                // Content based on selected view mode
                contentView
            }
            .opacity(isDrawerVisible ? 0 : 1)
            
            if let task = activeTask, isDrawerVisible {
                TaskDetailDrawer(
                    task: task,
                    isPresented: Binding(
                        get: { isDrawerVisible },
                        set: { newValue in
                            withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                                isDrawerVisible = newValue
                            }
                        }
                    ),
                    mode: isCreatingTask ? .create : .edit
                )
                .transition(.move(edge: .trailing))
            }
            
            if let focusTask = focusOverlayTask {
                FocusDurationSheet(
                    isPresented: Binding(
                        get: { focusOverlayTask != nil },
                        set: { newValue in
                            if !newValue {
                                focusOverlayTask = nil
                            }
                        }
                    ),
                    selectedDuration: $focusDuration,
                    itemTitle: focusTask.title,
                    itemType: "Task",
                    onStart: {
                        startFocusSession(for: focusTask)
                    }
                )
            }
        }
        .onAppear {
            checkFocusRecap()
            setupKeyboardNavigation()
        }
        .onChange(of: groupedSections.first(where: { $0.type == .today })?.tasks.count ?? 0) { _, newValue in
            if newValue == 0 {
                checkFocusRecap()
            }
        }
        .onKeyPress(.leftArrow) {
            if let currentIndex = TaskViewMode.allCases.firstIndex(of: selectedViewMode),
               currentIndex > 0 {
                selectedViewMode = TaskViewMode.allCases[currentIndex - 1]
            }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            if let currentIndex = TaskViewMode.allCases.firstIndex(of: selectedViewMode),
               currentIndex < TaskViewMode.allCases.count - 1 {
                selectedViewMode = TaskViewMode.allCases[currentIndex + 1]
            }
            return .handled
        }
        .onChange(of: isDrawerVisible) { _, newValue in
            if !newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if !isDrawerVisible {
                        activeTask = nil
                        isCreatingTask = false
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showCreateTask)) { notification in
            let dueDate = notification.object as? Date
            startCreatingTask(dueDate: dueDate)
        }
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
                    }
                    .frame(height: 0)
                    
                    Group {
                        switch selectedViewMode {
                        case .list:
                            listView
                        case .board:
                            TaskBoardView(
                                tasks: filteredTasks,
                                projects: allProjects,
                                areas: allAreas,
                                selectionMode: isSelectionMode,
                                selectedTaskIDs: selectedTaskIDs,
                                onSelectionToggle: { task in toggleTaskSelection(task) },
                                onTaskSelected: { task in openDrawer(for: task) },
                                onDuplicateTask: duplicateTask,
                                onArchiveTask: { task in
                                    task.status = .cancelled
                                    try? modelContext.save()
                                },
                                onDeleteTask: deleteTask
                            )
                        case .timeline:
                            TaskTimelineView(
                                tasks: filteredTasks,
                                projects: allProjects,
                                areas: allAreas,
                                onTaskSelected: { task in openDrawer(for: task) }
                            )
                        case .gallery:
                            TaskGalleryView(
                                tasks: filteredTasks,
                                projects: allProjects,
                                areas: allAreas,
                                selectionMode: isSelectionMode,
                                selectedTaskIDs: selectedTaskIDs,
                                onSelectionToggle: { task in toggleTaskSelection(task) },
                                onTaskSelected: { task in openDrawer(for: task) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = -value
            }
        }
    }
    
    private var listView: some View {
        VStack(spacing: 0) {
            // Focus Recap Banner
            if showFocusRecap {
                FocusRecapBanner(streak: currentStreak)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation(GlassMotion.Easing.spring) {
                                showFocusRecap = false
                            }
                        }
                    }
            }
            
            // Task sections
            ScrollView {
                ScrollViewReader { proxy in
                    LazyVStack(spacing: 24) {
                        ForEach(groupedSections) { section in
                            if !section.tasks.isEmpty || section.type == .completed {
                                TaskSectionView(
                                    section: section,
                                    projects: allProjects,
                                    areas: allAreas,
                                    focusedTaskIndex: $focusedTaskIndex,
                                    onToggleCollapse: {
                                        withAnimation(GlassMotion.Easing.spring) {
                                            if expandedSections.contains(section.type) {
                                                expandedSections.remove(section.type)
                                            } else {
                                                expandedSections.insert(section.type)
                                            }
                                        }
                                    },
                                    onEdit: { task in
                                        openDrawer(for: task)
                                    },
                                    onDuplicate: duplicateTask,
                                    onArchive: { task in
                                        task.status = .cancelled
                                        try? modelContext.save()
                                    },
                                    onDelete: deleteTask,
                                    onRequestFocus: { task in
                                        requestFocusSession(for: task)
                                    }
                                )
                            }
                        }
                        
                        // Empty state
                        if filteredTasks.isEmpty {
                            TasksEmptyStateView(filter: selectedFilter)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
        }
    }
    
    private func toggleTaskSelection(_ task: Task) {
        if selectedTaskIDs.contains(task.id) {
            selectedTaskIDs.remove(task.id)
            if selectedTaskIDs.isEmpty {
                isSelectionMode = false
            }
        } else {
            if !isSelectionMode {
                isSelectionMode = true
            }
            selectedTaskIDs.insert(task.id)
        }
        if isSelectionActive {
            withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                isDrawerVisible = false
                focusOverlayTask = nil
            }
        }
    }
    
    private func startCreatingTask(dueDate: Date? = nil) {
        guard !isDrawerVisible else { return }
        
        let newTask = Task(
            title: "",
            notes: nil,
            status: .todo,
            priority: .medium,
            dueDate: dueDate,
            projectId: nil,
            areaId: nil,
            effort: nil
        )
        
        modelContext.insert(newTask)
        activeTask = newTask
        isCreatingTask = true
        
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isDrawerVisible = true
        }
    }
    
    private func openDrawer(for task: Task) {
        guard !isSelectionActive else { return }
        
        activeTask = task
        isCreatingTask = false
        
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isDrawerVisible = true
        }
    }
    
    private func requestFocusSession(for task: Task) {
        guard focusOverlayTask?.id != task.id else { return }
        focusDuration = 1800
        withAnimation(.easeInOut(duration: 0.2)) {
            isDrawerVisible = false
            focusOverlayTask = task
        }
    }
    
    private func startFocusSession(for task: Task) {
        withAnimation(.easeOut(duration: 0.2)) {
            focusOverlayTask = nil
        }
        
        let params = PendingFocusSessionParams(
            objective: task.title,
            plannedDuration: focusDuration,
            targetObjectId: task.id,
            targetObjectType: "task"
        )
        
        NotificationCenter.default.post(name: .startPendingFocusSession, object: params)
        NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.focusMode)
    }
    
    private var headerOpacity: Double {
        let threshold: CGFloat = 100
        if scrollOffset > threshold {
            return max(0.3, 1.0 - (scrollOffset - threshold) / 200)
        }
        return 1.0
    }
    
    private var headerOffset: CGFloat {
        let threshold: CGFloat = 100
        if scrollOffset > threshold {
            return min(-20, -(scrollOffset - threshold) / 10)
        }
        return 0
    }
    
    private func checkFocusRecap() {
        let todayTasks = allTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return Calendar.current.isDateInToday(due)
        }
        let allComplete = todayTasks.allSatisfy { $0.status == .done }
        
        if allComplete && !todayTasks.isEmpty {
            withAnimation(GlassMotion.Easing.spring) {
                showFocusRecap = true
            }
        }
    }
    
    private func setupKeyboardNavigation() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Don't intercept if a text field or text editor is focused
            if let firstResponder = NSApp.keyWindow?.firstResponder,
               (firstResponder is NSTextView || firstResponder is NSTextField) {
                return event
            }
            
            if event.modifierFlags.contains(.command) {
                switch event.charactersIgnoringModifiers?.lowercased() {
                case "n":
                    startCreatingTask()
                    return nil
                case "\r": // Enter
                    if let index = focusedTaskIndex {
                        let allTasks = groupedSections.flatMap { $0.tasks }
                        if index < allTasks.count {
                            allTasks[index].status = .done
                            try? modelContext.save()
                        }
                    }
                    return nil
                default:
                    break
                }
            } else {
                switch event.keyCode {
                case 126: // Up arrow
                    navigateTasks(direction: -1)
                    return nil
                case 125: // Down arrow
                    navigateTasks(direction: 1)
                    return nil
                case 53: // Escape
                    if isDrawerVisible {
                        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                            isDrawerVisible = false
                        }
                        return nil
                    }
                    focusedTaskIndex = nil
                    return nil
                case 49: // Space
                    if let index = focusedTaskIndex {
                        let allTasks = groupedSections.flatMap { $0.tasks }
                        if index < allTasks.count {
                            // Toggle expansion handled in TaskCardV2
                        }
                    }
                    return nil
                default:
                    break
                }
            }
            return event
        }
    }
    
    private func navigateTasks(direction: Int) {
        let allTasks = groupedSections.flatMap { $0.tasks }
        if allTasks.isEmpty { return }
        
        let currentIndex = focusedTaskIndex ?? -1
        let newIndex = max(0, min(allTasks.count - 1, currentIndex + direction))
        focusedTaskIndex = newIndex
    }
    
    private func deleteTask(_ task: Task) {
        modelContext.delete(task)
        try? modelContext.save()
    }
    
    private func duplicateTask(_ task: Task) {
        let copy = Task(
            title: task.title,
            notes: task.notes,
            status: task.status,
            priority: task.priority,
            dueDate: task.dueDate,
            projectId: task.projectId,
            areaId: task.areaId,
            effort: task.effort
        )
        modelContext.insert(copy)
        try? modelContext.save()
    }
}

// MARK: - Task Section View

struct TaskSectionView: View {
    let section: UnifiedTasksView.TaskSection
    let projects: [Project]
    let areas: [Area]
    @Binding var focusedTaskIndex: Int?
    let onToggleCollapse: () -> Void
    let onEdit: (Task) -> Void
    let onDuplicate: (Task) -> Void
    let onArchive: (Task) -> Void
    let onDelete: (Task) -> Void
    let onRequestFocus: (Task) -> Void
    
    @State private var globalTaskIndex = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Button(action: onToggleCollapse) {
                HStack {
                    Text(section.type.rawValue)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.kosmicBlue, .kosmicPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Spacer()
                    
                    Text("\(section.tasks.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: section.isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            // Divider
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)
                .padding(.bottom, 4)
            
            // Task cards
            if !section.isCollapsed {
                LazyVStack(spacing: 12) {
                    ForEach(Array(section.tasks.enumerated()), id: \.element.id) { index, task in
                        let project = projects.first(where: { $0.id == task.projectId })
                        let area = areas.first(where: { $0.id == task.areaId })
                        let metrics = TaskFocusMetrics.defaultMetrics(for: task)
                        
                        TaskCardV2(
                            task: task,
                            project: project,
                            area: area,
                            metrics: metrics,
                            onEdit: { onEdit(task) },
                            onDuplicate: { onDuplicate(task) },
                            onArchive: { onArchive(task) },
                            onDelete: { onDelete(task) },
                            onRequestFocus: { onRequestFocus(task) }
                        )
                        .id("task-\(task.id)")
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Focus Recap Banner

struct FocusRecapBanner: View {
    let streak: Int
    
    @State private var pulsePhase: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.kosmicGreen)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("All tasks complete! 🎉")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Focus streak: \(streak) days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color.kosmicBlue.opacity(0.15),
                    Color.kosmicPurple.opacity(0.15)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.kosmicBlue.opacity(0.3 + pulsePhase * 0.2),
                            Color.kosmicPurple.opacity(0.3 + pulsePhase * 0.2)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2
                )
        )
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
            ) {
                pulsePhase = 1.0
            }
        }
    }
}

// MARK: - Tasks Empty State View

struct TasksEmptyStateView: View {
    let filter: TasksHeaderView.TaskFilter
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("No tasks found in this view")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
    
    private var iconName: String {
        switch filter {
        case .today:
            return "calendar.badge.clock"
        case .upcoming:
            return "calendar"
        case .completed:
            return "checkmark.circle"
        case .all:
            return "list.bullet"
        }
    }
    
    private var message: String {
        switch filter {
        case .today:
            return "No tasks for today"
        case .upcoming:
            return "No upcoming tasks"
        case .completed:
            return "No completed tasks"
        case .all:
            return "No tasks yet"
        }
    }
}

