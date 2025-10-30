//
//  GlassPanel.swift
//  Cloutmate
//
//  Glassmorphic Harmony UI - Glass Panel Component
//

import SwiftUI

struct GlassPanel<Content: View>: View {
    let tier: GlassTier
    let cornerRadius: CGFloat
    let showInnerStroke: Bool
    let showNoise: Bool
    let tintColor: Color?
    let content: Content
    
    @Environment(\.accessibilityGlassManager) private var accessibilityManager
    @Environment(\.colorScheme) private var colorScheme
    
    init(
        tier: GlassTier = .contentCard,
        cornerRadius: CGFloat? = nil,
        showInnerStroke: Bool = true,
        showNoise: Bool = true,
        tintColor: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.tier = tier
        self.cornerRadius = cornerRadius ?? GlassTierCalculator.cornerRadius(for: tier)
        self.showInnerStroke = showInnerStroke
        self.showNoise = showNoise
        self.tintColor = tintColor
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                ZStack {
                    // Base glass material
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(accessibilityManager.getMaterial(for: tier))
                    
                    // Tint overlay
                    if let tintColor = tintColor {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(tintColor.opacity(tier.lightLevel))
                    }
                    
                    // Noise texture overlay for realism
                    if showNoise && accessibilityManager.shouldApplyEffects() {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.005),
                                        Color.black.opacity(0.005)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blendMode(.overlay)
                    }
                    
                    // Inner stroke for depth
                    if showInnerStroke {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                Color.white.opacity(GlassTierCalculator.innerStrokeOpacity(for: tier)),
                                lineWidth: 1
                            )
                    }
                    
                    // Inner shadow for float illusion
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.05),
                                    Color.clear
                                ]),
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .blur(radius: GlassTierCalculator.innerShadowBlur(for: tier))
                        .offset(y: 2)
                }
            )
            .environment(\.glassTier, tier)
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
        GlassPanel(tier: .contentCard, tintColor: .blue) {
            Text("Content Card Glass")
                .padding()
        }
        
        GlassPanel(tier: .overlay, tintColor: .purple) {
            Text("Overlay Glass")
                .padding()
        }
    }
    .padding()
}
