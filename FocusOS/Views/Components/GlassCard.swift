//
//  GlassCard.swift
//  FocusOS
//
//  Minimal Apple Music-inspired Card Component
//

import SwiftUI

struct GlassCard<Content: View>: View {
    let tier: GlassTier
    let cornerRadius: CGFloat
    let gradientTint: Color? // Legacy parameter
    let showHeader: Bool
    let showFooter: Bool
    let headerContent: (() -> AnyView)?
    let footerContent: (() -> AnyView)?
    let content: Content
    
    @State private var isHovered = false
    @Environment(\.accessibilityGlassManager) private var accessibilityManager
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    init(
        tier: GlassTier = .contentCard,
        cornerRadius: CGFloat? = nil,
        gradientTint: Color? = nil, // Kept for compatibility
        showHeader: Bool = false,
        showFooter: Bool = false,
        headerContent: (() -> AnyView)? = nil,
        footerContent: (() -> AnyView)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.tier = tier
        self.cornerRadius = cornerRadius ?? 12 // Consistent corner radius
        self.gradientTint = gradientTint
        self.showHeader = showHeader
        self.showFooter = showFooter
        self.headerContent = headerContent
        self.footerContent = footerContent
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if showHeader, let header = headerContent {
                VStack(spacing: 12) {
                    header()
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    Divider()
                        .background(glassColorSystem.dividerColor())
                        .padding(.horizontal, 20)
                }
            }
            
            content
                .padding(.horizontal, 20)
                .padding(.vertical, showHeader || showFooter ? 16 : 20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            
            if showFooter, let footer = footerContent {
                Divider()
                    .background(glassColorSystem.dividerColor())
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                footer()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(cardBackground)
        .overlay(borderOverlay)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(
            color: shadowColor,
            radius: shadowRadius,
            x: 0,
            y: shadowY
        )
        .scaleEffect(isHovered ? 1.003 : 1.0) // Minimal hover scale
        .animation(.easeInOut(duration: 0.2), value: isHovered)
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

// MARK: - Private helpers
private extension GlassCard {
    var cardBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(glassColorSystem.cardColor())
    }
    
    var borderOverlay: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(glassColorSystem.borderColor(), lineWidth: 1)
    }
    
    var shadowColor: Color {
        isHovered ? Color.black.opacity(0.08) : Color.black.opacity(0.05)
    }
    
    var shadowRadius: CGFloat {
        isHovered ? 6 : 4
    }
    
    var shadowY: CGFloat {
        isHovered ? 3 : 2
    }
}

#Preview {
    VStack(spacing: 20) {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Content Card")
                    .font(.system(size: 20, weight: .semibold))
                Text("Clean minimal design matching Apple Music aesthetic.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        
        GlassCard(showHeader: true, headerContent: { AnyView(Text("With Header").font(.headline)) }) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Item 1")
                Text("Item 2")
            }
        }
    }
    .padding()
    .environmentObject(GlassColorSystem())
}
