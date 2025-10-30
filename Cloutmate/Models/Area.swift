//
//  Area.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData

@Model
final class Area {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String?
    var cadenceSetting: String? // JSON: {weekly: 3, quiet_hours: "21-08"}
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var tags: [String] = []
    
    init(
        title: String,
        notes: String? = nil,
        cadenceSetting: String? = nil,
        tags: [String] = []
    ) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.cadenceSetting = cadenceSetting
        self.createdAt = Date()
        self.updatedAt = Date()
        self.tags = tags
    }
}

