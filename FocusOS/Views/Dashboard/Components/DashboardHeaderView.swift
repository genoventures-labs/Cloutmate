//
//  DashboardHeaderView.swift
//  FocusOS
//
//  Dashboard V2 - Unified Header Zone with Cognitive Tempo Pulse Strip
//

import SwiftUI
import Combine

struct DashboardHeaderView: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @StateObject private var reactiveThemeManager = ReactiveThemeManager.shared
    @State private var pulsePhase: Double = 0.0
    @State private var tempoAnimation: Animation = .linear(duration: 3.0)
    
    let onRefresh: () -> Void
    let onSearch: () -> Void
    let onToggleInsights: (() -> Void)?
    
    private var currentState: EmotionalState {
        reactiveThemeManager.currentState
    }
    
    private var stateColor: Color {
        switch currentState {
        case .calm:
            return .kosmicBlue
        case .reflective:
            return .kosmicPurple
        case .energized:
            return .kosmicGreen
        case .fatigued:
            return .orange
        case .focused:
            return .kosmicBlue
        }
    }
    
    private var tempoDuration: Double {
        switch currentState {
        case .calm: return 3.5
        case .reflective: return 2.5
        case .energized: return 1.25
        case .focused: return 2.0
        case .fatigued: return 5.5
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main header content
            VStack(alignment: .leading, spacing: 12) {
                // Title and subline
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Dashboard")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(glassColorSystem.textPrimary())
                        
                        Text("Your day at a glance.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(glassColorSystem.textSecondary())
                            .metricLabelStyle()
                    }
                    
                    Spacer()
                    
                    // ARTE Status Light
                    HStack(spacing: 12) {
                        // Status ring indicator
                        ZStack {
                            Circle()
                                .stroke(stateColor.opacity(0.3), lineWidth: 2)
                                .frame(width: 24, height: 24)
                            
                            Circle()
                                .fill(stateColor.opacity(0.6))
                                .frame(width: 16, height: 16)
                        }
                        
                        // Quick Actions
                        HStack(spacing: 8) {
                            if let onToggleInsights = onToggleInsights {
                                Button(action: onToggleInsights) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 16))
                                        .foregroundColor(glassColorSystem.glassTint(for: .accent))
                                }
                                .buttonStyle(.plain)
                                .help("Aurora Insights")
                            }
                            
                            Button(action: {
                                NotificationCenter.default.post(name: .openContextualCreate, object: nil)
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(glassColorSystem.glassTint(for: .accent))
                            }
                            .buttonStyle(.plain)
                            .help("New Entry")
                            
                            Button(action: onRefresh) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 16))
                                    .foregroundColor(glassColorSystem.textSecondary())
                            }
                            .buttonStyle(.plain)
                            .help("Refresh")
                            
                            Button(action: onSearch) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 16))
                                    .foregroundColor(glassColorSystem.textSecondary())
                            }
                            .buttonStyle(.plain)
                            .help("Search")
                            .keyboardShortcut("k", modifiers: .command)
                        }
                    }
                }
                
                // Cognitive Tempo Pulse Strip
                if !reduceMotion {
                    cognitiveTempoStrip
                        .frame(height: 2)
                        .padding(.top, 4)
                }
            }
            .padding(20)
        }
        .background(
            LinearGradient(
                colors: [.kosmicBlue.opacity(0.1), .kosmicPurple.opacity(0.05)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .glassPanel(tier: .overlay, cornerRadius: 12)
        .onAppear {
            updateTempoAnimation()
            startTempoAnimation()
        }
        .onChange(of: currentState) { _, _ in
            updateTempoAnimation()
        }
        .onReceive(reactiveThemeManager.$currentState) { _ in
            updateTempoAnimation()
        }
    }
    
    private var cognitiveTempoStrip: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 1)
                    .fill(stateColor.opacity(0.1))
                    .frame(height: 2)
                
                // Animated pulse wave
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(
                            colors: [
                                stateColor.opacity(0.0),
                                stateColor.opacity(0.6 + pulsePhase * 0.4),
                                stateColor.opacity(0.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * 0.4, height: 2)
                    .offset(x: (geometry.size.width * pulsePhase) - (geometry.size.width * 0.2))
            }
        }
    }
    
    private func updateTempoAnimation() {
        tempoAnimation = .linear(duration: tempoDuration).repeatForever(autoreverses: false)
    }
    
    private func startTempoAnimation() {
        withAnimation(tempoAnimation) {
            pulsePhase = 1.0
        }
    }
}

#Preview {
    DashboardHeaderView(
        onRefresh: {},
        onSearch: {},
        onToggleInsights: nil
    )
    .padding()
    .environmentObject(GlassColorSystem())
}

