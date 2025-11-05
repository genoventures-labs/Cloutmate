//
//  TemporalIntelligenceSettingsView.swift
//  Cloutmate
//
//  Phase 9B controls for adaptive scheduling, calendar sync, context guard, and momentum loop.
//

import SwiftUI
import EventKit

struct TemporalIntelligenceSettingsView: View {
    @State private var dynamicReflowEnabled = AdaptiveSchedulerSettings.shared.isDynamicReflowEnabled
    @State private var workdayStart = AdaptiveSchedulerSettings.shared.workdayStartHour
    @State private var workdayEnd = AdaptiveSchedulerSettings.shared.workdayEndHour

    @State private var calendarSyncEnabled = CalendarSyncSettings.shared.syncEnabled
    @State private var calendarChoices: [EKCalendar] = []
    @State private var selectedCalendarId = CalendarSyncSettings.shared.calendarIdentifier ?? ""
    @State private var calendarAccessStatus: String = ""

    @State private var contextGuardEnabled = ContextGuardSettings.shared.isGuardEnabled
    @State private var contextSensitivity = ContextGuardSettings.shared.sensitivity
    @State private var baseDelay = ContextGuardSettings.shared.baseDelay

    @State private var momentumAdjustmentsEnabled = MomentumSettings.shared.adjustmentsEnabled

    private let eventStore = EKEventStore()

    var body: some View {
        Form {
            adaptiveSection
            calendarSection
            contextGuardSection
            momentumSection
        }
        .formStyle(.grouped)
        .navigationTitle("Temporal Intelligence")
        .task {
            if calendarSyncEnabled {
                await loadCalendars()
            }
        }
    }

    private var adaptiveSection: some View {
        Section(header: Text("Adaptive Scheduling"), footer: Text("Reflow shifts skipped focus blocks into your next high-energy window.")) {
            Toggle("Enable dynamic reflow", isOn: $dynamicReflowEnabled)
                .onChange(of: dynamicReflowEnabled) { newValue in
                    AdaptiveSchedulerSettings.shared.isDynamicReflowEnabled = newValue
                }

            Stepper(value: $workdayStart, in: 4...12, step: 1) {
                Text("Workday start: \(formattedHour(workdayStart))")
            }
            .onChange(of: workdayStart) { newValue in
                AdaptiveSchedulerSettings.shared.workdayStartHour = newValue
            }

            Stepper(value: $workdayEnd, in: 13...22, step: 1) {
                Text("Workday end: \(formattedHour(workdayEnd))")
            }
            .onChange(of: workdayEnd) { newValue in
                AdaptiveSchedulerSettings.shared.workdayEndHour = newValue
            }
        }
    }

    private var calendarSection: some View {
        Section(header: Text("Calendar Sync"), footer: Text(calendarAccessStatus).foregroundColor(.secondary)) {
            Toggle("Sync focus blocks to macOS Calendar", isOn: $calendarSyncEnabled)
                .onChange(of: calendarSyncEnabled) { newValue in
                    CalendarSyncSettings.shared.syncEnabled = newValue
                    if newValue {
                        Task { await requestAccessAndLoadCalendars() }
                    }
                }

            if calendarSyncEnabled {
                if calendarChoices.isEmpty {
                    ProgressView()
                } else {
                    Picker("Calendar", selection: $selectedCalendarId) {
                        ForEach(calendarChoices, id: \.calendarIdentifier) { calendar in
                            Text(calendar.title).tag(calendar.calendarIdentifier)
                        }
                    }
                    .onChange(of: selectedCalendarId) { newValue in
                        CalendarSyncSettings.shared.calendarIdentifier = newValue
                    }
                }

                Button("Refresh Calendars") {
                    Task { await loadCalendars() }
                }
            }
        }
    }

    private var contextGuardSection: some View {
        Section(header: Text("Context Switch Guard"), footer: Text("Higher sensitivity gives Aurora more authority to pause and check in before you jump between tabs.")) {
            Toggle("Enable guard", isOn: $contextGuardEnabled)
                .onChange(of: contextGuardEnabled) { newValue in
                    ContextGuardSettings.shared.isGuardEnabled = newValue
                }

            VStack(alignment: .leading) {
                HStack {
                    Text("Sensitivity")
                    Spacer()
                    Text(String(format: "%.0f%%", contextSensitivity * 100))
                }
                Slider(value: $contextSensitivity, in: 0.2...0.9, step: 0.05)
                    .onChange(of: contextSensitivity) { newValue in
                        ContextGuardSettings.shared.sensitivity = newValue
                    }
            }

            VStack(alignment: .leading) {
                HStack {
                    Text("Pause length")
                    Spacer()
                    Text(String(format: "%.1fs", baseDelay))
                }
                Slider(value: $baseDelay, in: 1.0...3.0, step: 0.1)
                    .onChange(of: baseDelay) { newValue in
                        ContextGuardSettings.shared.baseDelay = newValue
                    }
            }
        }
    }

    private var momentumSection: some View {
        Section(header: Text("Momentum Feedback"), footer: Text("Let Aurora bias tone and priorities based on your current flow state.").foregroundColor(.secondary)) {
            Toggle("Enable momentum-driven adjustments", isOn: $momentumAdjustmentsEnabled)
                .onChange(of: momentumAdjustmentsEnabled) { newValue in
                    MomentumSettings.shared.adjustmentsEnabled = newValue
                }
        }
    }

    private func formattedHour(_ hour: Int) -> String {
        let comps = DateComponents(hour: hour)
        let date = Calendar.current.date(from: comps) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: date)
    }

    private func requestAccessAndLoadCalendars() async {
        do {
            let granted = try await eventStore.requestAccess(to: .event)
            calendarAccessStatus = granted ? "Calendar access granted" : "Calendar access denied"
            if granted {
                await loadCalendars()
            }
        } catch {
            calendarAccessStatus = "Calendar access failed: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func loadCalendars() async {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .authorized, .fullAccess, .writeOnly:
            let calendars = eventStore.calendars(for: .event).filter { $0.allowsContentModifications }
            calendarChoices = calendars
            if let first = calendars.first, selectedCalendarId.isEmpty {
                selectedCalendarId = first.calendarIdentifier
                CalendarSyncSettings.shared.calendarIdentifier = first.calendarIdentifier
            }
            calendarAccessStatus = calendars.isEmpty ? "No writable calendars found" : ""
        case .notDetermined:
            calendarAccessStatus = "Calendar permission not requested yet"
        case .denied, .restricted:
            calendarAccessStatus = "Calendar access denied"
            calendarChoices = []
        @unknown default:
            calendarAccessStatus = "Unknown calendar authorization state"
        }
    }
}

#Preview {
    NavigationStack {
        TemporalIntelligenceSettingsView()
    }
}


