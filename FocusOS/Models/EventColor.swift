//
//  EventColor.swift
//  FocusOS
//
//  Aurora Calendar Cognition Layer - Color definitions
//

import Foundation
import SwiftUI

enum EventColor: String, CaseIterable {
    case red, orange, yellow, blue, green, purple
    
    var hex: String {
        switch self {
        case .red: return "#FF3B30"
        case .orange: return "#FF9500"
        case .yellow: return "#FFCC00"
        case .blue: return "#007AFF"
        case .green: return "#34C759"
        case .purple: return "#AF52DE"
        }
    }
    
    var color: Color {
        switch self {
        case .red: return Color(red: 1.0, green: 0.231, blue: 0.188)
        case .orange: return Color(red: 1.0, green: 0.584, blue: 0.0)
        case .yellow: return Color(red: 1.0, green: 0.8, blue: 0.0)
        case .blue: return Color(red: 0.0, green: 0.478, blue: 1.0)
        case .green: return Color(red: 0.204, green: 0.780, blue: 0.349)
        case .purple: return Color(red: 0.686, green: 0.322, blue: 0.871)
        }
    }
    
    var description: String {
        switch self {
        case .red: return "Critical urgency"
        case .orange: return "High priority"
        case .yellow: return "Mild time pressure"
        case .blue: return "Deep focus work"
        case .green: return "Calm & flexible"
        case .purple: return "Personal & recovery"
        }
    }
    
    var urgencyThreshold: Double {
        switch self {
        case .red: return 0.85
        case .orange: return 0.65
        case .yellow: return 0.45
        case .blue: return 0.35
        case .green: return 0.15
        case .purple: return 0.0
        }
    }
    
    static func from(urgencyScore: Double) -> EventColor {
        if urgencyScore >= EventColor.red.urgencyThreshold {
            return .red
        } else if urgencyScore >= EventColor.orange.urgencyThreshold {
            return .orange
        } else if urgencyScore >= EventColor.yellow.urgencyThreshold {
            return .yellow
        } else if urgencyScore >= EventColor.blue.urgencyThreshold {
            return .blue
        } else if urgencyScore >= EventColor.green.urgencyThreshold {
            return .green
        } else {
            return .purple
        }
    }
    
    static func from(hex: String) -> EventColor? {
        return EventColor.allCases.first { $0.hex == hex }
    }
}

