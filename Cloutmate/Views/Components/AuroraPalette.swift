//
//  AuroraPalette.swift
//  Cloutmate
//
//  Shared Aurora gradient utilities for shimmering headers & button glows.
//

import SwiftUI

enum AuroraPalette {
    private static func isNight(for date: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        return hour >= 18 || hour < 6
    }
    
    static func gradientColors(for colorScheme: ColorScheme, date: Date = Date()) -> [Color] {
        let night = isNight(for: date) || colorScheme == .dark
        let nightColors = [
            Color.cyan,
            Color(hue: 0.62, saturation: 0.52, brightness: 0.82),
            Color.purple
        ]
        
        let dayColors = [
            Color(hue: 0.08, saturation: 0.42, brightness: 0.98),
            Color.cyan,
            Color(hue: 0.76, saturation: 0.55, brightness: 0.92)
        ]
        
        return night ? nightColors : dayColors
    }
    
    static func linearGradient(for colorScheme: ColorScheme, date: Date = Date(), start: UnitPoint = .topLeading, end: UnitPoint = .bottomTrailing) -> LinearGradient {
        LinearGradient(
            colors: gradientColors(for: colorScheme, date: date),
            startPoint: start,
            endPoint: end
        )
    }
    
    static func radialGradient(for colorScheme: ColorScheme, date: Date = Date(), center: UnitPoint = .center, startRadius: CGFloat = 12, endRadius: CGFloat = 140) -> RadialGradient {
        RadialGradient(
            gradient: Gradient(colors: gradientColors(for: colorScheme, date: date)),
            center: center,
            startRadius: startRadius,
            endRadius: endRadius
        )
    }
}

struct AuroraShimmerModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @State private var animate = false
    
    private var shimmerGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: AuroraPalette.gradientColors(for: colorScheme)),
            center: .center,
            angle: .degrees(animate ? 360 : 0)
        )
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                shimmerGradient
                    .opacity(0.12)
                    .blendMode(.softLight)
                    .mask(content)
                    .animation(.easeInOut(duration: 20).repeatForever(autoreverses: false), value: animate)
            )
            .onAppear { animate = true }
    }
}

extension View {
    func auroraShimmer() -> some View {
        modifier(AuroraShimmerModifier())
    }
}


