//
//  Platform+UI.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import CloutmateShared
import Combine

extension Platform {
    var iconName: String {
        switch self {
        case .threads:
            return "bubble.left.and.bubble.right.fill"
        case .facebook:
            return "f.circle.fill"
        @unknown default:
            return "globe"
        }
    }
    
    var brandColor: Color {
        switch self {
        case .threads:
            return Color(red: 0.6, green: 0.4, blue: 1.0) // Purple
        case .facebook:
            return Color(red: 0.23, green: 0.35, blue: 0.84) // Facebook Blue
        @unknown default:
            return Color.accentColor
        }
    }
    
    var lightColor: Color {
        switch self {
        case .threads:
            return Color(red: 0.6, green: 0.4, blue: 1.0).opacity(0.1)
        case .facebook:
            return Color(red: 0.23, green: 0.35, blue: 0.84).opacity(0.1)
        @unknown default:
            return Color.accentColor.opacity(0.1)
        }
    }
    
    var buttonLabel: String {
        switch self {
        case .threads:
            return "Connect Threads"
        case .facebook:
            return "Connect Facebook"
        @unknown default:
            return "Connect Account"
        }
    }
}
