//
//  TaskSortOption.swift
//  FocusOS
//
//  Sort options for Tasks with comprehensive sorting capabilities
//

import SwiftUI
import FocusOSShared

enum TaskSortOption: String, CaseIterable, Identifiable {
    // Date/Time sorts
    case dueDateAsc = "dueDateAsc"
    case dueDateDesc = "dueDateDesc"
    case createdAsc = "createdAsc"
    case createdDesc = "createdDesc"
    case updatedAsc = "updatedAsc"
    case updatedDesc = "updatedDesc"
    case completedAsc = "completedAsc"
    case completedDesc = "completedDesc"
    
    // Priority sorts
    case priorityHighToLow = "priorityHighToLow"
    case priorityLowToHigh = "priorityLowToHigh"
    
    // Status sorts
    case statusTodoFirst = "statusTodoFirst"
    case statusDoneFirst = "statusDoneFirst"
    
    // Relationship sorts
    case byProject = "byProject"
    case byArea = "byArea"
    case unattachedFirst = "unattachedFirst"
    case unattachedLast = "unattachedLast"
    
    // Effort sorts
    case effortSmallToLarge = "effortSmallToLarge"
    case effortLargeToSmall = "effortLargeToSmall"
    
    // Alphabetical sorts
    case titleAsc = "titleAsc"
    case titleDesc = "titleDesc"
    
    // Combined sorts
    case priorityThenDueDate = "priorityThenDueDate"
    case dueDateThenPriority = "dueDateThenPriority"
    case statusThenDueDate = "statusThenDueDate"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .dueDateAsc: return "Due Date (Ascending)"
        case .dueDateDesc: return "Due Date (Descending)"
        case .createdAsc: return "Created (Oldest First)"
        case .createdDesc: return "Created (Newest First)"
        case .updatedAsc: return "Updated (Oldest First)"
        case .updatedDesc: return "Updated (Newest First)"
        case .completedAsc: return "Completed (Oldest First)"
        case .completedDesc: return "Completed (Newest First)"
        case .priorityHighToLow: return "Priority (High → Low)"
        case .priorityLowToHigh: return "Priority (Low → High)"
        case .statusTodoFirst: return "Status (To Do First)"
        case .statusDoneFirst: return "Status (Done First)"
        case .byProject: return "By Project"
        case .byArea: return "By Area"
        case .unattachedFirst: return "Unattached First"
        case .unattachedLast: return "Unattached Last"
        case .effortSmallToLarge: return "Effort (Small → Large)"
        case .effortLargeToSmall: return "Effort (Large → Small)"
        case .titleAsc: return "Title (A → Z)"
        case .titleDesc: return "Title (Z → A)"
        case .priorityThenDueDate: return "Priority, Then Due Date"
        case .dueDateThenPriority: return "Due Date, Then Priority"
        case .statusThenDueDate: return "Status, Then Due Date"
        }
    }
    
    var icon: String {
        switch self {
        case .dueDateAsc, .dueDateDesc: return "calendar"
        case .createdAsc, .createdDesc: return "plus.circle"
        case .updatedAsc, .updatedDesc: return "arrow.clockwise"
        case .completedAsc, .completedDesc: return "checkmark.circle"
        case .priorityHighToLow, .priorityLowToHigh: return "exclamationmark.circle"
        case .statusTodoFirst, .statusDoneFirst: return "list.bullet"
        case .byProject: return "folder"
        case .byArea: return "square.grid.2x2"
        case .unattachedFirst, .unattachedLast: return "link.slash"
        case .effortSmallToLarge, .effortLargeToSmall: return "gauge"
        case .titleAsc, .titleDesc: return "textformat"
        case .priorityThenDueDate, .dueDateThenPriority, .statusThenDueDate: return "arrow.up.arrow.down"
        }
    }
    
    var category: SortCategory {
        switch self {
        case .dueDateAsc, .dueDateDesc, .createdAsc, .createdDesc, .updatedAsc, .updatedDesc, .completedAsc, .completedDesc:
            return .dateTime
        case .priorityHighToLow, .priorityLowToHigh:
            return .priority
        case .statusTodoFirst, .statusDoneFirst:
            return .status
        case .byProject, .byArea, .unattachedFirst, .unattachedLast:
            return .relationship
        case .effortSmallToLarge, .effortLargeToSmall:
            return .effort
        case .titleAsc, .titleDesc:
            return .alphabetical
        case .priorityThenDueDate, .dueDateThenPriority, .statusThenDueDate:
            return .combined
        }
    }
    
    static var categories: [SortCategory] {
        [.dateTime, .priority, .status, .relationship, .effort, .alphabetical, .combined]
    }
    
    static func options(for category: SortCategory) -> [TaskSortOption] {
        allCases.filter { $0.category == category }
    }
}

enum SortCategory: String, CaseIterable {
    case dateTime = "Date & Time"
    case priority = "Priority"
    case status = "Status"
    case relationship = "Relationship"
    case effort = "Effort"
    case alphabetical = "Alphabetical"
    case combined = "Combined"
    
    var icon: String {
        switch self {
        case .dateTime: return "calendar"
        case .priority: return "exclamationmark.circle"
        case .status: return "list.bullet"
        case .relationship: return "folder"
        case .effort: return "gauge"
        case .alphabetical: return "textformat"
        case .combined: return "arrow.up.arrow.down"
        }
    }
}

