//
//  MondayImportSettings.swift
//  FocusOS
//
//  User preferences for Monday.com import behavior
//

import Foundation
import Combine

@MainActor
final class MondayImportSettings: ObservableObject {
    static let shared = MondayImportSettings()
    
    private struct Keys {
        static let importEnabled = "mondayImport.enabled"
        static let selectedBoardIds = "mondayImport.selectedBoardIds"
        static let syncInterval = "mondayImport.syncInterval"
        static let importCompletedItems = "mondayImport.importCompletedItems"
        static let lastSyncDate = "mondayImport.lastSyncDate"
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
    
    var selectedBoardIds: [String] {
        get {
            UserDefaults.standard.stringArray(forKey: Keys.selectedBoardIds) ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.selectedBoardIds)
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
            try? KeychainService.shared.getToken(forAccount: "monday_access_token")
        }
    }
    
    func storeTokens(accessToken: String) throws {
        try KeychainService.shared.storeToken(accessToken, forAccount: "monday_access_token")
        objectWillChange.send()
    }
    
    func clearTokens() {
        try? KeychainService.shared.deleteToken(forAccount: "monday_access_token")
        objectWillChange.send()
    }
    
    var isConnected: Bool {
        return accessToken != nil
    }
    
    private init() {}
}

