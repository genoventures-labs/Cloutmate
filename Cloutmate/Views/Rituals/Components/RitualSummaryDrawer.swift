//
//  RitualSummaryDrawer.swift
//  Cloutmate
//
//  Aurora-generated ritual summary drawer with tone-matched messaging
//

import SwiftUI

struct RitualSummaryDrawer: View {
    @Binding var isPresented: Bool
    let ritualType: FocusRitualType
    let summary: String
    let onSaveToJournal: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var tone: AuroraTone {
        AuroraToneKit.tone(for: ritualType)
    }
    
    var body: some View {
        Group {
            if isPresented {
                GeometryReader { geometry in
                    ZStack(alignment: .center) {
                        // Backdrop
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                closeDrawer()
                            }
                            .transition(.opacity)
                        
                        // Drawer
                        VStack(spacing: 0) {
                            AuroraDrawer(
                                isPresented: $isPresented,
                                title: "\(ritualType.displayName) Summary",
                                icon: "sparkles"
                            ) {
                                drawerContent
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var drawerContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Aurora branding
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            AuroraToneKit.accentGradient(for: AuroraToneKit.tone(for: ritualType))
                                .opacity(0.2)
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(
                            AuroraToneKit.accentGradient(for: AuroraToneKit.tone(for: ritualType))
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Aurora's Reflection")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                    
                    Text(AuroraToneKit.displayName(for: AuroraToneKit.tone(for: ritualType)))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                }
            }
            
            // Summary content
            DashboardTile(
                accent: AuroraToneKit.accentColor(for: AuroraToneKit.tone(for: ritualType)),
                padding: 24
            ) {
                Text(summary)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Action buttons
            HStack(spacing: 12) {
                GlassButton(
                    "Save to Journal",
                    icon: "book.fill",
                    style: .pill,
                    role: .primary
                ) {
                    onSaveToJournal()
                    closeDrawer()
                }
                
                GlassButton(
                    "Dismiss",
                    icon: "xmark",
                    style: .pill,
                    role: .surface
                ) {
                    closeDrawer()
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func closeDrawer() {
        withAnimation(GlassMotion.Easing.modalOpen) {
            isPresented = false
        }
    }
}

#Preview {
    @Previewable @State var isPresented = true
    
    RitualSummaryDrawer(
        isPresented: $isPresented,
        ritualType: .morning,
        summary: "Let's start strong. Today is a fresh canvas—focus on clarity and intention. You've set the foundation with your morning ritual, now channel that energy into your top priorities.",
        onSaveToJournal: {}
    )
    .environmentObject(GlassColorSystem())
}

