//
//  EmotionalStateIndicator.swift
//  FocusOS
//
//  Phase 7: ARTE - Aurora Reactive Theme Engine
//  Compact emotional state display for Insights Dashboard
//

import SwiftUI
import SwiftData

struct EmotionalStateIndicator: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @StateObject private var themeManager = ReactiveThemeManager.shared
    
    @Query(sort: \StateTransitionHistory.timestamp, order: .reverse)
    private var transitions: [StateTransitionHistory]
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(glassColorSystem.emotionalAccent())
                    Text("ARTE Status")
                        .font(.system(size: 18, weight: .bold))
                    Spacer()
                    
                    if themeManager.isEnabled {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                }
                
                if themeManager.isEnabled {
                    // Current State
                    currentStateView
                    
                    // State History
                    if !recentTransitions.isEmpty {
                        Divider()
                            .padding(.vertical, 4)
                        stateHistoryView
                    }
                } else {
                    Text("ARTE is disabled")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        themeManager.isEnabled = true
                        themeManager.restart(modelContext: modelContext)
                    }) {
                        Text("Enable ARTE")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(glassColorSystem.emotionalAccent())
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Current State
    
    private var currentStateView: some View {
        HStack(spacing: 16) {
            // State Icon with Glow
            ZStack {
                Circle()
                    .fill(glassColorSystem.emotionalAccent().opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: themeManager.currentState.iconName)
                    .font(.system(size: 28))
                    .foregroundColor(glassColorSystem.emotionalAccent())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(themeManager.currentState.displayName)
                    .font(.system(size: 20, weight: .bold))
                
                Text(themeManager.currentState.description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Mode badge
                HStack(spacing: 4) {
                    Image(systemName: modeBadgeIcon)
                        .font(.system(size: 10))
                    Text(themeManager.mode.displayName)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(glassColorSystem.emotionalAccent())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(glassColorSystem.emotionalAccent().opacity(0.15))
                )
                .padding(.top, 4)
            }
            
            Spacer()
            
            // Confidence Gauge
            confidenceGauge
        }
    }
    
    private var modeBadgeIcon: String {
        switch themeManager.mode {
        case .auto: return "wand.and.stars"
        case .manual: return "hand.tap"
        case .blend: return "slider.horizontal.3"
        }
    }
    
    private var confidenceGauge: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(glassColorSystem.emotionalAccent().opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: themeManager.confidence)
                    .stroke(glassColorSystem.emotionalAccent(), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(themeManager.confidence * 100))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(glassColorSystem.emotionalAccent())
            }
            
            Text("confidence")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - State History
    
    private var recentTransitions: [StateTransitionHistory] {
        Array(transitions.prefix(5))
    }
    
    private var stateHistoryView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Transitions")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            
            VStack(spacing: 6) {
                ForEach(recentTransitions, id: \.id) { transition in
                    historyRow(transition)
                }
            }
        }
    }
    
    private func historyRow(_ transition: StateTransitionHistory) -> some View {
        HStack(spacing: 8) {
            // Timeline Dot
            Circle()
                .fill(glassColorSystem.emotionalAccent().opacity(0.6))
                .frame(width: 6, height: 6)
            
            // Transition
            HStack(spacing: 4) {
                Text(transition.fromState.displayName)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                
                Text(transition.toState.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(glassColorSystem.textPrimary())
            }
            
            Spacer()
            
            // Time
            Text(relativeTime(from: transition.timestamp))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            // Manual Override Badge
            if transition.wasManualOverride {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 10))
                    .foregroundColor(glassColorSystem.emotionalAccent())
            }
        }
        .padding(.vertical, 4)
    }
    
    private func relativeTime(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

#Preview {
    EmotionalStateIndicator()
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [StateTransitionHistory.self, ARTEConfiguration.self])
        .frame(width: 400)
}

