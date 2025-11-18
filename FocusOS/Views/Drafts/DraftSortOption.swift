//
//  DraftSortOption.swift
//  FocusOS
//
//  Sort options for Drafts view
//

import Foundation

enum DraftSortOption: String, CaseIterable, Identifiable {
    // Date & Time
    case lastEditedAtDesc = "lastEditedAtDesc"
    case lastEditedAtAsc = "lastEditedAtAsc"
    case updatedAtDesc = "updatedAtDesc"
    case updatedAtAsc = "updatedAtAsc"
    case createdAtDesc = "createdAtDesc"
    case createdAtAsc = "createdAtAsc"
    case scheduledOrPublishedDateDesc = "scheduledOrPublishedDateDesc"
    case scheduledOrPublishedDateAsc = "scheduledOrPublishedDateAsc"
    
    // Alphabetical
    case titleAsc = "titleAsc"
    case titleDesc = "titleDesc"
    
    // Status
    case publishedFirst = "publishedFirst"
    case unpublishedFirst = "unpublishedFirst"
    case archivedFirst = "archivedFirst"
    
    // Word Count
    case wordCountDesc = "wordCountDesc"
    case wordCountAsc = "wordCountAsc"
    
    // Tags
    case tagCountDesc = "tagCountDesc"
    case tagCountAsc = "tagCountAsc"
    
    // Source
    case sourceAIGenerated = "sourceAIGenerated"
    case sourceUserCreated = "sourceUserCreated"
    
    // Combined
    case statusThenLastEdited = "statusThenLastEdited"
    case wordCountThenLastEdited = "wordCountThenLastEdited"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .lastEditedAtDesc: return "Recently Edited"
        case .lastEditedAtAsc: return "Oldest Edited"
        case .updatedAtDesc: return "Recently Updated"
        case .updatedAtAsc: return "Oldest Updated"
        case .createdAtDesc: return "Newest Created"
        case .createdAtAsc: return "Oldest Created"
        case .scheduledOrPublishedDateDesc: return "Upcoming Scheduled"
        case .scheduledOrPublishedDateAsc: return "Past Scheduled"
        case .titleAsc: return "Title A→Z"
        case .titleDesc: return "Title Z→A"
        case .publishedFirst: return "Published First"
        case .unpublishedFirst: return "Unpublished First"
        case .archivedFirst: return "Archived First"
        case .wordCountDesc: return "Longest First"
        case .wordCountAsc: return "Shortest First"
        case .tagCountDesc: return "Most Tags"
        case .tagCountAsc: return "Least Tags"
        case .sourceAIGenerated: return "AI Generated First"
        case .sourceUserCreated: return "User Created First"
        case .statusThenLastEdited: return "Status, Then Last Edited"
        case .wordCountThenLastEdited: return "Word Count, Then Last Edited"
        }
    }
    
    var icon: String {
        switch self {
        case .lastEditedAtDesc, .lastEditedAtAsc, .updatedAtDesc, .updatedAtAsc, .createdAtDesc, .createdAtAsc: return "clock"
        case .scheduledOrPublishedDateDesc, .scheduledOrPublishedDateAsc: return "calendar"
        case .titleAsc, .titleDesc: return "textformat"
        case .publishedFirst, .unpublishedFirst, .archivedFirst: return "checkmark.circle"
        case .wordCountDesc, .wordCountAsc: return "text.word.spacing"
        case .tagCountDesc, .tagCountAsc: return "tag"
        case .sourceAIGenerated, .sourceUserCreated: return "sparkles"
        case .statusThenLastEdited, .wordCountThenLastEdited: return "arrow.up.arrow.down"
        }
    }
    
    var category: DraftSortCategory {
        switch self {
        case .lastEditedAtDesc, .lastEditedAtAsc, .updatedAtDesc, .updatedAtAsc, .createdAtDesc, .createdAtAsc, .scheduledOrPublishedDateDesc, .scheduledOrPublishedDateAsc:
            return .dateTime
        case .titleAsc, .titleDesc:
            return .alphabetical
        case .publishedFirst, .unpublishedFirst, .archivedFirst:
            return .status
        case .wordCountDesc, .wordCountAsc:
            return .wordCount
        case .tagCountDesc, .tagCountAsc:
            return .tags
        case .sourceAIGenerated, .sourceUserCreated:
            return .source
        case .statusThenLastEdited, .wordCountThenLastEdited:
            return .combined
        }
    }
    
    static var categories: [DraftSortCategory] {
        [.dateTime, .alphabetical, .status, .wordCount, .tags, .source, .combined]
    }
    
    static func options(for category: DraftSortCategory) -> [DraftSortOption] {
        allCases.filter { $0.category == category }
    }
}

enum DraftSortCategory: String, CaseIterable {
    case dateTime = "Date & Time"
    case alphabetical = "Alphabetical"
    case status = "Status"
    case wordCount = "Word Count"
    case tags = "Tags"
    case source = "Source"
    case combined = "Combined"
    
    var icon: String {
        switch self {
        case .dateTime: return "clock"
        case .alphabetical: return "textformat"
        case .status: return "checkmark.circle"
        case .wordCount: return "text.word.spacing"
        case .tags: return "tag"
        case .source: return "sparkles"
        case .combined: return "arrow.up.arrow.down"
        }
    }
}

