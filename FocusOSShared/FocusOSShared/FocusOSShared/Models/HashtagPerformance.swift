//
//  HashtagPerformance.swift
//  FocusOSShared
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData

@Model
public final class HashtagPerformance {
    public var id: UUID = UUID()
    public var hashtag: String
    public var useCount: Int = 0
    public var totalEngagement: Int = 0
    public var averageEngagement: Double = 0
    public var bestPerformingPostId: UUID?
    public var lastUsedAt: Date?
    public var platform: String
    public var isTrending: Bool = false
    public var trendScore: Double = 0
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    
    public init(
        hashtag: String,
        platform: String,
        useCount: Int = 0,
        totalEngagement: Int = 0,
        averageEngagement: Double = 0,
        isTrending: Bool = false,
        trendScore: Double = 0
    ) {
        self.id = UUID()
        self.hashtag = hashtag
        self.platform = platform
        self.useCount = useCount
        self.totalEngagement = totalEngagement
        self.averageEngagement = averageEngagement
        self.isTrending = isTrending
        self.trendScore = trendScore
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
public final class HashtagSet {
    public var id: UUID = UUID()
    public var name: String
    public var hashtags: [String] = []
    public var notes: String?
    public var useCount: Int = 0
    public var averagePerformance: Double = 0
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    
    public init(
        name: String,
        hashtags: [String] = [],
        notes: String? = nil,
        useCount: Int = 0,
        averagePerformance: Double = 0
    ) {
        self.id = UUID()
        self.name = name
        self.hashtags = hashtags
        self.notes = notes
        self.useCount = useCount
        self.averagePerformance = averagePerformance
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

