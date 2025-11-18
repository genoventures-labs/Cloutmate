//
//  EventColorTooltip.swift
//  FocusOS
//
//  Aurora Calendar Cognition Layer - Color explanation tooltip
//

import SwiftUI

struct EventColorTooltip: View {
    let reason: EventColorReason
    let eventColor: EventColor
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Circle()
                    .fill(eventColor.color)
                    .frame(width: 12, height: 12)
                
                Text(eventColor.description)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                Spacer()
                
                Text(String(format: "%.0f%%", reason.urgencyScore * 100))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
            }
            
            Divider()
            
            // Primary factor
            VStack(alignment: .leading, spacing: 6) {
                Text("Primary reason")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
                
                Text(reason.explanation)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
            }
            
            // Secondary factors
            if !reason.secondaryFactors.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Also considered")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                    
                    ForEach(reason.secondaryFactors.prefix(3), id: \.self) { factor in
                        HStack(spacing: 6) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 4))
                            Text(factor.capitalized)
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                        }
                        .foregroundStyle(glassColorSystem.textSecondary())
                    }
                }
            }
            
            // User override notice
            if reason.isUserOverride {
                HStack(spacing: 6) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 11))
                    Text("You overrode Aurora's suggestion")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundStyle(eventColor.color)
                .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(glassColorSystem.backgroundElevated())
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(eventColor.color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

