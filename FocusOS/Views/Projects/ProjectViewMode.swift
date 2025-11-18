//
//  ProjectViewMode.swift
//  FocusOS
//
//  View mode enum for Projects multi-mode orchestration hub
//

import SwiftUI
import FocusOSShared

enum ProjectViewMode: String, CaseIterable {
    case list, board, roadmap, gallery
    
    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .board: return "square.grid.2x2"
        case .roadmap: return "chart.bar.doc.horizontal"
        case .gallery: return "photo.on.rectangle"
        }
    }
    
    var displayName: String {
        rawValue.capitalized
    }
}

enum ProjectFilter: String, CaseIterable, Identifiable {
    // Basic filters
    case all, active, paused, completed
    
    // Due date filters
    case withDueDate = "With Due Date"
    case withoutDueDate = "Without Due Date"
    case overdue = "Overdue"
    case dueThisWeek = "Due This Week"
    case dueThisMonth = "Due This Month"
    case dueThisQuarter = "Due This Quarter"
    
    // Relationship filters
    case unattached = "Unattached"
    case hasArea = "Has Area"
    
    // Tag filters
    case withTags = "With Tags"
    case withoutTags = "Without Tags"
    
    // Activity filters
    case recentlyUpdated = "Recently Updated"
    case recentlyCreated = "Recently Created"
    case stale = "Stale"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .active: return "Active"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .withDueDate: return "With Due Date"
        case .withoutDueDate: return "Without Due Date"
        case .overdue: return "Overdue"
        case .dueThisWeek: return "Due This Week"
        case .dueThisMonth: return "Due This Month"
        case .dueThisQuarter: return "Due This Quarter"
        case .unattached: return "Unattached"
        case .hasArea: return "Has Area"
        case .withTags: return "With Tags"
        case .withoutTags: return "Without Tags"
        case .recentlyUpdated: return "Recently Updated"
        case .recentlyCreated: return "Recently Created"
        case .stale: return "Stale"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .active: return "play.fill"
        case .paused: return "pause.fill"
        case .completed: return "checkmark.circle.fill"
        case .withDueDate: return "calendar.badge.plus"
        case .withoutDueDate: return "calendar.badge.minus"
        case .overdue: return "exclamationmark.triangle.fill"
        case .dueThisWeek: return "calendar.badge.clock"
        case .dueThisMonth: return "calendar"
        case .dueThisQuarter: return "calendar.badge.exclamationmark"
        case .unattached: return "link.slash"
        case .hasArea: return "square.grid.2x2"
        case .withTags: return "tag.fill"
        case .withoutTags: return "tag.slash"
        case .recentlyUpdated: return "arrow.clockwise.circle"
        case .recentlyCreated: return "plus.circle"
        case .stale: return "clock.badge.exclamationmark"
        }
    }
    
    var category: ProjectFilterCategory {
        switch self {
        case .all, .active, .paused, .completed:
            return .basic
        case .withDueDate, .withoutDueDate, .overdue, .dueThisWeek, .dueThisMonth, .dueThisQuarter:
            return .dueDate
        case .unattached, .hasArea:
            return .relationship
        case .withTags, .withoutTags:
            return .tags
        case .recentlyUpdated, .recentlyCreated, .stale:
            return .activity
        }
    }
    
    func matches(_ status: ProjectStatus) -> Bool {
        switch self {
        case .all: return true
        case .active: return status == .active
        case .paused: return status == .paused
        case .completed: return status == .completed
        default: return true
        }
    }
    
    static var categories: [ProjectFilterCategory] {
        [.basic, .dueDate, .relationship, .tags, .activity]
    }
    
    static func filters(for category: ProjectFilterCategory) -> [ProjectFilter] {
        allCases.filter { $0.category == category }
    }
}

enum ProjectFilterCategory: String, CaseIterable {
    case basic = "Basic"
    case dueDate = "Due Date"
    case relationship = "Relationship"
    case tags = "Tags"
    case activity = "Activity"
    
    var icon: String {
        switch self {
        case .basic: return "list.bullet"
        case .dueDate: return "calendar"
        case .relationship: return "folder"
        case .tags: return "tag"
        case .activity: return "clock"
        }
    }
}

