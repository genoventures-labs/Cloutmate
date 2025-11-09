//
//  FocusInsightsDrawer.swift
//  Cloutmate
//
//  Focus Gravity V2 - Sidebar with Current Pull, Drift Alerts, Focus Bias, and Aurora commentary
//

import SwiftUI
import SwiftData

struct FocusInsightsDrawer: View {
    let entities: [FocusEntity]
    let forecast: FocusForecast?
    let modelContext: ModelContext
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @StateObject private var reactiveTheme = ReactiveThemeManager.shared
    
    private var topEntities: [FocusEntity] {
        Array(entities.prefix(5))
    }
    
    private var focusDistribution: FocusEnergyProfile {
        FocusGravityService.shared.getFocusDistribution(entities: entities)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Text("Focus Insights")
                    .font(.title2.bold())
                    .foregroundColor(glassColorSystem.textPrimary())
                    .padding(.bottom, 8)
                
                // Current Pull
                currentPullSection
                
                // Focus Bias
                focusBiasSection
                
                // Drift Alerts
                if let forecast = forecast {
                    driftAlertsSection(forecast: forecast)
                }
                
                // Aurora Commentary
                auroraCommentarySection
            }
            .padding(20)
        }
        .background(glassColorSystem.backgroundElevated())
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Sections
    
    private var currentPullSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Pull")
                .font(.headline)
                .foregroundColor(glassColorSystem.textPrimary())
            
            if topEntities.isEmpty {
                Text("No entities pulling focus")
                    .font(.subheadline)
                    .foregroundColor(glassColorSystem.textSecondary())
            } else {
                ForEach(topEntities) { entity in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entity.name)
                                .font(.subheadline)
                                .foregroundColor(glassColorSystem.textPrimary())
                                .lineLimit(1)
                            
                            Text("\(Int(entity.focusAllocation))% allocation")
                                .font(.caption)
                                .foregroundColor(glassColorSystem.textSecondary())
                        }
                        
                        Spacer()
                        
                        Circle()
                            .fill(colorForEnergyType(entity.energy.dominantType))
                            .frame(width: 8, height: 8)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .background(glassColorSystem.cardColor())
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var focusBiasSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Focus Bias")
                .font(.headline)
                .foregroundColor(glassColorSystem.textPrimary())
            
            VStack(alignment: .leading, spacing: 8) {
                biasBar(label: "Cognitive", value: focusDistribution.cognitive, color: .kosmicBlue)
                biasBar(label: "Creative", value: focusDistribution.creative, color: .kosmicPurple)
                biasBar(label: "Completion", value: focusDistribution.completion, color: .kosmicGreen)
            }
        }
        .padding(16)
        .background(glassColorSystem.cardColor())
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func biasBar(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(glassColorSystem.textSecondary())
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.3))
                    .frame(width: geometry.size.width * CGFloat(value), height: 4)
            }
            .frame(height: 4)
        }
    }
    
    private func driftAlertsSection(forecast: FocusForecast) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Drift Alerts")
                .font(.headline)
                .foregroundColor(glassColorSystem.textPrimary())
            
            if forecast.fatigueRisk > 0.6 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("High Fatigue Risk")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(glassColorSystem.textPrimary())
                        Text("\(Int(forecast.fatigueRisk * 100))% risk detected")
                            .font(.caption)
                            .foregroundColor(glassColorSystem.textSecondary())
                    }
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            if forecast.focusStability < 0.5 {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path")
                        .foregroundColor(.kosmicPurple)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Focus Instability")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(glassColorSystem.textPrimary())
                        Text("Stability: \(Int(forecast.focusStability * 100))%")
                            .font(.caption)
                            .foregroundColor(glassColorSystem.textSecondary())
                    }
                }
                .padding(12)
                .background(Color.kosmicPurple.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            if forecast.fatigueRisk <= 0.6 && forecast.focusStability >= 0.5 {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.kosmicGreen)
                    Text("Focus stable")
                        .font(.subheadline)
                        .foregroundColor(glassColorSystem.textPrimary())
                }
                .padding(12)
                .background(Color.kosmicGreen.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(glassColorSystem.cardColor())
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var auroraCommentarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(stateColor)
                Text("Aurora Insight")
                    .font(.headline)
                    .foregroundColor(glassColorSystem.textPrimary())
            }
            
            Text(generateAuroraCommentary())
                .font(.subheadline)
                .foregroundColor(glassColorSystem.textSecondary())
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(stateColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(stateColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var stateColor: Color {
        switch reactiveTheme.currentState {
        case .calm: return .kosmicBlue
        case .focused: return .kosmicPurple
        case .fatigued: return .orange
        case .energized: return .kosmicGreen
        case .reflective: return .cyan
        }
    }
    
    private func generateAuroraCommentary() -> String {
        let dominantType = focusDistribution.dominantType
        let topEntity = topEntities.first
        
        var commentary = ""
        
        if let entity = topEntity {
            commentary += "\(entity.name) is pulling strongest focus right now"
            
            switch dominantType {
            case .cognitive:
                commentary += ", with analytical work dominating your attention."
            case .creative:
                commentary += ", showing creative flow is active."
            case .completion:
                commentary += ", indicating strong execution momentum."
            }
        } else {
            commentary = "Your focus is distributed evenly across energy types."
        }
        
        if let forecast = forecast, forecast.fatigueRisk > 0.6 {
            commentary += " Consider taking a break soon—fatigue risk is elevated."
        }
        
        return commentary
    }
    
    private func colorForEnergyType(_ type: FocusEnergyType) -> Color {
        switch type {
        case .cognitive: return .kosmicBlue
        case .creative: return .kosmicPurple
        case .completion: return .kosmicGreen
        }
    }
}

