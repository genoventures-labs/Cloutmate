//
//  CalendarEvent.swift
//  CloutmateShared
//
//  Created by Assistant on 11/12/25.
//

import Foundation
import SwiftData

public enum EventRecurrenceFrequency: String, Codable, CaseIterable, Sendable {
    case daily
    case weekly
    case monthly
    case yearly
}

public struct EventRecurrence: Codable, Hashable, Sendable {
    public var frequency: EventRecurrenceFrequency
    public var interval: Int
    public var endDate: Date?
    /// 1 = Sunday ... 7 = Saturday (Calendar.current.component(.weekday, from:))
    public var weekdays: [Int]?
    
    public init(
        frequency: EventRecurrenceFrequency,
        interval: Int = 1,
        endDate: Date? = nil,
        weekdays: [Int]? = nil
    ) {
        self.frequency = frequency
        self.interval = max(1, interval)
        self.endDate = endDate
        self.weekdays = weekdays
    }
}

@Model
public final class CalendarEvent {
    public var id: UUID
    public var title: String
    public var notes: String?
    public var location: String?
    public var startDate: Date
    public var endDate: Date
    public var allDay: Bool
    @Attribute(.transformable)
    public var recurrence: EventRecurrence?
    public var remindMinutesBefore: Int?
    public var colorHex: String?
    
    public var createdAt: Date
    public var updatedAt: Date
    public var auroraGenerated: Bool
    
    public var linkedEntityIds: [UUID]
    public var linkedEntityTypes: [String]
    
    public init(
        title: String,
        notes: String? = nil,
        location: String? = nil,
        startDate: Date,
        endDate: Date,
        allDay: Bool = false,
        recurrence: EventRecurrence? = nil,
        remindMinutesBefore: Int? = nil,
        colorHex: String? = nil,
        auroraGenerated: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.location = location
        self.startDate = startDate
        self.endDate = endDate
        self.allDay = allDay
        self.recurrence = recurrence
        self.remindMinutesBefore = remindMinutesBefore
        self.colorHex = colorHex
        self.createdAt = Date()
        self.updatedAt = Date()
        self.auroraGenerated = auroraGenerated
        self.linkedEntityIds = []
        self.linkedEntityTypes = []
    }
    
    public func touch() {
        updatedAt = Date()
    }
}

