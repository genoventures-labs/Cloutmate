//
//  Template.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData

@Model
final class Template {
    var id: UUID = UUID()
    var name: String = ""
    var caption: String = ""
    var platforms: [String] = [] // Array of Platform raw values
    var tags: [String] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    init(
        name: String,
        caption: String,
        platforms: [String] = [],
        tags: [String] = []
    ) {
        self.id = UUID()
        self.name = name
        self.caption = caption
        self.platforms = platforms
        self.tags = tags
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var templatePlatforms: [Platform] {
        get { platforms.compactMap { Platform(rawValue: $0) } }
        set { platforms = newValue.map { $0.rawValue } }
    }
    
    func apply(toDraft draft: Draft) {
        draft.caption = caption
        draft.tags = tags
        draft.updatedAt = Date()
    }
}

