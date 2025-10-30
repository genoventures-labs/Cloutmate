//
//  PlatformAccount.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData

@Model
public final class PlatformAccount {
    public var id: UUID = UUID()
    public var platform: String = "" // Platform raw value
    public var accountID: String = "" // Meta API account ID
    public var username: String = ""
    public var displayName: String?
    public var profileImageURL: String?
    public var createdAt: Date = Date()
    public var lastSyncedAt: Date?
    
    public init(
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
    
    public var accountPlatform: Platform? {
        Platform(rawValue: platform)
    }
    
    public func updateLastSynced() {
        lastSyncedAt = Date()
    }
}

