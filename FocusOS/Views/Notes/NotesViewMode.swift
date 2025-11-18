//
//  NotesViewMode.swift
//  FocusOS
//
//  View mode enum for Notes multi-mode viewing
//

import SwiftUI
import FocusOSShared

enum NotesViewMode: String, CaseIterable {
    case cards = "Cards"
    case list = "List"
    case grid = "Grid"
    case board = "Board"
    case timeline = "Timeline"
    
    var icon: String {
        switch self {
        case .cards: return "rectangle.stack"
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        case .board: return "rectangle.3.group"
        case .timeline: return "chart.line.uptrend.xyaxis"
        }
    }
    
    var displayName: String {
        rawValue
    }
}

