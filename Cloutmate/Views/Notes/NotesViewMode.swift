//
//  NotesViewMode.swift
//  Cloutmate
//
//  View mode enum for Notes multi-mode viewing
//

import SwiftUI
import CloutmateShared

enum NotesViewMode: String, CaseIterable {
    case cards = "Cards"
    case list = "List"
    case grid = "Grid"
    case table = "Table"
    case compact = "Compact"
    
    var icon: String {
        switch self {
        case .cards: return "rectangle.stack"
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        case .table: return "tablecells"
        case .compact: return "list.bullet.rectangle"
        }
    }
    
    var displayName: String {
        rawValue
    }
}

