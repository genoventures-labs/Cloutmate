//
//  NotionImportSettings.swift
//  FocusOS
//
//  User preferences for Notion import behavior
//

import Foundation
import Combine

@MainActor
final class NotionImportSettings: ObservableObject {
    static let shared = NotionImportSettings()
    
    private struct Keys {
        static let importEnabled = "notionImport.enabled"
        static let selectedDatabaseIds = "notionImport.selectedDatabaseIds"
        static let syncInterval = "notionImport.syncInterval"
        static let importCompletedItems = "notionImport.importCompletedItems"
        static let autoDetectTypes = "notionImport.autoDetectTypes"
        static let lastSyncDate = "notionImport.lastSyncDate"
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
    
    var selectedDatabaseIds: [String] {
        get {
            UserDefaults.standard.stringArray(forKey: Keys.selectedDatabaseIds) ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.selectedDatabaseIds)
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
    
    var importCompletedItems: Bool {
        get {
            UserDefaults.standard.object(forKey: Keys.importCompletedItems) as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.importCompletedItems)
            objectWillChange.send()
        }
    }
    
    var autoDetectTypes: Bool {
        get {
            UserDefaults.standard.object(forKey: Keys.autoDetectTypes) as? Bool ?? true // Default: true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.autoDetectTypes)
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
            try? KeychainService.shared.getToken(forAccount: "notion_access_token")
        }
    }
    
    var refreshToken: String? {
        get {
            try? KeychainService.shared.getToken(forAccount: "notion_refresh_token")
        }
    }
    
    func storeTokens(accessToken: String, refreshToken: String?) throws {
        try KeychainService.shared.storeToken(accessToken, forAccount: "notion_access_token")
        if let refreshToken = refreshToken {
            try KeychainService.shared.storeToken(refreshToken, forAccount: "notion_refresh_token")
        }
        objectWillChange.send()
    }
    
    func clearTokens() {
        try? KeychainService.shared.deleteToken(forAccount: "notion_access_token")
        try? KeychainService.shared.deleteToken(forAccount: "notion_refresh_token")
        objectWillChange.send()
    }
    
    var isConnected: Bool {
        return accessToken != nil
    }
    
    private init() {}
}

