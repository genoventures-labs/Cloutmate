//
//  GlassMaterialTiers.swift
//  Cloutmate
//
//  Minimal Material Tier System
//

import SwiftUI

// MARK: - Material Tier System
enum GlassTier: Int, CaseIterable {
    case background = 0
    case sidebar = 1
    case contentCard = 2
    case overlay = 3
    case floatingAction = 4
    
    var blurDepth: CGFloat {
        // Minimal blur for Apple Music aesthetic
        switch self {
        case .background: return 0
        case .sidebar: return 0
        case .contentCard: return 0
        case .overlay: return 2
        case .floatingAction: return 3
        }
    }
    
    var lightLevel: CGFloat {
        // Light levels for theme-aware backgrounds
        // These are legacy values, actual colors come from GlassColorSystem
        switch self {
        case .background: return 0.0
        case .sidebar: return 0.05
        case .contentCard: return 0.10
        case .overlay: return 0.15
        case .floatingAction: return 0.20
        }
    }
}

// MARK: - Tier Calculator
class GlassTierCalculator {
    /// Legacy method - no longer used in minimal design
    static func overlapBrightness(tier1: GlassTier, tier2: GlassTier) -> CGFloat {
        return tier2.lightLevel
    }
    
    /// Gets the recommended corner radius for a tier
    static func cornerRadius(for tier: GlassTier) -> CGFloat {
        // Consistent corner radii for Apple Music aesthetic
        switch tier {
        case .background: return 0
        case .sidebar: return 0
        case .contentCard: return 12
        case .overlay: return 12
        case .floatingAction: return 56 // Circle radius
        }
    }
}

// MARK: - Glass Tier Environment Key
struct GlassTierEnvironmentKey: EnvironmentKey {
    static let defaultValue: GlassTier = .contentCard
}

extension EnvironmentValues {
    var glassTier: GlassTier {
        get { self[GlassTierEnvironmentKey.self] }
        set { self[GlassTierEnvironmentKey.self] = newValue }
    }
}

// The actual glass panel modifier lives alongside the GlassPanel view.
