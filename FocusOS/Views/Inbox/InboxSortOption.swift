//
//  InboxSortOption.swift
//  FocusOS
//
//  Sort options for Inbox view
//

import Foundation

enum InboxSortOption: String, CaseIterable, Identifiable {
    // Date & Time
    case createdAtDesc = "createdAtDesc"
    case createdAtAsc = "createdAtAsc"
    case convertedAtDesc = "convertedAtDesc"
    case convertedAtAsc = "convertedAtAsc"
    
    // Type
    case typeText = "typeText"
    case typeImage = "typeImage"
    case typeFile = "typeFile"
    case typeURL = "typeURL"
    case typeVoice = "typeVoice"
    
    // Status
    case flaggedFirst = "flaggedFirst"
    case unflaggedFirst = "unflaggedFirst"
    case convertedFirst = "convertedFirst"
    case unconvertedFirst = "unconvertedFirst"
    
    // AI
    case aiImportedFirst = "aiImportedFirst"
    case userImportedFirst = "userImportedFirst"
    
    // Combined
    case flaggedThenCreated = "flaggedThenCreated"
    case typeThenCreated = "typeThenCreated"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .createdAtDesc: return "Newest First"
        case .createdAtAsc: return "Oldest First"
        case .convertedAtDesc: return "Recently Converted"
        case .convertedAtAsc: return "Oldest Converted"
        case .typeText: return "Text First"
        case .typeImage: return "Images First"
        case .typeFile: return "Files First"
        case .typeURL: return "URLs First"
        case .typeVoice: return "Voice First"
        case .flaggedFirst: return "Flagged First"
        case .unflaggedFirst: return "Unflagged First"
        case .convertedFirst: return "Converted First"
        case .unconvertedFirst: return "Unconverted First"
        case .aiImportedFirst: return "AI Imported First"
        case .userImportedFirst: return "User Imported First"
        case .flaggedThenCreated: return "Flagged, Then Created"
        case .typeThenCreated: return "Type, Then Created"
        }
    }
    
    var icon: String {
        switch self {
        case .createdAtDesc, .createdAtAsc: return "clock"
        case .convertedAtDesc, .convertedAtAsc: return "arrow.triangle.2.circlepath"
        case .typeText, .typeImage, .typeFile, .typeURL, .typeVoice: return "doc"
        case .flaggedFirst, .unflaggedFirst: return "flag.fill"
        case .convertedFirst, .unconvertedFirst: return "checkmark.circle"
        case .aiImportedFirst, .userImportedFirst: return "sparkles"
        case .flaggedThenCreated, .typeThenCreated: return "arrow.up.arrow.down"
        }
    }
    
    var category: InboxSortCategory {
        switch self {
        case .createdAtDesc, .createdAtAsc, .convertedAtDesc, .convertedAtAsc:
            return .dateTime
        case .typeText, .typeImage, .typeFile, .typeURL, .typeVoice:
            return .type
        case .flaggedFirst, .unflaggedFirst, .convertedFirst, .unconvertedFirst:
            return .status
        case .aiImportedFirst, .userImportedFirst:
            return .ai
        case .flaggedThenCreated, .typeThenCreated:
            return .combined
        }
    }
    
    static var categories: [InboxSortCategory] {
        [.dateTime, .type, .status, .ai, .combined]
    }
    
    static func options(for category: InboxSortCategory) -> [InboxSortOption] {
        allCases.filter { $0.category == category }
    }
}

enum InboxSortCategory: String, CaseIterable {
    case dateTime = "Date & Time"
    case type = "Type"
    case status = "Status"
    case ai = "AI"
    case combined = "Combined"
    
    var icon: String {
        switch self {
        case .dateTime: return "clock"
        case .type: return "doc"
        case .status: return "checkmark.circle"
        case .ai: return "sparkles"
        case .combined: return "arrow.up.arrow.down"
        }
    }
}

