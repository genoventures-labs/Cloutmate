//
//  InboxQuickCaptureDrawer.swift
//  Cloutmate
//
//  Drawer presentation for inbox capture
//

import SwiftUI

struct InboxQuickCaptureDrawer: View {
    @Binding var isPresented: Bool
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                gradientSidebar
                
                QuickCaptureView(onClose: closeDrawer)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(glassColorSystem.backgroundColor())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(glassColorSystem.backgroundColor())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        closeDrawer()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                }
            }
        }
        .frame(minWidth: 640, minHeight: 520)
        .frame(idealWidth: 780, idealHeight: 560)
    }
    
    private var gradientSidebar: some View {
        RoundedRectangle(cornerRadius: 0, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.kosmicBlue.opacity(0.85), Color.kosmicPurple.opacity(0.35)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 4)
    }
    
    private func closeDrawer() {
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isPresented = false
        }
    }
}

