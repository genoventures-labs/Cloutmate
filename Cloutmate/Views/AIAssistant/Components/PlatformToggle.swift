//
//  PlatformToggle.swift
//  Cloutmate
//
//  AI Assistant V2 - Platform Selector Toggle
//  Pill-style toggle matching Calendar toggle design
//

import SwiftUI
import CloutmateShared

struct PlatformToggle: View {
    @Binding var selectedPlatform: Platform
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Platform.allCases, id: \.self) { platform in
                Button(action: {
                    withAnimation(reduceMotion ? nil : GlassMotion.Easing.spring) {
                        selectedPlatform = platform
                    }
                }) {
                    Text(platform.displayName)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(selectedPlatform == platform ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(
                            Group {
                                if selectedPlatform == platform {
                                    // Selected state
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(Color.kosmicBlue.opacity(0.3))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                .strokeBorder(
                                                    LinearGradient(
                                                        colors: [Color.kosmicBlue.opacity(0.5), Color.kosmicBlue.opacity(0.3)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1.5
                                                )
                                        )
                                } else {
                                    // Unselected state
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(Color.clear)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(glassColorSystem.cardColor())
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(glassColorSystem.borderColor(), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    @Previewable @State var platform = Platform.threads
    
    PlatformToggle(selectedPlatform: $platform)
        .padding()
        .environmentObject(GlassColorSystem())
}

