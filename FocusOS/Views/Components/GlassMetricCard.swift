//
//  GlassMetricCard.swift
//  FocusOS
//
//  Minimal Metric Card Component
//

import SwiftUI

struct GlassMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let gradientColor: Color // Legacy parameter
    
    @State private var isHovered = false
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    init(
        title: String,
        value: String,
        icon: String,
        color: Color,
        gradientColor: Color? = nil // Kept for compatibility
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.gradientColor = gradientColor ?? color
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Icon
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(color)
                }
                
                Spacer()
            }
            
            Spacer()
            
            // Value and title
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(glassColorSystem.textSecondary())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(glassColorSystem.cardColor())
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(glassColorSystem.borderColor(), lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(isHovered ? 0.12 : 0.08),
            radius: isHovered ? 8 : 6,
            x: 0,
            y: isHovered ? 3 : 2
        )
        .scaleEffect(isHovered ? 1.002 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
        GlassMetricCard(
            title: "Total Posts",
            value: "42",
            icon: "doc.text.fill",
            color: .kosmicBlue
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
            color: .kosmicPurple
        )
        
        GlassMetricCard(
            title: "Likes",
            value: "892",
            icon: "hand.thumbsup.fill",
            color: .orange
        )
    }
    .padding()
    .environmentObject(GlassColorSystem())
}
