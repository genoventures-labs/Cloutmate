//
//  Platform.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation

public enum Platform: String, Codable, CaseIterable {
    case threads = "threads"
    case facebook = "facebook"
    
    public var displayName: String {
        switch self {
        case .threads:
            return "Threads"
        case .facebook:
            return "Facebook"
        }
    }
    
    public var colorName: String {
        switch self {
        case .threads:
            return "purple"
        case .facebook:
            return "blue"
        }
    }
}

public enum PostStatus: String, Codable, CaseIterable {
    case draft = "draft"
    case scheduled = "scheduled"
    case publishing = "publishing"
    case published = "published"
    case failed = "failed"
    
    public var displayName: String {
        switch self {
        case .draft:
            return "Draft"
        case .scheduled:
            return "Scheduled"
        case .publishing:
            return "Publishing"
        case .published:
            return "Published"
        case .failed:
            return "Failed"
        }
    }
}

