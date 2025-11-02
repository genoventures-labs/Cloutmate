//
//  NudgeOverlayView.swift
//  Cloutmate
//
//  Phase 8: Cognitive Loop Completion
//  Non-disruptive overlay for ARTE-aware smart nudges
//

import SwiftUI
import SwiftData

struct NudgeOverlayView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var service = SmartNudgeService.shared
    @State private var isVisible = false

    var body: some View {
        Group {
            if let nudge = service.latestNudge {
                overlay(for: nudge)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isVisible = true
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: service.latestNudge?.id)
    }

    private func overlay(for nudge: SmartNudge) -> some View {
        VStack {
            Spacer().frame(height: 16)

            HStack {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: icon(for: nudge.tone))
                            .foregroundColor(color(for: nudge.tone))
                        Text(nudge.message)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }

                    if let detail = nudge.detail {
                        Text(detail)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 12) {
                        Button {
                            handleResponse(.accepted, for: nudge)
                        } label: {
                            Text("Let's do it")
                                .font(.system(size: 13, weight: .bold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            handleResponse(.snoozed, for: nudge)
                        } label: {
                            Text("Remind me later")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .buttonStyle(.bordered)

                        Button("Dismiss") {
                            handleResponse(.dismissed, for: nudge)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(color(for: nudge.tone).opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(color(for: nudge.tone).opacity(0.3))
                    )
            )
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func handleResponse(_ response: SmartNudgeResponse, for nudge: SmartNudge) {
        nudge.registerResponse(response)

        if response == .snoozed {
            let cooldown = Date().addingTimeInterval(RitualSettings.shared.minimumNudgeInterval)
            nudge.suppress(until: cooldown)
        }

        do {
            try modelContext.save()
        } catch {
            // Soft-fail: log silently in production builds
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            service.clearLatestNudge()
            isVisible = false
        }
    }

    private func color(for tone: SmartNudgeTone) -> Color {
        switch tone {
        case .calm: return KosmicPalette.cyan
        case .energized: return KosmicPalette.violet
        case .gentle: return .orange
        case .focused: return .blue
        case .reflective: return .purple
        }
    }

    private func icon(for tone: SmartNudgeTone) -> String {
        switch tone {
        case .calm: return "leaf"
        case .energized: return "bolt.fill"
        case .gentle: return "hands.sparkles.fill"
        case .focused: return "target"
        case .reflective: return "brain.head.profile"
        }
    }
}


