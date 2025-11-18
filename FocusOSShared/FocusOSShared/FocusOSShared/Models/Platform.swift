//
//  Platform.swift
//  FocusOS
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation

// Platform enum removed - FocusOS is no longer a social media scheduling app
// PostStatus enum kept for internal post status tracking

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


