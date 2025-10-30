//
//  PerformancePrediction.swift
//  CloutmateShared
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData

@Model
public final class PerformancePrediction {
    public var id: UUID = UUID()
    public var postId: UUID
    public var predictedEngagementRate: Double
    public var confidence: Double
    public var factors: [String: Double] = [:]
    public var optimalPostingTime: Date?
    public var createdAt: Date = Date()
    
    public var captionLengthScore: Double = 0
    public var toneScore: Double = 0
    public var hashtagScore: Double = 0
    public var platformScore: Double = 0
    public var timeScore: Double = 0
    public var similarityScore: Double = 0
    
    public init(
        postId: UUID,
        predictedEngagementRate: Double,
        confidence: Double,
        factors: [String: Double] = [:],
        optimalPostingTime: Date? = nil
    ) {
        self.id = UUID()
        self.postId = postId
        self.predictedEngagementRate = predictedEngagementRate
        self.confidence = confidence
        self.factors = factors
        self.optimalPostingTime = optimalPostingTime
        self.createdAt = Date()
    }
}

