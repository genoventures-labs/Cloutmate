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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var glassColorSystem = GlassColorSystem()
    @Query(sort: \CloutmateShared.Post.scheduledDate) private var posts: [CloutmateShared.Post]
    @Query(sort: \CloutmateShared.Artifact.publishedAt) private var artifacts: [CloutmateShared.Artifact]
    @Query(sort: \CloutmateShared.Task.dueDate) private var tasks: [CloutmateShared.Task]
    @Query(sort: \CalendarEvent.startDate) private var events: [CalendarEvent]
    
    @State private var selectedDate = Date()
    @State private var isWeeklyView = false
    @State private var activePost: CloutmateShared.Post?
    @State private var activeArtifact: CloutmateShared.Artifact?
    @State private var activeTask: CloutmateShared.Task?
    @State private var activeEvent: CalendarEvent?
    @State private var dayItems: [CalendarDayDetailDrawer.Item] = []
    @State private var dayDrawerVisible = false
    @State private var postDrawerVisible = false
    @State private var artifactDrawerVisible = false
    @State private var taskDrawerVisible = false
    @State private var eventDrawerVisible = false
    @State private var selectedDay: Date = Date()
    @State private var composerRequest: CalendarComposerRequest?
    @State private var showingComposer = false
    @State private var isCreatingEvent = false
    @State private var pendingEventDraft: CalendarEventDraft?
    
    private let calendar = Calendar.current
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(.windowBackgroundColor)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                calendarHeader
                calendarContent
            }
            .opacity(hasActiveDrawer ? 0 : 1)
            
            if let post = activePost, postDrawerVisible {
                PostDetailDrawer(
                    post: post,
                    isPresented: Binding(
                        get: { postDrawerVisible },
                        set: { newValue in
                            withAnimation(calendarAnimation) {
                                postDrawerVisible = newValue
                            }
                        }
                    ),
                    onEdit: { editedPost in
                        launchComposer(with: CalendarComposerRequest(existingPost: editedPost, prefilledDate: editedPost.scheduledDate))
                    }
                )
                .transition(.move(edge: .trailing))
            }
            
            if let artifact = activeArtifact, artifactDrawerVisible {
                CalendarArtifactDetailDrawer(
                    artifact: artifact,
                    isPresented: Binding(
                        get: { artifactDrawerVisible },
                        set: { newValue in
                            withAnimation(calendarAnimation) {
                                artifactDrawerVisible = newValue
                            }
                        }
                    )
                )
                .transition(.move(edge: .trailing))
            }
            
            if let task = activeTask, taskDrawerVisible {
                TaskDetailDrawer(
                    mode: .edit,
                    existingTask: task,
                    initialDraft: TaskDraft(task: task),
                    isPresented: Binding(
                        get: { taskDrawerVisible },
                        set: { newValue in
                            withAnimation(calendarAnimation) {
                                taskDrawerVisible = newValue
                                if !newValue {
                                    activeTask = nil
                                }
                            }
                        }
                    ),
                    onCommit: { draft in
                        update(task, with: draft)
                        try? modelContext.save()
                        withAnimation(calendarAnimation) {
                            taskDrawerVisible = false
                            activeTask = nil
                        }
                    },
                    onCancel: {
                        withAnimation(calendarAnimation) {
                            taskDrawerVisible = false
                            activeTask = nil
                        }
                    }
                )
                .environmentObject(glassColorSystem)
                .transition(.move(edge: .trailing))
            }
            
            if eventDrawerVisible, let draft = pendingEventDraft {
                CalendarEventDrawer(
                    mode: isCreatingEvent ? .create : .edit,
                    existingEvent: activeEvent,
                    initialDraft: draft,
                    isPresented: Binding(
                        get: { eventDrawerVisible },
                        set: { newValue in
                            withAnimation(calendarAnimation) {
                                eventDrawerVisible = newValue
                                if !newValue {
                                    resetEventDrawerState()
                                }
                            }
                        }
                    ),
                    onCommit: { commitEvent(from: $0) },
                    onDelete: isCreatingEvent ? nil : deleteActiveEvent,
                    onCancel: cancelEventEditing,
                    onAskAurora: { askAuroraForEventSuggestions(using: draft) }
                )
                .environmentObject(glassColorSystem)
                .transition(.move(edge: .trailing))
            }
            
            if dayDrawerVisible {
                CalendarDayDetailDrawer(
                    date: selectedDay,
                    items: dayItems,
                    isPresented: Binding(
                        get: { dayDrawerVisible },
                        set: { newValue in
                            withAnimation(calendarAnimation) {
                                dayDrawerVisible = newValue
                            }
                        }
                    ),
                    onSelect: handleDayItemSelection
                )
                .transition(.move(edge: .trailing))
            }
            
            if showingComposer {
                ComposerDetailDrawer(
                    isPresented: Binding(
                        get: { showingComposer },
                        set: { newValue in
                            withAnimation(calendarAnimation) {
                                showingComposer = newValue
                                if !newValue {
                                    composerRequest = nil
                                }
                            }
                        }
                    ),
                    existingPost: composerRequest?.existingPost,
                    prefilledDate: composerRequest?.prefilledDate
                )
                .transition(.move(edge: .trailing))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openComposer)) { notification in
            let request = mapComposerNotification(notification)
            launchComposer(with: request)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openEntity)) { notification in
            guard let info = notification.userInfo,
                  let typeRaw = info["type"] as? String,
                  typeRaw == ObjectType.event.rawValue,
                  let idString = info["id"] as? String,
                  let uuid = UUID(uuidString: idString),
                  let event = events.first(where: { $0.id == uuid })
            else { return }
            
            let occurrence = CalendarEventOccurrence(
                event: event,
                startDate: event.startDate,
                endDate: event.endDate
            )
            openEventDrawer(for: occurrence)
        }
        .navigationTitle("Calendar")
        .environmentObject(glassColorSystem)
    }
    
    private var hasActiveDrawer: Bool {
        postDrawerVisible || artifactDrawerVisible || taskDrawerVisible || eventDrawerVisible || dayDrawerVisible || showingComposer
    }
    
    private var calendarAnimation: Animation {
        reduceMotion ? .default : GlassMotion.Easing.modalOpen
    }
    
    private func update(_ task: CloutmateShared.Task, with draft: TaskDraft) {
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
    
    private var calendarHeader: some View {
        HStack(alignment: .center, spacing: 16) {
                    CalendarViewToggle(isWeeklyView: $isWeeklyView)
            
            Spacer()
            
            Button {
                startCreatingEvent(at: selectedDate)
            } label: {
                Label("New Event", systemImage: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [.kosmicBlue, .kosmicPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
        }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }
                    
    private var calendarContent: some View {
        Group {
                    if isWeeklyView {
                        UnifiedWeeklyCalendarView(
                            posts: posts,
                            artifacts: artifacts,
                            tasks: tasks,
                    events: events,
                            selectedDate: $selectedDate,
                    onOpenDay: openDayDrawer,
                    onOpenPost: openPostDrawer,
                    onOpenArtifact: openArtifactDrawer,
                    onOpenTask: openTaskDrawer,
                    onOpenEvent: openEventDrawer,
                    onCompose: launchComposer
                )
                    } else {
                        UnifiedMonthlyCalendarView(
                            posts: posts,
                            artifacts: artifacts,
                            tasks: tasks,
                    events: events,
                            selectedDate: $selectedDate,
                    onOpenDay: openDayDrawer,
                    onOpenPost: openPostDrawer,
                    onOpenArtifact: openArtifactDrawer,
                    onOpenTask: openTaskDrawer,
                    onOpenEvent: openEventDrawer,
                    onCompose: launchComposer
                )
            }
        }
    }
    
    private func openDayDrawer(for date: Date) {
        selectedDay = date
        dayItems = itemsForDate(date)
        dayDrawerVisible = true
    }
    
    private func openPostDrawer(for post: CloutmateShared.Post) {
        activePost = post
        postDrawerVisible = true
    }
    
    private func openArtifactDrawer(for artifact: CloutmateShared.Artifact) {
        activeArtifact = artifact
        artifactDrawerVisible = true
    }
    
    private func openTaskDrawer(for task: CloutmateShared.Task) {
        activeTask = task
        taskDrawerVisible = true
    }
    
    private func openEventDrawer(for occurrence: CalendarEventOccurrence) {
        var draft = CalendarEventDraft(event: occurrence.event)
        draft.startDate = occurrence.startDate
        draft.endDate = occurrence.endDate
        
        activeEvent = occurrence.event
        pendingEventDraft = draft
        isCreatingEvent = false
        
        withAnimation(calendarAnimation) {
            eventDrawerVisible = true
        }
    }
    
    private func startCreatingEvent(at date: Date? = nil) {
        let baseDate = date ?? selectedDate
        let startOfDay = calendar.startOfDay(for: baseDate)
        let defaultStart = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: startOfDay) ?? baseDate
        let defaultEnd = calendar.date(byAdding: .hour, value: 1, to: defaultStart) ?? defaultStart.addingTimeInterval(3600)
        
        pendingEventDraft = CalendarEventDraft(
            title: "",
            location: "",
            notes: "",
            startDate: defaultStart,
            endDate: defaultEnd,
            allDay: false
        )
        activeEvent = nil
        isCreatingEvent = true
        
        withAnimation(calendarAnimation) {
            eventDrawerVisible = true
        }
    }
    
    private func commitEvent(from draft: CalendarEventDraft) {
        if isCreatingEvent {
            let newEvent = CalendarEvent(
                title: draft.title,
                notes: draft.notes.isEmpty ? nil : draft.notes,
                location: draft.location.isEmpty ? nil : draft.location,
                startDate: draft.startDate,
                endDate: draft.endDate,
                allDay: draft.allDay,
                recurrence: draft.recurrence,
                remindMinutesBefore: draft.remindMinutesBefore,
                colorHex: nil,
                auroraGenerated: false
            )
            newEvent.linkedEntityIds = draft.linkedEntityIds
            newEvent.linkedEntityTypes = draft.linkedEntityTypes
            modelContext.insert(newEvent)
        } else if let event = activeEvent {
            event.title = draft.title
            event.location = draft.location.isEmpty ? nil : draft.location
            event.notes = draft.notes.isEmpty ? nil : draft.notes
            event.startDate = draft.startDate
            event.endDate = draft.endDate
            event.allDay = draft.allDay
            event.recurrence = draft.recurrence
            event.remindMinutesBefore = draft.remindMinutesBefore
            event.linkedEntityIds = draft.linkedEntityIds
            event.linkedEntityTypes = draft.linkedEntityTypes
            event.touch()
        }
        
        try? modelContext.save()
    }
    
    private func deleteActiveEvent() {
        guard let event = activeEvent else { return }
        modelContext.delete(event)
        try? modelContext.save()
        withAnimation(calendarAnimation) {
            eventDrawerVisible = false
        }
        resetEventDrawerState()
    }
    
    private func cancelEventEditing() {
        resetEventDrawerState()
    }
    
    private func resetEventDrawerState() {
        pendingEventDraft = nil
        activeEvent = nil
        isCreatingEvent = false
    }
    
    private func askAuroraForEventSuggestions(using draft: CalendarEventDraft) {
        var payload: [String: Any] = [
            "intent": "scheduleEvent",
            "title": draft.title,
            "allDay": draft.allDay
        ]
        let isoFormatter = ISO8601DateFormatter()
        payload["startDate"] = isoFormatter.string(from: draft.startDate)
        payload["endDate"] = isoFormatter.string(from: draft.endDate)
        if !draft.location.isEmpty {
            payload["location"] = draft.location
        }
        if !draft.notes.isEmpty {
            payload["notes"] = draft.notes
        }
        if let recurrence = draft.recurrence {
            payload["recurrence"] = recurrence.frequency.rawValue
        }
        
        NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.aiAssistant)
        NotificationCenter.default.post(name: .openAIAssistantThread, object: payload)
    }
    
    private func launchComposer(with payload: CalendarComposerRequest?) {
        composerRequest = payload
        showingComposer = true
    }
    
    private func mapComposerNotification(_ notification: Notification) -> CalendarComposerRequest {
        if let request = notification.object as? CalendarComposerRequest {
            return request
        }
        
        if let post = notification.object as? CloutmateShared.Post {
            return CalendarComposerRequest(existingPost: post, prefilledDate: post.scheduledDate)
        }
        
        if let date = notification.object as? Date {
            return CalendarComposerRequest(prefilledDate: date)
        }
        
        return CalendarComposerRequest()
        }
    
    private func handleDayItemSelection(_ kind: CalendarDayDetailDrawer.Item.Kind) {
        withAnimation(calendarAnimation) {
            dayDrawerVisible = false
        }
        
        switch kind {
        case .post(let post):
            openPostDrawer(for: post)
        case .artifact(let artifact):
            openArtifactDrawer(for: artifact)
        case .task(let task):
            openTaskDrawer(for: task)
        case .event(let occurrence):
            openEventDrawer(for: occurrence)
        }
    }
    
    private func itemsForDate(_ date: Date) -> [CalendarDayDetailDrawer.Item] {
        var items: [CalendarDayDetailDrawer.Item] = []
        
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
        items.append(contentsOf: dayPosts.map { CalendarDayDetailDrawer.Item.post($0) })
        
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
        items.append(contentsOf: dayArtifacts.map { CalendarDayDetailDrawer.Item.artifact($0) })
        
        // Add tasks
        let dayTasks = tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: date)
        }
        items.append(contentsOf: dayTasks.map { CalendarDayDetailDrawer.Item.task($0) })
        
        // Add calendar events (including recurrences)
        let dayInterval = DateInterval(
            start: calendar.startOfDay(for: date),
            end: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        )
        let dayOccurrences = CalendarEventOccurrenceService.shared.occurrences(for: events, in: dayInterval)
        items.append(contentsOf: dayOccurrences.map { CalendarDayDetailDrawer.Item.event($0) })
        
        items.sort { lhs, rhs in
            switch (lhs.timestamp, rhs.timestamp) {
            case let (l?, r?):
                return l < r
            case (nil, nil):
                return lhs.title < rhs.title
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            }
        }
        
        return items
    }
}

struct UnifiedWeeklyCalendarView: View {
    let posts: [CloutmateShared.Post]
    let artifacts: [CloutmateShared.Artifact]
    let tasks: [CloutmateShared.Task]
    let events: [CalendarEvent]
    @Binding var selectedDate: Date
    let onOpenDay: (Date) -> Void
    let onOpenPost: (CloutmateShared.Post) -> Void
    let onOpenArtifact: (CloutmateShared.Artifact) -> Void
    let onOpenTask: (CloutmateShared.Task) -> Void
    let onOpenEvent: (CalendarEventOccurrence) -> Void
    let onCompose: (CalendarComposerRequest?) -> Void
    
    @State private var displayedWeek = Date()
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 0) {
            CalendarHeaderView(
                title: weekRangeText,
                onPrevious: previousWeek,
                onNext: nextWeek,
                onQuickAction: {
                    onCompose(CalendarComposerRequest(prefilledDate: selectedDate))
                }
            )
            .glassPanel(tier: .overlay, cornerRadius: 12)
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(weekDays, id: \.self) { date in
                        UnifiedDayColumn(
                            date: date,
                            items: itemsForDate(date),
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            onPostClick: onOpenPost,
                            onArtifactClick: onOpenArtifact,
                            onTaskClick: onOpenTask,
                            onEventClick: onOpenEvent,
                            onDoubleTap: {
                                onCompose(CalendarComposerRequest(prefilledDate: date))
                            },
                            onDaySelected: {
                                selectedDate = date
                                onOpenDay(date)
                            }
                        )
                    }
                }
                .padding()
            }
            .background(Color.clear)
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
        if let endDate = calendar.date(byAdding: .day, value: 6, to: weekInterval.start) {
            formatter.dateFormat = calendar.component(.year, from: endDate) == calendar.component(.year, from: weekInterval.start) ? "d, yyyy" : "MMM d, yyyy"
            let end = formatter.string(from: endDate)
            return "\(start) - \(end)"
        }
        return start
    }
    
    private func itemsForDate(_ date: Date) -> [CalendarItem] {
        var items: [CalendarItem] = []
        
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
        
        let dayTasks = tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: date)
        }
        items.append(contentsOf: dayTasks.map { CalendarItem.task($0) })
        
        let dayInterval = DateInterval(
            start: calendar.startOfDay(for: date),
            end: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        )
        let occurrences = CalendarEventOccurrenceService.shared.occurrences(for: events, in: dayInterval)
        items.append(contentsOf: occurrences.map { CalendarItem.event($0) })
        
        items.sort { $0.time < $1.time }
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
    let tasks: [CloutmateShared.Task]
    let events: [CalendarEvent]
    @Binding var selectedDate: Date
    let onOpenDay: (Date) -> Void
    let onOpenPost: (CloutmateShared.Post) -> Void
    let onOpenArtifact: (CloutmateShared.Artifact) -> Void
    let onOpenTask: (CloutmateShared.Task) -> Void
    let onOpenEvent: (CalendarEventOccurrence) -> Void
    let onCompose: (CalendarComposerRequest?) -> Void
    
    @State private var currentMonth = Date()
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 0) {
            CalendarHeaderView(
                title: monthText,
                onPrevious: previousMonth,
                onNext: nextMonth,
                onQuickAction: {
                    onCompose(CalendarComposerRequest(prefilledDate: selectedDate))
                }
            )
            .glassPanel(tier: .overlay, cornerRadius: 12)
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            ScrollView {
                VStack(spacing: 8) {
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
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                        ForEach(calendarDays, id: \.self) { date in
                            CalendarDayCellV2(
                                date: date,
                                items: itemsForDate(date),
                                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                isCurrentMonth: calendar.component(.month, from: date) == calendar.component(.month, from: currentMonth),
                                onTap: {
                                        selectedDate = date
                                    onOpenDay(date)
                                },
                                onPostTap: onOpenPost,
                                onArtifactTap: onOpenArtifact,
                                onTaskTap: onOpenTask,
                                onEventTap: onOpenEvent,
                                onCompose: {
                                    onCompose(CalendarComposerRequest(prefilledDate: date))
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
    }
    
    private var calendarDays: [Date] {
        guard let firstDayOfMonth = calendar.dateInterval(of: .month, for: currentMonth)?.start else {
            return []
        }
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let daysToSubtract = firstWeekday - 1
        guard let startDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: firstDayOfMonth) else {
            return []
        }
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
        
        let dayTasks = tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: date)
        }
        items.append(contentsOf: dayTasks.map { CalendarItem.task($0) })
        
        let dayInterval = DateInterval(
            start: calendar.startOfDay(for: date),
            end: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        )
        let occurrences = CalendarEventOccurrenceService.shared.occurrences(for: events, in: dayInterval)
        items.append(contentsOf: occurrences.map { CalendarItem.event($0) })
        
        items.sort { $0.time < $1.time }
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
    case task(CloutmateShared.Task)
    case event(CalendarEventOccurrence)
    
    var id: String {
        switch self {
        case .post(let post):
            return post.id.uuidString
        case .artifact(let artifact):
            return artifact.id.uuidString
        case .task(let task):
            return task.id.uuidString
        case .event(let occurrence):
            return occurrence.id
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
        case .event(let occurrence):
            return occurrence.startDate
        }
    }
}

struct UnifiedDayColumn: View {
    let date: Date
    let items: [CalendarItem]
    let isSelected: Bool
    var onPostClick: ((CloutmateShared.Post) -> Void)?
    var onArtifactClick: ((CloutmateShared.Artifact) -> Void)?
    var onTaskClick: ((CloutmateShared.Task) -> Void)?
    var onEventClick: ((CalendarEventOccurrence) -> Void)?
    var onDoubleTap: (() -> Void)?
    var onDaySelected: (() -> Void)?
    
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
                    let eventCount = items.filter { if case .event = $0 { return true }; return false }.count
                    
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
                    
                    if eventCount > 0 {
                        Text("\(eventCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.cyan)
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
            case .event(let occurrence):
                EventCard(occurrence: occurrence, onTap: {
                    onEventClick?(occurrence)
                    })
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onDaySelected?()
        }
        .onTapGesture(count: 2) {
            onDoubleTap?()
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
    let task: CloutmateShared.Task
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

struct EventCard: View {
    let occurrence: CalendarEventOccurrence
    var onTap: (() -> Void)?
    
    @State private var isHovering = false
    
    private var event: CalendarEvent {
        occurrence.event
    }
    
    private var timeRangeText: String {
        if event.allDay {
            return "All-day"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "\(formatter.string(from: occurrence.startDate)) – \(formatter.string(from: occurrence.endDate))"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .foregroundColor(.cyan)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title.isEmpty ? "Untitled Event" : event.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                HStack(spacing: 6) {
                    Label(timeRangeText, systemImage: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "mappin.and.ellipse")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                if event.recurrence != nil {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.2.squarepath")
                            .font(.caption2)
                        Text("Repeating")
                            .font(.caption2)
                    }
                    .foregroundColor(.cyan)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(isHovering ? 0.18 : 0.12),
                            Color.cyan.opacity(isHovering ? 0.1 : 0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cyan.opacity(isHovering ? 0.35 : 0.2), lineWidth: isHovering ? 1.5 : 1)
        )
        .shadow(color: Color.cyan.opacity(isHovering ? 0.25 : 0.08), radius: isHovering ? 6 : 3, y: isHovering ? 3 : 1)
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
