//
//  InboxItem.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData

@Model
final class InboxItem {
    var id: UUID = UUID()
    var content: String = ""
    var itemType: String = "text" // text, image, file, url
    var fileURL: String?
    var createdAt: Date = Date()
    var convertedToType: String? // task, note, post, project
    var convertedToId: UUID?
    var convertedAt: Date?
    
    init(
        content: String,
        itemType: String = "text",
        fileURL: String? = nil
    ) {
        self.id = UUID()
        self.content = content
        self.itemType = itemType
        self.fileURL = fileURL
        self.createdAt = Date()
    }
}

