//
//  NudgeOverlayView.swift
//  FocusOS
//
//  Phase 8: Cognitive Loop Completion
//  Non-disruptive overlay for ARTE-aware smart nudges
//

import SwiftUI
import SwiftData

struct NudgeOverlayView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var service = SmartNudgeService.shared
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var isVisible = false
    @State private var isPinned = false
    @State private var isHovering = false
    @State private var showOrbShimmer = false
    
    @State private var dismissalWorkItem: DispatchWorkItem?
    @State private var shimmerWorkItem: DispatchWorkItem?
    
    private let appearAnimation = Animation.spring(response: 0.45, dampingFraction: 0.82, blendDuration: 0.2)
    private let fadeAnimation = Animation.easeInOut(duration: 0.28)
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let nudge = service.latestNudge {
                overlay(for: nudge)
                    .padding(.trailing, 28)
                    .padding(.bottom, 28)
                    .offset(x: isVisible ? 0 : 28, y: isVisible ? 0 : 60)
                    .opacity(isVisible ? 1 : 0)
                    .animation(appearAnimation, value: isVisible)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .allowsHitTesting(true)
        .onChange(of: service.latestNudge?.id) { _, newValue in
            resetState(for: newValue)
        }
    }
    
    private func overlay(for nudge: SmartNudge) -> some View {
        HStack(alignment: .bottom, spacing: 14) {
            auroraOrb(for: nudge.tone)
            
            speechBubble(for: nudge)
        }
        .background(Color.clear) // Ensure no black background shows through
        .onAppear {
            presentNudge()
        }
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                cancelScheduledTasks()
            } else if !isPinned {
                scheduleAutoDismiss()
            }
        }
        .onDisappear {
            cancelScheduledTasks()
        }
    }
    
    // MARK: - UI Components
    
    private func auroraOrb(for tone: SmartNudgeTone) -> some View {
        let accent = color(for: tone)
        let glow = accent.opacity(0.7)
        
        return AuroraOrbView(
            accent: accent,
            glow: glow,
            size: 48,
            isActive: true,
            showsPulse: showOrbShimmer
        )
    }
    
    @ViewBuilder
    private func speechBubble(for nudge: SmartNudge) -> some View {
        // Match test nudge structure: clean, organized layout
        HStack(spacing: 10) {
            // Icon (matching test nudge style)
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(glassColorSystem.emotionalAccent())
                .frame(width: 20, height: 20)
            
            // Content section (matching test nudge structure)
            VStack(alignment: .leading, spacing: 2) {
                // Main message (title)
                    Text(nudge.message)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                        .fixedSize(horizontal: false, vertical: true)
                    
                // Detail (subtitle) - if available
                    if let detail = nudge.detail, !detail.isEmpty {
                        Text(detail)
                        .font(.caption)
                        .foregroundStyle(glassColorSystem.textSecondary())
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
            Spacer()
            
            // Action buttons - compact, matching test nudge style
            HStack(spacing: 6) {
                // Primary action button
                Button {
                    handleResponse(.accepted, for: nudge)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .medium))
                        Text("Do it")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        glassColorSystem.emotionalAccent(),
                                        glassColorSystem.emotionalAccent().opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                }
                .buttonStyle(.plain)
                
                // Pin button - subtle icon
                Button {
                    togglePin()
                } label: {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isPinned ? glassColorSystem.emotionalAccent() : glassColorSystem.textSecondary().opacity(0.6))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPinned ? "Unpin nudge" : "Pin nudge")
                
                // Dismiss button - subtle
                Button {
                    dismissNudge(animated: true)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(glassColorSystem.textSecondary().opacity(0.6))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: 380)
        .background(
            ZStack {
                // Base background with material to prevent black edges
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                // Colored overlay
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(glassColorSystem.backgroundSecondary().opacity(0.4))
            }
                .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(glassColorSystem.emotionalAccent().opacity(0.3), lineWidth: 1)
                )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        )
        .shadow(color: glassColorSystem.emotionalAccent().opacity(0.15), radius: 12, x: 0, y: 4)
    }
    
    // MARK: - Logic
    
    private func presentNudge() {
        cancelScheduledTasks()
        isPinned = false
        isHovering = false
        showOrbShimmer = false
        
        withAnimation(appearAnimation) {
            isVisible = true
        }
        scheduleAutoDismiss()
    }
    
    private func resetState(for id: UUID?) {
        cancelScheduledTasks()
        if id == nil {
            withAnimation(fadeAnimation) {
                isVisible = false
            }
            showOrbShimmer = false
            return
        }
        
        DispatchQueue.main.async {
            presentNudge()
        }
    }
    
    private func togglePin() {
        isPinned.toggle()
        if isPinned {
            cancelScheduledTasks()
        } else if !isHovering {
            scheduleAutoDismiss()
        }
    }
    
    private func scheduleAutoDismiss() {
        guard !isPinned else { return }
        cancelScheduledTasks()
        
        let shimmerTask = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.6)) {
                showOrbShimmer = true
            }
        }
        
        let dismissTask = DispatchWorkItem {
            dismissNudge(animated: true)
        }
        
        shimmerWorkItem = shimmerTask
        dismissalWorkItem = dismissTask
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.8, execute: shimmerTask)
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.0, execute: dismissTask)
    }
    
    private func cancelScheduledTasks() {
        dismissalWorkItem?.cancel()
        shimmerWorkItem?.cancel()
        dismissalWorkItem = nil
        shimmerWorkItem = nil
        showOrbShimmer = false
    }
    
    private func dismissNudge(animated: Bool) {
        cancelScheduledTasks()
        guard service.latestNudge != nil else { return }
        
        let performDismissal = {
            service.clearLatestNudge()
            isVisible = false
        }
        
        if animated {
            withAnimation(fadeAnimation) {
                isVisible = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                performDismissal()
            }
        } else {
            performDismissal()
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
        
        dismissNudge(animated: true)
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
    
}

// MARK: - Supporting Types

private struct ChatBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerRadius: CGFloat = 22
        let tailSize = CGSize(width: 16, height: 12)
        
        let bubbleRect = CGRect(
            x: rect.minX + tailSize.width,
            y: rect.minY,
            width: rect.width - tailSize.width,
            height: rect.height
        )
        
        path.addRoundedRect(in: bubbleRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        
        path.move(to: CGPoint(x: bubbleRect.minX, y: bubbleRect.midY - tailSize.height / 2))
        path.addQuadCurve(
            to: CGPoint(x: bubbleRect.minX - tailSize.width, y: bubbleRect.midY),
            control: CGPoint(x: bubbleRect.minX - tailSize.width * 0.45, y: bubbleRect.midY - tailSize.height)
        )
        path.addQuadCurve(
            to: CGPoint(x: bubbleRect.minX, y: bubbleRect.midY + tailSize.height / 2),
            control: CGPoint(x: bubbleRect.minX - tailSize.width * 0.45, y: bubbleRect.midY + tailSize.height)
        )
        path.closeSubpath()
        
        return path
    }
}


