//
//  CollapsedChatView.swift
//  FocusOS
//
//  Minimized Aurora chat orb with breathing animation.
//

import SwiftUI

struct CollapsedChatView: View {
    var title: String
    var subtitle: String
    var onTap: () -> Void
    var onLongPress: (() -> Void)?
    var accent: Color
    var glow: Color
    var isRecording: Bool

    @State private var isPressed = false
    @State private var ripple = false

    private var backgroundMaterial: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(glow.opacity(0.15), lineWidth: 1.2)
            )
            .shadow(color: glow.opacity(0.12), radius: 20, y: 10)
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 18) {
                AuroraOrbView(
                    accent: accent,
                    glow: glow,
                    size: 64,
                    isActive: true,
                    showsPulse: ripple
                )
                .overlay(alignment: .bottom) {
                    if isRecording {
                        Capsule()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                            .offset(y: 18)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 12)

                Image(systemName: "chevron.up")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .opacity(0.6)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(backgroundMaterial)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.18), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.8)
                .onChanged { _ in
                    guard !isPressed else { return }
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                    onLongPress?()
                }
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                ripple = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    ripple = false
                }
            }
        }
    }
}

#Preview {
    CollapsedChatView(
        title: "Aurora",
        subtitle: "Tap to resume conversation",
        onTap: {},
        onLongPress: {},
        accent: .kosmicBlue,
        glow: .kosmicPurple,
        isRecording: false
    )
    .padding()
    .background(Color.black.opacity(0.8))
}

