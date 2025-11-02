//
//  GlassEffectsSection.swift
//  Cloutmate
//
//  Glass Effects settings section
//

import SwiftUI

struct GlassEffectsSection: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @EnvironmentObject private var accessibilityGlassManager: AccessibilityGlassManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: Binding(
                get: { glassColorSystem.isTimeBasedShiftingEnabled },
                set: { glassColorSystem.isTimeBasedShiftingEnabled = $0 }
            )) {
                HStack(spacing: 8) {
                    Image(systemName: "sunrise")
                        .foregroundColor(.orange)
                        .frame(width: 20)
                    Text("Time-based color shifting")
                        .font(.body)
                }
            }
            
            HStack {
                Text("Performance Mode")
                    .font(.body)
                Spacer()
                Picker("", selection: Binding(
                    get: { accessibilityGlassManager.performanceMode },
                    set: { accessibilityGlassManager.performanceMode = $0 }
                )) {
                    ForEach(PerformanceMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
            }
            
            Toggle(isOn: Binding(
                get: { accessibilityGlassManager.reduceTransparency },
                set: { accessibilityGlassManager.reduceTransparency = $0 }
            )) {
                HStack(spacing: 8) {
                    Image(systemName: "eye")
                        .foregroundColor(.kosmicBlue)
                        .frame(width: 20)
                    Text("Reduce Transparency")
                        .font(.body)
                }
            }
            
            Toggle(isOn: Binding(
                get: { accessibilityGlassManager.isAnimationsEnabled },
                set: { accessibilityGlassManager.isAnimationsEnabled = $0 }
            )) {
                HStack(spacing: 8) {
                    Image(systemName: "play.circle")
                        .foregroundColor(.kosmicGreen)
                        .frame(width: 20)
                    Text("Enable Animations")
                        .font(.body)
                }
            }
        }
    }
}

#Preview {
    GlassEffectsSection()
        .padding()
        .frame(width: 600)
}

