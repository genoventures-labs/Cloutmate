//
//  AIAssistantPreferencesSheet.swift
//  FocusOS
//
//  AI Assistant V2 - Aurora Preferences Sheet
//

import SwiftUI
import FocusOSShared

struct AIAssistantPreferencesSheet: View {
    @Binding var isPresented: Bool
    @Bindable private var aiSettings = AISettings.shared
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    private var accentGradient: LinearGradient {
        AuroraPalette.linearGradient(for: colorScheme)
    }
    
    var body: some View {
        Group {
            if isPresented {
                GeometryReader { geometry in
                    ZStack(alignment: .bottom) {
                        // Backdrop
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                closeDrawer()
                            }
                            .transition(.opacity)
                        
                        // Drawer slides up from bottom
                        VStack(spacing: 0) {
                            V2DrawerScaffold(
                                accentGradient: accentGradient,
                                showsSidebar: false,
                                header: { headerContent },
                                content: { drawerContent },
                                sidebar: { EmptyView() }
                            )
                        }
                        .frame(maxHeight: geometry.size.height * 0.75)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
                }
            }
        }
    }
    
    private func closeDrawer() {
        withAnimation(GlassMotion.Easing.modalOpen) {
            isPresented = false
        }
    }
    
    private var headerContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Aurora Preferences")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                Text("Configure your AI assistant")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
            }
            
            Spacer()
            
            GlassButton(
                nil,
                icon: "xmark",
                style: .iconOnly,
                role: .surface
            ) {
                closeDrawer()
            }
            .accessibilityLabel("Close")
        }
    }
    
    @ViewBuilder
    private var drawerContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // AI Features Toggle
            DrawerSection(title: "AI Features", icon: "sparkles") {
                Toggle(isOn: Binding(
                    get: { aiSettings.isAIEnabled },
                    set: { aiSettings.isAIEnabled = $0 }
                )) {
                    Text("Enable AI Features")
                        .font(.body)
                        .foregroundStyle(glassColorSystem.textPrimary())
                }
                
                Text("When enabled, Aurora can help you create tasks, projects, notes, analyze documents, and have conversations.")
                    .font(.caption)
                    .foregroundStyle(glassColorSystem.textSecondary())
                    .padding(.top, 4)
            }
            
            // Airplane Mode
            DrawerSection(title: "Airplane Mode", icon: "airplane") {
                Toggle(isOn: Binding(
                    get: { aiSettings.airplaneMode },
                    set: { aiSettings.airplaneMode = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Airplane Mode")
                            .font(.body)
                            .foregroundStyle(glassColorSystem.textPrimary())
                        Text("Disable network access. Aurora runs entirely locally.")
                            .font(.caption)
                            .foregroundStyle(glassColorSystem.textSecondary())
                    }
                }
                
                if aiSettings.airplaneMode {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text("Aurora is running in offline mode.")
                            .font(.caption)
                            .foregroundStyle(glassColorSystem.textSecondary())
                    }
                    .padding(.top, 4)
                }
            }
            
            // Model Info (Read-only)
            DrawerSection(title: "AI Model", icon: "brain.head.profile") {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text("Aurora automatically selects the best model for each task. Gemma3 covers conversations and images, Gwen3 handles deep reasoning, and Granite keeps memories tidy in the background.")
                        .font(.caption)
                        .foregroundStyle(glassColorSystem.textSecondary())
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    @Previewable @State var isPresented = true
    AIAssistantPreferencesSheet(isPresented: $isPresented)
        .environmentObject(GlassColorSystem())
}
