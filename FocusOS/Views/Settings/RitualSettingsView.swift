//
//  RitualSettingsView.swift
//  FocusOS
//
//  Phase 8: Cognitive Loop Completion
//  Settings interface for rituals, weekly review, and smart nudges
//

import SwiftUI

struct RitualSettingsView: View {
    @State private var morningTime: Date = Date()
    @State private var eveningTime: Date = Date()
    @State private var weeklyReviewTime: Date = Date()
    @State private var weeklyReviewDay: Int = RitualSettings.shared.weeklyReviewDay
    @State private var nudgesEnabled: Bool = RitualSettings.shared.nudgesEnabled
    @State private var delayFatigue: Bool = RitualSettings.shared.delayPromptsWhenFatigued
    @State private var nudgeIntensity: Double = RitualSettings.shared.nudgeIntensity
    @State private var maxNudges: Int = RitualSettings.shared.maxNudgesPerDay
    @State private var quietHoursEnabled: Bool = RitualSettings.shared.quietHoursStart != nil
    @State private var quietStart: Date = Date()
    @State private var quietEnd: Date = Date()

    private let settings = RitualSettings.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ritualTimingSection
                weeklyReviewSection
                nudgeSettingsSection
                quietHoursSection
            }
            .padding(24)
        }
        .background(Color(.windowBackgroundColor))
        .onAppear(perform: syncState)
        .onChange(of: morningTime) { _, newValue in
            applyMorningTime(newValue)
        }
        .onChange(of: eveningTime) { _, newValue in
            applyEveningTime(newValue)
        }
        .onChange(of: weeklyReviewTime) { _, newValue in
            applyWeeklyReviewTime(newValue)
        }
        .onChange(of: weeklyReviewDay) { _, newValue in
            settings.updateWeeklyReview(day: newValue, hour: components(from: weeklyReviewTime).hour ?? 19, minute: components(from: weeklyReviewTime).minute ?? 0)
        }
        .onChange(of: nudgesEnabled) { _, newValue in
            settings.nudgesEnabled = newValue
        }
        .onChange(of: delayFatigue) { _, newValue in
            settings.delayPromptsWhenFatigued = newValue
        }
        .onChange(of: nudgeIntensity) { _, newValue in
            settings.nudgeIntensity = newValue
        }
        .onChange(of: maxNudges) { _, newValue in
            settings.maxNudgesPerDay = newValue
        }
    }

    // MARK: - Sections

    private var ritualTimingSection: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Daily Ritual Timing")
                    .font(.system(size: 20, weight: .semibold))

                VStack(alignment: .leading, spacing: 10) {
                    Text("Morning Ritual")
                        .font(.system(size: 14, weight: .semibold))
                    DatePicker("", selection: $morningTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                    Text("Aurora nudges focus around this time each morning.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Evening Reflection")
                        .font(.system(size: 14, weight: .semibold))
                    DatePicker("", selection: $eveningTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                    Text("Wind down the day and freeze momentum for tomorrow.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(22)
        }
    }

    private var weeklyReviewSection: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Weekly Review")
                    .font(.system(size: 20, weight: .semibold))

                Picker("Review Day", selection: $weeklyReviewDay) {
                    ForEach(Array(Calendar.current.weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                        Text(symbol).tag(index + 1)
                    }
                }
                .pickerStyle(.segmented)

                DatePicker("Review Time", selection: $weeklyReviewTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)

                Text("Aurora will guide you through weekly reflection at the scheduled time.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(22)
        }
    }

    private var nudgeSettingsSection: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Smart Nudges")
                        .font(.system(size: 20, weight: .semibold))
                    Spacer()
                    Toggle("", isOn: $nudgesEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Nudge Intensity")
                        .font(.system(size: 14, weight: .semibold))
                    Slider(value: $nudgeIntensity, in: 0...1)
                    Text("Aurora calibrates how assertive to be. 0 = whisper, 1 = high-energy coach.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Max nudges per day")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Stepper(value: $maxNudges, in: 1...6) {
                        Text("\(maxNudges)")
                    }
                    .frame(width: 120)
                }

                Toggle("Delay nudges when fatigued", isOn: $delayFatigue)
                    .font(.system(size: 13, weight: .medium))

                VStack(alignment: .leading, spacing: 10) {
                    Text("Nudge Categories")
                        .font(.system(size: 14, weight: .semibold))
                    ForEach(SmartNudgeTrigger.allCases.filter { $0 != .custom }, id: \.self) { trigger in
                        Toggle(triggerDisplayName(trigger), isOn: Binding(
                            get: { settings.isNudgeCategoryEnabled(trigger) },
                            set: { enabled in settings.setNudgeCategory(trigger, enabled: enabled) }
                        ))
                        .font(.system(size: 13))
                    }
                }
            }
            .padding(22)
        }
    }

    private var quietHoursSection: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Quiet Hours")
                        .font(.system(size: 20, weight: .semibold))
                    Spacer()
                    Toggle("", isOn: $quietHoursEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: quietHoursEnabled) { _, enabled in
                            applyQuietHours(enabled: enabled)
                        }
                }

                if quietHoursEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Start")
                                    .font(.system(size: 13, weight: .semibold))
                                DatePicker("", selection: $quietStart, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                            Spacer()
                            VStack(alignment: .leading) {
                                Text("End")
                                    .font(.system(size: 13, weight: .semibold))
                                DatePicker("", selection: $quietEnd, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                        }
                        .onChange(of: quietStart) { _, newValue in
                            settings.updateQuietHours(
                                startHour: components(from: newValue).hour,
                                startMinute: components(from: newValue).minute,
                                endHour: components(from: quietEnd).hour,
                                endMinute: components(from: quietEnd).minute
                            )
                        }
                        .onChange(of: quietEnd) { _, newValue in
                            settings.updateQuietHours(
                                startHour: components(from: quietStart).hour,
                                startMinute: components(from: quietStart).minute,
                                endHour: components(from: newValue).hour,
                                endMinute: components(from: newValue).minute
                            )
                        }

                        Text("Aurora will stay silent during quiet hours unless you explicitly request help.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No quiet hours configured. Nudges stay responsive all day.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(22)
        }
    }

    // MARK: - Helpers

    private func syncState() {
        morningTime = date(from: settings.morningTime)
        eveningTime = date(from: settings.eveningTime)
        weeklyReviewTime = date(from: settings.weeklyReviewTime)

        if let startSeconds = settings.quietHoursStart,
           let endSeconds = settings.quietHoursEnd {
            quietStart = date(fromSeconds: startSeconds)
            quietEnd = date(fromSeconds: endSeconds)
            quietHoursEnabled = true
        } else {
            quietHoursEnabled = false
        }
    }

    private func date(from components: DateComponents) -> Date {
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = components.hour
        dateComponents.minute = components.minute
        return calendar.date(from: dateComponents) ?? Date()
    }

    private func date(fromSeconds seconds: TimeInterval) -> Date {
        let hour = Int(seconds) / 3600
        let minute = (Int(seconds) % 3600) / 60
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }

    private func components(from date: Date) -> DateComponents {
        Calendar.current.dateComponents([.hour, .minute], from: date)
    }

    private func applyMorningTime(_ date: Date) {
        let comps = components(from: date)
        settings.updateMorningTime(hour: comps.hour ?? 8, minute: comps.minute ?? 0)
    }

    private func applyEveningTime(_ date: Date) {
        let comps = components(from: date)
        settings.updateEveningTime(hour: comps.hour ?? 18, minute: comps.minute ?? 0)
    }

    private func applyWeeklyReviewTime(_ date: Date) {
        let comps = components(from: date)
        settings.updateWeeklyReview(day: weeklyReviewDay, hour: comps.hour ?? 19, minute: comps.minute ?? 0)
    }

    private func applyQuietHours(enabled: Bool) {
        if enabled {
            let start = components(from: quietStart)
            let end = components(from: quietEnd)
            settings.updateQuietHours(
                startHour: start.hour,
                startMinute: start.minute,
                endHour: end.hour,
                endMinute: end.minute
            )
        } else {
            settings.updateQuietHours(startHour: nil, startMinute: nil, endHour: nil, endMinute: nil)
        }
    }

    private func triggerDisplayName(_ trigger: SmartNudgeTrigger) -> String {
        switch trigger {
        case .stalePriority: return "Stale high-priority items"
        case .captureVelocityDrop: return "Capture velocity drops"
        case .fatiguedState: return "Extended fatigue protection"
        case .expressOverweight: return "Express vs Distill imbalance"
        case .reflectionReminder: return "Reflection reminders"
        case .custom: return "Custom"
        }
    }
}

#Preview {
    RitualSettingsView()
        .frame(width: 620, height: 720)
}


