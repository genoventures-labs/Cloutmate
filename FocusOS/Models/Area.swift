//
//  Area.swift
//  FocusOS
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData

enum AreaStatus: String, Codable {
    case active = "active"
    case archived = "archived"
    case reviewNeeded = "reviewNeeded"
}

@Model
final class Area {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String?
    var cadenceSetting: String? // JSON: {weekly: 3, quiet_hours: "21-08"}
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var archivedAt: Date?
    var tags: [String] = []
    
    // V2 Extensions
    var statusRaw: String = AreaStatus.active.rawValue
    var categoryIcon: String?
    var colorAccent: String? // "kosmicBlue", "kosmicPurple", "kosmicGreen"
    var lastReviewDate: Date?
    var stabilityScore: Double = 0.0 // Cached stability (0-100)
    
    // Mention linking
    var linkedEntityIds: [UUID] = [] // IDs of mentioned items
    var linkedEntityTypes: [String] = [] // Types of mentioned items
    
    var status: AreaStatus {
        get { AreaStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }
    
    init(
        title: String,
        notes: String? = nil,
        cadenceSetting: String? = nil,
        tags: [String] = [],
        status: AreaStatus = .active,
        categoryIcon: String? = nil,
        colorAccent: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.cadenceSetting = cadenceSetting
        self.createdAt = Date()
        self.updatedAt = Date()
        self.tags = tags
        self.statusRaw = status.rawValue
        self.categoryIcon = categoryIcon
        self.colorAccent = colorAccent
        self.stabilityScore = 0.0
        self.linkedEntityIds = []
        self.linkedEntityTypes = []
    }
}

