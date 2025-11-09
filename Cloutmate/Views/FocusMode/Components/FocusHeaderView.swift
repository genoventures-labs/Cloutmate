//
//  FocusHeaderView.swift
//  Cloutmate
//
//  Focus Mode V2 - Unified Header Zone
//

import SwiftUI
import CloutmateShared

enum FocusFilter: String, CaseIterable {
    case session = "Session"
    case streak = "Streak"
    case stats = "Stats"
}

struct FocusHeaderView: View {
    let activeSession: FocusSession?
    let selectedFilter: FocusFilter
    let onFilterChange: (FocusFilter) -> Void
    let onStartSession: () -> Void
    let onPauseSession: () -> Void
    let onEndSession: () -> Void
    let onSetObjective: () -> Void
    let onOpenAuroraInsights: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrollOffset: CGFloat = 0
    @State private var breathingPhase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 16) {
                // Title and Subline
                VStack(alignment: .leading, spacing: 4) {
                    Text("Focus Mode")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Deep work, simplified.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Controls Row
                HStack(spacing: 12) {
                    // Timer Toggle Button
                    timerToggleButton
                    
                    // Set Objective Button
                    GlassButton(
                        "Set Objective",
                        icon: "target",
                        style: .standard,
                        role: .surface,
                        action: onSetObjective
                    )
                    
                    Spacer()
                    
                    // Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(FocusFilter.allCases, id: \.self) { filter in
                                FilterPill(
                                    title: filter.rawValue,
                                    isSelected: selectedFilter == filter,
                                    action: {
                                        if reduceMotion {
                                            onFilterChange(filter)
                                        } else {
                                            withAnimation(GlassMotion.Easing.spring) {
                                                onFilterChange(filter)
                                            }
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    
                    // Aurora Insight Button
                    GlassButton(
                        nil,
                        icon: "sparkles",
                        style: .iconOnly,
                        role: .surface,
                        tintColor: .kosmicPurple,
                        action: onOpenAuroraInsights
                    )
                    .frame(width: 40, height: 40)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                GlassPanel(tier: .overlay, cornerRadius: 0) {
                    LinearGradient(
                        colors: [
                            Color.kosmicBlue.opacity(0.1),
                            Color.kosmicPurple.opacity(0.05)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
            )
            .overlay(
                // Breathing animation overlay when session is active
                Group {
                    if activeSession != nil && !reduceMotion {
                        RoundedRectangle(cornerRadius: 0)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.kosmicBlue.opacity(0.3 + breathingPhase * 0.2),
                                        Color.kosmicPurple.opacity(0.2 + breathingPhase * 0.15)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                            .opacity(0.6 + breathingPhase * 0.4)
                    }
                }
            )
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: ScrollOffsetPreferenceKey.self, value: proxy.frame(in: .named("scroll")).minY)
                }
            )
            .opacity(headerOpacity)
            .offset(y: headerOffset)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
        .frame(height: 140)
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            scrollOffset = value
        }
        .onAppear {
            if activeSession != nil && !reduceMotion {
                startBreathingAnimation()
            }
        }
        .onChange(of: activeSession) { _, newSession in
            if newSession != nil && !reduceMotion {
                startBreathingAnimation()
            } else {
                breathingPhase = 0
            }
        }
    }
    
    // MARK: - Timer Toggle Button
    
    @ViewBuilder
    private var timerToggleButton: some View {
        if let session = activeSession {
            // Pause/End buttons when session is active
            HStack(spacing: 8) {
                GlassButton(
                    "Pause",
                    icon: "pause.circle.fill",
                    style: .standard,
                    role: .surface,
                    action: onPauseSession
                )
                
                GlassButton(
                    "End",
                    icon: "stop.circle.fill",
                    style: .standard,
                    role: .danger,
                    action: onEndSession
                )
            }
        } else {
            // Start button when no session
            GlassButton(
                "Start",
                icon: "play.circle.fill",
                style: .standard,
                role: .primary,
                action: onStartSession
            )
        }
    }
    
    // MARK: - Header Animation
    
    private var headerOpacity: Double {
        let threshold: CGFloat = 100
        if scrollOffset > threshold {
            return max(0.3, 1.0 - (scrollOffset - threshold) / 200)
        }
        return 1.0
    }
    
    private var headerOffset: CGFloat {
        let threshold: CGFloat = 100
        if scrollOffset > threshold {
            return min(-20, -(scrollOffset - threshold) / 10)
        }
        return 0
    }
    
    private func startBreathingAnimation() {
        withAnimation(
            Animation.easeInOut(duration: GlassMotion.Duration.auroraPulse)
                .repeatForever(autoreverses: true)
        ) {
            breathingPhase = 1.0
        }
    }
}

#Preview {
    FocusHeaderView(
        activeSession: nil,
        selectedFilter: .session,
        onFilterChange: { _ in },
        onStartSession: {},
        onPauseSession: {},
        onEndSession: {},
        onSetObjective: {},
        onOpenAuroraInsights: {}
    )
    .environmentObject(GlassColorSystem())
    .padding()
}

