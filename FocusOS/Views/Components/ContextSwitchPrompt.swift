//
//  ContextSwitchPrompt.swift
//  FocusOS
//
//  UI overlay for adaptive context switch guard.
//

import SwiftUI
import Combine

struct ContextSwitchPrompt: View {
    let title: String
    let message: String
    let decision: InterceptDecision
    let delay: TimeInterval
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var remaining: TimeInterval
    @State private var timerActive: Bool = true

    init(
        title: String = "Hold that switch",
        message: String,
        decision: InterceptDecision,
        delay: TimeInterval,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.decision = decision
        self.delay = delay
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _remaining = State(initialValue: delay)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)

            Text(message)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            countdownView

            HStack(spacing: 12) {
                Button(action: {
                    onCancel()
                }) {
                    Text("Stay here")
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: {
                    ContextSwitchGuard.shared.recordOverride(decision: decision)
                    onConfirm()
                }) {
                    Text(confirmLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(remaining > 0.0)
            }
            .padding(.top, 4)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 25, y: 8)
        .frame(maxWidth: 400)
        .padding(32)
        .onReceive(timer) { _ in
            guard timerActive else { return }
            if remaining <= 0 {
                timerActive = false
            } else {
                remaining = max(0.0, remaining - 0.1)
            }
        }
    }

    private var countdownView: some View {
        VStack(spacing: 4) {
            Text(remaining > 0 ? countdownLabel : "Ready when you are")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(.kosmicPurple)
        }
    }

    private var timer: Publishers.Autoconnect<Timer.TimerPublisher> {
        Timer
            .publish(every: 0.1, tolerance: 0.05, on: .main, in: .common)
            .autoconnect()
    }

    private var progress: Double {
        guard delay > 0 else { return 1.0 }
        let value = (delay - remaining) / delay
        return max(0.0, min(1.0, value))
    }

    private var countdownLabel: String {
        String(format: "Unlocking in %.1fs", remaining)
    }

    private var confirmLabel: String {
        switch decision {
        case .strongPrompt:
            return "Switch anyway"
        case .softPrompt:
            return "Go ahead"
        case .allow:
            return "Continue"
        }
    }
}


