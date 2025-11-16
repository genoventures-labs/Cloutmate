//
//  TabAttachmentDrawer.swift
//  Cloutmate
//
//  AI Assistant V2 - Tab Attachment Drawer
//  V2 drawer for selecting a tab to attach to the message
//

import SwiftUI
import CloutmateShared

struct TabAttachmentDrawer: View {
    @Binding var isPresented: Bool
    let onSelectTab: (TabIdentifier) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    private var accentGradient: LinearGradient {
        AuroraPalette.linearGradient(for: colorScheme)
    }
    
    private var availableTabs: [TabIdentifier] {
        TabIdentifier.allCases.filter { $0 != .aiAssistant }
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
                        .frame(maxHeight: geometry.size.height * 0.5)
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
                Text("Attach Tab")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                Text("Select a tab to attach to your message")
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
        ScrollView {
            VStack(spacing: 12) {
                ForEach(availableTabs, id: \.self) { tab in
                    Button {
                        onSelectTab(tab)
                        closeDrawer()
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(glassColorSystem.textPrimary())
                                .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(glassColorSystem.glassTint(for: .surface).opacity(0.3))
                                    )
                            
                            Text(tab.rawValue)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(glassColorSystem.textPrimary())
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(glassColorSystem.textSecondary())
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(glassColorSystem.glassTint(for: .surface).opacity(0.2))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(glassColorSystem.glassTint(for: .surface).opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

#Preview {
    @Previewable @State var isPresented = true
    TabAttachmentDrawer(
        isPresented: $isPresented,
        onSelectTab: { _ in }
    )
    .environmentObject(GlassColorSystem())
}

