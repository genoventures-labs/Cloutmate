//
//  AuroraDrawer.swift
//  FocusOS
//
//  Shared drawer shell for Aurora assistant overlays
//

import SwiftUI

struct AuroraDrawer<Content: View>: View {
    @Binding var isPresented: Bool
    let title: String
    let icon: String
    @ViewBuilder var content: () -> Content
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                gradientSidebar
                
                VStack(spacing: 0) {
                    header
                        .padding()
                        .background(.ultraThinMaterial)
                    
                    ScrollView {
                        content()
                            .padding(24)
                    }
                    .background(glassColorSystem.backgroundColor())
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(glassColorSystem.backgroundColor())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        close()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                }
            }
        }
        .frame(minWidth: 520, minHeight: 440)
        .frame(idealWidth: 640, idealHeight: 520)
    }
    
    private var gradientSidebar: some View {
        RoundedRectangle(cornerRadius: 0, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.kosmicBlue.opacity(0.9), Color.kosmicPurple.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 4)
    }
    
    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.kosmicBlue)
            Text(title)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(glassColorSystem.textPrimary())
            Spacer()
        }
    }
    
    private func close() {
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isPresented = false
        }
    }
}
