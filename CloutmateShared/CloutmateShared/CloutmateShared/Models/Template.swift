//
//  Template.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData

@Model
public final class Template {
    public var id: UUID = UUID()
    public var name: String = ""
    public var caption: String = ""
    public var platforms: [String] = [] // Array of Platform raw values
    public var tags: [String] = []
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    
    public init(
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
    
    public var templatePlatforms: [Platform] {
        get { platforms.compactMap { Platform(rawValue: $0) } }
        set { platforms = newValue.map { $0.rawValue } }
    }
}

