//
//  JournalViewMode.swift
//  Cloutmate
//
//  View mode enum for Journal multi-mode orchestration hub
//

import SwiftUI
import CloutmateShared

enum JournalViewMode: String, CaseIterable {
    case list, timeline, gallery
    
    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .timeline: return "chart.line.uptrend.xyaxis"
        case .gallery: return "photo.on.rectangle"
        }
    }
    
    var displayName: String {
        rawValue.capitalized
    }
}

