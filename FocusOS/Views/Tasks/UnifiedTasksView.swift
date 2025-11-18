//
//  UnifiedTasksView.swift
//  FocusOS
//
//  Tasks V2 - Unified view with sectioned grouping and focus orchestration
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers
import FocusOSShared
// Note: Area is defined in FocusOS/Models/Area.swift, not FocusOSShared

struct UnifiedTasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Query(sort: \FocusOSShared.Task.updatedAt, order: .reverse) private var allTasks: [FocusOSShared.Task]
    @Query private var allProjects: [FocusOSShared.Project]
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
    @State private var isFilterSortDrawerVisible = false
    @State private var isTasksSectionCollapsed = false
    @State private var isRemindersSectionCollapsed = false
    
    // Advanced filter state
    @State private var selectedProjectFilter: UUID?
    @State private var selectedAreaFilter: UUID?
    
    // Sort persistence per view mode
    @AppStorage("tasks.sort.list") private var listSortOption: String = TaskSortOption.dueDateAsc.rawValue
    @AppStorage("tasks.sort.board") private var boardSortOption: String = TaskSortOption.dueDateAsc.rawValue
    @AppStorage("tasks.sort.planner") private var plannerSortOption: String = TaskSortOption.dueDateAsc.rawValue
    @AppStorage("tasks.sort.gallery") private var gallerySortOption: String = TaskSortOption.dueDateAsc.rawValue
    
    private var currentSortOption: TaskSortOption {
        let rawValue: String
        switch selectedViewMode {
        case .list: rawValue = listSortOption
        case .board: rawValue = boardSortOption
        case .planner: rawValue = plannerSortOption
        case .gallery: rawValue = gallerySortOption
        }
        return TaskSortOption(rawValue: rawValue) ?? .dueDateAsc
    }
    
    enum TaskFilter: String, CaseIterable, Identifiable {
        // Basic filters
        case all = "All"
        case today = "Today"
        case upcoming = "Upcoming"
        case completed = "Completed"
        
        // Priority filters
        case highPriority = "High Priority"
        case mediumPriority = "Medium Priority"
        case lowPriority = "Low Priority"
        
        // Status filters
        case todo = "To Do"
        case inProgress = "In Progress"
        case cancelled = "Cancelled"
        
        // Relationship filters
        case unattached = "Unattached"
        case hasProject = "Has Project"
        case hasArea = "Has Area"
        
        // Due date filters
        case withDueDate = "With Due Date"
        case withoutDueDate = "Without Due Date"
        case overdue = "Overdue"
        case dueThisWeek = "Due This Week"
        case dueThisMonth = "Due This Month"
        
        // Effort filters
        case smallEffort = "Small Effort"
        case mediumEffort = "Medium Effort"
        case largeEffort = "Large Effort"
        case noEffort = "No Effort"
        
        // Source filters
        case reminders = "Reminders"
        case tasksOnly = "Tasks Only"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .today: return "sun.max.fill"
            case .upcoming: return "calendar"
            case .completed: return "checkmark.circle.fill"
            case .highPriority: return "exclamationmark.circle.fill"
            case .mediumPriority: return "exclamationmark.circle"
            case .lowPriority: return "minus.circle"
            case .todo: return "circle"
            case .inProgress: return "arrow.triangle.2.circlepath"
            case .cancelled: return "xmark.circle"
            case .unattached: return "link.slash"
            case .hasProject: return "folder"
            case .hasArea: return "square.grid.2x2"
            case .withDueDate: return "calendar.badge.plus"
            case .withoutDueDate: return "calendar.badge.minus"
            case .overdue: return "exclamationmark.triangle.fill"
            case .dueThisWeek: return "calendar.badge.clock"
            case .dueThisMonth: return "calendar"
            case .smallEffort: return "gauge.low"
            case .mediumEffort: return "gauge.medium"
            case .largeEffort: return "gauge.high"
            case .noEffort: return "gauge"
            case .reminders: return "bell.fill"
            case .tasksOnly: return "checklist"
            }
        }
        
        var category: TaskFilterCategory {
            switch self {
            case .all, .today, .upcoming, .completed:
                return .basic
            case .highPriority, .mediumPriority, .lowPriority:
                return .priority
            case .todo, .inProgress, .cancelled:
                return .status
            case .unattached, .hasProject, .hasArea:
                return .relationship
            case .withDueDate, .withoutDueDate, .overdue, .dueThisWeek, .dueThisMonth:
                return .dueDate
            case .smallEffort, .mediumEffort, .largeEffort, .noEffort:
                return .effort
            case .reminders, .tasksOnly:
                return .source
            }
        }
        
        static var categories: [TaskFilterCategory] {
            [.basic, .priority, .status, .relationship, .dueDate, .effort, .source]
        }
        
        static func filters(for category: TaskFilterCategory) -> [TaskFilter] {
            allCases.filter { $0.category == category }
        }
    }
    
    enum TaskFilterCategory: String, CaseIterable {
        case basic = "Basic"
        case priority = "Priority"
        case status = "Status"
        case relationship = "Relationship"
        case dueDate = "Due Date"
        case effort = "Effort"
        case source = "Source"
        
        var icon: String {
            switch self {
            case .basic: return "list.bullet"
            case .priority: return "exclamationmark.circle"
            case .status: return "checkmark.circle"
            case .relationship: return "folder"
            case .dueDate: return "calendar"
            case .effort: return "gauge"
            case .source: return "square.stack.3d.up"
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
    
    // Separate tasks and reminders
    private var allReminders: [Task] {
        allTasks.filter { $0.externalSource == "apple_reminders" }
    }
    
    private var allRegularTasks: [Task] {
        allTasks.filter { $0.externalSource != "apple_reminders" }
    }
    
    private var filteredTasks: [Task] {
        // First, determine which source to filter
        let sourceFiltered: [Task]
        switch selectedFilter {
        case .reminders:
            sourceFiltered = allReminders
        case .tasksOnly:
            sourceFiltered = allRegularTasks
        default:
            sourceFiltered = allTasks
        }
        
        var filtered = sourceFiltered
        
        switch selectedFilter {
        // Basic filters
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
        
        // Priority filters
        case .highPriority:
            filtered = filtered.filter { $0.priority == .high }
        case .mediumPriority:
            filtered = filtered.filter { $0.priority == .medium }
        case .lowPriority:
            filtered = filtered.filter { $0.priority == .low }
        
        // Status filters
        case .todo:
            filtered = filtered.filter { $0.status == .todo }
        case .inProgress:
            filtered = filtered.filter { $0.status == .inProgress }
        case .cancelled:
            filtered = filtered.filter { $0.status == .cancelled }
        
        // Relationship filters
        case .unattached:
            filtered = filtered.filter { $0.projectId == nil && $0.areaId == nil }
        case .hasProject:
            filtered = filtered.filter { $0.projectId != nil }
        case .hasArea:
            filtered = filtered.filter { $0.areaId != nil }
        
        // Due date filters
        case .withDueDate:
            filtered = filtered.filter { $0.dueDate != nil }
        case .withoutDueDate:
            filtered = filtered.filter { $0.dueDate == nil }
        case .overdue:
            filtered = filtered.filter { task in
                guard let due = task.dueDate else { return false }
                return due < Date() && task.status != .done
            }
        case .dueThisWeek:
            filtered = filtered.filter { task in
                guard let due = task.dueDate else { return false }
                let days = Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0
                return days >= 0 && days <= 7 && task.status != .done
            }
        case .dueThisMonth:
            filtered = filtered.filter { task in
                guard let due = task.dueDate else { return false }
                let days = Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0
                return days >= 0 && days <= 30 && task.status != .done
            }
        
        // Effort filters
        case .smallEffort:
            filtered = filtered.filter { $0.effort?.lowercased() == "small" }
        case .mediumEffort:
            filtered = filtered.filter { $0.effort?.lowercased() == "medium" }
        case .largeEffort:
            filtered = filtered.filter { $0.effort?.lowercased() == "large" }
        case .noEffort:
            filtered = filtered.filter { $0.effort == nil || $0.effort?.isEmpty == true }
        
        // Source filters (already handled above, but keep for completeness)
        case .reminders, .tasksOnly:
            break
        }
        
        // Apply advanced filters (project/area selection)
        if let projectId = selectedProjectFilter {
            filtered = filtered.filter { $0.projectId == projectId }
        }
        if let areaId = selectedAreaFilter {
            filtered = filtered.filter { $0.areaId == areaId }
        }
        
        return filtered
    }
    
    // Separate filtered tasks and reminders
    private var filteredRegularTasks: [Task] {
        filteredTasks.filter { $0.externalSource != "apple_reminders" }
    }
    
    private var filteredReminders: [Task] {
        filteredTasks.filter { $0.externalSource == "apple_reminders" }
    }
    
    private var sortedFilteredTasks: [Task] {
        sortTasks(filteredTasks, by: currentSortOption)
    }
    
    private var groupedSections: [TaskSection] {
        let today = Calendar.current.startOfDay(for: Date())
        let threeDaysFromNow = Calendar.current.date(byAdding: .day, value: 3, to: today)!
        
        let todayTasks = sortedFilteredTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return Calendar.current.isDateInToday(due) && task.status != .done
        }
        
        let nextUpTasks = sortedFilteredTasks.filter { task in
            guard let due = task.dueDate else { return false }
            let days = Calendar.current.dateComponents([.day], from: today, to: due).day ?? 0
            return days > 0 && days <= 3 && task.status != .done && !Calendar.current.isDateInToday(due)
        }
        
        let laterTasks = sortedFilteredTasks.filter { task in
            if task.status == .done { return false }
            guard let due = task.dueDate else { return true }
            let days = Calendar.current.dateComponents([.day], from: today, to: due).day ?? 0
            return days > 3 || days < 0
        }
        
        let completedTasks = sortedFilteredTasks.filter { $0.status == .done }
        
        return [
            TaskSection(type: .today, tasks: todayTasks, isCollapsed: !expandedSections.contains(.today)),
            TaskSection(type: .nextUp, tasks: nextUpTasks, isCollapsed: !expandedSections.contains(.nextUp)),
            TaskSection(type: .later, tasks: laterTasks, isCollapsed: !expandedSections.contains(.later)),
            TaskSection(type: .completed, tasks: completedTasks, isCollapsed: !expandedSections.contains(.completed))
        ]
    }
    
    // Separate grouped sections for reminders
    private var groupedReminderSections: [TaskSection] {
        let sortedReminders = sortTasks(filteredReminders, by: currentSortOption)
        let today = Calendar.current.startOfDay(for: Date())
        
        let todayReminders = sortedReminders.filter { task in
            guard let due = task.dueDate else { return false }
            return Calendar.current.isDateInToday(due) && task.status != .done
        }
        
        let nextUpReminders = sortedReminders.filter { task in
            guard let due = task.dueDate else { return false }
            let days = Calendar.current.dateComponents([.day], from: today, to: due).day ?? 0
            return days > 0 && days <= 3 && task.status != .done && !Calendar.current.isDateInToday(due)
        }
        
        let laterReminders = sortedReminders.filter { task in
            if task.status == .done { return false }
            guard let due = task.dueDate else { return true }
            let days = Calendar.current.dateComponents([.day], from: today, to: due).day ?? 0
            return days > 3 || days < 0
        }
        
        let completedReminders = sortedReminders.filter { $0.status == .done }
        
        return [
            TaskSection(type: .today, tasks: todayReminders, isCollapsed: !expandedSections.contains(.today)),
            TaskSection(type: .nextUp, tasks: nextUpReminders, isCollapsed: !expandedSections.contains(.nextUp)),
            TaskSection(type: .later, tasks: laterReminders, isCollapsed: !expandedSections.contains(.later)),
            TaskSection(type: .completed, tasks: completedReminders, isCollapsed: !expandedSections.contains(.completed))
        ]
    }
    
    // Grouped sections for regular tasks only
    private var groupedTaskSections: [TaskSection] {
        let sortedTasks = sortTasks(filteredRegularTasks, by: currentSortOption)
        let today = Calendar.current.startOfDay(for: Date())
        
        let todayTasks = sortedTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return Calendar.current.isDateInToday(due) && task.status != .done
        }
        
        let nextUpTasks = sortedTasks.filter { task in
            guard let due = task.dueDate else { return false }
            let days = Calendar.current.dateComponents([.day], from: today, to: due).day ?? 0
            return days > 0 && days <= 3 && task.status != .done && !Calendar.current.isDateInToday(due)
        }
        
        let laterTasks = sortedTasks.filter { task in
            if task.status == .done { return false }
            guard let due = task.dueDate else { return true }
            let days = Calendar.current.dateComponents([.day], from: today, to: due).day ?? 0
            return days > 3 || days < 0
        }
        
        let completedTasks = sortedTasks.filter { $0.status == .done }
        
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
            .opacity(isDrawerVisible || isFilterSortDrawerVisible ? 0 : 1)
            
            if isFilterSortDrawerVisible {
                TaskFilterSortDrawer(
                    isPresented: $isFilterSortDrawerVisible,
                    selectedFilter: $selectedFilter,
                    selectedSort: Binding(
                        get: { currentSortOption },
                        set: { newSort in
                            let rawValue = newSort.rawValue
                            switch selectedViewMode {
                            case .list: listSortOption = rawValue
                            case .board: boardSortOption = rawValue
                            case .planner: plannerSortOption = rawValue
                            case .gallery: gallerySortOption = rawValue
                            }
                        }
                    ),
                    selectedProjectFilter: $selectedProjectFilter,
                    selectedAreaFilter: $selectedAreaFilter,
                    allProjects: allProjects,
                    allAreas: allAreas
                )
                .transition(.move(edge: .trailing))
            }
            
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
        .onChange(of: selectedViewMode) { _, _ in
            // Sort option is automatically updated via currentSortOption computed property
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
                    
                    Button {
                        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                            isFilterSortDrawerVisible = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 14, weight: .medium))
                            Text("All Options")
                                .font(.system(.caption, design: .rounded).weight(.medium))
                        }
                        .foregroundStyle(glassColorSystem.textPrimary())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(glassColorSystem.cardColor().opacity(0.4))
                                .overlay(
                                    Capsule()
                                        .stroke(glassColorSystem.borderColor().opacity(0.5), lineWidth: 0.8)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                GlassDivider()
                
                // Most common filters (3 max)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Filters")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                    
                    HStack(spacing: 10) {
                        quickFilterButton(.all)
                        quickFilterButton(.today)
                        quickFilterButton(.upcoming)
                    }
                }
                
                GlassDivider()
                
                // Most common sorts (3 max)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Sort")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                    
                    HStack(spacing: 10) {
                        quickSortButton(.dueDateAsc)
                        quickSortButton(.priorityHighToLow)
                        quickSortButton(.updatedDesc)
                    }
                }
            }
            .padding(24)
        }
    }
    
    @ViewBuilder
    private func quickFilterButton(_ filter: TaskFilter) -> some View {
        Button {
            withAnimation(GlassMotion.Easing.spring) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.system(size: 11, weight: .medium))
                Text(filter.rawValue)
                    .font(.system(.caption, design: .rounded))
            }
            .foregroundStyle(selectedFilter == filter ? glassColorSystem.textPrimary() : glassColorSystem.textSecondary())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selectedFilter == filter ? glassColorSystem.cardColor().opacity(0.5) : glassColorSystem.backgroundSecondary().opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(selectedFilter == filter ? glassColorSystem.emotionalAccent().opacity(0.4) : glassColorSystem.borderColor().opacity(0.3), lineWidth: selectedFilter == filter ? 1.0 : 0.6)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func quickSortButton(_ sort: TaskSortOption) -> some View {
        Button {
            let rawValue = sort.rawValue
            switch selectedViewMode {
            case .list: listSortOption = rawValue
            case .board: boardSortOption = rawValue
            case .planner: plannerSortOption = rawValue
            case .gallery: gallerySortOption = rawValue
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: sort.icon)
                    .font(.system(size: 11, weight: .medium))
                Text(sort.displayName)
                    .font(.system(.caption, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(currentSortOption == sort ? glassColorSystem.textPrimary() : glassColorSystem.textSecondary())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(currentSortOption == sort ? glassColorSystem.cardColor().opacity(0.5) : glassColorSystem.backgroundSecondary().opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(currentSortOption == sort ? glassColorSystem.emotionalAccent().opacity(0.4) : glassColorSystem.borderColor().opacity(0.3), lineWidth: currentSortOption == sort ? 1.0 : 0.6)
                    )
            )
        }
        .buttonStyle(.plain)
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
            
            // Show tasks and reminders separately based on filter
            if selectedFilter == .reminders {
                // Show only reminders
                remindersSection
            } else if selectedFilter == .tasksOnly {
                // Show only regular tasks
                tasksSection
            } else {
                // Show both sections
                tasksSection
                remindersSection
            }
            
            if sortedFilteredTasks.isEmpty {
                TasksEmptyStateView(filter: selectedFilter)
                    .transition(.opacity)
            }
        }
    }
    
    @ViewBuilder
    private var tasksSection: some View {
        if !filteredRegularTasks.isEmpty || selectedFilter == .tasksOnly {
            VStack(alignment: .leading, spacing: 20) {
                // Collapsible section header for tasks
                Button(action: {
                    withAnimation(GlassMotion.Easing.spring) {
                        isTasksSectionCollapsed.toggle()
                    }
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.kosmicBlue.opacity(0.25), .kosmicBlue.opacity(0.22)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 38, height: 38)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                                )
                            
                            Image(systemName: "checklist")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.kosmicBlue)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tasks")
                                .font(.system(.title3, design: .rounded).weight(.semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.kosmicBlue, .kosmicBlue.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text("\(filteredRegularTasks.count) \(filteredRegularTasks.count == 1 ? "task" : "tasks")")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: isTasksSectionCollapsed ? "chevron.right" : "chevron.down")
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
                .padding(.horizontal, 4)
                
                if !isTasksSectionCollapsed {
                    ForEach(groupedTaskSections) { section in
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
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.kosmicBlue.opacity(0.7))
                        Text("Collapsed — tap to reveal tasks.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                    .transition(.opacity)
                }
            }
        }
    }
    
    @ViewBuilder
    private var remindersSection: some View {
        if !filteredReminders.isEmpty || selectedFilter == .reminders {
            VStack(alignment: .leading, spacing: 20) {
                // Collapsible section header for reminders
                Button(action: {
                    withAnimation(GlassMotion.Easing.spring) {
                        isRemindersSectionCollapsed.toggle()
                    }
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.kosmicPurple.opacity(0.25), .kosmicPurple.opacity(0.22)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 38, height: 38)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                                )
                            
                            Image(systemName: "bell.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.kosmicPurple)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reminders")
                                .font(.system(.title3, design: .rounded).weight(.semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.kosmicPurple, .kosmicPurple.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text("\(filteredReminders.count) \(filteredReminders.count == 1 ? "reminder" : "reminders")")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: isRemindersSectionCollapsed ? "chevron.right" : "chevron.down")
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
                .padding(.horizontal, 4)
                
                if !isRemindersSectionCollapsed {
                    ForEach(groupedReminderSections) { section in
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
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.kosmicPurple.opacity(0.7))
                        Text("Collapsed — tap to reveal reminders.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                    .transition(.opacity)
                }
                        }
                    }
    }

    private var boardView: some View {
        VStack(alignment: .leading, spacing: 24) {
            if selectedFilter != .reminders && !filteredRegularTasks.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "checklist")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.kosmicBlue)
                        Text("Tasks")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(glassColorSystem.textPrimary())
                    }
                    .padding(.horizontal, 4)
                    
        TaskBoardView(
                        tasks: sortTasks(filteredRegularTasks, by: currentSortOption),
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
                }
            }
            
            if selectedFilter != .tasksOnly && !filteredReminders.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.kosmicPurple)
                        Text("Reminders")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(glassColorSystem.textPrimary())
                    }
                    .padding(.horizontal, 4)
                    
                    TaskBoardView(
                        tasks: sortTasks(filteredReminders, by: currentSortOption),
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
                }
            }
        }
        .padding(.top, 8)
    }
    
    private var plannerView: some View {
        VStack(alignment: .leading, spacing: 24) {
            if selectedFilter != .reminders && !filteredRegularTasks.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "checklist")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.kosmicBlue)
                        Text("Tasks")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(glassColorSystem.textPrimary())
                    }
                    .padding(.horizontal, 4)
                    
        TaskPlannerView(
                        tasks: sortTasks(filteredRegularTasks, by: currentSortOption),
            projects: allProjects,
            areas: allAreas,
            onTaskSelected: { task in openDrawer(for: task) },
            onStartFocus: { task in requestFocusSession(for: task) }
        )
                }
            }
            
            if selectedFilter != .tasksOnly && !filteredReminders.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.kosmicPurple)
                        Text("Reminders")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(glassColorSystem.textPrimary())
                    }
                    .padding(.horizontal, 4)
                    
                    TaskPlannerView(
                        tasks: sortTasks(filteredReminders, by: currentSortOption),
                        projects: allProjects,
                        areas: allAreas,
                        onTaskSelected: { task in openDrawer(for: task) },
                        onStartFocus: { task in requestFocusSession(for: task) }
                    )
                }
            }
        }
        .padding(.vertical, 4)
                }
    
    private var galleryView: some View {
        VStack(alignment: .leading, spacing: 24) {
            if selectedFilter != .reminders && !filteredRegularTasks.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "checklist")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.kosmicBlue)
                        Text("Tasks")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(glassColorSystem.textPrimary())
                    }
                    .padding(.horizontal, 4)
                    
        TaskGalleryView(
                        tasks: sortTasks(filteredRegularTasks, by: currentSortOption),
            projects: allProjects,
            areas: allAreas,
            selectionMode: isSelectionMode,
            selectedTaskIDs: selectedTaskIDs,
            onSelectionToggle: { task in toggleTaskSelection(task) },
            onTaskSelected: { task in openDrawer(for: task) }
        )
                }
            }
            
            if selectedFilter != .tasksOnly && !filteredReminders.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.kosmicPurple)
                        Text("Reminders")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(glassColorSystem.textPrimary())
                    }
                    .padding(.horizontal, 4)
                    
                    TaskGalleryView(
                        tasks: sortTasks(filteredReminders, by: currentSortOption),
                        projects: allProjects,
                        areas: allAreas,
                        selectionMode: isSelectionMode,
                        selectedTaskIDs: selectedTaskIDs,
                        onSelectionToggle: { task in toggleTaskSelection(task) },
                        onTaskSelected: { task in openDrawer(for: task) }
                    )
                }
            }
        }
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
    
    private func updateSortOption(_ option: TaskSortOption) {
        switch selectedViewMode {
        case .list:
            listSortOption = option.rawValue
        case .board:
            boardSortOption = option.rawValue
        case .planner:
            plannerSortOption = option.rawValue
        case .gallery:
            gallerySortOption = option.rawValue
        }
    }
    
    private func sortTasks(_ tasks: [Task], by option: TaskSortOption) -> [Task] {
        var sorted = tasks
        
        switch option {
        // Date/Time sorts
        case .dueDateAsc:
            sorted.sort { task1, task2 in
                guard let date1 = task1.dueDate else { return false }
                guard let date2 = task2.dueDate else { return true }
                return date1 < date2
            }
        case .dueDateDesc:
            sorted.sort { task1, task2 in
                guard let date1 = task1.dueDate else { return true }
                guard let date2 = task2.dueDate else { return false }
                return date1 > date2
            }
        case .createdAsc:
            sorted.sort { $0.createdAt < $1.createdAt }
        case .createdDesc:
            sorted.sort { $0.createdAt > $1.createdAt }
        case .updatedAsc:
            sorted.sort { $0.updatedAt < $1.updatedAt }
        case .updatedDesc:
            sorted.sort { $0.updatedAt > $1.updatedAt }
        case .completedAsc:
            sorted.sort { task1, task2 in
                guard let date1 = task1.completedAt else { return false }
                guard let date2 = task2.completedAt else { return true }
                return date1 < date2
            }
        case .completedDesc:
            sorted.sort { task1, task2 in
                guard let date1 = task1.completedAt else { return true }
                guard let date2 = task2.completedAt else { return false }
                return date1 > date2
            }
        
        // Priority sorts
        case .priorityHighToLow:
            sorted.sort { task1, task2 in
                let priority1 = task1.priority
                let priority2 = task2.priority
                if priority1 == priority2 {
                    return task1.updatedAt > task2.updatedAt
                }
                let order: [TaskPriority] = [.high, .medium, .low]
                let index1 = order.firstIndex(of: priority1) ?? 999
                let index2 = order.firstIndex(of: priority2) ?? 999
                return index1 < index2
            }
        case .priorityLowToHigh:
            sorted.sort { task1, task2 in
                let priority1 = task1.priority
                let priority2 = task2.priority
                if priority1 == priority2 {
                    return task1.updatedAt > task2.updatedAt
                }
                let order: [TaskPriority] = [.low, .medium, .high]
                let index1 = order.firstIndex(of: priority1) ?? 999
                let index2 = order.firstIndex(of: priority2) ?? 999
                return index1 < index2
            }
        
        // Status sorts
        case .statusTodoFirst:
            sorted.sort { task1, task2 in
                let status1 = task1.status
                let status2 = task2.status
                if status1 == status2 {
                    return task1.updatedAt > task2.updatedAt
                }
                let order: [TaskStatus] = [.todo, .inProgress, .done, .cancelled]
                let index1 = order.firstIndex(of: status1) ?? 999
                let index2 = order.firstIndex(of: status2) ?? 999
                return index1 < index2
            }
        case .statusDoneFirst:
            sorted.sort { task1, task2 in
                let status1 = task1.status
                let status2 = task2.status
                if status1 == status2 {
                    return task1.updatedAt > task2.updatedAt
                }
                let order: [TaskStatus] = [.done, .inProgress, .todo, .cancelled]
                let index1 = order.firstIndex(of: status1) ?? 999
                let index2 = order.firstIndex(of: status2) ?? 999
                return index1 < index2
            }
        
        // Relationship sorts
        case .byProject:
            sorted.sort { task1, task2 in
                if task1.projectId == task2.projectId {
                    return task1.updatedAt > task2.updatedAt
                }
                if task1.projectId == nil { return false }
                if task2.projectId == nil { return true }
                return task1.projectId!.uuidString < task2.projectId!.uuidString
            }
        case .byArea:
            sorted.sort { task1, task2 in
                if task1.areaId == task2.areaId {
                    return task1.updatedAt > task2.updatedAt
                }
                if task1.areaId == nil { return false }
                if task2.areaId == nil { return true }
                return task1.areaId!.uuidString < task2.areaId!.uuidString
            }
        case .unattachedFirst:
            sorted.sort { task1, task2 in
                let task1Attached = task1.projectId != nil || task1.areaId != nil
                let task2Attached = task2.projectId != nil || task2.areaId != nil
                if task1Attached == task2Attached {
                    return task1.updatedAt > task2.updatedAt
                }
                return !task1Attached && task2Attached
            }
        case .unattachedLast:
            sorted.sort { task1, task2 in
                let task1Attached = task1.projectId != nil || task1.areaId != nil
                let task2Attached = task2.projectId != nil || task2.areaId != nil
                if task1Attached == task2Attached {
                    return task1.updatedAt > task2.updatedAt
                }
                return task1Attached && !task2Attached
            }
        
        // Effort sorts
        case .effortSmallToLarge:
            sorted.sort { task1, task2 in
                let effort1 = parseEffort(task1.effort)
                let effort2 = parseEffort(task2.effort)
                if effort1 == effort2 {
                    return task1.updatedAt > task2.updatedAt
                }
                return effort1 < effort2
            }
        case .effortLargeToSmall:
            sorted.sort { task1, task2 in
                let effort1 = parseEffort(task1.effort)
                let effort2 = parseEffort(task2.effort)
                if effort1 == effort2 {
                    return task1.updatedAt > task2.updatedAt
                }
                return effort1 > effort2
            }
        
        // Alphabetical sorts
        case .titleAsc:
            sorted.sort { task1, task2 in
                task1.title.localizedCaseInsensitiveCompare(task2.title) == .orderedAscending
            }
        case .titleDesc:
            sorted.sort { task1, task2 in
                task1.title.localizedCaseInsensitiveCompare(task2.title) == .orderedDescending
            }
        
        // Combined sorts
        case .priorityThenDueDate:
            sorted.sort { task1, task2 in
                let priority1 = task1.priority
                let priority2 = task2.priority
                if priority1 != priority2 {
                    let order: [TaskPriority] = [.high, .medium, .low]
                    let index1 = order.firstIndex(of: priority1) ?? 999
                    let index2 = order.firstIndex(of: priority2) ?? 999
                    return index1 < index2
                }
                guard let date1 = task1.dueDate else { return false }
                guard let date2 = task2.dueDate else { return true }
                return date1 < date2
            }
        case .dueDateThenPriority:
            sorted.sort { task1, task2 in
                guard let date1 = task1.dueDate else { return false }
                guard let date2 = task2.dueDate else { return true }
                if date1 != date2 {
                    return date1 < date2
                }
                let order: [TaskPriority] = [.high, .medium, .low]
                let index1 = order.firstIndex(of: task1.priority) ?? 999
                let index2 = order.firstIndex(of: task2.priority) ?? 999
                return index1 < index2
            }
        case .statusThenDueDate:
            sorted.sort { task1, task2 in
                let status1 = task1.status
                let status2 = task2.status
                if status1 != status2 {
                    let order: [TaskStatus] = [.todo, .inProgress, .done, .cancelled]
                    let index1 = order.firstIndex(of: status1) ?? 999
                    let index2 = order.firstIndex(of: status2) ?? 999
                    return index1 < index2
                }
                guard let date1 = task1.dueDate else { return false }
                guard let date2 = task2.dueDate else { return true }
                return date1 < date2
            }
        }
        
        return sorted
    }
    
    private func parseEffort(_ effort: String?) -> Int {
        guard let effort = effort?.lowercased() else { return 1 }
        switch effort {
        case "small": return 1
        case "medium": return 2
        case "large": return 3
        default: return 1
        }
    }
    
    @ViewBuilder
    private func filterCategoryMenu(for category: TaskFilterCategory) -> some View {
        let filters = TaskFilter.filters(for: category)
        let currentFilterInCategory = filters.first { $0 == selectedFilter }
        let isActive = currentFilterInCategory != nil
        
        Menu {
            ForEach(filters) { filter in
                Button {
                    withAnimation(GlassMotion.Easing.spring) {
                        selectedFilter = filter
                        // Clear advanced filters when switching away from relationship category
                        if filter.category != .relationship {
                            selectedProjectFilter = nil
                            selectedAreaFilter = nil
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: filter.icon)
                            .font(.system(size: 12, weight: .medium))
                        Text(filter.rawValue)
                        Spacer()
                        if selectedFilter == filter {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isActive ? glassColorSystem.textPrimary() : glassColorSystem.textSecondary())
                
                if let current = currentFilterInCategory {
                    Text(current.rawValue)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                        .lineLimit(1)
                } else {
                    Text(category.rawValue)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                        .lineLimit(1)
                }
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(glassColorSystem.textSecondary().opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isActive ? glassColorSystem.cardColor().opacity(0.5) : glassColorSystem.backgroundSecondary().opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isActive ? glassColorSystem.emotionalAccent().opacity(0.4) : glassColorSystem.borderColor().opacity(0.55), lineWidth: isActive ? 1.0 : 0.6)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private var projectFilterDropdown: some View {
        Menu {
            Button {
                selectedProjectFilter = nil
            } label: {
                HStack {
                    Text("All Projects")
                    if selectedProjectFilter == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            ForEach(allProjects) { project in
                Button {
                    selectedProjectFilter = project.id
                } label: {
                    HStack {
                        Text(project.title)
                        Spacer()
                        if selectedProjectFilter == project.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.system(size: 11, weight: .medium))
                Text(selectedProjectFilter != nil ? allProjects.first(where: { $0.id == selectedProjectFilter })?.title ?? "Project" : "All Projects")
                    .font(.system(.caption, design: .rounded))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(glassColorSystem.backgroundSecondary().opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(glassColorSystem.borderColor().opacity(0.55), lineWidth: 0.6)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private var areaFilterDropdown: some View {
        Menu {
            Button {
                selectedAreaFilter = nil
            } label: {
                HStack {
                    Text("All Areas")
                    if selectedAreaFilter == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            ForEach(allAreas) { area in
                Button {
                    selectedAreaFilter = area.id
                } label: {
                    HStack {
                        Text(area.title)
                        Spacer()
                        if selectedAreaFilter == area.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 11, weight: .medium))
                Text(selectedAreaFilter != nil ? allAreas.first(where: { $0.id == selectedAreaFilter })?.title ?? "Area" : "All Areas")
                    .font(.system(.caption, design: .rounded))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(glassColorSystem.backgroundSecondary().opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(glassColorSystem.borderColor().opacity(0.55), lineWidth: 0.6)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func sortCategoryMenu(for category: SortCategory) -> some View {
        let options = TaskSortOption.options(for: category)
        let currentOptionInCategory = options.first { $0 == currentSortOption }
        let isActive = currentOptionInCategory != nil
        
        Menu {
            ForEach(options) { option in
                Button {
                    updateSortOption(option)
                } label: {
                    HStack {
                        Text(option.displayName)
                        Spacer()
                        if currentSortOption == option {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isActive ? glassColorSystem.textPrimary() : glassColorSystem.textSecondary())
                
                if let current = currentOptionInCategory {
                    Text(current.displayName)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                        .lineLimit(1)
                } else {
                    Text(category.rawValue)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                        .lineLimit(1)
                }
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(glassColorSystem.textSecondary().opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isActive ? glassColorSystem.cardColor().opacity(0.5) : glassColorSystem.backgroundSecondary().opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isActive ? glassColorSystem.emotionalAccent().opacity(0.4) : glassColorSystem.borderColor().opacity(0.55), lineWidth: isActive ? 1.0 : 0.6)
                    )
            )
        }
        .buttonStyle(.plain)
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
        case .highPriority, .mediumPriority, .lowPriority:
            return "exclamationmark.circle"
        case .todo, .inProgress, .cancelled:
            return "circle"
        case .unattached, .hasProject, .hasArea:
            return "folder"
        case .withDueDate, .withoutDueDate, .overdue, .dueThisWeek, .dueThisMonth:
            return "calendar"
        case .smallEffort, .mediumEffort, .largeEffort, .noEffort:
            return "gauge"
        case .reminders:
            return "bell.fill"
        case .tasksOnly:
            return "checklist"
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
        case .highPriority:
            return "No high priority tasks"
        case .mediumPriority:
            return "No medium priority tasks"
        case .lowPriority:
            return "No low priority tasks"
        case .todo:
            return "No tasks to do"
        case .inProgress:
            return "No tasks in progress"
        case .cancelled:
            return "No cancelled tasks"
        case .unattached:
            return "No unattached tasks"
        case .hasProject:
            return "No tasks with projects"
        case .hasArea:
            return "No tasks with areas"
        case .withDueDate:
            return "No tasks with due dates"
        case .withoutDueDate:
            return "No tasks without due dates"
        case .overdue:
            return "No overdue tasks"
        case .dueThisWeek:
            return "No tasks due this week"
        case .dueThisMonth:
            return "No tasks due this month"
        case .smallEffort:
            return "No small effort tasks"
        case .mediumEffort:
            return "No medium effort tasks"
        case .largeEffort:
            return "No large effort tasks"
        case .noEffort:
            return "No tasks without effort"
        case .reminders:
            return "No reminders"
        case .tasksOnly:
            return "No tasks"
        }
    }
}

// MARK: - Task Filter Sort Drawer

struct TaskFilterSortDrawer: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @Binding var isPresented: Bool
    @Binding var selectedFilter: UnifiedTasksView.TaskFilter
    @Binding var selectedSort: TaskSortOption
    @Binding var selectedProjectFilter: UUID?
    @Binding var selectedAreaFilter: UUID?
    
    let allProjects: [Project]
    let allAreas: [Area]
    
    var body: some View {
        V2DrawerScaffold(
            accentGradient: AuroraPalette.linearGradient(for: colorScheme),
            header: {
                V2GlassHeaderBar(
                    title: "Filter & Sort Tasks",
                    subtitle: "Refine your task view"
                ) {
                    Button {
                        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                            isPresented = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                VStack(alignment: .leading, spacing: 32) {
                    // Filters Section
                    DrawerSection(title: "Filters", icon: "line.3.horizontal.decrease.circle") {
                        VStack(alignment: .leading, spacing: 20) {
                            ForEach(UnifiedTasksView.TaskFilterCategory.allCases, id: \.self) { category in
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: category.icon)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(glassColorSystem.textSecondary())
                                        Text(category.rawValue)
                                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                            .foregroundStyle(glassColorSystem.textPrimary())
                                    }
                                    
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                                        ForEach(UnifiedTasksView.TaskFilter.filters(for: category), id: \.id) { filter in
                                            FilterOptionButton(
                                                title: filter.rawValue,
                                                icon: filter.icon,
                                                isSelected: selectedFilter.id == filter.id,
                                                action: {
                                                    selectedFilter = filter
                                                }
                                            )
                                        }
                                    }
                                }
                            }
                            
                            // Advanced filters
                            if selectedFilter == .hasProject || selectedProjectFilter != nil || selectedFilter == .hasArea || selectedAreaFilter != nil {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Advanced Filters")
                                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                        .foregroundStyle(glassColorSystem.textPrimary())
                                    
                                    HStack(spacing: 12) {
                                        if selectedFilter == .hasProject || selectedProjectFilter != nil {
                                            projectFilterDropdown
                                        }
                                        if selectedFilter == .hasArea || selectedAreaFilter != nil {
                                            areaFilterDropdown
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Sort Section
                    DrawerSection(title: "Sort Options", icon: "arrow.up.arrow.down.circle") {
                        VStack(alignment: .leading, spacing: 20) {
                            ForEach(SortCategory.allCases, id: \.self) { category in
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: category.icon)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(glassColorSystem.textSecondary())
                                        Text(category.rawValue)
                                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                            .foregroundStyle(glassColorSystem.textPrimary())
                                    }
                                    
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                                        ForEach(TaskSortOption.options(for: category), id: \.id) { sort in
                                            SortOptionButton(
                                                title: sort.displayName,
                                                icon: sort.icon,
                                                isSelected: selectedSort.id == sort.id,
                                                action: {
                                                    selectedSort = sort
                                                }
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            sidebar: {
                EmptyView()
            }
        )
    }
    
    private var projectFilterDropdown: some View {
        Menu {
            ForEach(allProjects, id: \.id) { project in
                Button {
                    selectedProjectFilter = project.id
                } label: {
                    HStack {
                        Text(project.title)
                        if selectedProjectFilter == project.id {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text("Project")
                    .font(.system(.caption, design: .rounded))
                Spacer()
                if let projectId = selectedProjectFilter,
                   let project = allProjects.first(where: { $0.id == projectId }) {
                    Text(project.title)
                        .font(.system(.caption, design: .rounded))
                        .lineLimit(1)
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(glassColorSystem.cardColor().opacity(0.4))
            )
        }
    }
    
    private var areaFilterDropdown: some View {
        Menu {
            ForEach(allAreas, id: \.id) { area in
                Button {
                    selectedAreaFilter = area.id
                } label: {
                    HStack {
                        Text(area.title)
                        if selectedAreaFilter == area.id {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text("Area")
                    .font(.system(.caption, design: .rounded))
                Spacer()
                if let areaId = selectedAreaFilter,
                   let area = allAreas.first(where: { $0.id == areaId }) {
                    Text(area.title)
                        .font(.system(.caption, design: .rounded))
                        .lineLimit(1)
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(glassColorSystem.cardColor().opacity(0.4))
            )
        }
    }
}

// MARK: - Helper Views

private struct FilterOptionButton: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.system(.caption, design: .rounded))
                    .lineLimit(1)
                if isSelected {
                    Spacer()
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? glassColorSystem.cardColor().opacity(0.6) : glassColorSystem.backgroundSecondary().opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isSelected ? glassColorSystem.emotionalAccent().opacity(0.5) : glassColorSystem.borderColor().opacity(0.3), lineWidth: isSelected ? 1.2 : 0.8)
                    )
            )
            .foregroundStyle(isSelected ? glassColorSystem.textPrimary() : glassColorSystem.textSecondary())
        }
        .buttonStyle(.plain)
    }
}

private struct SortOptionButton: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.system(.caption, design: .rounded))
                    .lineLimit(1)
                if isSelected {
                    Spacer()
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? glassColorSystem.cardColor().opacity(0.6) : glassColorSystem.backgroundSecondary().opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isSelected ? glassColorSystem.emotionalAccent().opacity(0.5) : glassColorSystem.borderColor().opacity(0.3), lineWidth: isSelected ? 1.2 : 0.8)
                    )
            )
            .foregroundStyle(isSelected ? glassColorSystem.textPrimary() : glassColorSystem.textSecondary())
        }
        .buttonStyle(.plain)
    }
}

