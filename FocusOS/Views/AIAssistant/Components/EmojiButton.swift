//
//  EmojiButton.swift
//  FocusOS
//
//  Emoji picker toolbar button for Aurora chat input.
//

import SwiftUI

struct EmojiButton: View {
    var isDisabled: Bool = false
    var onToggle: () -> Void
    
    @State private var isHovering = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onToggle) {
            Circle()
                .fill(iconBackgroundGradient)
                .overlay(
                    Image(systemName: "face.smiling")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(isDisabled ? 0.4 : 0.9))
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                )
                .frame(width: 26, height: 26)
                .shadow(color: Color.white.opacity(isHovering ? 0.15 : 0.05), radius: isHovering ? 6 : 2, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { hovering in
            isHovering = hovering
        }
        .pressEvents(
            onPress: {
                withAnimation(.easeOut(duration: 0.12)) {
                    isPressed = true
                }
            },
            onRelease: {
                withAnimation(.easeOut(duration: 0.12)) {
                    isPressed = false
                }
            }
        )
        .accessibilityLabel("Emoji picker")
        .accessibilityHint("Open emoji picker to insert emojis.")
    }
    
    private var iconBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.kosmicBlue.opacity(0.9),
                Color.kosmicPurple.opacity(0.8)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressEventsModifier(onPress: onPress, onRelease: onRelease))
    }
}

private struct PressEventsModifier: ViewModifier {
    var onPress: () -> Void
    var onRelease: () -> Void
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() }
            )
    }
}

#Preview {
    HStack(spacing: 16) {
        EmojiButton(onToggle: {})
        EmojiButton(isDisabled: true, onToggle: {})
    }
    .padding()
    .background(Color.black.opacity(0.85))
}

