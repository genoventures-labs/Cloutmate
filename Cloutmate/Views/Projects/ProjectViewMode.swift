//
//  ProjectViewMode.swift
//  Cloutmate
//
//  View mode enum for Projects multi-mode orchestration hub
//

import SwiftUI
import CloutmateShared

enum ProjectViewMode: String, CaseIterable {
    case list, board, roadmap, gallery
    
    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .board: return "square.grid.2x2"
        case .roadmap: return "chart.bar.doc.horizontal"
        case .gallery: return "photo.on.rectangle"
        }
    }
    
    var displayName: String {
        rawValue.capitalized
    }
}

enum ProjectFilter: String, CaseIterable {
    case all, active, paused, completed
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .active: return "Active"
        case .paused: return "Paused"
        case .completed: return "Completed"
        }
    }
    
    func matches(_ status: ProjectStatus) -> Bool {
        switch self {
        case .all: return true
        case .active: return status == .active
        case .paused: return status == .paused
        case .completed: return status == .completed
        }
    }
}

