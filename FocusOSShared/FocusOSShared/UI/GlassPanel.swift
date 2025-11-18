//
//  GlassPanel.swift
//  FocusOSShared
//
//  Minimal Apple Music-inspired Panel Component
//

import SwiftUI

struct GlassPanel<Content: View>: View {
    let tier: GlassTier
    let cornerRadius: CGFloat
    let showInnerStroke: Bool
    let showNoise: Bool // Legacy parameter, no longer used
    let tintColor: Color?
    let content: Content
    
    @Environment(\.accessibilityGlassManager) private var accessibilityManager
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    init(
        tier: GlassTier = .contentCard,
        cornerRadius: CGFloat? = nil,
        showInnerStroke: Bool = true,
        showNoise: Bool = true, // Kept for compatibility
        tintColor: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.tier = tier
        self.cornerRadius = cornerRadius ?? 12 // Consistent corner radius
        self.showInnerStroke = showInnerStroke
        self.showNoise = showNoise
        self.tintColor = tintColor
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor)
                    .overlay(borderStroke)
                    .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
            )
            .environment(\.glassTier, tier)
    }
    
    // MARK: - Simplified Styling
    
    private var backgroundColor: Color {
        // Get the appropriate background color based on tier
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
    
    private var shadowColor: Color {
        switch tier {
        case .background:
            return .clear
        case .sidebar:
            return Color.black.opacity(0.1)
        case .contentCard:
            return Color.black.opacity(0.12)
        case .overlay:
            return Color.black.opacity(0.15)
        case .floatingAction:
            return Color.black.opacity(0.18)
        }
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

// MARK: - Modifier Extension
extension View {
    func glassPanel(
        tier: GlassTier = .contentCard,
        cornerRadius: CGFloat? = nil,
        showInnerStroke: Bool = true,
        showNoise: Bool = true,
        tintColor: Color? = nil
    ) -> some View {
        GlassPanel(
            tier: tier,
            cornerRadius: cornerRadius,
            showInnerStroke: showInnerStroke,
            showNoise: showNoise,
            tintColor: tintColor
        ) {
            self
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        GlassPanel(tier: .contentCard) {
            Text("Content Card")
                .font(.headline)
                .padding()
        }
        
        GlassPanel(tier: .overlay) {
            Text("Overlay Surface")
                .font(.headline)
                .padding()
        }
    }
    .padding()
    .environmentObject(GlassColorSystem())
}
