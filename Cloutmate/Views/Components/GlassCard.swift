//
//  GlassCard.swift
//  Cloutmate
//
//  Glassmorphic Harmony UI - Glass Card Component
//

import SwiftUI

struct GlassCard<Content: View>: View {
    let tier: GlassTier
    let cornerRadius: CGFloat
    let gradientTint: Color?
    let showHeader: Bool
    let showFooter: Bool
    let headerContent: (() -> AnyView)?
    let footerContent: (() -> AnyView)?
    let content: Content
    
    @State private var isHovered = false
    @Environment(\.accessibilityGlassManager) private var accessibilityManager
    
    init(
        tier: GlassTier = .contentCard,
        cornerRadius: CGFloat? = nil,
        gradientTint: Color? = nil,
        showHeader: Bool = false,
        showFooter: Bool = false,
        headerContent: (() -> AnyView)? = nil,
        footerContent: (() -> AnyView)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.tier = tier
        self.cornerRadius = cornerRadius ?? GlassTierCalculator.cornerRadius(for: tier)
        self.gradientTint = gradientTint
        self.showHeader = showHeader
        self.showFooter = showFooter
        self.headerContent = headerContent
        self.footerContent = footerContent
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            if showHeader, let header = headerContent {
                VStack(spacing: 8) {
                    header()
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    Divider()
                }
            }
            
            // Content
            content
                .padding(.horizontal, showHeader || showFooter ? 16 : 0)
                .padding(.vertical, showHeader || showFooter ? 16 : 0)
            
            // Footer
            if showFooter, let footer = footerContent {
                VStack(spacing: 8) {
                    Divider()
                    footer()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .glassPanel(
            tier: tier,
            cornerRadius: cornerRadius,
            tintColor: gradientTint
        )
        .shadow(
            color: isHovered ? .black.opacity(0.15) : .black.opacity(0.05),
            radius: isHovered ? 12 : 4,
            y: isHovered ? 8 : 2
        )
        .scaleEffect(isHovered ? GlassMotion.Transform.hoverScale : 1.0)
        .overlay(
            // Shimmer effect on hover
            Group {
                if isHovered && accessibilityManager.shouldApplyEffects() {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.2),
                            Color.white.opacity(0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .blendMode(.overlay)
                }
            }
        )
        .animation(GlassMotion.Easing.spring, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Convenience Initializers
extension GlassCard {
    init(
        tier: GlassTier = .contentCard,
        gradientTint: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            tier: tier,
            gradientTint: gradientTint,
            showHeader: false,
            showFooter: false,
            headerContent: nil,
            footerContent: nil,
            content: content
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        GlassCard(gradientTint: .blue) {
            Text("Simple Glass Card")
        }
        
        GlassCard(
            showHeader: true,
            headerContent: { AnyView(Text("Header").font(.headline)) }
        ) {
            Text("Card with Header")
        }
    }
    .padding()
}
