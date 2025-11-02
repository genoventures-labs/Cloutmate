//
//  ARTEGlassPanel.swift
//  Cloutmate
//
//  Phase 7: ARTE - Aurora Reactive Theme Engine
//  ARTE-aware wrapper for GlassPanel that applies emotional modulation
//

import SwiftUI
import CloutmateShared

/// ARTE-enhanced GlassPanel that applies emotional shadow tones
/// Use this in the main app instead of the base GlassPanel for ARTE integration
struct ARTEGlassPanel<Content: View>: View {
    let tier: GlassTier
    let cornerRadius: CGFloat
    let showInnerStroke: Bool
    let tintColor: Color?
    let content: Content
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    init(
        tier: GlassTier = .contentCard,
        cornerRadius: CGFloat? = nil,
        showInnerStroke: Bool = true,
        tintColor: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.tier = tier
        self.cornerRadius = cornerRadius ?? 12
        self.showInnerStroke = showInnerStroke
        self.tintColor = tintColor
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor)
                    .overlay(borderStroke)
                    .shadow(color: arteShadowColor, radius: shadowRadius, x: 0, y: shadowY)
            )
            .environment(\.glassTier, tier)
    }
    
    // MARK: - ARTE-Enhanced Styling
    
    private var backgroundColor: Color {
        switch tier {
        case .background:
            return glassColorSystem.backgroundColor()
        case .sidebar:
            return glassColorSystem.backgroundElevated()
        case .contentCard:
            return glassColorSystem.cardColor()
        case .overlay:
            return glassColorSystem.cardElevated()
        case .floatingAction:
            return glassColorSystem.cardElevated()
        }
    }
    
    @ViewBuilder
    private var borderStroke: some View {
        if showInnerStroke {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(glassColorSystem.borderColor(), lineWidth: 1)
        }
    }
    
    /// ARTE-aware shadow color with emotional modulation
    private var arteShadowColor: Color {
        let baseShadow: Color
        switch tier {
        case .background:
            baseShadow = .clear
        case .sidebar:
            baseShadow = Color.black.opacity(0.1)
        case .contentCard:
            baseShadow = Color.black.opacity(0.12)
        case .overlay:
            baseShadow = Color.black.opacity(0.15)
        case .floatingAction:
            baseShadow = Color.black.opacity(0.18)
        }
        
        // Apply ARTE emotional modulation if enabled and not transparent
        if baseShadow != .clear && glassColorSystem.isARTEEnabled {
            return glassColorSystem.emotionalShadowTone()
        }
        return baseShadow
    }
    
    private var shadowRadius: CGFloat {
        switch tier {
        case .background:
            return 0
        case .sidebar:
            return 4
        case .contentCard:
            return 6
        case .overlay:
            return 8
        case .floatingAction:
            return 12
        }
    }
    
    private var shadowY: CGFloat {
        switch tier {
        case .background:
            return 0
        case .sidebar:
            return 2
        case .contentCard:
            return 3
        case .overlay:
            return 4
        case .floatingAction:
            return 6
        }
    }
}

// MARK: - Convenience Extension
extension View {
    /// Apply ARTE-enhanced glass panel styling
    func arteGlassPanel(
        tier: GlassTier = .contentCard,
        cornerRadius: CGFloat? = nil,
        showInnerStroke: Bool = true,
        tintColor: Color? = nil
    ) -> some View {
        ARTEGlassPanel(
            tier: tier,
            cornerRadius: cornerRadius,
            showInnerStroke: showInnerStroke,
            tintColor: tintColor
        ) {
            self
        }
    }
}

