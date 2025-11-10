//
//  VoiceMemoDrawer.swift
//  Cloutmate
//
//  Drawer presentation for voice memo capture
//

import SwiftUI

struct VoiceMemoDrawer: View {
    @Binding var isPresented: Bool
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                gradientSidebar
                
                VoiceMemoView(onClose: closeDrawer)
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
        .frame(minWidth: 580, minHeight: 420)
        .frame(idealWidth: 700, idealHeight: 480)
    }
    
    private var gradientSidebar: some View {
        RoundedRectangle(cornerRadius: 0, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.kosmicPurple.opacity(0.85), Color.kosmicBlue.opacity(0.35)],
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
