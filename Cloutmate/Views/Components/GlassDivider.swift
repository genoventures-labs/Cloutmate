//
//  GlassDivider.swift
//  Cloutmate
//
//  Minimal Divider Component
//

import SwiftUI

struct GlassDivider: View {
    var thickness: CGFloat = 1
    var opacity: Double = 1.0 // Legacy parameter, no longer used
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        Rectangle()
            .fill(glassColorSystem.dividerColor())
        .frame(height: thickness)
    }
}

extension Divider {
    static func glass(opacity: Double = 1.0) -> some View {
        GlassDivider()
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Above")
        GlassDivider()
        Text("Below")
        GlassDivider(thickness: 1)
        Text("Thicker")
    }
    .padding()
    .environmentObject(GlassColorSystem())
}
