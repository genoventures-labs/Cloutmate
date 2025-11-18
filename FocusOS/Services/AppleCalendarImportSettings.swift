//
//  AppleCalendarImportSettings.swift
//  FocusOS
//
//  User preferences for Apple Calendar import behavior
//

import Foundation
import Combine

@MainActor
final class AppleCalendarImportSettings: ObservableObject {
    static let shared = AppleCalendarImportSettings()
    
    private struct Keys {
        static let importEnabled = "appleCalendarImport.enabled"
        static let selectedCalendarIds = "appleCalendarImport.selectedCalendarIds"
        static let syncInterval = "appleCalendarImport.syncInterval"
        static let importRangeDaysForward = "appleCalendarImport.importRangeDaysForward"
        static let importRangeDaysBack = "appleCalendarImport.importRangeDaysBack"
        static let autoColorize = "appleCalendarImport.autoColorize"
        static let lastSyncDate = "appleCalendarImport.lastSyncDate"
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
    
    var selectedCalendarIds: [String] {
        get {
            UserDefaults.standard.stringArray(forKey: Keys.selectedCalendarIds) ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.selectedCalendarIds)
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
    
    var importRangeDaysBack: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: Keys.importRangeDaysBack)
            return stored > 0 ? stored : 30 // Default: 30 days back
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.importRangeDaysBack)
            objectWillChange.send()
        }
    }
    
    var autoColorize: Bool {
        get {
            UserDefaults.standard.object(forKey: Keys.autoColorize) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.autoColorize)
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

