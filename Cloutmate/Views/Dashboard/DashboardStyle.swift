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
    static let neutral900 = Color(red: 0.10, green: 0.10, blue: 0.12)
    static let neutral600 = Color(red: 0.36, green: 0.38, blue: 0.42)
    static let neutral300 = Color(red: 0.78, green: 0.80, blue: 0.84)
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
    func body(content: Content) -> some View {
        content
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.secondary)
            .lineSpacing(2)
    }
}

extension View {
    func sectionTitleStyle() -> some View { modifier(SectionTitleStyle()) }
    func metricValueStyle() -> some View { modifier(MetricValueStyle()) }
    func metricLabelStyle() -> some View { modifier(MetricLabelStyle()) }
}

// Card chrome
extension View {
    func heroCard() -> some View {
        self
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.10), radius: 24, x: 0, y: 10)
    }
    
    func supportingCard() -> some View {
        self
            .padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}


