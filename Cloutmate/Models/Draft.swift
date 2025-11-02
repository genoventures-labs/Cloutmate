//
//  Draft.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData
import CloutmateShared

@Model
final class Draft {
    var id: UUID = UUID()
    var caption: String = ""
    var mediaURLs: [String] = []
    var tags: [String] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var notes: String?
    
    // Draft lifecycle tracking
    var associatedPostID: UUID?
    var convertedAt: Date?
    var scheduledOrPublishedDate: Date?
    var isArchived: Bool = false
    
    init(
        caption: String = "",
        mediaURLs: [String] = [],
        tags: [String] = [],
        notes: String? = nil
    ) {
        self.id = UUID()
        self.caption = caption
        self.mediaURLs = mediaURLs
        self.tags = tags
        self.createdAt = Date()
        self.updatedAt = Date()
        self.notes = notes
        self.isArchived = false
    }
    
    func toPost(platforms: [Platform], scheduledDate: Date?) -> Post {
        let post = Post(
            caption: caption,
            mediaURLs: mediaURLs,
            scheduledDate: scheduledDate,
            platforms: platforms.map { $0.rawValue },
            status: scheduledDate != nil ? PostStatus.scheduled.rawValue : PostStatus.draft.rawValue,
            tags: tags
        )
        return post
    }
}
