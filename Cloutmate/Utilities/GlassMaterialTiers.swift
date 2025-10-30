//
//  GlassMaterialTiers.swift
//  Cloutmate
//
//  Glassmorphic Harmony UI - Material Tier System
//

import SwiftUI

// MARK: - Glass Tier System
enum GlassTier: Int, CaseIterable {
    case background = 0
    case sidebar = 1
    case contentCard = 2
    case overlay = 3
    case floatingAction = 4
    
    var blurDepth: CGFloat {
        switch self {
        case .background: return 50
        case .sidebar: return 35
        case .contentCard: return 25
        case .overlay: return 15
        case .floatingAction: return 10
        }
    }
    
    var lightLevel: CGFloat {
        switch self {
        case .background: return 0.15
        case .sidebar: return 0.25
        case .contentCard: return 0.40
        case .overlay: return 0.50
        case .floatingAction: return 0.60
        }
    }
    
    var saturation: CGFloat {
        switch self {
        case .sidebar: return 1.3 // 130% saturation boost
        default: return 1.0
        }
    }
    
    var material: Material {
        // For now, using standard materials
        // In a production implementation, you'd create custom materials with the exact blur depth
        switch self {
        case .background: return .thinMaterial
        case .sidebar: return .regularMaterial
        case .contentCard: return .thinMaterial
        case .overlay: return .ultraThinMaterial
        case .floatingAction: return .ultraThinMaterial
        }
    }
}

// MARK: - Glass Tier Calculator
class GlassTierCalculator {
    /// Calculates the effective light level when two tiers overlap
    /// Applies the +10% brightness increase for refraction simulation
    static func overlapBrightness(tier1: GlassTier, tier2: GlassTier) -> CGFloat {
        let baseLevel = (tier1.lightLevel + tier2.lightLevel) / 2
        return min(baseLevel + 0.10, 1.0) // +10% refraction effect
    }
    
    /// Gets the recommended corner radius for a tier
    static func cornerRadius(for tier: GlassTier) -> CGFloat {
        switch tier {
        case .background: return 0
        case .sidebar: return 0
        case .contentCard: return 16
        case .overlay: return 20
        case .floatingAction: return 12
        }
    }
    
    /// Gets the recommended inner stroke opacity for a tier
    static func innerStrokeOpacity(for tier: GlassTier) -> CGFloat {
        switch tier {
        case .background: return 0.0
        case .sidebar: return 0.15
        case .contentCard: return 0.10
        case .overlay: return 0.12
        case .floatingAction: return 0.15
        }
    }
    
    /// Gets the inner shadow blur for float illusion
    static func innerShadowBlur(for tier: GlassTier) -> CGFloat {
        switch tier {
        case .background: return 0
        case .sidebar: return 2
        case .contentCard: return 4
        case .overlay: return 6
        case .floatingAction: return 3
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

// MARK: - Glass Panel Modifier
struct GlassPanelModifier: ViewModifier {
    let tier: GlassTier
    let cornerRadius: CGFloat
    let showInnerStroke: Bool
    let tintColor: Color?
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base glass material
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(tier.material)
                    
                    // Inner stroke for depth
                    if showInnerStroke {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(GlassTierCalculator.innerStrokeOpacity(for: tier)), lineWidth: 1)
                    }
                    
                    // Optional tint overlay
                    if let tintColor = tintColor {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(tintColor.opacity(0.1))
                    }
                }
            )
            .environment(\.glassTier, tier)
    }
}

extension View {
    func glassPanel(tier: GlassTier = .contentCard, 
                   cornerRadius: CGFloat? = nil,
                   showInnerStroke: Bool = true,
                   tintColor: Color? = nil) -> some View {
        modifier(GlassPanelModifier(
            tier: tier,
            cornerRadius: cornerRadius ?? GlassTierCalculator.cornerRadius(for: tier),
            showInnerStroke: showInnerStroke,
            tintColor: tintColor
        ))
    }
}
