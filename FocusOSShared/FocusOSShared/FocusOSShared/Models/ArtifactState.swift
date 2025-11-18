//
//  ArtifactState.swift
//  FocusOSShared
//
//  Created by Migration
//

import Foundation

public enum ArtifactState: String, Codable, CaseIterable {
    case idea = "idea"
    case draft = "draft"
    case final = "final"
    case published = "published"
    case archived = "archived"
    
    public var displayName: String {
        switch self {
        case .idea:
            return "Idea"
        case .draft:
            return "Draft"
        case .final:
            return "Final"
        case .published:
            return "Published"
        case .archived:
            return "Archived"
        }
    }
}

