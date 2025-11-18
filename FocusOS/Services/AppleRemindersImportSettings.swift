//
//  AppleRemindersImportSettings.swift
//  FocusOS
//
//  User preferences for Apple Reminders import behavior
//

import Foundation
import Combine

@MainActor
final class AppleRemindersImportSettings: ObservableObject {
    static let shared = AppleRemindersImportSettings()
    
    private struct Keys {
        static let importEnabled = "appleRemindersImport.enabled"
        static let selectedReminderListIds = "appleRemindersImport.selectedReminderListIds"
        static let syncInterval = "appleRemindersImport.syncInterval"
        static let importRangeDaysForward = "appleRemindersImport.importRangeDaysForward"
        static let importCompletedReminders = "appleRemindersImport.importCompletedReminders"
        static let lastSyncDate = "appleRemindersImport.lastSyncDate"
    }
    
    var importEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: Keys.importEnabled) as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.importEnabled)
            objectWillChange.send()
        }
    }
    
    var selectedReminderListIds: [String] {
        get {
            UserDefaults.standard.stringArray(forKey: Keys.selectedReminderListIds) ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.selectedReminderListIds)
            objectWillChange.send()
        }
    }
    
    var syncInterval: TimeInterval {
        get {
            let stored = UserDefaults.standard.double(forKey: Keys.syncInterval)
            return stored > 0 ? stored : 15 * 60 // Default: 15 minutes
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.syncInterval)
            objectWillChange.send()
        }
    }
    
    var importRangeDaysForward: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: Keys.importRangeDaysForward)
            return stored > 0 ? stored : 90 // Default: 90 days forward
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.importRangeDaysForward)
            objectWillChange.send()
        }
    }
    
    var importCompletedReminders: Bool {
        get {
            UserDefaults.standard.object(forKey: Keys.importCompletedReminders) as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.importCompletedReminders)
            objectWillChange.send()
        }
    }
    
    var lastSyncDate: Date? {
        get {
            UserDefaults.standard.object(forKey: Keys.lastSyncDate) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.lastSyncDate)
            objectWillChange.send()
        }
    }
    
    private init() {}
}

