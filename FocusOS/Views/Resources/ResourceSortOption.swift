//
//  ResourceSortOption.swift
//  FocusOS
//
//  Sort options for Resources view
//

import Foundation

enum ResourceSortOption: String, CaseIterable, Identifiable {
    // Date & Time
    case updatedAtDesc = "updatedAtDesc"
    case updatedAtAsc = "updatedAtAsc"
    case createdAtDesc = "createdAtDesc"
    case createdAtAsc = "createdAtAsc"
    
    // Alphabetical
    case titleAsc = "titleAsc"
    case titleDesc = "titleDesc"
    
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
    case typeThenUpdated = "typeThenUpdated"
    case authorThenUpdated = "authorThenUpdated"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .updatedAtDesc: return "Recently Updated"
        case .updatedAtAsc: return "Oldest Updated"
        case .createdAtDesc: return "Newest Created"
        case .createdAtAsc: return "Oldest Created"
        case .titleAsc: return "Title A→Z"
        case .titleDesc: return "Title Z→A"
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
        case .typeThenUpdated: return "Type, Then Updated"
        case .authorThenUpdated: return "Author, Then Updated"
        }
    }
    
    var icon: String {
        switch self {
        case .updatedAtDesc, .updatedAtAsc: return "arrow.clockwise"
        case .createdAtDesc, .createdAtAsc: return "plus.circle"
        case .titleAsc, .titleDesc: return "textformat"
        case .typeNote, .typeArticle, .typeVideo, .typePodcast, .typeBook, .typeLink: return "doc.text"
        case .byProject, .byArea: return "folder"
        case .unattachedFirst, .unattachedLast: return "link.slash"
        case .tagCountDesc, .tagCountAsc: return "tag"
        case .authorUserFirst, .authorAuroraFirst: return "person"
        case .typeThenUpdated, .authorThenUpdated: return "arrow.up.arrow.down"
        }
    }
    
    var category: ResourceSortCategory {
        switch self {
        case .updatedAtDesc, .updatedAtAsc, .createdAtDesc, .createdAtAsc:
            return .dateTime
        case .titleAsc, .titleDesc:
            return .alphabetical
        case .typeNote, .typeArticle, .typeVideo, .typePodcast, .typeBook, .typeLink:
            return .type
        case .byProject, .byArea, .unattachedFirst, .unattachedLast:
            return .relationship
        case .tagCountDesc, .tagCountAsc:
            return .tags
        case .authorUserFirst, .authorAuroraFirst:
            return .author
        case .typeThenUpdated, .authorThenUpdated:
            return .combined
        }
    }
    
    static var categories: [ResourceSortCategory] {
        [.dateTime, .alphabetical, .type, .relationship, .tags, .author, .combined]
    }
    
    static func options(for category: ResourceSortCategory) -> [ResourceSortOption] {
        allCases.filter { $0.category == category }
    }
}

enum ResourceSortCategory: String, CaseIterable {
    case dateTime = "Date & Time"
    case alphabetical = "Alphabetical"
    case type = "Type"
    case relationship = "Relationship"
    case tags = "Tags"
    case author = "Author"
    case combined = "Combined"
    
    var icon: String {
        switch self {
        case .dateTime: return "clock"
        case .alphabetical: return "textformat"
        case .type: return "doc.text"
        case .relationship: return "folder"
        case .tags: return "tag"
        case .author: return "person"
        case .combined: return "arrow.up.arrow.down"
        }
    }
}

