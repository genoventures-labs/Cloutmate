//
//  AIAssistantSection.swift
//  Cloutmate
//
//  AI Assistant settings section
//

import SwiftUI

struct AIAssistantSection: View {
    @State private var aiSettings = AISettings.shared
    @State private var availableModels: [String] = []
    @State private var isLoadingModels = false
    @State private var modelError: String?
    @Bindable private var ollamaManager = OllamaManagementService.shared
    @State private var isTogglingOllama: Bool = false
    @State private var ollamaToggleError: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
            
            Text("When enabled, AI features include: content brainstorming, hook generation, caption writing, text improvement, hashtag suggestions, and conversational AI chat.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Divider()
                .padding(.vertical, 4)
            
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
            
            Divider()
                .padding(.vertical, 4)
            
            // Hybrid Bridge Settings
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
                    VStack(alignment: .leading, spacing: 8) {
                        // API Key
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ollama Cloud API Key")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 28)
                            
                            SecureField("Enter your API key", text: Binding(
                                get: { aiSettings.ollamaCloudAPIKey ?? "" },
                                set: { aiSettings.ollamaCloudAPIKey = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .padding(.leading, 28)
                            
                            Text("Get your API key from https://ollama.com. Aurora will use cloud models when available, with automatic fallback to local Ollama.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.leading, 28)
                        }
                        
                        // Preferred Cloud Model
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
                                ForEach(ModelTierMap.allCloudModelsWithDisplayNames(), id: \.name) { model in
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
                        
                        // Latency Threshold
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
                    .padding(.top, 4)
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Model Selection
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "cpu")
                        .foregroundColor(.kosmicPurple)
                        .frame(width: 20)
                    Text("Ollama Model")
                        .font(.body)
                }
                
                if isLoadingModels {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading available models...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 28)
                } else if let error = modelError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 28)
                } else if !availableModels.isEmpty {
                    Picker("", selection: Binding(
                        get: { aiSettings.selectedOllamaModel },
                        set: { aiSettings.selectedOllamaModel = $0 }
                    )) {
                        ForEach(availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.leading, 28)
                } else {
                    // Fallback: manual text field if models couldn't be loaded
                    TextField("Model name (e.g., llama3.1)", text: Binding(
                        get: { aiSettings.selectedOllamaModel },
                        set: { aiSettings.selectedOllamaModel = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .padding(.leading, 28)
                }
                
                Text("Select the Ollama model to use for Aurora. Make sure the model is installed: `ollama pull <model-name>`")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 28)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Ollama Server Control
            VStack(alignment: .leading, spacing: 8) {
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
                
                // Status indicator
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
                
                // Error message
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
                
                Text(ollamaManager.isOllamaRunningSync ? 
                    "Ollama server is running. Aurora can process requests." :
                    "Start Ollama server to enable AI features. Aurora requires Ollama to be running.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 28)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            loadAvailableModels()
            Task {
                await refreshOllamaStatus()
                // Set up periodic status refresh
                startStatusRefreshTimer()
            }
        }
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
            
            // Also refresh models list if starting
            if running {
                loadAvailableModels()
            }
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
    
    private func loadAvailableModels() {
        guard !isLoadingModels else { return }
        isLoadingModels = true
        modelError = nil
        
        Task {
            do {
                let models = try await OllamaBridgeService.shared.fetchAvailableModels()
                await MainActor.run {
                    availableModels = models.sorted()
                    isLoadingModels = false
                    
                    // If current model isn't in the list, add it
                    if !availableModels.contains(aiSettings.selectedOllamaModel) {
                        availableModels.insert(aiSettings.selectedOllamaModel, at: 0)
                    }
                }
            } catch {
                await MainActor.run {
                    isLoadingModels = false
                    modelError = "Could not load models. Make sure Ollama is running."
                    // Fallback: add default model
                    if availableModels.isEmpty {
                        availableModels = [aiSettings.selectedOllamaModel]
                    }
                }
            }
        }
    }
}

#Preview {
    AIAssistantSection()
        .padding()
        .frame(width: 600)
}

