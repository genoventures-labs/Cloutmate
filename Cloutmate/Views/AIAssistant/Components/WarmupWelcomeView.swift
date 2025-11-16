//
//  WarmupWelcomeView.swift
//  Cloutmate
//
//  Welcome message shown while models are warming up
//

import SwiftUI

struct WarmupWelcomeView: View {
    let message: String
    let progress: String?
    
    var body: some View {
        VStack(spacing: 20) {
            // Aurora icon/animation
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.kosmicBlue, .kosmicPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.pulse.byLayer, options: .repeating)
            
            // Welcome message from Aurora
            Text(message)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // Progress indicator if available
            if let progress = progress, !progress.isEmpty {
                Text(progress)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .transition(.opacity)
            }
            
            // Subtle loading indicator
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.8)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    WarmupWelcomeView(
        message: "Hi! I'm just getting my systems ready. This will only take a moment...",
        progress: "Waking up Gemma3..."
    )
    .background(Color.black.opacity(0.95))
}

