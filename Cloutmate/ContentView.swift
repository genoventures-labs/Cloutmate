//
//  ContentView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import CloutmateShared

struct ContentView: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appearanceMode") private var appearanceModeRawValue = "system"
    
    private var effectiveColorScheme: ColorScheme {
        let mode = AppearanceMode(rawValue: appearanceModeRawValue) ?? .system
        switch mode {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return colorScheme
        }
    }
    
    var body: some View {
        ZStack {
            // Clean flat background with ARTE emotional overlay
            ZStack {
                glassColorSystem.backgroundColor()
                glassColorSystem.emotionalBackgroundShift()
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 2.0), value: glassColorSystem.emotionalState)
            
            // Main window content
            MainWindowView()
        }
        .onAppear {
            updateColorScheme()
        }
        .onChange(of: colorScheme) { _, _ in
            updateColorScheme()
        }
        .onChange(of: appearanceModeRawValue) { _, _ in
            updateColorScheme()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AppearanceModeChanged"))) { _ in
            updateColorScheme()
        }
    }
    
    private func updateColorScheme() {
        glassColorSystem.currentColorScheme = effectiveColorScheme
    }
}

#Preview {
    ContentView()
        .environmentObject(GlassColorSystem())
        .environmentObject(AccessibilityGlassManager())
        .modelContainer(for: [CloutmateShared.Post.self, Draft.self, CloutmateShared.Template.self, AIMessage.self, AIConversation.self])
}
