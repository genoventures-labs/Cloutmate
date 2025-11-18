//
//  DashboardTile.swift
//  FocusOS
//
//  Shared glassmorphic tile styling for Dashboard surfaces.
//

import SwiftUI

struct DashboardTile<Content: View>: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private let accent: Color?
    private let padding: CGFloat
    private let minHeight: CGFloat?
    private let content: Content
    
    init(
        accent: Color? = nil,
        padding: CGFloat = 22,
        minHeight: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.accent = accent
        self.padding = padding
        self.minHeight = minHeight
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background(tileBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(glassColorSystem.borderColor().opacity(0.32), lineWidth: 0.9)
            )
            .shadow(
                color: glassColorSystem.backgroundSecondary().opacity(0.18),
                radius: 18,
                x: 0,
                y: 12
            )
    }
    
    private var tileBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(glassColorSystem.cardColor().opacity(0.86))
            
            if let accent {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.22),
                                accent.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(reduceMotion ? 0.9 : 1.0)
            }
        }
    }
}


