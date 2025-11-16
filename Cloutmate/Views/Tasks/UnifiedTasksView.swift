//
//  UnifiedTasksView.swift
//  Cloutmate
//
//  Tasks V2 - Unified view with sectioned grouping and focus orchestration
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers
import CloutmateShared
// Note: Area is defined in Cloutmate/Models/Area.swift, not CloutmateShared

struct UnifiedTasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Query(sort: \CloutmateShared.Task.updatedAt, order: .reverse) private var allTasks: [CloutmateShared.Task]
    @Query private var allProjects: [CloutmateShared.Project]
    @Query private var allAreas: [Area]
    
    @State private var selectedFilter: TaskFilter = .all
    @State private var selectedViewMode: TaskViewMode = .list
    @State private var activeTask: Task?
    @State private var isDrawerVisible = false
    @State private var isCreatingTask = false
    @State private var pendingTaskDraft: TaskDraft?
    @State private var focusOverlayTask: Task?
    @State private var focusDuration: TimeInterval = 1800
    @State private var focusedTaskIndex: Int?
    @State private var showFocusRecap = false
    @State private var expandedSections: Set<TaskSectionType> = [.today, .nextUp, .later]
    @State private var isSelectionMode = false
    @State private var selectedTaskIDs: Set<UUID> = []
    
    enum TaskFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case today = "Today"
        case upcoming = "Upcoming"
        case completed = "Completed"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .today: return "sun.max.fill"
            case .upcoming: return "calendar"
            case .completed: return "checkmark.circle.fill"
            }
        }
    }
    
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
        ZStack {
            V2GlassContentScaffold(
                accentGradient: AuroraPalette.linearGradient(for: colorScheme),
                showsSidebar: false,
                header: { headerBar },
                content: { tasksContent },
                sidebar: { EmptyView() }
            )
            .opacity(isDrawerVisible ? 0 : 1)
            
            if isDrawerVisible {
                if isCreatingTask, let draft = pendingTaskDraft {
                    TaskDetailDrawer(
                        mode: .create,
                        existingTask: nil,
                        initialDraft: draft,
                        isPresented: creationDrawerBinding(),
                        onCommit: { committedDraft in
                            commitNewTask(from: committedDraft)
                        },
                        onCancel: {
                            pendingTaskDraft = nil
                            withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                                isDrawerVisible = false
                            }
                            isCreatingTask = false
                        }
                    )
                    .transition(.move(edge: .trailing))
                } else if let task = activeTask {
                    TaskDetailDrawer(
                        mode: .edit,
                        existingTask: task,
                        initialDraft: TaskDraft(task: task),
                        isPresented: editDrawerBinding(),
                        onCommit: { updatedDraft in
                            apply(updatedDraft, to: task)
                            try? modelContext.save()
                            withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                                isDrawerVisible = false
                            }
                            DispatchQueue.main.async {
                                activeTask = nil
                            }
                        },
                        onCancel: {
                            withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                                isDrawerVisible = false
                            }
                            DispatchQueue.main.async {
                                activeTask = nil
                            }
                        }
                    )
                    .transition(.move(edge: .trailing))
                }
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
    
    // MARK: - Layout
    
    private var headerBar: some View {
        V2GlassHeaderBar(
            title: "Tasks",
            subtitle: "Focus summary: \(todayCompletionRate) • \(currentStreak)-day streak",
            trailingAccessory: {
                HStack(spacing: 12) {
                    viewModeSelector
                    quickAddButton
                }
            }
        )
    }
    
    @ViewBuilder
    private var tasksContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            filterPanel
            activeModeView
        }
        .animation(.easeInOut(duration: 0.24), value: selectedViewMode)
                    }

    @ViewBuilder
    private var activeModeView: some View {
                        switch selectedViewMode {
                        case .list:
                            listView
                        case .board:
            boardView
        case .planner:
            plannerView
        case .gallery:
            galleryView
        }
    }
    
    private var viewModeSelector: some View {
        HStack(spacing: 6) {
            ForEach(TaskViewMode.allCases, id: \.self, content: modeButton)
        }
    }

    @ViewBuilder
    private func modeButton(for mode: TaskViewMode) -> some View {
        let isSelected = selectedViewMode == mode
        Button {
            selectedViewMode = mode
        } label: {
            Image(systemName: mode.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : glassColorSystem.textSecondary())
                .frame(width: 28, height: 28)
                .background {
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.kosmicBlue, .kosmicPurple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(glassColorSystem.cardColor().opacity(0.35))
                        }
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(glassColorSystem.borderColor().opacity(0.5), lineWidth: 0.6)
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }
    
    private var quickAddButton: some View {
        GlassButton(
            icon: "plus",
            style: .iconOnly,
            tintColor: .kosmicPurple,
            action: { startCreatingTask() }
        )
        .frame(width: 32, height: 32)
                                }
    
    private var filterPanel: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.kosmicPurple)
                        .padding(10)
                        .background(
                            Circle()
                                .fill(glassColorSystem.cardColor().opacity(0.4))
                                .overlay(
                                    Circle()
                                        .stroke(glassColorSystem.borderColor().opacity(0.6), lineWidth: 0.5)
                                )
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Focus your tasks")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(glassColorSystem.textPrimary())
                        Text("Choose the view and highlight the work that matters right now.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(glassColorSystem.textSecondary())
                    }
                    
                    Spacer()
                    
                    Button(role: nil) {
                        withAnimation(GlassMotion.Easing.spring) {
                            selectedFilter = .all
                        }
                    } label: {
                        Text("Reset")
                            .font(.system(.caption, design: .rounded).weight(.medium))
                            .foregroundStyle(glassColorSystem.textSecondary())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(glassColorSystem.cardColor().opacity(0.28))
                            )
                    }
                    .buttonStyle(.plain)
                }
                
                GlassDivider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Filter")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(TaskFilter.allCases) { filter in
                                FilterPill(
                                    title: filter.rawValue,
                                    isSelected: selectedFilter == filter,
                                    action: {
                                        withAnimation(GlassMotion.Easing.spring) {
                                            selectedFilter = filter
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
            .padding(24)
        }
    }
    
    private var listView: some View {
        VStack(alignment: .leading, spacing: 24) {
            if showFocusRecap {
                FocusRecapBanner(streak: currentStreak)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation(GlassMotion.Easing.spring) {
                                showFocusRecap = false
                            }
                        }
                    }
            }
            
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
                            },
                            onMoveTaskToSection: { task, destination in
                                handleTaskMove(task, to: destination)
                            },
                            onReorderTasks: { ordered, sectionType in
                                persistTaskOrder(ordered, in: sectionType)
                            },
                            fetchTaskByID: { id in
                                allTasks.first(where: { $0.id == id })
                                    }
                                )
                            }
                        }
                        
                        if filteredTasks.isEmpty {
                            TasksEmptyStateView(filter: selectedFilter)
                    .transition(.opacity)
                        }
                    }
    }

    private var boardView: some View {
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
            onDeleteTask: deleteTask,
            onStartFocus: { task in
                requestFocusSession(for: task)
            },
            onQuickAddTask: { status in
                startCreatingTask(status: status)
            }
        )
        .padding(.top, 8)
    }
    
    private var plannerView: some View {
        TaskPlannerView(
            tasks: filteredTasks,
            projects: allProjects,
            areas: allAreas,
            onTaskSelected: { task in openDrawer(for: task) },
            onStartFocus: { task in requestFocusSession(for: task) }
        )
        .padding(.vertical, 4)
                }
    
    private var galleryView: some View {
        TaskGalleryView(
            tasks: filteredTasks,
            projects: allProjects,
            areas: allAreas,
            selectionMode: isSelectionMode,
            selectedTaskIDs: selectedTaskIDs,
            onSelectionToggle: { task in toggleTaskSelection(task) },
            onTaskSelected: { task in openDrawer(for: task) }
        )
        .padding(.top, 8)
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
    
    private func startCreatingTask(status: TaskStatus = .todo, dueDate: Date? = nil) {
        guard !isDrawerVisible else { return }
        
        pendingTaskDraft = TaskDraft(
            title: "",
            notes: "",
            status: status,
            priority: .medium,
            dueDate: dueDate,
            projectId: nil,
            areaId: nil,
            effort: nil
        )
        activeTask = nil
        isCreatingTask = true
        
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isDrawerVisible = true
        }
    }
    
    private func creationDrawerBinding() -> Binding<Bool> {
        Binding(
            get: { isDrawerVisible && isCreatingTask },
            set: { newValue in
                if !newValue {
                    pendingTaskDraft = nil
                    isCreatingTask = false
                }
                withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                    isDrawerVisible = newValue
                }
            }
        )
    }
    
    private func editDrawerBinding() -> Binding<Bool> {
        Binding(
            get: { isDrawerVisible && !isCreatingTask },
            set: { newValue in
                if !newValue {
                    activeTask = nil
                }
                withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                    isDrawerVisible = newValue
                }
            }
        )
    }
    
    private func commitNewTask(from draft: TaskDraft) {
        let normalizedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNotes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle: String
        if !normalizedTitle.isEmpty {
            resolvedTitle = normalizedTitle
        } else if !normalizedNotes.isEmpty {
            resolvedTitle = String(normalizedNotes.prefix(48))
        } else {
            resolvedTitle = "Untitled Task"
        }
        
        let task = Task(
            title: resolvedTitle,
            notes: normalizedNotes.isEmpty ? nil : draft.notes,
            status: draft.status,
            priority: draft.priority,
            dueDate: draft.dueDate,
            projectId: draft.projectId,
            areaId: draft.areaId,
            effort: draft.effort
        )
        task.linkedEntityIds = draft.linkedEntityIds
        task.linkedEntityTypes = draft.linkedEntityTypes
        modelContext.insert(task)
        try? modelContext.save()
        
        pendingTaskDraft = nil
        isCreatingTask = false
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isDrawerVisible = false
        }
    }
    
    private func apply(_ draft: TaskDraft, to task: Task) {
        let normalizedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNotes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !normalizedTitle.isEmpty {
            task.title = normalizedTitle
        } else if !normalizedNotes.isEmpty {
            task.title = String(normalizedNotes.prefix(48))
        } else {
            task.title = "Untitled Task"
        }
        
        task.notes = normalizedNotes.isEmpty ? nil : draft.notes
        task.status = draft.status
        task.priority = draft.priority
        task.dueDate = draft.dueDate
        task.projectId = draft.projectId
        task.areaId = draft.areaId
        task.effort = draft.effort
        task.linkedEntityIds = draft.linkedEntityIds
        task.linkedEntityTypes = draft.linkedEntityTypes
        task.updatedAt = Date()
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
            targetObjectType: "task",
            shouldAutoStart: true
        )
        
        NotificationCenter.default.post(name: .startPendingFocusSession, object: params)
        NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.focusMode)
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

    private func handleTaskMove(_ task: Task, to section: TaskSectionType) {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        
        switch section {
        case .today:
            task.dueDate = startOfToday
            if task.status == .done { task.status = .todo }
        case .nextUp:
            task.dueDate = calendar.date(byAdding: .day, value: 2, to: startOfToday)
            if task.status == .done { task.status = .todo }
        case .later:
            task.dueDate = calendar.date(byAdding: .day, value: 7, to: startOfToday)
            if task.status == .done { task.status = .todo }
        case .completed:
            task.status = .done
            task.completedAt = Date()
        }
        task.updatedAt = Date()
        try? modelContext.save()
    }
    
    private func persistTaskOrder(_ tasks: [Task], in section: TaskSectionType) {
        let base = Date()
        for (offset, task) in tasks.enumerated() {
            task.updatedAt = base.addingTimeInterval(Double(tasks.count - offset))
        }
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
    let onMoveTaskToSection: (Task, UnifiedTasksView.TaskSectionType) -> Void
    let onReorderTasks: ([Task], UnifiedTasksView.TaskSectionType) -> Void
    let fetchTaskByID: (UUID) -> Task?
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @State private var orderedTasks: [Task]
    @State private var draggingTaskID: UUID?
    @State private var dropTargetTaskID: UUID?
    @State private var dragSourceSection: UnifiedTasksView.TaskSectionType?
    @State private var isSectionDropTarget = false
    
    init(
        section: UnifiedTasksView.TaskSection,
        projects: [Project],
        areas: [Area],
        focusedTaskIndex: Binding<Int?>,
        onToggleCollapse: @escaping () -> Void,
        onEdit: @escaping (Task) -> Void,
        onDuplicate: @escaping (Task) -> Void,
        onArchive: @escaping (Task) -> Void,
        onDelete: @escaping (Task) -> Void,
        onRequestFocus: @escaping (Task) -> Void,
        onMoveTaskToSection: @escaping (Task, UnifiedTasksView.TaskSectionType) -> Void,
        onReorderTasks: @escaping ([Task], UnifiedTasksView.TaskSectionType) -> Void,
        fetchTaskByID: @escaping (UUID) -> Task?
    ) {
        self.section = section
        self.projects = projects
        self.areas = areas
        self._focusedTaskIndex = focusedTaskIndex
        self.onToggleCollapse = onToggleCollapse
        self.onEdit = onEdit
        self.onDuplicate = onDuplicate
        self.onArchive = onArchive
        self.onDelete = onDelete
        self.onRequestFocus = onRequestFocus
        self.onMoveTaskToSection = onMoveTaskToSection
        self.onReorderTasks = onReorderTasks
        self.fetchTaskByID = fetchTaskByID
        _orderedTasks = State(initialValue: section.tasks)
    }
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 26) {
            VStack(alignment: .leading, spacing: 16) {
            sectionHeader
                GlassDivider()
                    .padding(.vertical, 4)
            taskCardsSection
        }
            .padding(24)
            .onChange(of: section.tasks.map(\.id)) { _ in
                orderedTasks = section.tasks
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(glassColorSystem.emotionalAccent().opacity(isSectionDropTarget ? 0.28 : 0),
                        lineWidth: isSectionDropTarget ? 1.4 : 0)
                .animation(.easeInOut(duration: 0.18), value: isSectionDropTarget)
        )
        .onDrop(
            of: [.text],
            delegate: TaskListDropDelegate(
                targetTask: nil,
                tasks: $orderedTasks,
                draggingTaskID: $draggingTaskID,
                dropTargetTaskID: $dropTargetTaskID,
                dragSourceSection: $dragSourceSection,
                section: section.type,
                isSectionDropTarget: $isSectionDropTarget,
                fetchTask: fetchTaskByID,
                onReorder: { reordered in
                    orderedTasks = reordered
                    onReorderTasks(reordered, section.type)
                },
                onMoveToSection: { movedTask in
                    onMoveTaskToSection(movedTask, section.type)
                }
            )
        )
    }
    
    private var sectionHeader: some View {
            Button(action: onToggleCollapse) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.kosmicBlue.opacity(0.25), .kosmicPurple.opacity(0.22)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                        )
                    
                    Text(section.type.rawValue.prefix(1).uppercased())
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.type.rawValue)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.kosmicBlue, .kosmicPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("\(section.tasks.count) \(section.tasks.count == 1 ? "task" : "tasks")")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                    
                    Image(systemName: section.isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
                }
            .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
    }
            
    @ViewBuilder
    private var taskCardsSection: some View {
            if !section.isCollapsed {
            VStack(spacing: 14) {
                ForEach(Array(orderedTasks.enumerated()), id: \.element.id) { index, task in
                    taskCard(for: task, at: index)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        } else {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.kosmicPurple.opacity(0.7))
                Text("Collapsed — tap to reveal tasks in this group.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 6)
            .transition(.opacity)
        }
    }
    
    private func taskCard(for task: Task, at index: Int) -> some View {
                        let project = projects.first(where: { $0.id == task.projectId })
                        let area = areas.first(where: { $0.id == task.areaId })
                        let metrics = TaskFocusMetrics.defaultMetrics(for: task)
                        
        return TaskCardV2(
                            task: task,
                            project: project,
                            area: area,
                            metrics: metrics,
                            onEdit: { onEdit(task) },
                            onDuplicate: { onDuplicate(task) },
                            onArchive: { onArchive(task) },
                            onDelete: { onDelete(task) },
            onRequestFocus: { onRequestFocus($0) },
            isBeingDragged: draggingTaskID == task.id,
            isDropTarget: dropTargetTaskID == task.id
                        )
                        .id("task-\(task.id)")
        .onDrag {
            dragSourceSection = section.type
            draggingTaskID = task.id
            dropTargetTaskID = task.id
            return NSItemProvider(object: task.id.uuidString as NSString)
        }
        .onDrop(
            of: [.text],
            delegate: TaskListDropDelegate(
                targetTask: task,
                tasks: $orderedTasks,
                draggingTaskID: $draggingTaskID,
                dropTargetTaskID: $dropTargetTaskID,
                dragSourceSection: $dragSourceSection,
                section: section.type,
                isSectionDropTarget: $isSectionDropTarget,
                fetchTask: fetchTaskByID,
                onReorder: { reordered in
                    orderedTasks = reordered
                    onReorderTasks(reordered, section.type)
                },
                onMoveToSection: { movedTask in
                    onMoveTaskToSection(movedTask, section.type)
                }
            )
        )
    }
}

// MARK: - Focus Recap Banner

struct FocusRecapBanner: View {
    let streak: Int
    
    @State private var pulsePhase: CGFloat = 0
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 22) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.kosmicGreen.opacity(0.25), .kosmicBlue.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: .kosmicGreen.opacity(0.25), radius: 12, y: 6)
                    
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.kosmicGreen)
                }
            
                VStack(alignment: .leading, spacing: 6) {
                    Text("Momentum locked in.")
                        .font(.system(.headline, design: .rounded))
                    .foregroundColor(.primary)
                
                    Text("Every task is complete — focus streak at \(streak) day\(streak == 1 ? "" : "s").")
                        .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
                
                Text("Aurora applauds 🌟")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.kosmicPurple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
        .background(
                        Capsule()
                            .fill(Color.kosmicPurple.opacity(0.12))
        )
            }
            .padding(22)
        }
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

private struct TaskListDropDelegate: DropDelegate {
    let targetTask: Task?
    @Binding var tasks: [Task]
    @Binding var draggingTaskID: UUID?
    @Binding var dropTargetTaskID: UUID?
    @Binding var dragSourceSection: UnifiedTasksView.TaskSectionType?
    let section: UnifiedTasksView.TaskSectionType
    @Binding var isSectionDropTarget: Bool
    let fetchTask: (UUID) -> Task?
    let onReorder: ([Task]) -> Void
    let onMoveToSection: (Task) -> Void
    
    func validateDrop(info: DropInfo) -> Bool {
        true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggingID = draggingTaskID else { return }
        if dragSourceSection == section {
            guard let fromIndex = tasks.firstIndex(where: { $0.id == draggingID }) else { return }
            var toIndex = tasks.count - 1
            if let targetTask = targetTask,
               let index = tasks.firstIndex(where: { $0.id == targetTask.id }) {
                toIndex = index
            }
            if fromIndex != toIndex {
                withAnimation(.easeInOut(duration: 0.16)) {
                    let item = tasks.remove(at: fromIndex)
                    tasks.insert(item, at: toIndex)
                }
                dropTargetTaskID = targetTask?.id
            }
        } else {
            dropTargetTaskID = targetTask?.id
            isSectionDropTarget = targetTask == nil
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
    
    func dropExited(info: DropInfo) {
        dropTargetTaskID = nil
        isSectionDropTarget = false
    }
    
    func performDrop(info: DropInfo) -> Bool {
        defer {
            draggingTaskID = nil
            dropTargetTaskID = nil
            dragSourceSection = nil
            isSectionDropTarget = false
        }
        
        guard let draggingID = draggingTaskID else { return false }
        
        if dragSourceSection == section {
            onReorder(tasks)
            return true
        } else if let movedTask = fetchTask(draggingID) {
            if !tasks.contains(where: { $0.id == movedTask.id }) {
                withAnimation(.easeInOut(duration: 0.16)) {
                    if let targetTask = targetTask,
                       let index = tasks.firstIndex(where: { $0.id == targetTask.id }) {
                        tasks.insert(movedTask, at: index)
                    } else {
                        tasks.append(movedTask)
                    }
                }
            }
            onMoveToSection(movedTask)
            return true
        }
        
        return false
    }
    
    func dropSessionDidEnd(_ session: DropSession) {
        draggingTaskID = nil
        dropTargetTaskID = nil
        dragSourceSection = nil
        isSectionDropTarget = false
    }
}

// MARK: - Tasks Empty State View

struct TasksEmptyStateView: View {
    let filter: UnifiedTasksView.TaskFilter
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 24) {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.kosmicBlue.opacity(0.18), Color.kosmicPurple.opacity(0.18)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                        )
                    
            Image(systemName: iconName)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(.kosmicPurple)
                }
            
                VStack(spacing: 6) {
            Text(message)
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("No tasks found in this view right now.")
                        .font(.system(.caption, design: .rounded))
                .foregroundColor(.secondary)
                }
                
                Button {
                    NotificationCenter.default.post(name: .showCreateTask, object: nil)
                } label: {
                    Label("Capture a new task", systemImage: "plus.circle.fill")
                        .font(.system(.callout, design: .rounded).weight(.semibold))
        }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.kosmicPurple)
            }
        .frame(maxWidth: .infinity)
            .padding(30)
        }
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

