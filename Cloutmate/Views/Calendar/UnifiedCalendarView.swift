//
//  UnifiedCalendarView.swift
//  Cloutmate
//
//  Calendar showing both tasks and posts
//

import SwiftUI
import SwiftData
import CloutmateShared

struct UnifiedCalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CloutmateShared.Post.scheduledDate) private var posts: [CloutmateShared.Post]
    @Query(sort: \CloutmateShared.Artifact.publishedAt) private var artifacts: [CloutmateShared.Artifact]
    @Query(sort: \CloutmateShared.Task.dueDate) private var tasks: [CloutmateShared.Task]
    
    @State private var selectedDate = Date()
    @State private var isWeeklyView = false
    @State private var showingComposer = false
    @State private var showingArtifactComposer = false
    @State private var prefilledDate: Date?
    @State private var selectedPost: CloutmateShared.Post?
    @State private var selectedArtifact: CloutmateShared.Artifact?
    @State private var selectedTask: Task?
    @State private var draggedItem: Any?
    @State private var showConflictWarning = false
    @State private var conflictDate: Date?
    @State private var showDrawer = false
    
    var body: some View {
        ZStack {
            Color(.windowBackgroundColor)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with toggle
                VStack(spacing: 16) {
                    CalendarViewToggle(isWeeklyView: $isWeeklyView)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    if isWeeklyView {
                        UnifiedWeeklyCalendarView(
                            posts: posts,
                            artifacts: artifacts,
                            tasks: tasks,
                            selectedDate: $selectedDate,
                            showingComposer: $showingComposer,
                            showingArtifactComposer: $showingArtifactComposer,
                            prefilledDate: $prefilledDate,
                            selectedPost: $selectedPost,
                            selectedArtifact: $selectedArtifact,
                            selectedTask: $selectedTask,
                            showDrawer: $showDrawer
                        )
                        .background(Color.clear)
                    } else {
                        UnifiedMonthlyCalendarView(
                            posts: posts,
                            artifacts: artifacts,
                            tasks: tasks,
                            selectedDate: $selectedDate,
                            showingComposer: $showingComposer,
                            showingArtifactComposer: $showingArtifactComposer,
                            prefilledDate: $prefilledDate,
                            selectedPost: $selectedPost,
                            selectedArtifact: $selectedArtifact,
                            selectedTask: $selectedTask,
                            showDrawer: $showDrawer
                        )
                        .background(Color.clear)
                    }
                }
            }
            
            // Daily Snapshot Drawer overlay
            if showDrawer {
                DailySnapshotDrawer(
                    date: selectedDate,
                    isPresented: $showDrawer
                )
                .transition(.move(edge: .trailing))
            }
        }
        .navigationTitle("Calendar")
        .sheet(isPresented: $showingComposer) {
            ComposerWindow(prefilledDate: prefilledDate)
        }
        .sheet(isPresented: $showingArtifactComposer) {
            ArtifactComposerView(prefilledDate: prefilledDate)
        }
        .sheet(item: $selectedPost) { post in
            PostPreviewSheet(post: Binding.constant(post))
        }
        .sheet(item: $selectedArtifact) { artifact in
            ArtifactPreviewSheet(artifact: Binding.constant(artifact))
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailSheet(task: task)
        }
        .onAppear {
            // Set up keyboard navigation
            setupKeyboardNavigation()
        }
    }
    
    private func setupKeyboardNavigation() {
        // Keyboard navigation will be handled by the calendar views
    }
}

struct UnifiedWeeklyCalendarView: View {
    let posts: [CloutmateShared.Post]
    let artifacts: [CloutmateShared.Artifact]
    let tasks: [Task]
    @Binding var selectedDate: Date
    @Binding var showingComposer: Bool
    @Binding var showingArtifactComposer: Bool
    @Binding var prefilledDate: Date?
    @Binding var selectedPost: CloutmateShared.Post?
    @Binding var selectedArtifact: CloutmateShared.Artifact?
    @Binding var selectedTask: Task?
    @Binding var showDrawer: Bool
    
    @State private var displayedWeek = Date()
    @State private var showItemListSheet = false
    @State private var itemsForSelectedDate: [CalendarItem] = []
    @State private var selectedDateForList = Date()
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 0) {
            // Week header using new CalendarHeaderView
            CalendarHeaderView(
                title: weekRangeText,
                onPrevious: previousWeek,
                onNext: nextWeek,
                onQuickAction: {
                    NotificationCenter.default.post(name: .openContextualCreate, object: TabIdentifier.calendar)
                }
            )
            .glassPanel(tier: .overlay, cornerRadius: 12)
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            // Days with items
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(weekDays, id: \.self) { date in
                        UnifiedDayColumn(
                            date: date,
                            items: itemsForDate(date),
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            onPostClick: { post in
                                selectedPost = post
                            },
                            onArtifactClick: { artifact in
                                selectedArtifact = artifact
                            },
                            onTaskClick: { task in
                                selectedTask = task
                            }
                        )
                        .onTapGesture {
                            withAnimation(GlassMotion.Easing.modalOpen) {
                                selectedDate = date
                                showDrawer = true
                            }
                        }
                        .onTapGesture(count: 2) {
                            let today = Date()
                            if calendar.isDateInToday(date) || date > today {
                                prefilledDate = date
                                showingArtifactComposer = true
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.clear)
        }
        .sheet(isPresented: $showItemListSheet) {
            UnifiedCalendarListSheet(
                date: selectedDateForList,
                items: itemsForSelectedDate,
                isPresented: $showItemListSheet
            )
        }
    }
    
    private var weekDays: [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: displayedWeek) else {
            return []
        }
        
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: weekInterval.start)
        }
    }
    
    private var weekRangeText: String {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: displayedWeek) else {
            return ""
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: weekInterval.start)
        
        // Get end date (last day of week)
        if let endDate = calendar.date(byAdding: .day, value: 6, to: weekInterval.start) {
            let endYear = calendar.component(.year, from: endDate)
            let startYear = calendar.component(.year, from: weekInterval.start)
            
            if endYear == startYear {
                formatter.dateFormat = "d, yyyy"
            } else {
                formatter.dateFormat = "MMM d, yyyy"
            }
            let end = formatter.string(from: endDate)
            return "\(start) - \(end)"
        }
        
        return start
    }
    
    private func itemsForDate(_ date: Date) -> [CalendarItem] {
        var items: [CalendarItem] = []
        
        // Add posts (backward compatibility)
        let dayPosts = posts.filter { post in
            if let scheduledDate = post.scheduledDate, calendar.isDate(scheduledDate, inSameDayAs: date) {
                return true
            }
            if let publishedDate = post.publishedDate, calendar.isDate(publishedDate, inSameDayAs: date) {
                return true
            }
            return false
        }
        items.append(contentsOf: dayPosts.map { CalendarItem.post($0) })
        
        // Add artifacts
        let dayArtifacts = artifacts.filter { artifact in
            if let publishedAt = artifact.publishedAt, calendar.isDate(publishedAt, inSameDayAs: date) {
                return true
            }
            if artifact.artifactState == .published || artifact.artifactState == .final,
               calendar.isDate(artifact.createdAt, inSameDayAs: date) {
                return true
            }
            return false
        }
        items.append(contentsOf: dayArtifacts.map { CalendarItem.artifact($0) })
        
        // Add tasks
        let dayTasks = tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: date)
        }
        items.append(contentsOf: dayTasks.map { CalendarItem.task($0) })
        
        // Sort by time
        items.sort { item1, item2 in
            let time1 = item1.time
            let time2 = item2.time
            return time1 < time2
        }
        
        return items
    }
    
    private func previousWeek() {
        if let newDate = calendar.date(byAdding: .weekOfYear, value: -1, to: displayedWeek) {
            displayedWeek = newDate
        }
    }
    
    private func nextWeek() {
        if let newDate = calendar.date(byAdding: .weekOfYear, value: 1, to: displayedWeek) {
            displayedWeek = newDate
        }
    }
}

struct UnifiedMonthlyCalendarView: View {
    let posts: [CloutmateShared.Post]
    let artifacts: [CloutmateShared.Artifact]
    let tasks: [Task]
    @Binding var selectedDate: Date
    @Binding var showingComposer: Bool
    @Binding var showingArtifactComposer: Bool
    @Binding var prefilledDate: Date?
    @Binding var selectedPost: CloutmateShared.Post?
    @Binding var selectedArtifact: CloutmateShared.Artifact?
    @Binding var selectedTask: Task?
    @Binding var showDrawer: Bool
    
    @State private var currentMonth = Date()
    @State private var showItemListSheet = false
    @State private var itemsForSelectedDate: [CalendarItem] = []
    @State private var selectedDateForList = Date()
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 0) {
            // Month header using new CalendarHeaderView
            CalendarHeaderView(
                title: monthText,
                onPrevious: previousMonth,
                onNext: nextMonth,
                onQuickAction: {
                    NotificationCenter.default.post(name: .openContextualCreate, object: TabIdentifier.calendar)
                }
            )
            .glassPanel(tier: .overlay, cornerRadius: 12)
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            // Calendar grid
            ScrollView {
                VStack(spacing: 8) {
                    // Weekday headers
                    HStack(spacing: 4) {
                        ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                            Text(day)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Calendar days using new CalendarDayCellV2
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                        ForEach(calendarDays, id: \.self) { date in
                            CalendarDayCellV2(
                                date: date,
                                items: itemsForDate(date),
                                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                isCurrentMonth: calendar.component(.month, from: date) == calendar.component(.month, from: currentMonth),
                                onTap: {
                                    withAnimation(GlassMotion.Easing.modalOpen) {
                                        selectedDate = date
                                        showDrawer = true
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color.clear)
        }
        .sheet(isPresented: $showItemListSheet) {
            UnifiedCalendarListSheet(
                date: selectedDateForList,
                items: itemsForSelectedDate,
                isPresented: $showItemListSheet
            )
        }
    }
    
    private var calendarDays: [Date] {
        guard let firstDayOfMonth = calendar.dateInterval(of: .month, for: currentMonth)?.start else {
            return []
        }
        
        // Get first weekday of month
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let daysToSubtract = firstWeekday - 1
        
        // Get start date (first Sunday of calendar)
        guard let startDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: firstDayOfMonth) else {
            return []
        }
        
        // Generate 42 days (6 weeks × 7 days)
        return (0..<42).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startDate)
        }
    }
    
    private var monthText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }
    
    private func itemsForDate(_ date: Date) -> [CalendarItem] {
        var items: [CalendarItem] = []
        
        // Add posts (backward compatibility)
        let dayPosts = posts.filter { post in
            if let scheduledDate = post.scheduledDate, calendar.isDate(scheduledDate, inSameDayAs: date) {
                return true
            }
            if let publishedDate = post.publishedDate, calendar.isDate(publishedDate, inSameDayAs: date) {
                return true
            }
            return false
        }
        items.append(contentsOf: dayPosts.map { CalendarItem.post($0) })
        
        // Add artifacts
        let dayArtifacts = artifacts.filter { artifact in
            if let publishedAt = artifact.publishedAt, calendar.isDate(publishedAt, inSameDayAs: date) {
                return true
            }
            if artifact.artifactState == .published || artifact.artifactState == .final,
               calendar.isDate(artifact.createdAt, inSameDayAs: date) {
                return true
            }
            return false
        }
        items.append(contentsOf: dayArtifacts.map { CalendarItem.artifact($0) })
        
        // Add tasks
        let dayTasks = tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: date)
        }
        items.append(contentsOf: dayTasks.map { CalendarItem.task($0) })
        
        return items
    }
    
    private func previousMonth() {
        if let newDate = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newDate
        }
    }
    
    private func nextMonth() {
        if let newDate = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newDate
        }
    }
}

enum CalendarItem: Identifiable {
    case post(CloutmateShared.Post)
    case artifact(CloutmateShared.Artifact)
    case task(Task)
    
    var id: UUID {
        switch self {
        case .post(let post):
            return post.id
        case .artifact(let artifact):
            return artifact.id
        case .task(let task):
            return task.id
        }
    }
    
    var time: Date {
        switch self {
        case .post(let post):
            return post.scheduledDate ?? post.publishedDate ?? Date()
        case .artifact(let artifact):
            return artifact.publishedAt ?? artifact.createdAt
        case .task(let task):
            return task.dueDate ?? Date()
        }
    }
}

struct UnifiedDayColumn: View {
    let date: Date
    let items: [CalendarItem]
    let isSelected: Bool
    var onPostClick: ((CloutmateShared.Post) -> Void)?
    var onArtifactClick: ((CloutmateShared.Artifact) -> Void)?
    var onTaskClick: ((Task) -> Void)?
    
    @State private var isHovered = false
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Day header
            HStack {
                Text(dayText)
                    .font(.system(.headline, design: .rounded))
                Text(dateText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                
                // Show count with badges
                HStack(spacing: 4) {
                    let postCount = items.filter { if case .post = $0 { return true }; return false }.count
                    let artifactCount = items.filter { if case .artifact = $0 { return true }; return false }.count
                    let taskCount = items.filter { if case .task = $0 { return true }; return false }.count
                    
                    if postCount > 0 {
                        Text("\(postCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.kosmicBlue)
                            .cornerRadius(8)
                    }
                    
                    if artifactCount > 0 {
                        Text("\(artifactCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.kosmicPurple)
                            .cornerRadius(8)
                    }
                    
                    if taskCount > 0 {
                        Text("\(taskCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.kosmicGreen)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassPanel(tier: isSelected ? .overlay : .contentCard, cornerRadius: 12, tintColor: isSelected ? Color.kosmicBlue.opacity(0.2) : nil)
            .shadow(
                color: isSelected ? Color.kosmicBlue.opacity(0.3) : .black.opacity(0.05),
                radius: isSelected ? 8 : 2,
                y: isSelected ? 4 : 1
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .onHover { hovering in
                isHovered = hovering
            }
            
            // Items
            ForEach(items.prefix(5)) { item in
                switch item {
                case .post(let post):
                    PostCard(post: post, onTap: {
                        onPostClick?(post)
                    })
                case .artifact(let artifact):
                    ArtifactCard(artifact: artifact, onTap: {
                        onArtifactClick?(artifact)
                    })
                case .task(let task):
                    TaskCard(task: task, onTap: {
                        onTaskClick?(task)
                    })
                }
            }
        }
    }
    
    private var dayText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

struct TaskCard: View {
    let task: Task
    var onTap: (() -> Void)?
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 10) {
            // Task icon
            Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                .foregroundColor(task.status == .done ? .kosmicGreen : .orange)
                .font(.title3)
            
            // Task title
            Text(task.title)
                .lineLimit(2)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(12)
        .background(
            Group {
                if isHovering {
                    LinearGradient(
                        colors: [Color.kosmicGreen.opacity(0.12), Color.kosmicGreen.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    LinearGradient(
                        colors: [Color.secondary.opacity(0.12), Color.secondary.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isHovering ? Color.kosmicGreen.opacity(0.4) : Color.kosmicGreen.opacity(0.2),
                    lineWidth: isHovering ? 1.5 : 1
                )
        )
        .cornerRadius(12)
        .shadow(
            color: isHovering ? Color.kosmicGreen.opacity(0.3) : .black.opacity(0.05),
            radius: isHovering ? 4 : 2,
            x: 0,
            y: isHovering ? 2 : 1
        )
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            onTap?()
        }
    }
}

struct UnifiedCalendarListSheet: View {
    let date: Date
    let items: [CalendarItem]
    @Binding var isPresented: Bool
    
    private let calendar = Calendar.current
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Date header
                    HStack {
                        Text(date, style: .date)
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        Text("\(items.count) items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .glassPanel(tier: .overlay, cornerRadius: 12)
                    .padding()
                    
                    // Items grouped by type
                    if items.isEmpty {
                        ContentUnavailableView(
                            "No items",
                            systemImage: "calendar",
                            description: Text("No tasks or posts scheduled for this date")
                        )
                        .frame(height: 200)
                        .padding()
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            // Posts (backward compatibility)
                            let posts = items.compactMap { if case .post(let p) = $0 { return p }; return nil }
                            if !posts.isEmpty {
                                Text("Posts")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ForEach(posts) { post in
                                    PostPreviewRow(post: post)
                                        .padding(.horizontal)
                                }
                            }
                            
                            // Artifacts
                            let artifacts = items.compactMap { if case .artifact(let a) = $0 { return a }; return nil }
                            if !artifacts.isEmpty {
                                Text("Artifacts")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ForEach(artifacts) { artifact in
                                    ArtifactPreviewRow(artifact: artifact)
                                        .padding(.horizontal)
                                }
                            }
                            
                            // Tasks
                            let tasks = items.compactMap { if case .task(let t) = $0 { return t }; return nil }
                            if !tasks.isEmpty {
                                Text("Tasks")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ForEach(tasks) { task in
                                    TaskRow(task: task)
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.clear)
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct TaskDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let task: Task
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(task.status == .done ? .kosmicGreen : .orange)
                            .font(.title)
                        Text(task.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .glassPanel(tier: .overlay, cornerRadius: 12)
                    .padding()
                    
                    if let notes = task.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.body)
                            .padding()
                            .glassPanel(tier: .contentCard, cornerRadius: 12)
                    }
                }
                .padding()
            }
            .background(Color.clear)
            .navigationTitle("Task Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct UnifiedCalendarDayCell: View {
    let date: Date
    let items: [CalendarItem]
    let isSelected: Bool
    let isCurrentMonth: Bool
    var onTap: () -> Void
    
    private let calendar = Calendar.current
    
    private var isToday: Bool {
        calendar.isDateInToday(date)
    }
    
    private var dayNumber: Int {
        calendar.component(.day, from: date)
    }
    
    private var postCount: Int {
        items.filter { if case .post = $0 { return true }; return false }.count
    }
    
    private var taskCount: Int {
        items.filter { if case .task = $0 { return true }; return false }.count
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(dayNumber)")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundColor(isToday ? .kosmicBlue : (isCurrentMonth ? .primary : .secondary))
                
                // Item count badges
                HStack(spacing: 2) {
                    if postCount > 0 {
                        Circle()
                            .fill(Color.kosmicBlue)
                            .frame(width: 4, height: 4)
                    }
                    if items.filter({ if case .artifact = $0 { return true }; return false }).count > 0 {
                        Circle()
                            .fill(Color.kosmicPurple)
                            .frame(width: 4, height: 4)
                    }
                    if taskCount > 0 {
                        Circle()
                            .fill(Color.kosmicGreen)
                            .frame(width: 4, height: 4)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.kosmicBlue.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isToday ? Color.kosmicBlue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    UnifiedCalendarView()
        .modelContainer(for: [CloutmateShared.Post.self, CloutmateShared.Artifact.self, CloutmateShared.Task.self])
}

// MARK: - Artifact Card Components

struct ArtifactCard: View {
    let artifact: CloutmateShared.Artifact
    var onTap: (() -> Void)?
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 10) {
            // Format badge
            Image(systemName: formatIcon)
                .font(.system(size: 15))
                .foregroundColor(formatColor)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
            
            // Time
            if let publishedAt = artifact.publishedAt {
                Text(publishedAt, style: .time)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.15), Color.accentColor.opacity(0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(6)
            }
            
            // Title/content preview
            Text(artifact.title.isEmpty ? artifact.content : artifact.title)
                .lineLimit(1)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(12)
        .background(
            Group {
                if isHovering {
                    LinearGradient(
                        colors: [Color.kosmicPurple.opacity(0.12), Color.kosmicPurple.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    LinearGradient(
                        colors: [Color.secondary.opacity(0.12), Color.secondary.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isHovering ? Color.kosmicPurple.opacity(0.4) : Color.kosmicPurple.opacity(0.2),
                    lineWidth: isHovering ? 1.5 : 1
                )
        )
        .cornerRadius(12)
        .shadow(
            color: isHovering ? Color.kosmicPurple.opacity(0.3) : .black.opacity(0.05),
            radius: isHovering ? 4 : 2,
            x: 0,
            y: isHovering ? 2 : 1
        )
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            onTap?()
        }
    }
    
    private var formatIcon: String {
        switch artifact.format {
        case .brief: return "doc.text"
        case .summary: return "doc.text.below.ecg"
        case .reflection: return "brain.head.profile"
        case .report: return "doc.text.magnifyingglass"
        case .releaseNote: return "megaphone"
        case .lessonLearned: return "lightbulb"
        }
    }
    
    private var formatColor: Color {
        switch artifact.format {
        case .brief: return .kosmicCyan
        case .summary: return .kosmicBlue
        case .reflection: return .kosmicPurple
        case .report: return .kosmicPurple
        case .releaseNote: return .kosmicGreen
        case .lessonLearned: return .orange
        }
    }
}

struct ArtifactPreviewRow: View {
    let artifact: CloutmateShared.Artifact
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(artifact.title.isEmpty ? artifact.content.prefix(50).description : artifact.title)
                    .lineLimit(2)
                    .font(.body)
                
                if let publishedAt = artifact.publishedAt {
                    Text(publishedAt, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            ArtifactStateBadge(state: artifact.artifactState)
        }
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 8)
    }
}

struct ArtifactStateBadge: View {
    let state: ArtifactState
    
    var body: some View {
        Text(state.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(stateColor.opacity(0.2))
            .foregroundColor(stateColor)
            .cornerRadius(6)
    }
    
    private var stateColor: Color {
        switch state {
        case .idea: return .gray
        case .draft: return .kosmicBlue
        case .final: return .kosmicPurple
        case .published: return .kosmicGreen
        case .archived: return .secondary
        }
    }
}
