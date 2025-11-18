//
//  FlowCompanionSettingsSection.swift
//  FocusOS
//
//  Phase 10: Flow Companion settings section
//

import SwiftUI

struct FlowCompanionSettingsSection: View {
    @StateObject private var settings = FlowCompanionSettings.shared
    @State private var showingResetAlert = false
    
    var body: some View {
        GlassCard(showHeader: true, headerContent: {
            AnyView(
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                    Text("Flow Companion")
                        .font(.headline)
                }
            )
        }) {
            VStack(alignment: .leading, spacing: 16) {
                // Enable/Disable
                Toggle("Enable Flow Companion", isOn: $settings.isEnabled)
                    .font(.system(size: 14))
                
                if settings.isEnabled {
                    Divider()
                    
                    // Trigger toggles
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Reflection Triggers")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Toggle("Drift Events", isOn: $settings.isDriftTriggerEnabled)
                            .font(.system(size: 13))
                        
                        Toggle("Evening Ritual", isOn: $settings.isEveningTriggerEnabled)
                            .font(.system(size: 13))
                        
                        Toggle("Idle Detection", isOn: $settings.isIdleTriggerEnabled)
                            .font(.system(size: 13))
                        
                        if settings.isIdleTriggerEnabled {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Idle Timeout")
                                        .font(.system(size: 12))
                                    Spacer()
                                    Text("\(settings.idleTimeoutMinutes) min")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                Slider(value: Binding(
                                    get: { Double(settings.idleTimeoutMinutes) },
                                    set: { settings.idleTimeoutMinutes = Int($0) }
                                ), in: 1...30, step: 1)
                                .tint(.purple)
                            }
                            .padding(.leading, 20)
                            .padding(.top, 4)
                        }
                    }
                    
                    Divider()
                    
                    // Reflection tone
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reflection Tone")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Picker("Tone", selection: $settings.reflectionTone) {
                            Text("Gentle").tag("gentle")
                            Text("Direct").tag("direct")
                            Text("Curious").tag("curious")
                            Text("Supportive").tag("supportive")
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Divider()
                    
                    // Reset prompts button
                    Button(action: {
                        showingResetAlert = true
                    }) {
                        Label("Reset Reflection Prompts", systemImage: "arrow.clockwise")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                    .alert("Reset Prompts", isPresented: $showingResetAlert) {
                        Button("Cancel", role: .cancel) {}
                        Button("Reset", role: .destructive) {
                            resetPrompts()
                        }
                    } message: {
                        Text("This will reload default reflection prompts from the library.")
                    }
                }
            }
            .padding(20)
        }
    }
    
    private func resetPrompts() {
        // Reload prompts from plist
        FlowCompanionEngine.shared.loadPrompts()
    }
}

