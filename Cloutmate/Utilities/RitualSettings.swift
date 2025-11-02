//
//  RitualSettings.swift
//  Cloutmate
//
//  Phase 8: Cognitive Loop Completion
//  Hybrid persistence wrapper for ritual scheduling, nudges, and review settings
//

import Foundation
import Combine

@MainActor
final class RitualSettings {
    static let shared = RitualSettings()

    private enum Keys {
        static let morningSeconds = "ritual.morning.seconds"
        static let eveningSeconds = "ritual.evening.seconds"
        static let weeklyReviewDay = "ritual.weeklyReview.day"
        static let weeklyReviewSeconds = "ritual.weeklyReview.seconds"
        static let nudgesEnabled = "ritual.nudges.enabled"
        static let delayFatigue = "ritual.nudges.delayFatigue"
        static let nudgeIntensity = "ritual.nudges.intensity"
        static let maxNudges = "ritual.nudges.maxPerDay"
        static let minInterval = "ritual.nudges.minInterval"
        static let quietStart = "ritual.nudges.quietStart"
        static let quietEnd = "ritual.nudges.quietEnd"
        static let nudgeCategory = "ritual.nudges.category."
    }

    private let defaults: UserDefaults
    let settingsDidChange = PassthroughSubject<Void, Never>()

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaults()
    }

    // MARK: - Registration

    private func registerDefaults() {
        defaults.register(defaults: [
            Keys.morningSeconds: RitualSettings.secondsFrom(hour: 8, minute: 0),
            Keys.eveningSeconds: RitualSettings.secondsFrom(hour: 18, minute: 0),
            Keys.weeklyReviewDay: 1, // Sunday
            Keys.weeklyReviewSeconds: RitualSettings.secondsFrom(hour: 19, minute: 0),
            Keys.nudgesEnabled: true,
            Keys.delayFatigue: true,
            Keys.nudgeIntensity: 0.7,
            Keys.maxNudges: 3,
            Keys.minInterval: 3600.0
        ])

        for trigger in SmartNudgeTrigger.allCases {
            defaults.register(defaults: [Keys.nudgeCategory + trigger.rawValue: true])
        }
    }

    // MARK: - Ritual Scheduling

    var morningTime: DateComponents {
        get { Self.components(from: defaults.double(forKey: Keys.morningSeconds)) }
        set {
            defaults.set(Self.seconds(from: newValue), forKey: Keys.morningSeconds)
            notifyChange()
        }
    }

    var eveningTime: DateComponents {
        get { Self.components(from: defaults.double(forKey: Keys.eveningSeconds)) }
        set {
            defaults.set(Self.seconds(from: newValue), forKey: Keys.eveningSeconds)
            notifyChange()
        }
    }

    var weeklyReviewDay: Int {
        get { defaults.integer(forKey: Keys.weeklyReviewDay) }
        set {
            defaults.set(newValue, forKey: Keys.weeklyReviewDay)
            notifyChange()
        }
    }

    var weeklyReviewTime: DateComponents {
        get { Self.components(from: defaults.double(forKey: Keys.weeklyReviewSeconds)) }
        set {
            defaults.set(Self.seconds(from: newValue), forKey: Keys.weeklyReviewSeconds)
            notifyChange()
        }
    }

    func updateMorningTime(hour: Int, minute: Int) {
        morningTime = DateComponents(hour: hour, minute: minute)
    }

    func updateEveningTime(hour: Int, minute: Int) {
        eveningTime = DateComponents(hour: hour, minute: minute)
    }

    func updateWeeklyReview(day: Int, hour: Int, minute: Int) {
        weeklyReviewDay = day
        weeklyReviewTime = DateComponents(hour: hour, minute: minute)
    }

    func nextWindow(for type: FocusRitualType, after date: Date = Date()) -> (start: Date, end: Date) {
        let components: DateComponents
        let window: TimeInterval

        switch type {
        case .morning:
            components = morningTime
            window = 90 * 60
        case .evening:
            components = eveningTime
            window = 90 * 60
        }

        let calendar = Calendar.current
        let next = calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTimePreservingSmallerComponents) ?? calendar.date(bySettingHour: components.hour ?? 8, minute: components.minute ?? 0, second: 0, of: date) ?? date
        let end = next.addingTimeInterval(window)
        return (next, end)
    }

    // MARK: - Nudges

    var nudgesEnabled: Bool {
        get { defaults.bool(forKey: Keys.nudgesEnabled) }
        set {
            defaults.set(newValue, forKey: Keys.nudgesEnabled)
            notifyChange()
        }
    }

    var delayPromptsWhenFatigued: Bool {
        get { defaults.bool(forKey: Keys.delayFatigue) }
        set {
            defaults.set(newValue, forKey: Keys.delayFatigue)
            notifyChange()
        }
    }

    var nudgeIntensity: Double {
        get { defaults.double(forKey: Keys.nudgeIntensity) }
        set {
            defaults.set(newValue, forKey: Keys.nudgeIntensity)
            notifyChange()
        }
    }

    var maxNudgesPerDay: Int {
        get {
            let value = defaults.integer(forKey: Keys.maxNudges)
            return value > 0 ? value : 3
        }
        set {
            defaults.set(newValue, forKey: Keys.maxNudges)
            notifyChange()
        }
    }

    var minimumNudgeInterval: TimeInterval {
        get {
            let value = defaults.double(forKey: Keys.minInterval)
            return value > 0 ? value : 3600
        }
        set {
            defaults.set(newValue, forKey: Keys.minInterval)
            notifyChange()
        }
    }

    func isNudgeCategoryEnabled(_ trigger: SmartNudgeTrigger) -> Bool {
        defaults.bool(forKey: Keys.nudgeCategory + trigger.rawValue)
    }

    func setNudgeCategory(_ trigger: SmartNudgeTrigger, enabled: Bool) {
        defaults.set(enabled, forKey: Keys.nudgeCategory + trigger.rawValue)
        notifyChange()
    }

    // MARK: - Quiet Hours

    var quietHoursStart: TimeInterval? {
        get {
            let value = defaults.double(forKey: Keys.quietStart)
            return value > 0 ? value : nil
        }
        set {
            if let newValue = newValue {
                defaults.set(newValue, forKey: Keys.quietStart)
            } else {
                defaults.removeObject(forKey: Keys.quietStart)
            }
            notifyChange()
        }
    }

    var quietHoursEnd: TimeInterval? {
        get {
            let value = defaults.double(forKey: Keys.quietEnd)
            return value > 0 ? value : nil
        }
        set {
            if let newValue = newValue {
                defaults.set(newValue, forKey: Keys.quietEnd)
            } else {
                defaults.removeObject(forKey: Keys.quietEnd)
            }
            notifyChange()
        }
    }

    func updateQuietHours(startHour: Int?, startMinute: Int?, endHour: Int?, endMinute: Int?) {
        if let hour = startHour, let minute = startMinute {
            quietHoursStart = RitualSettings.secondsFrom(hour: hour, minute: minute)
        } else {
            quietHoursStart = nil
        }

        if let hour = endHour, let minute = endMinute {
            quietHoursEnd = RitualSettings.secondsFrom(hour: hour, minute: minute)
        } else {
            quietHoursEnd = nil
        }
    }

    func isWithinQuietHours(_ date: Date) -> Bool {
        guard let start = quietHoursStart, let end = quietHoursEnd else { return false }
        let seconds = Self.secondsSinceMidnight(for: date)

        if start <= end {
            return seconds >= start && seconds <= end
        } else {
            // Wraps past midnight
            return seconds >= start || seconds <= end
        }
    }

    // MARK: - Weekly Review Scheduling

    func nextWeeklyReview(after date: Date = Date()) -> Date {
        var components = DateComponents()
        components.weekday = weeklyReviewDay
        components.hour = weeklyReviewTime.hour
        components.minute = weeklyReviewTime.minute

        let calendar = Calendar.current
        return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTimePreservingSmallerComponents) ?? date
    }

    // MARK: - Helpers

    private func notifyChange() {
        settingsDidChange.send(())
    }

    private static func secondsFrom(hour: Int, minute: Int) -> TimeInterval {
        TimeInterval(hour * 3600 + minute * 60)
    }

    private static func seconds(from components: DateComponents) -> TimeInterval {
        secondsFrom(hour: components.hour ?? 0, minute: components.minute ?? 0)
    }

    private static func components(from seconds: TimeInterval) -> DateComponents {
        let totalSeconds = Int(seconds)
        let hour = totalSeconds / 3600
        let minute = (totalSeconds % 3600) / 60
        return DateComponents(hour: hour, minute: minute)
    }

    private static func secondsSinceMidnight(for date: Date) -> TimeInterval {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        return TimeInterval(components.hour ?? 0) * 3600 + TimeInterval(components.minute ?? 0) * 60 + TimeInterval(components.second ?? 0)
    }
}


