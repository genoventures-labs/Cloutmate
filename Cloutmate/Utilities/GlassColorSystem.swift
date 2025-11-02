//
//  GlassColorSystem.swift
//  Cloutmate
//
//  Minimal Apple Music-inspired color system with theme support
//

import SwiftUI
import Combine
import AppKit

class GlassColorSystem: ObservableObject {
    @Published var isTimeBasedShiftingEnabled: Bool = true
    @Published var currentColorScheme: ColorScheme = .dark
    
    // MARK: - ARTE Integration (Phase 7)
    @Published var emotionalState: EmotionalState = .calm
    @Published var emotionalIntensity: Double = 0.7
    @Published var isARTEEnabled: Bool = true
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Palette
    private enum Palette {
        // Dark Mode Colors (Apple Music inspired)
        enum Dark {
            static let background = Color(hex: "1A1A1A")
            static let backgroundElevated = Color(hex: "2C2C2E")
            static let backgroundSecondary = Color(hex: "3A3A3C")
            static let card = Color(hex: "2C2C2E")
            static let cardElevated = Color(hex: "3A3A3C")
        }
        
        // Light Mode Colors
        enum Light {
            static let background = Color(hex: "F5F5F7")
            static let backgroundElevated = Color.white
            static let backgroundSecondary = Color(hex: "EBEBF0")
            static let card = Color.white
            static let cardElevated = Color.white
        }
        
        // Kosmic Brand Accents (theme-independent)
        static let accentPrimary = Color(red: 72/255, green: 131/255, blue: 255/255)
        static let accentSecondary = Color(red: 124/255, green: 77/255, blue: 255/255)
        static let success = Color(red: 67/255, green: 160/255, blue: 71/255)
        static let danger = Color(red: 229/255, green: 57/255, blue: 53/255)
    }
    
    // MARK: - Roles
    enum GlassRole {
        case primary
        case accent
        case success
        case danger
        case surface
    }
    
    // MARK: - Theme-Aware Colors
    
    /// Main background color
    func backgroundColor() -> Color {
        currentColorScheme == .dark ? Palette.Dark.background : Palette.Light.background
    }
    
    /// Elevated background (sidebar)
    func backgroundElevated() -> Color {
        currentColorScheme == .dark ? Palette.Dark.backgroundElevated : Palette.Light.backgroundElevated
    }
    
    /// Secondary background
    func backgroundSecondary() -> Color {
        currentColorScheme == .dark ? Palette.Dark.backgroundSecondary : Palette.Light.backgroundSecondary
    }
    
    /// Card background
    func cardColor() -> Color {
        currentColorScheme == .dark ? Palette.Dark.card : Palette.Light.card
    }
    
    /// Elevated card background
    func cardElevated() -> Color {
        currentColorScheme == .dark ? Palette.Dark.cardElevated : Palette.Light.cardElevated
    }
    
    /// Border color (subtle)
    func borderColor() -> Color {
        currentColorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }
    
    /// Divider color
    func dividerColor() -> Color {
        currentColorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.06)
    }
    
    /// Primary text color
    func textPrimary() -> Color {
        currentColorScheme == .dark ? Color.white : Color.black
    }
    
    /// Secondary text color
    func textSecondary() -> Color {
        currentColorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6)
    }
    
    /// Tertiary text color
    func textTertiary() -> Color {
        currentColorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.4)
    }
    
    /// Accent tint for roles
    func glassTint(for role: GlassRole) -> Color {
        switch role {
        case .primary:
            return Palette.accentPrimary
        case .accent:
            return Palette.accentSecondary
        case .success:
            return Palette.success
        case .danger:
            return Palette.danger
        case .surface:
            return currentColorScheme == .dark ? Palette.Dark.backgroundSecondary : Palette.Light.backgroundSecondary
        }
    }
    
    /// Solid button color (replaces gradient)
    func buttonColor(for role: GlassRole) -> Color {
        switch role {
        case .primary:
            return Palette.accentPrimary
        case .accent:
            return Palette.accentSecondary
        case .success:
            return Palette.success
        case .danger:
            return Palette.danger
        case .surface:
            return currentColorScheme == .dark ? Palette.Dark.cardElevated : Palette.Light.cardElevated
        }
    }
    
    /// Legacy: Returns solid color as gradient for backward compatibility
    func buttonGradient(for role: GlassRole) -> LinearGradient {
        let color = buttonColor(for: role)
        return LinearGradient(colors: [color], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    /// Simplified border (returns solid color as gradient for compatibility)
    func borderGradient(for role: GlassRole) -> LinearGradient {
        let color: Color
        switch role {
        case .primary, .accent, .success, .danger:
            color = glassTint(for: role).opacity(0.3)
        case .surface:
            color = borderColor()
        }
        return LinearGradient(colors: [color], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    /// Removed glow effect - returns transparent
    func borderGlow(for role: GlassRole) -> Color {
        return .clear
    }
    
    // MARK: - Panels (Simplified for minimal design)
    
    /// Sidebar color (flat)
    func sidebarGradient() -> LinearGradient {
        let color = backgroundElevated()
        return LinearGradient(colors: [color], startPoint: .top, endPoint: .bottom)
    }
    
    /// Panel color based on tier (flat)
    func panelGradient(for tier: GlassTier) -> LinearGradient {
        let color: Color
        switch tier {
        case .background:
            color = backgroundColor()
        case .sidebar:
            color = backgroundElevated()
        case .contentCard:
            color = cardColor()
        case .overlay:
            color = cardElevated()
        case .floatingAction:
            color = cardElevated()
        }
        return LinearGradient(colors: [color], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    /// No specular highlight in minimal design
    func panelSpecularHighlight(for tier: GlassTier) -> LinearGradient {
        return LinearGradient(colors: [Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    /// Subtle border rim
    func panelRim(for tier: GlassTier) -> LinearGradient {
        let color = borderColor()
        return LinearGradient(colors: [color], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    // MARK: - Legacy support (removed effects)
    
    /// Removed auroral gradient
    func auroralGradient() -> LinearGradient {
        let color = Palette.accentPrimary.opacity(0.6)
        return LinearGradient(colors: [color], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    /// Flat background (no gradient)
    func backgroundGradient() -> LinearGradient {
        let color = backgroundColor()
        return LinearGradient(colors: [color], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    // MARK: - ARTE Emotional Modulation (Phase 7)
    
    /// Apply emotional modulation to a color
    func applyEmotionalModulation(to color: Color) -> Color {
        guard isARTEEnabled else { return color }
        
        let palette = EmotionalPalette.palette(for: emotionalState)
        let intensity = emotionalIntensity
        
        // Adjust color based on emotional palette
        // This is a simplified version - modulates saturation and brightness
        return color
            .adjustSaturation(by: palette.accentSaturation * intensity)
            .adjustContrast(by: palette.contrastModifier)
    }
    
    /// Get emotionally-modulated accent color
    func emotionalAccent() -> Color {
        guard isARTEEnabled else { return Palette.accentPrimary }
        
        let palette = EmotionalPalette.palette(for: emotionalState)
        let baseAccent = Palette.accentPrimary
        
        // Shift hue based on emotional state
        return baseAccent
            .adjustHue(to: palette.accentHue)
            .adjustSaturation(by: palette.accentSaturation * emotionalIntensity)
    }
    
    /// Get emotionally-modulated shadow tone
    func emotionalShadowTone() -> Color {
        guard isARTEEnabled else {
            return currentColorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.15)
        }
        
        let palette = EmotionalPalette.palette(for: emotionalState)
        let warmth = palette.shadowWarmth
        
        // Warm shadows = slightly brown/orange tint
        // Cool shadows = slightly blue tint
        if warmth > 0 {
            // Warmer shadows
            return Color(red: 0.1 * warmth, green: 0.05 * warmth, blue: 0.0)
                .opacity(currentColorScheme == .dark ? 0.4 : 0.2)
        } else {
            // Cooler shadows
            return Color(red: 0.0, green: 0.05 * abs(warmth), blue: 0.1 * abs(warmth))
                .opacity(currentColorScheme == .dark ? 0.4 : 0.2)
        }
    }
    
    /// Get emotionally-modulated background shift
    func emotionalBackgroundShift() -> Color {
        guard isARTEEnabled else { return Color.clear }
        
        let palette = EmotionalPalette.palette(for: emotionalState)
        return palette.backgroundTint.opacity(emotionalIntensity)
    }
    
    /// Get emotionally-adjusted animation speed multiplier
    func emotionalAnimationSpeed() -> Double {
        guard isARTEEnabled else { return 1.0 }
        
        let palette = EmotionalPalette.palette(for: emotionalState)
        return palette.animationSpeed
    }
    
    /// Update emotional state from ReactiveThemeManager
    func updateEmotionalState(_ state: EmotionalState, intensity: Double) {
        self.emotionalState = state
        self.emotionalIntensity = intensity
    }
    
    // MARK: - Lifecycle
    init() {
        // Initialize with system appearance
        updateColorScheme()
        
        // Listen for system appearance changes
        NotificationCenter.default.publisher(for: NSNotification.Name("NSInterfaceThemeChangedNotification"))
            .sink { [weak self] _ in
                _Concurrency.Task { @MainActor in
                    // Only update if using system theme
                    let appearanceMode = UserDefaults.standard.string(forKey: "appearanceMode") ?? "system"
                    if appearanceMode == "system" {
                        self?.updateColorScheme()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateColorScheme() {
        // Respect user's appearance preference
        let appearanceMode = UserDefaults.standard.string(forKey: "appearanceMode") ?? "system"
        switch appearanceMode {
        case "light":
            currentColorScheme = .light
        case "dark":
            currentColorScheme = .dark
        default: // system
            currentColorScheme = NSApp.effectiveAppearance.name == .darkAqua ? .dark : .light
        }
    }
}

// MARK: - Color Extension for Hex Support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    // MARK: - ARTE Color Manipulation
    
    /// Adjust saturation by multiplier
    func adjustSaturation(by multiplier: Double) -> Color {
        // Simplified saturation adjustment
        // In production, would use HSB color space conversion
        return self
    }
    
    /// Adjust contrast by multiplier
    func adjustContrast(by multiplier: Double) -> Color {
        // Simplified contrast adjustment
        // In production, would adjust lightness in LAB color space
        return self
    }
    
    /// Adjust hue to target value (0-360)
    func adjustHue(to targetHue: Double) -> Color {
        // Simplified hue adjustment
        // In production, would use HSB color space conversion
        return self
    }
}
