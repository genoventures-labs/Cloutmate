//
//  TodoistImportSettings.swift
//  FocusOS
//
//  User preferences for Todoist import behavior
//

import Foundation
import Combine

@MainActor
final class TodoistImportSettings: ObservableObject {
    static let shared = TodoistImportSettings()
    
    private struct Keys {
        static let importEnabled = "todoistImport.enabled"
        static let selectedProjectIds = "todoistImport.selectedProjectIds"
        static let syncInterval = "todoistImport.syncInterval"
        static let importCompletedTasks = "todoistImport.importCompletedTasks"
        static let lastSyncDate = "todoistImport.lastSyncDate"
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
    
    var selectedProjectIds: [String] {
        get {
            UserDefaults.standard.stringArray(forKey: Keys.selectedProjectIds) ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.selectedProjectIds)
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
    
    var importCompletedTasks: Bool {
        get {
            UserDefaults.standard.object(forKey: Keys.importCompletedTasks) as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.importCompletedTasks)
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
    
    // Token access (stored in Keychain, not UserDefaults)
    var accessToken: String? {
        get {
            try? KeychainService.shared.getToken(forAccount: "todoist_access_token")
        }
    }
    
    var refreshToken: String? {
        get {
            try? KeychainService.shared.getToken(forAccount: "todoist_refresh_token")
        }
    }
    
    func storeTokens(accessToken: String, refreshToken: String?) throws {
        try KeychainService.shared.storeToken(accessToken, forAccount: "todoist_access_token")
        if let refreshToken = refreshToken {
            try KeychainService.shared.storeToken(refreshToken, forAccount: "todoist_refresh_token")
        }
        objectWillChange.send()
    }
    
    func clearTokens() {
        try? KeychainService.shared.deleteToken(forAccount: "todoist_access_token")
        try? KeychainService.shared.deleteToken(forAccount: "todoist_refresh_token")
        objectWillChange.send()
    }
    
    var isConnected: Bool {
        return accessToken != nil
    }
    
    private init() {}
}

