//
//  ComposerDetailDrawer.swift
//  Cloutmate
//
//  Drawer presentation wrapping ComposerWindow for inline usage.
//

import SwiftUI
import CloutmateShared

struct ComposerDetailDrawer: View {
    @Binding var isPresented: Bool
    let existingPost: CloutmateShared.Post?
    let prefilledDate: Date?
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                gradientSidebar
                
                ComposerWindow(existingPost: existingPost, prefilledDate: prefilledDate, onClose: closeDrawer)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(glassColorSystem.backgroundColor())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .frame(idealWidth: 840, idealHeight: 660)
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
