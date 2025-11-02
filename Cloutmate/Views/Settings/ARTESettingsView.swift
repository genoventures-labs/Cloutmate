//
//  ARTESettingsView.swift
//  Cloutmate
//
//  Phase 7: ARTE - Aurora Reactive Theme Engine
//  Control panel for ARTE configuration and state management
//

import SwiftUI
import SwiftData

struct ARTESettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @StateObject private var themeManager = ReactiveThemeManager.shared
    
    @Query private var configurations: [ARTEConfiguration]
    @State private var showResetConfirmation = false
    @State private var performanceMetrics: ARTEPerformanceMetrics?
    
    private var config: ARTEConfiguration? {
        configurations.first
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection
                
                // Master Toggle
                masterToggleSection
                
                if themeManager.isEnabled {
                    // Mode Selection
                    modeSelectionSection
                    
                    // Intensity Control
                    intensitySection
                    
                    // Current State Display
                    currentStateSection
                    
                    // Manual State Picker (if in manual mode)
                    if themeManager.mode == .manual {
                        manualStateSection
                    }
                    
                    // Advanced Settings
                    advancedSection
                    
                    // Performance Stats
                    performanceSection
                }
            }
            .padding(24)
        }
        .frame(maxWidth: 600)
        .onAppear {
            loadConfiguration()
            updatePerformanceMetrics()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 28))
                    .foregroundColor(glassColorSystem.emotionalAccent())
                Text("ARTE")
                    .font(.system(size: 32, weight: .bold))
            }
            
            Text("Aurora Reactive Theme Engine")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Text("ARTE dynamically adapts your interface to match your cognitive-emotional rhythm, creating a living workspace that responds to how you think and feel.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
    }
    
    // MARK: - Master Toggle
    
    private var masterToggleSection: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable ARTE")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Activate emotional theme adaptation")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $themeManager.isEnabled)
                    .toggleStyle(.switch)
                    .onChange(of: themeManager.isEnabled) { _, newValue in
                        glassColorSystem.isARTEEnabled = newValue
                        themeManager.saveConfiguration(modelContext: modelContext)
                        if newValue {
                            themeManager.restart(modelContext: modelContext)
                        } else {
                            themeManager.stop()
                        }
                    }
            }
            .padding(16)
        }
    }
    
    // MARK: - Mode Selection
    
    private var modeSelectionSection: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Operation Mode")
                    .font(.system(size: 16, weight: .semibold))
                
                ForEach(ARTEMode.allCases, id: \.self) { mode in
                    modeOptionButton(mode)
                }
            }
            .padding(16)
        }
    }
    
    private func modeOptionButton(_ mode: ARTEMode) -> some View {
        Button(action: {
            themeManager.mode = mode
            themeManager.saveConfiguration(modelContext: modelContext)
        }) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: themeManager.mode == mode ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(themeManager.mode == mode ? glassColorSystem.emotionalAccent() : .secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(glassColorSystem.textPrimary())
                    Text(mode.description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeManager.mode == mode ? glassColorSystem.emotionalAccent().opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Intensity
    
    private var intensitySection: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Intensity")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Text("\(Int(themeManager.intensity * 100))%")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(glassColorSystem.emotionalAccent())
                }
                
                Slider(value: $themeManager.intensity, in: 0...1, step: 0.1)
                    .accentColor(glassColorSystem.emotionalAccent())
                    .onChange(of: themeManager.intensity) { _, newValue in
                        glassColorSystem.emotionalIntensity = newValue
                        themeManager.saveConfiguration(modelContext: modelContext)
                    }
                
                Text("Controls how strongly emotional states affect the interface. Lower values are more subtle.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(16)
        }
    }
    
    // MARK: - Current State
    
    private var currentStateSection: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Current State")
                    .font(.system(size: 16, weight: .semibold))
                
                HStack(spacing: 16) {
                    // State Icon
                    Image(systemName: themeManager.currentState.iconName)
                        .font(.system(size: 32))
                        .foregroundColor(glassColorSystem.emotionalAccent())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(themeManager.currentState.displayName)
                            .font(.system(size: 18, weight: .bold))
                        Text(themeManager.currentState.description)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Confidence Badge
                    VStack(spacing: 2) {
                        Text("Confidence")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("\(Int(themeManager.confidence * 100))%")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(glassColorSystem.emotionalAccent())
                    }
                }
                
                // Color Preview
                HStack(spacing: 8) {
                    ForEach(EmotionalState.allCases, id: \.self) { state in
                        colorPreviewDot(for: state)
                    }
                }
                .padding(.top, 8)
                
                // Transition Progress
                if themeManager.isTransitioning {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Transitioning...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        ProgressView(value: themeManager.transitionProgress)
                            .progressViewStyle(.linear)
                            .tint(glassColorSystem.emotionalAccent())
                    }
                    .padding(.top, 8)
                }
            }
            .padding(16)
        }
    }
    
    private func colorPreviewDot(for state: EmotionalState) -> some View {
        let palette = EmotionalPalette.palette(for: state)
        let isActive = themeManager.currentState == state
        
        return Circle()
            .fill(palette.backgroundTint)
            .frame(width: isActive ? 24 : 16, height: isActive ? 24 : 16)
            .overlay(
                Circle()
                    .strokeBorder(isActive ? glassColorSystem.emotionalAccent() : Color.clear, lineWidth: 2)
            )
            .animation(.spring(response: 0.3), value: isActive)
    }
    
    // MARK: - Manual State Selection
    
    private var manualStateSection: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Select State")
                    .font(.system(size: 16, weight: .semibold))
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(EmotionalState.allCases, id: \.self) { state in
                        stateButton(state)
                    }
                }
            }
            .padding(16)
        }
    }
    
    private func stateButton(_ state: EmotionalState) -> some View {
        Button(action: {
            themeManager.setManualState(state, modelContext: modelContext)
        }) {
            VStack(spacing: 8) {
                Image(systemName: state.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(themeManager.currentState == state ? glassColorSystem.emotionalAccent() : glassColorSystem.textSecondary())
                Text(state.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(glassColorSystem.textPrimary())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeManager.currentState == state ? glassColorSystem.emotionalAccent().opacity(0.15) : glassColorSystem.backgroundSecondary())
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Advanced Settings
    
    private var advancedSection: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Advanced")
                    .font(.system(size: 16, weight: .semibold))
                
                Toggle("Adaptive Timing", isOn: Binding(
                    get: { config?.adaptiveTiming ?? true },
                    set: { newValue in
                        config?.adaptiveTiming = newValue
                        try? modelContext.save()
                    }
                ))
                .font(.system(size: 14))
                
                Text("Adjusts detection frequency based on your activity level")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Divider()
                
                Toggle("Learning Enabled", isOn: Binding(
                    get: { config?.learningEnabled ?? true },
                    set: { newValue in
                        config?.learningEnabled = newValue
                        try? modelContext.save()
                    }
                ))
                .font(.system(size: 14))
                
                Text("ARTE learns from your manual overrides to improve detection accuracy")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Divider()
                
                Button(action: { showResetConfirmation = true }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Reset Learning Data")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .alert("Reset Learning Data?", isPresented: $showResetConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Reset", role: .destructive) {
                        resetLearningData()
                    }
                } message: {
                    Text("This will clear all calibration data and ARTE will start learning from scratch.")
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - Performance
    
    private var performanceSection: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Performance")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Button(action: updatePerformanceMetrics) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
                
                if let metrics = performanceMetrics {
                    VStack(spacing: 8) {
                        metricRow(label: "Avg Update Latency", value: metrics.formattedAverageLatency)
                        metricRow(label: "Max Update Latency", value: metrics.formattedMaxLatency)
                        metricRow(label: "Total Transitions", value: "\(metrics.totalTransitions)")
                        metricRow(label: "Est. CPU Usage", value: String(format: "%.1f%%", metrics.estimatedCPUPercent))
                        metricRow(
                            label: "Status",
                            value: metrics.isWithinTargets ? "✅ Optimal" : "⚠️ Needs Optimization",
                            valueColor: metrics.isWithinTargets ? .green : .orange
                        )
                    }
                } else {
                    Text("Loading metrics...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
        }
    }
    
    private func metricRow(label: String, value: String, valueColor: Color? = nil) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(valueColor ?? glassColorSystem.textPrimary())
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadConfiguration() {
        if let config = config {
            themeManager.isEnabled = config.isEnabled
            themeManager.mode = config.mode
            themeManager.intensity = config.intensity
        }
    }
    
    private func updatePerformanceMetrics() {
        let telemetry = ThemeTelemetryService()
        performanceMetrics = telemetry.getCurrentMetrics()
    }
    
    private func resetLearningData() {
        config?.calibrationData = nil
        config?.manualOverrideCount = 0
        config?.lastManualOverride = nil
        try? modelContext.save()
    }
}

#Preview {
    ARTESettingsView()
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [ARTEConfiguration.self])
}

