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
    @State private var showCreateSheet = false
    @State private var showEditSheet = false
    @State private var taskToEdit: Task?
    @State private var scrollOffset: CGFloat = 0
    @State private var focusedTaskIndex: Int?
    @State private var showFocusRecap = false
    @State private var expandedSections: Set<TaskSectionType> = [.today, .nextUp, .later]
    
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
                    onFilterChange: { selectedFilter = $0 },
                    onQuickAdd: {
                        NotificationCenter.default.post(name: .openContextualCreate, object: TabIdentifier.tasks)
                    }
                )
                .glassPanel(tier: .overlay, cornerRadius: 12)
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 8)
                .opacity(headerOpacity)
                .offset(y: headerOffset)
                .transition(.move(edge: .top).combined(with: .opacity))
                
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
                                            taskToEdit = task
                                            showEditSheet = true
                                        },
                                        onDuplicate: duplicateTask,
                                        onArchive: { task in
                                            task.status = .cancelled
                                            try? modelContext.save()
                                        },
                                        onDelete: deleteTask
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
                        .background(
                            GeometryReader { geometry in
                                Color.clear
                                    .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
                            }
                        )
                        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                            scrollOffset = value
                        }
                    }
                }
                .coordinateSpace(name: "scroll")
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateTaskSheetWithPrefill(prefilledDate: Calendar.current.startOfDay(for: Date()))
        }
        .sheet(isPresented: $showEditSheet) {
            if let task = taskToEdit {
                EditTaskSheet(task: task)
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
            if event.modifierFlags.contains(.command) {
                switch event.charactersIgnoringModifiers?.lowercased() {
                case "n":
                    showCreateSheet = true
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
                            onDelete: { onDelete(task) }
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

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Create Task Sheet with Prefill

struct CreateTaskSheetWithPrefill: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allProjects: [CloutmateShared.Project]
    @Query private var allAreas: [Area]
    
    let prefilledDate: Date
    
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var status: CloutmateShared.TaskStatus = .todo
    @State private var priority: CloutmateShared.TaskPriority = .medium
    @State private var hasDueDate: Bool = true
    @State private var dueDate: Date
    @State private var projectId: UUID?
    @State private var areaId: UUID?
    @State private var effort: String = ""
    
    init(prefilledDate: Date) {
        self.prefilledDate = prefilledDate
        self._dueDate = State(initialValue: prefilledDate)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Task Title *", text: $title)
                        TextField("Notes", text: $notes, axis: .vertical).lineLimit(3...6)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Status").font(.caption).foregroundColor(.secondary)
                        Picker("Status", selection: $status) {
                            ForEach(CloutmateShared.TaskStatus.allCases, id: \.self) { s in Text(s.displayName).tag(s) }
                        }.pickerStyle(.segmented)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Priority").font(.caption).foregroundColor(.secondary)
                        Picker("Priority", selection: $priority) {
                            ForEach(CloutmateShared.TaskPriority.allCases, id: \.self) { p in Text(p.displayName).tag(p) }
                        }.pickerStyle(.segmented)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Set Due Date", isOn: $hasDueDate)
                        if hasDueDate {
                            DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                        }
                    }
                    
                    if !allProjects.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Project").font(.caption).foregroundColor(.secondary)
                            Picker("Project", selection: $projectId) {
                                Text("None").tag(UUID?.none)
                                ForEach(allProjects) { p in Text(p.title).tag(p.id as UUID?) }
                            }
                        }
                    }
                    
                    if !allAreas.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Area").font(.caption).foregroundColor(.secondary)
                            Picker("Area", selection: $areaId) {
                                Text("None").tag(UUID?.none)
                                ForEach(allAreas) { a in Text(a.title).tag(a.id as UUID?) }
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Effort").font(.caption).foregroundColor(.secondary)
                        Picker("Effort", selection: $effort) {
                            Text("None").tag("")
                            Text("Small").tag("small")
                            Text("Medium").tag("medium")
                            Text("Large").tag("large")
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createTask() }.disabled(title.isEmpty)
                }
            }
        }
        .frame(width: 600, height: 520)
    }
    
    private func createTask() {
        let task = CloutmateShared.Task(
            title: title,
            notes: notes.isEmpty ? nil : notes,
            status: status,
            priority: priority,
            dueDate: hasDueDate ? dueDate : nil,
            projectId: projectId,
            areaId: areaId,
            effort: effort.isEmpty ? nil : effort
        )
        modelContext.insert(task)
        try? modelContext.save()
        
        // Haptic feedback
        let generator = NSHapticFeedbackManager.defaultPerformer
        generator.perform(.generic, performanceTime: .default)
        
        dismiss()
    }
}

#Preview {
    UnifiedTasksView()
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [Task.self, Project.self, Area.self])
}

