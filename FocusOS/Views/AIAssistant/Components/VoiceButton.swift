//
//  VoiceButton.swift
//  FocusOS
//
//  Animated microphone button for Aurora chat.
//

import SwiftUI

struct VoiceButton: View {
    var isRecording: Bool
    var isDisabled: Bool
    var onTap: () -> Void

    @State private var glowPhase: CGFloat = 0
    @State private var waveformPhase: CGFloat = 0

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.red.opacity(isRecording ? 0.9 : 0.7),
                Color.orange.opacity(isRecording ? 0.8 : 0.5)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(gradient)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.28), lineWidth: 1.2)
                    )
                    .shadow(color: Color.red.opacity(isRecording ? 0.35 : 0.12), radius: isRecording ? 10 : 4, y: 3)
                    .scaleEffect(isRecording ? 1.05 + 0.02 * sin(glowPhase) : 1.0)

                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(isDisabled ? 0.3 : 0.92))
            }
            .frame(width: 26, height: 26)
            .overlay(alignment: .bottom) {
                if isRecording {
                    waveform
                        .offset(y: 20)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onAppear {
            guard isRecording else { return }
            animateGlow()
        }
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                animateGlow()
            }
        }
        .accessibilityLabel(isRecording ? "Stop recording" : "Voice input")
        .accessibilityHint("Activate voice-to-text capture for Aurora.")
    }

    private var waveform: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            Canvas { context, size in
                var path = Path()
                let samples = 24
                let amplitude: CGFloat = height / 2
                for index in 0..<samples {
                    let progress = CGFloat(index) / CGFloat(samples)
                    let x = progress * width
                    let sine = sin(progress * 12 * .pi + waveformPhase)
                    let y = height / 2 + sine * amplitude * 0.6
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                context.stroke(
                    path,
                    with: .color(Color.red.opacity(0.8)),
                    lineWidth: 1.8
                )
            }
        }
        .frame(width: 42, height: 12)
        .onAppear {
            withAnimation(.linear(duration: 0.6).repeatForever(autoreverses: false)) {
                waveformPhase = .pi * 2
            }
        }
    }

    private func animateGlow() {
        withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) {
            glowPhase = .pi * 2
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        VoiceButton(isRecording: false, isDisabled: false, onTap: {})
        VoiceButton(isRecording: true, isDisabled: false, onTap: {})
    }
    .padding()
    .background(Color.black.opacity(0.9))
}

