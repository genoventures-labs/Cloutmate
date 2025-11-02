//
//  GlassMaterialTiers.swift
//  CloutmateShared
//
//  Cosmic Deck UI - Material Tier System
//

import SwiftUI

// MARK: - Glass Tier System
public enum GlassTier: Int, CaseIterable {
    case background = 0
    case sidebar = 1
    case contentCard = 2
    case overlay = 3
    case floatingAction = 4
    
    var blurDepth: CGFloat {
        switch self {
        case .background: return 40
        case .sidebar: return 32
        case .contentCard: return 18
        case .overlay: return 14
        case .floatingAction: return 12
        }
    }
    
    var lightLevel: CGFloat {
        switch self {
        case .background: return 0.12
        case .sidebar: return 0.24
        case .contentCard: return 0.36
        case .overlay: return 0.42
        case .floatingAction: return 0.48
        }
    }
}

// MARK: - Glass Tier Calculator
public final class GlassTierCalculator {
    public static func overlapBrightness(tier1: GlassTier, tier2: GlassTier) -> CGFloat {
        let baseLevel = (tier1.lightLevel + tier2.lightLevel) / 2
        return min(baseLevel + 0.10, 1.0)
    }
    
    public static func cornerRadius(for tier: GlassTier) -> CGFloat {
        switch tier {
        case .background: return 0
        case .sidebar: return 18
        case .contentCard: return 20
        case .overlay: return 22
        case .floatingAction: return 28
        }
    }
}

// MARK: - Glass Tier Environment Key
struct GlassTierEnvironmentKey: EnvironmentKey {
    static let defaultValue: GlassTier = .contentCard
}

public extension EnvironmentValues {
    var glassTier: GlassTier {
        get { self[GlassTierEnvironmentKey.self] }
        set { self[GlassTierEnvironmentKey.self] = newValue }
    }
}

// The actual glass panel modifier lives alongside the GlassPanel view.
