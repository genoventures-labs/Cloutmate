//
//  AppleCalendarPermissionDeniedDrawer.swift
//  FocusOS
//
//  Custom drawer alert for Apple Calendar permission denied
//

import SwiftUI
import AppKit

struct AppleCalendarPermissionDeniedDrawer: View {
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var onOpenSystemSettings: () -> Void
    
    private var accentGradient: LinearGradient {
        AuroraPalette.linearGradient(for: colorScheme)
    }
    
    var body: some View {
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
                    V2DrawerScaffold(
                        accentGradient: accentGradient,
                        showsSidebar: false,
                        header: { headerView },
                        content: { contentView },
                        sidebar: { EmptyView() }
                    )
                }
                .frame(width: min(500, geometry.size.width * 0.8))
                .frame(maxHeight: .infinity, alignment: .center)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .onKeyPress(.escape) {
            closeDrawer()
            return .handled
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Calendar Access Needed")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
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
        }
    }
    
    // MARK: - Content
    
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("FocusOS needs permission to read your Apple Calendar events.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("Enable access in System Settings to continue.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            HStack(spacing: 12) {
                GlassButton("Cancel", icon: "xmark", role: .surface) {
                    closeDrawer()
                }
                
                Spacer()
                
                GlassButton("Open System Settings", icon: "gear", role: .accent) {
                    openSystemSettings()
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func openSystemSettings() {
        // Deep-link to Calendar privacy settings
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
        onOpenSystemSettings()
        closeDrawer()
    }
    
    private func closeDrawer() {
        withAnimation(GlassMotion.Easing.modalOpen) {
            isPresented = false
        }
    }
}

