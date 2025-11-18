//
//  ThemeManager.swift
//  FocusOS
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import Combine

enum AppTheme: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case minimal = "Minimal"
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .minimal:
            return nil // Follow system
        }
    }
}

final class ThemeManager: ObservableObject {
    @Published var currentTheme: AppTheme = .minimal
    
    func applyTheme(_ theme: AppTheme) {
        currentTheme = theme
    }
}

