//
//  FocusGravityCard.swift
//  FocusOS
//
//  Focus Gravity V2 - Priority card matching Tasks/Projects V2 visual language
//

import SwiftUI

struct FocusGravityCard: View {
    let entity: FocusEntity
    let isSelected: Bool
    let accentColor: Color
    
    @State private var isHovered = false
    @State private var isExpanded = false
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 12) {
                // Header row
                HStack(alignment: .top, spacing: 12) {
                    // Object type badge
                    typeBadge
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entity.name)
                            .font(.headline)
                            .foregroundColor(glassColorSystem.textPrimary())
                            .lineLimit(isExpanded ? nil : 2)
                        
                        // CPS score
                        HStack(spacing: 8) {
                            Text("CPS: \(Int(entity.cpsScore * 100))")
                                .font(.caption)
                                .foregroundColor(glassColorSystem.textSecondary())
                            
                            if let lastActivity = entity.lastActivity {
                                Text("• \(timeAgo(from: lastActivity))")
                                    .font(.caption)
                                    .foregroundColor(glassColorSystem.textTertiary())
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Quick actions
                    if isHovered {
                        HStack(spacing: 8) {
                            Button {
                                // Open action
                            } label: {
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundColor(accentColor)
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                // Pin action
                            } label: {
                                Image(systemName: "pin.fill")
                                    .foregroundColor(glassColorSystem.textSecondary())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Focus distribution bar
                focusDistributionBar
                
                // Expanded content
                if isExpanded {
                    expandedContent
                }
                
                // Micro forecast badge
                if let forecast = entity.forecast {
                    forecastBadge(forecast: forecast)
                }
            }
            .padding(16)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isSelected ? accentColor.opacity(0.5) : accentColor.opacity(0.25),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isExpanded.toggle()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entity.name), \(entity.type)")
        .accessibilityValue("CPS score \(Int(entity.cpsScore * 100)), \(Int(entity.focusAllocation))% focus allocation")
        .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    // MARK: - Components
    
    private var typeBadge: some View {
        Text(entity.type.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundColor(typeColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(typeColor.opacity(0.15))
            .clipShape(Capsule())
    }
    
    private var typeColor: Color {
        switch entity.type.lowercased() {
        case "task": return .kosmicBlue
        case "project": return .kosmicPurple
        case "note": return .kosmicGreen
        default: return .gray
        }
    }
    
    private var focusDistributionBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Focus Distribution")
                .font(.caption)
                .foregroundColor(glassColorSystem.textSecondary())
            
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Cognitive
                    Rectangle()
                        .fill(Color.kosmicBlue)
                        .frame(width: geometry.size.width * CGFloat(entity.energy.cognitive))
                    
                    // Creative
                    Rectangle()
                        .fill(Color.kosmicPurple)
                        .frame(width: geometry.size.width * CGFloat(entity.energy.creative))
                    
                    // Completion
                    Rectangle()
                        .fill(Color.kosmicGreen)
                        .frame(width: geometry.size.width * CGFloat(entity.energy.completion))
                }
            }
            .frame(height: 6)
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }
    
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            
            // Session count
            HStack {
                Image(systemName: "timer")
                    .font(.caption)
                    .foregroundColor(glassColorSystem.textSecondary())
                Text("\(entity.sessionCount) focus sessions")
                    .font(.caption)
                    .foregroundColor(glassColorSystem.textSecondary())
            }
            
            // Ritual weight
            if entity.ritualWeight > 0 {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundColor(glassColorSystem.textSecondary())
                    Text("Ritual weight: \(Int(entity.ritualWeight * 100))%")
                        .font(.caption)
                        .foregroundColor(glassColorSystem.textSecondary())
                }
            }
            
            // Energy breakdown
            VStack(alignment: .leading, spacing: 4) {
                Text("Energy Profile")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(glassColorSystem.textPrimary())
                
                HStack(spacing: 16) {
                    energyItem(label: "Cognitive", value: entity.energy.cognitive, color: .kosmicBlue)
                    energyItem(label: "Creative", value: entity.energy.creative, color: .kosmicPurple)
                    energyItem(label: "Completion", value: entity.energy.completion, color: .kosmicGreen)
                }
            }
        }
    }
    
    private func energyItem(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(glassColorSystem.textSecondary())
            Text("\(Int(value * 100))%")
                .font(.caption.weight(.semibold))
                .foregroundColor(color)
        }
    }
    
    private func forecastBadge(forecast: FocusForecast) -> some View {
        HStack(spacing: 6) {
            Image(systemName: forecast.fatigueRisk > 0.6 ? "exclamationmark.triangle.fill" : "sparkles")
                .font(.caption2)
            
            if let windowStart = forecast.nextFocusWindowStart,
               windowStart.timeIntervalSinceNow > 0 {
                let minutes = Int(windowStart.timeIntervalSinceNow / 60)
                Text("Focus Peak in \(minutes)m")
                    .font(.caption)
            } else if forecast.fatigueRisk > 0.6 {
                Text("Fatigue risk ↑")
                    .font(.caption)
            } else {
                Text("Stable focus")
                    .font(.caption)
            }
        }
        .foregroundColor(forecast.fatigueRisk > 0.6 ? .orange : .kosmicGreen)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            (forecast.fatigueRisk > 0.6 ? Color.orange : Color.kosmicGreen)
                .opacity(0.15)
        )
        .clipShape(Capsule())
    }
    
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "just now"
        }
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "\(minutes)m ago"
        }
        let hours = Int(interval / 3600)
        if hours < 24 {
            return "\(hours)h ago"
        }
        let days = Int(interval / 86400)
        return "\(days)d ago"
    }
}

