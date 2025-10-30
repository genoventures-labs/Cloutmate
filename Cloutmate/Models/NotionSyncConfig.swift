//
//  NotionSyncConfig.swift
//  Cloutmate
//
//  Sync Configuration Model for Notion Integration
//

import Foundation
import SwiftData

@Model
final class NotionSyncConfig {
    var id: UUID = UUID()
    var databaseId: String = ""  // Notion database ID
    var cloutmateType: String = ""  // "Project", "Task", "Note", "Area"
    var propertyMappings: [String: String] = [:]  // Notion property name -> Cloutmate field name
    var isActive: Bool = true
    var syncInterval: TimeInterval = 3600  // 3600 (hourly) or 86400 (daily)
    var lastSyncedAt: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // Store Notion workspace info
    var workspaceId: String?
    var workspaceName: String?
    var databaseTitle: String?
    
    // Sync options
    var autoSync: Bool = true
    var createNewItems: Bool = true
    var updateExistingItems: Bool = true
    var deleteRemovedItems: Bool = false
    
    init(
        databaseId: String,
        cloutmateType: String,
        propertyMappings: [String: String] = [:],
        isActive: Bool = true,
        syncInterval: TimeInterval = 3600
    ) {
        self.id = UUID()
        self.databaseId = databaseId
        self.cloutmateType = cloutmateType
        self.propertyMappings = propertyMappings
        self.isActive = isActive
        self.syncInterval = syncInterval
        self.createdAt = Date()
        self.updatedAt = Date()
        self.autoSync = true
        self.createNewItems = true
        self.updateExistingItems = true
        self.deleteRemovedItems = false
    }
}

// MARK: - Helper Extensions

extension NotionSyncConfig {
    var needsSync: Bool {
        guard isActive && autoSync else { return false }
        
        guard let lastSynced = lastSyncedAt else {
            return true  // Never synced
        }
        
        let timeSinceLastSync = Date().timeIntervalSince(lastSynced)
        return timeSinceLastSync >= syncInterval
    }
    
    func updateLastSync() {
        lastSyncedAt = Date()
        updatedAt = Date()
    }
}

