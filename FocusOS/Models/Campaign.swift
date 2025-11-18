//
//  Campaign.swift
//  FocusOS
//
//  Multi-post campaign model
//

import Foundation
import SwiftData
import SwiftUI

enum CampaignStatus: String, Codable, CaseIterable {
    case draft
    case scheduled
    case active
    case completed
    
    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .scheduled: return "Scheduled"
        case .active: return "Active"
        case .completed: return "Completed"
        }
    }
    
    var color: Color {
        switch self {
        case .draft: return .gray
        case .scheduled: return .kosmicBlue
        case .active: return .kosmicGreen
        case .completed: return .purple
        }
    }
}

@Model
final class Campaign {
    var id: UUID = UUID()
    var title: String = ""
    var goal: String?
    var projectId: UUID?
    var postIds: [UUID] = []
    var startDate: Date?
    var endDate: Date?
    var statusRaw: String = CampaignStatus.draft.rawValue
    var tags: [String] = []
    var notes: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    init(
        title: String,
        goal: String? = nil,
        projectId: UUID? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        status: CampaignStatus = .draft,
        tags: [String] = [],
        notes: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.goal = goal
        self.projectId = projectId
        self.postIds = []
        self.startDate = startDate
        self.endDate = endDate
        self.statusRaw = status.rawValue
        self.tags = tags
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var status: CampaignStatus {
        get { CampaignStatus(rawValue: statusRaw) ?? .draft }
        set {
            statusRaw = newValue.rawValue
            updatedAt = Date()
        }
    }
}

