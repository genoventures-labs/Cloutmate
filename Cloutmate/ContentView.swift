//
//  ContentView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @State private var backgroundOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Tier 0 - Ambient depth background with animated parallax drift
            glassColorSystem.backgroundGradient()
                .offset(x: cos(backgroundOffset) * 10, y: sin(backgroundOffset) * 10)
                .animation(
                    Animation.linear(duration: 20)
                        .repeatForever(autoreverses: false),
                    value: backgroundOffset
                )
                .ignoresSafeArea()
            
            // Main window on top
            MainWindowView()
        }
        .onAppear {
            // Start subtle parallax drift animation
            backgroundOffset = .pi * 2
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(GlassColorSystem())
        .environmentObject(AccessibilityGlassManager())
        .modelContainer(for: [Post.self, Draft.self, Template.self, AIMessage.self, AIConversation.self])
}
