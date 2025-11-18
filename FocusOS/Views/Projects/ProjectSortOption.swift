//
//  ProjectSortOption.swift
//  FocusOS
//
//  Sort options for Projects with comprehensive sorting capabilities
//

import SwiftUI
import FocusOSShared

enum ProjectSortOption: String, CaseIterable, Identifiable {
    // Date/Time sorts
    case dueDateAsc = "dueDateAsc"
    case dueDateDesc = "dueDateDesc"
    case createdAsc = "createdAsc"
    case createdDesc = "createdDesc"
    case updatedAsc = "updatedAsc"
    case updatedDesc = "updatedDesc"
    case archivedAsc = "archivedAsc"
    case archivedDesc = "archivedDesc"
    
    // Status sorts
    case statusActiveFirst = "statusActiveFirst"
    case statusCompletedFirst = "statusCompletedFirst"
    
    // Relationship sorts
    case byArea = "byArea"
    case unattachedFirst = "unattachedFirst"
    case unattachedLast = "unattachedLast"
    
    // Tag sorts
    case tagCountDesc = "tagCountDesc"
    case tagCountAsc = "tagCountAsc"
    
    // Alphabetical sorts
    case titleAsc = "titleAsc"
    case titleDesc = "titleDesc"
    
    // Combined sorts
    case statusThenDueDate = "statusThenDueDate"
    case statusThenUpdated = "statusThenUpdated"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .dueDateAsc: return "Due Date (Ascending)"
        case .dueDateDesc: return "Due Date (Descending)"
        case .createdAsc: return "Created (Oldest First)"
        case .createdDesc: return "Created (Newest First)"
        case .updatedAsc: return "Updated (Oldest First)"
        case .updatedDesc: return "Updated (Newest First)"
        case .archivedAsc: return "Archived (Oldest First)"
        case .archivedDesc: return "Archived (Newest First)"
        case .statusActiveFirst: return "Status (Active First)"
        case .statusCompletedFirst: return "Status (Completed First)"
        case .byArea: return "By Area"
        case .unattachedFirst: return "Unattached First"
        case .unattachedLast: return "Unattached Last"
        case .tagCountDesc: return "Tag Count (Most First)"
        case .tagCountAsc: return "Tag Count (Least First)"
        case .titleAsc: return "Title (A → Z)"
        case .titleDesc: return "Title (Z → A)"
        case .statusThenDueDate: return "Status, Then Due Date"
        case .statusThenUpdated: return "Status, Then Updated"
        }
    }
    
    var icon: String {
        switch self {
        case .dueDateAsc, .dueDateDesc: return "calendar"
        case .createdAsc, .createdDesc: return "plus.circle"
        case .updatedAsc, .updatedDesc: return "arrow.clockwise"
        case .archivedAsc, .archivedDesc: return "archivebox"
        case .statusActiveFirst, .statusCompletedFirst: return "list.bullet"
        case .byArea: return "square.grid.2x2"
        case .unattachedFirst, .unattachedLast: return "link.slash"
        case .tagCountDesc, .tagCountAsc: return "tag"
        case .titleAsc, .titleDesc: return "textformat"
        case .statusThenDueDate, .statusThenUpdated: return "arrow.up.arrow.down"
        }
    }
    
    var category: ProjectSortCategory {
        switch self {
        case .dueDateAsc, .dueDateDesc, .createdAsc, .createdDesc, .updatedAsc, .updatedDesc, .archivedAsc, .archivedDesc:
            return .dateTime
        case .statusActiveFirst, .statusCompletedFirst:
            return .status
        case .byArea, .unattachedFirst, .unattachedLast:
            return .relationship
        case .tagCountDesc, .tagCountAsc:
            return .tags
        case .titleAsc, .titleDesc:
            return .alphabetical
        case .statusThenDueDate, .statusThenUpdated:
            return .combined
        }
    }
    
    static var categories: [ProjectSortCategory] {
        [.dateTime, .status, .relationship, .tags, .alphabetical, .combined]
    }
    
    static func options(for category: ProjectSortCategory) -> [ProjectSortOption] {
        allCases.filter { $0.category == category }
    }
}

enum ProjectSortCategory: String, CaseIterable {
    case dateTime = "Date & Time"
    case status = "Status"
    case relationship = "Relationship"
    case tags = "Tags"
    case alphabetical = "Alphabetical"
    case combined = "Combined"
    
    var icon: String {
        switch self {
        case .dateTime: return "calendar"
        case .status: return "list.bullet"
        case .relationship: return "folder"
        case .tags: return "tag"
        case .alphabetical: return "textformat"
        case .combined: return "arrow.up.arrow.down"
        }
    }
}

