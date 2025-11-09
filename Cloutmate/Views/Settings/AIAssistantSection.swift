//
//  AIAssistantSection.swift
//  Cloutmate
//
//  AI Assistant settings section
//

import SwiftUI

struct AIAssistantSection: View {
    @State private var aiSettings = AISettings.shared
    @Bindable private var ollamaManager = OllamaManagementService.shared
    @State private var isTogglingOllama: Bool = false
    @State private var ollamaToggleError: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            aiFeaturesToggle
            aiFeaturesDescription
            Divider().padding(.vertical, 4)
            airplaneModeToggle
            Divider().padding(.vertical, 4)
            hybridBridgeSettings
            Divider().padding(.vertical, 4)
            modelInfoSection
            Divider().padding(.vertical, 4)
            ollamaServerControl
        }
        .onAppear {
            Task {
                await refreshOllamaStatus()
                startStatusRefreshTimer()
            }
        }
    }
    
    // MARK: - View Components
    
    private var aiFeaturesToggle: some View {
        Toggle(isOn: Binding(
            get: { aiSettings.isAIEnabled },
            set: { aiSettings.isAIEnabled = $0 }
        )) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(.kosmicBlue)
                    .frame(width: 20)
                Text("Enable AI Features")
                    .font(.body)
            }
        }
    }
    
    private var aiFeaturesDescription: some View {
        Text("When enabled, AI features include: content brainstorming, hook generation, caption writing, text improvement, hashtag suggestions, and conversational AI chat.")
            .font(.caption)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    private var airplaneModeToggle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: Binding(
                get: { aiSettings.airplaneMode },
                set: { aiSettings.airplaneMode = $0 }
            )) {
                HStack(spacing: 8) {
                    Image(systemName: "airplane")
                        .foregroundColor(.kosmicPurple)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Airplane Mode")
                            .font(.body)
                        Text("Disable all network access. Aurora runs entirely locally using Ollama.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if aiSettings.airplaneMode {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.kosmicGreen)
                        .font(.caption)
                    Text("Aurora is running in offline mode. All processing happens locally on your device.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 28)
                .padding(.top, -4)
            }
        }
    }
    
    private var hybridBridgeSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { aiSettings.useHybridBridge },
                set: { aiSettings.useHybridBridge = $0 }
            )) {
                HStack(spacing: 8) {
                    Image(systemName: "cloud.fill")
                        .foregroundColor(.kosmicBlue)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hybrid Cloud Routing")
                            .font(.body)
                        Text("Use cloud models for enhanced capabilities with automatic fallback to local Ollama")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if aiSettings.useHybridBridge {
                hybridBridgeOptions
            }
        }
    }
    
    private var hybridBridgeOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            preferredCloudModelPicker
            latencyThresholdSlider
            apiKeyInfo
        }
        .padding(.top, 4)
    }
    
    private var preferredCloudModelPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Preferred Cloud Model")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 28)
            
            Picker("", selection: Binding(
                get: { aiSettings.preferredCloudModel ?? "auto" },
                set: { aiSettings.preferredCloudModel = $0 == "auto" ? nil : $0 }
            )) {
                Text("Auto (Intent-Based)").tag("auto")
                ForEach(ModelTierMap.allLocalModelsWithDisplayNames(), id: \.name) { model in
                    Text(model.displayName).tag(model.name)
                }
            }
            .pickerStyle(.menu)
            .padding(.leading, 28)
            
            Text("Default model preference. Aurora will still route dynamically based on intent clusters, but will prefer this model when appropriate.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.leading, 28)
        }
    }
    
    private var latencyThresholdSlider: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Latency Threshold: \(Int(aiSettings.latencyThreshold))s")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 28)
            
            Slider(
                value: Binding(
                    get: { aiSettings.latencyThreshold },
                    set: { aiSettings.latencyThreshold = $0 }
                ),
                in: 2...15,
                step: 1
            )
            .padding(.leading, 28)
            
            Text("If a response takes longer than this threshold, Aurora will proactively escalate to a faster model. Keeps responses snappy.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.leading, 28)
        }
    }
    
    private var apiKeyInfo: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
                .font(.caption)
            Text("Ollama Cloud API key is configured in Info.plist (OllamaCloudAPIKey).")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.leading, 28)
    }
    
    private var modelInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "cpu")
                    .foregroundColor(.kosmicPurple)
                    .frame(width: 20)
                Text("AI Model")
                    .font(.body)
            }
            
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                Text("Aurora automatically selects the best model for each task. Vision tasks use Gemini 2.5 Flash (cloud), coding tasks use qwen2.5-coder:1.5b, regular chat uses granite3.2:2b.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 28)
        }
    }
    
    private var ollamaServerControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            ollamaServerHeader
            ollamaStatusIndicator
            ollamaErrorMessage
            ollamaStatusDescription
        }
    }
    
    private var ollamaServerHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "server.rack")
                .foregroundColor(.kosmicPurple)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text("Ollama Server")
                    .font(.body)
                Text("Control Ollama server lifecycle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            
            if isTogglingOllama {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 44)
            } else {
                Toggle("", isOn: Binding(
                    get: { ollamaManager.isOllamaRunningSync },
                    set: { newValue in
                        Task {
                            await toggleOllamaServer(to: newValue)
                        }
                    }
                ))
                .toggleStyle(.switch)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var ollamaStatusIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: ollamaManager.isOllamaRunningSync ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(ollamaManager.isOllamaRunningSync ? .kosmicGreen : .orange)
                .font(.caption)
            Text(ollamaManager.isOllamaRunningSync ? "Ollama is running and ready" : "Ollama is not running")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if !ollamaManager.isOllamaRunningSync {
                Spacer()
                Button("Refresh Status") {
                    Task {
                        await refreshOllamaStatus()
                    }
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundColor(.kosmicBlue)
            }
        }
        .padding(.leading, 28)
    }
    
    private var ollamaErrorMessage: some View {
        Group {
            if let error = ollamaToggleError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 28)
            }
        }
    }
    
    private var ollamaStatusDescription: some View {
        Text(ollamaManager.isOllamaRunningSync ? 
            "Ollama server is running. Aurora can process requests." :
            "Start Ollama server to enable AI features. Aurora requires Ollama to be running.")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.leading, 28)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    private func toggleOllamaServer(to running: Bool) async {
        isTogglingOllama = true
        ollamaToggleError = nil
        
        do {
            if running {
                try await ollamaManager.startOllama()
            } else {
                try await ollamaManager.stopOllama()
            }
            
            // Refresh status after toggle
            await refreshOllamaStatus()
        } catch {
            ollamaToggleError = error.localizedDescription
            // Refresh status to show actual state
            await refreshOllamaStatus()
        }
        
        isTogglingOllama = false
    }
    
    private func refreshOllamaStatus() async {
        await ollamaManager.refreshStatus()
        // Clear error if status shows it's resolved
        if ollamaManager.isOllamaRunningSync && ollamaToggleError != nil {
            ollamaToggleError = nil
        }
    }
    
    private func startStatusRefreshTimer() {
        // Refresh status every 5 seconds
        Task {
            while true {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                await refreshOllamaStatus()
            }
        }
    }
}

#Preview {
    AIAssistantSection()
        .padding()
        .frame(width: 600)
}

