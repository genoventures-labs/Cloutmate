//
//  GlassMetricCard.swift
//  Cloutmate
//
//  Glassmorphic Harmony UI - Glass Metric Card Component
//

import SwiftUI

struct GlassMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let gradientColor: Color
    
    @State private var isHovered = false
    @Environment(\.accessibilityGlassManager) private var accessibilityManager
    
    init(
        title: String,
        value: String,
        icon: String,
        color: Color,
        gradientColor: Color? = nil
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.gradientColor = gradientColor ?? color
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Icon with circular glass background
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color.opacity(0.9))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(color.opacity(0.1))
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                            )
                    )
                
                Spacer()
            }
            
            Spacer()
            
            // Value and title
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .tracking(0.2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassPanel(
            tier: .contentCard,
            cornerRadius: 16,
            tintColor: gradientColor.opacity(0.05)
        )
        .overlay(
            // Shimmer pass on hover
            Group {
                if isHovered && accessibilityManager.shouldApplyEffects() {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.3),
                            Color.white.opacity(0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .blendMode(.overlay)
                    .animation(
                        Animation.linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                        value: isHovered
                    )
                }
            }
        )
        .shadow(
            color: isHovered ? .black.opacity(0.15) : .black.opacity(0.05),
            radius: isHovered ? 12 : 4,
            y: isHovered ? 6 : 2
        )
        .scaleEffect(isHovered ? GlassMotion.Transform.hoverScale : 1.0)
        .animation(GlassMotion.Easing.spring, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
        GlassMetricCard(
            title: "Total Posts",
            value: "42",
            icon: "doc.text.fill",
            color: .blue
        )
        
        GlassMetricCard(
            title: "Engagement",
            value: "4.2%",
            icon: "heart.fill",
            color: .pink
        )
        
        GlassMetricCard(
            title: "Reach",
            value: "1.2K",
            icon: "eye.fill",
            color: .purple
        )
        
        GlassMetricCard(
            title: "Likes",
            value: "892",
            icon: "hand.thumbsup.fill",
            color: .orange
        )
    }
    .padding()
}
