//
//  AreaViewMode.swift
//  Cloutmate
//
//  View mode enum for Areas multi-mode orchestration hub
//

import SwiftUI

enum AreaViewMode: String, CaseIterable {
    case grid, list, board, overview
    
    var icon: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        case .board: return "rectangle.stack"
        case .overview: return "chart.bar.doc.horizontal"
        }
    }
    
    var displayName: String {
        switch self {
        case .grid: return "Grid"
        case .list: return "List"
        case .board: return "Board"
        case .overview: return "Overview"
        }
    }
}

