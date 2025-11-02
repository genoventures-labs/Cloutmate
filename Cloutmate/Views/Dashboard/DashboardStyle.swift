//
//  DashboardStyle.swift
//  Cloutmate
//
//  Tokens for palette, typography and card chrome for the dashboard.
//

import SwiftUI

enum KosmicPalette {
    static let violet = Color(red: 0.44, green: 0.31, blue: 0.92)
    static let cyan = Color(red: 0.20, green: 0.76, blue: 0.86)
    static let kosmicBlue = Color(red: 72/255, green: 131/255, blue: 255/255) // Primary brand blue
    static let kosmicGreen = Color(red: 67/255, green: 160/255, blue: 71/255) // Success green
    static let neutral900 = Color(red: 0.10, green: 0.10, blue: 0.12)
    static let neutral600 = Color(red: 0.36, green: 0.38, blue: 0.42)
    static let neutral300 = Color(red: 0.78, green: 0.80, blue: 0.84)
}

// MARK: - ShapeStyle Extension for Kosmic Palette
extension ShapeStyle where Self == Color {
    static var kosmicBlue: Color { KosmicPalette.kosmicBlue }
    static var kosmicGreen: Color { KosmicPalette.kosmicGreen }
    static var kosmicViolet: Color { KosmicPalette.violet }
    static var kosmicCyan: Color { KosmicPalette.cyan }
}

struct SectionTitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(.primary)
            .lineSpacing(4)
    }
}

struct MetricValueStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 32, weight: .bold))
            .foregroundColor(.primary)
    }
}

struct MetricLabelStyle: ViewModifier {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(glassColorSystem.textSecondary())
            .lineSpacing(2)
    }
}

struct DashboardSecondaryTextStyle: ViewModifier {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    func body(content: Content) -> some View {
        content
            .foregroundStyle(glassColorSystem.textSecondary())
    }
}

struct DashboardTertiaryTextStyle: ViewModifier {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    func body(content: Content) -> some View {
        content
            .foregroundStyle(glassColorSystem.textTertiary())
    }
}

extension View {
    func sectionTitleStyle() -> some View { modifier(SectionTitleStyle()) }
    func metricValueStyle() -> some View { modifier(MetricValueStyle()) }
    func metricLabelStyle() -> some View { modifier(MetricLabelStyle()) }
    func dashboardSecondaryText() -> some View { modifier(DashboardSecondaryTextStyle()) }
    func dashboardTertiaryText() -> some View { modifier(DashboardTertiaryTextStyle()) }
}

struct DashboardMetricTile: View {
    let label: String
    let value: String
    var accent: Color = .primary
    var caption: String?
    @Environment(\.colorScheme) private var colorScheme
    
    private var labelColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.7) : Color.primary.opacity(0.65)
    }
    
    private var captionColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.45) : Color.primary.opacity(0.5)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(accent)
            
            Text(label.uppercased())
                .font(.caption)
                .foregroundColor(labelColor)
                .tracking(0.6)
            
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundColor(captionColor)
            }
        }
    }
}

struct DashboardTag: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text.uppercased())
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.1), in: Capsule())
    }
}

// Card chrome - Theme-aware cards
extension View {
    func heroCard() -> some View {
        self.modifier(HeroCardModifier())
    }
    
    func supportingCard() -> some View {
        self.modifier(SupportingCardModifier())
    }
}

struct HeroCardModifier: ViewModifier {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(glassColorSystem.cardColor())
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(glassColorSystem.borderColor(), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
    }
}

struct SupportingCardModifier: ViewModifier {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(glassColorSystem.cardColor())
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(glassColorSystem.borderColor(), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}
