//
//  DailyOverviewPanel.swift
//  Cloutmate
//
//  Dashboard V2 - Daily Overview Row with 3-column adaptive cards
//

import SwiftUI
import SwiftData
import CloutmateShared

struct DailyOverviewPanel: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @StateObject private var reactiveThemeManager = ReactiveThemeManager.shared
    @State private var priorityItems: [PriorityItem] = []
    @State private var latestForecast: FocusForecast?
    @State private var hoveredCard: Int? = nil
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ], spacing: 16) {
            // Card 1: Focus Gravity Summary
            FocusGravitySummaryCard(
                priorityItems: Array(priorityItems.prefix(3)),
                latestForecast: latestForecast,
                isHovered: hoveredCard == 0,
                onTap: {
                    NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.focusGravity)
                }
            )
            .onHover { hovering in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    hoveredCard = hovering ? 0 : nil
                }
            }
            
            // Card 2: ARTE Mood Pulse
            ARTEMoodPulseCard(
                currentState: reactiveThemeManager.currentState,
                isHovered: hoveredCard == 1,
                onTap: {
                    NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.insights)
                }
            )
            .onHover { hovering in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    hoveredCard = hovering ? 1 : nil
                }
            }
            
            // Card 3: Predictive Cognition Forecast
            PredictiveCognitionCard(
                forecast: latestForecast,
                isHovered: hoveredCard == 2,
                onTap: {
                    // Deep link to Predictive Cognition settings
                }
            )
            .onHover { hovering in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    hoveredCard = hovering ? 2 : nil
                }
            }
        }
        .task {
            await loadData()
        }
    }
    
    @MainActor
    private func loadData() async {
        // Load priority items
        priorityItems = PriorityEngine.shared.getTopObjects(limit: 3, modelContext: modelContext)
        
        // Load latest forecast
        latestForecast = CognitionPredictor.shared.fetchLatestForecast(modelContext: modelContext)
    }
}

// MARK: - Focus Gravity Summary Card

struct FocusGravitySummaryCard: View {
    let priorityItems: [PriorityItem]
    let latestForecast: FocusForecast?
    let isHovered: Bool
    let onTap: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "gauge.with.dots.needle.67percent")
                        .font(.system(size: 18))
                        .foregroundColor(.kosmicBlue)
                    Text("Focus Gravity")
                        .font(.headline)
                        .foregroundColor(glassColorSystem.textPrimary())
                }
                
                if priorityItems.isEmpty {
                    Text("No priorities yet")
                        .font(.caption)
                        .foregroundColor(glassColorSystem.textSecondary())
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(priorityItems.prefix(3)) { item in
                            HStack {
                                Text(item.title)
                                    .font(.subheadline)
                                    .foregroundColor(glassColorSystem.textPrimary())
                                    .lineLimit(1)
                                Spacer()
                                Text("\(Int(item.score * 100))")
                                    .font(.caption)
                                    .foregroundColor(.kosmicBlue)
                            }
                        }
                    }
                }
                
                if let forecast = latestForecast,
                   let windowStart = forecast.nextFocusWindowStart {
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.kosmicPurple)
                        Text("Next Priority Window: \(windowStart, style: .time)")
                            .font(.caption)
                            .foregroundColor(glassColorSystem.textSecondary())
                    }
                    .padding(.top, 4)
                }
            }
            .padding(16)
        }
        .scaleEffect(isHovered ? 1.015 : 1.0)
        .shadow(color: isHovered ? Color.kosmicPurple.opacity(0.2) : Color.black.opacity(0.05), radius: isHovered ? 8 : 3)
        .onTapGesture(perform: onTap)
    }
}

// MARK: - ARTE Mood Pulse Card

struct ARTEMoodPulseCard: View {
    let currentState: EmotionalState
    let isHovered: Bool
    let onTap: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    private var stateColor: Color {
        switch currentState {
        case .calm: return .kosmicBlue
        case .reflective: return .kosmicPurple
        case .energized: return .kosmicGreen
        case .fatigued: return .orange
        case .focused: return .kosmicBlue
        }
    }
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12, tintColor: stateColor.opacity(0.1)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: currentState.iconName)
                        .font(.system(size: 18))
                        .foregroundColor(stateColor)
                    Text("ARTE Mood Pulse")
                        .font(.headline)
                        .foregroundColor(glassColorSystem.textPrimary())
                }
                
                Text(currentState.displayName)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(stateColor)
                
                Text("You've maintained a steady \(currentState.displayName.lowercased()) energy since yesterday.")
                    .font(.subheadline)
                    .foregroundColor(glassColorSystem.textSecondary())
                    .italic()
                    .lineLimit(2)
            }
            .padding(16)
        }
        .scaleEffect(isHovered ? 1.015 : 1.0)
        .shadow(color: isHovered ? stateColor.opacity(0.2) : Color.black.opacity(0.05), radius: isHovered ? 8 : 3)
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Predictive Cognition Forecast Card

struct PredictiveCognitionCard: View {
    let forecast: FocusForecast?
    let isHovered: Bool
    let onTap: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    private var driftLevel: String {
        guard let forecast = forecast else { return "Unknown" }
        if forecast.fatigueRisk > 0.65 {
            return "High"
        } else if forecast.fatigueRisk > 0.35 {
            return "Medium"
        } else {
            return "Low"
        }
    }
    
    private var driftColor: Color {
        guard let forecast = forecast else { return .gray }
        if forecast.fatigueRisk > 0.65 {
            return .orange
        } else if forecast.fatigueRisk > 0.35 {
            return .yellow
        } else {
            return .kosmicGreen
        }
    }
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 18))
                        .foregroundColor(.kosmicPurple)
                    Text("Cognitive Forecast")
                        .font(.headline)
                        .foregroundColor(glassColorSystem.textPrimary())
                }
                
                if let forecast = forecast {
                    // Fatigue risk meter
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Fatigue Risk")
                                .font(.caption)
                                .foregroundColor(glassColorSystem.textSecondary())
                            Spacer()
                            Text("\(Int(forecast.fatigueRisk * 100))%")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(driftColor)
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 6)
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(
                                        LinearGradient(
                                            colors: [driftColor.opacity(0.6), driftColor],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * forecast.fatigueRisk, height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                    
                    // Peak Focus window
                    if let windowStart = forecast.nextFocusWindowStart,
                       let windowEnd = forecast.nextFocusWindowEnd {
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.caption)
                                .foregroundColor(.kosmicGreen)
                            Text("Peak Focus: \(windowStart, style: .time) - \(windowEnd, style: .time)")
                                .font(.caption)
                                .foregroundColor(glassColorSystem.textSecondary())
                        }
                    }
                    
                    // Cognitive Drift indicator
                    HStack {
                        Image(systemName: "waveform.path")
                            .font(.caption)
                            .foregroundColor(driftColor)
                        Text("Cognitive Drift: \(driftLevel)")
                            .font(.caption)
                            .foregroundColor(glassColorSystem.textSecondary())
                    }
                } else {
                    Text("No forecast available")
                        .font(.caption)
                        .foregroundColor(glassColorSystem.textSecondary())
                }
            }
            .padding(16)
        }
        .scaleEffect(isHovered ? 1.015 : 1.0)
        .shadow(color: isHovered ? Color.kosmicPurple.opacity(0.2) : Color.black.opacity(0.05), radius: isHovered ? 8 : 3)
        .onTapGesture(perform: onTap)
    }
}

#Preview {
    DailyOverviewPanel()
        .padding()
        .environmentObject(GlassColorSystem())
}

