//
//  SpotlightResultToast.swift
//  Cloutmate
//
//  Glass blur toast component for Spotlight execution confirmations
//

import SwiftUI

struct SpotlightResultToast: View {
    let message: String
    let systemImage: String?
    
    @State private var isVisible = false
    
    init(message: String, systemImage: String? = nil) {
        self.message = message
        self.systemImage = systemImage
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon = systemImage {
                Image(systemName: icon)
                    .foregroundColor(.kosmicGreen)
                    .font(.title3)
            }
            
            Text(message)
                .foregroundColor(.primary)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.medium)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [Color.kosmicGreen.opacity(0.3), Color.kosmicGreen.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .scaleEffect(isVisible ? 1 : 0.9)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isVisible = true
            }
            
            // Auto-dismiss after 2.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
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
}

