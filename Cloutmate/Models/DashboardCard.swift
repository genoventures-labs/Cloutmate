//
//  DashboardCard.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData

enum DashboardCardType: String, Codable, CaseIterable {
    // PARA Workflow Cards
    case todayOverview = "Today Overview"
    case inboxCount = "Inbox"
    case activeProjects = "Active Projects"
    case upcomingTasks = "Upcoming Tasks"
    case recentNotes = "Recent Notes"
    case areasOverview = "Areas"
    
    // PARA Workflow Insights
    case projectsOverview = "Projects Overview"
    case tasksOverview = "Tasks Overview"
    case areasHealth = "Areas Health"
    case notesActivity = "Notes Activity"
    
    // Productivity Insights
    case upcomingDeadlines = "Upcoming Deadlines"
    case workloadBalance = "Workload Balance"
    case completionRate = "Completion Rate"
    case inboxTrend = "Inbox Trend"
    
    // Quick Actions
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
        case .projectsOverview: return "chart.bar.doc.horizontal.fill"
        case .tasksOverview: return "list.clipboard.fill"
        case .areasHealth: return "heart.circle.fill"
        case .notesActivity: return "book.fill"
        case .upcomingDeadlines: return "clock.badge.fill"
        case .workloadBalance: return "scalemass.fill"
        case .completionRate: return "chart.pie.fill"
        case .inboxTrend: return "chart.line.uptrend.xyaxis"
        case .quickCapture: return "plus.circle.fill"
        case .aiSuggestions: return "sparkles"
        }
    }
    
    var defaultSize: DashboardCardSize {
        switch self {
        // Large cards - detailed overviews
        case .todayOverview, .activeProjects, .projectsOverview: return .large
        
        // Medium cards - moderate detail
        case .quickCapture, .aiSuggestions, .tasksOverview, .areasHealth, .workloadBalance, .completionRate: return .medium
        
        // Small cards - quick metrics
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

