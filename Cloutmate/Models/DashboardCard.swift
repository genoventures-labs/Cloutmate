//
//  DashboardCard.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData

enum DashboardCardType: String, Codable, CaseIterable {
    // PARA Cards
    case todayOverview = "Today Overview"
    case inboxCount = "Inbox"
    case activeProjects = "Active Projects"
    case upcomingTasks = "Upcoming Tasks"
    case recentNotes = "Recent Notes"
    case areasOverview = "Areas"
    
    // Social Publishing Cards
    case scheduledPosts = "Scheduled Posts"
    case draftCount = "Drafts"
    case recentInsights = "Recent Insights"
    case postingStreak = "Posting Streak"
    case topPerformingPost = "Top Post"
    
    // Combined Cards
    case quickCapture = "Quick Capture"
    case aiSuggestions = "AI Suggestions"
    
    var icon: String {
        switch self {
        case .todayOverview: return "sun.max.fill"
        case .inboxCount: return "tray.fill"
        case .activeProjects: return "folder.fill"
        case .upcomingTasks: return "checkmark.circle"
        case .recentNotes: return "doc.text"
        case .areasOverview: return "rectangle.stack.fill"
        case .scheduledPosts: return "calendar"
        case .draftCount: return "doc.text.fill"
        case .recentInsights: return "chart.line.uptrend.xyaxis"
        case .postingStreak: return "flame.fill"
        case .topPerformingPost: return "star.fill"
        case .quickCapture: return "plus.circle.fill"
        case .aiSuggestions: return "sparkles"
        }
    }
    
    var defaultSize: DashboardCardSize {
        switch self {
        case .todayOverview, .activeProjects: return .large
        case .quickCapture, .aiSuggestions: return .medium
        default: return .small
        }
    }
}

enum DashboardCardSize: String, Codable {
    case small // 1x1
    case medium // 2x1
    case large // 2x2
}

@Model
final class DashboardCard {
    var id: UUID = UUID()
    var cardType: String = ""
    var position: Int = 0
    var size: String = DashboardCardSize.small.rawValue
    var isPinned: Bool = false
    var isVisible: Bool = true
    var createdAt: Date = Date()
    
    init(cardType: DashboardCardType, position: Int, size: DashboardCardSize = .small) {
        self.id = UUID()
        self.cardType = cardType.rawValue
        self.position = position
        self.size = size.rawValue
        self.isPinned = false
        self.isVisible = true
        self.createdAt = Date()
    }
    
    var type: DashboardCardType {
        get { DashboardCardType(rawValue: cardType) ?? .todayOverview }
        set { cardType = newValue.rawValue }
    }
    
    var cardSize: DashboardCardSize {
        get { DashboardCardSize(rawValue: size) ?? .small }
        set { size = newValue.rawValue }
    }
}

