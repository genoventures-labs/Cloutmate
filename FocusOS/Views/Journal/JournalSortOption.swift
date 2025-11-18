//
//  JournalSortOption.swift
//  FocusOS
//
//  Sort options for Journal view
//

import Foundation

enum JournalSortOption: String, CaseIterable, Identifiable {
    // Date & Time
    case entryDateDesc = "entryDateDesc"
    case entryDateAsc = "entryDateAsc"
    case createdAtDesc = "createdAtDesc"
    case createdAtAsc = "createdAtAsc"
    case updatedAtDesc = "updatedAtDesc"
    case updatedAtAsc = "updatedAtAsc"
    
    // Alphabetical
    case titleAsc = "titleAsc"
    case titleDesc = "titleDesc"
    
    // Entry Type
    case typeReflection = "typeReflection"
    case typeContentIdea = "typeContentIdea"
    case typeProjectTracker = "typeProjectTracker"
    
    // Mood
    case moodExcited = "moodExcited"
    case moodGrateful = "moodGrateful"
    case moodReflective = "moodReflective"
    case moodMotivated = "moodMotivated"
    case moodContemplative = "moodContemplative"
    case moodCreative = "moodCreative"
    case moodFrustrated = "moodFrustrated"
    case moodCalm = "moodCalm"
    
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
    
    // AI Content
    case hasAIContentFirst = "hasAIContentFirst"
    case noAIContentFirst = "noAIContentFirst"
    
    // Combined
    case typeThenEntryDate = "typeThenEntryDate"
    case moodThenEntryDate = "moodThenEntryDate"
    case authorThenEntryDate = "authorThenEntryDate"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .entryDateDesc: return "Newest Entry"
        case .entryDateAsc: return "Oldest Entry"
        case .createdAtDesc: return "Newest Created"
        case .createdAtAsc: return "Oldest Created"
        case .updatedAtDesc: return "Recently Updated"
        case .updatedAtAsc: return "Oldest Updated"
        case .titleAsc: return "Title A→Z"
        case .titleDesc: return "Title Z→A"
        case .typeReflection: return "Reflections First"
        case .typeContentIdea: return "Content Ideas First"
        case .typeProjectTracker: return "Project Trackers First"
        case .moodExcited: return "Excited First"
        case .moodGrateful: return "Grateful First"
        case .moodReflective: return "Reflective First"
        case .moodMotivated: return "Motivated First"
        case .moodContemplative: return "Contemplative First"
        case .moodCreative: return "Creative First"
        case .moodFrustrated: return "Frustrated First"
        case .moodCalm: return "Calm First"
        case .byProject: return "By Project"
        case .byArea: return "By Area"
        case .unattachedFirst: return "Unattached First"
        case .unattachedLast: return "Unattached Last"
        case .tagCountDesc: return "Most Tags"
        case .tagCountAsc: return "Least Tags"
        case .authorUserFirst: return "User First"
        case .authorAuroraFirst: return "Aurora First"
        case .hasAIContentFirst: return "AI Content First"
        case .noAIContentFirst: return "No AI Content First"
        case .typeThenEntryDate: return "Type, Then Entry Date"
        case .moodThenEntryDate: return "Mood, Then Entry Date"
        case .authorThenEntryDate: return "Author, Then Entry Date"
        }
    }
    
    var icon: String {
        switch self {
        case .entryDateDesc, .entryDateAsc, .createdAtDesc, .createdAtAsc, .updatedAtDesc, .updatedAtAsc: return "calendar"
        case .titleAsc, .titleDesc: return "textformat"
        case .typeReflection, .typeContentIdea, .typeProjectTracker: return "book"
        case .moodExcited, .moodGrateful, .moodReflective, .moodMotivated, .moodContemplative, .moodCreative, .moodFrustrated, .moodCalm: return "face.smiling"
        case .byProject, .byArea: return "folder"
        case .unattachedFirst, .unattachedLast: return "link.slash"
        case .tagCountDesc, .tagCountAsc: return "tag"
        case .authorUserFirst, .authorAuroraFirst: return "person"
        case .hasAIContentFirst, .noAIContentFirst: return "sparkles"
        case .typeThenEntryDate, .moodThenEntryDate, .authorThenEntryDate: return "arrow.up.arrow.down"
        }
    }
    
    var category: JournalSortCategory {
        switch self {
        case .entryDateDesc, .entryDateAsc, .createdAtDesc, .createdAtAsc, .updatedAtDesc, .updatedAtAsc:
            return .dateTime
        case .titleAsc, .titleDesc:
            return .alphabetical
        case .typeReflection, .typeContentIdea, .typeProjectTracker:
            return .entryType
        case .moodExcited, .moodGrateful, .moodReflective, .moodMotivated, .moodContemplative, .moodCreative, .moodFrustrated, .moodCalm:
            return .mood
        case .byProject, .byArea, .unattachedFirst, .unattachedLast:
            return .relationship
        case .tagCountDesc, .tagCountAsc:
            return .tags
        case .authorUserFirst, .authorAuroraFirst:
            return .author
        case .hasAIContentFirst, .noAIContentFirst:
            return .aiContent
        case .typeThenEntryDate, .moodThenEntryDate, .authorThenEntryDate:
            return .combined
        }
    }
    
    static var categories: [JournalSortCategory] {
        [.dateTime, .alphabetical, .entryType, .mood, .relationship, .tags, .author, .aiContent, .combined]
    }
    
    static func options(for category: JournalSortCategory) -> [JournalSortOption] {
        allCases.filter { $0.category == category }
    }
}

enum JournalSortCategory: String, CaseIterable {
    case dateTime = "Date & Time"
    case alphabetical = "Alphabetical"
    case entryType = "Entry Type"
    case mood = "Mood"
    case relationship = "Relationship"
    case tags = "Tags"
    case author = "Author"
    case aiContent = "AI Content"
    case combined = "Combined"
    
    var icon: String {
        switch self {
        case .dateTime: return "calendar"
        case .alphabetical: return "textformat"
        case .entryType: return "book"
        case .mood: return "face.smiling"
        case .relationship: return "folder"
        case .tags: return "tag"
        case .author: return "person"
        case .aiContent: return "sparkles"
        case .combined: return "arrow.up.arrow.down"
        }
    }
}

