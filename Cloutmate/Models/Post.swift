//
//  Post.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData

@Model
final class Post {
    var id: UUID = UUID()
    var caption: String = ""
    var mediaURLs: [String] = [] // Array of local file URLs or URLs
    var scheduledDate: Date?
    var publishedDate: Date?
    var platforms: [String] = [] // Array of Platform raw values
    var status: String = PostStatus.draft.rawValue // PostStatus raw value
    var tags: [String] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // Engagement metrics from Meta API
    var engagementRate: Double?
    var impressions: Int?
    var likes: Int?
    var comments: Int?
    var saves: Int?
    var reach: Int?
    
    // API IDs for tracking
    var threadsPostID: String?
    var facebookPostID: String?
    
    // Retry management
    var retryCount: Int = 0
    var lastError: String?
    
    init(
        caption: String,
        mediaURLs: [String] = [],
        scheduledDate: Date? = nil,
        platforms: [String] = [],
        status: String = PostStatus.draft.rawValue,
        tags: [String] = []
    ) {
        self.id = UUID()
        self.caption = caption
        self.mediaURLs = mediaURLs
        self.scheduledDate = scheduledDate
        self.publishedDate = nil
        self.platforms = platforms
        self.status = status
        self.tags = tags
        self.createdAt = Date()
        self.updatedAt = Date()
        self.retryCount = 0
    }
    
    var postStatus: PostStatus {
        get { PostStatus(rawValue: status) ?? .draft }
        set { status = newValue.rawValue }
    }
    
    var postPlatforms: [Platform] {
        get { platforms.compactMap { Platform(rawValue: $0) } }
        set { platforms = newValue.map { $0.rawValue } }
    }
    
    func updateEngagementMetrics(
        engagementRate: Double? = nil,
        impressions: Int? = nil,
        likes: Int? = nil,
        comments: Int? = nil,
        saves: Int? = nil,
        reach: Int? = nil
    ) {
        if let engagementRate = engagementRate {
            self.engagementRate = engagementRate
        }
        if let impressions = impressions {
            self.impressions = impressions
        }
        if let likes = likes {
            self.likes = likes
        }
        if let comments = comments {
            self.comments = comments
        }
        if let saves = saves {
            self.saves = saves
        }
        if let reach = reach {
            self.reach = reach
        }
        self.updatedAt = Date()
    }
}

