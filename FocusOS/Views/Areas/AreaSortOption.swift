//
//  AreaSortOption.swift
//  FocusOS
//
//  Sort options for Areas view
//

import Foundation

enum AreaSortOption: String, CaseIterable, Identifiable {
    // Date & Time
    case updatedAtDesc = "updatedAtDesc"
    case updatedAtAsc = "updatedAtAsc"
    case createdAtDesc = "createdAtDesc"
    case createdAtAsc = "createdAtAsc"
    case lastReviewDateDesc = "lastReviewDateDesc"
    case lastReviewDateAsc = "lastReviewDateAsc"
    case archivedAtDesc = "archivedAtDesc"
    case archivedAtAsc = "archivedAtAsc"
    
    // Alphabetical
    case titleAsc = "titleAsc"
    case titleDesc = "titleDesc"
    
    // Status
    case statusActiveFirst = "statusActiveFirst"
    case statusArchivedFirst = "statusArchivedFirst"
    case reviewNeededFirst = "reviewNeededFirst"
    
    // Stability
    case stabilityHighToLow = "stabilityHighToLow"
    case stabilityLowToHigh = "stabilityLowToHigh"
    
    // Tags
    case tagCountDesc = "tagCountDesc"
    case tagCountAsc = "tagCountAsc"
    
    // Combined
    case statusThenUpdated = "statusThenUpdated"
    case stabilityThenUpdated = "stabilityThenUpdated"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .updatedAtDesc: return "Recently Updated"
        case .updatedAtAsc: return "Oldest Updated"
        case .createdAtDesc: return "Newest Created"
        case .createdAtAsc: return "Oldest Created"
        case .lastReviewDateDesc: return "Recently Reviewed"
        case .lastReviewDateAsc: return "Oldest Reviewed"
        case .archivedAtDesc: return "Recently Archived"
        case .archivedAtAsc: return "Oldest Archived"
        case .titleAsc: return "Title A→Z"
        case .titleDesc: return "Title Z→A"
        case .statusActiveFirst: return "Active First"
        case .statusArchivedFirst: return "Archived First"
        case .reviewNeededFirst: return "Review Needed First"
        case .stabilityHighToLow: return "Stability High→Low"
        case .stabilityLowToHigh: return "Stability Low→High"
        case .tagCountDesc: return "Most Tags"
        case .tagCountAsc: return "Least Tags"
        case .statusThenUpdated: return "Status, Then Updated"
        case .stabilityThenUpdated: return "Stability, Then Updated"
        }
    }
    
    var icon: String {
        switch self {
        case .updatedAtDesc, .updatedAtAsc: return "arrow.clockwise"
        case .createdAtDesc, .createdAtAsc: return "plus.circle"
        case .lastReviewDateDesc, .lastReviewDateAsc: return "calendar.badge.clock"
        case .archivedAtDesc, .archivedAtAsc: return "archivebox"
        case .titleAsc, .titleDesc: return "textformat"
        case .statusActiveFirst, .statusArchivedFirst, .reviewNeededFirst: return "checkmark.circle"
        case .stabilityHighToLow, .stabilityLowToHigh: return "chart.line.uptrend.xyaxis"
        case .tagCountDesc, .tagCountAsc: return "tag"
        case .statusThenUpdated, .stabilityThenUpdated: return "arrow.up.arrow.down"
        }
    }
    
    var category: AreaSortCategory {
        switch self {
        case .updatedAtDesc, .updatedAtAsc, .createdAtDesc, .createdAtAsc, .lastReviewDateDesc, .lastReviewDateAsc, .archivedAtDesc, .archivedAtAsc:
            return .dateTime
        case .titleAsc, .titleDesc:
            return .alphabetical
        case .statusActiveFirst, .statusArchivedFirst, .reviewNeededFirst:
            return .status
        case .stabilityHighToLow, .stabilityLowToHigh:
            return .stability
        case .tagCountDesc, .tagCountAsc:
            return .tags
        case .statusThenUpdated, .stabilityThenUpdated:
            return .combined
        }
    }
    
    static var categories: [AreaSortCategory] {
        [.dateTime, .alphabetical, .status, .stability, .tags, .combined]
    }
    
    static func options(for category: AreaSortCategory) -> [AreaSortOption] {
        allCases.filter { $0.category == category }
    }
}

enum AreaSortCategory: String, CaseIterable {
    case dateTime = "Date & Time"
    case alphabetical = "Alphabetical"
    case status = "Status"
    case stability = "Stability"
    case tags = "Tags"
    case combined = "Combined"
    
    var icon: String {
        switch self {
        case .dateTime: return "clock"
        case .alphabetical: return "textformat"
        case .status: return "checkmark.circle"
        case .stability: return "chart.line.uptrend.xyaxis"
        case .tags: return "tag"
        case .combined: return "arrow.up.arrow.down"
        }
    }
}

