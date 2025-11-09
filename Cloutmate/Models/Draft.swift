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
    var archivedAt: Date?
    var title: String = ""
    var notes: String?
    
    // Draft metadata & publishing
    var source: String?
    @Attribute(.externalStorage) var tagsData: Data?
    var isPublished: Bool = false
    var lastEditedAt: Date = Date()
    var wordCount: Int = 0
    @Attribute(.externalStorage) var versionHistoryData: Data?
    
    // Draft lifecycle tracking
    var associatedPostID: UUID?
    var convertedAt: Date?
    var scheduledOrPublishedDate: Date?
    var isArchived: Bool = false
    
    init(
        title: String = "",
        caption: String = "",
        mediaURLs: [String] = [],
        tags: [String] = [],
        notes: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.caption = caption
        self.mediaURLs = mediaURLs
        self.tags = tags
        self.createdAt = Date()
        self.updatedAt = Date()
        self.lastEditedAt = Date()
        self.notes = notes
        self.isArchived = false
        self.wordCount = Draft.calculateWordCount(for: caption, notes: notes, title: title)
    }
    
    func toPost(scheduledDate: Date?) -> Post {
        let post = Post(
            caption: caption,
            mediaURLs: mediaURLs,
            scheduledDate: scheduledDate,
            status: scheduledDate != nil ? PostStatus.scheduled.rawValue : PostStatus.draft.rawValue,
            tags: tags
        )
        return post
    }
    
    static func calculateWordCount(for caption: String, notes: String?, title: String = "") -> Int {
        let titleWords = title.split { $0.isWhitespace || $0.isNewline }
        let captionWords = caption.split { $0.isWhitespace || $0.isNewline }
        let notesWords = notes?.split { $0.isWhitespace || $0.isNewline } ?? []
        return titleWords.count + captionWords.count + notesWords.count
    }
}
