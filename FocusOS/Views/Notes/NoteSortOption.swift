//
//  NoteSortOption.swift
//  FocusOS
//
//  Sort options for Notes view
//

import Foundation

enum NoteSortOption: String, CaseIterable, Identifiable {
    // Date & Time
    case updatedAtDesc = "updatedAtDesc"
    case updatedAtAsc = "updatedAtAsc"
    case createdAtDesc = "createdAtDesc"
    case createdAtAsc = "createdAtAsc"
    case pinnedAtDesc = "pinnedAtDesc"
    case pinnedAtAsc = "pinnedAtAsc"
    
    // Alphabetical
    case titleAsc = "titleAsc"
    case titleDesc = "titleDesc"
    
    // Pinned
    case pinnedFirst = "pinnedFirst"
    case unpinnedFirst = "unpinnedFirst"
    
    // Type
    case typeNote = "typeNote"
    case typeArticle = "typeArticle"
    case typeVideo = "typeVideo"
    case typePodcast = "typePodcast"
    case typeBook = "typeBook"
    case typeLink = "typeLink"
    
    // Relationship
    case byProject = "byProject"
    case byArea = "byArea"
    case unattachedFirst = "unattachedFirst"
    case unattachedLast = "unattachedLast"
    
    // Tags
    case tagCountDesc = "tagCountDesc"
    case tagCountAsc = "tagCountAsc"
    
    // Author
    case authorUserFirst = "authorUserFirst"
    case authorAuroraFirst = "authorAuroraFirst"
    
    // Combined
    case pinnedThenUpdated = "pinnedThenUpdated"
    case typeThenUpdated = "typeThenUpdated"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .updatedAtDesc: return "Recently Updated"
        case .updatedAtAsc: return "Oldest Updated"
        case .createdAtDesc: return "Newest Created"
        case .createdAtAsc: return "Oldest Created"
        case .pinnedAtDesc: return "Recently Pinned"
        case .pinnedAtAsc: return "Oldest Pinned"
        case .titleAsc: return "Title A→Z"
        case .titleDesc: return "Title Z→A"
        case .pinnedFirst: return "Pinned First"
        case .unpinnedFirst: return "Unpinned First"
        case .typeNote: return "Notes First"
        case .typeArticle: return "Articles First"
        case .typeVideo: return "Videos First"
        case .typePodcast: return "Podcasts First"
        case .typeBook: return "Books First"
        case .typeLink: return "Links First"
        case .byProject: return "By Project"
        case .byArea: return "By Area"
        case .unattachedFirst: return "Unattached First"
        case .unattachedLast: return "Unattached Last"
        case .tagCountDesc: return "Most Tags"
        case .tagCountAsc: return "Least Tags"
        case .authorUserFirst: return "User First"
        case .authorAuroraFirst: return "Aurora First"
        case .pinnedThenUpdated: return "Pinned, Then Updated"
        case .typeThenUpdated: return "Type, Then Updated"
        }
    }
    
    var icon: String {
        switch self {
        case .updatedAtDesc, .updatedAtAsc: return "arrow.clockwise"
        case .createdAtDesc, .createdAtAsc: return "plus.circle"
        case .pinnedAtDesc, .pinnedAtAsc: return "pin"
        case .titleAsc, .titleDesc: return "textformat"
        case .pinnedFirst, .unpinnedFirst: return "pin.fill"
        case .typeNote, .typeArticle, .typeVideo, .typePodcast, .typeBook, .typeLink: return "doc.text"
        case .byProject, .byArea: return "folder"
        case .unattachedFirst, .unattachedLast: return "link.slash"
        case .tagCountDesc, .tagCountAsc: return "tag"
        case .authorUserFirst, .authorAuroraFirst: return "person"
        case .pinnedThenUpdated, .typeThenUpdated: return "arrow.up.arrow.down"
        }
    }
    
    var category: NoteSortCategory {
        switch self {
        case .updatedAtDesc, .updatedAtAsc, .createdAtDesc, .createdAtAsc, .pinnedAtDesc, .pinnedAtAsc:
            return .dateTime
        case .titleAsc, .titleDesc:
            return .alphabetical
        case .pinnedFirst, .unpinnedFirst:
            return .pinned
        case .typeNote, .typeArticle, .typeVideo, .typePodcast, .typeBook, .typeLink:
            return .type
        case .byProject, .byArea, .unattachedFirst, .unattachedLast:
            return .relationship
        case .tagCountDesc, .tagCountAsc:
            return .tags
        case .authorUserFirst, .authorAuroraFirst:
            return .author
        case .pinnedThenUpdated, .typeThenUpdated:
            return .combined
        }
    }
    
    static var categories: [NoteSortCategory] {
        [.dateTime, .alphabetical, .pinned, .type, .relationship, .tags, .author, .combined]
    }
    
    static func options(for category: NoteSortCategory) -> [NoteSortOption] {
        allCases.filter { $0.category == category }
    }
}

enum NoteSortCategory: String, CaseIterable {
    case dateTime = "Date & Time"
    case alphabetical = "Alphabetical"
    case pinned = "Pinned"
    case type = "Type"
    case relationship = "Relationship"
    case tags = "Tags"
    case author = "Author"
    case combined = "Combined"
    
    var icon: String {
        switch self {
        case .dateTime: return "clock"
        case .alphabetical: return "textformat"
        case .pinned: return "pin"
        case .type: return "doc.text"
        case .relationship: return "folder"
        case .tags: return "tag"
        case .author: return "person"
        case .combined: return "arrow.up.arrow.down"
        }
    }
}

