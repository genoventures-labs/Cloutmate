//
//  WebButton.swift
//  Cloutmate
//
//  Opens Aurora's web knowledge bridge.
//

import SwiftUI

struct WebButton: View {
    var isDisabled: Bool
    var onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.kosmicBlue.opacity(0.85),
                                Color.kosmicPurple.opacity(0.75)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.22), lineWidth: 0.9)
                    )
                    .shadow(color: Color.kosmicBlue.opacity(isHovering ? 0.28 : 0.12), radius: isHovering ? 6 : 3, y: 2)

                Image(systemName: "globe")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(isDisabled ? 0.35 : 0.92))
            }
            .frame(width: 28, height: 24)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.18)) {
                isHovering = hovering
            }
        }
        .accessibilityLabel("Web search")
        .accessibilityHint("Open Aurora's web knowledge bridge.")
    }
}

#Preview {
    WebButton(isDisabled: false, onTap: {})
        .padding()
        .background(Color.black.opacity(0.9))
}

