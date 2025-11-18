//
//  FocusForecastRing.swift
//  FocusOS
//
//  Focus Gravity V2 - Predictive energy ring overlay with color-coded fatigue risk
//

import SwiftUI

struct FocusForecastRing: View {
    let forecast: FocusForecast
    let reduceMotion: Bool
    
    @State private var ringRotation: Double = 0
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    private var ringColor: Color {
        if forecast.fatigueRisk > 0.7 {
            return .red
        } else if forecast.fatigueRisk > 0.4 {
            return .orange
        } else {
            return .kosmicGreen
        }
    }
    
    private var ringOpacity: Double {
        min(1.0, 0.3 + (forecast.fatigueRisk * 0.4))
    }
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(
                    ringColor.opacity(ringOpacity),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [5, 5])
                )
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(reduceMotion ? 0 : ringRotation))
            
            // Inner pulse
            if !reduceMotion {
                Circle()
                    .stroke(ringColor.opacity(ringOpacity * 0.5), lineWidth: 2)
                    .frame(width: 80, height: 80)
                    .scaleEffect(1.0 + sin(ringRotation * .pi / 180) * 0.1)
            }
        }
        .onAppear {
            if !reduceMotion {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    ringRotation = 360
                }
            }
        }
    }
}

