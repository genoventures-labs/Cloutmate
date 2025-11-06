//
//  OutputFormat.swift
//  CloutmateShared
//
//  Created by Migration
//

import Foundation

public enum OutputFormat: String, Codable, CaseIterable {
    case brief = "brief"
    case summary = "summary"
    case reflection = "reflection"
    case report = "report"
    case releaseNote = "releaseNote"
    case lessonLearned = "lessonLearned"
    
    public var displayName: String {
        switch self {
        case .brief:
            return "Brief"
        case .summary:
            return "Summary"
        case .reflection:
            return "Reflection"
        case .report:
            return "Report"
        case .releaseNote:
            return "Release Note"
        case .lessonLearned:
            return "Lesson Learned"
        }
    }
    
    public var colorName: String {
        switch self {
        case .brief:
            return "cyan"
        case .summary:
            return "blue"
        case .reflection:
            return "purple"
        case .report:
            return "indigo"
        case .releaseNote:
            return "green"
        case .lessonLearned:
            return "orange"
        }
    }
    
    public var description: String {
        switch self {
        case .brief:
            return "Quick, concise summary"
        case .summary:
            return "Comprehensive overview"
        case .reflection:
            return "Personal reflection and insights"
        case .report:
            return "Detailed status report"
        case .releaseNote:
            return "Release announcement format"
        case .lessonLearned:
            return "Key learnings and takeaways"
        }
    }
}

