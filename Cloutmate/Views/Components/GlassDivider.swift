//
//  GlassDivider.swift
//  Cloutmate
//
//  Glassmorphic Harmony UI - Glass Divider Component
//

import SwiftUI

struct GlassDivider: View {
    var thickness: CGFloat = 0.5
    var opacity: Double = 0.2
    
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(opacity))
            .frame(height: thickness)
            .blur(radius: 0.5)
    }
}

extension Divider {
    static func glass(opacity: Double = 0.2) -> some View {
        GlassDivider(opacity: opacity)
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Above")
        
        GlassDivider()
        
        Text("Below")
        
        GlassDivider(thickness: 1, opacity: 0.3)
        
        Text("Thicker")
    }
    .padding()
}
