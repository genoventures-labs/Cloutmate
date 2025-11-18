//
//  CalendarCognitionSettingsView.swift
//  FocusOS
//
//  Aurora Calendar Cognition Layer - Settings panel
//

import SwiftUI

struct CalendarCognitionSettingsView: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @AppStorage("calendarCognitionEnabled") private var enabled = true
    @AppStorage("calendarColorUpdateInterval") private var updateInterval: Double = 900 // 15 minutes
    @AppStorage("triageThreshold") private var triageThreshold = 3
    @AppStorage("colorSensitivity") private var colorSensitivity: Double = 0.5
    @AppStorage("overrideLearningEnabled") private var overrideLearningEnabled = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Calendar Cognition")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                Text("Aurora automatically colorizes your calendar based on urgency, deadlines, and energy patterns")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
            }
            
            Divider()
            
            // Enable/Disable
            Toggle(isOn: $enabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable Auto-Colorization")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                    
                    Text("Aurora will automatically assign colors to calendar events")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                }
            }
            .toggleStyle(.switch)
            .tint(.kosmicBlue)
            
            if enabled {
                // Update Frequency
                VStack(alignment: .leading, spacing: 12) {
                    Text("Update Frequency")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                    
                    Picker("", selection: $updateInterval) {
                        Text("15 minutes").tag(900.0)
                        Text("30 minutes").tag(1800.0)
                        Text("1 hour").tag(3600.0)
                    }
                    .pickerStyle(.segmented)
                    
                    Text("How often Aurora re-analyzes and updates event colors")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                }
                
                // Color Sensitivity
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Color Sensitivity")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(glassColorSystem.textPrimary())
                        
                        Spacer()
                        
                        Text(String(format: "%.0f%%", colorSensitivity * 100))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(glassColorSystem.textSecondary())
                    }
                    
                    Slider(value: $colorSensitivity, in: 0.0...1.0)
                        .tint(.kosmicBlue)
                    
                    Text("How aggressively Aurora detects urgency (higher = more red/orange events)")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                }
                
                // Triage Threshold
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Triage Threshold")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(glassColorSystem.textPrimary())
                        
                        Spacer()
                        
                        Stepper("", value: $triageThreshold, in: 1...10)
                            .labelsHidden()
                    }
                    
                    Text("Number of high-urgency events per day that trigger triage recommendations")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                }
                
                // Override Learning
                Toggle(isOn: $overrideLearningEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Learn from Overrides")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(glassColorSystem.textPrimary())
                        
                        Text("Aurora adapts color weights based on your manual color overrides")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(glassColorSystem.textSecondary())
                    }
                }
                .toggleStyle(.switch)
                .tint(.kosmicBlue)
                
                // Reset
                Button {
                    resetColorHistory()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset Color History")
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
    }
    
    private func resetColorHistory() {
        // This would clear all EventColorReason records
        // Implementation would require ModelContext access
    }
}

