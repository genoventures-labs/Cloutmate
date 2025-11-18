//
//  InsightSnapshot.swift
//  FocusOS
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData

@Model
final class InsightSnapshot {
    var id: UUID = UUID()
    var postID: UUID = UUID()
    var capturedAt: Date = Date()
    var engagementRate: Double?
    var impressions: Int?
    var likes: Int?
    var comments: Int?
    var saves: Int?
    var reach: Int?
    
    init(
        postID: UUID,
        engagementRate: Double? = nil,
        impressions: Int? = nil,
        likes: Int? = nil,
        comments: Int? = nil,
        saves: Int? = nil,
        reach: Int? = nil
    ) {
        self.id = UUID()
        self.postID = postID
        self.capturedAt = Date()
        self.engagementRate = engagementRate
        self.impressions = impressions
        self.likes = likes
        self.comments = comments
        self.saves = saves
        self.reach = reach
    }
}

