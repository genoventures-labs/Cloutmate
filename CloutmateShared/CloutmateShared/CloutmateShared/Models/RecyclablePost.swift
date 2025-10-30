//
//  RecyclablePost.swift
//  CloutmateShared
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData

@Model
public final class RecyclablePost {
    public var id: UUID = UUID()
    public var originalPostId: UUID
    public var isEvergreen: Bool = false
    public var lastRecycledAt: Date?
    public var recycleCount: Int = 0
    public var nextSuggestedDate: Date?
    public var topicTags: [String] = []
    public var engagementScore: Double = 0
    public var variations: [String] = []
    public var createdAt: Date = Date()
    
    public init(
        originalPostId: UUID,
        isEvergreen: Bool = false,
        engagementScore: Double = 0,
        topicTags: [String] = [],
        nextSuggestedDate: Date? = nil
    ) {
        self.id = UUID()
        self.originalPostId = originalPostId
        self.isEvergreen = isEvergreen
        self.engagementScore = engagementScore
        self.topicTags = topicTags
        self.nextSuggestedDate = nextSuggestedDate
        self.recycleCount = 0
        self.createdAt = Date()
    }
}

