//
//  UserPreferences.swift
//  Cloutmate
//
//  Stores user-level AI and posting preferences
//

import Foundation
import SwiftData

@Model
final class UserPreferences {
    var id: UUID = UUID()
    var preferredPostingHours: [Int] = [9, 12, 15] // 24h clock suggested hours
    var defaultPlatforms: [String] = [] // Platform.rawValue
    var defaultTone: String = "friendly"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    init() {
        self.id = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}


