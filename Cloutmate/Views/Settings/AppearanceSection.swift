//
//  AppearanceSection.swift
//  Cloutmate
//
//  Appearance settings section
//

import SwiftUI
import AppKit

struct AppearanceSection: View {
    @AppStorage("appearanceMode") private var appearanceModeRawValue = "system"
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }
    
    private func updateAppearance(_ mode: AppearanceMode) {
        appearanceModeRawValue = mode.rawValue
        applyAppearance(mode)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Theme")
                Spacer()
                Picker("", selection: Binding(
                    get: { appearanceMode },
                    set: { updateAppearance($0) }
                )) {
                    Text("Light").tag(AppearanceMode.light)
                    Text("Dark").tag(AppearanceMode.dark)
                    Text("System").tag(AppearanceMode.system)
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }
        }
        .onAppear {
            applyAppearance(appearanceMode)
        }
    }
    
    private func applyAppearance(_ mode: AppearanceMode) {
        switch mode {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
            glassColorSystem.currentColorScheme = .light
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
            glassColorSystem.currentColorScheme = .dark
        case .system:
            NSApp.appearance = nil
            glassColorSystem.currentColorScheme = NSApp.effectiveAppearance.name == .darkAqua ? .dark : .light
        }
        // Notify ContentView to update
        NotificationCenter.default.post(name: NSNotification.Name("AppearanceModeChanged"), object: nil)
    }
}

enum AppearanceMode: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
}

#Preview {
    AppearanceSection()
        .padding()
        .frame(width: 600)
}

