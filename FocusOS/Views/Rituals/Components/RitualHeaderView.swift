//
//  RitualHeaderView.swift
//  FocusOS
//
//  Rituals V2: Header component with dynamic greeting and ARTE-adaptive gradient
//

import SwiftUI

struct RitualHeaderView: View {
    let ritualType: FocusRitualType
    @StateObject private var reactiveThemeManager = ReactiveThemeManager.shared
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(greeting)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(glassColorSystem.textPrimary())
            
            Text(subtext)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(glassColorSystem.textSecondary())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.15)
            .blur(radius: 20)
        )
    }
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch ritualType {
        case .morning:
            if hour >= 5 && hour < 12 {
                return "Good morning"
            } else if hour >= 12 && hour < 17 {
                return "Good afternoon"
            } else {
                return "Good morning"
            }
        case .evening:
            if hour >= 17 && hour < 22 {
                return "Winding down?"
            } else {
                return "Evening reflection"
            }
        }
    }
    
    private var subtext: String {
        switch ritualType {
        case .morning:
            return "Let's set the day's intention and focus"
        case .evening:
            return "Reflect on what moved and what resisted"
        }
    }
    
    private var gradientColors: [Color] {
        let emotionalState = reactiveThemeManager.currentState
        
        switch ritualType {
        case .morning:
            // Morning: kosmicBlue → kosmicPurple (or ARTE-adaptive)
            switch emotionalState {
            case .energized:
                return [.kosmicBlue, .kosmicGreen]
            case .focused:
                return [.kosmicBlue, .kosmicPurple]
            case .calm:
                return [.kosmicBlue, .kosmicPurple]
            case .reflective:
                return [.kosmicPurple, .kosmicBlue]
            case .fatigued:
                return [.kosmicPurple.opacity(0.6), .kosmicBlue.opacity(0.6)]
            }
        case .evening:
            // Evening: kosmicPurple → kosmicGreen (or ARTE-adaptive)
            switch emotionalState {
            case .energized:
                return [.kosmicPurple, .kosmicGreen]
            case .focused:
                return [.kosmicPurple, .kosmicBlue]
            case .calm:
                return [.kosmicPurple, .kosmicGreen]
            case .reflective:
                return [.kosmicPurple, .kosmicGreen]
            case .fatigued:
                return [.kosmicPurple.opacity(0.6), .kosmicGreen.opacity(0.6)]
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        RitualHeaderView(ritualType: .morning)
        RitualHeaderView(ritualType: .evening)
    }
    .padding()
    .environmentObject(GlassColorSystem())
}

