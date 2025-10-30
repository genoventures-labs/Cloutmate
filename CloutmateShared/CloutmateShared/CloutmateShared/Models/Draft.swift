//
//  Draft.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData

@Model
public final class Draft {
    public var id: UUID = UUID()
    public var caption: String = ""
    public var mediaURLs: [String] = []
    public var tags: [String] = []
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var notes: String?
    
    // Draft lifecycle tracking
    public var associatedPostID: UUID?
    public var convertedAt: Date?
    public var scheduledOrPublishedDate: Date?
    public var isArchived: Bool = false
    
    public init(
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
    
    public func toPost(platforms: [Platform], scheduledDate: Date?) -> Post {
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

