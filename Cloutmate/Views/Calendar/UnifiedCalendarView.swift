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
    @Query(sort: \CloutmateShared.Task.dueDate) private var tasks: [CloutmateShared.Task]
    
    @State private var selectedDate = Date()
    @State private var isWeeklyView = false
    @State private var showingComposer = false
    @State private var prefilledDate: Date?
    @State private var selectedPost: CloutmateShared.Post?
    @State private var selectedTask: Task?
    @State private var draggedItem: Any?
    @State private var showConflictWarning = false
    @State private var conflictDate: Date?
    
    var body: some View {
        ZStack {
            Color(.windowBackgroundColor)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // View toggle with Glass Buttons
                HStack(spacing: 8) {
                    GlassButton(
                        "Monthly",
                        style: .pill,
                        role: !isWeeklyView ? .primary : .surface,
                        tintColor: !isWeeklyView ? Color(red: 0.36, green: 0.66, blue: 1.0) : Color.white.opacity(0.35),
                        action: { isWeeklyView = false }
                    )
                    
                    GlassButton(
                        "Weekly",
                        style: .pill,
                        role: isWeeklyView ? .primary : .surface,
                        tintColor: isWeeklyView ? Color(red: 0.36, green: 0.66, blue: 1.0) : Color.white.opacity(0.35),
                        action: { isWeeklyView = true }
                    )
                    
                    Spacer()
                }
                .padding()
                
                if isWeeklyView {
                    UnifiedWeeklyCalendarView(
                        posts: posts,
                        tasks: tasks,
                        selectedDate: $selectedDate,
                        showingComposer: $showingComposer,
                        prefilledDate: $prefilledDate,
                        selectedPost: $selectedPost,
                        selectedTask: $selectedTask
                    )
                    .background(Color.clear)
                } else {
                    UnifiedMonthlyCalendarView(
                        posts: posts,
                        tasks: tasks,
                        selectedDate: $selectedDate,
                        showingComposer: $showingComposer,
                        prefilledDate: $prefilledDate,
                        selectedPost: $selectedPost,
                        selectedTask: $selectedTask
                    )
                    .background(Color.clear)
                }
            }
        }
        .navigationTitle("Calendar")
        .sheet(isPresented: $showingComposer) {
            ComposerWindow(prefilledDate: prefilledDate)
        }
        .sheet(item: $selectedPost) { post in
            PostPreviewSheet(post: Binding.constant(post))
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailSheet(task: task)
        }
    }
}

struct UnifiedWeeklyCalendarView: View {
    let posts: [CloutmateShared.Post]
    let tasks: [Task]
    @Binding var selectedDate: Date
    @Binding var showingComposer: Bool
    @Binding var prefilledDate: Date?
    @Binding var selectedPost: CloutmateShared.Post?
    @Binding var selectedTask: Task?
    
    @State private var displayedWeek = Date()
    @State private var showItemListSheet = false
    @State private var itemsForSelectedDate: [CalendarItem] = []
    @State private var selectedDateForList = Date()
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 0) {
            // Week header
            HStack {
                GlassButton(icon: "chevron.left", style: .iconOnly, tintColor: .kosmicBlue, action: previousWeek)
                    .frame(width: 32, height: 32)
                
                Spacer()
                
                Text(weekRangeText)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.kosmicBlue, .kosmicPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Spacer()
                
                GlassButton(icon: "chevron.right", style: .iconOnly, tintColor: .kosmicBlue, action: nextWeek)
                    .frame(width: 32, height: 32)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .glassPanel(tier: .overlay, cornerRadius: 12)
            .padding(.horizontal)
            
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
                            onTaskClick: { task in
                                selectedTask = task
                            }
                        )
                        .onTapGesture {
                            selectedDate = date
                            selectedDateForList = date
                            itemsForSelectedDate = itemsForDate(date)
                            showItemListSheet = true
                        }
                        .onTapGesture(count: 2) {
                            let today = Date()
                            if calendar.isDateInToday(date) || date > today {
                                prefilledDate = date
                                showingComposer = true
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
        formatter.dateFormat = "d, yyyy"
        let end = formatter.string(from: weekInterval.end)
        
        return "\(start) - \(end)"
    }
    
    private func itemsForDate(_ date: Date) -> [CalendarItem] {
        var items: [CalendarItem] = []
        
        // Add posts
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
    let tasks: [Task]
    @Binding var selectedDate: Date
    @Binding var showingComposer: Bool
    @Binding var prefilledDate: Date?
    @Binding var selectedPost: CloutmateShared.Post?
    @Binding var selectedTask: Task?
    
    @State private var currentMonth = Date()
    @State private var showItemListSheet = false
    @State private var itemsForSelectedDate: [CalendarItem] = []
    @State private var selectedDateForList = Date()
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 0) {
            // Month header
            HStack {
                GlassButton(icon: "chevron.left", style: .iconOnly, tintColor: .kosmicBlue, action: previousMonth)
                    .frame(width: 32, height: 32)
                
                Spacer()
                
                Text(monthText)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.kosmicBlue, .kosmicPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Spacer()
                
                GlassButton(icon: "chevron.right", style: .iconOnly, tintColor: .kosmicBlue, action: nextMonth)
                    .frame(width: 32, height: 32)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .glassPanel(tier: .overlay, cornerRadius: 12)
            .padding(.horizontal)
            
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
                    
                    // Calendar days
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                        ForEach(calendarDays, id: \.self) { date in
                            UnifiedCalendarDayCell(
                                date: date,
                                items: itemsForDate(date),
                                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                isCurrentMonth: calendar.component(.month, from: date) == calendar.component(.month, from: currentMonth),
                                onTap: {
                                    selectedDate = date
                                    selectedDateForList = date
                                    itemsForSelectedDate = itemsForDate(date)
                                    showItemListSheet = true
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
        
        // Add posts
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
    case task(Task)
    
    var id: UUID {
        switch self {
        case .post(let post):
            return post.id
        case .task(let task):
            return task.id
        }
    }
    
    var time: Date {
        switch self {
        case .post(let post):
            return post.scheduledDate ?? post.publishedDate ?? Date()
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
                            // Posts
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
        .modelContainer(for: [CloutmateShared.Post.self, CloutmateShared.Task.self])
}
