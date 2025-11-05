//
//  ColorExtensions.swift
//  Cloutmate
//
//  Color extensions to replace asset catalog lookups and provide theme-aware colors
//

import SwiftUI

extension Color {
    /// System blue color (Kosmic blue) - replaces .blue to avoid asset catalog lookup
    static var kosmicBlue: Color {
        if let system = GlassColorSystem.active {
            return system.glassTint(for: .primary)
        }
        return Color(red: 72/255, green: 131/255, blue: 255/255)
    }
    
    /// System green color (success/accent) - replaces .green to avoid asset catalog lookup
    static var kosmicGreen: Color {
        if let system = GlassColorSystem.active {
            return system.glassTint(for: .success)
        }
        return Color(red: 67/255, green: 160/255, blue: 71/255)
    }
    
    /// System purple color (Kosmic purple) - replaces .purple
    static var kosmicPurple: Color {
        if let system = GlassColorSystem.active {
            return system.glassTint(for: .accent)
        }
        return Color(red: 124/255, green: 77/255, blue: 255/255)
    }
    
    // Legacy compatibility - map system colors to explicit values
    // These avoid asset catalog lookups while maintaining compatibility
    static var safeBlue: Color {
        kosmicBlue
    }
    
    static var safeGreen: Color {
        kosmicGreen
    }
}

