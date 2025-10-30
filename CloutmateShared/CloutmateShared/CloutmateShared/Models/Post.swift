//
//  Post.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData
import UniformTypeIdentifiers

@Model
public final class Post {
    public var id: UUID = UUID()
    public var caption: String = ""
    public var mediaURLs: [String] = [] // Array of local file URLs or URLs
    public var scheduledDate: Date?
    public var publishedDate: Date?
    public var platforms: [String] = [] // Array of Platform raw values
    public var status: String = PostStatus.draft.rawValue // PostStatus raw value
    public var tags: [String] = []
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    
    // Engagement metrics from Meta API
    public var engagementRate: Double?
    public var impressions: Int?
    public var likes: Int?
    public var comments: Int?
    public var saves: Int?
    public var reach: Int?
    
    // API IDs for tracking
    public var threadsPostID: String?
    public var facebookPostID: String?
    
    // Platform-specific page IDs (e.g., Facebook page IDs)
    public var pageIDs: [String: String] = [:]
    
    // Custom properties for database views
    public var customProperties: [String: String] = [:]
    public var contentPillar: String?
    public var funnelStage: String?
    public var campaignId: UUID?
    
    // Retry management
    public var retryCount: Int = 0
    public var lastError: String?
    
    // PARA integration
    public var projectId: UUID?
    public var areaId: UUID?
    
    public init(
        caption: String,
        mediaURLs: [String] = [],
        scheduledDate: Date? = nil,
        platforms: [String] = [],
        status: String = PostStatus.draft.rawValue,
        tags: [String] = [],
        projectId: UUID? = nil,
        areaId: UUID? = nil
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
        self.projectId = projectId
        self.areaId = areaId
    }
    
    public var postStatus: PostStatus {
        get { PostStatus(rawValue: status) ?? .draft }
        set { status = newValue.rawValue }
    }
    
    public var postPlatforms: [Platform] {
        get { platforms.compactMap { Platform(rawValue: $0) } }
        set { platforms = newValue.map { $0.rawValue } }
    }
    
    // Helper method to safely access page IDs
    public func getPageID(for platform: Platform) -> String? {
        return pageIDs[platform.rawValue]
    }
    
    public func updateEngagementMetrics(
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

