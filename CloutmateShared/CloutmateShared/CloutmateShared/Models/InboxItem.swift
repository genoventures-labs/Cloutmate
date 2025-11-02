//
//  InboxItem.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData

@Model
public final class InboxItem {
    public var id: UUID = UUID()
    public var content: String = ""
    public var itemType: String = "text" // text, image, file, url
    public var fileURL: String?
    public var createdAt: Date = Date()
    public var convertedToType: String? // task, note, post, project
    public var convertedToId: UUID?
    public var convertedAt: Date?
    
    public init(
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

