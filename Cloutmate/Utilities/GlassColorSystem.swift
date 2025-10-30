//
//  GlassColorSystem.swift
//  Cloutmate
//
//  Glassmorphic Harmony UI - Glass Color System
//

import SwiftUI
import Combine
import AppKit

class GlassColorSystem: ObservableObject {
    @Published var isTimeBasedShiftingEnabled: Bool = true
    @Published var currentColorScheme: ColorScheme = .light
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Time of Day Detection
    private var timeOfDay: TimeOfDay {
        guard isTimeBasedShiftingEnabled else { return .afternoon }
        
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<21: return .evening
        default: return .night
        }
    }
    
    // MARK: - Glass Tint Colors (Light Mode)
    
    enum GlassRole {
        case primary
        case accent
        case success
        case danger
        case surface
    }
    
    // Base colors with opacity
    func glassTint(for role: GlassRole) -> Color {
        let baseColor: Color
        
        switch role {
        case .primary:
            baseColor = currentColorScheme == .dark ? 
                Color(red: 144/255, green: 202/255, blue: 249/255) :
                Color(red: 30/255, green: 136/255, blue: 229/255)
                
        case .accent:
            baseColor = currentColorScheme == .dark ?
                Color(red: 179/255, green: 157/255, blue: 219/255) :
                Color(red: 124/255, green: 77/255, blue: 255/255)
                
        case .success:
            baseColor = currentColorScheme == .dark ?
                Color(red: 129/255, green: 199/255, blue: 132/255) :
                Color(red: 67/255, green: 160/255, blue: 71/255)
                
        case .danger:
            baseColor = currentColorScheme == .dark ?
                Color(red: 239/255, green: 154/255, blue: 154/255) :
                Color(red: 229/255, green: 57/255, blue: 53/255)
                
        case .surface:
            baseColor = currentColorScheme == .dark ?
                Color(white: 0, opacity: 0.25) :
                Color(white: 1, opacity: 0.3)
        }
        
        // Apply time-of-day ambient shift
        return applyAmbientShift(to: baseColor)
    }
    
    // MARK: - Border Glow
    func borderGlow(for role: GlassRole) -> Color {
        switch role {
        case .primary:
            return Color(red: 30/255, green: 136/255, blue: 229/255, opacity: 0.3)
        case .accent:
            return Color(red: 124/255, green: 77/255, blue: 255/255, opacity: 0.35)
        case .success:
            return Color(red: 67/255, green: 160/255, blue: 71/255, opacity: 0.3)
        case .danger:
            return Color(red: 229/255, green: 57/255, blue: 53/255, opacity: 0.3)
        case .surface:
            return Color(white: 1, opacity: 0.2)
        }
    }
    
    // MARK: - Ambient Color Shifting
    private enum TimeOfDay {
        case morning
        case afternoon
        case evening
        case night
    }
    
    private func applyAmbientShift(to color: Color) -> Color {
        guard isTimeBasedShiftingEnabled else { return color }
        
        // Convert to HSB for ambient adjustment
        let shiftFactor: CGFloat
        
        switch timeOfDay {
        case .morning:
            // Warm, golden shift
            shiftFactor = 0.02 // Slight yellow shift
        case .afternoon:
            // Neutral
            shiftFactor = 0.0
        case .evening:
            // Cool, violet shift (Kosmic tone)
            shiftFactor = -0.03 // Blue-violet shift
        case .night:
            // Deep blue shift
            shiftFactor = -0.05
        }
        
        // Apply subtle hue shift
        return color.adjustHue(shiftFactor)
    }
    
    // MARK: - Auroral Gradient (for tab headers)
    func auroralGradient() -> LinearGradient {
        let colors: [Color]
        
        if isTimeBasedShiftingEnabled {
            switch timeOfDay {
            case .morning:
                colors = [
                    Color(red: 255/255, green: 235/255, blue: 200/255, opacity: 0.6),
                    Color(red: 255/255, green: 200/255, blue: 150/255, opacity: 0.4)
                ]
            case .afternoon:
                colors = [
                    Color(red: 200/255, green: 220/255, blue: 255/255, opacity: 0.6),
                    Color(red: 150/255, green: 180/255, blue: 255/255, opacity: 0.4)
                ]
            case .evening:
                colors = [
                    Color(red: 220/255, green: 200/255, blue: 255/255, opacity: 0.6),
                    Color(red: 180/255, green: 150/255, blue: 255/255, opacity: 0.4)
                ]
            case .night:
                colors = [
                    Color(red: 100/255, green: 120/255, blue: 200/255, opacity: 0.6),
                    Color(red: 50/255, green: 70/255, blue: 150/255, opacity: 0.4)
                ]
            }
        } else {
            colors = [
                Color(red: 200/255, green: 220/255, blue: 255/255, opacity: 0.6),
                Color(red: 150/255, green: 180/255, blue: 255/255, opacity: 0.4)
            ]
        }
        
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Background Gradient
    func backgroundGradient() -> LinearGradient {
        return LinearGradient(
            colors: [
                Color(red: 249/255, green: 250/255, blue: 251/255),
                Color(red: 237/255, green: 239/255, blue: 242/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    init() {
        // Update color scheme based on system appearance
        NotificationCenter.default.publisher(for: NSNotification.Name("NSInterfaceThemeChangedNotification"))
            .sink { [weak self] _ in
                _Concurrency.Task { @MainActor in
                    self?.updateColorScheme()
                }
            }
            .store(in: &cancellables)
        
        updateColorScheme()
    }
    
    private func updateColorScheme() {
        currentColorScheme = NSApp.effectiveAppearance.name == .darkAqua ? .dark : .light
    }
}

// MARK: - Color Extension
extension Color {
    func adjustHue(_ shift: CGFloat) -> Color {
        // SwiftUI doesn't have native HSB manipulation, so we return original
        // In a production app, you'd convert to HSB, adjust, and convert back
        return self
    }
}
