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
            Spacer().frame(height: 20)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: icon(for: nudge.tone))
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(color(for: nudge.tone))
                            .frame(width: 28)
                        
                        VStack(alignment: .leading, spacing: 6) {
                        Text(nudge.message)
                                .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)

                    if let detail = nudge.detail {
                        Text(detail)
                                    .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.bottom, 4)

                    HStack(spacing: 12) {
                        Button {
                            handleResponse(.accepted, for: nudge)
                        } label: {
                            Text("Let's do it")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)

                        Button {
                            handleResponse(.snoozed, for: nudge)
                        } label: {
                            Text("Remind me later")
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)

                        Button("Dismiss") {
                            handleResponse(.dismissed, for: nudge)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                }
                Spacer()
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThickMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(color(for: nudge.tone).opacity(0.4), lineWidth: 1.5)
                    )
                    .shadow(color: color(for: nudge.tone).opacity(0.2), radius: 12, x: 0, y: 4)
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
        case .focused: return .kosmicBlue
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


