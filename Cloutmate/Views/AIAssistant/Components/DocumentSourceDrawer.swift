//
//  DocumentSourceDrawer.swift
//  Cloutmate
//
//  AI Assistant V2 - Document Source Drawer
//  V2 drawer for choosing document source (file picker or URL)
//

import SwiftUI
import CloutmateShared

struct DocumentSourceDrawer: View {
    @Binding var isPresented: Bool
    let onSelectFromComputer: () -> Void
    let onSelectFromURL: () -> Void
    
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
                        .frame(maxHeight: geometry.size.height * 0.4)
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
                Text("Add Document")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                Text("Choose how you want to bring this document into the chat")
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
        VStack(spacing: 16) {
            DrawerSection(title: "Source", icon: "doc.fill") {
                VStack(spacing: 12) {
                    GlassButton(
                        "From Computer",
                        icon: "folder.fill",
                        style: .standard,
                        role: .primary,
                        tintColor: .kosmicBlue
                    ) {
                        closeDrawer()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onSelectFromComputer()
                        }
                    }
                    
                    GlassButton(
                        "From URL",
                        icon: "link",
                        style: .standard,
                        role: .surface,
                        tintColor: .kosmicPurple
                    ) {
                        closeDrawer()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onSelectFromURL()
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    @Previewable @State var isPresented = true
    DocumentSourceDrawer(
        isPresented: $isPresented,
        onSelectFromComputer: {},
        onSelectFromURL: {}
    )
    .environmentObject(GlassColorSystem())
}

