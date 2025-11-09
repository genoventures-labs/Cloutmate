//
//  AIAssistantPreferencesSheet.swift
//  Cloutmate
//
//  AI Assistant V2 - Aurora Preferences Sheet
//

import SwiftUI
import CloutmateShared

struct AIAssistantPreferencesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var aiSettings = AISettings.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 32))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.kosmicBlue, .kosmicPurple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Aurora Preferences")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Configure your AI assistant")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                    
                    Divider()
                    
                    // AI Features Toggle
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: Binding(
                            get: { aiSettings.isAIEnabled },
                            set: { aiSettings.isAIEnabled = $0 }
                        )) {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.kosmicBlue)
                                Text("Enable AI Features")
                                    .font(.body)
                            }
                        }
                        
                        Text("When enabled, Aurora can help you create tasks, projects, notes, analyze documents, and have conversations.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Airplane Mode
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: Binding(
                            get: { aiSettings.airplaneMode },
                            set: { aiSettings.airplaneMode = $0 }
                        )) {
                            HStack(spacing: 8) {
                                Image(systemName: "airplane")
                                    .foregroundColor(.kosmicPurple)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Airplane Mode")
                                        .font(.body)
                                    Text("Disable network access. Aurora runs entirely locally.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        if aiSettings.airplaneMode {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("Aurora is running in offline mode.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Model Info (Read-only)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.kosmicPurple)
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
                    }
                }
                .padding(24)
            }
            .frame(width: 500, height: 600)
            .navigationTitle("Aurora Preferences")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AIAssistantPreferencesSheet()
}
