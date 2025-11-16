//
//  CalendarEventDrawer.swift
//  Cloutmate
//
//  Created by Assistant on 11/12/25.
//

import SwiftUI
import SwiftData
import CloutmateShared

struct CalendarEventDraft: Equatable {
    var title: String
    var location: String
    var notes: String
    var startDate: Date
    var endDate: Date
    var allDay: Bool
    var recurrence: EventRecurrence?
    var remindMinutesBefore: Int?
    var linkedEntityIds: [UUID]
    var linkedEntityTypes: [String]
    
    init(
        title: String = "",
        location: String = "",
        notes: String = "",
        startDate: Date = Date(),
        endDate: Date = Date().addingTimeInterval(60 * 60),
        allDay: Bool = false,
        recurrence: EventRecurrence? = nil,
        remindMinutesBefore: Int? = nil,
        linkedEntityIds: [UUID] = [],
        linkedEntityTypes: [String] = []
    ) {
        self.title = title
        self.location = location
        self.notes = notes
        self.startDate = startDate
        self.endDate = endDate
        self.allDay = allDay
        self.recurrence = recurrence
        self.remindMinutesBefore = remindMinutesBefore
        self.linkedEntityIds = linkedEntityIds
        self.linkedEntityTypes = linkedEntityTypes
    }
    
    init(event: CalendarEvent) {
        self.init(
            title: event.title,
            location: event.location ?? "",
            notes: event.notes ?? "",
            startDate: event.startDate,
            endDate: event.endDate,
            allDay: event.allDay,
            recurrence: event.recurrence,
            remindMinutesBefore: event.remindMinutesBefore,
            linkedEntityIds: event.linkedEntityIds,
            linkedEntityTypes: event.linkedEntityTypes
        )
    }
    
    var canCommit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        endDate >= startDate
    }
}

struct CalendarEventDrawer: View {
    enum Mode {
        case create
        case edit
    }
    
    let mode: Mode
    let existingEvent: CalendarEvent?
    @Binding var isPresented: Bool
    let onCommit: (CalendarEventDraft) -> Void
    let onDelete: (() -> Void)?
    let onCancel: () -> Void
    let onAskAurora: (() -> Void)?
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @State private var draft: CalendarEventDraft
    @FocusState private var titleFieldFocused: Bool
    
    @State private var recurrenceEndEnabled: Bool
    @State private var recurrenceEndDate: Date
    init(
        mode: Mode,
        existingEvent: CalendarEvent?,
        initialDraft: CalendarEventDraft,
        isPresented: Binding<Bool>,
        onCommit: @escaping (CalendarEventDraft) -> Void,
        onDelete: (() -> Void)? = nil,
        onCancel: @escaping () -> Void,
        onAskAurora: (() -> Void)? = nil
    ) {
        self.mode = mode
        self.existingEvent = existingEvent
        self._isPresented = isPresented
        self.onCommit = onCommit
        self.onDelete = onDelete
        self.onCancel = onCancel
        self.onAskAurora = onAskAurora
        _draft = State(initialValue: initialDraft)
        let recurrenceEnd = initialDraft.recurrence?.endDate ?? Calendar.current.date(byAdding: .month, value: 3, to: initialDraft.endDate) ?? initialDraft.endDate
        _recurrenceEndDate = State(initialValue: recurrenceEnd)
        _recurrenceEndEnabled = State(initialValue: initialDraft.recurrence?.endDate != nil)
    }
    
    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.kosmicBlue,
                Color.kosmicPurple
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var recurrenceOption: RecurrenceOption {
        guard let recurrence = draft.recurrence else {
            return .none
        }
        switch recurrence.frequency {
        case .daily:
            return .daily
        case .weekly:
            return recurrence.interval == 2 ? .biWeekly : .weekly
        case .monthly:
            return .monthly
        case .yearly:
            return .yearly
        }
    }
    
    var body: some View {
        NavigationStack {
            V2DrawerScaffold(
                accentGradient: accentGradient,
                showsSidebar: false,
                header: { headerContent },
                content: {
                    scheduleSection
                    recurrenceSection
                    reminderSection
                    notesSection
                    automationSection
                    actionsSection
                },
                sidebar: { EmptyView() }
            )
            .frame(minWidth: 560, minHeight: 580)
            .frame(idealWidth: 780, idealHeight: 660)
        }
        .onEscape { cancel() }
        .onAppear {
            if mode == .create {
                titleFieldFocused = true
            }
        }
    }
    
    private func closeDrawerAnimated() {
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isPresented = false
        }
    }
    
    private func cancel() {
        closeDrawerAnimated()
        onCancel()
    }
    
    private var headerContent: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 14) {
                TextField("Event title", text: $draft.title)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                    .textFieldStyle(.plain)
                    .focused($titleFieldFocused)
                    .drawerFocusGlow()
                
                HStack(spacing: 10) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Location", text: $draft.location)
                        .textFieldStyle(.plain)
                        .foregroundColor(glassColorSystem.textSecondary())
                }
                .drawerFocusGlow()
                
                HStack(spacing: 12) {
                    metadataPill(
                        title: formattedHeaderDate,
                        icon: draft.allDay ? "sun.max.fill" : "clock"
                    )
                    
                    if !draft.location.trimmingCharacters(in: .whitespaces).isEmpty {
                        metadataPill(
                            title: draft.location,
                            icon: "mappin.and.ellipse"
                        )
                    }
                    
                    metadataPill(
                        title: reminderLabel,
                        icon: "bell.fill"
                    )
                }
            }
            
            Spacer(minLength: 24)
            
            VStack(spacing: 12) {
                GlassButton(
                    "Cancel",
                    icon: "xmark",
                    style: .standard,
                    role: .surface
                ) {
                    cancel()
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                GlassButton(
                    mode == .create ? "Create Event" : "Save Changes",
                    icon: "calendar.badge.checkmark",
                    style: .standard,
                    role: .primary
                ) {
                    onCommit(draft)
                    closeDrawerAnimated()
                }
                .disabled(!draft.canCommit)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
    }
    
    private var scheduleSection: some View {
        DrawerSection(title: "Schedule", icon: "calendar") {
            VStack(alignment: .leading, spacing: 18) {
                Toggle(isOn: $draft.allDay) {
                    Label("All-day event", systemImage: "sun.max.fill")
                        .font(.subheadline)
                        .foregroundColor(glassColorSystem.textSecondary())
                }
                .toggleStyle(.switch)
                .onChange(of: draft.allDay) { _, newValue in
                    if newValue {
                        draft.startDate = calendar.startOfDay(for: draft.startDate)
                        draft.endDate = calendar.date(byAdding: .day, value: 1, to: draft.startDate) ?? draft.startDate.addingTimeInterval(86400)
                    }
                }
                
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 16) {
                    GridRow {
                        detailField(title: "Starts") {
                            DatePicker(
                                "",
                                selection: $draft.startDate,
                                displayedComponents: draft.allDay ? [.date] : [.date, .hourAndMinute]
                            )
                            .labelsHidden()
                        }
                        
                        detailField(title: "Ends") {
                            DatePicker(
                                "",
                                selection: $draft.endDate,
                                in: draft.startDate...,
                                displayedComponents: draft.allDay ? [.date] : [.date, .hourAndMinute]
                            )
                            .labelsHidden()
                        }
                    }
                }
                
                if draft.endDate < draft.startDate {
                    Text("End time must be after start time.")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    private var recurrenceSection: some View {
        DrawerSection(title: "Recurrence", icon: "arrow.2.squarepath") {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Repeat", selection: Binding(
                    get: { recurrenceOption },
                    set: { newValue in applyRecurrenceOption(newValue) }
                )) {
                    ForEach(RecurrenceOption.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                
                if draft.recurrence != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $recurrenceEndEnabled.animation()) {
                            Text("Set end date")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(glassColorSystem.textSecondary())
                        }
                        .toggleStyle(.switch)
                        .onChange(of: recurrenceEndEnabled) { _, enabled in
                            if enabled {
                                updateRecurrenceEndDate(recurrenceEndDate)
                            } else {
                                draft.recurrence?.endDate = nil
                            }
                        }
                        
                        if recurrenceEndEnabled {
                            DatePicker(
                                "Ends on",
                                selection: $recurrenceEndDate,
                                in: draft.startDate...,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.compact)
                            .onChange(of: recurrenceEndDate) { _, newValue in
                                updateRecurrenceEndDate(newValue)
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
    
    private var reminderSection: some View {
        DrawerSection(title: "Reminder", icon: "bell.fill") {
            VStack(alignment: .leading, spacing: 10) {
                Menu {
                    Button("None") {
                        draft.remindMinutesBefore = nil
                    }
                    Divider()
                    ForEach(ReminderOption.allCases) { option in
                        Button(option.displayName) {
                            draft.remindMinutesBefore = option.minutesBefore
                        }
                    }
                } label: {
                    HStack {
                        Text(reminderLabel)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(glassColorSystem.cardColor())
                    .cornerRadius(12)
                }
                
                Text("Choose when to receive a notification before the event begins.")
                    .font(.caption)
                    .foregroundColor(glassColorSystem.textSecondary())
            }
        }
    }
    
    private var notesSection: some View {
        DrawerSection(title: "Notes & Mentions", icon: "doc.richtext") {
            MentionTextEditor(
                text: $draft.notes,
                placeholder: "Add context, links, or mentions…",
                excludeObjectId: mode == .edit ? existingEvent?.id : nil,
                excludeObjectType: mode == .edit ? .event : nil,
                onMentionsChanged: { ids, types in
                    draft.linkedEntityIds = ids
                    draft.linkedEntityTypes = types
                }
            )
            .frame(minHeight: 170)
            .drawerFocusGlow()
        }
    }
    
    private var automationSection: some View {
        DrawerSection(title: "Aurora Assistance", icon: "sparkles") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Let Aurora suggest ideal timing or refine recurrence patterns automatically.")
                    .font(.caption)
                    .foregroundColor(glassColorSystem.textSecondary())
                
                GlassButton(
                    "Ask Aurora to schedule",
                    icon: "wand.and.stars",
                    style: .standard,
                    role: .surface
                ) {
                    onAskAurora?()
                }
                .disabled(onAskAurora == nil)
            }
        }
    }
    
    private var actionsSection: some View {
        DrawerSection(title: "Actions", icon: "square.and.arrow.down") {
            HStack {
                if mode == .edit {
                    Button(role: .destructive) {
                        onDelete?()
                        closeDrawerAnimated()
                    } label: {
                        Label("Delete Event", systemImage: "trash")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red.opacity(0.2))
                }
                
                Spacer()
            }
        }
    }
    
    private func applyRecurrenceOption(_ option: RecurrenceOption) {
        switch option {
        case .none:
            draft.recurrence = nil
            recurrenceEndEnabled = false
        case .daily:
            draft.recurrence = EventRecurrence(frequency: .daily)
        case .weekly:
            draft.recurrence = EventRecurrence(frequency: .weekly, interval: 1, weekdays: currentWeekdayArray())
        case .biWeekly:
            draft.recurrence = EventRecurrence(frequency: .weekly, interval: 2, weekdays: currentWeekdayArray())
        case .monthly:
            draft.recurrence = EventRecurrence(frequency: .monthly)
        case .yearly:
            draft.recurrence = EventRecurrence(frequency: .yearly)
        }
        
        if draft.recurrence != nil && recurrenceEndEnabled {
            updateRecurrenceEndDate(recurrenceEndDate)
        }
    }
    
    private func updateRecurrenceEndDate(_ date: Date) {
        guard var recurrence = draft.recurrence else { return }
        recurrence.endDate = date
        draft.recurrence = recurrence
    }
    
    private func currentWeekdayArray() -> [Int] {
        let weekday = calendar.component(.weekday, from: draft.startDate)
        return [weekday]
    }
    
    private var formattedHeaderDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = draft.allDay ? .none : .short
        return formatter.string(from: draft.startDate)
    }
    
    private var reminderLabel: String {
        if let minutes = draft.remindMinutesBefore {
            return ReminderOption(minutesBefore: minutes)?.displayName ?? "\(minutes) min before"
        }
        return "No reminder"
    }
    
    private var calendar: Calendar {
        Calendar.current
    }
    
    private func detailField<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundColor(glassColorSystem.textSecondary())
            content()
        }
    }
    
    private func metadataPill(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.12))
        .clipShape(Capsule())
    }
    
    private enum RecurrenceOption: String, CaseIterable, Identifiable {
        case none
        case daily
        case weekly
        case biWeekly
        case monthly
        case yearly
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .none: return "None"
            case .daily: return "Daily"
            case .weekly: return "Weekly"
            case .biWeekly: return "Bi-Weekly"
            case .monthly: return "Monthly"
            case .yearly: return "Yearly"
            }
        }
    }
    
    private enum ReminderOption: Int, CaseIterable, Identifiable {
        case fiveMinutes = 5
        case fifteenMinutes = 15
        case thirtyMinutes = 30
        case oneHour = 60
        case oneDay = 1440
        
        var id: Int { rawValue }
        
        var minutesBefore: Int {
            rawValue
        }
        
        var displayName: String {
            switch self {
            case .fiveMinutes: return "5 minutes before"
            case .fifteenMinutes: return "15 minutes before"
            case .thirtyMinutes: return "30 minutes before"
            case .oneHour: return "1 hour before"
            case .oneDay: return "1 day before"
            }
        }
        
        init?(minutesBefore: Int) {
            self.init(rawValue: minutesBefore)
        }
    }
}

