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
    
    @Environment(\.modelContext) private var modelContext
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
            HStack(spacing: 0) {
                accentSidebar
                VStack(spacing: 0) {
                    header
                        .padding()
                        .background(.ultraThinMaterial)
                    
                    Divider()
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            titleSection
                            scheduleSection
                            recurrenceSection
                            reminderSection
                            notesSection
                            automationSection
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 24)
                    }
                    .background(glassColorSystem.backgroundColor())
                    
                    Divider()
                    
                    footer
                        .padding(16)
                        .background(glassColorSystem.toolbarColor())
                }
            }
            .background(glassColorSystem.backgroundColor())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        closeDrawerAnimated()
                        onCancel()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                }
            }
        }
        .frame(minWidth: 520, minHeight: 560)
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
    
    private var accentSidebar: some View {
        LinearGradient(
            colors: [.kosmicBlue.opacity(0.9), .kosmicPurple.opacity(0.65)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: 4)
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(mode == .create ? "New Event" : "Edit Event")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(glassColorSystem.textPrimary())
            
            Text("\(formattedHeaderDate)")
                .font(.caption)
                .foregroundColor(glassColorSystem.textSecondary())
        }
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Event title", text: $draft.title)
                .textFieldStyle(.plain)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(glassColorSystem.textPrimary())
                .focused($titleFieldFocused)
            
            TextField("Location", text: $draft.location)
                .textFieldStyle(.roundedBorder)
                .foregroundColor(glassColorSystem.textSecondary())
        }
    }
    
    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Schedule")
            
            Toggle(isOn: $draft.allDay) {
                Label("All-day event", systemImage: "sun.max.fill")
            }
            .toggleStyle(.switch)
            .foregroundColor(glassColorSystem.textSecondary())
            .onChange(of: draft.allDay) { _, newValue in
                if newValue {
                    draft.startDate = calendar.startOfDay(for: draft.startDate)
                    draft.endDate = calendar.date(byAdding: .day, value: 1, to: draft.startDate) ?? draft.startDate.addingTimeInterval(86400)
                }
            }
            
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    DatePicker(
                        "Starts",
                        selection: $draft.startDate,
                        displayedComponents: draft.allDay ? [.date] : [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    
                    DatePicker(
                        "Ends",
                        selection: $draft.endDate,
                        in: draft.startDate...,
                        displayedComponents: draft.allDay ? [.date] : [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
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
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Recurrence")
            
            Picker("Repeat", selection: Binding(
                get: { recurrenceOption },
                set: { newValue in
                    applyRecurrenceOption(newValue)
                }
            )) {
                ForEach(RecurrenceOption.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)
            
            if draft.recurrence != nil {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $recurrenceEndEnabled.animation()) {
                        Label("Set end date", systemImage: "calendar.badge.exclamationmark")
                    }
                    .toggleStyle(.switch)
                    .foregroundColor(glassColorSystem.textSecondary())
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
    
    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Reminder")
            
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
                    Image(systemName: "bell.fill")
                    Text(reminderLabel)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(glassColorSystem.cardColor())
                .cornerRadius(8)
            }
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Notes")
            
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
            .frame(minHeight: 140)
            .background(glassColorSystem.cardColor())
            .cornerRadius(10)
        }
    }
    
    private var automationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Aurora Assistance")
            
            Text("Let Aurora suggest ideal scheduling or adjust recurrence based on your patterns.")
                .font(.caption)
                .foregroundColor(glassColorSystem.textSecondary())
            
            Button {
                onAskAurora?()
            } label: {
                Label("Ask Aurora to schedule", systemImage: "sparkles")
                    .font(.caption)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            }
            .buttonStyle(.plain)
            .disabled(onAskAurora == nil)
        }
    }
    
    private var footer: some View {
        HStack {
            if mode == .edit {
                Button(role: .destructive) {
                    onDelete?()
                    closeDrawerAnimated()
                } label: {
                    Label("Delete Event", systemImage: "trash")
                }
                .buttonStyle(.borderless)
            }
            
            Spacer()
            
            Button("Cancel") {
                closeDrawerAnimated()
                onCancel()
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
            
            Button {
                onCommit(draft)
                closeDrawerAnimated()
            } label: {
                Text(mode == .create ? "Save Event" : "Update Event")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(draft.canCommit ? glassColorSystem.accentGradient() : Color.gray.opacity(0.2))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(!draft.canCommit)
        }
    }
    
    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(glassColorSystem.textSecondary())
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

