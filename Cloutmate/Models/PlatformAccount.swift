//
//  PlatformAccount.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData

@Model
final class PlatformAccount {
    var id: UUID = UUID()
    var platform: String = "" // Platform raw value
    var accountID: String = "" // Meta API account ID
    var username: String = ""
    var displayName: String?
    var profileImageURL: String?
    var createdAt: Date = Date()
    var lastSyncedAt: Date?
    
    init(
        platform: String,
        accountID: String,
        username: String,
        displayName: String? = nil,
        profileImageURL: String? = nil
    ) {
        self.id = UUID()
        self.platform = platform
        self.accountID = accountID
        self.username = username
        self.displayName = displayName
        self.profileImageURL = profileImageURL
        self.createdAt = Date()
    }
    
    var accountPlatform: Platform? {
        Platform(rawValue: platform)
    }
    
    func updateLastSynced() {
        lastSyncedAt = Date()
    }
}

