//
//  AccessibilityGlassManager.swift
//  Cloutmate
//
//  Glassmorphic Harmony UI - Accessibility & Performance Manager
//

import SwiftUI
import AppKit
import Combine

enum PerformanceMode: String, CaseIterable {
    case maxFidelity = "Max Fidelity"
    case balanced = "Balanced"
    
    var description: String {
        switch self {
        case .maxFidelity:
            return "Maximum visual quality with all effects enabled"
        case .balanced:
            return "Optimized performance with selective effects"
        }
    }
}

class AccessibilityGlassManager: ObservableObject {
    @Published var reduceTransparency: Bool = false
    @Published var performanceMode: PerformanceMode = .balanced
    @Published var isAnimationsEnabled: Bool = true
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Initialize accessibility settings
        // Update on main thread if needed
        _Concurrency.Task { @MainActor in
        updateAccessibilitySettings()
        }
    }
    
    @MainActor
    private func updateAccessibilitySettings() {
        // Note: There's no direct API to check Reduce Transparency in Swift
        // In a production app, you'd use NSWorkspace to check accessibility preferences
    }
    
    // MARK: - Material Selection
    
    /// Get the appropriate material based on accessibility settings
    func getMaterial(for tier: GlassTier) -> Material {
        if reduceTransparency {
            // Use thicker material for better contrast when transparency is reduced
            return .thickMaterial
        }
        
        // Return tier-appropriate material
        return tier.material
    }
    
    // MARK: - Performance Optimization
    
    /// Should effects be applied based on performance mode
    func shouldApplyEffects() -> Bool {
        return performanceMode == .maxFidelity
    }
    
    /// Should animations be disabled
    func shouldDisableAnimations() -> Bool {
        return !isAnimationsEnabled || performanceMode == .balanced
    }
    
    // MARK: - Contrast Adjustment
    
    /// Adjust accent colors for better contrast in Light Mode
    func adjustedAccentColor(_ baseColor: Color, for scheme: ColorScheme) -> Color {
        if scheme == .light && reduceTransparency {
            // Make 10% darker for better legibility
            return baseColor.opacity(0.9)
        }
        return baseColor
    }
    
    // MARK: - Accessibility Annotations
    
    /// Apply reduced motion based on system preferences
    func withAccessibilityAnimation<T>(transform: @escaping () -> T) -> T where T: Equatable {
        if shouldDisableAnimations() {
            var result: T?
            withAnimation(nil) {
                result = transform()
            }
            return result ?? transform()
        } else {
            return withAnimation(.easeInOut) {
                transform()
            }
        }
    }
}

// MARK: - Environment Key
struct AccessibilityGlassManagerKey: EnvironmentKey {
    static let defaultValue: AccessibilityGlassManager = AccessibilityGlassManager()
}

extension EnvironmentValues {
    var accessibilityGlassManager: AccessibilityGlassManager {
        get { self[AccessibilityGlassManagerKey.self] }
        set { self[AccessibilityGlassManagerKey.self] = newValue }
    }
}
