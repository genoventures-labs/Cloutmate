//
//  AIAssistantToolbar.swift
//  Cloutmate
//
//  AI Assistant V2 - Toolbar Component (Overlay Tier)
//  GlassPanel-based toolbar with core capabilities and actions
//

import SwiftUI
import CloutmateShared

struct AIAssistantToolbar: View {
    let viewModel: AIAssistantViewModel
    @Binding var isRecording: Bool
    let onSmartRecap: () -> Void
    let onExportToDraft: () -> Void
    let onVoiceInput: () -> Void
    let onToolbarAction: (ToolbarAction) -> Void
    let onWebSearch: () -> Void
    
    @Environment(\.glassTier) private var glassTier
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    private let aiSettings = AISettings.shared
    private let tintManager = ArteTintManager.shared
    private let usageTracker = ToolbarUsageTracker.shared
    
    var body: some View {
        GlassPanel(tier: .overlay) {
        HStack(spacing: 12) {
                // Core Capabilities Toolbar
                let orderedActions = usageTracker.orderedActions()
                let tintColor = tintManager.combinedTintColor(activity: viewModel.currentActivity)
                
                ForEach(orderedActions, id: \.self) { action in
                    toolbarButton(for: action, tintColor: tintColor)
                }
                
                Spacer()
                
                // Smart Recap
                GlassButton(
                    icon: "doc.text.fill",
                    style: .iconOnly,
                    action: onSmartRecap
                )
                .frame(width: 32, height: 32)
            .disabled(viewModel.messages.isEmpty)
            .help("Generate session summary")
            
            // Export to Drafts
                GlassButton(
                    icon: "square.and.arrow.down",
                    style: .iconOnly,
                    action: onExportToDraft
                )
                .frame(width: 32, height: 32)
            .disabled(viewModel.messages.isEmpty)
            .help("Export to Drafts")
            
            // Airplane Mode Toggle
                GlassButton(
                    icon: aiSettings.airplaneMode ? "airplane" : "airplane.departure",
                    style: .iconOnly,
                    tintColor: aiSettings.airplaneMode ? .orange : nil,
                    action: {
                aiSettings.airplaneMode.toggle()
                    }
                )
                .frame(width: 32, height: 32)
            .help(aiSettings.airplaneMode ? "Offline cognition active" : "Enable offline mode")
            
            // Voice Input
                GlassButton(
                    icon: isRecording ? "mic.fill" : "mic.circle",
                    style: .iconOnly,
                    tintColor: isRecording ? .red : nil,
                    action: onVoiceInput
                )
                .frame(width: 32, height: 32)
            .disabled(viewModel.isLoading)
            .help(isRecording ? "Stop recording" : "Voice input")
                .keyboardShortcut("r", modifiers: .command)
                
                // Web Search
                GlassButton(
                    icon: "globe",
                    style: .iconOnly,
                    action: {
                        onWebSearch()
                    }
                )
                .frame(width: 32, height: 32)
                .disabled(viewModel.isLoading)
                .help("Search the web")
                .keyboardShortcut("w", modifiers: [.command, .shift])
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        }
    }
    
    private func toolbarButton(for action: ToolbarAction, tintColor: Color) -> some View {
        GlassButton(
            icon: action.icon,
            style: .iconOnly,
            tintColor: tintColor,
            action: {
                handleToolbarAction(action)
            }
        )
        .frame(width: 32, height: 32)
        .disabled(viewModel.isLoading)
        .help(action.rawValue)
        .keyboardShortcut(keyboardShortcut(for: action), modifiers: [.command, .shift])
    }
    
    private func keyboardShortcut(for action: ToolbarAction) -> KeyEquivalent {
        switch action {
        case .createTask: return "1"
        case .createProject: return "2"
        case .createNote: return "3"
        case .createReminder: return "4"
        case .analyzeDocument: return "5"
        case .analyzeImage: return "6"
        }
    }
    
    private func handleToolbarAction(_ action: ToolbarAction) {
        onToolbarAction(action)
    }
}

#Preview {
    @Previewable @State var viewModel = AIAssistantViewModel()
    @Previewable @State var isRecording = false
    
    AIAssistantToolbar(
        viewModel: viewModel,
        isRecording: $isRecording,
        onSmartRecap: {},
        onExportToDraft: {},
        onVoiceInput: {},
        onToolbarAction: { _ in },
        onWebSearch: {}
    )
    .environment(\.glassTier, GlassTier.overlay)
    .environmentObject(GlassColorSystem())
}

