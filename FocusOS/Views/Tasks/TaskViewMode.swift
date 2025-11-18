//
//  TaskViewMode.swift
//  FocusOS
//
//  View mode enum for Tasks multi-mode orchestration hub
//

import SwiftUI
import FocusOSShared

enum TaskViewMode: String, CaseIterable {
    case list, board, planner, gallery
    
    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .board: return "square.grid.2x2"
        case .planner: return "chart.bar.doc.horizontal"
        case .gallery: return "photo.on.rectangle"
        }
    }
    
    var displayName: String {
        rawValue.capitalized
    }
}

