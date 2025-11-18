//
//  PostingTimeTest.swift
//  FocusOSShared
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData

public enum TestStatus: String, Codable {
    case active
    case completed
    case cancelled
}

@Model
public final class PostingTimeTest {
    public var id: UUID = UUID()
    public var basePostId: UUID
    public var testVariants: [UUID] = []
    public var testStartDate: Date = Date()
    public var testEndDate: Date?
    public var results: [String: Double] = [:]
    public var winningTime: Date?
    public var statusRaw: String = TestStatus.active.rawValue
    public var createdAt: Date = Date()
    
    public var status: TestStatus {
        get { TestStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }
    
    public init(
        basePostId: UUID,
        testVariants: [UUID] = [],
        testStartDate: Date = Date(),
        status: TestStatus = .active
    ) {
        self.id = UUID()
        self.basePostId = basePostId
        self.testVariants = testVariants
        self.testStartDate = testStartDate
        self.statusRaw = status.rawValue
        self.createdAt = Date()
    }
}

@Model
public final class OptimalPostingTime {
    public var id: UUID = UUID()
    public var platform: String
    public var dayOfWeek: Int
    public var hourOfDay: Int
    public var engagementMultiplier: Double = 1.0
    public var sampleSize: Int = 0
    public var confidence: Double = 0
    public var lastUpdated: Date = Date()
    
    public init(
        platform: String,
        dayOfWeek: Int,
        hourOfDay: Int,
        engagementMultiplier: Double = 1.0,
        sampleSize: Int = 0,
        confidence: Double = 0
    ) {
        self.id = UUID()
        self.platform = platform
        self.dayOfWeek = dayOfWeek
        self.hourOfDay = hourOfDay
        self.engagementMultiplier = engagementMultiplier
        self.sampleSize = sampleSize
        self.confidence = confidence
        self.lastUpdated = Date()
    }
}

