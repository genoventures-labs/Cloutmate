//
//  ArtifactFilter.swift
//  Cloutmate
//
//  Artifacts V2 - Filter enum for artifact states
//

import Foundation
import CloutmateShared

enum ArtifactFilter: String, CaseIterable {
    case all, draft, published, archived
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .draft: return "Draft"
        case .published: return "Published"
        case .archived: return "Archived"
        }
    }
    
    func matches(_ state: ArtifactState) -> Bool {
        switch self {
        case .all: return true
        case .draft: return state == .draft
        case .published: return state == .published
        case .archived: return state == .archived
        }
    }
}

