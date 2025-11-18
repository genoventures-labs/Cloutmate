//
//  ContentTopic.swift
//  FocusOSShared
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData

@Model
public final class ContentTopic {
    public var id: UUID = UUID()
    public var name: String
    public var postCount: Int = 0
    public var lastPostedAt: Date?
    public var averageEngagement: Double = 0
    public var relatedKeywords: [String] = []
    public var isUnderrepresented: Bool = false
    public var suggestedFrequency: Int = 0
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    
    public init(
        name: String,
        postCount: Int = 0,
        averageEngagement: Double = 0,
        relatedKeywords: [String] = [],
        isUnderrepresented: Bool = false,
        suggestedFrequency: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.postCount = postCount
        self.averageEngagement = averageEngagement
        self.relatedKeywords = relatedKeywords
        self.isUnderrepresented = isUnderrepresented
        self.suggestedFrequency = suggestedFrequency
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
public final class ContentBalance {
    public var id: UUID = UUID()
    public var analyzedAt: Date = Date()
    public var contentTypes: [String: Double] = [:]
    public var topicClusters: [String: Int] = [:]
    public var gaps: [String] = []
    public var recommendations: [String] = []
    
    public init(
        contentTypes: [String: Double] = [:],
        topicClusters: [String: Int] = [:],
        gaps: [String] = [],
        recommendations: [String] = []
    ) {
        self.id = UUID()
        self.contentTypes = contentTypes
        self.topicClusters = topicClusters
        self.gaps = gaps
        self.recommendations = recommendations
        self.analyzedAt = Date()
    }
}

