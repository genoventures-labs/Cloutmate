//
//  SpotlightResultToast.swift
//  FocusOS
//
//  Glass blur toast component for Spotlight execution confirmations
//

import SwiftUI
import FocusOSShared

struct SpotlightResultToast: View {
    let message: String
    let systemImage: String?
    
    @State private var isVisible = false
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    init(message: String, systemImage: String? = nil) {
        self.message = message
        self.systemImage = systemImage
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon = systemImage {
                Image(systemName: icon)
                    .foregroundStyle(.kosmicGreen)
                    .font(.system(size: 16, weight: .medium))
            }
            
            Text(message)
                .foregroundStyle(glassColorSystem.textPrimary())
                .font(.system(size: 14, weight: .medium, design: .rounded))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(glassColorSystem.cardColor().opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.kosmicGreen.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
        )
        .scaleEffect(isVisible ? 1 : 0.9)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(GlassMotion.Easing.spring) {
                isVisible = true
            }
            
            // Auto-dismiss after 2.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(GlassMotion.Easing.spring) {
                    isVisible = false
                }
            }
        }
    }
}

#Preview {
    VStack {
        SpotlightResultToast(message: "☀️ Morning Ritual started", systemImage: "sparkles")
        SpotlightResultToast(message: "Created task: Review design mockups")
        SpotlightResultToast(message: "Found 5 rituals this week", systemImage: "moon.stars.fill")
    }
    .padding()
    .background(Color.black.opacity(0.3))
    .environmentObject(GlassColorSystem())
}

