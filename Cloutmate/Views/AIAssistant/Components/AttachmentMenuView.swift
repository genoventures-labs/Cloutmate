//
//  AttachmentMenuView.swift
//  Cloutmate
//
//  Inline attachment picker for Aurora chat input.
//

import SwiftUI

struct AttachmentMenuView: View {
    enum AttachmentType {
        case document
        case image
    }

    var isDisabled: Bool
    var activeAttachment: AttachmentType?
    var onSelectDocument: () -> Void
    var onSelectImage: () -> Void

    @State private var isHovering = false
    @State private var isPressed = false

    private var icon: String {
        switch activeAttachment {
        case .document:
            return "doc.fill"
        case .image:
            return "photo"
        case .none:
            return "plus"
        }
    }

    var body: some View {
        Menu {
            Button("Attach Document", action: onSelectDocument)
                .disabled(isDisabled || activeAttachment == .document)
            Button("Upload Image", action: onSelectImage)
                .disabled(isDisabled || activeAttachment == .image)
        } label: {
            Circle()
                .fill(iconBackgroundGradient)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(isDisabled ? 0.4 : 0.9))
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                )
                .frame(width: 26, height: 26)
                .shadow(color: Color.white.opacity(isHovering ? 0.15 : 0.05), radius: isHovering ? 6 : 2, y: 2)
        }
        .menuStyle(.borderlessButton)
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
        .accessibilityLabel("Attachment menu")
        .accessibilityHint("Attach a document or image to your message.")
    }

    private var iconBackgroundGradient: LinearGradient {
        let colors: [Color]
        switch activeAttachment {
        case .document:
            colors = [Color.kosmicBlue, Color.kosmicPurple]
        case .image:
            colors = [Color.kosmicPurple, Color.pink.opacity(0.75)]
        case .none:
            colors = [Color.kosmicBlue.opacity(0.9), Color.kosmicPurple.opacity(0.8)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
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
        AttachmentMenuView(
            isDisabled: false,
            activeAttachment: nil,
            onSelectDocument: {},
            onSelectImage: {}
        )
        AttachmentMenuView(
            isDisabled: false,
            activeAttachment: .document,
            onSelectDocument: {},
            onSelectImage: {}
        )
    }
    .padding()
    .background(Color.black.opacity(0.85))
}

